// Package compras es el microservicio de compras: ordenes de compra y sus
// recepciones. lee SOLO su base (andina_compras) con svc_compras.
package compras

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Servicio guarda la conexion a la base de compras.
type Servicio struct {
	db *pgxpool.Pool
}

// ErrNoExiste: la orden no existe.
var ErrNoExiste = errors.New("no existe")

// Orden es una orden de compra con sus totales.
type Orden struct {
	ID             int       `json:"id_orden_compra"`
	IDProveedor    int       `json:"id_proveedor"`
	Proveedor      string    `json:"proveedor,omitempty"` // lo pone catalogo
	AlmacenDestino int       `json:"id_almacen_destino"`
	IDEmpleado     int       `json:"id_empleado"`
	FechaOrden     time.Time `json:"fecha_orden"`
	FechaEstimada  time.Time `json:"fecha_estimada"`
	Estado         string    `json:"estado"`
	Productos      int       `json:"productos"`
	TotalCentavos  int64     `json:"total_centavos"`
}

// Ordenes devuelve las ordenes (opcional: de un estado), con cuantos
// productos tienen y cuanto suman (cantidad x costo).
func (s *Servicio) Ordenes(ctx context.Context, estado string) ([]Orden, error) {
	rows, err := s.db.Query(ctx, `
		SELECT o.id_orden_compra, o.id_proveedor, o.id_almacen_destino, o.id_empleado,
		       o.fecha_orden, o.fecha_estimada, o.estado,
		       count(d.id_producto)::int,
		       COALESCE(sum(d.cantidad_solicitada * d.costo_unitario) * 100, 0)::bigint
		FROM compras.ordenes_compra o
		LEFT JOIN compras.detalle_orden_compra d ON d.id_orden_compra = o.id_orden_compra
		WHERE $1 = '' OR o.estado = $1
		GROUP BY o.id_orden_compra
		ORDER BY o.fecha_orden DESC, o.id_orden_compra DESC`, estado)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (Orden, error) {
		var o Orden
		err := row.Scan(&o.ID, &o.IDProveedor, &o.AlmacenDestino, &o.IDEmpleado, &o.FechaOrden,
			&o.FechaEstimada, &o.Estado, &o.Productos, &o.TotalCentavos)
		return o, err
	})
}

// Linea es un producto de una orden: lo pedido y lo que ya llego.
type Linea struct {
	IDProducto            int    `json:"id_producto"`
	Producto              string `json:"producto,omitempty"` // lo pone catalogo
	CantidadSolicitada    int    `json:"cantidad_solicitada"`
	CantidadRecibida      int    `json:"cantidad_recibida"`
	CantidadPendiente     int    `json:"cantidad_pendiente"`
	CostoUnitarioCentavos int64  `json:"costo_unitario_centavos"`
}

// Detalle devuelve una orden y sus lineas. lo recibido suma solo las
// recepciones REGISTRADAS (las ANULADAS no cuentan).
func (s *Servicio) Detalle(ctx context.Context, id int) (Orden, []Linea, error) {
	ordenes, err := s.ordenPorID(ctx, id)
	if err != nil {
		return Orden{}, nil, err
	}
	rows, err := s.db.Query(ctx, `
		SELECT d.id_producto, d.cantidad_solicitada,
		       COALESCE(r.recibida, 0)::int,
		       (d.costo_unitario * 100)::bigint
		FROM compras.detalle_orden_compra d
		LEFT JOIN (
		    SELECT dr.id_producto, sum(dr.cantidad_recibida) AS recibida
		    FROM compras.recepciones_compra rc
		    JOIN compras.detalle_recepcion dr ON dr.id_recepcion = rc.id_recepcion
		    WHERE rc.id_orden_compra = $1 AND rc.estado = 'REGISTRADA'
		    GROUP BY dr.id_producto
		) r ON r.id_producto = d.id_producto
		WHERE d.id_orden_compra = $1
		ORDER BY d.id_producto`, id)
	if err != nil {
		return Orden{}, nil, err
	}
	lineas, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (Linea, error) {
		var l Linea
		err := row.Scan(&l.IDProducto, &l.CantidadSolicitada, &l.CantidadRecibida, &l.CostoUnitarioCentavos)
		l.CantidadPendiente = max(l.CantidadSolicitada-l.CantidadRecibida, 0)
		return l, err
	})
	return ordenes, lineas, err
}

func (s *Servicio) ordenPorID(ctx context.Context, id int) (Orden, error) {
	var o Orden
	err := s.db.QueryRow(ctx, `
		SELECT o.id_orden_compra, o.id_proveedor, o.id_almacen_destino, o.id_empleado,
		       o.fecha_orden, o.fecha_estimada, o.estado,
		       (SELECT count(*) FROM compras.detalle_orden_compra d WHERE d.id_orden_compra = o.id_orden_compra)::int,
		       (SELECT COALESCE(sum(d.cantidad_solicitada * d.costo_unitario) * 100, 0)
		        FROM compras.detalle_orden_compra d WHERE d.id_orden_compra = o.id_orden_compra)::bigint
		FROM compras.ordenes_compra o
		WHERE o.id_orden_compra = $1`, id).
		Scan(&o.ID, &o.IDProveedor, &o.AlmacenDestino, &o.IDEmpleado, &o.FechaOrden,
			&o.FechaEstimada, &o.Estado, &o.Productos, &o.TotalCentavos)
	if errors.Is(err, pgx.ErrNoRows) {
		return o, ErrNoExiste
	}
	return o, err
}
