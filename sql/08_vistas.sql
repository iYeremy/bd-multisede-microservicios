-- =====================================================================
-- 08_vistas.sql
-- Microservicio de Reportes Corporativos: solo vistas de solo lectura.
--
-- Bloque A: parámetros y vistas de unificación de fragmentos (UNION ALL).
-- Bloque B: las 10 vistas obligatorias del enunciado.
--
-- Las vistas que tienen columna id_sede sirven tanto para uso local
-- (WHERE id_sede = n) como para consulta consolidada (todas las sedes).
-- =====================================================================

-- ---------------------------------------------------------------------
-- A. Parámetros y unificación de fragmentos
-- ---------------------------------------------------------------------

-- Fecha de corte y umbrales usados por todas las consultas (S-14, S-15, S-16)
CREATE VIEW reportes.parametros AS
SELECT DATE '2026-10-15' AS fecha_corte,
       15                AS dias_pedido_antiguo,
       90                AS dias_baja_rotacion;

-- Une los 4 fragmentos de inventario. La columna fragmento indica de qué
-- tabla física proviene cada fila.
CREATE VIEW reportes.vista_inventario_consolidado AS
SELECT 'inventarios.inv_bogota'   AS fragmento, i.* FROM inventarios.inv_bogota   i
UNION ALL
SELECT 'inventarios.inv_medellin' AS fragmento, i.* FROM inventarios.inv_medellin i
UNION ALL
SELECT 'inventarios.inv_cali'     AS fragmento, i.* FROM inventarios.inv_cali     i
UNION ALL
SELECT 'inventarios.inv_cedi'     AS fragmento, i.* FROM inventarios.inv_cedi     i;

CREATE VIEW reportes.vista_pedidos_consolidado AS
SELECT 'ventas.ped_bogota'   AS fragmento, p.* FROM ventas.ped_bogota   p
UNION ALL
SELECT 'ventas.ped_medellin' AS fragmento, p.* FROM ventas.ped_medellin p
UNION ALL
SELECT 'ventas.ped_cali'     AS fragmento, p.* FROM ventas.ped_cali     p
UNION ALL
SELECT 'ventas.ped_cedi'     AS fragmento, p.* FROM ventas.ped_cedi     p;

CREATE VIEW reportes.vista_detalle_pedido_consolidado AS
SELECT 'ventas.det_ped_bogota'   AS fragmento, d.* FROM ventas.det_ped_bogota   d
UNION ALL
SELECT 'ventas.det_ped_medellin' AS fragmento, d.* FROM ventas.det_ped_medellin d
UNION ALL
SELECT 'ventas.det_ped_cali'     AS fragmento, d.* FROM ventas.det_ped_cali     d
UNION ALL
SELECT 'ventas.det_ped_cedi'     AS fragmento, d.* FROM ventas.det_ped_cedi     d;

-- ---------------------------------------------------------------------
-- B. Vistas obligatorias
-- ---------------------------------------------------------------------

-- 1. Inventario por sede (fuentes: fragmentos de inventarios + catálogo)
CREATE VIEW reportes.vista_inventario_por_sede AS
SELECT i.id_sede, s.nombre AS sede,
       i.id_almacen, a.nombre AS almacen,
       p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria,
       i.existencia_actual, i.stock_minimo, p.precio_lista,
       i.existencia_actual * p.precio_lista AS valorizacion_estimada,
       i.fragmento
FROM reportes.vista_inventario_consolidado i
JOIN catalogo.sedes      s ON s.id_sede      = i.id_sede
JOIN catalogo.almacenes  a ON a.id_almacen   = i.id_almacen
JOIN catalogo.productos  p ON p.id_producto  = i.id_producto
JOIN catalogo.categorias c ON c.id_categoria = p.id_categoria;

-- 2. Alertas de reabastecimiento: existencia cero o bajo el mínimo (RN-18)
CREATE VIEW reportes.vista_alertas_reabastecimiento AS
SELECT v.id_sede, v.sede, v.id_almacen, v.almacen, v.id_producto, v.sku, v.producto, v.categoria,
       v.existencia_actual, v.stock_minimo,
       v.stock_minimo - v.existencia_actual AS faltante,
       CASE WHEN v.existencia_actual = 0 THEN 'SIN EXISTENCIA' ELSE 'BAJO MINIMO' END AS nivel_alerta
FROM reportes.vista_inventario_por_sede v
WHERE v.existencia_actual = 0
   OR v.existencia_actual < v.stock_minimo;

-- 3. Productos activos sin registro de inventario en una sede
CREATE VIEW reportes.vista_productos_sin_inventario AS
SELECT s.id_sede, s.nombre AS sede, p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria
FROM catalogo.productos p
JOIN catalogo.categorias c ON c.id_categoria = p.id_categoria
CROSS JOIN catalogo.sedes s
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (SELECT 1
                  FROM reportes.vista_inventario_consolidado i
                  WHERE i.id_sede = s.id_sede
                    AND i.id_producto = p.id_producto);

-- 4. Ventas confirmadas (CONFIRMADO o ENTREGADO, RN-29) por sede y mes
CREATE VIEW reportes.vista_ventas_mensuales_por_sede AS
SELECT p.id_sede, s.nombre AS sede,
       date_trunc('month', p.fecha_pedido)::date AS mes,
       COUNT(*)                                  AS pedidos,
       SUM(p.total_registrado)                   AS total_vendido
FROM reportes.vista_pedidos_consolidado p
JOIN catalogo.sedes s ON s.id_sede = p.id_sede
WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
GROUP BY p.id_sede, s.nombre, date_trunc('month', p.fecha_pedido);

-- 5. Pedidos pendientes con su antigüedad respecto de la fecha de corte
CREATE VIEW reportes.vista_pedidos_pendientes AS
SELECT p.id_sede, s.nombre AS sede, p.id_pedido, p.fecha_pedido,
       pr.fecha_corte - p.fecha_pedido AS dias_antiguedad,
       (pr.fecha_corte - p.fecha_pedido) > pr.dias_pedido_antiguo AS es_antiguo,
       p.id_cliente, cl.nombre_completo AS cliente,
       p.id_empleado, e.nombre_completo AS vendedor,
       p.total_registrado
FROM reportes.vista_pedidos_consolidado p
CROSS JOIN reportes.parametros pr
JOIN catalogo.sedes      s  ON s.id_sede      = p.id_sede
JOIN catalogo.clientes   cl ON cl.id_cliente  = p.id_cliente
JOIN identidad.empleados e  ON e.id_empleado  = p.id_empleado
WHERE p.estado = 'PENDIENTE';

-- 6. Saldos pendientes: total registrado menos pagos confirmados (RN-31)
CREATE VIEW reportes.vista_saldos_pendientes AS
SELECT p.id_sede, s.nombre AS sede, p.id_pedido, p.fecha_pedido, p.estado,
       p.id_cliente, cl.nombre_completo AS cliente,
       p.total_registrado,
       COALESCE(pg.pagado, 0)                      AS pagos_confirmados,
       p.total_registrado - COALESCE(pg.pagado, 0) AS saldo_pendiente
FROM reportes.vista_pedidos_consolidado p
JOIN catalogo.sedes    s  ON s.id_sede     = p.id_sede
JOIN catalogo.clientes cl ON cl.id_cliente = p.id_cliente
LEFT JOIN (SELECT id_sede, id_pedido, SUM(valor) AS pagado
           FROM ventas.pagos
           WHERE estado = 'CONFIRMADO'
           GROUP BY id_sede, id_pedido) pg
       ON pg.id_sede = p.id_sede AND pg.id_pedido = p.id_pedido
WHERE p.estado <> 'ANULADO'
  AND p.total_registrado - COALESCE(pg.pagado, 0) > 0;

-- 7. Compras pendientes de recibir por orden y producto
CREATE VIEW reportes.vista_compras_pendientes AS
SELECT oc.id_orden_compra, oc.fecha_orden, oc.fecha_estimada, oc.estado,
       pv.razon_social AS proveedor, a.nombre AS almacen_destino,
       d.id_producto, p.nombre AS producto,
       d.cantidad_solicitada,
       COALESCE(r.recibida, 0)                         AS cantidad_recibida,
       d.cantidad_solicitada - COALESCE(r.recibida, 0) AS cantidad_pendiente
FROM compras.ordenes_compra oc
JOIN compras.detalle_orden_compra d ON d.id_orden_compra = oc.id_orden_compra
JOIN catalogo.proveedores pv ON pv.id_proveedor = oc.id_proveedor
JOIN catalogo.almacenes   a  ON a.id_almacen    = oc.id_almacen_destino
JOIN catalogo.productos   p  ON p.id_producto   = d.id_producto
LEFT JOIN (SELECT rc.id_orden_compra, dr.id_producto, SUM(dr.cantidad_recibida) AS recibida
           FROM compras.recepciones_compra rc
           JOIN compras.detalle_recepcion dr ON dr.id_recepcion = rc.id_recepcion
           WHERE rc.estado = 'REGISTRADA'
           GROUP BY rc.id_orden_compra, dr.id_producto) r
       ON r.id_orden_compra = d.id_orden_compra AND r.id_producto = d.id_producto
WHERE oc.estado <> 'CANCELADA'
  AND d.cantidad_solicitada > COALESCE(r.recibida, 0);

-- 8. Transferencias despachadas y aún no recibidas (RN-22)
CREATE VIEW reportes.vista_transferencias_en_transito AS
SELECT t.id_transferencia,
       ao.nombre AS almacen_origen,  so.nombre AS sede_origen,
       ad.nombre AS almacen_destino, sd.nombre AS sede_destino,
       t.fecha_solicitud, t.fecha_despacho,
       pr.fecha_corte - t.fecha_despacho AS dias_en_transito,
       dt.id_producto, p.nombre AS producto, dt.cantidad_enviada
FROM inventarios.transferencias t
CROSS JOIN reportes.parametros pr
JOIN inventarios.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN catalogo.almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN catalogo.sedes     so ON so.id_sede    = ao.id_sede
JOIN catalogo.almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN catalogo.sedes     sd ON sd.id_sede    = ad.id_sede
JOIN catalogo.productos p  ON p.id_producto = dt.id_producto
WHERE t.estado = 'DESPACHADA'
  AND t.fecha_recepcion IS NULL;

-- 9. Devoluciones aprobadas frente a unidades vendidas, por producto
CREATE VIEW reportes.vista_devoluciones_por_producto AS
WITH vendidas AS (
    SELECT d.id_producto, SUM(d.cantidad) AS unidades_vendidas
    FROM reportes.vista_detalle_pedido_consolidado d
    JOIN reportes.vista_pedidos_consolidado p
      ON p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido
    WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
    GROUP BY d.id_producto
), devueltas AS (
    SELECT dd.id_producto, SUM(dd.cantidad) AS unidades_devueltas
    FROM ventas.devoluciones dv
    JOIN ventas.detalle_devolucion dd ON dd.id_devolucion = dv.id_devolucion
    WHERE dv.estado = 'APROBADA'
    GROUP BY dd.id_producto
)
SELECT p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria,
       v.unidades_vendidas,
       COALESCE(dv.unidades_devueltas, 0) AS unidades_devueltas,
       round(100.0 * COALESCE(dv.unidades_devueltas, 0) / v.unidades_vendidas, 2) AS porcentaje_devolucion
FROM vendidas v
JOIN catalogo.productos  p ON p.id_producto  = v.id_producto
JOIN catalogo.categorias c ON c.id_categoria = p.id_categoria
LEFT JOIN devueltas dv ON dv.id_producto = v.id_producto;

-- 10. Reporte corporativo por sede. Cada fuente se agrega por separado en
--     su propia CTE y luego se une por id_sede, para no duplicar cifras
--     por relaciones uno a muchos (RN-42).
--     Fuentes: catalogo, fragmentos de inventarios y ventas, compras e
--     inventarios.transferencias.
CREATE VIEW reportes.vista_reporte_corporativo AS
WITH inv AS (
    SELECT id_sede,
           COUNT(DISTINCT id_producto) FILTER (WHERE existencia_actual > 0) AS productos_con_existencia,
           SUM(existencia_actual)                                           AS unidades_inventario
    FROM reportes.vista_inventario_consolidado
    GROUP BY id_sede
), activos AS (
    SELECT i.id_sede, COUNT(DISTINCT i.id_producto) AS productos_activos
    FROM reportes.vista_inventario_consolidado i
    JOIN catalogo.productos p ON p.id_producto = i.id_producto
    WHERE p.estado = 'ACTIVO'
    GROUP BY i.id_sede
), ven AS (
    SELECT id_sede,
           COUNT(*)              FILTER (WHERE estado IN ('CONFIRMADO', 'ENTREGADO')) AS pedidos_vendidos,
           SUM(total_registrado) FILTER (WHERE estado IN ('CONFIRMADO', 'ENTREGADO')) AS valor_ventas,
           COUNT(*)              FILTER (WHERE estado = 'PENDIENTE')                  AS pedidos_pendientes
    FROM reportes.vista_pedidos_consolidado
    GROUP BY id_sede
), com AS (
    SELECT a.id_sede,
           COUNT(DISTINCT oc.id_orden_compra)                 AS ordenes_compra,
           SUM(d.cantidad_solicitada * d.costo_unitario)      AS valor_compras
    FROM compras.ordenes_compra oc
    JOIN compras.detalle_orden_compra d ON d.id_orden_compra = oc.id_orden_compra
    JOIN catalogo.almacenes a ON a.id_almacen = oc.id_almacen_destino
    WHERE oc.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tr_sal AS (
    SELECT a.id_sede, COUNT(*) AS transferencias_enviadas
    FROM inventarios.transferencias t
    JOIN catalogo.almacenes a ON a.id_almacen = t.id_almacen_origen
    WHERE t.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tr_ent AS (
    SELECT a.id_sede, COUNT(*) AS transferencias_recibidas
    FROM inventarios.transferencias t
    JOIN catalogo.almacenes a ON a.id_almacen = t.id_almacen_destino
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
FROM catalogo.sedes s
LEFT JOIN activos ac ON ac.id_sede  = s.id_sede
LEFT JOIN inv        ON inv.id_sede = s.id_sede
LEFT JOIN ven        ON ven.id_sede = s.id_sede
LEFT JOIN com        ON com.id_sede = s.id_sede
LEFT JOIN tr_sal ts  ON ts.id_sede  = s.id_sede
LEFT JOIN tr_ent te  ON te.id_sede  = s.id_sede;

COMMENT ON VIEW reportes.vista_inventario_consolidado      IS 'UNION ALL de inv_bogota, inv_medellin, inv_cali, inv_cedi';
COMMENT ON VIEW reportes.vista_pedidos_consolidado         IS 'UNION ALL de ped_bogota, ped_medellin, ped_cali, ped_cedi';
COMMENT ON VIEW reportes.vista_detalle_pedido_consolidado  IS 'UNION ALL de det_ped_bogota, det_ped_medellin, det_ped_cali, det_ped_cedi';
COMMENT ON VIEW reportes.vista_inventario_por_sede         IS 'Fuentes: fragmentos de inventarios + catalogo';
COMMENT ON VIEW reportes.vista_alertas_reabastecimiento    IS 'Fuentes: fragmentos de inventarios + catalogo';
COMMENT ON VIEW reportes.vista_productos_sin_inventario    IS 'Fuentes: catalogo + fragmentos de inventarios';
COMMENT ON VIEW reportes.vista_ventas_mensuales_por_sede   IS 'Fuentes: fragmentos de ventas + catalogo';
COMMENT ON VIEW reportes.vista_pedidos_pendientes          IS 'Fuentes: fragmentos de ventas + catalogo + identidad';
COMMENT ON VIEW reportes.vista_saldos_pendientes           IS 'Fuentes: fragmentos de ventas + ventas.pagos + catalogo';
COMMENT ON VIEW reportes.vista_compras_pendientes          IS 'Fuentes: compras + catalogo';
COMMENT ON VIEW reportes.vista_transferencias_en_transito  IS 'Fuentes: inventarios.transferencias + catalogo';
COMMENT ON VIEW reportes.vista_devoluciones_por_producto   IS 'Fuentes: fragmentos de ventas + ventas.devoluciones + catalogo';
COMMENT ON VIEW reportes.vista_reporte_corporativo         IS 'Fuentes: todos los microservicios, agregados por separado';
