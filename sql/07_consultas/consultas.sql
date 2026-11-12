-- 07_consultas/consultas.sql
-- las 20 consultas del enunciado (base andina_reportes). ver README.md:
-- ahi se explica cada una y en cual aparece cada cosa (JOIN, CTE...).

\echo
\echo '=== Consulta 1. Inventario por producto y sede ==='
SELECT p.nombre                              AS producto,
       c.nombre                              AS categoria,
       s.nombre                              AS sede,
       a.nombre                              AS almacen,
       i.existencia_actual,
       i.stock_minimo,
       i.existencia_actual * p.precio_lista  AS valorizacion_estimada,
       round(100.0 * i.existencia_actual * p.precio_lista
             / SUM(i.existencia_actual * p.precio_lista) OVER (PARTITION BY i.id_sede), 2) AS pct_valor_sede
FROM reportes.vista_inventario_consolidado i
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, id_categoria, precio_lista FROM catalogo.productos')
         AS p(id_producto INTEGER, nombre VARCHAR(100), id_categoria INTEGER, precio_lista NUMERIC(14,2)) ON p.id_producto  = i.id_producto
JOIN dblink('srv_catalogo', 'SELECT id_categoria, nombre FROM catalogo.categorias')
         AS c(id_categoria INTEGER, nombre VARCHAR(60)) ON c.id_categoria = p.id_categoria
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60)) ON s.id_sede      = i.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre FROM catalogo.almacenes')
         AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60)) ON a.id_almacen   = i.id_almacen
ORDER BY s.id_sede, a.nombre, c.nombre, p.nombre;

\echo
\echo '=== Consulta 2. Alertas de reabastecimiento ==='
SELECT s.nombre AS sede, a.nombre AS almacen, p.sku, p.nombre AS producto,
       i.existencia_actual, i.stock_minimo,
       i.stock_minimo - i.existencia_actual AS faltante,
       CASE WHEN i.existencia_actual = 0 THEN 'SIN EXISTENCIA' ELSE 'BAJO MINIMO' END AS nivel
FROM reportes.vista_inventario_consolidado i
JOIN dblink('srv_catalogo', 'SELECT id_producto, sku, nombre FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100)) ON p.id_producto = i.id_producto
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60)) ON s.id_sede     = i.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre FROM catalogo.almacenes')
         AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60)) ON a.id_almacen  = i.id_almacen
WHERE i.existencia_actual = 0
   OR i.existencia_actual < i.stock_minimo
ORDER BY faltante DESC, s.nombre;

\echo
\echo '=== Consulta 3. Productos activos ausentes por sede ==='
SELECT s.nombre AS sede, p.sku, p.nombre AS producto
FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, estado FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), estado VARCHAR(15))
CROSS JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
               AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10))
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (SELECT 1
                  FROM reportes.vista_inventario_consolidado i
                  WHERE i.id_sede = s.id_sede
                    AND i.id_producto = p.id_producto)
ORDER BY s.id_sede, p.id_producto;

\echo
\echo '=== Consulta 4. Top 5 de productos mas vendidos por sede y trimestre (ROW_NUMBER / DENSE_RANK) ==='
WITH ventas_producto AS (
    SELECT pv.id_sede,
           to_char(pv.fecha_pedido, 'YYYY-"T"Q') AS periodo,
           d.id_producto,
           SUM(d.cantidad)                       AS unidades
    FROM reportes.vista_pedidos_consolidado pv
    JOIN reportes.vista_detalle_pedido_consolidado d
      ON d.id_sede = pv.id_sede AND d.id_pedido = pv.id_pedido
    WHERE pv.estado IN ('CONFIRMADO', 'ENTREGADO')
    GROUP BY pv.id_sede, periodo, d.id_producto
), ranking AS (
    SELECT vp.*, p.nombre AS producto,
           ROW_NUMBER() OVER (PARTITION BY vp.id_sede, vp.periodo ORDER BY vp.unidades DESC, p.nombre) AS puesto,
           DENSE_RANK() OVER (PARTITION BY vp.id_sede, vp.periodo ORDER BY vp.unidades DESC)           AS nivel_ventas
    FROM ventas_producto vp
    JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, estado FROM catalogo.productos')
             AS p(id_producto INTEGER, nombre VARCHAR(100), estado VARCHAR(15)) ON p.id_producto = vp.id_producto
)
SELECT s.nombre AS sede, r.periodo, r.puesto, r.nivel_ventas, r.producto, r.unidades
FROM ranking r
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON s.id_sede = r.id_sede
WHERE r.puesto <= 5
ORDER BY s.id_sede, r.periodo, r.puesto;

\echo
\echo '=== Consulta 5. Ventas mensuales por sede y variacion frente al mes anterior (LAG) ==='
WITH mensual AS (
    SELECT id_sede, sede, mes, total_vendido,
           LAG(total_vendido) OVER (PARTITION BY id_sede ORDER BY mes) AS mes_anterior
    FROM reportes.vista_ventas_mensuales_por_sede
)
SELECT sede,
       to_char(mes, 'YYYY-MM')                                   AS mes,
       total_vendido,
       mes_anterior,
       total_vendido - mes_anterior                              AS variacion,
       round(100.0 * (total_vendido - mes_anterior) / mes_anterior, 2) AS variacion_pct
FROM mensual
ORDER BY id_sede, mes;

\echo
\echo '=== Consulta 6. Clientes con compras en al menos dos sedes ==='
SELECT c.id_cliente, c.nombre_completo,
       COUNT(DISTINCT p.id_sede)                                 AS sedes_visitadas,
       string_agg(DISTINCT s.nombre, ', ' ORDER BY s.nombre)     AS sedes,
       SUM(p.total_registrado)                                   AS total_comprado
FROM reportes.vista_pedidos_consolidado p
JOIN dblink('srv_catalogo', 'SELECT id_cliente, nombre_completo, estado FROM catalogo.clientes')
         AS c(id_cliente INTEGER, nombre_completo VARCHAR(120), estado VARCHAR(10)) ON c.id_cliente = p.id_cliente
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON s.id_sede    = p.id_sede
WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
GROUP BY c.id_cliente, c.nombre_completo
HAVING COUNT(DISTINCT p.id_sede) >= 2
ORDER BY sedes_visitadas DESC, total_comprado DESC;

\echo
\echo '=== Consulta 7. Pedidos con pagos pendientes ==='
SELECT s.nombre AS sede, p.id_pedido, p.estado, c.nombre_completo AS cliente,
       p.total_registrado                          AS valor_total,
       COALESCE(pg.pagado, 0)                      AS pagos_confirmados,
       p.total_registrado - COALESCE(pg.pagado, 0) AS saldo_por_pagar
FROM reportes.vista_pedidos_consolidado p
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON s.id_sede    = p.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_cliente, nombre_completo, estado FROM catalogo.clientes')
         AS c(id_cliente INTEGER, nombre_completo VARCHAR(120), estado VARCHAR(10)) ON c.id_cliente = p.id_cliente
LEFT JOIN (SELECT id_sede, id_pedido, SUM(valor) AS pagado
           FROM dblink('srv_ventas', 'SELECT id_sede, id_pedido, valor, estado FROM ventas.pagos')
                    AS pagos(id_sede INTEGER, id_pedido INTEGER, valor NUMERIC(14,2), estado VARCHAR(10))
           WHERE estado = 'CONFIRMADO'
           GROUP BY id_sede, id_pedido) pg
       ON pg.id_sede = p.id_sede AND pg.id_pedido = p.id_pedido
WHERE p.estado <> 'ANULADO'
  AND p.total_registrado > COALESCE(pg.pagado, 0)
ORDER BY saldo_por_pagar DESC;

\echo
\echo '=== Consulta 8. Pedidos con tres o mas productos distintos ==='
SELECT s.nombre AS sede, d.id_pedido,
       COUNT(DISTINCT d.id_producto)            AS productos_distintos,
       SUM(d.cantidad)                          AS unidades,
       SUM(d.cantidad * d.precio_unitario)      AS importe_detalle,
       MAX(p.total_registrado)                  AS total_registrado
FROM reportes.vista_detalle_pedido_consolidado d
JOIN reportes.vista_pedidos_consolidado p ON p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60)) ON s.id_sede = d.id_sede
GROUP BY s.nombre, d.id_sede, d.id_pedido
HAVING COUNT(DISTINCT d.id_producto) >= 3
ORDER BY productos_distintos DESC, importe_detalle DESC;

\echo
\echo '=== Consulta 9. Pedidos pendientes con mas de 15 dias de antiguedad ==='
SELECT pp.sede, pp.id_pedido, pp.fecha_pedido, pp.dias_antiguedad, pp.cliente, pp.vendedor, pp.total_registrado
FROM reportes.vista_pedidos_pendientes pp
CROSS JOIN reportes.parametros pr
WHERE pp.dias_antiguedad > pr.dias_pedido_antiguo
ORDER BY pp.dias_antiguedad DESC;

\echo
\echo '=== Consulta 10. Detalles de pedidos pendientes cuya cantidad supera la existencia ==='
SELECT s.nombre AS sede, p.id_pedido, p.fecha_pedido, pr.nombre AS producto,
       d.cantidad AS cantidad_pedida,
       COALESCE((SELECT i.existencia_actual
                 FROM reportes.vista_inventario_consolidado i
                 WHERE i.id_almacen  = p.id_almacen
                   AND i.id_producto = d.id_producto), 0) AS existencia_almacen
FROM reportes.vista_pedidos_consolidado p
JOIN reportes.vista_detalle_pedido_consolidado d ON d.id_sede = p.id_sede AND d.id_pedido = p.id_pedido
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10))  ON s.id_sede      = p.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, estado FROM catalogo.productos')
         AS pr(id_producto INTEGER, nombre VARCHAR(100), estado VARCHAR(15)) ON pr.id_producto = d.id_producto
WHERE p.estado = 'PENDIENTE'
  AND d.cantidad > COALESCE((SELECT i.existencia_actual            -- la misma subconsulta, ahora para filtrar
                             FROM reportes.vista_inventario_consolidado i
                             WHERE i.id_almacen  = p.id_almacen
                               AND i.id_producto = d.id_producto), 0)
ORDER BY s.nombre, p.id_pedido;

\echo
\echo '=== Consulta 11. Cumplimiento de proveedores ==='
WITH ultima_recepcion AS (
    SELECT oc.id_orden_compra, oc.id_proveedor, oc.fecha_estimada,
           MAX(rc.fecha_recepcion) AS fecha_ultima_recepcion
    FROM dblink('srv_compras', 'SELECT id_orden_compra, id_proveedor, fecha_estimada, estado FROM compras.ordenes_compra')
             AS oc(id_orden_compra INTEGER, id_proveedor INTEGER, fecha_estimada DATE, estado VARCHAR(10))
    JOIN dblink('srv_compras', 'SELECT id_orden_compra, fecha_recepcion, estado FROM compras.recepciones_compra')
             AS rc(id_orden_compra INTEGER, fecha_recepcion DATE, estado VARCHAR(10)) ON rc.id_orden_compra = oc.id_orden_compra
    WHERE oc.estado = 'RECIBIDA' AND rc.estado = 'REGISTRADA'
    GROUP BY oc.id_orden_compra, oc.id_proveedor, oc.fecha_estimada
), totales AS (
    SELECT id_proveedor, COUNT(*) AS total_ordenes
    FROM dblink('srv_compras', 'SELECT id_orden_compra, id_proveedor, fecha_estimada, estado FROM compras.ordenes_compra')
             AS ordenes_compra(id_orden_compra INTEGER, id_proveedor INTEGER, fecha_estimada DATE, estado VARCHAR(10))
    WHERE estado <> 'CANCELADA'
    GROUP BY id_proveedor
)
SELECT pv.razon_social                                                          AS proveedor,
       t.total_ordenes,
       COUNT(u.id_orden_compra)                                                 AS ordenes_recibidas,
       COUNT(CASE WHEN u.fecha_ultima_recepcion <= u.fecha_estimada THEN 1 END) AS recibidas_en_plazo,
       -- si llego antes de la fecha estimada cuenta como 0 dias de retraso
       round(AVG(CASE WHEN u.fecha_ultima_recepcion > u.fecha_estimada
                      THEN u.fecha_ultima_recepcion - u.fecha_estimada
                      ELSE 0 END), 2)                                           AS promedio_dias_retraso
FROM totales t
JOIN dblink('srv_catalogo', 'SELECT id_proveedor, razon_social, estado FROM catalogo.proveedores')
         AS pv(id_proveedor INTEGER, razon_social VARCHAR(100), estado VARCHAR(10)) ON pv.id_proveedor = t.id_proveedor
LEFT JOIN ultima_recepcion u ON u.id_proveedor = t.id_proveedor
GROUP BY pv.razon_social, t.total_ordenes
ORDER BY promedio_dias_retraso DESC NULLS LAST;

\echo
\echo '=== Consulta 12. Compras pendientes de recibir (incluye recepciones parciales) ==='
SELECT oc.id_orden_compra, oc.estado, pv.razon_social AS proveedor, p.nombre AS producto,
       d.cantidad_solicitada,
       COALESCE(r.recibida, 0)                         AS cantidad_recibida,
       d.cantidad_solicitada - COALESCE(r.recibida, 0) AS cantidad_pendiente
FROM dblink('srv_compras', 'SELECT id_orden_compra, id_proveedor, estado FROM compras.ordenes_compra')
         AS oc(id_orden_compra INTEGER, id_proveedor INTEGER, estado VARCHAR(10))
JOIN dblink('srv_compras', 'SELECT id_orden_compra, id_producto, cantidad_solicitada FROM compras.detalle_orden_compra')
         AS d(id_orden_compra INTEGER, id_producto INTEGER, cantidad_solicitada INTEGER) ON d.id_orden_compra = oc.id_orden_compra
JOIN dblink('srv_catalogo', 'SELECT id_proveedor, razon_social, estado FROM catalogo.proveedores')
         AS pv(id_proveedor INTEGER, razon_social VARCHAR(100), estado VARCHAR(10)) ON pv.id_proveedor = oc.id_proveedor
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
WHERE oc.estado IN ('EMITIDA', 'PARCIAL')
ORDER BY oc.id_orden_compra, p.nombre;

\echo
\echo '=== Consulta 13. Transferencias en transito ==='
SELECT t.id_transferencia,
       so.nombre || ' / ' || ao.nombre AS origen,
       sd.nombre || ' / ' || ad.nombre AS destino,
       p.nombre AS producto, dt.cantidad_enviada,
       t.fecha_despacho,
       pr.fecha_corte - t.fecha_despacho AS dias_transcurridos
FROM dblink('srv_inventarios', 'SELECT id_transferencia, id_almacen_origen, id_almacen_destino, fecha_despacho, fecha_recepcion, estado FROM inventarios.transferencias')
         AS t(id_transferencia INTEGER, id_almacen_origen INTEGER, id_almacen_destino INTEGER, fecha_despacho DATE, fecha_recepcion DATE, estado VARCHAR(10))
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
WHERE t.fecha_despacho IS NOT NULL
  AND t.fecha_recepcion IS NULL
  AND t.estado = 'DESPACHADA'
ORDER BY dias_transcurridos DESC, t.id_transferencia;

\echo
\echo '=== Consulta 14. Diferencias entre cantidad enviada y recibida ==='
SELECT t.id_transferencia, t.fecha_recepcion, p.nombre AS producto,
       dt.cantidad_enviada, dt.cantidad_recibida,
       dt.cantidad_recibida - dt.cantidad_enviada AS diferencia
FROM dblink('srv_inventarios', 'SELECT id_transferencia, fecha_recepcion FROM inventarios.transferencias')
         AS t(id_transferencia INTEGER, fecha_recepcion DATE)
JOIN dblink('srv_inventarios', 'SELECT id_transferencia, id_producto, cantidad_enviada, cantidad_recibida FROM inventarios.detalle_transferencia')
         AS dt(id_transferencia INTEGER, id_producto INTEGER, cantidad_enviada INTEGER, cantidad_recibida INTEGER) ON dt.id_transferencia = t.id_transferencia
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre FROM catalogo.productos')
         AS p(id_producto INTEGER, nombre VARCHAR(100)) ON p.id_producto = dt.id_producto
WHERE dt.cantidad_recibida IS NOT NULL
  AND dt.cantidad_recibida <> dt.cantidad_enviada
ORDER BY t.id_transferencia;

\echo
\echo '=== Consulta 15. Redistribucion: excedente en una sede y faltante en otra ==='
WITH stock_sede AS (
    SELECT id_sede, id_producto,
           SUM(existencia_actual) AS existencia,
           SUM(stock_minimo)      AS minimo
    FROM reportes.vista_inventario_consolidado
    GROUP BY id_sede, id_producto
)
SELECT p.nombre                         AS producto,
       so.nombre                        AS sede_con_excedente,
       ex.existencia - ex.minimo        AS excedente,
       sd.nombre                        AS sede_con_faltante,
       fa.minimo - fa.existencia        AS faltante,
       -- se sugiere mover lo menor entre lo que sobra y lo que falta
       -- (con CASE, porque no usamos LEAST)
       CASE WHEN ex.existencia - ex.minimo < fa.minimo - fa.existencia
            THEN ex.existencia - ex.minimo
            ELSE fa.minimo - fa.existencia END AS unidades_sugeridas
FROM stock_sede ex
JOIN stock_sede fa ON fa.id_producto = ex.id_producto AND fa.id_sede <> ex.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre FROM catalogo.productos')
         AS p(id_producto INTEGER, nombre VARCHAR(100))  ON p.id_producto = ex.id_producto
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre FROM catalogo.sedes')
         AS so(id_sede INTEGER, nombre VARCHAR(60)) ON so.id_sede    = ex.id_sede
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre FROM catalogo.sedes')
         AS sd(id_sede INTEGER, nombre VARCHAR(60)) ON sd.id_sede    = fa.id_sede
WHERE ex.existencia > ex.minimo
  AND fa.existencia < fa.minimo
-- desempate por sede, para que el orden salga siempre igual
ORDER BY unidades_sugeridas DESC, p.nombre, ex.id_sede, fa.id_sede;

\echo
\echo '=== Consulta 16. Productos de baja rotacion (existencia > 0 y sin ventas en 90 dias) ==='
SELECT p.sku, p.nombre AS producto, p.estado,
       SUM(i.existencia_actual) AS existencia_total,
       (SELECT MAX(pv.fecha_pedido)
        FROM reportes.vista_detalle_pedido_consolidado d
        JOIN reportes.vista_pedidos_consolidado pv ON pv.id_sede = d.id_sede AND pv.id_pedido = d.id_pedido
        WHERE d.id_producto = p.id_producto
          AND pv.estado IN ('CONFIRMADO', 'ENTREGADO')) AS ultima_venta
FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre, estado FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), estado VARCHAR(15))
JOIN reportes.vista_inventario_consolidado i ON i.id_producto = p.id_producto
CROSS JOIN reportes.parametros pr
WHERE NOT EXISTS (SELECT 1
                  FROM reportes.vista_detalle_pedido_consolidado d
                  JOIN reportes.vista_pedidos_consolidado pv
                    ON pv.id_sede = d.id_sede AND pv.id_pedido = d.id_pedido
                  WHERE d.id_producto = p.id_producto
                    AND pv.estado IN ('CONFIRMADO', 'ENTREGADO')
                    AND pv.fecha_pedido > pr.fecha_corte - pr.dias_baja_rotacion)
GROUP BY p.id_producto, p.sku, p.nombre, p.estado
HAVING SUM(i.existencia_actual) > 0
ORDER BY ultima_venta NULLS FIRST, p.sku;

\echo
\echo '=== Consulta 17. Devoluciones por producto y categoria (periodo jul-oct 2026) ==='
WITH vendidas AS (
    SELECT d.id_producto, SUM(d.cantidad) AS vendidas
    FROM reportes.vista_detalle_pedido_consolidado d
    JOIN reportes.vista_pedidos_consolidado p ON p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido
    WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
      AND p.fecha_pedido BETWEEN DATE '2026-07-01' AND DATE '2026-10-15'
    GROUP BY d.id_producto
), devueltas AS (
    SELECT dd.id_producto, SUM(dd.cantidad) AS devueltas
    FROM dblink('srv_ventas', 'SELECT id_devolucion, id_sede, id_pedido, estado FROM ventas.devoluciones')
             AS dv(id_devolucion INTEGER, id_sede INTEGER, id_pedido INTEGER, estado VARCHAR(10))
    JOIN dblink('srv_ventas', 'SELECT id_devolucion, id_producto, cantidad FROM ventas.detalle_devolucion')
             AS dd(id_devolucion INTEGER, id_producto INTEGER, cantidad INTEGER) ON dd.id_devolucion = dv.id_devolucion
    JOIN reportes.vista_pedidos_consolidado p ON p.id_sede = dv.id_sede AND p.id_pedido = dv.id_pedido
    WHERE dv.estado = 'APROBADA'
      AND p.fecha_pedido BETWEEN DATE '2026-07-01' AND DATE '2026-10-15'
    GROUP BY dd.id_producto
)
SELECT c.nombre AS categoria, p.nombre AS producto,
       v.vendidas,
       COALESCE(d.devueltas, 0) AS devueltas,
       round(100.0 * COALESCE(d.devueltas, 0) / v.vendidas, 2) AS pct_devolucion,
       -- el mismo % pero de toda la categoria (funcion de ventana)
       round(100.0 * SUM(COALESCE(d.devueltas, 0)) OVER (PARTITION BY c.id_categoria)
             / SUM(v.vendidas) OVER (PARTITION BY c.id_categoria), 2) AS pct_devolucion_categoria
FROM vendidas v
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, id_categoria, estado FROM catalogo.productos')
         AS p(id_producto INTEGER, nombre VARCHAR(100), id_categoria INTEGER, estado VARCHAR(15)) ON p.id_producto  = v.id_producto
JOIN dblink('srv_catalogo', 'SELECT id_categoria, nombre, estado FROM catalogo.categorias')
         AS c(id_categoria INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON c.id_categoria = p.id_categoria
LEFT JOIN devueltas d ON d.id_producto = v.id_producto   -- productos sin devoluciones salen con 0 %
ORDER BY c.nombre, pct_devolucion DESC, v.vendidas DESC;

\echo
\echo '=== Consulta 18a. Productos que hay en Bogota y NO en Cali (EXCEPT) ==='
-- EXCEPT: lo que esta en la primera lista y no en la segunda.
-- se leen los fragmentos directo (por dblink): es una consulta por sede
SELECT p.sku, p.nombre
FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100))
WHERE p.id_producto IN (
    SELECT id_producto FROM dblink('srv_inventarios', 'SELECT id_producto FROM inventarios.inv_bogota')
                                AS inv_bogota(id_producto INTEGER)
    EXCEPT
    SELECT id_producto FROM dblink('srv_inventarios', 'SELECT id_producto FROM inventarios.inv_cali')
                                AS inv_cali(id_producto INTEGER)
)
ORDER BY p.sku;

\echo
\echo '=== Consulta 18b. Productos comunes a Medellin y Cali (INTERSECT) ==='
-- INTERSECT: lo que esta en las dos listas
SELECT p.sku, p.nombre
FROM dblink('srv_catalogo', 'SELECT id_producto, sku, nombre FROM catalogo.productos')
         AS p(id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100))
WHERE p.id_producto IN (
    SELECT id_producto FROM dblink('srv_inventarios', 'SELECT id_producto FROM inventarios.inv_medellin')
                                AS inv_medellin(id_producto INTEGER)
    INTERSECT
    SELECT id_producto FROM dblink('srv_inventarios', 'SELECT id_producto FROM inventarios.inv_cali')
                                AS inv_cali(id_producto INTEGER)
)
ORDER BY p.sku;

\echo
\echo '=== Consulta 19. Clasificacion de vendedores por sede (RANK) ==='
WITH ventas_empleado AS (
    SELECT id_sede, id_empleado, COUNT(*) AS pedidos, SUM(total_registrado) AS total_vendido
    FROM reportes.vista_pedidos_consolidado
    WHERE estado IN ('CONFIRMADO', 'ENTREGADO')
    GROUP BY id_sede, id_empleado
)
SELECT s.nombre AS sede, e.nombre_completo AS vendedor, v.pedidos, v.total_vendido,
       RANK() OVER (PARTITION BY v.id_sede ORDER BY v.total_vendido DESC) AS puesto
FROM ventas_empleado v
JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON s.id_sede     = v.id_sede
JOIN dblink('srv_identidad', 'SELECT id_empleado, id_sede, nombre_completo, estado FROM identidad.empleados')
         AS e(id_empleado INTEGER, id_sede INTEGER, nombre_completo VARCHAR(120), estado VARCHAR(10)) ON e.id_empleado = v.id_empleado
ORDER BY s.id_sede, puesto;

\echo
\echo '=== Consulta 20. Consolidado corporativo por sede ==='
WITH inv AS (
    SELECT id_sede, SUM(existencia_actual) AS unidades_inventario
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
           SUM(CASE WHEN estado IN ('CONFIRMADO', 'ENTREGADO') THEN total_registrado END) AS valor_ventas,
           COUNT(CASE WHEN estado = 'PENDIENTE' THEN 1 END)                             AS pedidos_pendientes
    FROM reportes.vista_pedidos_consolidado
    GROUP BY id_sede
), com AS (
    SELECT a.id_sede, COUNT(DISTINCT oc.id_orden_compra) AS ordenes_compra,
           SUM(d.cantidad_solicitada * d.costo_unitario) AS valor_compras
    FROM dblink('srv_compras', 'SELECT id_orden_compra, id_almacen_destino, estado FROM compras.ordenes_compra')
             AS oc(id_orden_compra INTEGER, id_almacen_destino INTEGER, estado VARCHAR(10))
    JOIN dblink('srv_compras', 'SELECT id_orden_compra, id_producto, cantidad_solicitada, costo_unitario FROM compras.detalle_orden_compra')
             AS d(id_orden_compra INTEGER, id_producto INTEGER, cantidad_solicitada INTEGER, costo_unitario NUMERIC(14,2)) ON d.id_orden_compra = oc.id_orden_compra
    JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, estado FROM catalogo.almacenes')
             AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON a.id_almacen = oc.id_almacen_destino
    WHERE oc.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tra AS (
    -- DISTINCT: si origen y destino son de la misma sede (las dos bodegas
    -- del CEDI), la transferencia sale dos veces y se contaria doble
    SELECT a.id_sede, COUNT(DISTINCT t.id_transferencia) AS transferencias
    FROM dblink('srv_inventarios', 'SELECT id_transferencia, id_almacen_origen, id_almacen_destino, estado FROM inventarios.transferencias')
             AS t(id_transferencia INTEGER, id_almacen_origen INTEGER, id_almacen_destino INTEGER, estado VARCHAR(10))
    JOIN dblink('srv_catalogo', 'SELECT id_almacen, id_sede, nombre, estado FROM catalogo.almacenes')
             AS a(id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10)) ON a.id_almacen IN (t.id_almacen_origen, t.id_almacen_destino)
    WHERE t.estado <> 'CANCELADA'
    GROUP BY a.id_sede
)
SELECT s.nombre AS sede,
       COALESCE(ac.productos_activos, 0)   AS productos_activos,
       COALESCE(inv.unidades_inventario, 0) AS unidades_inventario,
       COALESCE(ven.valor_ventas, 0)       AS valor_ventas,
       COALESCE(ven.pedidos_pendientes, 0) AS pedidos_pendientes,
       COALESCE(com.ordenes_compra, 0)     AS ordenes_compra,
       COALESCE(com.valor_compras, 0)      AS valor_compras,
       COALESCE(tra.transferencias, 0)     AS transferencias
FROM dblink('srv_catalogo', 'SELECT id_sede, nombre, estado FROM catalogo.sedes')
         AS s(id_sede INTEGER, nombre VARCHAR(60), estado VARCHAR(10))
LEFT JOIN activos ac ON ac.id_sede  = s.id_sede
LEFT JOIN inv        ON inv.id_sede = s.id_sede
LEFT JOIN ven        ON ven.id_sede = s.id_sede
LEFT JOIN com        ON com.id_sede = s.id_sede
LEFT JOIN tra        ON tra.id_sede = s.id_sede
ORDER BY s.id_sede;
