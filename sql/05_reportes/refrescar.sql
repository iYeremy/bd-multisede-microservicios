-- 05_reportes/refrescar.sql
-- pone los reportes al dia: REFRESH de todas las vistas materializadas,
-- en orden y en una transaccion. ver README.md.
--     psql -U postgres -d andina_reportes -f sql/05_reportes/refrescar.sql

\set ON_ERROR_STOP on

BEGIN;

-- 1. consolidadas
REFRESH MATERIALIZED VIEW reportes.vista_inventario_consolidado;
REFRESH MATERIALIZED VIEW reportes.vista_pedidos_consolidado;
REFRESH MATERIALIZED VIEW reportes.vista_detalle_pedido_consolidado;

-- 2. las que leen las consolidadas o traen datos por dblink
REFRESH MATERIALIZED VIEW reportes.vista_inventario_por_sede;
REFRESH MATERIALIZED VIEW reportes.vista_productos_sin_inventario;
REFRESH MATERIALIZED VIEW reportes.vista_ventas_mensuales_por_sede;
REFRESH MATERIALIZED VIEW reportes.vista_pedidos_pendientes;
REFRESH MATERIALIZED VIEW reportes.vista_saldos_pendientes;
REFRESH MATERIALIZED VIEW reportes.vista_compras_pendientes;
REFRESH MATERIALIZED VIEW reportes.vista_transferencias_en_transito;
REFRESH MATERIALIZED VIEW reportes.vista_devoluciones_por_producto;
REFRESH MATERIALIZED VIEW reportes.vista_reporte_corporativo;

-- 3. alertas (lee vista_inventario_por_sede)
REFRESH MATERIALIZED VIEW reportes.vista_alertas_reabastecimiento;

-- 4. la hora del refresco
REFRESH MATERIALIZED VIEW reportes.vista_ultima_actualizacion;

COMMIT;

SELECT actualizado_en AS reportes_actualizados_en FROM reportes.vista_ultima_actualizacion;
