-- =====================================================================
-- sync/exportar_catalogo.sql
-- el servicio de catalogo publica sus datos en archivos CSV para que
-- reportes guarde una copia (se corre conectado a andina_catalogo).
--
-- inventarios, ventas y compras tambien leen estos archivos para armar
-- sus datos de prueba (ver 07_datos_*.sql).
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql. la ruta csv/ es relativa a la carpeta desde donde se
-- lanzo psql, por eso run_all.sql se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
--
-- en el sistema real esto lo haria el backend cada cierto tiempo.
-- =====================================================================

\copy catalogo.sedes              TO 'csv/catalogo.sedes.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.almacenes          TO 'csv/catalogo.almacenes.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.categorias         TO 'csv/catalogo.categorias.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.productos          TO 'csv/catalogo.productos.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.proveedores        TO 'csv/catalogo.proveedores.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.producto_proveedor TO 'csv/catalogo.producto_proveedor.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.clientes           TO 'csv/catalogo.clientes.csv' WITH (FORMAT csv, HEADER)
