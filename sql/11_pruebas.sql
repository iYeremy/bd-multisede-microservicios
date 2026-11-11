-- =====================================================================
-- 11_pruebas.sql
-- pruebas minimas de verificacion (seccion 11 del enunciado).
--
-- ahora cada servicio tiene su base, asi que las pruebas van por partes:
-- cada parte se conecta (\c) a la base donde esta lo que prueba, por eso
-- los numeros no van en orden (la prueba 9 de permisos esta repartida en
-- varias bases). al final hay dos pruebas nuevas: la 11 muestra que una
-- base no puede leer las tablas de otra, y la 12 muestra el ETL: un
-- pedido nuevo no aparece en los reportes hasta que corre el ETL.
--
-- cada parte va entre BEGIN y ROLLBACK: lo que se inserta o cambia se
-- deshace al final, asi el script se puede correr las veces que sea sin
-- ensuciar los datos. (una transaccion no puede abarcar dos bases, por
-- eso hay un BEGIN ... ROLLBACK por base.)
--
-- varias pruebas DEBEN fallar (SKU repetido, permiso denegado...). el
-- ERROR que muestra psql es justo la prueba de que la base lo rechazo.
-- para que un error no tumbe todo se usan dos opciones de psql:
--   ON_ERROR_STOP off     si algo falla, sigue con lo siguiente.
--   ON_ERROR_ROLLBACK on  deshace solo la instruccion que fallo; sin
--                         esto, un error dentro de BEGIN rompe toda la
--                         transaccion y todo lo que sigue tambien falla.
--
-- SET ROLE hace que la sesion actue como ese usuario, con sus permisos
-- (sin tener que conectarse de nuevo). RESET ROLE vuelve a ser postgres.
-- =====================================================================

\set ON_ERROR_STOP off
\set ON_ERROR_ROLLBACK on

-- ---------------------------------------------------------------------
-- base andina_catalogo: pruebas 1, 2, 4 y 9.5
-- ---------------------------------------------------------------------
\c andina_catalogo
BEGIN;

\echo
\echo '=== Prueba 1. Crear un producto valido y consultarlo ==='
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('PAP-099', 'Agenda ejecutiva 2027', 5, 'UND', 27900);

SELECT id_producto, sku, nombre, id_categoria, precio_lista, estado
FROM catalogo.productos
WHERE sku = 'PAP-099';

\echo
\echo '=== Prueba 2. SKU duplicado (UNIQUE) -> esperado: ERROR llave duplicada ==='
-- ALI-001 ya existe
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('ALI-001', 'Arroz duplicado', 1, 'KG', 5000);

\echo
\echo '=== Prueba 4. Clave foranea local inexistente (FK) -> esperado: ERROR viola la llave foranea ==='
-- la categoria 999 no existe
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista)
VALUES ('XXX-001', 'Producto sin categoría', 999, 'UND', 1000);

\echo
\echo '=== Prueba 9. Accesos permitidos y denegados por rol (por partes, en cada base) ==='
\echo '--- 9.5 vendedor_bogota: modifica el precio de un producto del catalogo (DENEGADO) -> esperado: ERROR permiso denegado ---'
-- ventas no puede tocar tablas de catalogo (RN-39). el vendedor si entra
-- a andina_catalogo, pero solo para leer productos y clientes.
SET ROLE vendedor_bogota;
UPDATE catalogo.productos SET precio_lista = 1 WHERE id_producto = 1;

RESET ROLE;

ROLLBACK;

-- ---------------------------------------------------------------------
-- base andina_compras: prueba 3 (cantidad negativa) y 9.8b
-- ---------------------------------------------------------------------
\c andina_compras
BEGIN;

\echo
\echo '=== Prueba 3. Cantidad negativa (CHECK) -> esperado: ERROR viola la restriccion check ==='
-- una cantidad pedida negativa (la existencia negativa se prueba en
-- inventarios, 3b)
INSERT INTO compras.detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
VALUES (1, 80, -5, 1000);

\echo '--- 9.8b auditor_interno: modificar una orden de compra -> esperado: ERROR permiso denegado ---'
SET ROLE auditor_interno;
UPDATE compras.ordenes_compra SET estado = 'CANCELADA' WHERE id_orden_compra = 1;
RESET ROLE;

ROLLBACK;

-- ---------------------------------------------------------------------
-- base andina_inventarios: pruebas 3, 4b, 5, 8 y 9.7
-- ---------------------------------------------------------------------
\c andina_inventarios
BEGIN;

\echo
\echo '--- 3b. Existencia negativa (CHECK) -> esperado: ERROR viola la restriccion check ---'
UPDATE inventarios.inv_bogota SET existencia_actual = -1 WHERE id_producto = 1;

\echo
\echo '--- 4b. Una fila de otra sede no entra en el fragmento de Bogota -> esperado: ERROR viola la restriccion check ---'
-- id_sede = 2 en inv_bogota: el CHECK (id_sede = 1) la rechaza
INSERT INTO inventarios.inv_bogota (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo)
VALUES (2, 2, 1, 10, 5);

\echo
\echo '=== Prueba 5. Los fragmentos de dos sedes contienen registros distintos ==='
-- cada fragmento solo tiene su sede (sede_min = sede_max)
SELECT 'inv_bogota' AS fragmento, COUNT(*) AS filas, MIN(id_sede) AS sede_min, MAX(id_sede) AS sede_max
FROM inventarios.inv_bogota
UNION ALL
SELECT 'inv_cali', COUNT(*), MIN(id_sede), MAX(id_sede)
FROM inventarios.inv_cali;

-- ninguna fila esta en dos fragmentos: la interseccion da 0
SELECT COUNT(*) AS filas_repetidas_entre_fragmentos
FROM (SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_bogota
      INTERSECT
      SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_cali) x;

\echo
\echo '=== Prueba 8. Comparacion de surtido Bogota vs Medellin (EXCEPT / INTERSECT) ==='
-- cuantos productos tiene solo una sede, solo la otra, o las dos
SELECT 'Solo en Bogota' AS conjunto, COUNT(*) AS productos
FROM (SELECT id_producto FROM inventarios.inv_bogota EXCEPT SELECT id_producto FROM inventarios.inv_medellin) a
UNION ALL
SELECT 'Solo en Medellin', COUNT(*)
FROM (SELECT id_producto FROM inventarios.inv_medellin EXCEPT SELECT id_producto FROM inventarios.inv_bogota) b
UNION ALL
SELECT 'En ambas', COUNT(*)
FROM (SELECT id_producto FROM inventarios.inv_bogota INTERSECT SELECT id_producto FROM inventarios.inv_medellin) c;

\echo '--- 9.7 inventario_cedi: actualiza su fragmento (PERMITIDO) y el de Bogota (DENEGADO -> esperado: ERROR permiso denegado) ---'
SET ROLE inventario_cedi;
UPDATE inventarios.inv_cedi SET existencia_actual = existencia_actual + 10, fecha_actualizacion = now()
WHERE id_almacen = 4 AND id_producto = 1
RETURNING id_sede, id_almacen, id_producto, existencia_actual;

UPDATE inventarios.inv_bogota SET existencia_actual = 0 WHERE id_producto = 1;
RESET ROLE;

ROLLBACK;

-- ---------------------------------------------------------------------
-- base andina_ventas: pruebas 4, 5, 9.2, 9.3, 9.4 y 9.6
-- ---------------------------------------------------------------------
\c andina_ventas
BEGIN;

\echo
\echo '--- 4c. Detalle de un pedido que no existe (FK compuesta) -> esperado: ERROR viola la llave foranea ---'
-- detalle de un pedido que no existe en el fragmento de bogota
-- (la FK compuesta det_ped_bogota -> ped_bogota lo rechaza)
INSERT INTO ventas.det_ped_bogota (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
VALUES (1, 99999, 1, 1, 4800);

\echo
\echo '--- 5b. Fragmentos de pedidos de dos sedes ---'
SELECT 'ped_bogota' AS fragmento, COUNT(*) AS pedidos, MIN(fecha_pedido) AS desde, MAX(fecha_pedido) AS hasta
FROM ventas.ped_bogota
UNION ALL
SELECT 'ped_cali', COUNT(*), MIN(fecha_pedido), MAX(fecha_pedido)
FROM ventas.ped_cali;

\echo '--- 9.2 gerente_general: INSERT en ventas.pagos (DENEGADO) -> esperado: ERROR permiso denegado ---'
-- gerente_general ni siquiera tiene CONNECT a andina_ventas (no podria
-- conectarse); con SET ROLE se ve que tampoco tiene permiso en la tabla.
SET ROLE gerente_general;
INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
VALUES (1, 1, DATE '2026-10-15', 1000, 'EFECTIVO', 'CONFIRMADO');
RESET ROLE;

\echo '--- 9.3 vendedor_bogota: registra un pedido en el fragmento de su sede (PERMITIDO) ---'
-- no se indica id_sede ni id_pedido: el DEFAULT pone la sede 1 y el
-- IDENTITY el siguiente numero. RETURNING muestra lo que se inserto.
SET ROLE vendedor_bogota;
INSERT INTO ventas.ped_bogota (id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
VALUES (1, 5, 3, DATE '2026-10-15', 'PENDIENTE', 9600)
RETURNING id_sede, id_pedido, estado, total_registrado;

INSERT INTO ventas.det_ped_bogota (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT 1, MAX(id_pedido), 1, 2, 4800 FROM ventas.ped_bogota;

\echo '--- 9.4 vendedor_bogota: consulta pedidos de Cali (DENEGADO) -> esperado: ERROR permiso denegado ---'
SELECT COUNT(*) FROM ventas.ped_cali;

\echo '--- 9.6 vendedor_bogota: borra un pago (DENEGADO por el REVOKE DELETE) -> esperado: ERROR permiso denegado ---'
DELETE FROM ventas.pagos WHERE id_pago = 1;
RESET ROLE;

ROLLBACK;

-- ---------------------------------------------------------------------
-- base andina_identidad: prueba 9.8
-- ---------------------------------------------------------------------
\c andina_identidad
BEGIN;

\echo '--- 9.8 auditor_interno: lee todo, pero leer password_hash -> esperado: ERROR permiso denegado ---'
-- el primer SELECT funciona; el de password_hash falla
SET ROLE auditor_interno;
SELECT nombre_usuario, rol, estado FROM identidad.usuarios ORDER BY id_usuario LIMIT 3;

SELECT password_hash FROM identidad.usuarios LIMIT 1;

RESET ROLE;

ROLLBACK;

-- ---------------------------------------------------------------------
-- base andina_reportes: pruebas 6, 7, 9.1, 10 y la de referencias sin FK
-- aqui esta el staging con los datos de todos los servicios, por eso es
-- el unico lugar donde se pueden cruzar (y revisar los huerfanos).
-- ---------------------------------------------------------------------
\c andina_reportes
BEGIN;

\echo '=== Prueba 6. La vista consolidada reune los fragmentos de las 4 sedes ==='
-- salen las 4 sedes y el total de la vista es igual a la suma de los
-- 4 fragmentos (no falta ni sobra nada)
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
\echo '=== Prueba 7b. Funcion de ventana: participacion de cada sede en las ventas ==='
-- SUM(SUM(...)) OVER () es el total de todas las sedes juntas, para
-- sacar el % de cada una
SELECT sede, SUM(total_vendido) AS total,
       round(100.0 * SUM(total_vendido) / SUM(SUM(total_vendido)) OVER (), 2) AS participacion_pct,
       ROW_NUMBER() OVER (ORDER BY SUM(total_vendido) DESC) AS puesto
FROM reportes.vista_ventas_mensuales_por_sede
GROUP BY sede;

\echo
\echo '--- 9.1 gerente_general: SELECT sobre el reporte corporativo (PERMITIDO) ---'
SET ROLE gerente_general;
SELECT sede, valor_ventas, pedidos_pendientes FROM reportes.vista_reporte_corporativo ORDER BY id_sede;

\echo '--- 9.1b gerente_general: leer el staging de ventas en reportes (DENEGADO) -> esperado: ERROR permiso denegado ---'
-- ve el reporte, pero no las tablas que hay debajo
SELECT COUNT(*) FROM ventas.ped_bogota;
RESET ROLE;


\echo
\echo '=== Prueba 10. El reporte corporativo no duplica ventas ni cantidades ==='
-- cada total del reporte se compara con el mismo total sacado
-- directo de la fuente: si son iguales, el reporte no duplico nada
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

\echo '--- Contraejemplo: unir todo en un solo JOIN SI duplica el valor de ventas ---'
-- cada pedido se repite una vez por cada producto que tiene, asi que su
-- total se suma varias veces. por eso el reporte usa una CTE por fuente.
SELECT SUM(p.total_registrado) AS ventas_duplicadas_por_join
FROM reportes.vista_pedidos_consolidado p
JOIN reportes.vista_detalle_pedido_consolidado d ON d.id_sede = p.id_sede AND d.id_pedido = p.id_pedido
WHERE p.estado IN ('CONFIRMADO', 'ENTREGADO');

\echo
\echo '=== Prueba extra. Referencias sin FK declarada (cada fila debe dar 0) ==='
-- como entre servicios no hay FK, la base no impide un id que no
-- exista. aqui se revisa a mano: NOT EXISTS cuenta las filas que
-- apuntan a algo inexistente (huerfanos). todas deben dar 0.
-- las que dicen "de su sede" revisan tambien que el almacen o el
-- empleado sean de la misma sede que la fila.
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
\echo '=== Prueba 11. Cada servicio solo ve su propia base ==='
-- conectados a ventas, las tablas de catalogo no existen: viven en otra
-- base. esto es lo que obliga a que ventas le pida los datos al
-- servicio de catalogo (y a que reportes reciba los datos por un ETL).
\c andina_ventas
\echo '--- 11.1 desde andina_ventas: leer catalogo.productos -> esperado: ERROR la relacion no existe ---'
SELECT COUNT(*) FROM catalogo.productos;

\echo '--- 11.2 nombrando la otra base (base.esquema.tabla) -> esperado: ERROR no estan implementadas las referencias entre bases ---'
SELECT COUNT(*) FROM andina_catalogo.catalogo.productos;

\echo '--- 11.3 a que base puede entrar cada rol (has_database_privilege) ---'
-- has_database_privilege(rol, base, 'CONNECT') responde true o false.
-- se compara con la matriz de 09_roles.sql.
SELECT r.rol,
       has_database_privilege(r.rol, 'andina_catalogo',    'CONNECT') AS catalogo,
       has_database_privilege(r.rol, 'andina_identidad',   'CONNECT') AS identidad,
       has_database_privilege(r.rol, 'andina_compras',     'CONNECT') AS compras,
       has_database_privilege(r.rol, 'andina_inventarios', 'CONNECT') AS inventarios,
       has_database_privilege(r.rol, 'andina_ventas',      'CONNECT') AS ventas,
       has_database_privilege(r.rol, 'andina_reportes',    'CONNECT') AS reportes
FROM (VALUES ('gerente_general'), ('vendedor_bogota'), ('inventario_cedi'), ('compras_cedi'),
             ('auditor_interno'), ('svc_ventas'), ('svc_reportes')) r(rol)
ORDER BY r.rol;

\echo
\echo '=== Prueba 12. ETL: los reportes van atrasados hasta que corre el ETL (consistencia eventual) ==='
-- la idea: un pedido nuevo se guarda en andina_ventas, pero los reportes
-- no lo ven hasta que el ETL lo lleva a reportes y refresca las vistas
-- materializadas.
-- esta prueba NO va en BEGIN ... ROLLBACK: el ETL tiene que ver el
-- pedido guardado de verdad. al final se borra y se corre el ETL otra
-- vez, asi los datos quedan como estaban.

\echo '--- 12.1 antes: pedidos de Bogota que ve el reporte ---'
\c andina_reportes
SELECT COUNT(*) AS pedidos_bogota_en_reporte
FROM reportes.vista_pedidos_consolidado
WHERE id_sede = 1;

\echo '--- 12.2 se registra un pedido nuevo en andina_ventas (queda guardado) ---'
-- \gset guarda el id_pedido que devuelve RETURNING en la variable de
-- psql :pedido_prueba, para poder borrarlo al final
\c andina_ventas
INSERT INTO ventas.ped_bogota (id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
VALUES (1, 5, 3, DATE '2026-10-15', 'PENDIENTE', 0)
RETURNING id_pedido AS pedido_prueba \gset
SELECT COUNT(*) AS pedidos_bogota_en_ventas FROM ventas.ped_bogota;

\echo '--- 12.3 el reporte todavia NO lo ve: sigue con la ultima carga ---'
\c andina_reportes
SELECT COUNT(*) AS pedidos_bogota_en_reporte
FROM reportes.vista_pedidos_consolidado
WHERE id_sede = 1;

\echo '--- 12.4 se corre el ETL completo ---'
\ir etl/refrescar_reportes.sql

\echo '--- 12.5 ahora el reporte si lo ve (uno mas que en 12.1) ---'
SELECT COUNT(*) AS pedidos_bogota_en_reporte
FROM reportes.vista_pedidos_consolidado
WHERE id_sede = 1;

\echo '--- 12.6 control de la carga: tablas donde no cuadran las filas de origen y de staging (debe dar 0) ---'
-- etl.cargas no deja guardar una fila que no cuadre (CHECK), asi que
-- esto siempre da 0. si una tabla no cuadrara, la carga entera se habria
-- deshecho.
SELECT COUNT(*) AS tablas_que_no_cuadran
FROM etl.cargas
WHERE fecha_carga = (SELECT MAX(fecha_carga) FROM etl.cargas)
  AND filas_origen <> filas_staging;

\echo '--- 12.7 limpieza: se borra el pedido de prueba y se corre el ETL otra vez ---'
-- es la unica vez que se borra algo: es solo la limpieza de esta prueba
\c andina_ventas
DELETE FROM ventas.ped_bogota WHERE id_pedido = :pedido_prueba;
\ir etl/refrescar_reportes.sql

-- refrescar_reportes.sql prende ON_ERROR_STOP, se vuelve a apagar
\set ON_ERROR_STOP off

\c andina_reportes
\echo
\echo '--- Volumen de datos de prueba (en el staging de reportes, sin las filas de las pruebas) ---'
-- conteo final para comparar con los minimos de la seccion 10
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

-- se dejan las opciones de psql como estaban
\set ON_ERROR_ROLLBACK off
\set ON_ERROR_STOP on
