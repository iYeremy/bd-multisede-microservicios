-- 04_datos/ventas.sql
-- datos de prueba de ventas (base andina_ventas). ver README.md.
-- lee precios (catalogo) y surtido (inventarios) con dblink y al final lo quita.

SELECT setseed(0.2026);

-- de otros servicios, por dblink
\ir ../03_dblink/servidores.sql

-- precios
CREATE TEMP TABLE tmp_productos AS
SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, precio_lista FROM catalogo.productos')
         AS t(id_producto INTEGER, precio_lista NUMERIC(14,2));

-- que hay en cada almacen (el UNION ALL se hace alla, en andina_inventarios)
CREATE TEMP TABLE tmp_inv AS
SELECT * FROM dblink('srv_inventarios',
         'SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_bogota
          UNION ALL SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_medellin
          UNION ALL SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_cali
          UNION ALL SELECT id_sede, id_almacen, id_producto FROM inventarios.inv_cedi')
         AS t(id_sede INTEGER, id_almacen INTEGER, id_producto INTEGER);

-- 300 pedidos: bogota 100, medellin 80, cali 70, CEDI 50
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

-- id_pedido desde 1 en cada sede (como el IDENTITY). estado segun antiguedad
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

-- detalles: productos al azar del almacen. antes de agosto el precio era 5 % menor (RN-27)
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

-- total = suma de los detalles (RN-28)
ALTER TABLE tmp_ped ADD COLUMN total_registrado NUMERIC(14,2);
UPDATE tmp_ped p
SET total_registrado = d.total
FROM (SELECT id_sede, id_pedido, SUM(cantidad * precio_unitario) AS total
      FROM tmp_det GROUP BY id_sede, id_pedido) d
WHERE p.id_sede = d.id_sede AND p.id_pedido = d.id_pedido;

-- cada pedido y sus detalles a su fragmento. el IDENTITY repite los mismos numeros
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

-- pagos: completos, parciales, anticipos y rechazados (RN-30, RN-31)
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

-- 22 devoluciones de pedidos confirmados o entregados (RN-32)
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

-- la mitad de lo vendido de 1 o 2 productos del pedido (RN-33)
INSERT INTO ventas.detalle_devolucion (id_devolucion, id_producto, cantidad, condicion_producto)
SELECT x.id_devolucion, x.id_producto,
       CASE WHEN x.cantidad / 2 < 1 THEN 1 ELSE x.cantidad / 2 END,
       CASE WHEN x.id_devolucion % 3 = 0 THEN 'BUENO' ELSE 'AVERIADO' END
FROM (SELECT d.id_devolucion, dp.id_producto, dp.cantidad,
             ROW_NUMBER() OVER (PARTITION BY d.id_devolucion ORDER BY dp.cantidad DESC, dp.id_producto) AS n
      FROM tmp_dev d
      JOIN tmp_det dp ON dp.id_sede = d.id_sede AND dp.id_pedido = d.id_pedido) x
WHERE x.n <= 1 + x.id_devolucion % 2;

-- limpieza
DROP TABLE tmp_productos, tmp_inv, tmp_ped_base, tmp_ped, tmp_det, tmp_pag, tmp_dev;

-- ya no hace falta dblink aqui
\ir ../03_dblink/quitar.sql
