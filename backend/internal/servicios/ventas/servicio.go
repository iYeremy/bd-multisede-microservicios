// Package ventas es el microservicio de ventas: pedidos por sede (tablas
// ped_* y det_ped_*, una por sede), pagos y devoluciones. lee y escribe
// SOLO su base (andina_ventas) con svc_ventas.
package ventas

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// fragmento es el par de tablas de una sede: encabezado y detalle.
type fragmento struct {
	pedidos, detalle pgx.Identifier
}

var fragmentos = map[int]fragmento{
	1: {pgx.Identifier{"ventas", "ped_bogota"}, pgx.Identifier{"ventas", "det_ped_bogota"}},
	2: {pgx.Identifier{"ventas", "ped_medellin"}, pgx.Identifier{"ventas", "det_ped_medellin"}},
	3: {pgx.Identifier{"ventas", "ped_cali"}, pgx.Identifier{"ventas", "det_ped_cali"}},
	4: {pgx.Identifier{"ventas", "ped_cedi"}, pgx.Identifier{"ventas", "det_ped_cedi"}},
}

var (
	// ErrSedeInvalida: la sede no tiene fragmento.
	ErrSedeInvalida = errors.New("sede invalida")
	// ErrNoExiste: el pedido no existe en el fragmento de la sede.
	ErrNoExiste = errors.New("no existe")
)

func fragmentoDe(sede int) (fragmento, error) {
	f, ok := fragmentos[sede]
	if !ok {
		return fragmento{}, ErrSedeInvalida
	}
	return f, nil
}

// NombreFragmento devuelve "ventas.ped_cali", para mostrarlo.
func NombreFragmento(sede int) string {
	f, ok := fragmentos[sede]
	if !ok {
		return ""
	}
	return f.pedidos[0] + "." + f.pedidos[1]
}

// Servicio guarda la conexion a la base de ventas.
type Servicio struct {
	db *pgxpool.Pool
}

// Pedido es el encabezado de un pedido.
type Pedido struct {
	IDSede        int       `json:"id_sede"`
	IDPedido      int       `json:"id_pedido"`
	IDAlmacen     int       `json:"id_almacen"`
	IDCliente     int       `json:"id_cliente"`
	Cliente       string    `json:"cliente,omitempty"` // lo pone catalogo
	IDEmpleado    int       `json:"id_empleado"`
	FechaPedido   time.Time `json:"fecha_pedido"`
	Estado        string    `json:"estado"`
	TotalCentavos int64     `json:"total_centavos"`
}

const columnasPedido = `id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado,
	(total_registrado * 100)::bigint`

func escanearPedido(row pgx.CollectableRow) (Pedido, error) {
	var p Pedido
	err := row.Scan(&p.IDSede, &p.IDPedido, &p.IDAlmacen, &p.IDCliente, &p.IDEmpleado, &p.FechaPedido, &p.Estado, &p.TotalCentavos)
	return p, err
}

// Pedidos devuelve los ultimos pedidos del fragmento de una sede.
func (s *Servicio) Pedidos(ctx context.Context, sede int, estado string, limite int) ([]Pedido, error) {
	f, err := fragmentoDe(sede)
	if err != nil {
		return nil, err
	}
	rows, err := s.db.Query(ctx, `
		SELECT `+columnasPedido+`
		FROM `+f.pedidos.Sanitize()+`
		WHERE $1 = '' OR estado = $1
		ORDER BY fecha_pedido DESC, id_pedido DESC
		LIMIT $2`, estado, limite)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, escanearPedido)
}

// Linea es un producto de un pedido. precio_unitario es el precio del
// momento de la venta (precio historico): si despues cambia el precio de
// lista, el pedido no cambia.
type Linea struct {
	IDProducto             int    `json:"id_producto"`
	Producto               string `json:"producto,omitempty"` // lo pone catalogo
	Cantidad               int    `json:"cantidad"`
	PrecioUnitarioCentavos int64  `json:"precio_unitario_centavos"`
	SubtotalCentavos       int64  `json:"subtotal_centavos"`
}

// Detalle devuelve un pedido de la sede con sus lineas.
func (s *Servicio) Detalle(ctx context.Context, sede, id int) (Pedido, []Linea, error) {
	f, err := fragmentoDe(sede)
	if err != nil {
		return Pedido{}, nil, err
	}
	rows, err := s.db.Query(ctx, `SELECT `+columnasPedido+` FROM `+f.pedidos.Sanitize()+` WHERE id_pedido = $1`, id)
	if err != nil {
		return Pedido{}, nil, err
	}
	p, err := pgx.CollectExactlyOneRow(rows, escanearPedido)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, nil, ErrNoExiste
	}
	if err != nil {
		return p, nil, err
	}

	rows, err = s.db.Query(ctx, `
		SELECT id_producto, cantidad, (precio_unitario * 100)::bigint
		FROM `+f.detalle.Sanitize()+`
		WHERE id_pedido = $1
		ORDER BY id_producto`, id)
	if err != nil {
		return p, nil, err
	}
	lineas, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (Linea, error) {
		var l Linea
		err := row.Scan(&l.IDProducto, &l.Cantidad, &l.PrecioUnitarioCentavos)
		l.SubtotalCentavos = int64(l.Cantidad) * l.PrecioUnitarioCentavos
		return l, err
	})
	return p, lineas, err
}

// NuevoPedido es lo que hace falta para guardar un pedido, ya validado.
type NuevoPedido struct {
	Sede, Almacen, Cliente, Empleado int
	Lineas                           []Linea // con el precio de catalogo ya puesto
}

// Crear guarda el encabezado y todas las lineas en UNA transaccion: o se
// guarda todo, o nada (no pueden quedar pedidos sin detalle).
func (s *Servicio) Crear(ctx context.Context, np NuevoPedido) (Pedido, error) {
	f, err := fragmentoDe(np.Sede)
	if err != nil {
		return Pedido{}, err
	}
	var total int64
	for _, l := range np.Lineas {
		total += int64(l.Cantidad) * l.PrecioUnitarioCentavos
	}

	var p Pedido
	err = pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		// id_pedido lo genera la tabla (GENERATED ALWAYS AS IDENTITY), y cada
		// fragmento lleva su propia cuenta. RETURNING lo devuelve sin otra consulta
		// los centavos se pasan a pesos dentro de sql: $5::numeric / 100 es exacto
		err := tx.QueryRow(ctx, `
			INSERT INTO `+f.pedidos.Sanitize()+`
			       (id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, total_registrado)
			VALUES ($1, $2, $3, $4, CURRENT_DATE, $5::numeric / 100)
			RETURNING `+columnasPedido,
			np.Sede, np.Almacen, np.Cliente, np.Empleado, total).
			Scan(&p.IDSede, &p.IDPedido, &p.IDAlmacen, &p.IDCliente, &p.IDEmpleado, &p.FechaPedido, &p.Estado, &p.TotalCentavos)
		if err != nil {
			return err
		}
		// las lineas van en un Batch: pgx manda todos los INSERT en UN solo
		// viaje a la base, en vez de uno por linea. con la base lejos (neon)
		// cada viaje cuesta ~150 ms, asi que esto importa
		lote := &pgx.Batch{}
		for _, l := range np.Lineas {
			lote.Queue(`
				INSERT INTO `+f.detalle.Sanitize()+` (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
				VALUES ($1, $2, $3, $4, $5::numeric / 100)`,
				np.Sede, p.IDPedido, l.IDProducto, l.Cantidad, l.PrecioUnitarioCentavos)
		}
		// Close lee todas las respuestas y devuelve el primer error
		return tx.SendBatch(ctx, lote).Close() // error: ROLLBACK; nil: COMMIT
	})
	return p, err
}
