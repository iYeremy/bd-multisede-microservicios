-- =====================================================================
-- etl/transformar.sql
-- ETL, paso T (transformar): recalcula las vistas materializadas de
-- reportes con lo que hay ahora en el staging. se corre conectado a
-- andina_reportes, despues de cargar.sql.
--
-- REFRESH MATERIALIZED VIEW vuelve a ejecutar la consulta de la vista y
-- reemplaza el resultado guardado. una vista materializada no cambia
-- sola: solo cambia aqui.
--
-- el orden importa: una vista que lee de otra se refresca despues, si
-- no, tomaria los datos viejos de la de abajo.
--   1. las consolidadas (juntan los fragmentos)
--   2. las que leen las consolidadas o el staging
--   3. alertas, que lee inventario_por_sede
--
-- todo va en una transaccion: los reportes se actualizan todos juntos y
-- nadie ve una mezcla de vistas nuevas y viejas. mientras corre, las
-- vistas quedan bloqueadas para leer un momento (con estos datos es
-- casi nada).
-- =====================================================================

BEGIN;

-- 1. consolidadas
REFRESH MATERIALIZED VIEW reportes.vista_inventario_consolidado;
REFRESH MATERIALIZED VIEW reportes.vista_pedidos_consolidado;
REFRESH MATERIALIZED VIEW reportes.vista_detalle_pedido_consolidado;

-- 2. las que leen de las consolidadas o directo del staging
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

COMMIT;
