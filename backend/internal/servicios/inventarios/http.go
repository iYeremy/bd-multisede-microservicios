package inventarios

import (
	"context"
	"net/http"
	"strconv"
	"strings"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Rutas cuelga las rutas de inventarios.
//
//	GET /api/inventarios/mi-sede[?bajos=true]   el fragmento de tu sede
//	GET /api/inventarios/transferencias[?estado=DESPACHADA]
func Rutas(mux *http.ServeMux, db *pgxpool.Pool, cfg plataforma.Config) {
	h := &handlers{s: &Servicio{db: db}, cli: plataforma.NuevoClienteInterno(cfg.TokenInterno)}
	roles := []string{plataforma.RolInventario, plataforma.RolAdmin}
	mux.HandleFunc("GET /api/inventarios/mi-sede", plataforma.ConRol(h.miSede, roles...))
	mux.HandleFunc("GET /api/inventarios/transferencias", plataforma.ConRol(h.transferencias, roles...))
}

type handlers struct {
	s   *Servicio
	cli *plataforma.ClienteInterno
}

func (h *handlers) miSede(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	sede, ok := plataforma.SedeDe(r, u)
	tabla, err := Fragmento(sede)
	if !ok || err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, "sede invalida")
		return
	}
	items, err := h.s.Existencias(r.Context(), sede, r.URL.Query().Get("bajos") == "true")
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}

	// los nombres viven en catalogo: se piden todos en UNA llamada. si
	// catalogo no responde, se devuelve igual, con ids y un aviso (degradar)
	ids := make([]int, len(items))
	for i, e := range items {
		ids[i] = e.IDProducto
	}
	nombres, err := h.nombresProductos(r, ids)
	catalogoOK := err == nil
	for i := range items {
		items[i].Producto = nombres[items[i].IDProducto]
	}

	resp := map[string]any{
		"sede": sede, "fragmento": strings.ReplaceAll(tabla, `"`, ""),
		"catalogo_disponible": catalogoOK, "filas": len(items), "existencias": items,
	}
	if !catalogoOK {
		resp["aviso"] = "Catalogo no responde: se muestran los ids de producto sin nombre"
	}
	h.cli.Auditar(r, u, "SELECT", strings.ReplaceAll(tabla, `"`, ""))
	plataforma.ResponderJSON(w, http.StatusOK, resp)
}

func (h *handlers) transferencias(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	ts, err := h.s.Transferencias(r.Context(), r.URL.Query().Get("estado"))
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	ids := []int{}
	for _, t := range ts {
		ids = append(ids, t.AlmacenOrigen, t.AlmacenDestino)
	}
	nombres, err := h.nombresAlmacenes(r, ids)
	for i := range ts {
		ts[i].NombreOrigen = nombres[ts[i].AlmacenOrigen]
		ts[i].NombreDestino = nombres[ts[i].AlmacenDestino]
	}
	resp := map[string]any{"catalogo_disponible": err == nil, "filas": len(ts), "transferencias": ts}
	if err != nil {
		resp["aviso"] = "Catalogo no responde: se muestran los ids de almacen sin nombre"
	}
	plataforma.ResponderJSON(w, http.StatusOK, resp)
}

// lo que este servicio necesita de catalogo. se define aqui su propia
// version de "producto" (solo los campos que usa) en vez de importar el
// codigo de catalogo: asi catalogo puede cambiar por dentro sin romper esto.
type productoCatalogo struct {
	ID     int    `json:"id_producto"`
	Nombre string `json:"nombre"`
}

type almacenCatalogo struct {
	ID     int    `json:"id_almacen"`
	Nombre string `json:"nombre"`
}

func (h *handlers) nombresProductos(r *http.Request, ids []int) (map[int]string, error) {
	var ps []productoCatalogo
	err := h.pedirPorIds(r.Context(), r, "/interno/productos", ids, &ps)
	m := map[int]string{}
	for _, p := range ps {
		m[p.ID] = p.Nombre
	}
	return m, err
}

func (h *handlers) nombresAlmacenes(r *http.Request, ids []int) (map[int]string, error) {
	var as []almacenCatalogo
	err := h.pedirPorIds(r.Context(), r, "/interno/almacenes", ids, &as)
	m := map[int]string{}
	for _, a := range as {
		m[a.ID] = a.Nombre
	}
	return m, err
}

// pedirPorIds arma ?ids=1,2,3 (sin repetidos) y llama a catalogo.
func (h *handlers) pedirPorIds(ctx context.Context, r *http.Request, ruta string, ids []int, destino any) error {
	if len(ids) == 0 {
		return nil
	}
	vistos := map[int]bool{}
	partes := []string{}
	for _, id := range ids {
		if !vistos[id] {
			vistos[id] = true
			partes = append(partes, strconv.Itoa(id))
		}
	}
	return h.cli.Get(ctx, "catalogo", ruta+"?ids="+strings.Join(partes, ","), r.Header.Get(plataforma.HeaderRequestID), destino)
}
