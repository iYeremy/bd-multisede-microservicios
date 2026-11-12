-- 04_datos/inventarios.sql
-- datos de prueba de inventarios (base andina_inventarios). ver README.md.
-- lee almacenes y productos de catalogo con dblink y al final lo quita.

SELECT setseed(0.2026);

-- de catalogo, por dblink
\ir ../03_dblink/servidores.sql

CREATE TEMP TABLE tmp_almacenes AS
SELECT * FROM dblink('srv_catalogo', 'SELECT id_almacen, id_sede FROM catalogo.almacenes')
         AS t(id_almacen INTEGER, id_sede INTEGER);

CREATE TEMP TABLE tmp_productos AS
SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto FROM catalogo.productos')
         AS t(id_producto INTEGER);

-- existencias: todas las parejas almacen-producto (CROSS JOIN), salvo los
-- huecos de surtido. r y r2 son numeros al azar que deciden la existencia
CREATE TEMP TABLE tmp_inv AS
SELECT x.id_sede, x.id_almacen, x.id_producto,
       CASE
           WHEN x.id_almacen = 4 THEN CASE WHEN x.r < 0.06 THEN floor(x.r2 * x.minimo)::int
                                           ELSE x.minimo + 50 + floor(x.r2 * 350)::int END
           WHEN x.id_almacen = 5 THEN floor(x.r2 * 60)::int
           WHEN x.r < 0.06 THEN 0
           WHEN x.r < 0.20 THEN floor(x.r2 * x.minimo)::int
           ELSE x.minimo + floor(x.r2 * 100)::int
       END AS existencia_actual,
       x.minimo AS stock_minimo,
       TIMESTAMP '2026-10-15 18:00' - floor(x.r2 * 20) * INTERVAL '1 day' AS fecha_actualizacion
FROM (SELECT a.id_sede, a.id_almacen, p.id_producto,
             random() AS r, random() AS r2,
             CASE a.id_almacen WHEN 4 THEN 40 + floor(random() * 41)::int
                               WHEN 5 THEN floor(random() * 11)::int
                               ELSE 10 + floor(random() * 21)::int END AS minimo
      FROM tmp_almacenes a
      CROSS JOIN tmp_productos p
      -- huecos de surtido
      WHERE (a.id_almacen = 1 AND p.id_producto % 9 <> 0)
         OR (a.id_almacen = 2 AND p.id_producto % 7 <> 0)
         OR (a.id_almacen = 3 AND p.id_producto % 5 <> 0)
         OR (a.id_almacen = 4 AND p.id_producto <> 80)
         OR (a.id_almacen = 5 AND p.id_producto <= 20)) x;

-- los productos sin rotacion necesitan existencia positiva (consulta 16)
UPDATE tmp_inv
SET existencia_actual = stock_minimo + 25
WHERE id_producto IN (19, 35, 53, 70, 78, 12, 27, 44, 58, 75)
  AND existencia_actual = 0;

-- cada fila a su fragmento (si no, el CHECK la rechaza)
INSERT INTO inventarios.inv_bogota (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 1;
INSERT INTO inventarios.inv_medellin (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 2;
INSERT INTO inventarios.inv_cali (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 3;
INSERT INTO inventarios.inv_cedi (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 4;

-- 25 transferencias, la mayoria del CEDI a las sedes. 4 en transito (consulta 13)
CREATE TEMP TABLE tmp_tr AS
SELECT t.*,
       CASE WHEN t.estado IN ('SOLICITADA', 'CANCELADA') THEN NULL
            ELSE t.fecha_solicitud + 1 + t.id_transferencia % 2 END AS fecha_despacho
FROM (SELECT i AS id_transferencia,
             CASE WHEN i % 6 = 0 THEN 1 ELSE 4 END           AS origen,
             CASE WHEN i % 6 = 0 THEN 2 ELSE 1 + i % 3 END   AS destino,
             DATE '2026-05-05' + ((i - 1) * 13) / 2          AS fecha_solicitud,
             CASE WHEN i IN (20, 22, 23, 24) THEN 'DESPACHADA'
                  WHEN i IN (21, 25)         THEN 'SOLICITADA'
                  WHEN i = 11                THEN 'CANCELADA'
                  ELSE 'RECIBIDA' END                        AS estado
      FROM generate_series(1, 25) AS i) t;

INSERT INTO inventarios.transferencias (id_almacen_origen, id_almacen_destino,
                                        fecha_solicitud, fecha_despacho, fecha_recepcion, estado)
SELECT origen, destino, fecha_solicitud, fecha_despacho,
       CASE WHEN estado = 'RECIBIDA' THEN fecha_despacho + 2 + id_transferencia % 3 END,
       estado
FROM tmp_tr
ORDER BY id_transferencia;

-- 2 a 4 productos con existencia en el origen
INSERT INTO inventarios.detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida)
SELECT x.id_transferencia, x.id_producto, x.enviada,
       CASE WHEN x.estado = 'RECIBIDA' THEN x.enviada END
FROM (SELECT s.id_transferencia, s.estado, s.id_producto, 10 + floor(random() * 40)::int AS enviada
      FROM (SELECT t.id_transferencia, t.estado, i.id_producto,
                   ROW_NUMBER() OVER (PARTITION BY t.id_transferencia ORDER BY random()) AS n
            FROM tmp_tr t
            JOIN tmp_inv i ON i.id_almacen = t.origen AND i.existencia_actual > 0) s
      WHERE s.n <= 2 + s.id_transferencia % 3) x;

-- algunas llegan con 1 a 3 unidades menos (RN-23, consulta 14)
UPDATE inventarios.detalle_transferencia dt
SET cantidad_recibida = dt.cantidad_enviada - (1 + dt.id_transferencia % 3)
FROM inventarios.transferencias t
WHERE t.id_transferencia = dt.id_transferencia
  AND t.estado = 'RECIBIDA'
  AND t.id_transferencia % 4 = 0
  AND dt.id_producto = (SELECT min(id_producto) FROM inventarios.detalle_transferencia d2
                        WHERE d2.id_transferencia = dt.id_transferencia);

-- limpieza
DROP TABLE tmp_almacenes, tmp_productos, tmp_inv, tmp_tr;

-- ya no hace falta dblink aqui
\ir ../03_dblink/quitar.sql
