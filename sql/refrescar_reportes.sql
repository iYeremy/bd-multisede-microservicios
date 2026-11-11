-- =====================================================================
-- refrescar_reportes.sql
-- pone los reportes al dia: vuelve a calcular todas las vistas
-- materializadas de andina_reportes. cada REFRESH vuelve a traer los
-- datos de las otras bases por dblink y reemplaza el resultado guardado.
--
-- uso (desde cualquier carpeta):
--     psql -U postgres -d andina_reportes -f sql/refrescar_reportes.sql
--
-- para que corra solo cada 5 minutos, una linea en el crontab del
-- servidor (crontab -e):
--     */5 * * * * psql -U postgres -d andina_reportes -f /ruta/del/proyecto/sql/refrescar_reportes.sql
-- "*/5 * * * *" = cada 5 minutos, a toda hora, todos los dias.
--
-- el orden importa: una vista que lee de otra se refresca despues, si
-- no, tomaria los datos viejos de la de abajo.
--   1. las consolidadas (juntan los fragmentos de cada sede)
--   2. las que leen las consolidadas o traen datos por dblink
--   3. alertas, que lee inventario_por_sede
--   4. la hora de la actualizacion, al final
--
-- todo va en una transaccion: o se actualizan todas o ninguna, y nadie
-- ve una mezcla de vistas nuevas y viejas. si una base no responde, el
-- refresco falla entero y los reportes se quedan con lo ultimo bueno.
-- =====================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. consolidadas
REFRESH MATERIALIZED VIEW reportes.vista_inventario_consolidado;
REFRESH MATERIALIZED VIEW reportes.vista_pedidos_consolidado;
REFRESH MATERIALIZED VIEW reportes.vista_detalle_pedido_consolidado;

-- 2. las que leen de las consolidadas o traen datos por dblink
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
