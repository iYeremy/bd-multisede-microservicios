package gateway

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
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
