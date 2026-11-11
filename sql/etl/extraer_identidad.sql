-- =====================================================================
-- etl/extraer_identidad.sql
-- ETL, paso E (extraer): saca las tablas de andina_identidad a archivos
-- CSV en la carpeta csv/. se corre conectado a andina_identidad.
--
-- solo LEE la base del servicio: el ETL nunca escribe en ella.
--
-- solo sale empleados. usuarios y auditoria_accesos se quedan en
-- identidad: tienen contrasenas y a reportes no le sirven.
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql (no en el servidor). la ruta csv/ es relativa a la carpeta
-- desde donde se lanzo psql, por eso todo se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
-- =====================================================================

\copy identidad.empleados TO 'csv/identidad.empleados.csv' WITH (FORMAT csv, HEADER)

-- conteo de filas de cada tabla, para el control de la carga: despues,
-- cargar.sql compara estos numeros con lo que quedo en el staging.
-- una vista temporal (TEMP) desaparece al cerrar la conexion. se usa
-- porque \copy tiene que ir en una sola linea y asi queda corto.
CREATE TEMP VIEW tmp_conteo AS
SELECT 'identidad.empleados' AS tabla, COUNT(*) AS filas FROM identidad.empleados;
\copy (SELECT * FROM tmp_conteo) TO 'csv/conteo_identidad.csv' WITH (FORMAT csv, HEADER)
DROP VIEW tmp_conteo;
