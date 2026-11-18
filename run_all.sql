-- run_all.sql
-- ejecuta todo el proyecto en orden, en 6 instancias de postgresql (una
-- por microservicio). ver sql/README.md
--     scripts/correr.sh config/local.env     (instancias locales)
--     scripts/correr.sh config/neon.env      (neon)

\set ON_ERROR_STOP on
\pset pager off

-- conexion de cada servicio (sale de config/*.env)
\ir sql/00_config/conexiones.sql

-- cada servicio en su instancia: borrar y crear su base, tablas, datos y
-- roles. catalogo va primero: los datos de los demas lo leen con dblink

\echo '>> catalogo'
\c :conn_catalogo_admin
SET client_min_messages = warning;
\set db andina_catalogo
\set comentario 'Microservicio de Catalogo y Terceros (datos maestros)'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/crear.sql
\c :conn_catalogo
\ir sql/02_tablas/catalogo.sql
\ir sql/04_datos/catalogo.sql
\ir sql/06_roles/catalogo.sql

\echo '>> identidad'
\c :conn_identidad_admin
SET client_min_messages = warning;
\set db andina_identidad
\set comentario 'Microservicio de Identidad y Accesos'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/crear.sql
\c :conn_identidad
\ir sql/02_tablas/identidad.sql
\ir sql/04_datos/identidad.sql
\ir sql/06_roles/identidad.sql

\echo '>> compras'
\c :conn_compras_admin
SET client_min_messages = warning;
\set db andina_compras
\set comentario 'Microservicio de Compras y Abastecimiento'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/crear.sql
\c :conn_compras
\ir sql/02_tablas/compras.sql
\ir sql/04_datos/compras.sql
\ir sql/06_roles/compras.sql

\echo '>> inventarios'
\c :conn_inventarios_admin
SET client_min_messages = warning;
\set db andina_inventarios
\set comentario 'Microservicio de Inventarios y Transferencias (inventarios fragmentado por sede)'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/crear.sql
\c :conn_inventarios
\ir sql/02_tablas/inventarios.sql
\ir sql/04_datos/inventarios.sql
\ir sql/06_roles/inventarios.sql

\echo '>> ventas'
\c :conn_ventas_admin
SET client_min_messages = warning;
\set db andina_ventas
\set comentario 'Microservicio de Ventas y Pagos (pedidos y detalles fragmentados por sede)'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/crear.sql
\c :conn_ventas
\ir sql/02_tablas/ventas.sql
\ir sql/04_datos/ventas.sql
\ir sql/06_roles/ventas.sql

-- reportes: dblink, vistas materializadas (vacias), el primer refresco
-- y al final sus roles (los GRANT necesitan que las vistas existan)
\echo '>> reportes'
\c :conn_reportes_admin
SET client_min_messages = warning;
\set db andina_reportes
\set comentario 'Microservicio de Reportes Corporativos: vistas materializadas que traen los datos por dblink'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/crear.sql
\c :conn_reportes
\ir sql/03_dblink/servidores.sql
\ir sql/05_reportes/vistas.sql
\ir sql/05_reportes/refrescar.sql
\ir sql/06_roles/reportes.sql

\echo '>> consultas'
\c :conn_reportes
\ir sql/07_consultas/consultas.sql

\echo '>> pruebas'
\ir sql/08_pruebas/pruebas.sql
