-- =====================================================================
-- 11_pruebas.sql
-- Pruebas mínimas de verificación (sección 11 del enunciado).
--
-- Todo corre dentro de una transacción que se revierte al final, así el
-- script se puede ejecutar varias veces sin alterar los datos.
--
-- Las operaciones que DEBEN fallar se ejecutan tal cual: psql muestra el
-- ERROR (esa es la evidencia del rechazo) y sigue con la siguiente.
--   ON_ERROR_STOP off    -> un error no detiene el script.
--   ON_ERROR_ROLLBACK on -> psql deshace solo la instrucción que falló,
--                           sin abortar el resto de la transacción.
-- =====================================================================

\set ON_ERROR_STOP off
\set ON_ERROR_ROLLBACK on

BEGIN;

\echo
\echo '=== Prueba 1. Crear un producto válido y consultarlo ==='
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('PAP-099', 'Agenda ejecutiva 2027', 5, 'UND', 27900);

SELECT id_producto, sku, nombre, id_categoria, precio_lista, estado
FROM catalogo.productos
WHERE sku = 'PAP-099';

\echo
\echo '=== Prueba 2. SKU duplicado (UNIQUE) -> esperado: ERROR llave duplicada ==='
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('ALI-001', 'Arroz duplicado', 1, 'KG', 5000);

\echo
\echo '=== Prueba 3. Cantidad negativa (CHECK) -> esperado: ERROR viola la restricción check ==='
INSERT INTO compras.detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
VALUES (1, 80, -5, 1000);

UPDATE inventarios.inv_bogota SET existencia_actual = -1 WHERE id_producto = 1;

\echo
\echo '=== Prueba 4. Clave foránea local inexistente (FK) -> esperado: ERROR viola la llave foránea ==='
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('XXX-001', 'Producto sin categoría', 999, 'UND', 1000);

-- Detalle de un pedido que no existe en el fragmento de Bogotá
INSERT INTO ventas.det_ped_bogota (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
VALUES (1, 99999, 1, 1, 4800);

\echo
\echo '--- 4b. Una fila de otra sede no entra en el fragmento de Bogotá -> esperado: ERROR viola la restricción check ---'
INSERT INTO inventarios.inv_bogota (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo)
VALUES (2, 2, 1, 10, 5);

\echo
\echo '=== Prueba 5. Los fragmentos de dos sedes contienen registros distintos ==='
SELECT 'inv_bogota' AS fragmento, COUNT(*) AS filas, MIN(id_sede) AS sede_min, MAX(id_sede) AS sede_max
FROM inventarios.inv_bogota
UNION ALL
SELECT 'inv_cali', COUNT(*), MIN(id_sede), MAX(id_sede)
FROM inventarios.inv_cali;

SELECT 'ped_bogota' AS fragmento, COUNT(*) AS pedidos, MIN(fecha_pedido) AS desde, MAX(fecha_pedido) AS hasta
FROM ventas.ped_bogota
UNION ALL
SELECT 'ped_cali', COUNT(*), MIN(fecha_pedido), MAX(fecha_pedido)
FROM ventas.ped_cali;

-- Ninguna fila está en dos fragmentos (intersección vacía)
SELECT COUNT(*) AS filas_repetidas_entre_fragmentos
FROM (SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_bogota
      INTERSECT
      SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_cali) x;

\echo
\echo '=== Prueba 6. La vista consolidada reúne los fragmentos de las 4 sedes ==='
SELECT fragmento, id_sede, COUNT(*) AS filas
FROM reportes.vista_inventario_consolidado
GROUP BY fragmento, id_sede
ORDER BY id_sede;

SELECT (SELECT COUNT(*) FROM reportes.vista_inventario_consolidado) AS filas_vista,
       (SELECT COUNT(*) FROM inventarios.inv_bogota) + (SELECT COUNT(*) FROM inventarios.inv_medellin)
     + (SELECT COUNT(*) FROM inventarios.inv_cali)   + (SELECT COUNT(*) FROM inventarios.inv_cedi) AS suma_fragmentos;

\echo
\echo '=== Prueba 7a. Consulta con CTE: ventas confirmadas por sede ==='
WITH ventas_sede AS (
    SELECT id_sede, SUM(total_registrado) AS total
    FROM reportes.vista_pedidos_consolidado
    WHERE estado IN ('CONFIRMADO', 'ENTREGADO')
    GROUP BY id_sede
)
SELECT s.nombre, v.total
FROM ventas_sede v JOIN catalogo.sedes s ON s.id_sede = v.id_sede
ORDER BY v.total DESC;

\echo
\echo '=== Prueba 7b. Función de ventana: participación de cada sede en las ventas ==='
SELECT sede, SUM(total_vendido) AS total,
       round(100.0 * SUM(total_vendido) / SUM(SUM(total_vendido)) OVER (), 2) AS participacion_pct,
       ROW_NUMBER() OVER (ORDER BY SUM(total_vendido) DESC) AS puesto
FROM reportes.vista_ventas_mensuales_por_sede
GROUP BY sede;

\echo
\echo '=== Prueba 8. Comparación de surtido Bogotá vs Medellín (EXCEPT / INTERSECT) ==='
SELECT 'Solo en Bogotá' AS conjunto, COUNT(*) AS productos
FROM (SELECT id_producto FROM inventarios.inv_bogota EXCEPT SELECT id_producto FROM inventarios.inv_medellin) a
UNION ALL
SELECT 'Solo en Medellín', COUNT(*)
FROM (SELECT id_producto FROM inventarios.inv_medellin EXCEPT SELECT id_producto FROM inventarios.inv_bogota) b
UNION ALL
SELECT 'En ambas', COUNT(*)
FROM (SELECT id_producto FROM inventarios.inv_bogota INTERSECT SELECT id_producto FROM inventarios.inv_medellin) c;

\echo
\echo '=== Prueba 9. Accesos permitidos y denegados por rol ==='

\echo '--- 9.1 gerente_general: SELECT sobre el reporte corporativo (PERMITIDO) ---'
SET ROLE gerente_general;
SELECT sede, valor_ventas, pedidos_pendientes FROM reportes.vista_reporte_corporativo ORDER BY id_sede;

\echo '--- 9.2 gerente_general: INSERT en ventas.pagos (DENEGADO) -> esperado: ERROR permiso denegado ---'
INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
VALUES (1, 1, DATE '2026-10-15', 1000, 'EFECTIVO', 'CONFIRMADO');
RESET ROLE;

\echo '--- 9.3 vendedor_bogota: registra un pedido en el fragmento de su sede (PERMITIDO) ---'
SET ROLE vendedor_bogota;
INSERT INTO ventas.ped_bogota (id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
VALUES (1, 5, 3, DATE '2026-10-15', 'PENDIENTE', 9600)
RETURNING id_sede, id_pedido, estado, total_registrado;

INSERT INTO ventas.det_ped_bogota (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT 1, MAX(id_pedido), 1, 2, 4800 FROM ventas.ped_bogota;

\echo '--- 9.4 vendedor_bogota: consulta pedidos de Cali (DENEGADO) -> esperado: ERROR permiso denegado ---'
SELECT COUNT(*) FROM ventas.ped_cali;

\echo '--- 9.5 vendedor_bogota: modifica el precio de un producto del catálogo (DENEGADO) -> esperado: ERROR permiso denegado ---'
UPDATE catalogo.productos SET precio_lista = 1 WHERE id_producto = 1;

\echo '--- 9.6 vendedor_bogota: borra un pago (DENEGADO por el REVOKE DELETE) -> esperado: ERROR permiso denegado ---'
DELETE FROM ventas.pagos WHERE id_pago = 1;
RESET ROLE;

\echo '--- 9.7 inventario_cedi: actualiza su fragmento (PERMITIDO) y el de Bogotá (DENEGADO -> esperado: ERROR permiso denegado) ---'
SET ROLE inventario_cedi;
UPDATE inventarios.inv_cedi SET existencia_actual = existencia_actual + 10, fecha_actualizacion = now()
WHERE id_almacen = 4 AND id_producto = 1
RETURNING id_sede, id_almacen, id_producto, existencia_actual;

UPDATE inventarios.inv_bogota SET existencia_actual = 0 WHERE id_producto = 1;
RESET ROLE;

\echo '--- 9.8 auditor_interno: lee todo, pero leer password_hash y modificar -> esperado: ERROR permiso denegado ---'
SET ROLE auditor_interno;
SELECT nombre_usuario, rol, estado FROM identidad.usuarios ORDER BY id_usuario LIMIT 3;

SELECT password_hash FROM identidad.usuarios LIMIT 1;

UPDATE compras.ordenes_compra SET estado = 'CANCELADA' WHERE id_orden_compra = 1;
RESET ROLE;

\echo '--- 9.9 Privilegios efectivos (has_table_privilege) ---'
SELECT r.rol, t.tabla, op.operacion, has_table_privilege(r.rol, t.tabla, op.operacion) AS permitido
FROM (VALUES ('gerente_general'), ('vendedor_bogota'), ('inventario_cedi'), ('compras_cedi'), ('auditor_interno')) r(rol)
CROSS JOIN (VALUES ('ventas.ped_bogota'), ('inventarios.inv_cedi'), ('compras.ordenes_compra'),
                   ('reportes.vista_reporte_corporativo')) t(tabla)
CROSS JOIN (VALUES ('SELECT'), ('INSERT')) op(operacion)
ORDER BY r.rol, t.tabla, op.operacion;

\echo
\echo '=== Prueba 10. El reporte corporativo no duplica ventas ni cantidades ==='
-- Se compara cada total del reporte con el mismo total calculado
-- directamente sobre la fuente; reporte y fuente deben ser iguales.
SELECT 'valor_ventas' AS medida,
       (SELECT SUM(valor_ventas) FROM reportes.vista_reporte_corporativo) AS reporte,
       (SELECT SUM(total_registrado) FROM reportes.vista_pedidos_consolidado WHERE estado IN ('CONFIRMADO', 'ENTREGADO')) AS fuente
UNION ALL
SELECT 'unidades_inventario',
       (SELECT SUM(unidades_inventario) FROM reportes.vista_reporte_corporativo),
       (SELECT SUM(existencia_actual) FROM reportes.vista_inventario_consolidado)
UNION ALL
SELECT 'ordenes_compra',
       (SELECT SUM(ordenes_compra) FROM reportes.vista_reporte_corporativo),
       (SELECT COUNT(*) FROM compras.ordenes_compra WHERE estado <> 'CANCELADA')
UNION ALL
SELECT 'pedidos_pendientes',
       (SELECT SUM(pedidos_pendientes) FROM reportes.vista_reporte_corporativo),
       (SELECT COUNT(*) FROM reportes.vista_pedidos_consolidado WHERE estado = 'PENDIENTE');

\echo '--- Contraejemplo: unir todo en un solo JOIN SÍ duplica el valor de ventas ---'
SELECT SUM(p.total_registrado) AS ventas_duplicadas_por_join
FROM reportes.vista_pedidos_consolidado p
JOIN reportes.vista_detalle_pedido_consolidado d ON d.id_sede = p.id_sede AND d.id_pedido = p.id_pedido
WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO');

\echo
\echo '=== Prueba extra. Referencias sin FK declarada (cada fila debe dar 0) ==='
SELECT 'compras.ordenes_compra.id_proveedor' AS referencia, COUNT(*) AS huerfanos
FROM compras.ordenes_compra o
WHERE NOT EXISTS (SELECT 1 FROM catalogo.proveedores p WHERE p.id_proveedor = o.id_proveedor)
UNION ALL
SELECT 'compras.ordenes_compra.id_empleado', COUNT(*)
FROM compras.ordenes_compra o
WHERE NOT EXISTS (SELECT 1 FROM identidad.empleados e WHERE e.id_empleado = o.id_empleado)
UNION ALL
SELECT 'compras.detalle_orden_compra.id_producto', COUNT(*)
FROM compras.detalle_orden_compra d
WHERE NOT EXISTS (SELECT 1 FROM catalogo.productos p WHERE p.id_producto = d.id_producto)
UNION ALL
SELECT 'inventarios.inv_*.id_almacen (y su sede)', COUNT(*)
FROM reportes.vista_inventario_consolidado i
WHERE NOT EXISTS (SELECT 1 FROM catalogo.almacenes a WHERE a.id_almacen = i.id_almacen AND a.id_sede = i.id_sede)
UNION ALL
SELECT 'inventarios.detalle_transferencia.id_producto', COUNT(*)
FROM inventarios.detalle_transferencia d
WHERE NOT EXISTS (SELECT 1 FROM catalogo.productos p WHERE p.id_producto = d.id_producto)
UNION ALL
SELECT 'ventas.ped_*.id_cliente', COUNT(*)
FROM reportes.vista_pedidos_consolidado v
WHERE NOT EXISTS (SELECT 1 FROM catalogo.clientes c WHERE c.id_cliente = v.id_cliente)
UNION ALL
SELECT 'ventas.ped_*.id_almacen (de su sede)', COUNT(*)
FROM reportes.vista_pedidos_consolidado v
WHERE NOT EXISTS (SELECT 1 FROM catalogo.almacenes a WHERE a.id_almacen = v.id_almacen AND a.id_sede = v.id_sede)
UNION ALL
SELECT 'ventas.ped_*.id_empleado (de su sede)', COUNT(*)
FROM reportes.vista_pedidos_consolidado v
WHERE NOT EXISTS (SELECT 1 FROM identidad.empleados e WHERE e.id_empleado = v.id_empleado AND e.id_sede = v.id_sede)
UNION ALL
SELECT 'ventas.det_ped_*.id_producto', COUNT(*)
FROM reportes.vista_detalle_pedido_consolidado d
WHERE NOT EXISTS (SELECT 1 FROM catalogo.productos p WHERE p.id_producto = d.id_producto)
UNION ALL
SELECT 'ventas.pagos (id_sede, id_pedido)', COUNT(*)
FROM ventas.pagos g
WHERE NOT EXISTS (SELECT 1 FROM reportes.vista_pedidos_consolidado v
                  WHERE v.id_sede = g.id_sede AND v.id_pedido = g.id_pedido)
UNION ALL
SELECT 'ventas.devoluciones (id_sede, id_pedido)', COUNT(*)
FROM ventas.devoluciones dv
WHERE NOT EXISTS (SELECT 1 FROM reportes.vista_pedidos_consolidado v
                  WHERE v.id_sede = dv.id_sede AND v.id_pedido = dv.id_pedido)
UNION ALL
SELECT 'ventas.detalle_devolucion: producto del pedido', COUNT(*)
FROM ventas.detalle_devolucion dd
JOIN ventas.devoluciones dv ON dv.id_devolucion = dd.id_devolucion
WHERE NOT EXISTS (SELECT 1 FROM reportes.vista_detalle_pedido_consolidado d
                  WHERE d.id_sede = dv.id_sede AND d.id_pedido = dv.id_pedido
                    AND d.id_producto = dd.id_producto)
UNION ALL
SELECT 'identidad.empleados.id_sede', COUNT(*)
FROM identidad.empleados e
WHERE NOT EXISTS (SELECT 1 FROM catalogo.sedes s WHERE s.id_sede = e.id_sede);

ROLLBACK;

\echo
\echo '--- Volumen de datos de prueba (después del ROLLBACK, sin las filas de las pruebas) ---'
SELECT 'sedes' AS tabla, COUNT(*) FROM catalogo.sedes
UNION ALL SELECT 'almacenes', COUNT(*) FROM catalogo.almacenes
UNION ALL SELECT 'categorias', COUNT(*) FROM catalogo.categorias
UNION ALL SELECT 'productos', COUNT(*) FROM catalogo.productos
UNION ALL SELECT 'proveedores', COUNT(*) FROM catalogo.proveedores
UNION ALL SELECT 'clientes', COUNT(*) FROM catalogo.clientes
UNION ALL SELECT 'empleados', COUNT(*) FROM identidad.empleados
UNION ALL SELECT 'pedidos_venta', COUNT(*) FROM reportes.vista_pedidos_consolidado
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM reportes.vista_detalle_pedido_consolidado
UNION ALL SELECT 'pagos', COUNT(*) FROM ventas.pagos
UNION ALL SELECT 'devoluciones', COUNT(*) FROM ventas.devoluciones
UNION ALL SELECT 'ordenes_compra', COUNT(*) FROM compras.ordenes_compra
UNION ALL SELECT 'recepciones_compra', COUNT(*) FROM compras.recepciones_compra
UNION ALL SELECT 'transferencias', COUNT(*) FROM inventarios.transferencias
UNION ALL SELECT 'inventarios', COUNT(*) FROM reportes.vista_inventario_consolidado;


\set ON_ERROR_ROLLBACK off
\set ON_ERROR_STOP on
