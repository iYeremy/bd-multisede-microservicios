-- =====================================================================
-- etl/cargar.sql
-- ETL, paso L (cargar): mete en el staging de andina_reportes los CSV
-- que dejaron los extraer_*.sql. se corre conectado a andina_reportes.
--
-- el staging son las tablas de los esquemas catalogo, identidad,
-- compras, inventarios y ventas DENTRO de andina_reportes: una copia de
-- lo que hay en cada servicio. no son datos nuevos, y nadie escribe ahi
-- salvo este script.
--
-- es una carga completa: se borra todo el staging y se vuelve a llenar.
-- con estos volumenes es lo mas simple. (la otra opcion, una carga
-- incremental, traeria solo lo que cambio, pero es mucho mas compleja.)
--
-- todo va en UNA transaccion (BEGIN ... COMMIT): si algo falla, no se
-- guarda nada y el staging se queda como estaba. asi los reportes nunca
-- ven datos a medias.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. vaciar el staging. primero las tablas hijas y despues las padre,
--    porque las FK no dejan borrar un padre que todavia tiene hijos.
-- ---------------------------------------------------------------------
-- catalogo
DELETE FROM catalogo.producto_proveedor;
DELETE FROM catalogo.almacenes;
DELETE FROM catalogo.productos;
DELETE FROM catalogo.sedes;
DELETE FROM catalogo.categorias;
DELETE FROM catalogo.proveedores;
DELETE FROM catalogo.clientes;

-- identidad
DELETE FROM identidad.empleados;

-- compras
DELETE FROM compras.detalle_recepcion;
DELETE FROM compras.recepciones_compra;
DELETE FROM compras.detalle_orden_compra;
DELETE FROM compras.ordenes_compra;

-- inventarios
DELETE FROM inventarios.detalle_transferencia;
DELETE FROM inventarios.transferencias;
DELETE FROM inventarios.inv_bogota;
DELETE FROM inventarios.inv_medellin;
DELETE FROM inventarios.inv_cali;
DELETE FROM inventarios.inv_cedi;

-- ventas
DELETE FROM ventas.det_ped_bogota;
DELETE FROM ventas.det_ped_medellin;
DELETE FROM ventas.det_ped_cali;
DELETE FROM ventas.det_ped_cedi;
DELETE FROM ventas.ped_bogota;
DELETE FROM ventas.ped_medellin;
DELETE FROM ventas.ped_cali;
DELETE FROM ventas.ped_cedi;
DELETE FROM ventas.detalle_devolucion;
DELETE FROM ventas.devoluciones;
DELETE FROM ventas.pagos;

-- ---------------------------------------------------------------------
-- 2. cargar los CSV, ahora al reves: primero padres y despues hijas.
--    \copy ... FROM si guarda el id que trae el archivo aunque la columna
--    sea GENERATED ALWAYS AS IDENTITY, asi el staging queda con los
--    mismos ids que el original.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 3. control de la carga: cuantas filas habia en cada tabla de origen
--    (los conteo_*.csv de la extraccion) contra cuantas quedaron en el
--    staging. se guarda en etl.cargas.
--    esa tabla tiene un CHECK (filas_origen = filas_staging): si alguna
--    tabla no cuadra, el INSERT falla, la transaccion se cae y la carga
--    completa se deshace.
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_conteo_origen (tabla VARCHAR(60), filas INTEGER);
\copy tmp_conteo_origen FROM 'csv/conteo_catalogo.csv'    WITH (FORMAT csv, HEADER)
\copy tmp_conteo_origen FROM 'csv/conteo_identidad.csv'   WITH (FORMAT csv, HEADER)
\copy tmp_conteo_origen FROM 'csv/conteo_compras.csv'     WITH (FORMAT csv, HEADER)
\copy tmp_conteo_origen FROM 'csv/conteo_inventarios.csv' WITH (FORMAT csv, HEADER)
\copy tmp_conteo_origen FROM 'csv/conteo_ventas.csv'      WITH (FORMAT csv, HEADER)

-- now() da la hora en que empezo la transaccion, asi todas las filas de
-- esta carga quedan con la misma fecha_carga.
INSERT INTO etl.cargas (fecha_carga, tabla, filas_origen, filas_staging)
SELECT now(), o.tabla, o.filas, s.filas
FROM tmp_conteo_origen o
JOIN (
      SELECT 'catalogo.sedes'                    AS tabla, COUNT(*) AS filas FROM catalogo.sedes
      UNION ALL SELECT 'catalogo.almacenes'               , COUNT(*) FROM catalogo.almacenes
      UNION ALL SELECT 'catalogo.categorias'              , COUNT(*) FROM catalogo.categorias
      UNION ALL SELECT 'catalogo.productos'               , COUNT(*) FROM catalogo.productos
      UNION ALL SELECT 'catalogo.proveedores'             , COUNT(*) FROM catalogo.proveedores
      UNION ALL SELECT 'catalogo.producto_proveedor'      , COUNT(*) FROM catalogo.producto_proveedor
      UNION ALL SELECT 'catalogo.clientes'                , COUNT(*) FROM catalogo.clientes
      UNION ALL SELECT 'identidad.empleados'              , COUNT(*) FROM identidad.empleados
      UNION ALL SELECT 'compras.ordenes_compra'           , COUNT(*) FROM compras.ordenes_compra
      UNION ALL SELECT 'compras.detalle_orden_compra'     , COUNT(*) FROM compras.detalle_orden_compra
      UNION ALL SELECT 'compras.recepciones_compra'       , COUNT(*) FROM compras.recepciones_compra
      UNION ALL SELECT 'compras.detalle_recepcion'        , COUNT(*) FROM compras.detalle_recepcion
      UNION ALL SELECT 'inventarios.inv_bogota'           , COUNT(*) FROM inventarios.inv_bogota
      UNION ALL SELECT 'inventarios.inv_medellin'         , COUNT(*) FROM inventarios.inv_medellin
      UNION ALL SELECT 'inventarios.inv_cali'             , COUNT(*) FROM inventarios.inv_cali
      UNION ALL SELECT 'inventarios.inv_cedi'             , COUNT(*) FROM inventarios.inv_cedi
      UNION ALL SELECT 'inventarios.transferencias'       , COUNT(*) FROM inventarios.transferencias
      UNION ALL SELECT 'inventarios.detalle_transferencia', COUNT(*) FROM inventarios.detalle_transferencia
      UNION ALL SELECT 'ventas.ped_bogota'                , COUNT(*) FROM ventas.ped_bogota
      UNION ALL SELECT 'ventas.ped_medellin'              , COUNT(*) FROM ventas.ped_medellin
      UNION ALL SELECT 'ventas.ped_cali'                  , COUNT(*) FROM ventas.ped_cali
      UNION ALL SELECT 'ventas.ped_cedi'                  , COUNT(*) FROM ventas.ped_cedi
      UNION ALL SELECT 'ventas.det_ped_bogota'            , COUNT(*) FROM ventas.det_ped_bogota
      UNION ALL SELECT 'ventas.det_ped_medellin'          , COUNT(*) FROM ventas.det_ped_medellin
      UNION ALL SELECT 'ventas.det_ped_cali'              , COUNT(*) FROM ventas.det_ped_cali
      UNION ALL SELECT 'ventas.det_ped_cedi'              , COUNT(*) FROM ventas.det_ped_cedi
      UNION ALL SELECT 'ventas.pagos'                     , COUNT(*) FROM ventas.pagos
      UNION ALL SELECT 'ventas.devoluciones'              , COUNT(*) FROM ventas.devoluciones
      UNION ALL SELECT 'ventas.detalle_devolucion'        , COUNT(*) FROM ventas.detalle_devolucion
) s ON s.tabla = o.tabla;

DROP TABLE tmp_conteo_origen;

COMMIT;
