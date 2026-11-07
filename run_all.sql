-- =====================================================================
-- run_all.sql
-- ejecuta todo el proyecto en orden: borra, crea, carga datos, crea
-- vistas y roles, corre las 20 consultas y las pruebas.
--
-- uso (desde la carpeta del proyecto):
--     psql -U postgres -d comercializadora -f run_all.sql
--
-- se puede correr las veces que se quiera: 00_reset.sql deja la base
-- limpia y los datos usan una semilla fija, asi el resultado siempre es
-- el mismo.
--
-- las lineas que empiezan con \ son comandos de psql (el cliente), no
-- SQL: el servidor nunca las ve. por eso estos scripts se corren con
-- psql y no con pgAdmin (ver manual-ejecucion.md, seccion 4).
-- =====================================================================

-- si una instruccion falla, psql se detiene en vez de seguir con la
-- base a medio crear. 11_pruebas.sql lo apaga mientras corre, porque
-- ahi los errores son el resultado esperado.
\set ON_ERROR_STOP on

-- muestra los resultados largos de una vez, sin el paginador (less).
\pset pager off

-- oculta los avisos NOTICE (por ejemplo "el esquema no existe, se
-- omite" del DROP ... IF EXISTS). solo se muestran WARNING y ERROR.
SET client_min_messages = warning;

-- \echo imprime un texto para saber en que paso va la ejecucion.
-- \ir incluye otro archivo con una ruta relativa a ESTE archivo (\i la
-- tomaria relativa a la carpeta desde donde se lanzo psql).
--
-- el orden importa: primero los datos maestros (catalogo, identidad),
-- despues los servicios que guardan sus identificadores, luego los
-- datos, las vistas y al final los roles, porque los GRANT ... ON ALL
-- TABLES solo alcanzan a los objetos que ya existen.
\echo '>> 00 reset'
\ir sql/00_reset.sql
\echo '>> 01 esquemas'
\ir sql/01_esquemas.sql
\echo '>> 02 catalogo'
\ir sql/02_catalogo.sql
\echo '>> 03 identidad'
\ir sql/03_identidad.sql
\echo '>> 04 compras'
\ir sql/04_compras.sql
\echo '>> 05 inventarios (fragmentos por sede)'
\ir sql/05_inventarios.sql
\echo '>> 06 ventas (fragmentos por sede)'
\ir sql/06_ventas.sql
\echo '>> 07 datos de prueba'
\ir sql/07_datos.sql
\echo '>> 08 vistas'
\ir sql/08_vistas.sql
\echo '>> 09 roles y permisos'
\ir sql/09_roles.sql

-- desde aqui se vuelven a mostrar los avisos normales: las consultas y
-- las pruebas son la evidencia que se entrega.
SET client_min_messages = notice;
\echo '>> 10 consultas'
\ir sql/10_consultas.sql
\echo '>> 11 pruebas'
\ir sql/11_pruebas.sql
