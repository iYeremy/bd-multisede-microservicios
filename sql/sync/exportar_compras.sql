-- =====================================================================
-- sync/exportar_compras.sql
-- el servicio de compras publica sus datos en archivos CSV para que
-- reportes guarde una copia (se corre conectado a andina_compras).
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql. la ruta csv/ es relativa a la carpeta desde donde se
-- lanzo psql, por eso run_all.sql se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
--
-- en el sistema real esto lo haria el backend cada cierto tiempo.
-- =====================================================================

\copy compras.ordenes_compra       TO 'csv/compras.ordenes_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.detalle_orden_compra TO 'csv/compras.detalle_orden_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.recepciones_compra   TO 'csv/compras.recepciones_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.detalle_recepcion    TO 'csv/compras.detalle_recepcion.csv' WITH (FORMAT csv, HEADER)
