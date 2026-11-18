package plataforma

import (
	"net/http"
	"slices"
	"strconv"
)

// encabezados que pone el gateway despues de validar la sesion. el gateway
// borra los que vengan del navegador, asi que si llegan aqui son confiables.
const (
	HeaderUsuarioID       = "X-Usuario-Id"
	HeaderUsuarioRol      = "X-Usuario-Rol"
	HeaderUsuarioEmpleado = "X-Usuario-Empleado"
	HeaderUsuarioSede     = "X-Usuario-Sede"
)

// roles de la aplicacion (columna identidad.usuarios.rol)
const (
	RolAdmin      = "ADMINISTRADOR"
	RolGerencia   = "GERENCIA"
	RolInventario = "INVENTARIO"
	RolCompras    = "COMPRAS"
	RolVendedor   = "VENDEDOR"
	RolAuditor    = "AUDITOR"
)

// Usuario es quien hace la peticion, segun la sesion.
type Usuario struct {
	ID       int    `json:"id_usuario"`
	Nombre   string `json:"nombre_usuario"`
	Rol      string `json:"rol"`
	Empleado int    `json:"id_empleado"`
	Sede     int    `json:"id_sede"`
}

// UsuarioDe lee el usuario de los encabezados que puso el gateway.
// ok es false si no vienen (la peticion no paso por el gateway).
func UsuarioDe(r *http.Request) (Usuario, bool) {
	id, err1 := strconv.Atoi(r.Header.Get(HeaderUsuarioID))
	emp, err2 := strconv.Atoi(r.Header.Get(HeaderUsuarioEmpleado))
	sede, err3 := strconv.Atoi(r.Header.Get(HeaderUsuarioSede))
	rol := r.Header.Get(HeaderUsuarioRol)
	if err1 != nil || err2 != nil || err3 != nil || rol == "" {
		return Usuario{}, false
	}
	return Usuario{ID: id, Rol: rol, Empleado: emp, Sede: sede}, true
}

// Handler que ademas recibe al usuario de la sesion.
type HandlerConUsuario func(w http.ResponseWriter, r *http.Request, u Usuario)

// ConRol protege una ruta: solo entran los roles de la lista. el gateway
// autentica (quien eres) y cada servicio autoriza (que puedes hacer).
//
//	mux.HandleFunc("GET /api/ventas/pedidos", plataforma.ConRol(s.verPedidos, RolVendedor, RolAdmin))
func ConRol(h HandlerConUsuario, roles ...string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		u, ok := UsuarioDe(r)
		if !ok {
			ResponderError(w, http.StatusUnauthorized, "Inicia sesion primero")
			return
		}
		if !slices.Contains(roles, u.Rol) {
			ResponderError(w, http.StatusForbidden, "Tu rol ("+u.Rol+") no puede hacer esto")
			return
		}
		h(w, r, u)
	}
}

// SedeDe decide de que sede se consulta. la sede SIEMPRE sale de la sesion;
// solo el administrador puede pedir otra con ?sede=N (para revisar todas).
func SedeDe(r *http.Request, u Usuario) (int, bool) {
	if u.Rol == RolAdmin {
		if s := r.URL.Query().Get("sede"); s != "" {
			n, err := strconv.Atoi(s)
			return n, err == nil
		}
	}
	return u.Sede, true
}
