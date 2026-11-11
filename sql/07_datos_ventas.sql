-- =====================================================================
-- 07_datos_ventas.sql
-- datos de prueba del servicio de ventas (base andina_ventas): 300
-- pedidos con sus detalles (cada uno en el fragmento de su sede), pagos
-- y 22 devoluciones.
--
-- cuando este servicio necesita datos de otro (ids, precios...) no los
-- puede leer directo, porque estan en otra base. los toma del CSV que
-- ese servicio publico (carpeta csv/, ver sql/etl/extraer_*.sql). en el sistema
-- real eso seria una llamada HTTP al otro servicio.
-- aqui se necesitan los precios (catalogo) y que productos tiene cada
-- almacen (inventarios), para vender solo lo que hay.
-- los ids de clientes (1 a 100) y de vendedores de cada sede se escriben
-- a mano: son los que crearon los scripts de catalogo e identidad.
--
-- tecnica: los datos se generan primero en tablas temporales y despues
-- cada fila se inserta en el fragmento de su sede (WHERE id_sede = n).
-- =====================================================================

SELECT setseed(0.2026);

-- ---------------------------------------------------------------------
-- datos que vienen de otros servicios
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_productos (
    id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER,
    unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15)
);
\copy tmp_productos FROM 'csv/catalogo.productos.csv' WITH (FORMAT csv, HEADER)

-- los 4 fragmentos de inventario van a una sola tabla temporal
CREATE TEMP TABLE tmp_inv (
    id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER,
    existencia_actual INTEGER, stock_minimo INTEGER, fecha_actualizacion TIMESTAMP
);
\copy tmp_inv FROM 'csv/inventarios.inv_bogota.csv'   WITH (FORMAT csv, HEADER)
\copy tmp_inv FROM 'csv/inventarios.inv_medellin.csv' WITH (FORMAT csv, HEADER)
\copy tmp_inv FROM 'csv/inventarios.inv_cali.csv'     WITH (FORMAT csv, HEADER)
\copy tmp_inv FROM 'csv/inventarios.inv_cedi.csv'     WITH (FORMAT csv, HEADER)

-- ---------------------------------------------------------------------
-- ventas: 300 pedidos (bogota 100, medellin 80, cali 70, CEDI 50)
-- primero la base de cada pedido: sede, almacen de esa sede, cliente al
-- azar, uno de los vendedores de la sede, fecha en el periodo y cuantas
-- lineas (1 a 5) tendra. generate_series(1, 100) con "n <= cant" deja
-- la cantidad exacta de pedidos de cada sede.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_ped_base AS
SELECT s.id_sede, s.id_almacen,
       1 + floor(random() * 100)::int                                         AS id_cliente,
       s.vendedores[1 + floor(random() * array_length(s.vendedores, 1))::int] AS id_empleado,
       DATE '2026-05-01' + floor(random() * 168)::int                          AS fecha_pedido,
       random()                                                               AS r_estado,
       1 + floor(random() * 5)::int                                           AS nlineas
FROM (VALUES (1, 1, 100, ARRAY[3, 4, 5]),
             (2, 2,  80, ARRAY[8, 9, 10]),
             (3, 3,  70, ARRAY[12, 13, 14]),
             (4, 4,  50, ARRAY[18, 19])) AS s(id_sede, id_almacen, cant, vendedores)
CROSS JOIN generate_series(1, 100) AS g(n)
WHERE g.n <= s.cant;

-- id_pedido: ROW_NUMBER() OVER (PARTITION BY id_sede ...) numera desde 1
-- dentro de cada sede en orden de fecha, igual que lo hara el IDENTITY
-- de cada fragmento.
-- estado segun antiguedad: los pedidos viejos casi siempre ya estan
-- entregados y los recientes suelen seguir pendientes; algunos viejos
-- quedan pendientes a proposito (consulta 9).
CREATE TEMP TABLE tmp_ped AS
SELECT b.*,
       ROW_NUMBER() OVER (PARTITION BY b.id_sede ORDER BY b.fecha_pedido, b.id_cliente, b.r_estado)::int AS id_pedido,
       CASE
           WHEN b.r_estado < 0.05 THEN 'ANULADO'
           WHEN DATE '2026-10-15' - b.fecha_pedido > 30 THEN
               CASE WHEN b.r_estado < 0.09 THEN 'PENDIENTE' WHEN b.r_estado < 0.20 THEN 'CONFIRMADO' ELSE 'ENTREGADO' END
           WHEN DATE '2026-10-15' - b.fecha_pedido > 15 THEN
               CASE WHEN b.r_estado < 0.25 THEN 'PENDIENTE' WHEN b.r_estado < 0.55 THEN 'CONFIRMADO' ELSE 'ENTREGADO' END
           ELSE
               CASE WHEN b.r_estado < 0.55 THEN 'PENDIENTE' WHEN b.r_estado < 0.80 THEN 'CONFIRMADO' ELSE 'ENTREGADO' END
       END AS estado
FROM tmp_ped_base b;

-- detalles: a cada pedido se le asignan nlineas productos distintos al
-- azar (ROW_NUMBER sobre ORDER BY random() y luego n <= nlineas) entre
-- los que existen en el almacen del pedido.
-- el precio se guarda en el detalle: antes de agosto la lista era 5 %
-- menor, asi se ve que el precio historico no depende del catalogo
-- actual (RN-27). el CEDI vende al por mayor (cantidades hasta 30, S-02).
CREATE TEMP TABLE tmp_det AS
SELECT c.id_sede, c.id_pedido, c.id_producto,
       1 + floor(random() * CASE WHEN c.id_sede = 4 THEN 30 ELSE 8 END)::int AS cantidad,
       round(c.precio_lista * CASE WHEN c.fecha_pedido < DATE '2026-08-01' THEN 0.95 ELSE 1 END, 0) AS precio_unitario
FROM (SELECT p.id_sede, p.id_pedido, p.fecha_pedido, p.nlineas, pr.id_producto, pr.precio_lista,
             ROW_NUMBER() OVER (PARTITION BY p.id_sede, p.id_pedido ORDER BY random()) AS n
      FROM tmp_ped p
      JOIN tmp_inv i ON i.id_almacen = p.id_almacen
      JOIN tmp_productos pr ON pr.id_producto = i.id_producto
      WHERE pr.id_producto NOT IN (19, 35, 53, 70, 78)                     -- nunca se venden
        AND (p.fecha_pedido < DATE '2026-07-01'
             OR pr.id_producto NOT IN (12, 27, 44, 58, 75, 39, 64, 80))) c -- sin ventas desde julio
WHERE c.n <= c.nlineas;

-- total registrado = suma de cantidad x precio de los detalles (RN-28).
-- UPDATE ... FROM actualiza cada pedido con el total calculado en la
-- subconsulta d.
ALTER TABLE tmp_ped ADD COLUMN total_registrado NUMERIC(14,2);
UPDATE tmp_ped p
SET total_registrado = d.total
FROM (SELECT id_sede, id_pedido, SUM(cantidad * precio_unitario) AS total
      FROM tmp_det GROUP BY id_sede, id_pedido) d
WHERE p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido;

-- cada pedido va a su fragmento, y sus detalles al fragmento de la misma
-- sede. los pedidos se insertan ordenados por id_pedido SIN indicar el
-- numero: el IDENTITY del fragmento les asigna 1, 2, 3..., los mismos
-- numeros que ya tienen sus detalles en tmp_det. por eso la FK de los
-- detalles encuentra su pedido.
INSERT INTO ventas.ped_bogota (id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM tmp_ped WHERE id_sede = 1 ORDER BY id_pedido;
INSERT INTO ventas.ped_medellin (id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM tmp_ped WHERE id_sede = 2 ORDER BY id_pedido;
INSERT INTO ventas.ped_cali (id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM tmp_ped WHERE id_sede = 3 ORDER BY id_pedido;
INSERT INTO ventas.ped_cedi (id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM tmp_ped WHERE id_sede = 4 ORDER BY id_pedido;

INSERT INTO ventas.det_ped_bogota (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM tmp_det WHERE id_sede = 1;
INSERT INTO ventas.det_ped_medellin (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM tmp_det WHERE id_sede = 2;
INSERT INTO ventas.det_ped_cali (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM tmp_det WHERE id_sede = 3;
INSERT INTO ventas.det_ped_cedi (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_sede, id_pedido, id_producto, cantidad, precio_unitario FROM tmp_det WHERE id_sede = 4;

-- pagos (RN-30, RN-31):
--   entregados   pagados completos, en 1 o 2 cuotas
--   confirmados  algunos pagados, otros con saldo (consulta 7)
--   pendientes   algunos con anticipo del 30 %
--   anulados     algunos con un pago rechazado
-- el primer INSERT crea el primer pago y el segundo la segunda cuota.
-- las fechas nunca pasan de la fecha de corte.
CREATE TEMP TABLE tmp_pag AS
SELECT id_sede, id_pedido, fecha_pedido, estado, total_registrado AS total, random() AS r,
       (ARRAY['EFECTIVO', 'TARJETA_DEBITO', 'TARJETA_CREDITO', 'TRANSFERENCIA'])[1 + floor(random() * 4)::int] AS medio
FROM tmp_ped;

INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT id_sede, id_pedido,
       CASE WHEN fecha_pedido + 1 > DATE '2026-10-15' THEN DATE '2026-10-15' ELSE fecha_pedido + 1 END,
       CASE
           WHEN estado = 'ENTREGADO'  AND r < 0.3 THEN round(total / 2, 2)
           WHEN estado = 'ENTREGADO'              THEN total
           WHEN estado = 'CONFIRMADO' AND r < 0.4 THEN total
           WHEN estado = 'CONFIRMADO'             THEN round(total / 2, 2)
           WHEN estado = 'PENDIENTE'              THEN round(total * 0.3, 2)
           ELSE total
       END,
       medio,
       CASE WHEN estado = 'ANULADO' THEN 'RECHAZADO' ELSE 'CONFIRMADO' END
FROM tmp_pag
WHERE estado IN ('ENTREGADO', 'CONFIRMADO')
   OR (estado = 'PENDIENTE' AND r < 0.35)
   OR (estado = 'ANULADO'   AND r < 0.5);

INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT id_sede, id_pedido,
       CASE WHEN fecha_pedido + 8 > DATE '2026-10-15' THEN DATE '2026-10-15' ELSE fecha_pedido + 8 END,
       total - round(total / 2, 2), medio,
       CASE WHEN estado = 'ENTREGADO' THEN 'CONFIRMADO' ELSE 'PENDIENTE' END
FROM tmp_pag
WHERE (estado = 'ENTREGADO' AND r < 0.3)
   OR (estado = 'CONFIRMADO' AND r >= 0.7);

-- devoluciones: 22 pedidos confirmados o entregados elegidos al azar
-- (RN-32), con 1 o 2 productos cada una. estado: la mayoria aprobadas,
-- algunas solicitadas y rechazadas.
CREATE TEMP TABLE tmp_dev AS
SELECT (ROW_NUMBER() OVER ())::int AS id_devolucion, x.*
FROM (SELECT id_sede, id_pedido, fecha_pedido
      FROM tmp_ped
      WHERE estado IN ('ENTREGADO', 'CONFIRMADO') AND fecha_pedido <= DATE '2026-10-10'
      ORDER BY random()
      LIMIT 22) x;

INSERT INTO ventas.devoluciones (id_sede, id_pedido, fecha_solicitud, motivo, estado)
SELECT id_sede, id_pedido,
       CASE WHEN fecha_pedido + 2 + id_devolucion % 6 > DATE '2026-10-15' THEN DATE '2026-10-15'
            ELSE fecha_pedido + 2 + id_devolucion % 6 END,
       (ARRAY['Producto defectuoso', 'Empaque dañado', 'Producto equivocado',
              'Fecha de vencimiento próxima', 'Cliente insatisfecho'])[1 + id_devolucion % 5],
       CASE WHEN id_devolucion % 7 = 0 THEN 'RECHAZADA'
            WHEN id_devolucion % 5 = 0 THEN 'SOLICITADA'
            ELSE 'APROBADA' END
FROM tmp_dev
ORDER BY id_devolucion;

-- se devuelven los 1 o 2 productos con mas unidades del pedido, la mitad
-- de lo vendido (nunca mas de lo vendido, RN-33). como salen del JOIN
-- con los detalles del pedido, siempre son productos del pedido (RN-32).
INSERT INTO ventas.detalle_devolucion (id_devolucion, id_producto, cantidad, condicion_producto)
SELECT x.id_devolucion, x.id_producto,
       CASE WHEN x.cantidad / 2 < 1 THEN 1 ELSE x.cantidad / 2 END,
       CASE WHEN x.id_devolucion % 3 = 0 THEN 'BUENO' ELSE 'AVERIADO' END
FROM (SELECT d.id_devolucion, dp.id_producto, dp.cantidad,
             ROW_NUMBER() OVER (PARTITION BY d.id_devolucion ORDER BY dp.cantidad DESC, dp.id_producto) AS n
      FROM tmp_dev d
      JOIN tmp_det dp ON dp.id_sede = d.id_sede AND dp.id_pedido = d.id_pedido) x
WHERE x.n <= 1 + x.id_devolucion % 2;

-- limpieza de las tablas temporales
DROP TABLE tmp_productos, tmp_inv, tmp_ped_base, tmp_ped, tmp_det, tmp_pag, tmp_dev;
