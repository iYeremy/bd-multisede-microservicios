// Package catalogo es el microservicio de Catalogo y Terceros. lee SOLO
// su base (andina_catalogo) con el usuario svc_catalogo. los demas
// servicios le piden datos por http (rutas /interno/...).
package catalogo

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Servicio guarda la conexion a la base del catalogo.
type Servicio struct {
	db *pgxpool.Pool
}

// ErrNoExiste se devuelve cuando el registro buscado no esta.
var ErrNoExiste = errors.New("no existe")

// Producto es un producto del catalogo. el precio va en centavos (int64)
// para no tener errores de redondeo: 4800.00 pesos = 480000 centavos.
type Producto struct {
	ID             int    `json:"id_producto"`
	SKU            string `json:"sku"`
	Nombre         string `json:"nombre"`
	Categoria      string `json:"categoria"`
	UnidadMedida   string `json:"unidad_medida"`
	PrecioCentavos int64  `json:"precio_centavos"`
	Estado         string `json:"estado"`
}

// columnas comunes de las consultas de productos. (precio * 100)::bigint
// pasa el NUMERIC(14,2) a centavos enteros.
const selectProductos = `
	SELECT p.id_producto, p.sku, p.nombre, c.nombre, p.unidad_medida,
	       (p.precio_lista * 100)::bigint, p.estado
	FROM catalogo.productos p
	JOIN catalogo.categorias c ON c.id_categoria = p.id_categoria`

func escanearProductos(rows pgx.Rows) ([]Producto, error) {
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (Producto, error) {
		var p Producto
		err := row.Scan(&p.ID, &p.SKU, &p.Nombre, &p.Categoria, &p.UnidadMedida, &p.PrecioCentavos, &p.Estado)
		return p, err
	})
}

// Productos devuelve todos los productos, o solo los de un estado (ACTIVO...).
// los valores siempre van como parametros ($1): nunca se pega texto del
// usuario dentro del sql, asi no hay inyeccion sql.
func (s *Servicio) Productos(ctx context.Context, estado string) ([]Producto, error) {
	rows, err := s.db.Query(ctx, selectProductos+`
		WHERE $1 = '' OR p.estado = $1
		ORDER BY p.id_producto`, estado)
	if err != nil {
		return nil, err
	}
	return escanearProductos(rows)
}

// ProductosPorIds devuelve los productos de una lista de ids, en una sola
// consulta (= ANY($1) compara contra todos los de la lista).
func (s *Servicio) ProductosPorIds(ctx context.Context, ids []int32) ([]Producto, error) {
	rows, err := s.db.Query(ctx, selectProductos+`
		WHERE p.id_producto = ANY($1)
		ORDER BY p.id_producto`, ids)
	if err != nil {
		return nil, err
	}
	return escanearProductos(rows)
}

// Cliente es un cliente de la empresa.
type Cliente struct {
	ID             int     `json:"id_cliente"`
	TipoDocumento  string  `json:"tipo_documento"`
	NumDocumento   string  `json:"num_documento"`
	NombreCompleto string  `json:"nombre_completo"`
	Correo         *string `json:"correo"` // puntero: puede ser NULL
	Estado         string  `json:"estado"`
}

const selectClientes = `
	SELECT id_cliente, tipo_documento, num_documento, nombre_completo, correo, estado
	FROM catalogo.clientes`

func escanearCliente(row pgx.CollectableRow) (Cliente, error) {
	var c Cliente
	err := row.Scan(&c.ID, &c.TipoDocumento, &c.NumDocumento, &c.NombreCompleto, &c.Correo, &c.Estado)
	return c, err
}

// Clientes devuelve todos los clientes.
func (s *Servicio) Clientes(ctx context.Context) ([]Cliente, error) {
	rows, err := s.db.Query(ctx, selectClientes+` ORDER BY id_cliente`)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, escanearCliente)
}

// ClientesPorIds devuelve los clientes de una lista de ids.
func (s *Servicio) ClientesPorIds(ctx context.Context, ids []int32) ([]Cliente, error) {
	rows, err := s.db.Query(ctx, selectClientes+` WHERE id_cliente = ANY($1) ORDER BY id_cliente`, ids)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, escanearCliente)
}

// Cliente devuelve un cliente por su id, o ErrNoExiste.
func (s *Servicio) Cliente(ctx context.Context, id int) (Cliente, error) {
	rows, err := s.db.Query(ctx, selectClientes+` WHERE id_cliente = $1`, id)
	if err != nil {
		return Cliente{}, err
	}
	c, err := pgx.CollectExactlyOneRow(rows, escanearCliente)
	if errors.Is(err, pgx.ErrNoRows) {
		return Cliente{}, ErrNoExiste
	}
	return c, err
}

// Sede es una sede de la empresa.
type Sede struct {
	ID       int    `json:"id_sede"`
	Nombre   string `json:"nombre"`
	Ciudad   string `json:"ciudad"`
	TipoSede string `json:"tipo_sede"`
	Estado   string `json:"estado"`
}

// Sedes devuelve las 4 sedes.
func (s *Servicio) Sedes(ctx context.Context) ([]Sede, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id_sede, nombre, ciudad, tipo_sede, estado
		FROM catalogo.sedes ORDER BY id_sede`)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByPos[Sede])
}

// AlmacenVenta devuelve el almacen desde el que vende una sede: el activo
// de menor id (en el CEDI es el 4, la bodega general).
func (s *Servicio) AlmacenVenta(ctx context.Context, idSede int) (int, error) {
	var id int
	err := s.db.QueryRow(ctx, `
		SELECT id_almacen FROM catalogo.almacenes
		WHERE id_sede = $1 AND estado = 'ACTIVO'
		ORDER BY id_almacen LIMIT 1`, idSede).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrNoExiste
	}
	return id, err
}

// Proveedor es un proveedor (solo lo que necesitan los otros servicios).
type Proveedor struct {
	ID          int    `json:"id_proveedor"`
	RazonSocial string `json:"razon_social"`
	Estado      string `json:"estado"`
}

// ProveedoresPorIds devuelve los proveedores de una lista de ids.
func (s *Servicio) ProveedoresPorIds(ctx context.Context, ids []int32) ([]Proveedor, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id_proveedor, razon_social, estado
		FROM catalogo.proveedores
		WHERE id_proveedor = ANY($1)
		ORDER BY id_proveedor`, ids)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByPos[Proveedor])
}

// Almacen es un almacen de una sede.
type Almacen struct {
	ID     int    `json:"id_almacen"`
	Nombre string `json:"nombre"`
	IDSede int    `json:"id_sede"`
	Estado string `json:"estado"`
}

// AlmacenesPorIds devuelve los almacenes de una lista de ids.
func (s *Servicio) AlmacenesPorIds(ctx context.Context, ids []int32) ([]Almacen, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id_almacen, nombre, id_sede, estado
		FROM catalogo.almacenes
		WHERE id_almacen = ANY($1)
		ORDER BY id_almacen`, ids)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByPos[Almacen])
}
