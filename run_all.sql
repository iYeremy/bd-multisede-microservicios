-- =====================================================================
-- run_all.sql
-- Ejecuta todos los scripts en orden. Uso (desde cualquier carpeta):
--     psql -U postgres -d comercializadora -f run_all.sql
-- =====================================================================

\set ON_ERROR_STOP on
\pset pager off
SET client_min_messages = warning;

\echo '>> 00 Reset'
\ir sql/00_reset.sql
\echo '>> 01 Esquemas'
\ir sql/01_esquemas.sql
\echo '>> 02 Catálogo'
\ir sql/02_catalogo.sql
\echo '>> 03 Identidad'
\ir sql/03_identidad.sql
\echo '>> 04 Compras'
\ir sql/04_compras.sql
\echo '>> 05 Inventarios (fragmentos por sede)'
\ir sql/05_inventarios.sql
\echo '>> 06 Ventas (fragmentos por sede)'
\ir sql/06_ventas.sql
\echo '>> 07 Datos de prueba'
\ir sql/07_datos.sql
\echo '>> 08 Vistas'
\ir sql/08_vistas.sql
\echo '>> 09 Roles y permisos'
\ir sql/09_roles.sql

SET client_min_messages = notice;
\echo '>> 10 Consultas'
\ir sql/10_consultas.sql
\echo '>> 11 Pruebas'
\ir sql/11_pruebas.sql
