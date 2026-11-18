package compras

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Rutas cuelga las rutas de compras.
//
//	GET /api/compras/ordenes[?estado=EMITIDA]
//	GET /api/compras/ordenes/{id}             la orden con lo pedido y lo recibido
func Rutas(mux *http.ServeMux, db *pgxpool.Pool, cfg plataforma.Config) {
	h := &handlers{s: &Servicio{db: db}, cli: plataforma.NuevoClienteInterno(cfg.TokenInterno)}
	roles := []string{plataforma.RolCompras, plataforma.RolAdmin}
	mux.HandleFunc("GET /api/compras/ordenes", plataforma.ConRol(h.ordenes, roles...))
	mux.HandleFunc("GET /api/compras/ordenes/{id}", plataforma.ConRol(h.detalle, roles...))
}

type handlers struct {
	s   *Servicio
	cli *plataforma.ClienteInterno
}

func (h *handlers) ordenes(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	lista, err := h.s.Ordenes(r.Context(), r.URL.Query().Get("estado"))
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	ids := make([]int, len(lista))
	for i, o := range lista {
		ids[i] = o.IDProveedor
	}
	nombres, err := h.nombres(r, "/interno/proveedores", "id_proveedor", "razon_social", ids)
	for i := range lista {
		lista[i].Proveedor = nombres[lista[i].IDProveedor]
	}
	resp := map[string]any{"catalogo_disponible": err == nil, "filas": len(lista), "ordenes": lista}
	if err != nil {
		resp["aviso"] = "Catalogo no responde: se muestran los ids de proveedor sin nombre"
	}
	h.cli.Auditar(r, u, "SELECT", "compras.ordenes_compra")
	plataforma.ResponderJSON(w, http.StatusOK, resp)
}

func (h *handlers) detalle(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, "id de orden invalido")
		return
	}
	o, lineas, err := h.s.Detalle(r.Context(), id)
	if errors.Is(err, ErrNoExiste) {
		plataforma.ResponderError(w, http.StatusNotFound, "la orden no existe")
		return
	}
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	ids := []int{}
	for _, l := range lineas {
		ids = append(ids, l.IDProducto)
	}
	productos, err1 := h.nombres(r, "/interno/productos", "id_producto", "nombre", ids)
	for i := range lineas {
		lineas[i].Producto = productos[lineas[i].IDProducto]
	}
	proveedores, err2 := h.nombres(r, "/interno/proveedores", "id_proveedor", "razon_social", []int{o.IDProveedor})
	o.Proveedor = proveedores[o.IDProveedor]

	resp := map[string]any{"orden": o, "lineas": lineas, "catalogo_disponible": err1 == nil && err2 == nil}
	plataforma.ResponderJSON(w, http.StatusOK, resp)
}

// nombres pide a catalogo una lista por ids y arma un mapa id -> nombre.
// recibe el nombre de los campos porque proveedores y productos los llaman
// distinto. usa map[string]any: solo necesitamos dos campos de cada fila.
func (h *handlers) nombres(r *http.Request, ruta, campoID, campoNombre string, ids []int) (map[int]string, error) {
	m := map[int]string{}
	if len(ids) == 0 {
		return m, nil
	}
	vistos := map[int]bool{}
	partes := []string{}
	for _, id := range ids {
		if !vistos[id] {
			vistos[id] = true
			partes = append(partes, strconv.Itoa(id))
		}
	}
	var filas []map[string]any
	err := h.cli.Get(r.Context(), "catalogo", ruta+"?ids="+strings.Join(partes, ","),
		r.Header.Get(plataforma.HeaderRequestID), &filas)
	for _, f := range filas {
		// los numeros de json llegan como float64
		if id, ok := f[campoID].(float64); ok {
			m[int(id)], _ = f[campoNombre].(string)
		}
	}
	return m, err
}
