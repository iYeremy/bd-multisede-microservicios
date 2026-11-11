-- =====================================================================
-- etl/extraer_ventas.sql
-- ETL, paso E (extraer): saca las tablas de andina_ventas a archivos
-- CSV en la carpeta csv/. se corre conectado a andina_ventas.
--
-- solo LEE la base del servicio: el ETL nunca escribe en ella.
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql (no en el servidor). la ruta csv/ es relativa a la carpeta
-- desde donde se lanzo psql, por eso todo se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
-- =====================================================================

\copy ventas.ped_bogota         TO 'csv/ventas.ped_bogota.csv' WITH (FORMAT csv, HEADER)
\copy ventas.ped_medellin       TO 'csv/ventas.ped_medellin.csv' WITH (FORMAT csv, HEADER)
\copy ventas.ped_cali           TO 'csv/ventas.ped_cali.csv' WITH (FORMAT csv, HEADER)
\copy ventas.ped_cedi           TO 'csv/ventas.ped_cedi.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_bogota     TO 'csv/ventas.det_ped_bogota.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_medellin   TO 'csv/ventas.det_ped_medellin.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_cali       TO 'csv/ventas.det_ped_cali.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_cedi       TO 'csv/ventas.det_ped_cedi.csv' WITH (FORMAT csv, HEADER)
\copy ventas.pagos              TO 'csv/ventas.pagos.csv' WITH (FORMAT csv, HEADER)
\copy ventas.devoluciones       TO 'csv/ventas.devoluciones.csv' WITH (FORMAT csv, HEADER)
\copy ventas.detalle_devolucion TO 'csv/ventas.detalle_devolucion.csv' WITH (FORMAT csv, HEADER)

-- conteo de filas de cada tabla, para el control de la carga: despues,
-- cargar.sql compara estos numeros con lo que quedo en el staging.
-- una vista temporal (TEMP) desaparece al cerrar la conexion. se usa
-- porque \copy tiene que ir en una sola linea y asi queda corto.
CREATE TEMP VIEW tmp_conteo AS
SELECT 'ventas.ped_bogota'         AS tabla, COUNT(*) AS filas FROM ventas.ped_bogota
UNION ALL SELECT 'ventas.ped_medellin'      , COUNT(*) FROM ventas.ped_medellin
UNION ALL SELECT 'ventas.ped_cali'          , COUNT(*) FROM ventas.ped_cali
UNION ALL SELECT 'ventas.ped_cedi'          , COUNT(*) FROM ventas.ped_cedi
UNION ALL SELECT 'ventas.det_ped_bogota'    , COUNT(*) FROM ventas.det_ped_bogota
UNION ALL SELECT 'ventas.det_ped_medellin'  , COUNT(*) FROM ventas.det_ped_medellin
UNION ALL SELECT 'ventas.det_ped_cali'      , COUNT(*) FROM ventas.det_ped_cali
UNION ALL SELECT 'ventas.det_ped_cedi'      , COUNT(*) FROM ventas.det_ped_cedi
UNION ALL SELECT 'ventas.pagos'             , COUNT(*) FROM ventas.pagos
UNION ALL SELECT 'ventas.devoluciones'      , COUNT(*) FROM ventas.devoluciones
UNION ALL SELECT 'ventas.detalle_devolucion', COUNT(*) FROM ventas.detalle_devolucion;
\copy (SELECT * FROM tmp_conteo) TO 'csv/conteo_ventas.csv' WITH (FORMAT csv, HEADER)
DROP VIEW tmp_conteo;
