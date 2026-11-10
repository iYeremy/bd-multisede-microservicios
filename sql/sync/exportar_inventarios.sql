-- =====================================================================
-- sync/exportar_inventarios.sql
-- el servicio de inventarios publica sus datos en archivos CSV para que
-- reportes guarde una copia (se corre conectado a andina_inventarios).
--
-- ventas tambien lee los inv_*.csv para vender solo lo que hay en cada
-- almacen (ver 07_datos_ventas.sql).
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql. la ruta csv/ es relativa a la carpeta desde donde se
-- lanzo psql, por eso run_all.sql se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
--
-- en el sistema real esto lo haria el backend cada cierto tiempo.
-- =====================================================================

\copy inventarios.inv_bogota            TO 'csv/inventarios.inv_bogota.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_medellin          TO 'csv/inventarios.inv_medellin.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_cali              TO 'csv/inventarios.inv_cali.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_cedi              TO 'csv/inventarios.inv_cedi.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.transferencias        TO 'csv/inventarios.transferencias.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.detalle_transferencia TO 'csv/inventarios.detalle_transferencia.csv' WITH (FORMAT csv, HEADER)
