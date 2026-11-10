-- =====================================================================
-- sync/importar_reportes.sql
-- carga en andina_reportes la copia de los datos de cada servicio (los
-- CSV que dejaron los exportar_*.sql). se corre conectado a
-- andina_reportes, despues de crear ahi las tablas con 02 a 06.
--
-- la idea: reportes necesita cruzar datos de todos los servicios (por
-- ejemplo ventas con nombres de productos), pero una consulta no puede
-- leer otra base. entonces reportes guarda su propia copia de solo
-- lectura y sus vistas leen de ahi.
--
-- la copia puede ir un poco atrasada respecto a la base original (se
-- actualiza cuando se vuelve a sincronizar). eso se llama consistencia
-- eventual y es normal en microservicios.
--
-- el orden importa: primero las tablas "padre" (sedes, ordenes,
-- pedidos...) y despues las que tienen FK hacia ellas.
-- \copy si guarda el id que trae el archivo aunque la columna sea
-- GENERATED ALWAYS AS IDENTITY, asi la copia queda con los mismos ids.
-- =====================================================================

-- 03_identidad.sql crea las 3 tablas de identidad, pero reportes solo
-- necesita empleados. usuarios y auditoria_accesos se borran de la copia
-- (ahi van las contrasenas, y eso se queda en su servicio).
DROP TABLE identidad.auditoria_accesos, identidad.usuarios;

-- catalogo
\copy catalogo.sedes              FROM 'csv/catalogo.sedes.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.almacenes          FROM 'csv/catalogo.almacenes.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.categorias         FROM 'csv/catalogo.categorias.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.productos          FROM 'csv/catalogo.productos.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.proveedores        FROM 'csv/catalogo.proveedores.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.producto_proveedor FROM 'csv/catalogo.producto_proveedor.csv' WITH (FORMAT csv, HEADER)
\copy catalogo.clientes           FROM 'csv/catalogo.clientes.csv' WITH (FORMAT csv, HEADER)

-- identidad
\copy identidad.empleados FROM 'csv/identidad.empleados.csv' WITH (FORMAT csv, HEADER)

-- compras
\copy compras.ordenes_compra       FROM 'csv/compras.ordenes_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.detalle_orden_compra FROM 'csv/compras.detalle_orden_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.recepciones_compra   FROM 'csv/compras.recepciones_compra.csv' WITH (FORMAT csv, HEADER)
\copy compras.detalle_recepcion    FROM 'csv/compras.detalle_recepcion.csv' WITH (FORMAT csv, HEADER)

-- inventarios
\copy inventarios.inv_bogota            FROM 'csv/inventarios.inv_bogota.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_medellin          FROM 'csv/inventarios.inv_medellin.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_cali              FROM 'csv/inventarios.inv_cali.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.inv_cedi              FROM 'csv/inventarios.inv_cedi.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.transferencias        FROM 'csv/inventarios.transferencias.csv' WITH (FORMAT csv, HEADER)
\copy inventarios.detalle_transferencia FROM 'csv/inventarios.detalle_transferencia.csv' WITH (FORMAT csv, HEADER)

-- ventas
\copy ventas.ped_bogota         FROM 'csv/ventas.ped_bogota.csv' WITH (FORMAT csv, HEADER)
\copy ventas.ped_medellin       FROM 'csv/ventas.ped_medellin.csv' WITH (FORMAT csv, HEADER)
\copy ventas.ped_cali           FROM 'csv/ventas.ped_cali.csv' WITH (FORMAT csv, HEADER)
\copy ventas.ped_cedi           FROM 'csv/ventas.ped_cedi.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_bogota     FROM 'csv/ventas.det_ped_bogota.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_medellin   FROM 'csv/ventas.det_ped_medellin.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_cali       FROM 'csv/ventas.det_ped_cali.csv' WITH (FORMAT csv, HEADER)
\copy ventas.det_ped_cedi       FROM 'csv/ventas.det_ped_cedi.csv' WITH (FORMAT csv, HEADER)
\copy ventas.pagos              FROM 'csv/ventas.pagos.csv' WITH (FORMAT csv, HEADER)
\copy ventas.devoluciones       FROM 'csv/ventas.devoluciones.csv' WITH (FORMAT csv, HEADER)
\copy ventas.detalle_devolucion FROM 'csv/ventas.detalle_devolucion.csv' WITH (FORMAT csv, HEADER)

-- se marca cada esquema como copia, para que nadie se confunda en \dn+
COMMENT ON SCHEMA catalogo    IS 'Copia de solo lectura de andina_catalogo';
COMMENT ON SCHEMA identidad   IS 'Copia de solo lectura de andina_identidad (solo empleados)';
COMMENT ON SCHEMA compras     IS 'Copia de solo lectura de andina_compras';
COMMENT ON SCHEMA inventarios IS 'Copia de solo lectura de andina_inventarios';
COMMENT ON SCHEMA ventas      IS 'Copia de solo lectura de andina_ventas';
