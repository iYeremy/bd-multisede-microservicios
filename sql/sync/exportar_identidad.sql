-- =====================================================================
-- sync/exportar_identidad.sql
-- el servicio de identidad publica sus datos en archivos CSV para que
-- reportes guarde una copia (se corre conectado a andina_identidad).
--
-- solo se publica empleados. usuarios y auditoria_accesos no salen de
-- identidad: tienen contrasenas y a reportes no le sirven.
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql. la ruta csv/ es relativa a la carpeta desde donde se
-- lanzo psql, por eso run_all.sql se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
--
-- en el sistema real esto lo haria el backend cada cierto tiempo.
-- =====================================================================

\copy identidad.empleados TO 'csv/identidad.empleados.csv' WITH (FORMAT csv, HEADER)
