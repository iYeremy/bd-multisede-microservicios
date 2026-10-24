-- =====================================================================
-- 11_pruebas.sql
-- Pruebas mínimas de verificación (sección 11 del enunciado).
--
-- Todo corre dentro de una transacción que se revierte al final, así el
-- script se puede ejecutar varias veces sin alterar los datos.
-- Las operaciones que DEBEN fallar van dentro de bloques DO que capturan
-- el error y lo muestran como NOTICE (resultado esperado = rechazo).
-- =====================================================================

BEGIN;

\echo
\echo '=== Prueba 1. Crear un producto válido y consultarlo ==='
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('PAP-099', 'Agenda ejecutiva 2027', 5, 'UND', 27900);

SELECT id_producto, sku, nombre, id_categoria, precio_lista, estado
FROM catalogo.productos
WHERE sku = 'PAP-099';

\echo
\echo '=== Prueba 2. SKU duplicado (UNIQUE) -> debe rechazarse ==='
DO $$
BEGIN
    INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
    VALUES ('ALI-001', 'Arroz duplicado', 1, 'KG', 5000);
    RAISE NOTICE 'FALLO: se aceptó un SKU duplicado';
EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK, rechazado (%): %', SQLSTATE, SQLERRM;
END $$;

\echo
\echo '=== Prueba 3. Cantidad negativa (CHECK) -> debe rechazarse ==='
DO $$
BEGIN
    INSERT INTO compras.detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
    VALUES (1, 80, -5, 1000);
    RAISE NOTICE 'FALLO: se aceptó una cantidad negativa';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK, rechazado (%): %', SQLSTATE, SQLERRM;
END $$;

DO $$
BEGIN
    UPDATE inventarios.inv_bogota SET existencia_actual = -1 WHERE id_producto = 1;
    RAISE NOTICE 'FALLO: se aceptó existencia negativa';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK, rechazado (%): %', SQLSTATE, SQLERRM;
END $$;

\echo
\echo '=== Prueba 4. Clave foránea local inexistente (FK) -> debe rechazarse ==='
DO $$
BEGIN
    INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
    VALUES ('XXX-001', 'Producto sin categoría', 999, 'UND', 1000);
    RAISE NOTICE 'FALLO: se aceptó una categoría inexistente';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK, rechazado (%): %', SQLSTATE, SQLERRM;
END $$;

DO $$
BEGIN
    INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
    VALUES (1, 99999, DATE '2026-10-15', 10000, 'EFECTIVO', 'CONFIRMADO');
    RAISE NOTICE 'FALLO: se aceptó un pago de un pedido inexistente';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK, rechazado (%): %', SQLSTATE, SQLERRM;
END $$;

\echo
\echo '--- 4b. Una fila con una sede sin fragmento no tiene dónde guardarse ---'
DO $$
BEGIN
    INSERT INTO inventarios.inventarios (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo)
    VALUES (9, 1, 1, 10, 5);
    RAISE NOTICE 'FALLO: se aceptó una sede sin fragmento';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK, rechazado (%): %', SQLSTATE, SQLERRM;
END $$;

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

\echo '--- 9.2 gerente_general: INSERT en ventas.pagos (DENEGADO) ---'
DO $$
BEGIN
    INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
    VALUES (1, 1, DATE '2026-10-15', 1000, 'EFECTIVO', 'CONFIRMADO');
    RAISE NOTICE 'FALLO: gerencia pudo insertar un pago';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, denegado (%): %', SQLSTATE, SQLERRM;
END $$;
RESET ROLE;

\echo '--- 9.3 vendedor_bogota: registra un pedido en el fragmento de su sede (PERMITIDO) ---'
SET ROLE vendedor_bogota;
INSERT INTO ventas.ped_bogota (id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
VALUES (1, 5, 3, DATE '2026-10-15', 'PENDIENTE', 9600)
RETURNING id_sede, id_pedido, estado, total_registrado;

INSERT INTO ventas.det_ped_bogota (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT 1, MAX(id_pedido), 1, 2, 4800 FROM ventas.ped_bogota;

\echo '--- 9.4 vendedor_bogota: consulta pedidos de Cali (DENEGADO) ---'
DO $$
BEGIN
    PERFORM COUNT(*) FROM ventas.ped_cali;
    RAISE NOTICE 'FALLO: el vendedor de Bogotá pudo leer pedidos de Cali';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, denegado (%): %', SQLSTATE, SQLERRM;
END $$;

\echo '--- 9.5 vendedor_bogota: modifica el precio de un producto del catálogo (DENEGADO) ---'
DO $$
BEGIN
    UPDATE catalogo.productos SET precio_lista = 1 WHERE id_producto = 1;
    RAISE NOTICE 'FALLO: el vendedor pudo modificar el catálogo';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, denegado (%): %', SQLSTATE, SQLERRM;
END $$;

\echo '--- 9.6 vendedor_bogota: borra un pago (DENEGADO por el REVOKE DELETE) ---'
DO $$
BEGIN
    DELETE FROM ventas.pagos WHERE id_pago = 1;
    RAISE NOTICE 'FALLO: el vendedor pudo borrar un pago';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, denegado (%): %', SQLSTATE, SQLERRM;
END $$;
RESET ROLE;

\echo '--- 9.7 inventario_cedi: actualiza su fragmento (PERMITIDO) y el de Bogotá (DENEGADO) ---'
SET ROLE inventario_cedi;
UPDATE inventarios.inv_cedi SET existencia_actual = existencia_actual + 10, fecha_actualizacion = now()
WHERE id_almacen = 4 AND id_producto = 1
RETURNING id_sede, id_almacen, id_producto, existencia_actual;

DO $$
BEGIN
    UPDATE inventarios.inv_bogota SET existencia_actual = 0 WHERE id_producto = 1;
    RAISE NOTICE 'FALLO: inventario_cedi pudo modificar Bogotá';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, denegado (%): %', SQLSTATE, SQLERRM;
END $$;
RESET ROLE;

\echo '--- 9.8 auditor_interno: lee todo pero no ve password_hash ni puede modificar ---'
SET ROLE auditor_interno;
SELECT nombre_usuario, rol, estado FROM identidad.usuarios ORDER BY id_usuario LIMIT 3;

DO $$
BEGIN
    PERFORM password_hash FROM identidad.usuarios;
    RAISE NOTICE 'FALLO: el auditor pudo leer password_hash';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, denegado (%): %', SQLSTATE, SQLERRM;
END $$;

DO $$
BEGIN
    UPDATE compras.ordenes_compra SET estado = 'CANCELADA' WHERE id_orden_compra = 1;
    RAISE NOTICE 'FALLO: el auditor pudo modificar una orden';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK, denegado (%): %', SQLSTATE, SQLERRM;
END $$;
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
-- directamente sobre la fuente; la columna coincide debe ser verdadera.
SELECT 'valor_ventas' AS medida,
       (SELECT SUM(valor_ventas) FROM reportes.vista_reporte_corporativo) AS reporte,
       (SELECT SUM(total_registrado) FROM ventas.pedidos_venta WHERE estado IN ('CONFIRMADO', 'ENTREGADO')) AS fuente
UNION ALL
SELECT 'unidades_inventario',
       (SELECT SUM(unidades_inventario) FROM reportes.vista_reporte_corporativo),
       (SELECT SUM(existencia_actual) FROM inventarios.inventarios)
UNION ALL
SELECT 'ordenes_compra',
       (SELECT SUM(ordenes_compra) FROM reportes.vista_reporte_corporativo),
       (SELECT COUNT(*) FROM compras.ordenes_compra WHERE estado <> 'CANCELADA')
UNION ALL
SELECT 'pedidos_pendientes',
       (SELECT SUM(pedidos_pendientes) FROM reportes.vista_reporte_corporativo),
       (SELECT COUNT(*) FROM ventas.pedidos_venta WHERE estado = 'PENDIENTE');

\echo '--- Contraejemplo: unir todo en un solo JOIN SÍ duplica el valor de ventas ---'
SELECT SUM(p.total_registrado) AS ventas_duplicadas_por_join
FROM ventas.pedidos_venta p
JOIN ventas.detalle_pedido d ON d.id_sede = p.id_sede AND d.id_pedido = p.id_pedido
WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO');

\echo
\echo '=== Prueba extra. Identificadores compartidos sin FK (cada fila debe dar 0) ==='
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
SELECT 'inventarios.inventarios.id_almacen (y su sede)', COUNT(*)
FROM inventarios.inventarios i
WHERE NOT EXISTS (SELECT 1 FROM catalogo.almacenes a WHERE a.id_almacen = i.id_almacen AND a.id_sede = i.id_sede)
UNION ALL
SELECT 'inventarios.detalle_transferencia.id_producto', COUNT(*)
FROM inventarios.detalle_transferencia d
WHERE NOT EXISTS (SELECT 1 FROM catalogo.productos p WHERE p.id_producto = d.id_producto)
UNION ALL
SELECT 'ventas.pedidos_venta.id_cliente', COUNT(*)
FROM ventas.pedidos_venta v
WHERE NOT EXISTS (SELECT 1 FROM catalogo.clientes c WHERE c.id_cliente = v.id_cliente)
UNION ALL
SELECT 'ventas.pedidos_venta.id_almacen (de su sede)', COUNT(*)
FROM ventas.pedidos_venta v
WHERE NOT EXISTS (SELECT 1 FROM catalogo.almacenes a WHERE a.id_almacen = v.id_almacen AND a.id_sede = v.id_sede)
UNION ALL
SELECT 'ventas.pedidos_venta.id_empleado (de su sede)', COUNT(*)
FROM ventas.pedidos_venta v
WHERE NOT EXISTS (SELECT 1 FROM identidad.empleados e WHERE e.id_empleado = v.id_empleado AND e.id_sede = v.id_sede)
UNION ALL
SELECT 'ventas.detalle_pedido.id_producto', COUNT(*)
FROM ventas.detalle_pedido d
WHERE NOT EXISTS (SELECT 1 FROM catalogo.productos p WHERE p.id_producto = d.id_producto)
UNION ALL
SELECT 'identidad.empleados.id_sede', COUNT(*)
FROM identidad.empleados e
WHERE NOT EXISTS (SELECT 1 FROM catalogo.sedes s WHERE s.id_sede = e.id_sede);

\echo
\echo '--- Volumen de datos de prueba ---'
SELECT 'sedes' AS tabla, COUNT(*) FROM catalogo.sedes
UNION ALL SELECT 'almacenes', COUNT(*) FROM catalogo.almacenes
UNION ALL SELECT 'categorias', COUNT(*) FROM catalogo.categorias
UNION ALL SELECT 'productos', COUNT(*) FROM catalogo.productos
UNION ALL SELECT 'proveedores', COUNT(*) FROM catalogo.proveedores
UNION ALL SELECT 'clientes', COUNT(*) FROM catalogo.clientes
UNION ALL SELECT 'empleados', COUNT(*) FROM identidad.empleados
UNION ALL SELECT 'pedidos_venta', COUNT(*) FROM ventas.pedidos_venta
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM ventas.detalle_pedido
UNION ALL SELECT 'pagos', COUNT(*) FROM ventas.pagos
UNION ALL SELECT 'devoluciones', COUNT(*) FROM ventas.devoluciones
UNION ALL SELECT 'ordenes_compra', COUNT(*) FROM compras.ordenes_compra
UNION ALL SELECT 'recepciones_compra', COUNT(*) FROM compras.recepciones_compra
UNION ALL SELECT 'transferencias', COUNT(*) FROM inventarios.transferencias
UNION ALL SELECT 'inventarios', COUNT(*) FROM inventarios.inventarios;

ROLLBACK;
