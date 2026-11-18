package plataforma

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

// httptest permite probar un handler sin levantar un servidor de verdad:
// NewRequest arma la peticion y NewRecorder guarda la respuesta.
func TestConRol(t *testing.T) {
	h := ConRol(func(w http.ResponseWriter, r *http.Request, u Usuario) {
		w.WriteHeader(http.StatusOK)
	}, RolVendedor)

	casos := []struct {
		nombre string
		rol    string // vacio = sin encabezados (no paso por el gateway)
		codigo int
	}{
		{"sin sesion", "", http.StatusUnauthorized},
		{"rol permitido", RolVendedor, http.StatusOK},
		{"otro rol", RolGerencia, http.StatusForbidden},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			r := httptest.NewRequest("GET", "/x", nil)
			if c.rol != "" {
				r.Header.Set(HeaderUsuarioID, "1")
				r.Header.Set(HeaderUsuarioEmpleado, "1")
				r.Header.Set(HeaderUsuarioSede, "3")
				r.Header.Set(HeaderUsuarioRol, c.rol)
			}
			w := httptest.NewRecorder()
			h(w, r)
			if w.Code != c.codigo {
				t.Errorf("codigo %d, se esperaba %d", w.Code, c.codigo)
			}
		})
	}
}

func TestSedeDe(t *testing.T) {
	r := httptest.NewRequest("GET", "/x?sede=1", nil)
	if s, _ := SedeDe(r, Usuario{Rol: RolVendedor, Sede: 3}); s != 3 {
		t.Errorf("un vendedor de cali no puede pedir otra sede: dio %d", s)
	}
	if s, _ := SedeDe(r, Usuario{Rol: RolAdmin, Sede: 3}); s != 1 {
		t.Errorf("el admin si puede: dio %d", s)
	}
}
