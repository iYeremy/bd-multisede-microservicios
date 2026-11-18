// Package inventarios es el microservicio de inventarios: existencias por
// sede (una tabla por sede: los fragmentos inv_*) y transferencias. lee
// SOLO su base (andina_inventarios) con svc_inventarios.
package inventarios

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// fragmentos: la sede decide la tabla. es la fragmentacion horizontal del
// diseno vista desde el backend: cada sede consulta solo su pedazo.
var fragmentos = map[int]pgx.Identifier{
	1: {"inventarios", "inv_bogota"},
	2: {"inventarios", "inv_medellin"},
	3: {"inventarios", "inv_cali"},
	4: {"inventarios", "inv_cedi"},
}

// ErrSedeInvalida: la sede no tiene fragmento.
var ErrSedeInvalida = errors.New("sede invalida")

// Fragmento devuelve el nombre de la tabla de una sede ("inventarios.inv_cali").
func Fragmento(sede int) (string, error) {
	f, ok := fragmentos[sede]
	if !ok {
		return "", ErrSedeInvalida
	}
	// Sanitize pone comillas: "inventarios"."inv_cali". el nombre solo puede
	// salir de este mapa, nunca de lo que mande el usuario
	return f.Sanitize(), nil
}

// Servicio guarda la conexion a la base de inventarios.
type Servicio struct {
	db *pgxpool.Pool
}

// Existencia es una fila de inventario.
type Existencia struct {
	IDAlmacen          int       `json:"id_almacen"`
	IDProducto         int       `json:"id_producto"`
	Producto           string    `json:"producto,omitempty"` // lo pone catalogo
	ExistenciaActual   int       `json:"existencia_actual"`
	StockMinimo        int       `json:"stock_minimo"`
	BajoMinimo         bool      `json:"bajo_minimo"`
	FechaActualizacion time.Time `json:"fecha_actualizacion"`
}

// Existencias lee el fragmento de una sede. soloBajos: solo lo que esta
// por debajo del stock minimo.
func (s *Servicio) Existencias(ctx context.Context, sede int, soloBajos bool) ([]Existencia, error) {
	tabla, err := Fragmento(sede)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `
		SELECT id_almacen, id_producto, existencia_actual, stock_minimo,
		       existencia_actual < stock_minimo, fecha_actualizacion
		FROM `+tabla+`
		WHERE NOT $1 OR existencia_actual < stock_minimo
		ORDER BY id_almacen, id_producto`, soloBajos)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (Existencia, error) {
		var e Existencia
		err := row.Scan(&e.IDAlmacen, &e.IDProducto, &e.ExistenciaActual, &e.StockMinimo, &e.BajoMinimo, &e.FechaActualizacion)
		return e, err
	})
}

// Transferencia es un traslado entre almacenes, con el total de su detalle.
type Transferencia struct {
	ID               int        `json:"id_transferencia"`
	AlmacenOrigen    int        `json:"id_almacen_origen"`
	AlmacenDestino   int        `json:"id_almacen_destino"`
	NombreOrigen     string     `json:"almacen_origen,omitempty"`  // lo pone catalogo
	NombreDestino    string     `json:"almacen_destino,omitempty"` // lo pone catalogo
	FechaSolicitud   time.Time  `json:"fecha_solicitud"`
	FechaDespacho    *time.Time `json:"fecha_despacho"` // puntero: puede ser NULL
	FechaRecepcion   *time.Time `json:"fecha_recepcion"`
	Estado           string     `json:"estado"`
	Productos        int        `json:"productos"`
	UnidadesEnviadas int        `json:"unidades_enviadas"`
}

// Transferencias devuelve las transferencias (opcional: de un estado).
func (s *Servicio) Transferencias(ctx context.Context, estado string) ([]Transferencia, error) {
	rows, err := s.db.Query(ctx, `
		SELECT t.id_transferencia, t.id_almacen_origen, t.id_almacen_destino,
		       t.fecha_solicitud, t.fecha_despacho, t.fecha_recepcion, t.estado,
		       count(d.id_producto)::int, COALESCE(sum(d.cantidad_enviada), 0)::int
		FROM inventarios.transferencias t
		LEFT JOIN inventarios.detalle_transferencia d ON d.id_transferencia = t.id_transferencia
		WHERE $1 = '' OR t.estado = $1
		GROUP BY t.id_transferencia
		ORDER BY t.fecha_solicitud DESC, t.id_transferencia DESC`, estado)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (Transferencia, error) {
		var t Transferencia
		err := row.Scan(&t.ID, &t.AlmacenOrigen, &t.AlmacenDestino, &t.FechaSolicitud, &t.FechaDespacho,
			&t.FechaRecepcion, &t.Estado, &t.Productos, &t.UnidadesEnviadas)
		return t, err
	})
}
