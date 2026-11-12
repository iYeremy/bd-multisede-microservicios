-- 05_reportes/vistas.sql
-- vistas de reportes (base andina_reportes). ver README.md.
-- son MATERIALIZADAS: guardan el resultado y se actualizan con
-- refrescar.sql. traen los datos de las otras bases con dblink.

CREATE SCHEMA reportes;
COMMENT ON SCHEMA reportes IS 'Microservicio de Reportes Corporativos: vistas materializadas que traen los datos por dblink';

-- a. parametros y vistas que juntan los fragmentos

-- fecha de corte y umbrales (S-14 a S-16). vista normal: son constantes
CREATE VIEW reportes.parametros AS
SELECT DATE '2026-10-15' AS fecha_corte,
       15                AS dias_pedido_antiguo,
       90                AS dias_baja_rotacion;

-- los 4 inventarios en uno. fragmento = de que base y tabla viene cada fila
CREATE MATERIALIZED VIEW reportes.vista_inventario_consolidado AS
SELECT 'andina_inventarios.inv_bogota' AS fragmento, i.*
FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_bogota')
     AS i(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
UNION ALL
SELECT 'andina_inventarios.inv_medellin' AS fragmento, i.*
FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_medellin')
     AS i(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
UNION ALL
SELECT 'andina_inventarios.inv_cali' AS fragmento, i.*
FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_cali')
     AS i(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
UNION ALL
SELECT 'andina_inventarios.inv_cedi' AS fragmento, i.*
FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_cedi')
     AS i(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
WITH NO DATA;

-- lo mismo para pedidos y detalles
CREATE MATERIALIZED VIEW reportes.vista_pedidos_consolidado AS
SELECT 'andina_ventas.ped_bogota' AS fragmento, p.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_bogota')
     AS p(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
UNION ALL
SELECT 'andina_ventas.ped_medellin' AS fragmento, p.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_medellin')
     AS p(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
UNION ALL
SELECT 'andina_ventas.ped_cali' AS fragmento, p.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_cali')
     AS p(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
UNION ALL
SELECT 'andina_ventas.ped_cedi' AS fragmento, p.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_cedi')
     AS p(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
WITH NO DATA;

CREATE MATERIALIZED VIEW reportes.vista_detalle_pedido_consolidado AS
SELECT 'andina_ventas.det_ped_bogota' AS fragmento, d.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_bogota')
     AS d(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
UNION ALL
SELECT 'andina_ventas.det_ped_medellin' AS fragmento, d.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_medellin')
     AS d(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
UNION ALL
SELECT 'andina_ventas.det_ped_cali' AS fragmento, d.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_cali')
     AS d(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
UNION ALL
SELECT 'andina_ventas.det_ped_cedi' AS fragmento, d.*
FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_cedi')
     AS d(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
WITH NO DATA;

-- b. las 10 vistas del enunciado

-- 1. inventario por sede con nombres y valorizacion
CREATE MATERIALIZED VIEW reportes.vista_inventario_por_sede AS
SELECT i.id_sede, s.nombre AS sede,
       i.id_almacen, a.nombre AS almacen,
       p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria,
       i.existencia_actual, i.stock_minimo, p.precio_lista,
       i.existencia_actual * p.precio_lista AS valorizacion_estimada,
       i.fragmento
FROM reportes.vista_inventario_consolidado i
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60)) ON s.id_sede      = i.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre FROM catalogo.almacenes')
         AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60)) ON a.id_almacen   = i.id_almacen
JOIN dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, precio_lista FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, precio_lista NUMERIC(14,2)) ON p.id_producto  = i.id_producto
JOIN dblink('srv_catalogo', 'SELECT id_categoria, nombre FROM catalogo.categorias')
         AS c(id_categoria INTEGER, nombre VARCHAR(60)) ON c.id_categoria = p.id_categoria
WITH NO DATA;

-- 2. existencia en cero o bajo el minimo (RN-18)
CREATE MATERIALIZED VIEW reportes.vista_alertas_reabastecimiento AS
SELECT v.id_sede, v.sede, v.id_almacen, v.almacen, v.id_producto, v.sku, v.producto, v.categoria,
       v.existencia_actual, v.stock_minimo,
       v.stock_minimo - v.existencia_actual AS faltante,
       CASE WHEN v.existencia_actual = 0 THEN 'SIN EXISTENCIA' ELSE 'BAJO MINIMO' END AS nivel_alerta
FROM reportes.vista_inventario_por_sede v
WHERE v.existencia_actual = 0
   OR v.existencia_actual < v.stock_minimo
WITH NO DATA;

-- 3. productos activos sin inventario en una sede
CREATE MATERIALIZED VIEW reportes.vista_productos_sin_inventario AS
SELECT s.id_sede, s.nombre AS sede, p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria
FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, estado FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, estado VARCHAR(15))
JOIN dblink('srv_catalogo', 'SELECT id_categoria, nombre, estado FROM catalogo.categorias')
         AS c(id_categoria INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON c.id_categoria = p.id_categoria
CROSS JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
               AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10))
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (SELECT 1
                  FROM reportes.vista_inventario_consolidado i
                  WHERE i.id_sede = s.id_sede
                    AND i.id_producto = p.id_producto)
WITH NO DATA;

-- 4. ventas confirmadas por sede y mes (RN-29)
CREATE MATERIALIZED VIEW reportes.vista_ventas_mensuales_por_sede AS
SELECT p.id_sede, s.nombre AS sede,
       date_trunc('month', p.fecha_pedido)::date AS mes,
       COUNT(*)                                  AS pedidos,
       SUM(p.total_registrado)                   AS total_vendido
FROM reportes.vista_pedidos_consolidado p
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON s.id_sede = p.id_sede
WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
GROUP BY p.id_sede, s.nombre, date_trunc('month', p.fecha_pedido)
WITH NO DATA;

-- 5. pedidos pendientes y su antiguedad (S-15)
CREATE MATERIALIZED VIEW reportes.vista_pedidos_pendientes AS
SELECT p.id_sede, s.nombre AS sede, p.id_pedido, p.fecha_pedido,
       pr.fecha_corte - p.fecha_pedido AS dias_antiguedad,
       (pr.fecha_corte - p.fecha_pedido) > pr.dias_pedido_antiguo AS es_antiguo,
       p.id_cliente, cl.nombre_completo AS cliente,
       p.id_empleado, e.nombre_completo AS vendedor,
       p.total_registrado
FROM reportes.vista_pedidos_consolidado p
CROSS JOIN reportes.parametros pr
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10))  ON s.id_sede      = p.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_cliente, nombre_completo, estado FROM catalogo.clientes')
         AS cl(id_cliente INTEGER, nombre_completo VARCHAR(120), estado VARCHAR(10)) ON cl.id_cliente  = p.id_cliente
JOIN dblink('srv_identidad', 'SELECT id_empleado, id_sede, nombre_completo, estado FROM identidad.empleados')
         AS e(id_empleado INTEGER, id_sede INTEGER, nombre_completo VARCHAR(120), estado VARCHAR(10))  ON e.id_empleado  = p.id_empleado
WHERE p.estado = 'PENDIENTE'
WITH NO DATA;

-- 6. total menos pagos confirmados (RN-31)
CREATE MATERIALIZED VIEW reportes.vista_saldos_pendientes AS
SELECT p.id_sede, s.nombre AS sede, p.id_pedido, p.fecha_pedido, p.estado,
       p.id_cliente, cl.nombre_completo AS cliente,
       p.total_registrado,
       COALESCE(pg.pagado, 0)                      AS pagos_confirmados,
       p.total_registrado - COALESCE(pg.pagado, 0) AS saldo_pendiente
FROM reportes.vista_pedidos_consolidado p
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10))  ON s.id_sede     = p.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_cliente, nombre_completo, estado FROM catalogo.clientes')
         AS cl(id_cliente INTEGER, nombre_completo VARCHAR(120), estado VARCHAR(10)) ON cl.id_cliente = p.id_cliente
LEFT JOIN (SELECT id_sede, id_pedido, SUM(valor) AS pagado
           FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, valor, estado FROM ventas.pagos')
                    AS pagos(id_sede INTEGER, id_pedido INTEGER, valor NUMERIC(14,2), estado VARCHAR(10))
           WHERE estado = 'CONFIRMADO'
           GROUP BY id_sede, id_pedido) pg
       ON pg.id_sede = p.id_sede AND pg.id_pedido = p.id_pedido
WHERE p.estado <> 'ANULADO'
  AND p.total_registrado - COALESCE(pg.pagado, 0) > 0
WITH NO DATA;

-- 7. solicitado menos recibido, por orden y producto (RN-11)
CREATE MATERIALIZED VIEW reportes.vista_compras_pendientes AS
SELECT oc.id_orden_compra, oc.fecha_orden, oc.fecha_estimada, oc.estado,
       pv.razon_social AS proveedor, a.nombre AS almacen_destino,
       d.id_producto, p.nombre AS producto,
       d.cantidad_solicitada,
       COALESCE(r.recibida, 0)                         AS cantidad_recibida,
       d.cantidad_solicitada - COALESCE(r.recibida, 0) AS cantidad_pendiente
FROM dblink('srv_compras', 'SELECT id_orden_compra, id_proveedor, id_almacen_destino, fecha_orden, fecha_estimada, estado FROM compras.ordenes_compra')
         AS oc(id_orden_compra INTEGER, id_proveedor INTEGER, id_almacen_destino INTEGER, fecha_orden DATE, fecha_estimada DATE, estado VARCHAR(10))
JOIN dblink('srv_compras', 'SELECT id_orden_compra, id_producto, cantidad_solicitada FROM compras.detalle_orden_compra')
         AS d(id_orden_compra INTEGER, id_producto INTEGER, cantidad_solicitada INTEGER) ON d.id_orden_compra = oc.id_orden_compra
JOIN dblink('srv_catalogo', 'SELECT id_proveedor, razon_social, estado FROM catalogo.proveedores')
         AS pv(id_proveedor INTEGER, razon_social VARCHAR(100), estado VARCHAR(10)) ON pv.id_proveedor = oc.id_proveedor
JOIN dblink('srv_catalogo', 'SELECT id_almacen, nombre, estado FROM catalogo.almacenes')
         AS a(id_almacen INTEGER, nombre VARCHAR(60), estado VARCHAR(10))  ON a.id_almacen    = oc.id_almacen_destino
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, estado FROM catalogo.productos')
         AS p(id_producto INTEGER, nombre VARCHAR(100), estado VARCHAR(15))  ON p.id_producto   = d.id_producto
LEFT JOIN (SELECT rc.id_orden_compra, dr.id_producto, SUM(dr.cantidad_recibida) AS recibida
           FROM dblink('srv_compras', 'SELECT id_recepcion, id_orden_compra, estado FROM compras.recepciones_compra')
                    AS rc(id_recepcion INTEGER, id_orden_compra INTEGER, estado VARCHAR(10))
           JOIN dblink('srv_compras', 'SELECT id_recepcion, id_producto, cantidad_recibida FROM compras.detalle_recepcion')
                    AS dr(id_recepcion INTEGER, id_producto INTEGER, cantidad_recibida INTEGER) ON dr.id_recepcion = rc.id_recepcion
           WHERE rc.estado = 'REGISTRADA'
           GROUP BY rc.id_orden_compra, dr.id_producto) r
       ON r.id_orden_compra = d.id_orden_compra AND r.id_producto = d.id_producto
WHERE oc.estado <> 'CANCELADA'
  AND d.cantidad_solicitada > COALESCE(r.recibida, 0)
WITH NO DATA;

-- 8. transferencias despachadas sin recibir (RN-22)
CREATE MATERIALIZED VIEW reportes.vista_transferencias_en_transito AS
SELECT t.id_transferencia,
       ao.nombre AS almacen_origen,  so.nombre AS sede_origen,
       ad.nombre AS almacen_destino, sd.nombre AS sede_destino,
       t.fecha_solicitud, t.fecha_despacho,
       pr.fecha_corte - t.fecha_despacho AS dias_en_transito,
       dt.id_producto, p.nombre AS producto, dt.cantidad_enviada
FROM dblink('srv_inventarios', 'SELECT id_transferencia, id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado FROM inventarios.transferencias')
         AS t(id_transferencia INTEGER, id_almacen_origen INTEGER, id_almacen_destino INTEGER, fecha_solicitud DATE, fecha_despacho DATE, fecha_recepcion DATE, estado VARCHAR(10))
CROSS JOIN reportes.parametros pr
JOIN dblink('srv_inventarios', 'SELECT id_transferencia, id_producto, cantidad_enviada FROM inventarios.detalle_transferencia')
         AS dt(id_transferencia INTEGER, id_producto INTEGER, cantidad_enviada INTEGER) ON dt.id_transferencia = t.id_transferencia
JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, estado FROM catalogo.almacenes')
         AS ao(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON ao.id_almacen = t.id_almacen_origen
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS so(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON so.id_sede    = ao.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, estado FROM catalogo.almacenes')
         AS ad(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON ad.id_almacen = t.id_almacen_destino
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS sd(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON sd.id_sede    = ad.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, estado FROM catalogo.productos')
         AS p(id_producto INTEGER, nombre VARCHAR(100), estado VARCHAR(15))  ON p.id_producto = dt.id_producto
WHERE t.estado = 'DESPACHADA'
  AND t.fecha_recepcion IS NULL
WITH NO DATA;

-- 9. unidades vendidas vs devueltas por producto (RN-34)
CREATE MATERIALIZED VIEW reportes.vista_devoluciones_por_producto AS
WITH vendidas AS (
    SELECT d.id_producto, SUM(d.cantidad) AS unidades_vendidas
    FROM reportes.vista_detalle_pedido_consolidado d
    JOIN reportes.vista_pedidos_consolidado p
      ON p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido
    WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
    GROUP BY d.id_producto
), devueltas AS (
    SELECT dd.id_producto, SUM(dd.cantidad) AS unidades_devueltas
    FROM dblink('srv_ventas', 'SELECT id_devolucion, id_sede, id_pedido, estado FROM ventas.devoluciones')
             AS dv(id_devolucion INTEGER, id_sede INTEGER, id_pedido INTEGER, estado VARCHAR(10))
    JOIN dblink('srv_ventas', 'SELECT id_devolucion, id_producto, cantidad FROM ventas.detalle_devolucion')
             AS dd(id_devolucion INTEGER, id_producto INTEGER, cantidad INTEGER) ON dd.id_devolucion = dv.id_devolucion
    WHERE dv.estado = 'APROBADA'
    GROUP BY dd.id_producto
)
SELECT p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria,
       v.unidades_vendidas,
       COALESCE(dv.unidades_devueltas, 0) AS unidades_devueltas,
       round(100.0 * COALESCE(dv.unidades_devueltas, 0) / v.unidades_vendidas, 2) AS porcentaje_devolucion
FROM vendidas v
JOIN dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, estado FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, estado VARCHAR(15)) ON p.id_producto  = v.id_producto
JOIN dblink('srv_catalogo', 'SELECT id_categoria, nombre, estado FROM catalogo.categorias')
         AS c(id_categoria INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON c.id_categoria = p.id_categoria
LEFT JOIN devueltas dv ON dv.id_producto = v.id_producto
WITH NO DATA;

-- 10. resumen por sede, cada fuente agregada aparte para no duplicar (RN-42)
CREATE MATERIALIZED VIEW reportes.vista_reporte_corporativo AS
WITH inv AS (
    SELECT id_sede,
           COUNT(DISTINCT CASE WHEN existencia_actual > 0 THEN id_producto END) AS productos_con_existencia,
           SUM(existencia_actual)                                           AS unidades_inventario
    FROM reportes.vista_inventario_consolidado
    GROUP BY id_sede
), activos AS (
    SELECT i.id_sede, COUNT(DISTINCT i.id_producto) AS productos_activos
    FROM reportes.vista_inventario_consolidado i
    JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, estado FROM catalogo.productos')
             AS p(id_producto INTEGER, nombre VARCHAR(100), estado VARCHAR(15)) ON p.id_producto = i.id_producto
    WHERE p.estado = 'ACTIVO'
    GROUP BY i.id_sede
), ven AS (
    SELECT id_sede,
           COUNT(CASE WHEN estado IN ('CONFIRMADO', 'ENTREGADO') THEN 1 END)                AS pedidos_vendidos,
           SUM(CASE WHEN estado IN ('CONFIRMADO', 'ENTREGADO') THEN total_registrado END) AS valor_ventas,
           COUNT(CASE WHEN estado = 'PENDIENTE' THEN 1 END)                             AS pedidos_pendientes
    FROM reportes.vista_pedidos_consolidado
    GROUP BY id_sede
), com AS (
    SELECT a.id_sede,
           COUNT(DISTINCT oc.id_orden_compra)                 AS ordenes_compra,
           SUM(d.cantidad_solicitada * d.costo_unitario)      AS valor_compras
    FROM dblink('srv_compras', 'SELECT id_orden_compra, id_almacen_destino, estado FROM compras.ordenes_compra')
             AS oc(id_orden_compra INTEGER, id_almacen_destino INTEGER, estado VARCHAR(10))
    JOIN dblink('srv_compras', 'SELECT id_orden_compra, id_producto, cantidad_solicitada, costo_unitario FROM compras.detalle_orden_compra')
             AS d(id_orden_compra INTEGER, id_producto INTEGER, cantidad_solicitada INTEGER, costo_unitario NUMERIC(14,2)) ON d.id_orden_compra = oc.id_orden_compra
    JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, estado FROM catalogo.almacenes')
             AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON a.id_almacen = oc.id_almacen_destino
    WHERE oc.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tr_sal AS (
    SELECT a.id_sede, COUNT(*) AS transferencias_enviadas
    FROM dblink('srv_inventarios', 'SELECT id_almacen_origen, id_almacen_destino, estado FROM inventarios.transferencias')
             AS t(id_almacen_origen INTEGER, id_almacen_destino INTEGER, estado VARCHAR(10))
    JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, estado FROM catalogo.almacenes')
             AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON a.id_almacen = t.id_almacen_origen
    WHERE t.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tr_ent AS (
    SELECT a.id_sede, COUNT(*) AS transferencias_recibidas
    FROM dblink('srv_inventarios', 'SELECT id_almacen_origen, id_almacen_destino, estado FROM inventarios.transferencias')
             AS t(id_almacen_origen INTEGER, id_almacen_destino INTEGER, estado VARCHAR(10))
    JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, estado FROM catalogo.almacenes')
             AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON a.id_almacen = t.id_almacen_destino
    WHERE t.estado = 'RECIBIDA'
    GROUP BY a.id_sede
)
SELECT s.id_sede, s.nombre AS sede, s.tipo_sede,
       COALESCE(ac.productos_activos, 0)          AS productos_activos,
       COALESCE(inv.productos_con_existencia, 0)  AS productos_con_existencia,
       COALESCE(inv.unidades_inventario, 0)       AS unidades_inventario,
       COALESCE(ven.pedidos_vendidos, 0)          AS pedidos_vendidos,
       COALESCE(ven.valor_ventas, 0)              AS valor_ventas,
       COALESCE(ven.pedidos_pendientes, 0)        AS pedidos_pendientes,
       COALESCE(com.ordenes_compra, 0)            AS ordenes_compra,
       COALESCE(com.valor_compras, 0)             AS valor_compras,
       COALESCE(ts.transferencias_enviadas, 0)    AS transferencias_enviadas,
       COALESCE(te.transferencias_recibidas, 0)   AS transferencias_recibidas
FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, tipo_sede, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), tipo_sede VARCHAR(15), estado VARCHAR(10))
LEFT JOIN activos ac ON ac.id_sede  = s.id_sede
LEFT JOIN inv        ON inv.id_sede = s.id_sede
LEFT JOIN ven        ON ven.id_sede = s.id_sede
LEFT JOIN com        ON com.id_sede = s.id_sede
LEFT JOIN tr_sal ts  ON ts.id_sede  = s.id_sede
LEFT JOIN tr_ent te  ON te.id_sede  = s.id_sede
WITH NO DATA;

-- procedencia de cada vista (seccion 6 del enunciado)
COMMENT ON MATERIALIZED VIEW reportes.vista_inventario_consolidado      IS 'UNION ALL de los fragmentos de andina_inventarios: inv_bogota, inv_medellin, inv_cali, inv_cedi';
COMMENT ON MATERIALIZED VIEW reportes.vista_pedidos_consolidado         IS 'UNION ALL de los fragmentos de andina_ventas: ped_bogota, ped_medellin, ped_cali, ped_cedi';
COMMENT ON MATERIALIZED VIEW reportes.vista_detalle_pedido_consolidado  IS 'UNION ALL de los fragmentos de andina_ventas: det_ped_bogota, det_ped_medellin, det_ped_cali, det_ped_cedi';
COMMENT ON MATERIALIZED VIEW reportes.vista_inventario_por_sede         IS 'Fuentes: fragmentos de inventarios + catalogo';
COMMENT ON MATERIALIZED VIEW reportes.vista_alertas_reabastecimiento    IS 'Fuentes: fragmentos de inventarios + catalogo';
COMMENT ON MATERIALIZED VIEW reportes.vista_productos_sin_inventario    IS 'Fuentes: catalogo + fragmentos de inventarios';
COMMENT ON MATERIALIZED VIEW reportes.vista_ventas_mensuales_por_sede   IS 'Fuentes: fragmentos de ventas + catalogo';
COMMENT ON MATERIALIZED VIEW reportes.vista_pedidos_pendientes          IS 'Fuentes: fragmentos de ventas + catalogo + identidad';
COMMENT ON MATERIALIZED VIEW reportes.vista_saldos_pendientes           IS 'Fuentes: fragmentos de ventas + ventas.pagos + catalogo';
COMMENT ON MATERIALIZED VIEW reportes.vista_compras_pendientes          IS 'Fuentes: compras + catalogo';
COMMENT ON MATERIALIZED VIEW reportes.vista_transferencias_en_transito  IS 'Fuentes: inventarios.transferencias + catalogo';
COMMENT ON MATERIALIZED VIEW reportes.vista_devoluciones_por_producto   IS 'Fuentes: fragmentos de ventas + ventas.devoluciones + catalogo';
COMMENT ON MATERIALIZED VIEW reportes.vista_reporte_corporativo         IS 'Fuentes: todos los microservicios, agregados por separado';

-- c. hora del ultimo refresco
CREATE MATERIALIZED VIEW reportes.vista_ultima_actualizacion AS
SELECT now() AS actualizado_en
WITH NO DATA;

COMMENT ON MATERIALIZED VIEW reportes.vista_ultima_actualizacion IS 'Hora del ultimo REFRESH de los reportes';
