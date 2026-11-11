-- =====================================================================
-- etl/extraer_catalogo.sql
-- ETL, paso E (extraer): saca las tablas de andina_catalogo a archivos
-- CSV en la carpeta csv/. se corre conectado a andina_catalogo.
--
-- solo LEE la base del servicio: el ETL nunca escribe en ella.
--
-- ojo: inventarios, ventas y compras tambien leen estos CSV para armar
-- sus datos de prueba (ver 07_datos_*.sql).
--
-- \copy ... TO escribe el resultado en un archivo del computador donde
-- corre psql (no en el servidor). la ruta csv/ es relativa a la carpeta
-- desde donde se lanzo psql, por eso todo se corre desde la carpeta del
-- proyecto. HEADER pone los nombres de las columnas en la primera linea.
-- =====================================================================

\copy catalogo.sedes              TO 'csv/catalogo.sedes.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.almacenes          TO 'csv/catalogo.almacenes.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.categorias         TO 'csv/catalogo.categorias.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.productos          TO 'csv/catalogo.productos.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.proveedores        TO 'csv/catalogo.proveedores.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.producto_proveedor TO 'csv/catalogo.producto_proveedor.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.clientes           TO 'csv/catalogo.clientes.csv' WITH (FORMAT csv, HEADER)

-- conteo de filas de cada tabla, para el control de la carga: despues,
-- cargar.sql compara estos numeros con lo que quedo en el staging.
-- una vista temporal (TEMP) desaparece al cerrar la conexion. se usa
-- porque \copy tiene que ir en una sola linea y asi queda corto.
CREATE TEMP VIEW tmp_conteo AS
SELECT 'catalogo.sedes'              AS tabla, COUNT(*) AS filas FROM catalogo.sedes
UNION ALL SELECT 'catalogo.almacenes'         , COUNT(*) FROM catalogo.almacenes
UNION ALL SELECT 'catalogo.categorias'        , COUNT(*) FROM catalogo.categorias
UNION ALL SELECT 'catalogo.productos'         , COUNT(*) FROM catalogo.productos
UNION ALL SELECT 'catalogo.proveedores'       , COUNT(*) FROM catalogo.proveedores
UNION ALL SELECT 'catalogo.producto_proveedor', COUNT(*) FROM catalogo.producto_proveedor
UNION ALL SELECT 'catalogo.clientes'          , COUNT(*) FROM catalogo.clientes;
\copy (SELECT * FROM tmp_conteo) TO 'csv/conteo_catalogo.csv' WITH (FORMAT csv, HEADER)
DROP VIEW tmp_conteo;
