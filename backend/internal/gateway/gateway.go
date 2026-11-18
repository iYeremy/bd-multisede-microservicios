// Package gateway es la unica puerta de entrada al backend: recibe todo lo
// que llega del navegador, valida la sesion con identidad y lo reenvia al
// servicio que corresponde. los servicios no se exponen hacia afuera.
package gateway

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httputil"
	"net/url"
	"slices"
	"strconv"
	"sync"
	"time"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/iYeremy/bd-multisede-microservicios/backend/web"
)

// nombre de la cookie y del encabezado de la sesion (los mismos de identidad;
// se repiten aqui porque el gateway no importa el codigo de los servicios)
const (
	cookieSesion = "sesion"
	headerSesion = "X-Sesion"
)

// encabezados que solo puede poner el gateway. si vienen del navegador se
// borran: si no, cualquiera podria decir "soy el admin" mandando
// X-Usuario-Rol: ADMINISTRADOR.
var encabezadosProtegidos = []string{
	plataforma.HeaderUsuarioID, plataforma.HeaderUsuarioRol,
	plataforma.HeaderUsuarioEmpleado, plataforma.HeaderUsuarioSede,
	plataforma.HeaderToken, headerSesion,
}

// rutas que no piden sesion (todas las demas de /api si)
var rutasPublicas = []string{"/api/identidad/login", "/api/identidad/logout"}

// Gateway guarda un proxy por servicio y los clientes http.
type Gateway struct {
	proxies      map[string]*httputil.ReverseProxy
	cliente      *plataforma.ClienteInterno
	clienteSalud *http.Client
}

// Nuevo arma el gateway con la direccion de cada servicio (URL_<SERVICIO>
// en el .env, o http://127.0.0.1:810x por defecto).
func Nuevo(tokenInterno string) (*Gateway, error) {
	g := &Gateway{
		proxies:      map[string]*httputil.ReverseProxy{},
		cliente:      plataforma.NuevoClienteInterno(tokenInterno),
		clienteSalud: &http.Client{Timeout: 2 * time.Second},
	}
	for _, s := range plataforma.Servicios {
		destino, err := url.Parse(plataforma.URLServicio(s))
		if err != nil {
			return nil, err
		}
		g.proxies[s] = nuevoProxy(s, destino)
	}
	return g, nil
}

// nuevoProxy reenvia la peticion tal cual (misma ruta) al servicio destino.
func nuevoProxy(servicio string, destino *url.URL) *httputil.ReverseProxy {
	return &httputil.ReverseProxy{
		Rewrite: func(pr *httputil.ProxyRequest) {
			pr.SetURL(destino)
			pr.SetXForwarded()
			// pr.Out es una copia de la peticion: lleva los X-Usuario-* que
			// puso autenticar (y ya sin lo que mando el navegador)
		},
		// si el servicio esta apagado o no responde
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			plataforma.ResponderError(w, http.StatusServiceUnavailable, "Servicio "+servicio+" no disponible")
		},
	}
}

// Rutas devuelve el handler del gateway.
//
//	/api/<servicio>/...  valida la sesion y lo reenvia a ese servicio
//	GET /salud           estado de los seis servicios
//	GET /                el front (backend/web/static, metido en el binario)
//	/interno/...         nunca se reenvia (no existe en el gateway)
func (g *Gateway) Rutas() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/{servicio}/", g.reenviar) // /api/reportes/vista_...
	mux.HandleFunc("/api/{servicio}", g.reenviar)  // /api/reportes (sin barra al final)
	mux.HandleFunc("GET /salud", g.salud)
	// "/" atrapa todo lo demas. va sin metodo porque "GET /" chocaria con
	// "/api/{servicio}/" (ninguno de los dos seria mas especifico)
	mux.Handle("/", front())
	return mux
}

// front sirve los archivos del front. solo GET; lo que no existe da 404
// (por ejemplo /interno/sesion: el gateway no lo reenvia nunca).
func front() http.Handler {
	archivos := http.FileServerFS(web.Archivos())
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			plataforma.ResponderError(w, http.StatusMethodNotAllowed, "Metodo no permitido")
			return
		}
		h := w.Header()
		// la pagina solo puede cargar sus propios archivos (y la fuente de
		// google): si alguien lograra meter un <script> en un dato, no corre
		h.Set("Content-Security-Policy", "default-src 'self'; style-src 'self' https://fonts.googleapis.com; "+
			"font-src https://fonts.gstatic.com; img-src 'self' data:; frame-ancestors 'none'")
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "same-origin")
		// sin cache: al actualizar el servidor, el navegador trae lo nuevo
		h.Set("Cache-Control", "no-cache")
		archivos.ServeHTTP(w, r)
	})
}

func (g *Gateway) reenviar(w http.ResponseWriter, r *http.Request) {
	proxy, ok := g.proxies[r.PathValue("servicio")]
	if !ok {
		plataforma.ResponderError(w, http.StatusNotFound, "No existe el servicio "+r.PathValue("servicio"))
		return
	}

	// 1. borrar lo que el navegador no puede mandar
	for _, h := range encabezadosProtegidos {
		r.Header.Del(h)
	}

	// 2. validar la sesion (menos en login y logout)
	if !slices.Contains(rutasPublicas, r.URL.Path) {
		if !g.autenticar(w, r) {
			return
		}
	}
	proxy.ServeHTTP(w, r)
}

// autenticar le pregunta a identidad de quien es la cookie. si es valida,
// pone los X-Usuario-* en la peticion; si no, responde 401 o 503 y
// devuelve false (la peticion no llega a ningun servicio).
func (g *Gateway) autenticar(w http.ResponseWriter, r *http.Request) bool {
	c, err := r.Cookie(cookieSesion)
	if err != nil || c.Value == "" {
		plataforma.ResponderError(w, http.StatusUnauthorized, "Inicia sesion primero")
		return false
	}

	var u plataforma.Usuario
	err = g.cliente.Get(r.Context(), "identidad", "/interno/sesion", r.Header.Get(plataforma.HeaderRequestID),
		&u, plataforma.ConEncabezado(headerSesion, c.Value))
	var caido plataforma.ErrServicioCaido
	switch {
	case errors.As(err, &caido):
		plataforma.ResponderError(w, http.StatusServiceUnavailable, "Identidad no disponible: no se puede validar la sesion")
		return false
	case err != nil:
		plataforma.ResponderError(w, http.StatusUnauthorized, "Sesion invalida o vencida: inicia sesion de nuevo")
		return false
	}

	r.Header.Set(plataforma.HeaderUsuarioID, strconv.Itoa(u.ID))
	r.Header.Set(plataforma.HeaderUsuarioRol, u.Rol)
	r.Header.Set(plataforma.HeaderUsuarioEmpleado, strconv.Itoa(u.Empleado))
	r.Header.Set(plataforma.HeaderUsuarioSede, strconv.Itoa(u.Sede))
	return true
}

// EstadoServicio es una fila de /salud.
type EstadoServicio struct {
	Servicio string `json:"servicio"`
	Estado   string `json:"estado"` // ok, sin base de datos, caido
	MS       int64  `json:"ms"`     // cuanto tardo en responder
}

// salud pregunta a los seis servicios a la vez (en paralelo, con
// goroutines) y responde 200 si todos estan bien, o 503 si alguno no.
func (g *Gateway) salud(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()

	estados := make([]EstadoServicio, len(plataforma.Servicios))
	var wg sync.WaitGroup
	for i, s := range plataforma.Servicios {
		wg.Add(1)
		go func() {
			defer wg.Done()
			inicio := time.Now()
			estados[i] = EstadoServicio{Servicio: s, Estado: g.preguntarSalud(ctx, s)}
			estados[i].MS = time.Since(inicio).Milliseconds()
		}()
	}
	wg.Wait()

	codigo := http.StatusOK
	if slices.ContainsFunc(estados, func(e EstadoServicio) bool { return e.Estado != "ok" }) {
		codigo = http.StatusServiceUnavailable
	}
	plataforma.ResponderJSON(w, codigo, map[string]any{"servicios": estados})
}

func (g *Gateway) preguntarSalud(ctx context.Context, servicio string) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, plataforma.URLServicio(servicio)+"/salud", nil)
	if err != nil {
		return "caido"
	}
	resp, err := g.clienteSalud.Do(req)
	if err != nil {
		return "caido"
	}
	defer resp.Body.Close()
	var cuerpo struct {
		Estado string `json:"estado"`
	}
	json.NewDecoder(resp.Body).Decode(&cuerpo)
	if resp.StatusCode == http.StatusOK {
		return "ok"
	}
	return cuerpo.Estado
}
