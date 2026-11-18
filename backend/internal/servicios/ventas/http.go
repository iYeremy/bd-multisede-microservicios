package ventas

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"sync"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Rutas cuelga las rutas de ventas.
//
//	GET  /api/ventas/pedidos[?estado=PENDIENTE]   los ultimos pedidos de tu sede
//	GET  /api/ventas/pedidos/{id}                 un pedido con sus productos
//	POST /api/ventas/pedidos                      crear un pedido (VENDEDOR)
//	     {"id_cliente": 5, "productos": [{"id_producto": 1, "cantidad": 3}]}
func Rutas(mux *http.ServeMux, db *pgxpool.Pool, cfg plataforma.Config) {
	h := &handlers{s: &Servicio{db: db}, cli: plataforma.NuevoClienteInterno(cfg.TokenInterno)}
	leer := []string{plataforma.RolVendedor, plataforma.RolAdmin}
	mux.HandleFunc("GET /api/ventas/pedidos", plataforma.ConRol(h.pedidos, leer...))
	mux.HandleFunc("GET /api/ventas/pedidos/{id}", plataforma.ConRol(h.detalle, leer...))
	mux.HandleFunc("POST /api/ventas/pedidos", plataforma.ConRol(h.crear, plataforma.RolVendedor))
}

type handlers struct {
	s   *Servicio
	cli *plataforma.ClienteInterno
}

// lo que ventas necesita de catalogo (sus propias versiones, ver inventarios)
type productoCatalogo struct {
	ID             int    `json:"id_producto"`
	Nombre         string `json:"nombre"`
	PrecioCentavos int64  `json:"precio_centavos"`
	Estado         string `json:"estado"`
}

type clienteCatalogo struct {
	ID     int    `json:"id_cliente"`
	Nombre string `json:"nombre_completo"`
	Estado string `json:"estado"`
}

func (h *handlers) pedidos(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	sede, ok := plataforma.SedeDe(r, u)
	if !ok {
		plataforma.ResponderError(w, http.StatusBadRequest, "sede invalida")
		return
	}
	lista, err := h.s.Pedidos(r.Context(), sede, r.URL.Query().Get("estado"), 100)
	if errors.Is(err, ErrSedeInvalida) {
		plataforma.ResponderError(w, http.StatusBadRequest, "sede invalida")
		return
	}
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	ids := make([]int, len(lista))
	for i, p := range lista {
		ids[i] = p.IDCliente
	}
	var clientes []clienteCatalogo
	errCat := h.porIds(r, "/interno/clientes", ids, &clientes)
	nombres := map[int]string{}
	for _, c := range clientes {
		nombres[c.ID] = c.Nombre
	}
	for i := range lista {
		lista[i].Cliente = nombres[lista[i].IDCliente]
	}
	resp := map[string]any{"sede": sede, "fragmento": NombreFragmento(sede), "catalogo_disponible": errCat == nil,
		"filas": len(lista), "pedidos": lista}
	if errCat != nil {
		resp["aviso"] = "Catalogo no responde: se muestran los ids de cliente sin nombre"
	}
	h.cli.Auditar(r, u, "SELECT", NombreFragmento(sede))
	plataforma.ResponderJSON(w, http.StatusOK, resp)
}

func (h *handlers) detalle(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	sede, ok := plataforma.SedeDe(r, u)
	id, err := strconv.Atoi(r.PathValue("id"))
	if !ok || err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, "sede o id invalido")
		return
	}
	p, lineas, err := h.s.Detalle(r.Context(), sede, id)
	switch {
	case errors.Is(err, ErrNoExiste):
		// un vendedor de cali no "ve" los pedidos de bogota: para el, no existen
		plataforma.ResponderError(w, http.StatusNotFound, "el pedido no existe en "+NombreFragmento(sede))
		return
	case errors.Is(err, ErrSedeInvalida):
		plataforma.ResponderError(w, http.StatusBadRequest, "sede invalida")
		return
	case err != nil:
		plataforma.ErrorDB(w, r, err)
		return
	}
	ids := make([]int, len(lineas))
	for i, l := range lineas {
		ids[i] = l.IDProducto
	}
	var productos []productoCatalogo
	errCat := h.porIds(r, "/interno/productos", ids, &productos)
	nombres := map[int]string{}
	for _, pr := range productos {
		nombres[pr.ID] = pr.Nombre
	}
	for i := range lineas {
		lineas[i].Producto = nombres[lineas[i].IDProducto]
	}
	plataforma.ResponderJSON(w, http.StatusOK, map[string]any{
		"fragmento": NombreFragmento(sede), "pedido": p, "lineas": lineas, "catalogo_disponible": errCat == nil,
	})
}

// solicitudPedido es lo que manda el navegador.
type solicitudPedido struct {
	IDCliente int `json:"id_cliente"`
	Productos []struct {
		IDProducto int `json:"id_producto"`
		Cantidad   int `json:"cantidad"`
	} `json:"productos"`
}

// validar revisa la solicitud sin tocar ningun otro servicio.
func (sp solicitudPedido) validar() error {
	if sp.IDCliente <= 0 {
		return errors.New("falta id_cliente")
	}
	if len(sp.Productos) == 0 || len(sp.Productos) > 50 {
		return errors.New("el pedido debe tener entre 1 y 50 productos")
	}
	vistos := map[int]bool{}
	for _, p := range sp.Productos {
		if p.IDProducto <= 0 || p.Cantidad <= 0 || p.Cantidad > 10000 {
			return fmt.Errorf("producto %d: cantidad invalida (%d)", p.IDProducto, p.Cantidad)
		}
		if vistos[p.IDProducto] {
			return fmt.Errorf("el producto %d esta repetido", p.IDProducto)
		}
		vistos[p.IDProducto] = true
	}
	return nil
}

// crear es el flujo principal: valida, le pregunta a catalogo, guarda en
// el fragmento de la sede y registra la auditoria.
func (h *handlers) crear(w http.ResponseWriter, r *http.Request, u plataforma.Usuario) {
	// 1. leer y validar lo que mando el navegador
	var sp solicitudPedido
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10)).Decode(&sp); err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, "json invalido")
		return
	}
	if err := sp.validar(); err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, err.Error())
		return
	}
	// la sede sale de la sesion, nunca del navegador
	sede := u.Sede
	if _, err := fragmentoDe(sede); err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, "tu usuario no tiene una sede valida")
		return
	}

	// 2. preguntarle a catalogo tres cosas A LA VEZ (cada una en su goroutine):
	//    el cliente, los productos con su precio, y el almacen de venta de la sede
	cat, err := h.consultarCatalogo(r, sp, sede)
	var caido plataforma.ErrServicioCaido
	if errors.As(err, &caido) {
		plataforma.ResponderError(w, http.StatusServiceUnavailable, "Catalogo no disponible: no se creo el pedido")
		return
	}
	if err != nil {
		plataforma.ResponderError(w, http.StatusBadRequest, err.Error())
		return
	}

	// 3. armar las lineas con el precio de lista de HOY (precio historico)
	precios := map[int]productoCatalogo{}
	for _, p := range cat.productos {
		precios[p.ID] = p
	}
	np := NuevoPedido{Sede: sede, Almacen: cat.almacen, Cliente: sp.IDCliente, Empleado: u.Empleado}
	for _, sol := range sp.Productos {
		p, ok := precios[sol.IDProducto]
		if !ok {
			plataforma.ResponderError(w, http.StatusBadRequest, fmt.Sprintf("el producto %d no existe", sol.IDProducto))
			return
		}
		if p.Estado != "ACTIVO" {
			plataforma.ResponderError(w, http.StatusBadRequest, fmt.Sprintf("el producto %d (%s) esta %s", p.ID, p.Nombre, p.Estado))
			return
		}
		np.Lineas = append(np.Lineas, Linea{IDProducto: p.ID, Producto: p.Nombre, Cantidad: sol.Cantidad,
			PrecioUnitarioCentavos: p.PrecioCentavos, SubtotalCentavos: int64(sol.Cantidad) * p.PrecioCentavos})
	}

	// 4. guardar (una transaccion en ped_<sede> + det_ped_<sede>)
	pedido, err := h.s.Crear(r.Context(), np)
	if err != nil {
		plataforma.ErrorDB(w, r, err)
		return
	}
	pedido.Cliente = cat.cliente.Nombre

	// 5. auditoria (en segundo plano: si falla, el pedido igual queda)
	h.cli.Auditar(r, u, "INSERT", NombreFragmento(sede))

	plataforma.ResponderJSON(w, http.StatusCreated, map[string]any{
		"fragmento": NombreFragmento(sede), "pedido": pedido, "lineas": np.Lineas,
	})
}

type datosCatalogo struct {
	cliente   clienteCatalogo
	productos []productoCatalogo
	almacen   int
}

// consultarCatalogo hace las tres llamadas en paralelo y espera las tres
// (sync.WaitGroup). asi tarda lo que la mas lenta, no la suma de las tres.
func (h *handlers) consultarCatalogo(r *http.Request, sp solicitudPedido, sede int) (datosCatalogo, error) {
	reqID := r.Header.Get(plataforma.HeaderRequestID)
	ids := make([]int, len(sp.Productos))
	for i, p := range sp.Productos {
		ids[i] = p.IDProducto
	}
	var d datosCatalogo
	var almacen struct {
		ID int `json:"id_almacen"`
	}
	var errCliente, errProductos, errAlmacen error
	ctx := r.Context()

	var wg sync.WaitGroup
	wg.Add(3)
	go func() {
		defer wg.Done()
		errCliente = h.cli.Get(ctx, "catalogo", fmt.Sprintf("/interno/clientes/%d", sp.IDCliente), reqID, &d.cliente)
	}()
	go func() {
		defer wg.Done()
		errProductos = h.cli.Get(ctx, "catalogo", "/interno/productos?ids="+unirIds(ids), reqID, &d.productos)
	}()
	go func() {
		defer wg.Done()
		errAlmacen = h.cli.Get(ctx, "catalogo", fmt.Sprintf("/interno/sedes/%d/almacen-venta", sede), reqID, &almacen)
	}()
	wg.Wait()
	d.almacen = almacen.ID

	// si catalogo esta caido, eso manda (503); si no, el primer error de datos
	for _, err := range []error{errCliente, errProductos, errAlmacen} {
		var caido plataforma.ErrServicioCaido
		if errors.As(err, &caido) {
			return d, err
		}
	}
	var resp plataforma.ErrRespuesta
	if errors.As(errCliente, &resp) && resp.Codigo == http.StatusNotFound {
		return d, fmt.Errorf("el cliente %d no existe", sp.IDCliente)
	}
	if err := errors.Join(errCliente, errProductos, errAlmacen); err != nil {
		return d, err
	}
	if d.cliente.Estado != "ACTIVO" {
		return d, fmt.Errorf("el cliente %d esta %s", d.cliente.ID, d.cliente.Estado)
	}
	return d, nil
}

// porIds pide a catalogo una lista por ids. si no hay ids, no llama.
func (h *handlers) porIds(r *http.Request, ruta string, ids []int, destino any) error {
	if len(ids) == 0 {
		return nil
	}
	return h.cli.Get(r.Context(), "catalogo", ruta+"?ids="+unirIds(ids), r.Header.Get(plataforma.HeaderRequestID), destino)
}

// unirIds arma "1,2,3" sin repetidos.
func unirIds(ids []int) string {
	vistos := map[int]bool{}
	partes := []string{}
	for _, id := range ids {
		if !vistos[id] {
			vistos[id] = true
			partes = append(partes, strconv.Itoa(id))
		}
	}
	return strings.Join(partes, ",")
}
