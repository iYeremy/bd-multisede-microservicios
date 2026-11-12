-- run_all.sql
-- ejecuta todo el proyecto en orden. ver sql/README.md
--     psql -U postgres -f run_all.sql
-- si dblink pide contrasena: ver sql/03_dblink/README.md

\set ON_ERROR_STOP on
\pset pager off

-- borrar y crear las 6 bases (desde la base postgres)
\c postgres
SET client_min_messages = warning;
\echo '>> bases'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/bases.sql

-- cada servicio en su base: tablas y datos de prueba
\echo '>> catalogo'
\c andina_catalogo
\ir sql/02_tablas/catalogo.sql
\ir sql/04_datos/catalogo.sql

\echo '>> identidad'
\c andina_identidad
\ir sql/02_tablas/identidad.sql
\ir sql/04_datos/identidad.sql

\echo '>> compras'
\c andina_compras
\ir sql/02_tablas/compras.sql
\ir sql/04_datos/compras.sql

\echo '>> inventarios (fragmentos por sede)'
\c andina_inventarios
\ir sql/02_tablas/inventarios.sql
\ir sql/04_datos/inventarios.sql

\echo '>> ventas (fragmentos por sede)'
\c andina_ventas
\ir sql/02_tablas/ventas.sql
\ir sql/04_datos/ventas.sql

-- reportes: dblink, vistas materializadas (vacias) y el primer refresco
\echo '>> reportes'
\c andina_reportes
\ir sql/03_dblink/servidores.sql
\ir sql/05_reportes/vistas.sql
\ir sql/05_reportes/refrescar.sql

-- los permisos al final: GRANT ... ON ALL TABLES solo ve lo que ya existe
\echo '>> roles y permisos'
\ir sql/06_roles/roles.sql

\echo '>> consultas'
\c andina_reportes
\ir sql/07_consultas/consultas.sql

\echo '>> pruebas'
\ir sql/08_pruebas/pruebas.sql
