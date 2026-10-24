-- =====================================================================
-- 10_consultas.sql
-- Las 20 consultas obligatorias. Fecha de corte: reportes.parametros.
--
-- Cobertura de construcciones SQL:
--   JOIN ................. 1, 2, 4, 6, 7, 10, 11, 13, 14, 15, 17, 19
--   LEFT JOIN ............ 7, 12, 17, 20
--   NOT EXISTS ........... 3, 16
--   Subconsulta correlac.  10, 16
--   GROUP BY / HAVING .... 6, 8, 11 / 6, 8
--   CTE (WITH) ........... 4, 5, 11, 15, 17, 19, 20
--   Funciones de ventana . 1 (SUM OVER), 4 (ROW_NUMBER, DENSE_RANK), 5 (LAG), 17 (SUM OVER), 19 (RANK)
--   Operaciones conjuntos  18 (EXCEPT, INTERSECT) + UNION ALL en las vistas
-- =====================================================================

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
JOIN catalogo.productos  p ON p.id_producto  = i.id_producto
JOIN catalogo.categorias c ON c.id_categoria = p.id_categoria
JOIN catalogo.sedes      s ON s.id_sede      = i.id_sede
JOIN catalogo.almacenes  a ON a.id_almacen   = i.id_almacen
ORDER BY s.id_sede, a.nombre, c.nombre, p.nombre;

\echo
\echo '=== Consulta 2. Alertas de reabastecimiento ==='
SELECT s.nombre AS sede, a.nombre AS almacen, p.sku, p.nombre AS producto,
       i.existencia_actual, i.stock_minimo,
       i.stock_minimo - i.existencia_actual AS faltante,
       CASE WHEN i.existencia_actual = 0 THEN 'SIN EXISTENCIA' ELSE 'BAJO MINIMO' END AS nivel
FROM reportes.vista_inventario_consolidado i
JOIN catalogo.productos p ON p.id_producto = i.id_producto
JOIN catalogo.sedes     s ON s.id_sede     = i.id_sede
JOIN catalogo.almacenes a ON a.id_almacen  = i.id_almacen
WHERE i.existencia_actual = 0
   OR i.existencia_actual < i.stock_minimo
ORDER BY faltante DESC, s.nombre;

\echo
\echo '=== Consulta 3. Productos activos ausentes por sede ==='
SELECT s.nombre AS sede, p.sku, p.nombre AS producto
FROM catalogo.productos p
CROSS JOIN catalogo.sedes s
WHERE p.estado = 'ACTIVO'
  AND NOT EXISTS (SELECT 1
                  FROM reportes.vista_inventario_consolidado i
                  WHERE i.id_sede = s.id_sede
                    AND i.id_producto = p.id_producto)
ORDER BY s.id_sede, p.id_producto;

\echo
\echo '=== Consulta 4. Top 5 de productos más vendidos por sede y trimestre (ROW_NUMBER / DENSE_RANK) ==='
-- ROW_NUMBER limita a exactamente 5 filas por sede y trimestre (los empates
-- se desempatan por nombre); DENSE_RANK muestra qué productos empatan.
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
    JOIN catalogo.productos p ON p.id_producto = vp.id_producto
)
SELECT s.nombre AS sede, r.periodo, r.puesto, r.nivel_ventas, r.producto, r.unidades
FROM ranking r
JOIN catalogo.sedes s ON s.id_sede = r.id_sede
WHERE r.puesto <= 5
ORDER BY s.id_sede, r.periodo, r.puesto;

\echo
\echo '=== Consulta 5. Ventas mensuales por sede y variación frente al mes anterior (LAG) ==='
-- Octubre llega solo hasta la fecha de corte (día 15), por eso su caída es parcial.
WITH mensual AS (
    SELECT id_sede, sede, mes, total_vendido
    FROM reportes.vista_ventas_mensuales_por_sede
)
SELECT sede,
       to_char(mes, 'YYYY-MM')                                       AS mes,
       total_vendido,
       LAG(total_vendido) OVER (PARTITION BY id_sede ORDER BY mes)   AS mes_anterior,
       total_vendido - LAG(total_vendido) OVER (PARTITION BY id_sede ORDER BY mes) AS variacion,
       round(100.0 * (total_vendido - LAG(total_vendido) OVER (PARTITION BY id_sede ORDER BY mes))
             / NULLIF(LAG(total_vendido) OVER (PARTITION BY id_sede ORDER BY mes), 0), 2) AS variacion_pct
FROM mensual
ORDER BY id_sede, mes;

\echo
\echo '=== Consulta 6. Clientes con compras en al menos dos sedes ==='
SELECT c.id_cliente, c.nombre_completo,
       COUNT(DISTINCT p.id_sede)                                 AS sedes_visitadas,
       string_agg(DISTINCT s.nombre, ', ' ORDER BY s.nombre)     AS sedes,
       SUM(p.total_registrado)                                   AS total_comprado
FROM reportes.vista_pedidos_consolidado p
JOIN catalogo.clientes c ON c.id_cliente = p.id_cliente
JOIN catalogo.sedes    s ON s.id_sede    = p.id_sede
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
JOIN catalogo.sedes    s ON s.id_sede    = p.id_sede
JOIN catalogo.clientes c ON c.id_cliente = p.id_cliente
LEFT JOIN (SELECT id_sede, id_pedido, SUM(valor) AS pagado
           FROM ventas.pagos
           WHERE estado = 'CONFIRMADO'
           GROUP BY id_sede, id_pedido) pg
       ON pg.id_sede = p.id_sede AND pg.id_pedido = p.id_pedido
WHERE p.estado <> 'ANULADO'
  AND p.total_registrado > COALESCE(pg.pagado, 0)
ORDER BY saldo_por_pagar DESC;

\echo
\echo '=== Consulta 8. Pedidos con tres o más productos distintos ==='
SELECT s.nombre AS sede, d.id_pedido,
       COUNT(DISTINCT d.id_producto)            AS productos_distintos,
       SUM(d.cantidad)                          AS unidades,
       SUM(d.cantidad * d.precio_unitario)      AS importe_detalle,
       MAX(p.total_registrado)                  AS total_registrado
FROM reportes.vista_detalle_pedido_consolidado d
JOIN reportes.vista_pedidos_consolidado p ON p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido
JOIN catalogo.sedes s ON s.id_sede = d.id_sede
GROUP BY s.nombre, d.id_sede, d.id_pedido
HAVING COUNT(DISTINCT d.id_producto) >= 3
ORDER BY productos_distintos DESC, importe_detalle DESC;

\echo
\echo '=== Consulta 9. Pedidos pendientes con más de 15 días de antigüedad ==='
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
JOIN catalogo.sedes     s  ON s.id_sede      = p.id_sede
JOIN catalogo.productos pr ON pr.id_producto = d.id_producto
WHERE p.estado = 'PENDIENTE'
  AND d.cantidad > COALESCE((SELECT i.existencia_actual            -- subconsulta correlacionada
                             FROM reportes.vista_inventario_consolidado i
                             WHERE i.id_almacen  = p.id_almacen
                               AND i.id_producto = d.id_producto), 0)
ORDER BY s.nombre, p.id_pedido;

\echo
\echo '=== Consulta 11. Cumplimiento de proveedores ==='
WITH ultima_recepcion AS (
    SELECT oc.id_orden_compra, oc.id_proveedor, oc.fecha_estimada,
           MAX(rc.fecha_recepcion) AS fecha_ultima_recepcion
    FROM compras.ordenes_compra oc
    JOIN compras.recepciones_compra rc ON rc.id_orden_compra = oc.id_orden_compra
    WHERE oc.estado = 'RECIBIDA' AND rc.estado = 'REGISTRADA'
    GROUP BY oc.id_orden_compra, oc.id_proveedor, oc.fecha_estimada
), totales AS (
    SELECT id_proveedor, COUNT(*) AS total_ordenes
    FROM compras.ordenes_compra
    WHERE estado <> 'CANCELADA'
    GROUP BY id_proveedor
)
SELECT pv.razon_social                                                          AS proveedor,
       t.total_ordenes,
       COUNT(u.id_orden_compra)                                                 AS ordenes_recibidas,
       COUNT(*) FILTER (WHERE u.fecha_ultima_recepcion <= u.fecha_estimada)     AS recibidas_en_plazo,
       round(AVG(GREATEST(u.fecha_ultima_recepcion - u.fecha_estimada, 0)), 2)  AS promedio_dias_retraso
FROM totales t
JOIN catalogo.proveedores pv ON pv.id_proveedor = t.id_proveedor
LEFT JOIN ultima_recepcion u ON u.id_proveedor = t.id_proveedor
GROUP BY pv.razon_social, t.total_ordenes
ORDER BY promedio_dias_retraso DESC NULLS LAST;

\echo
\echo '=== Consulta 12. Compras pendientes de recibir (incluye recepciones parciales) ==='
SELECT oc.id_orden_compra, oc.estado, pv.razon_social AS proveedor, p.nombre AS producto,
       d.cantidad_solicitada,
       COALESCE(r.recibida, 0)                         AS cantidad_recibida,
       d.cantidad_solicitada - COALESCE(r.recibida, 0) AS cantidad_pendiente
FROM compras.ordenes_compra oc
JOIN compras.detalle_orden_compra d ON d.id_orden_compra = oc.id_orden_compra
JOIN catalogo.proveedores pv ON pv.id_proveedor = oc.id_proveedor
JOIN catalogo.productos   p  ON p.id_producto   = d.id_producto
LEFT JOIN (SELECT rc.id_orden_compra, dr.id_producto, SUM(dr.cantidad_recibida) AS recibida
           FROM compras.recepciones_compra rc
           JOIN compras.detalle_recepcion dr ON dr.id_recepcion = rc.id_recepcion
           WHERE rc.estado = 'REGISTRADA'
           GROUP BY rc.id_orden_compra, dr.id_producto) r
       ON r.id_orden_compra = d.id_orden_compra AND r.id_producto = d.id_producto
WHERE oc.estado IN ('EMITIDA', 'PARCIAL')
ORDER BY oc.id_orden_compra, p.nombre;

\echo
\echo '=== Consulta 13. Transferencias en tránsito ==='
SELECT t.id_transferencia,
       so.nombre || ' / ' || ao.nombre AS origen,
       sd.nombre || ' / ' || ad.nombre AS destino,
       p.nombre AS producto, dt.cantidad_enviada,
       t.fecha_despacho,
       pr.fecha_corte - t.fecha_despacho AS dias_transcurridos
FROM inventarios.transferencias t
CROSS JOIN reportes.parametros pr
JOIN inventarios.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN catalogo.almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN catalogo.sedes     so ON so.id_sede    = ao.id_sede
JOIN catalogo.almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN catalogo.sedes     sd ON sd.id_sede    = ad.id_sede
JOIN catalogo.productos p  ON p.id_producto = dt.id_producto
WHERE t.fecha_despacho IS NOT NULL
  AND t.fecha_recepcion IS NULL
  AND t.estado = 'DESPACHADA'
ORDER BY dias_transcurridos DESC, t.id_transferencia;

\echo
\echo '=== Consulta 14. Diferencias entre cantidad enviada y recibida ==='
SELECT t.id_transferencia, t.fecha_recepcion, p.nombre AS producto,
       dt.cantidad_enviada, dt.cantidad_recibida,
       dt.cantidad_recibida - dt.cantidad_enviada AS diferencia
FROM inventarios.transferencias t
JOIN inventarios.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN catalogo.productos p ON p.id_producto = dt.id_producto
WHERE dt.cantidad_recibida IS NOT NULL
  AND dt.cantidad_recibida <> dt.cantidad_enviada
ORDER BY t.id_transferencia;

\echo
\echo '=== Consulta 15. Redistribución: excedente en una sede y faltante en otra ==='
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
       LEAST(ex.existencia - ex.minimo, fa.minimo - fa.existencia) AS unidades_sugeridas
FROM stock_sede ex
JOIN stock_sede fa ON fa.id_producto = ex.id_producto AND fa.id_sede <> ex.id_sede
JOIN catalogo.productos p  ON p.id_producto = ex.id_producto
JOIN catalogo.sedes     so ON so.id_sede    = ex.id_sede
JOIN catalogo.sedes     sd ON sd.id_sede    = fa.id_sede
WHERE ex.existencia > ex.minimo
  AND fa.existencia < fa.minimo
ORDER BY unidades_sugeridas DESC, p.nombre;

\echo
\echo '=== Consulta 16. Productos de baja rotación (existencia > 0 y sin ventas en 90 días) ==='
SELECT p.sku, p.nombre AS producto, p.estado,
       SUM(i.existencia_actual) AS existencia_total,
       (SELECT MAX(pv.fecha_pedido)
        FROM reportes.vista_detalle_pedido_consolidado d
        JOIN reportes.vista_pedidos_consolidado pv ON pv.id_sede = d.id_sede AND pv.id_pedido = d.id_pedido
        WHERE d.id_producto = p.id_producto
          AND pv.estado IN ('CONFIRMADO', 'ENTREGADO')) AS ultima_venta
FROM catalogo.productos p
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
\echo '=== Consulta 17. Devoluciones por producto y categoría (periodo jul-oct 2026) ==='
WITH vendidas AS (
    SELECT d.id_producto, SUM(d.cantidad) AS vendidas
    FROM reportes.vista_detalle_pedido_consolidado d
    JOIN reportes.vista_pedidos_consolidado p ON p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido
    WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO')
      AND p.fecha_pedido BETWEEN DATE '2026-07-01' AND DATE '2026-10-15'
    GROUP BY d.id_producto
), devueltas AS (
    SELECT dd.id_producto, SUM(dd.cantidad) AS devueltas
    FROM ventas.devoluciones dv
    JOIN ventas.detalle_devolucion dd ON dd.id_devolucion = dv.id_devolucion
    JOIN reportes.vista_pedidos_consolidado p ON p.id_sede = dv.id_sede AND p.id_pedido = dv.id_pedido
    WHERE dv.estado = 'APROBADA'
      AND p.fecha_pedido BETWEEN DATE '2026-07-01' AND DATE '2026-10-15'
    GROUP BY dd.id_producto
)
SELECT c.nombre AS categoria, p.nombre AS producto,
       v.vendidas,
       COALESCE(d.devueltas, 0) AS devueltas,
       round(100.0 * COALESCE(d.devueltas, 0) / v.vendidas, 2) AS pct_devolucion,
       -- mismo cálculo agregado a nivel de categoría (función de ventana)
       round(100.0 * SUM(COALESCE(d.devueltas, 0)) OVER (PARTITION BY c.id_categoria)
             / SUM(v.vendidas) OVER (PARTITION BY c.id_categoria), 2) AS pct_devolucion_categoria
FROM vendidas v
JOIN catalogo.productos  p ON p.id_producto  = v.id_producto
JOIN catalogo.categorias c ON c.id_categoria = p.id_categoria
LEFT JOIN devueltas d ON d.id_producto = v.id_producto   -- productos sin devoluciones salen con 0 %
ORDER BY c.nombre, pct_devolucion DESC, v.vendidas DESC;

\echo
\echo '=== Consulta 18a. Productos que hay en Bogotá y NO en Cali (EXCEPT) ==='
SELECT p.sku, p.nombre
FROM catalogo.productos p
WHERE p.id_producto IN (
    SELECT id_producto FROM inventarios.inv_bogota
    EXCEPT
    SELECT id_producto FROM inventarios.inv_cali
)
ORDER BY p.sku;

\echo
\echo '=== Consulta 18b. Productos comunes a Medellín y Cali (INTERSECT) ==='
SELECT COUNT(*) AS productos_comunes
FROM (SELECT id_producto FROM inventarios.inv_medellin
      INTERSECT
      SELECT id_producto FROM inventarios.inv_cali) comunes;

\echo
\echo '=== Consulta 19. Clasificación de vendedores por sede (RANK) ==='
WITH ventas_empleado AS (
    SELECT id_sede, id_empleado, COUNT(*) AS pedidos, SUM(total_registrado) AS total_vendido
    FROM reportes.vista_pedidos_consolidado
    WHERE estado IN ('CONFIRMADO', 'ENTREGADO')
    GROUP BY id_sede, id_empleado
)
SELECT s.nombre AS sede, e.nombre_completo AS vendedor, v.pedidos, v.total_vendido,
       RANK() OVER (PARTITION BY v.id_sede ORDER BY v.total_vendido DESC) AS puesto
FROM ventas_empleado v
JOIN catalogo.sedes      s ON s.id_sede     = v.id_sede
JOIN identidad.empleados e ON e.id_empleado = v.id_empleado
ORDER BY s.id_sede, puesto;

\echo
\echo '=== Consulta 20. Consolidado corporativo por sede ==='
-- Cada fuente se agrega en su propia CTE y luego se une por sede: así un
-- pedido con varios detalles o una orden con varios productos no
-- multiplica los conteos. Es la misma lógica de reportes.vista_reporte_corporativo.
WITH inv AS (
    SELECT id_sede, SUM(existencia_actual) AS unidades_inventario
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
           SUM(total_registrado) FILTER (WHERE estado IN ('CONFIRMADO', 'ENTREGADO')) AS valor_ventas,
           COUNT(*)              FILTER (WHERE estado = 'PENDIENTE')                  AS pedidos_pendientes
    FROM reportes.vista_pedidos_consolidado
    GROUP BY id_sede
), com AS (
    SELECT a.id_sede, COUNT(DISTINCT oc.id_orden_compra) AS ordenes_compra,
           SUM(d.cantidad_solicitada * d.costo_unitario) AS valor_compras
    FROM compras.ordenes_compra oc
    JOIN compras.detalle_orden_compra d ON d.id_orden_compra = oc.id_orden_compra
    JOIN catalogo.almacenes a ON a.id_almacen = oc.id_almacen_destino
    WHERE oc.estado <> 'CANCELADA'
    GROUP BY a.id_sede
), tra AS (
    SELECT a.id_sede, COUNT(*) AS transferencias
    FROM inventarios.transferencias t
    JOIN catalogo.almacenes a ON a.id_almacen IN (t.id_almacen_origen, t.id_almacen_destino)
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
FROM catalogo.sedes s
LEFT JOIN activos ac ON ac.id_sede  = s.id_sede
LEFT JOIN inv        ON inv.id_sede = s.id_sede
LEFT JOIN ven        ON ven.id_sede = s.id_sede
LEFT JOIN com        ON com.id_sede = s.id_sede
LEFT JOIN tra        ON tra.id_sede = s.id_sede
ORDER BY s.id_sede;
