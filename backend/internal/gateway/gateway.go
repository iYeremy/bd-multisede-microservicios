// Package gateway es la unica puerta de entrada al backend: recibe todo lo
// que llega del navegador y lo reenvia al servicio que corresponde. los
// servicios solo escuchan en 127.0.0.1, asi que desde afuera solo se llega
// por aqui.
package gateway

import (
	"context"
	"net/http"
	"net/http/httputil"
	"net/url"
	"slices"
	"sync"
	"time"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
)

// encabezados que solo puede poner el gateway (cuando valida la sesion, en
// la fase 3). si vienen del navegador se borran: si no, cualquiera podria
// decir "soy el admin" mandando X-Usuario-Rol: ADMINISTRADOR.
var encabezadosProtegidos = []string{
	"X-Usuario-Id", "X-Usuario-Rol", "X-Usuario-Empleado", "X-Usuario-Sede",
	plataforma.HeaderToken,
}

// Gateway guarda un proxy por servicio y un cliente para /salud.
type Gateway struct {
	proxies map[string]*httputil.ReverseProxy
	urls    map[string]string
	cliente *plataforma.ClienteInterno
}

// Nuevo arma el gateway con la direccion de cada servicio (URL_<SERVICIO>
// en el .env, o http://127.0.0.1:810x por defecto).
func Nuevo(tokenInterno string) (*Gateway, error) {
	g := &Gateway{
		proxies: map[string]*httputil.ReverseProxy{},
		urls:    map[string]string{},
		cliente: plataforma.NuevoClienteInterno(tokenInterno),
	}
	for _, s := range plataforma.Servicios {
		destino, err := url.Parse(plataforma.URLServicio(s))
		if err != nil {
			return nil, err
		}
		g.urls[s] = destino.String()
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
			for _, h := range encabezadosProtegidos {
				pr.Out.Header.Del(h)
			}
		},
		// si el servicio esta apagado o no responde
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			plataforma.ResponderError(w, http.StatusServiceUnavailable, "Servicio "+servicio+" no disponible")
		},
	}
}

// Rutas devuelve el handler del gateway.
//
//	/api/<servicio>/...  se reenvia a ese servicio
//	GET /salud           estado de los seis servicios
//	/interno/...         nunca se reenvia (no existe en el gateway)
func (g *Gateway) Rutas() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/{servicio}/", func(w http.ResponseWriter, r *http.Request) {
		proxy, ok := g.proxies[r.PathValue("servicio")]
		if !ok {
			plataforma.ResponderError(w, http.StatusNotFound, "No existe el servicio "+r.PathValue("servicio"))
			return
		}
		proxy.ServeHTTP(w, r)
	})
	mux.HandleFunc("GET /salud", g.salud)
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		plataforma.ResponderJSON(w, http.StatusOK, map[string]string{
			"mensaje": "Comercializadora Andina - gateway. El front llega en la fase 7; por ahora: /salud y /api/<servicio>/...",
		})
	})
	return mux
}

// EstadoServicio es una fila de /salud.
type EstadoServicio struct {
	Servicio string `json:"servicio"`
	Estado   string `json:"estado"` // ok, sin base de datos, caido
	URL      string `json:"url"`
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
			var resp struct {
				Estado string `json:"estado"`
			}
			codigo, err := g.cliente.Get(ctx, s, g.urls[s]+"/salud", r.Header.Get(plataforma.HeaderRequestID), &resp)
			estado := "caido"
			switch {
			case err == nil && codigo == http.StatusOK:
				estado = "ok"
			case err == nil:
				estado = "sin base de datos"
			}
			estados[i] = EstadoServicio{Servicio: s, Estado: estado, URL: g.urls[s]}
		}()
	}
	wg.Wait()

	codigo := http.StatusOK
	if slices.ContainsFunc(estados, func(e EstadoServicio) bool { return e.Estado != "ok" }) {
		codigo = http.StatusServiceUnavailable
	}
	plataforma.ResponderJSON(w, codigo, map[string]any{"servicios": estados})
}
