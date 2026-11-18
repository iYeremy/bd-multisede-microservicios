// Package reportes es el microservicio de reportes corporativos. lee SOLO
// su base (andina_reportes) con svc_reportes. sus vistas materializadas
// traen los datos de las otras instancias con dblink, dentro de postgresql:
// este servicio solo las lee y las refresca cada cierto tiempo.
package reportes

import (
	"context"
	"fmt"
	"log/slog"
	"slices"
	"sync"
	"time"

	"github.com/iYeremy/bd-multisede-microservicios/backend/internal/plataforma"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Vista es una vista de la lista blanca: solo estas se pueden pedir.
type Vista struct {
	Nombre      string   `json:"nombre"`
	Descripcion string   `json:"descripcion"`
	PorSede     bool     `json:"por_sede"` // tiene columna id_sede: se puede filtrar por sede
	roles       []string // ademas de GERENCIA, AUDITOR y ADMINISTRADOR, que ven todas
}

var (
	inv = []string{plataforma.RolInventario}
	com = []string{plataforma.RolCompras}
)

// las mismas reglas que sql/06_roles/reportes.sql
var vistas = []Vista{
	{"vista_reporte_corporativo", "Resumen por sede: inventario, ventas, compras y transferencias", true, nil},
	{"vista_inventario_por_sede", "Existencias por sede y almacen, con valorizacion", true, nil},
	{"vista_alertas_reabastecimiento", "Productos por debajo del stock minimo", true, inv},
	{"vista_productos_sin_inventario", "Productos activos que una sede no tiene", true, inv},
	{"vista_transferencias_en_transito", "Transferencias despachadas que no han llegado", false, inv},
	{"vista_ventas_mensuales_por_sede", "Pedidos y total vendido por mes", true, nil},
	{"vista_pedidos_pendientes", "Pedidos pendientes y su antiguedad", true, nil},
	{"vista_saldos_pendientes", "Pedidos con saldo por pagar", true, nil},
	{"vista_compras_pendientes", "Ordenes de compra con unidades por recibir", false, com},
	{"vista_devoluciones_por_producto", "Unidades vendidas y devueltas por producto", false, nil},
	{"vista_inventario_consolidado", "UNION ALL de los 4 fragmentos de inventario", true, nil},
	{"vista_pedidos_consolidado", "UNION ALL de los 4 fragmentos de pedidos", true, nil},
	{"vista_detalle_pedido_consolidado", "UNION ALL de los 4 fragmentos de detalle de pedido", true, nil},
}

// los que ven todas las vistas
var rolesCorporativos = []string{plataforma.RolGerencia, plataforma.RolAuditor, plataforma.RolAdmin}

func buscarVista(nombre string) (Vista, bool) {
	i := slices.IndexFunc(vistas, func(v Vista) bool { return v.Nombre == nombre })
	if i < 0 {
		return Vista{}, false
	}
	return vistas[i], true
}

func (v Vista) puedeVer(rol string) bool {
	return slices.Contains(rolesCorporativos, rol) || slices.Contains(v.roles, rol)
}

// el orden del refresco: primero las consolidadas, porque otras las leen.
// es el mismo de sql/05_reportes/refrescar.sql
var ordenRefresco = []string{
	"vista_inventario_consolidado", "vista_pedidos_consolidado", "vista_detalle_pedido_consolidado",
	"vista_inventario_por_sede", "vista_productos_sin_inventario", "vista_ventas_mensuales_por_sede",
	"vista_pedidos_pendientes", "vista_saldos_pendientes", "vista_compras_pendientes",
	"vista_transferencias_en_transito", "vista_devoluciones_por_producto", "vista_reporte_corporativo",
	"vista_alertas_reabastecimiento",
	"vista_ultima_actualizacion",
}

// Servicio guarda la conexion y un candado para no refrescar dos veces a la vez.
type Servicio struct {
	db          *pgxpool.Pool
	refrescando sync.Mutex
}

// ErrOcupado: ya hay un refresco en curso.
var ErrOcupado = fmt.Errorf("ya se estan refrescando los reportes")

// Refrescar corre los REFRESH en orden, en UNA transaccion: si una
// instancia no responde, se revierte todo y quedan los datos anteriores
// (nunca quedan unas vistas nuevas y otras viejas).
func (s *Servicio) Refrescar(ctx context.Context) (time.Duration, error) {
	if !s.refrescando.TryLock() {
		return 0, ErrOcupado
	}
	defer s.refrescando.Unlock()

	inicio := time.Now()
	err := pgx.BeginFunc(ctx, s.db, func(tx pgx.Tx) error {
		for _, v := range ordenRefresco {
			sql := "REFRESH MATERIALIZED VIEW " + pgx.Identifier{"reportes", v}.Sanitize()
			if _, err := tx.Exec(ctx, sql); err != nil {
				return fmt.Errorf("%s: %w", v, err)
			}
		}
		return nil
	})
	return time.Since(inicio), err
}

// RefrescarCada refresca los reportes cada intervalo, hasta que ctx termine.
func (s *Servicio) RefrescarCada(ctx context.Context, intervalo time.Duration) {
	t := time.NewTicker(intervalo)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			// cada vuelta con su propio limite de tiempo
			c, cancel := context.WithTimeout(ctx, 2*time.Minute)
			dur, err := s.Refrescar(c)
			cancel()
			if err != nil {
				slog.Error("fallo el refresco automatico; quedan los datos anteriores", "error", err)
				continue
			}
			slog.Info("reportes refrescados", "duracion", dur.Round(time.Millisecond))
		}
	}
}

// UltimaActualizacion es la hora del ultimo REFRESH.
func (s *Servicio) UltimaActualizacion(ctx context.Context) (time.Time, error) {
	var t time.Time
	err := s.db.QueryRow(ctx, `SELECT actualizado_en FROM reportes.vista_ultima_actualizacion`).Scan(&t)
	return t, err
}

// Leer devuelve las filas de una vista como una lista de mapas
// {columna: valor}: asi una sola funcion sirve para las 13 vistas, sin un
// struct por vista. sede = 0 significa todas las sedes.
func (s *Servicio) Leer(ctx context.Context, v Vista, sede, limite int) ([]map[string]any, error) {
	// el nombre de la tabla NO puede ir como $1 (los parametros son solo
	// para valores). por eso sale de la lista blanca y se escapa con Sanitize
	sql := "SELECT * FROM " + pgx.Identifier{"reportes", v.Nombre}.Sanitize()
	args := []any{}
	if v.PorSede && sede > 0 {
		sql += " WHERE id_sede = $1"
		args = append(args, sede)
	}
	// las vistas materializadas no garantizan orden: se ordena por las primeras columnas
	sql += fmt.Sprintf(" ORDER BY 1, 2, 3 LIMIT %d", limite) // limite es un int: no hay inyeccion posible

	rows, err := s.db.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToMap)
}
