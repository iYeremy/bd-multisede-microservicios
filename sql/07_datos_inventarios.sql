-- =====================================================================
-- 07_datos_inventarios.sql
-- datos de prueba del servicio de inventarios (base andina_inventarios):
-- existencias de cada almacen (en el fragmento de su sede) y 25
-- transferencias.
--
-- cuando este servicio necesita datos de otro (ids, precios...) no los
-- puede leer directo, porque estan en otra base. los toma del CSV que
-- ese servicio publico (carpeta csv/, ver sql/etl/extraer_*.sql). en el sistema
-- real eso seria una llamada HTTP al otro servicio.
-- aqui se necesitan los almacenes (con su sede) y los productos.
-- =====================================================================

SELECT setseed(0.2026);

-- ---------------------------------------------------------------------
-- datos que vienen de catalogo
-- tablas temporales (CREATE TEMP TABLE, desaparecen al cerrar la
-- sesion) con las mismas columnas del CSV, en el mismo orden.
-- \copy ... FROM lee el archivo desde el computador donde corre psql.
-- HEADER: la primera linea del archivo son los nombres de las columnas.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_almacenes (
    id_almacen INTEGER, id_sede INTEGER, nombre VARCHAR(60), tipo_almacen VARCHAR(15), estado VARCHAR(10)
);
\copy tmp_almacenes FROM 'csv/catalogo.almacenes.csv' WITH (FORMAT csv, HEADER)

CREATE TEMP TABLE tmp_productos (
    id_producto INTEGER, sku VARCHAR(20), nombre VARCHAR(100), id_categoria INTEGER,
    unidad_medida VARCHAR(10), precio_lista NUMERIC(14,2), estado VARCHAR(15)
);
\copy tmp_productos FROM 'csv/catalogo.productos.csv' WITH (FORMAT csv, HEADER)

-- ---------------------------------------------------------------------
-- inventarios
-- se generan en una tabla temporal (tmp_inv) cruzando almacenes con
-- productos (CROSS JOIN = todas las combinaciones) y luego cada fila se
-- inserta en el fragmento de su sede.
--
-- r y r2 son dos numeros al azar por fila que deciden la existencia:
--   almacenes de venta (1-3): 6 % en cero, 14 % bajo el minimo y el
--     resto por encima (alertas de reabastecimiento, consulta 2).
--   bodega general CEDI (4): casi todo con mucho stock.
--   bodega de despacho CEDI (5): pocas unidades.
-- ---------------------------------------------------------------------
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
      -- huecos de surtido: cada almacen deja por fuera algunos productos
      WHERE (a.id_almacen = 1 AND p.id_producto % 9 <> 0)
         OR (a.id_almacen = 2 AND p.id_producto % 7 <> 0)
         OR (a.id_almacen = 3 AND p.id_producto % 5 <> 0)
         OR (a.id_almacen = 4 AND p.id_producto <> 80)
         OR (a.id_almacen = 5 AND p.id_producto <= 20)) x;

-- los productos sin rotacion deben tener existencia positiva: la
-- consulta 16 busca productos con stock que no se venden
UPDATE tmp_inv
SET existencia_actual = stock_minimo + 25
WHERE id_producto IN (19, 35, 53, 70, 78, 12, 27, 44, 58, 75)
  AND existencia_actual = 0;

-- reparto en fragmentos: cada INSERT toma solo las filas de su sede
-- (WHERE id_sede = n). si una fila tuviera otra sede, el CHECK del
-- fragmento la rechazaria.
INSERT INTO inventarios.inv_bogota (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 1;
INSERT INTO inventarios.inv_medellin (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 2;
INSERT INTO inventarios.inv_cali (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 3;
INSERT INTO inventarios.inv_cedi (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM tmp_inv WHERE id_sede = 4;

-- ---------------------------------------------------------------------
-- transferencias: 25, la mayoria del CEDI (almacen 4) hacia las sedes.
-- estados fijos: 4 despachadas sin recibir (en transito, consulta 13),
-- 2 solicitadas, 1 cancelada y el resto recibidas. las fechas de
-- despacho y recepcion solo existen cuando corresponde (RN-20).
-- ---------------------------------------------------------------------
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

-- cada transferencia lleva entre 2 y 4 productos con existencia en el
-- origen. cantidad_recibida queda NULL si todavia no se recibe (RN-21).
INSERT INTO inventarios.detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida)
SELECT x.id_transferencia, x.id_producto, x.enviada,
       CASE WHEN x.estado = 'RECIBIDA' THEN x.enviada END
FROM (SELECT s.id_transferencia, s.estado, s.id_producto, 10 + floor(random() * 40)::int AS enviada
      FROM (SELECT t.id_transferencia, t.estado, i.id_producto,
                   ROW_NUMBER() OVER (PARTITION BY t.id_transferencia ORDER BY random()) AS n
            FROM tmp_tr t
            JOIN tmp_inv i ON i.id_almacen = t.origen AND i.existencia_actual > 0) s
      WHERE s.n <= 2 + s.id_transferencia % 3) x;

-- diferencias entre enviado y recibido en algunas transferencias
-- recibidas (RN-23, consulta 14): llegan 1 a 3 unidades menos del
-- primer producto
UPDATE inventarios.detalle_transferencia dt
SET cantidad_recibida = dt.cantidad_enviada - (1 + dt.id_transferencia % 3)
FROM inventarios.transferencias t
WHERE t.id_transferencia = dt.id_transferencia
  AND t.estado = 'RECIBIDA'
  AND t.id_transferencia % 4 = 0
  AND dt.id_producto = (SELECT min(id_producto) FROM inventarios.detalle_transferencia d2
                        WHERE d2.id_transferencia = dt.id_transferencia);

-- limpieza de las tablas temporales
DROP TABLE tmp_almacenes, tmp_productos, tmp_inv, tmp_tr;
