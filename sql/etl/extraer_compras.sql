-- =====================================================================
-- etl/extraer_compras.sql
-- ETL, paso E (extraer): saca las tablas de andina_compras a archivos
-- CSV en la carpeta csv/. se corre conectado a andina_compras.
--
-- solo LEE la base del servicio: el ETL nunca escribe en ella.
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql (no en el servidor). la ruta csv/ es relativa a la carpeta
-- desde donde se lanzo psql, por eso todo se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
-- =====================================================================

\copy compras.ordenes_compra       TO 'csv/compras.ordenes_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.detalle_orden_compra TO 'csv/compras.detalle_orden_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.recepciones_compra   TO 'csv/compras.recepciones_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.detalle_recepcion    TO 'csv/compras.detalle_recepcion.csv' WITH (FORMAT csv, HEADER)

-- conteo de filas de cada tabla, para el control de la carga: despues,
-- cargar.sql compara estos numeros con lo que quedo en el staging.
-- una vista temporal (TEMP) desaparece al cerrar la conexion. se usa
-- porque \copy tiene que ir en una sola linea y asi queda corto.
CREATE TEMP VIEW tmp_conteo AS
SELECT 'compras.ordenes_compra'       AS tabla, COUNT(*) AS filas FROM compras.ordenes_compra
UNION ALL SELECT 'compras.detalle_orden_compra', COUNT(*) FROM compras.detalle_orden_compra
UNION ALL SELECT 'compras.recepciones_compra'  , COUNT(*) FROM compras.recepciones_compra
UNION ALL SELECT 'compras.detalle_recepcion'   , COUNT(*) FROM compras.detalle_recepcion;
\copy (SELECT * FROM tmp_conteo) TO 'csv/conteo_compras.csv' WITH (FORMAT csv, HEADER)
DROP VIEW tmp_conteo;
