-- =====================================================================
-- 08_vistas.sql
-- microservicio de reportes (base andina_reportes).
--
-- reportes no es dueno de ninguna tabla. sus vistas traen los datos de
-- las otras bases con dblink (ver dblink/servidores.sql).
--
-- como se lee cada vista: arriba, en el WITH, hay una CTE por cada tabla
-- de otra base que se necesita. cada una es una llamada a dblink, por
-- ejemplo:
--     catalogo_productos AS (
--         SELECT * FROM dblink('srv_catalogo', 'SELECT ... FROM catalogo.productos')
--             AS t(id_producto INTEGER, ...)
--     )
-- y despues la consulta usa catalogo_productos como si fuera la tabla.
-- el nombre es esquema_tabla, para que se vea de donde viene.
--
-- las vistas son MATERIALIZADAS:
--   una vista normal es una consulta guardada con nombre: no guarda
--   datos, cada vez que se lee vuelve a ejecutar su consulta.
--   una vista materializada ejecuta la consulta y GUARDA el resultado,
--   como si fuera una tabla. leerla es rapido, pero no cambia sola: se
--   actualiza solo con REFRESH MATERIALIZED VIEW (refrescar_reportes.sql),
--   que se programa cada X minutos. o sea, es "la vista que se va
--   actualizando cada X tiempo".
--   aqui ademas evita que cada lectura de un reporte vaya por dblink a
--   las otras bases: dblink solo se usa al refrescar.
--
-- WITH NO DATA: crea la vista vacia, sin ejecutar la consulta todavia.
-- se llena la primera vez que corre refrescar_reportes.sql. hasta
-- entonces, leerla da error ("no ha sido poblada").
--
-- parte a: vistas que juntan las 4 sedes en una sola (UNION ALL).
-- parte b: las 10 vistas que pide el enunciado, hechas encima de las
--          de la parte a.
--
-- si una vista tiene id_sede, sirve para una sede (WHERE id_sede = n)
-- o para toda la empresa (sin WHERE).
-- =====================================================================

CREATE SCHEMA reportes;
COMMENT ON SCHEMA reportes IS 'Microservicio de Reportes Corporativos: vistas materializadas que traen los datos por dblink';

-- ---------------------------------------------------------------------
-- a. parametros y unificacion de fragmentos
-- ---------------------------------------------------------------------

-- fecha de corte y umbrales que usan las vistas y las consultas
-- (S-14, S-15, S-16). se usa una fecha fija en vez de current_date para
-- que los resultados no cambien segun el dia en que se ejecute.
-- esta si es una vista normal: son constantes, no hay nada que refrescar.
CREATE VIEW reportes.parametros AS
SELECT DATE '2026-10-15' AS fecha_corte,
       15                AS dias_pedido_antiguo,
       90                AS dias_baja_rotacion;

-- junta los 4 inventarios en uno solo. la columna fragmento dice de que
-- base y tabla viene cada fila (seccion 6 del enunciado: que se vea la
-- procedencia).
-- UNION ALL y no UNION: UNION gasta tiempo buscando repetidos, y aqui no
-- puede haber, porque el CHECK de cada sede ya lo impide.
CREATE MATERIALIZED VIEW reportes.vista_inventario_consolidado AS
WITH inventarios_inv_bogota AS (
    SELECT * FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_bogota')
        AS t(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
),
inventarios_inv_medellin AS (
    SELECT * FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_medellin')
        AS t(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
),
inventarios_inv_cali AS (
    SELECT * FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_cali')
        AS t(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
),
inventarios_inv_cedi AS (
    SELECT * FROM dblink('srv_inventarios', 'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios.inv_cedi')
        AS t(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER, existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP)
)
SELECT 'andina_inventarios.inv_bogota'   AS fragmento, i.* FROM inventarios_inv_bogota   i
UNION ALL
SELECT 'andina_inventarios.inv_medellin' AS fragmento, i.* FROM inventarios_inv_medellin i
UNION ALL
SELECT 'andina_inventarios.inv_cali'     AS fragmento, i.* FROM inventarios_inv_cali     i
UNION ALL
SELECT 'andina_inventarios.inv_cedi'     AS fragmento, i.* FROM inventarios_inv_cedi     i
WITH NO DATA;

-- lo mismo para pedidos y para sus detalles
CREATE MATERIALIZED VIEW reportes.vista_pedidos_consolidado AS
WITH ventas_ped_bogota AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_bogota')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
),
ventas_ped_medellin AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_medellin')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
),
ventas_ped_cali AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_cali')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
),
ventas_ped_cedi AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM ventas.ped_cedi')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_almacen INTEGER, id_cliente INTEGER, id_empleado INTEGER, fecha_pedido DATE, estado VARCHAR(10), total_registrado NUMERIC(14,2))
)
SELECT 'andina_ventas.ped_bogota'   AS fragmento, p.* FROM ventas_ped_bogota   p
UNION ALL
SELECT 'andina_ventas.ped_medellin' AS fragmento, p.* FROM ventas_ped_medellin p
UNION ALL
SELECT 'andina_ventas.ped_cali'     AS fragmento, p.* FROM ventas_ped_cali     p
UNION ALL
SELECT 'andina_ventas.ped_cedi'     AS fragmento, p.* FROM ventas_ped_cedi     p
WITH NO DATA;

CREATE MATERIALIZED VIEW reportes.vista_detalle_pedido_consolidado AS
WITH ventas_det_ped_bogota AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_bogota')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
),
ventas_det_ped_medellin AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_medellin')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
),
ventas_det_ped_cali AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_cali')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
),
ventas_det_ped_cedi AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM ventas.det_ped_cedi')
        AS t(id_sede INTEGER, id_pedido INTEGER, id_producto INTEGER, cantidad INTEGER, precio_unitario NUMERIC(14,2))
)
SELECT 'andina_ventas.det_ped_bogota'   AS fragmento, d.* FROM ventas_det_ped_bogota   d
UNION ALL
SELECT 'andina_ventas.det_ped_medellin' AS fragmento, d.* FROM ventas_det_ped_medellin d
UNION ALL
SELECT 'andina_ventas.det_ped_cali'     AS fragmento, d.* FROM ventas_det_ped_cali     d
UNION ALL
SELECT 'andina_ventas.det_ped_cedi'     AS fragmento, d.* FROM ventas_det_ped_cedi     d
WITH NO DATA;

-- ---------------------------------------------------------------------
-- b. vistas obligatorias
-- ---------------------------------------------------------------------

-- 1. inventario por sede: une el inventario consolidado con el catalogo
--    para mostrar nombres en vez de ids, y calcula la valorizacion
--    (existencia x precio de lista).
--    fuentes: fragmentos de inventarios + catalogo
CREATE MATERIALIZED VIEW reportes.vista_inventario_por_sede AS
WITH catalogo_sedes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, ciudad, direccion, tipo_sede, estado FROM catalogo.sedes')
        AS t(id_sede INTEGER, nombre VARCHAR(60), ciudad VARCHAR(60), direccion VARCHAR(120), tipo_sede VARCHAR(15), estado VARCHAR(10))
),
catalogo_almacenes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, tipo_almacen, estado FROM catalogo.almacenes')
        AS t(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), tipo_almacen VARCHAR(15), estado VARCHAR(10))
),
catalogo_productos AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado FROM catalogo.productos')
        AS t(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15))
),
catalogo_categorias AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_categoria, nombre, descripcion, estado FROM catalogo.categorias')
        AS t(id_categoria INTEGER, nombre VARCHAR(60), descripcion VARCHAR(200), estado VARCHAR(10))
)
SELECT i.id_sede, s.nombre AS sede,
       i.id_almacen, a.nombre AS almacen,
       p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria,
       i.existencia_actual, i.stock_minimo, p.precio_lista,
       i.existencia_actual * p.precio_lista AS valorizacion_estimada,
       i.fragmento
FROM reportes.vista_inventario_consolidado i
JOIN catalogo_sedes      s ON s.id_sede      = i.id_sede
JOIN catalogo_almacenes  a ON a.id_almacen   = i.id_almacen
JOIN catalogo_productos  p ON p.id_producto  = i.id_producto
JOIN catalogo_categorias c ON c.id_categoria = p.id_categoria
WITH NO DATA;

-- 2. alertas de reabastecimiento: existencia cero o bajo el minimo
--    (RN-18). se apoya en la vista 1, que ya trae los nombres.
CREATE MATERIALIZED VIEW reportes.vista_alertas_reabastecimiento AS
SELECT v.id_sede, v.sede, v.id_almacen, v.almacen, v.id_producto, v.sku, v.producto, v.categoria,
       v.existencia_actual, v.stock_minimo,
       v.stock_minimo - v.existencia_actual AS faltante,
       CASE WHEN v.existencia_actual = 0 THEN 'SIN EXISTENCIA' ELSE 'BAJO MINIMO' END AS nivel_alerta
FROM reportes.vista_inventario_por_sede v
WHERE v.existencia_actual = 0
   OR v.existencia_actual < v.stock_minimo
WITH NO DATA;

-- 3. productos activos sin registro de inventario en una sede.
--    CROSS JOIN arma todas las parejas producto-sede y NOT EXISTS deja
--    solo las que no aparecen en ningun fragmento.
CREATE MATERIALIZED VIEW reportes.vista_productos_sin_inventario AS
WITH catalogo_productos AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado FROM catalogo.productos')
        AS t(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15))
),
catalogo_categorias AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_categoria, nombre, descripcion, estado FROM catalogo.categorias')
        AS t(id_categoria INTEGER, nombre VARCHAR(60), descripcion VARCHAR(200), estado VARCHAR(10))
),
catalogo_sedes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, ciudad, direccion, tipo_sede, estado FROM catalogo.sedes')
        AS t(id_sede INTEGER, nombre VARCHAR(60), ciudad VARCHAR(60), direccion VARCHAR(120), tipo_sede VARCHAR(15), estado VARCHAR(10))
)
SELECT s.id_sede, s.nombre AS sede, p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria
FROM catalogo_productos p
JOIN catalogo_categorias c ON c.id_categoria = p.id_categoria
CROSS JOIN catalogo_sedes s
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (SELECT 1
                  FROM reportes.vista_inventario_consolidado i
                  WHERE i.id_sede = s.id_sede
                    AND i.id_producto = p.id_producto)
WITH NO DATA;

-- 4. ventas confirmadas (CONFIRMADO o ENTREGADO, RN-29) por sede y mes.
--    date_trunc('month', fecha) lleva cada fecha al dia 1 de su mes para
--    agrupar por mes.
CREATE MATERIALIZED VIEW reportes.vista_ventas_mensuales_por_sede AS
WITH catalogo_sedes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, ciudad, direccion, tipo_sede, estado FROM catalogo.sedes')
        AS t(id_sede INTEGER, nombre VARCHAR(60), ciudad VARCHAR(60), direccion VARCHAR(120), tipo_sede VARCHAR(15), estado VARCHAR(10))
)
SELECT p.id_sede, s.nombre AS sede,
       date_trunc('month', p.fecha_pedido)::date AS mes,
       COUNT(*)                                  AS pedidos,
       SUM(p.total_registrado)                   AS total_vendido
FROM reportes.vista_pedidos_consolidado p
JOIN catalogo_sedes s ON s.id_sede = p.id_sede
WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
GROUP BY p.id_sede, s.nombre, date_trunc('month', p.fecha_pedido)
WITH NO DATA;

-- 5. pedidos pendientes con su antiguedad respecto de la fecha de corte.
--    restar dos DATE da los dias entre ellas. es_antiguo marca los que
--    superan el umbral de 15 dias (S-15).
--    CROSS JOIN con parametros (una sola fila) pega la fecha de corte a
--    cada pedido.
CREATE MATERIALIZED VIEW reportes.vista_pedidos_pendientes AS
WITH catalogo_sedes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, ciudad, direccion, tipo_sede, estado FROM catalogo.sedes')
        AS t(id_sede INTEGER, nombre VARCHAR(60), ciudad VARCHAR(60), direccion VARCHAR(120), tipo_sede VARCHAR(15), estado VARCHAR(10))
),
catalogo_clientes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_cliente, tipo_documento, num_documento, nombre_completo, correo, telefono, estado FROM catalogo.clientes')
        AS t(id_cliente INTEGER, tipo_documento VARCHAR(10), num_documento VARCHAR(20), nombre_completo VARCHAR(120), correo VARCHAR(100), telefono VARCHAR(20), estado VARCHAR(10))
),
identidad_empleados AS (
    SELECT * FROM dblink('srv_identidad', 'SELECT id_empleado, id_sede, num_documento, nombre_completo, cargo, correo, estado FROM identidad.empleados')
        AS t(id_empleado INTEGER, id_sede INTEGER, num_documento VARCHAR(20), nombre_completo VARCHAR(120), cargo VARCHAR(30), correo VARCHAR(100), estado VARCHAR(10))
)
SELECT p.id_sede, s.nombre AS sede, p.id_pedido, p.fecha_pedido,
       pr.fecha_corte - p.fecha_pedido AS dias_antiguedad,
       (pr.fecha_corte - p.fecha_pedido) > pr.dias_pedido_antiguo AS es_antiguo,
       p.id_cliente, cl.nombre_completo AS cliente,
       p.id_empleado, e.nombre_completo AS vendedor,
       p.total_registrado
FROM reportes.vista_pedidos_consolidado p
CROSS JOIN reportes.parametros pr
JOIN catalogo_sedes      s  ON s.id_sede      = p.id_sede
JOIN catalogo_clientes   cl ON cl.id_cliente  = p.id_cliente
JOIN identidad_empleados e  ON e.id_empleado  = p.id_empleado
WHERE p.estado = 'PENDIENTE'
WITH NO DATA;

-- 6. saldos pendientes: total registrado menos pagos confirmados (RN-31).
--    los pagos se suman primero por pedido (subconsulta pg) y despues se
--    unen, asi un pedido con varios pagos no se repite.
--    LEFT JOIN conserva los pedidos sin ningun pago; para ellos la suma
--    sale NULL y COALESCE(pg.pagado, 0) la convierte en 0.
CREATE MATERIALIZED VIEW reportes.vista_saldos_pendientes AS
WITH catalogo_sedes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, ciudad, direccion, tipo_sede, estado FROM catalogo.sedes')
        AS t(id_sede INTEGER, nombre VARCHAR(60), ciudad VARCHAR(60), direccion VARCHAR(120), tipo_sede VARCHAR(15), estado VARCHAR(10))
),
catalogo_clientes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_cliente, tipo_documento, num_documento, nombre_completo, correo, telefono, estado FROM catalogo.clientes')
        AS t(id_cliente INTEGER, tipo_documento VARCHAR(10), num_documento VARCHAR(20), nombre_completo VARCHAR(120), correo VARCHAR(100), telefono VARCHAR(20), estado VARCHAR(10))
),
ventas_pagos AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_pago, id_sede, id_pedido, fecha_pago, valor, medio_pago, estado FROM ventas.pagos')
        AS t(id_pago INTEGER, id_sede INTEGER, id_pedido INTEGER, fecha_pago DATE, valor NUMERIC(14,2), medio_pago VARCHAR(20), estado VARCHAR(10))
)
SELECT p.id_sede, s.nombre AS sede, p.id_pedido, p.fecha_pedido, p.estado,
       p.id_cliente, cl.nombre_completo AS cliente,
       p.total_registrado,
       COALESCE(pg.pagado, 0)                      AS pagos_confirmados,
       p.total_registrado - COALESCE(pg.pagado, 0) AS saldo_pendiente
FROM reportes.vista_pedidos_consolidado p
JOIN catalogo_sedes    s  ON s.id_sede     = p.id_sede
JOIN catalogo_clientes cl ON cl.id_cliente = p.id_cliente
LEFT JOIN (SELECT id_sede, id_pedido, SUM(valor) AS pagado
           FROM ventas_pagos
           WHERE estado = 'CONFIRMADO'
           GROUP BY id_sede, id_pedido) pg
       ON pg.id_sede = p.id_sede AND pg.id_pedido = p.id_pedido
WHERE p.estado <> 'ANULADO'
  AND p.total_registrado - COALESCE(pg.pagado, 0) > 0
WITH NO DATA;

-- 7. compras pendientes de recibir por orden y producto: solicitado
--    menos lo recibido en todas sus recepciones registradas (RN-11).
--    mismo patron que la vista 6: sumar primero, LEFT JOIN y COALESCE.
CREATE MATERIALIZED VIEW reportes.vista_compras_pendientes AS
WITH compras_ordenes_compra AS (
    SELECT * FROM dblink('srv_compras', 'SELECT id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado FROM compras.ordenes_compra')
        AS t(id_orden_compra INTEGER, id_proveedor INTEGER, id_almacen_destino INTEGER, id_empleado INTEGER, fecha_orden DATE, fecha_estimada DATE, estado VARCHAR(10))
),
compras_detalle_orden_compra AS (
    SELECT * FROM dblink('srv_compras', 'SELECT id_orden_compra, id_producto, cantidad_solicitada, costo_unitario FROM compras.detalle_orden_compra')
        AS t(id_orden_compra INTEGER, id_producto INTEGER, cantidad_solicitada INTEGER, costo_unitario NUMERIC(14,2))
),
catalogo_proveedores AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_proveedor, identificacion, razon_social, ciudad, correo, telefono, estado FROM catalogo.proveedores')
        AS t(id_proveedor INTEGER, identificacion VARCHAR(20), razon_social VARCHAR(100), ciudad VARCHAR(60), correo VARCHAR(100), telefono VARCHAR(20), estado VARCHAR(10))
),
catalogo_almacenes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, tipo_almacen, estado FROM catalogo.almacenes')
        AS t(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), tipo_almacen VARCHAR(15), estado VARCHAR(10))
),
catalogo_productos AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado FROM catalogo.productos')
        AS t(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15))
),
compras_recepciones_compra AS (
    SELECT * FROM dblink('srv_compras', 'SELECT id_recepcion, id_orden_compra, fecha_recepcion, estado FROM compras.recepciones_compra')
        AS t(id_recepcion INTEGER, id_orden_compra INTEGER, fecha_recepcion DATE, estado VARCHAR(10))
),
compras_detalle_recepcion AS (
    SELECT * FROM dblink('srv_compras', 'SELECT id_recepcion, id_producto, cantidad_recibida FROM compras.detalle_recepcion')
        AS t(id_recepcion INTEGER, id_producto INTEGER, cantidad_recibida INTEGER)
)
SELECT oc.id_orden_compra, oc.fecha_orden, oc.fecha_estimada, oc.estado,
       pv.razon_social AS proveedor, a.nombre AS almacen_destino,
       d.id_producto, p.nombre AS producto,
       d.cantidad_solicitada,
       COALESCE(r.recibida, 0)                         AS cantidad_recibida,
       d.cantidad_solicitada - COALESCE(r.recibida, 0) AS cantidad_pendiente
FROM compras_ordenes_compra oc
JOIN compras_detalle_orden_compra d ON d.id_orden_compra = oc.id_orden_compra
JOIN catalogo_proveedores pv ON pv.id_proveedor = oc.id_proveedor
JOIN catalogo_almacenes   a  ON a.id_almacen    = oc.id_almacen_destino
JOIN catalogo_productos   p  ON p.id_producto   = d.id_producto
LEFT JOIN (SELECT rc.id_orden_compra, dr.id_producto, SUM(dr.cantidad_recibida) AS recibida
           FROM compras_recepciones_compra rc
           JOIN compras_detalle_recepcion dr ON dr.id_recepcion = rc.id_recepcion
           WHERE rc.estado = 'REGISTRADA'
           GROUP BY rc.id_orden_compra, dr.id_producto) r
       ON r.id_orden_compra = d.id_orden_compra AND r.id_producto = d.id_producto
WHERE oc.estado <> 'CANCELADA'
  AND d.cantidad_solicitada > COALESCE(r.recibida, 0)
WITH NO DATA;

-- 8. transferencias despachadas y aun no recibidas (RN-22).
--    almacenes y sedes se unen dos veces, con alias distintos (ao/so
--    para el origen, ad/sd para el destino), porque la transferencia
--    tiene dos almacenes.
CREATE MATERIALIZED VIEW reportes.vista_transferencias_en_transito AS
WITH inventarios_transferencias AS (
    SELECT * FROM dblink('srv_inventarios', 'SELECT id_transferencia, id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado FROM inventarios.transferencias')
        AS t(id_transferencia INTEGER, id_almacen_origen INTEGER, id_almacen_destino INTEGER, fecha_solicitud DATE, fecha_despacho DATE, fecha_recepcion DATE, estado VARCHAR(10))
),
inventarios_detalle_transferencia AS (
    SELECT * FROM dblink('srv_inventarios', 'SELECT id_transferencia, id_producto, cantidad_enviada, cantidad_recibida FROM inventarios.detalle_transferencia')
        AS t(id_transferencia INTEGER, id_producto INTEGER, cantidad_enviada INTEGER, cantidad_recibida INTEGER)
),
catalogo_almacenes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, tipo_almacen, estado FROM catalogo.almacenes')
        AS t(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), tipo_almacen VARCHAR(15), estado VARCHAR(10))
),
catalogo_sedes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, ciudad, direccion, tipo_sede, estado FROM catalogo.sedes')
        AS t(id_sede INTEGER, nombre VARCHAR(60), ciudad VARCHAR(60), direccion VARCHAR(120), tipo_sede VARCHAR(15), estado VARCHAR(10))
),
catalogo_productos AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado FROM catalogo.productos')
        AS t(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15))
)
SELECT t.id_transferencia,
       ao.nombre AS almacen_origen,  so.nombre AS sede_origen,
       ad.nombre AS almacen_destino, sd.nombre AS sede_destino,
       t.fecha_solicitud, t.fecha_despacho,
       pr.fecha_corte - t.fecha_despacho AS dias_en_transito,
       dt.id_producto, p.nombre AS producto, dt.cantidad_enviada
FROM inventarios_transferencias t
CROSS JOIN reportes.parametros pr
JOIN inventarios_detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN catalogo_almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN catalogo_sedes     so ON so.id_sede    = ao.id_sede
JOIN catalogo_almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN catalogo_sedes     sd ON sd.id_sede    = ad.id_sede
JOIN catalogo_productos p  ON p.id_producto = dt.id_producto
WHERE t.estado = 'DESPACHADA'
  AND t.fecha_recepcion IS NULL
WITH NO DATA;

-- 9. devoluciones aprobadas frente a unidades vendidas, por producto
--    (RN-34). WITH define dos subconsultas con nombre (CTE): vendidas y
--    devueltas se calculan por separado y luego se unen por producto.
CREATE MATERIALIZED VIEW reportes.vista_devoluciones_por_producto AS
WITH ventas_devoluciones AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_devolucion, id_sede, id_pedido, fecha_solicitud, motivo, estado FROM ventas.devoluciones')
        AS t(id_devolucion INTEGER, id_sede INTEGER, id_pedido INTEGER, fecha_solicitud DATE, motivo VARCHAR(200), estado VARCHAR(10))
),
ventas_detalle_devolucion AS (
    SELECT * FROM dblink('srv_ventas', 'SELECT id_devolucion, id_producto, cantidad, condicion_producto FROM ventas.detalle_devolucion')
        AS t(id_devolucion INTEGER, id_producto INTEGER, cantidad INTEGER, condicion_producto VARCHAR(10))
),
catalogo_productos AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado FROM catalogo.productos')
        AS t(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15))
),
catalogo_categorias AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_categoria, nombre, descripcion, estado FROM catalogo.categorias')
        AS t(id_categoria INTEGER, nombre VARCHAR(60), descripcion VARCHAR(200), estado VARCHAR(10))
),
vendidas AS (
    SELECT d.id_producto, SUM(d.cantidad) AS unidades_vendidas
    FROM reportes.vista_detalle_pedido_consolidado d
    JOIN reportes.vista_pedidos_consolidado p
      ON p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido
    WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
    GROUP BY d.id_producto
), devueltas AS (
    SELECT dd.id_producto, SUM(dd.cantidad) AS unidades_devueltas
    FROM ventas_devoluciones dv
    JOIN ventas_detalle_devolucion dd ON dd.id_devolucion = dv.id_devolucion
    WHERE dv.estado = 'APROBADA'
    GROUP BY dd.id_producto
)
SELECT p.id_producto, p.sku, p.nombre AS producto, c.nombre AS categoria,
       v.unidades_vendidas,
       COALESCE(dv.unidades_devueltas, 0) AS unidades_devueltas,
       round(100.0 * COALESCE(dv.unidades_devueltas, 0) / v.unidades_vendidas, 2) AS porcentaje_devolucion
FROM vendidas v
JOIN catalogo_productos  p ON p.id_producto  = v.id_producto
JOIN catalogo_categorias c ON c.id_categoria = p.id_categoria
LEFT JOIN devueltas dv ON dv.id_producto = v.id_producto
WITH NO DATA;

-- 10. reporte corporativo: un resumen por sede.
--     el truco: si se unen pedidos, inventario y compras en un solo JOIN,
--     cada pedido se repite muchas veces y las sumas salen infladas.
--     por eso cada cosa se resume aparte (una CTE por fuente, una fila
--     por sede) y al final se juntan por sede (RN-42).
--     la prueba 10 de 11_pruebas.sql revisa que los totales cuadren.
--     COUNT(CASE WHEN ... THEN 1 END) cuenta solo las filas que cumplen
--     la condicion (las demas dan NULL y COUNT no las cuenta).
CREATE MATERIALIZED VIEW reportes.vista_reporte_corporativo AS
WITH catalogo_productos AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado FROM catalogo.productos')
        AS t(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER, unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15))
),
compras_ordenes_compra AS (
    SELECT * FROM dblink('srv_compras', 'SELECT id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado FROM compras.ordenes_compra')
        AS t(id_orden_compra INTEGER, id_proveedor INTEGER, id_almacen_destino INTEGER, id_empleado INTEGER, fecha_orden DATE, fecha_estimada DATE, estado VARCHAR(10))
),
compras_detalle_orden_compra AS (
    SELECT * FROM dblink('srv_compras', 'SELECT id_orden_compra, id_producto, cantidad_solicitada, costo_unitario FROM compras.detalle_orden_compra')
        AS t(id_orden_compra INTEGER, id_producto INTEGER, cantidad_solicitada INTEGER, costo_unitario NUMERIC(14,2))
),
catalogo_almacenes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, tipo_almacen, estado FROM catalogo.almacenes')
        AS t(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), tipo_almacen VARCHAR(15), estado VARCHAR(10))
),
inventarios_transferencias AS (
    SELECT * FROM dblink('srv_inventarios', 'SELECT id_transferencia, id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado FROM inventarios.transferencias')
        AS t(id_transferencia INTEGER, id_almacen_origen INTEGER, id_almacen_destino INTEGER, fecha_solicitud DATE, fecha_despacho DATE, fecha_recepcion DATE, estado VARCHAR(10))
),
catalogo_sedes AS (
    SELECT * FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, ciudad, direccion, tipo_sede, estado FROM catalogo.sedes')
        AS t(id_sede INTEGER, nombre VARCHAR(60), ciudad VARCHAR(60), direccion VARCHAR(120), tipo_sede VARCHAR(15), estado VARCHAR(10))
),
inv AS (
    SELECT id_sede,
           COUNT(DISTINCT CASE WHEN existencia_actual > 0 THEN id_producto END) AS productos_con_existencia,
           SUM(existencia_actual)                                           AS unidades_inventario
    FROM reportes.vista_inventario_consolidado
    GROUP BY id_sede
), activos AS (
    SELECT i.id_sede, COUNT(DISTINCT i.id_producto) AS productos_activos
    FROM reportes.vista_inventario_consolidado i
    JOIN catalogo_productos p ON p.id_producto = i.id_producto
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
    FROM compras_ordenes_compra oc
    JOIN compras_detalle_orden_compra d ON d.id_orden_compra = oc.id_orden_compra
    JOIN catalogo_almacenes a ON a.id_almacen = oc.id_almacen_destino
    WHERE oc.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tr_sal AS (
    SELECT a.id_sede, COUNT(*) AS transferencias_enviadas
    FROM inventarios_transferencias t
    JOIN catalogo_almacenes a ON a.id_almacen = t.id_almacen_origen
    WHERE t.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tr_ent AS (
    SELECT a.id_sede, COUNT(*) AS transferencias_recibidas
    FROM inventarios_transferencias t
    JOIN catalogo_almacenes a ON a.id_almacen = t.id_almacen_destino
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
FROM catalogo_sedes s
LEFT JOIN activos ac ON ac.id_sede  = s.id_sede
LEFT JOIN inv        ON inv.id_sede = s.id_sede
LEFT JOIN ven        ON ven.id_sede = s.id_sede
LEFT JOIN com        ON com.id_sede = s.id_sede
LEFT JOIN tr_sal ts  ON ts.id_sede  = s.id_sede
LEFT JOIN tr_ent te  ON te.id_sede  = s.id_sede
WITH NO DATA;

-- procedencia de cada vista, guardada en la base (seccion 6 del enunciado).
-- todas traen los datos de la base de cada servicio por dblink.
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

-- ---------------------------------------------------------------------
-- c. de cuando son los datos
-- una vista materializada de una sola fila con la hora del ultimo
-- refresco. refrescar_reportes.sql la refresca al final, asi quien lea
-- un reporte sabe "datos al...". now() da la hora en que empezo la
-- transaccion del refresco.
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW reportes.vista_ultima_actualizacion AS
SELECT now() AS actualizado_en
WITH NO DATA;

COMMENT ON MATERIALIZED VIEW reportes.vista_ultima_actualizacion IS 'Hora del ultimo REFRESH de los reportes';
