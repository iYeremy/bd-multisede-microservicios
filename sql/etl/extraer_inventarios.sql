-- =====================================================================
-- etl/extraer_inventarios.sql
-- ETL, paso E (extraer): saca las tablas de andina_inventarios a archivos
-- CSV en la carpeta csv/. se corre conectado a andina_inventarios.
--
-- solo LEE la base del servicio: el ETL nunca escribe en ella.
--
-- ojo: ventas tambien lee los inv_*.csv para vender solo lo que hay en
-- cada almacen (ver 07_datos_ventas.sql).
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql (no en el servidor). la ruta csv/ es relativa a la carpeta
-- desde donde se lanzo psql, por eso todo se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
-- =====================================================================

\copy inventarios.inv_bogota            TO 'csv/inventarios.inv_bogota.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_medellin          TO 'csv/inventarios.inv_medellin.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_cali              TO 'csv/inventarios.inv_cali.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_cedi              TO 'csv/inventarios.inv_cedi.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.transferencias        TO 'csv/inventarios.transferencias.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.detalle_transferencia TO 'csv/inventarios.detalle_transferencia.csv' WITH (FORMAT csv, HEADER)

-- conteo de filas de cada tabla, para el control de la carga: despues,
-- cargar.sql compara estos numeros con lo que quedo en el staging.
-- una vista temporal (TEMP) desaparece al cerrar la conexion. se usa
-- porque \copy tiene que ir en una sola linea y asi queda corto.
CREATE TEMP VIEW tmp_conteo AS
SELECT 'inventarios.inv_bogota'            AS tabla, COUNT(*) AS filas FROM inventarios.inv_bogota
UNION ALL SELECT 'inventarios.inv_medellin'         , COUNT(*) FROM inventarios.inv_medellin
UNION ALL SELECT 'inventarios.inv_cali'             , COUNT(*) FROM inventarios.inv_cali
UNION ALL SELECT 'inventarios.inv_cedi'             , COUNT(*) FROM inventarios.inv_cedi
UNION ALL SELECT 'inventarios.transferencias'       , COUNT(*) FROM inventarios.transferencias
UNION ALL SELECT 'inventarios.detalle_transferencia', COUNT(*) FROM inventarios.detalle_transferencia;
\copy (SELECT * FROM tmp_conteo) TO 'csv/conteo_inventarios.csv' WITH (FORMAT csv, HEADER)
DROP VIEW tmp_conteo;
