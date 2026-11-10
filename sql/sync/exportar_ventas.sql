-- =====================================================================
-- sync/exportar_ventas.sql
-- el servicio de ventas publica sus datos en archivos CSV para que
-- reportes guarde una copia (se corre conectado a andina_ventas).
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql. la ruta csv/ es relativa a la carpeta desde donde se
-- lanzo psql, por eso run_all.sql se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
--
-- en el sistema real esto lo haria el backend cada cierto tiempo.
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
