package catalogo

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Rutas cuelga las rutas del catalogo en el mux.
//
//	publicas (llegan por el gateway, con sesion):
//	  GET /api/catalogo/productos[?estado=ACTIVO]
//	  GET /api/catalogo/clientes
//	  GET /api/catalogo/sedes
//	internas (solo otros servicios, con X-Token-Interno):
//	  GET /interno/productos?ids=1,2,3
//	  GET /interno/clientes?ids=1,2
//	  GET /interno/clientes/{id}
//	  GET /interno/almacenes?ids=1,2
//	  GET /interno/sedes/{id}/almacen-venta
//	  GET /interno/proveedores?ids=1,2
func Rutas(mux *http.ServeMux, db *pgxpool.Pool, cfg plataforma.Config) {
	s := &Servicio{db: db}
	interno := func(h http.HandlerFunc) http.HandlerFunc { return plataforma.SoloInterno(cfg.TokenInterno, h) }

	// quien puede ver que (cada servicio autoriza)
	conRol := func(h http.HandlerFunc, roles ...string) http.HandlerFunc {
		return plataforma.ConRol(func(w http.ResponseWriter, r *http.Request, _ plataforma.Usuario) { h(w, r) }, roles...)
	}
	const (
		admin, ger, inv, com, ven, aud = plataforma.RolAdmin, plataforma.RolGerencia, plataforma.RolInventario,
			plataforma.RolCompras, plataforma.RolVendedor, plataforma.RolAuditor
	)

	mux.HandleFunc("GET /api/catalogo/productos", conRol(s.verProductos, admin, ger, inv, com, ven))
	mux.HandleFunc("GET /api/catalogo/clientes", conRol(s.verClientes, admin, ven))
	mux.HandleFunc("GET /api/catalogo/sedes", conRol(s.verSedes, admin, ger, inv, com, ven, aud))

	mux.HandleFunc("GET /interno/productos", interno(s.productosPorIds))
	mux.HandleFunc("GET /interno/clientes", interno(s.clientesPorIds))
	mux.HandleFunc("GET /interno/clientes/{id}", interno(s.verCliente))
	mux.HandleFunc("GET /interno/almacenes", interno(s.almacenesPorIds))
	mux.HandleFunc("GET /interno/sedes/{id}/almacen-venta", interno(s.almacenVenta))
	mux.HandleFunc("GET /interno/proveedores", interno(s.proveedoresPorIds))
}

func (s *Servicio) verProductos(w http.ResponseWriter, r *http.Request) {
	productos, err := s.Productos(r.Context(), r.URL.Query().Get("estado"))
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, productos)
}

func (s *Servicio) verClientes(w http.ResponseWriter, r *http.Request) {
	clientes, err := s.Clientes(r.Context())
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, clientes)
}

func (s *Servicio) verSedes(w http.ResponseWriter, r *http.Request) {
	sedes, err := s.Sedes(r.Context())
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, sedes)
}

func (s *Servicio) productosPorIds(w http.ResponseWriter, r *http.Request) {
	ids, ok := leerIds(w, r)
	if !ok {
		return
	}
	productos, err := s.ProductosPorIds(r.Context(), ids)
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, productos)
}

func (s *Servicio) proveedoresPorIds(w http.ResponseWriter, r *http.Request) {
	ids, ok := leerIds(w, r)
	if !ok {
		return
	}
	proveedores, err := s.ProveedoresPorIds(r.Context(), ids)
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, proveedores)
}

func (s *Servicio) clientesPorIds(w http.ResponseWriter, r *http.Request) {
	ids, ok := leerIds(w, r)
	if !ok {
		return
	}
	clientes, err := s.ClientesPorIds(r.Context(), ids)
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, clientes)
}

func (s *Servicio) almacenesPorIds(w http.ResponseWriter, r *http.Request) {
	ids, ok := leerIds(w, r)
	if !ok {
		return
	}
	almacenes, err := s.AlmacenesPorIds(r.Context(), ids)
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, almacenes)
}

func (s *Servicio) verCliente(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, "id de cliente invalido")
		return
	}
	c, err := s.Cliente(r.Context(), id)
	if errors.Is(err, ErrNoExiste) {
		plataforma.ResponderError(w, http.StatusNotFound, "el cliente no existe")
		return
	}
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, c)
}

func (s *Servicio) almacenVenta(w http.ResponseWriter, r *http.Request) {
	idSede, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, "id de sede invalido")
		return
	}
	id, err := s.AlmacenVenta(r.Context(), idSede)
	if errors.Is(err, ErrNoExiste) {
		plataforma.ResponderError(w, http.StatusNotFound, "la sede no tiene un almacen activo")
		return
	}
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	plataforma.ResponderJSON(w, http.StatusOK, map[string]int{"id_almacen": id})
}

// leerIds lee ?ids=1,2,3. si viene mal, responde 400 y devuelve ok=false.
func leerIds(w http.ResponseWriter, r *http.Request) ([]int32, bool) {
	texto := r.URL.Query().Get("ids")
	if texto == "" {
		plataforma.ResponderError(w, http.StatusBadRequest, "falta el parametro ids (por ejemplo ?ids=1,2,3)")
		return nil, false
	}
	partes := strings.Split(texto, ",")
	ids := make([]int32, 0, len(partes))
	for _, p := range partes {
		n, err := strconv.ParseInt(strings.TrimSpace(p), 10, 32)
		if err != nil || n <= 0 {
			plataforma.ResponderError(w, http.StatusBadRequest, "ids invalidos: "+p)
			return nil, false
		}
		ids = append(ids, int32(n))
	}
	return ids, true
}
