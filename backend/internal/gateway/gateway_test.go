package gateway

import (
	"compress/gzip"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
)

// prueba el gateway con servicios FALSOS: un identidad que solo conoce el
// token "bueno", y un catalogo que devuelve los encabezados que le llegaron.
func TestGatewayValidaSesionYBorraEncabezados(t *testing.T) {
	identidad := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get(headerSesion) != "bueno" {
			plataforma.ResponderError(w, http.StatusUnauthorized, "no")
			return
		}
		plataforma.ResponderJSON(w, http.StatusOK, plataforma.Usuario{ID: 10, Rol: "VENDEDOR", Empleado: 12, Sede: 3})
	}))
	defer identidad.Close()
	catalogo := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		plataforma.ResponderJSON(w, http.StatusOK, map[string]string{
			"rol": r.Header.Get(plataforma.HeaderUsuarioRol), "sede": r.Header.Get(plataforma.HeaderUsuarioSede),
		})
	}))
	defer catalogo.Close()

	// t.Setenv cambia una variable solo durante esta prueba
	t.Setenv("URL_IDENTIDAD", identidad.URL)
	t.Setenv("URL_CATALOGO", catalogo.URL)
	g, err := Nuevo("token-de-prueba")
	if err != nil {
		t.Fatal(err)
	}
	h := g.Rutas()

	pedir := func(cookie string, extra map[string]string) *httptest.ResponseRecorder {
		r := httptest.NewRequest("GET", "/api/catalogo/productos", nil)
		if cookie != "" {
			r.AddCookie(&http.Cookie{Name: cookieSesion, Value: cookie})
		}
		for k, v := range extra {
			r.Header.Set(k, v)
		}
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w
	}

	if w := pedir("", nil); w.Code != http.StatusUnauthorized {
		t.Errorf("sin cookie: %d, se esperaba 401", w.Code)
	}
	if w := pedir("inventado", nil); w.Code != http.StatusUnauthorized {
		t.Errorf("token falso: %d, se esperaba 401", w.Code)
	}

	// con sesion valida, pero intentando hacerse pasar por admin de bogota
	w := pedir("bueno", map[string]string{plataforma.HeaderUsuarioRol: "ADMINISTRADOR", plataforma.HeaderUsuarioSede: "1"})
	var got map[string]string
	json.NewDecoder(w.Body).Decode(&got)
	if w.Code != http.StatusOK || got["rol"] != "VENDEDOR" || got["sede"] != "3" {
		t.Errorf("le llego al servicio %v (codigo %d): debia ser VENDEDOR de la sede 3", got, w.Code)
	}

	// el gateway no reenvia /interno
	r := httptest.NewRequest("GET", "/interno/productos?ids=1", nil)
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)
	if rec.Code != http.StatusNotFound {
		t.Errorf("/interno por el gateway: %d, se esperaba 404", rec.Code)
	}
}

func TestGatewaySirveElFront(t *testing.T) {
	g, err := Nuevo("token-de-prueba")
	if err != nil {
		t.Fatal(err)
	}
	h := g.Rutas()
	pedir := func(metodo, ruta string) *httptest.ResponseRecorder {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(metodo, ruta, nil))
		return rec
	}

	for _, ruta := range []string{"/", "/app.js", "/estilos.css", "/icono.svg"} {
		rec := pedir("GET", ruta)
		if rec.Code != http.StatusOK {
			t.Errorf("GET %s: %d, se esperaba 200", ruta, rec.Code)
		}
		if rec.Header().Get("Content-Security-Policy") == "" {
			t.Errorf("GET %s: falta la Content-Security-Policy", ruta)
		}
	}
	if !strings.Contains(pedir("GET", "/").Body.String(), "app.js") {
		t.Error("GET / deberia devolver index.html")
	}
	if c := pedir("POST", "/").Code; c != http.StatusMethodNotAllowed {
		t.Errorf("POST /: %d, se esperaba 405", c)
	}
	if c := pedir("GET", "/no-existe.js").Code; c != http.StatusNotFound {
		t.Errorf("un archivo que no existe: %d, se esperaba 404", c)
	}
}

func TestGatewayComprimeYUsaCache(t *testing.T) {
	g, err := Nuevo("token-de-prueba")
	if err != nil {
		t.Fatal(err)
	}
	h := g.Rutas()
	pedir := func(ruta string, encabezados map[string]string) *httptest.ResponseRecorder {
		req := httptest.NewRequest("GET", ruta, nil)
		for k, v := range encabezados {
			req.Header.Set(k, v)
		}
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		return rec
	}

	// con gzip: el cuerpo llega comprimido y se puede descomprimir
	rec := pedir("/app.js", map[string]string{"Accept-Encoding": "gzip"})
	if rec.Header().Get("Content-Encoding") != "gzip" {
		t.Fatalf("app.js deberia ir comprimido, encabezados: %v", rec.Header())
	}
	zr, err := gzip.NewReader(rec.Body)
	if err != nil {
		t.Fatal(err)
	}
	plano, _ := io.ReadAll(zr)
	if !strings.Contains(string(plano), "navegar") {
		t.Error("el app.js descomprimido no se parece al original")
	}

	// sin gzip: igual que siempre
	rec = pedir("/app.js", nil)
	if rec.Header().Get("Content-Encoding") != "" || !strings.Contains(rec.Body.String(), "navegar") {
		t.Error("sin Accept-Encoding no deberia comprimir")
	}

	// cache: con la misma huella, 304 y sin cuerpo
	huella := rec.Header().Get("ETag")
	if huella == "" {
		t.Fatal("app.js deberia tener ETag")
	}
	rec = pedir("/app.js", map[string]string{"If-None-Match": huella, "Accept-Encoding": "gzip"})
	if rec.Code != http.StatusNotModified || rec.Body.Len() != 0 {
		t.Errorf("con la misma huella: %d y %d bytes, se esperaba 304 sin cuerpo", rec.Code, rec.Body.Len())
	}
}
