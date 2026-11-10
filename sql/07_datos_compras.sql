-- =====================================================================
-- 07_datos_compras.sql
-- datos de prueba del servicio de compras (base andina_compras): 60
-- ordenes de compra con sus detalles y recepciones.
--
-- cuando este servicio necesita datos de otro (ids, precios...) no los
-- puede leer directo, porque estan en otra base. los toma del CSV que
-- ese servicio publico (carpeta csv/, ver sql/sync/). en el sistema
-- real eso seria una llamada HTTP al otro servicio.
-- aqui se necesita que productos vende cada proveedor y a que costo
-- (catalogo.producto_proveedor). los ids de empleados compradores (16 y
-- 17) y de almacenes (1 a 5) se escriben a mano.
-- =====================================================================

SELECT setseed(0.2026);

-- ---------------------------------------------------------------------
-- datos que vienen de catalogo
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_producto_proveedor (
    id_producto INTEGER, id_proveedor INTEGER, costo_referencia NUMERIC(14,2), plazo_entrega_dias INTEGER
);
\copy tmp_producto_proveedor FROM 'csv/catalogo.producto_proveedor.csv' WITH (FORMAT csv, HEADER)

-- ---------------------------------------------------------------------
-- compras: 60 ordenes repartidas en el periodo
-- la mayoria llega al CEDI (almacen 4, S-06); cada 5 ordenes una llega
-- a una sede. retraso = dias que se pasa de la fecha estimada: los
-- proveedores 3 y 7 siempre se retrasan, los demas llegan entre 2 dias
-- antes y 1 despues.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_oc AS
SELECT o.*,
       o.fecha_orden + 5 + (o.id_proveedor % 4) * 3 AS fecha_estimada,
       CASE WHEN o.id_proveedor IN (3, 7) THEN 3 + o.id_orden_compra % 8   -- proveedores con retraso
            ELSE -2 + o.id_orden_compra % 4 END                            -- entre 2 dias antes y 1 despues
            AS retraso
FROM (SELECT i AS id_orden_compra,
             1 + (i * 7) % 10                                   AS id_proveedor,
             CASE WHEN i % 5 = 0 THEN 1 + (i / 5) % 3 ELSE 4 END AS id_almacen_destino,
             CASE WHEN i % 2 = 0 THEN 16 ELSE 17 END             AS id_empleado,
             DATE '2026-05-01' + ((i - 1) * 163) / 59            AS fecha_orden
      FROM generate_series(1, 60) AS i) o;

-- estado de cada orden (RN-13): 2 canceladas, emitidas si aun no llega
-- la fecha estimada, algunas parciales y el resto recibidas
ALTER TABLE tmp_oc ADD COLUMN estado VARCHAR(10);
UPDATE tmp_oc SET estado = CASE
    WHEN id_orden_compra IN (17, 41)                                 THEN 'CANCELADA'
    WHEN fecha_estimada > DATE '2026-10-15' OR id_orden_compra = 50  THEN 'EMITIDA'
    WHEN id_orden_compra % 7 = 0 OR fecha_orden > DATE '2026-09-20'  THEN 'PARCIAL'
    ELSE 'RECIBIDA' END;

INSERT INTO compras.ordenes_compra (id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado)
SELECT id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado
FROM tmp_oc
ORDER BY id_orden_compra;

-- cada orden pide entre 2 y 4 productos al azar de los que ofrece su
-- proveedor (JOIN con producto_proveedor). el costo pactado varia un
-- poco alrededor del costo de referencia (RN-27).
INSERT INTO compras.detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
SELECT x.id_orden_compra, x.id_producto,
       (2 + floor(random() * 10)::int) * 10,
       round(x.costo_referencia * (0.97 + random() * 0.06)::numeric, 0)
FROM (SELECT o.id_orden_compra, pp.id_producto, pp.costo_referencia,
             ROW_NUMBER() OVER (PARTITION BY o.id_orden_compra ORDER BY random()) AS n
      FROM tmp_oc o
      JOIN tmp_producto_proveedor pp ON pp.id_proveedor = o.id_proveedor) x
WHERE x.n <= 2 + x.id_orden_compra % 3;

-- recepciones (RN-11): las ordenes recibidas llegan en 1 o 2 entregas;
-- las parciales tienen una sola entrega con la mitad de lo pedido
-- (consulta 12). la fecha de recepcion no puede ser anterior a la orden
-- ni posterior a la fecha de corte.
-- el UNION ALL arma la primera entrega de todas y la segunda solo de
-- las que llegan en dos partes.
CREATE TEMP TABLE tmp_rec AS
SELECT (ROW_NUMBER() OVER (ORDER BY x.id_orden_compra, x.nro))::int AS id_recepcion,
       x.id_orden_compra, x.nro, x.estado, x.dos_entregas,
       CASE WHEN x.fecha < x.fecha_orden         THEN x.fecha_orden
            WHEN x.fecha > DATE '2026-10-15'     THEN DATE '2026-10-15'
            ELSE x.fecha END AS fecha_recepcion
FROM (
    SELECT id_orden_compra, 1 AS nro, estado, (id_orden_compra % 3 = 0) AS dos_entregas, fecha_orden,
           fecha_estimada + retraso
           - CASE WHEN estado = 'RECIBIDA' AND id_orden_compra % 3 = 0 THEN 5 ELSE 0 END AS fecha
    FROM tmp_oc WHERE estado IN ('RECIBIDA', 'PARCIAL')
    UNION ALL
    SELECT id_orden_compra, 2, estado, TRUE, fecha_orden, fecha_estimada + retraso
    FROM tmp_oc WHERE estado = 'RECIBIDA' AND id_orden_compra % 3 = 0
) x;

INSERT INTO compras.recepciones_compra (id_orden_compra, fecha_recepcion, estado)
SELECT id_orden_compra, fecha_recepcion, 'REGISTRADA' FROM tmp_rec ORDER BY id_recepcion;

-- cada recepcion recibe los productos de su orden (RN-12): la mitad si
-- es parcial, todo si es una sola entrega, o 60 % + 40 % si son dos
INSERT INTO compras.detalle_recepcion (id_recepcion, id_producto, cantidad_recibida)
SELECT r.id_recepcion, d.id_producto,
       CASE
           WHEN r.estado = 'PARCIAL'                   THEN d.cantidad_solicitada / 2
           WHEN NOT r.dos_entregas                     THEN d.cantidad_solicitada
           WHEN r.nro = 1                              THEN round(d.cantidad_solicitada * 0.6)::int
           ELSE d.cantidad_solicitada - round(d.cantidad_solicitada * 0.6)::int
       END
FROM tmp_rec r
JOIN compras.detalle_orden_compra d ON d.id_orden_compra = r.id_orden_compra;

-- limpieza de las tablas temporales
DROP TABLE tmp_producto_proveedor, tmp_oc, tmp_rec;
