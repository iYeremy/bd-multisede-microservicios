-- =====================================================================
-- run_all.sql
-- ejecuta todo el proyecto en orden: borra, crea las 6 bases, crea las
-- tablas y los datos de cada servicio, arma la copia de reportes con
-- sus vistas, da los permisos, corre las 20 consultas y las pruebas.
--
-- uso (DESDE LA CARPETA DEL PROYECTO, porque los CSV se guardan en csv/):
--     psql -U postgres -f run_all.sql
--
-- se puede correr las veces que se quiera: 00_reset.sql borra todo y los
-- datos usan una semilla fija, asi el resultado siempre es el mismo.
--
-- las lineas que empiezan con \ son comandos de psql (el cliente), no
-- SQL: el servidor nunca las ve. por eso estos scripts se corren con
-- psql y no con pgAdmin (ver manual-ejecucion.md).
--
-- como funciona, en corto:
--   1. cada microservicio tiene su base (andina_catalogo, andina_ventas...)
--      con sus tablas y sus datos.
--   2. cada servicio exporta sus tablas a CSV (sql/sync/exportar_*.sql).
--   3. andina_reportes crea las mismas tablas, carga los CSV (su copia
--      de lectura) y encima crea las vistas.
--   4. las consultas corren en andina_reportes, donde esta todo junto.
-- =====================================================================

-- si una instruccion falla, psql se detiene en vez de seguir con todo a
-- medio crear. 11_pruebas.sql lo apaga mientras corre, porque ahi los
-- errores son el resultado esperado.
\set ON_ERROR_STOP on

-- muestra los resultados largos de una vez, sin el paginador (less).
\pset pager off

-- \c base   se conecta a otra base (cierra la conexion anterior). cada
--           script corre conectado a la base de su servicio.
-- \echo     imprime un texto para saber en que paso va la ejecucion.
-- \ir       incluye otro archivo con una ruta relativa a ESTE archivo
--           (\i la tomaria relativa a la carpeta desde donde se lanzo
--           psql).

-- ---------------------------------------------------------------------
-- borrar y crear las bases (desde la base postgres)
-- ---------------------------------------------------------------------
\c postgres
-- oculta los avisos NOTICE (por ejemplo "la base no existe, se omite"
-- del DROP ... IF EXISTS). solo dura en esta conexion.
SET client_min_messages = warning;
\echo '>> 00 reset'
\ir sql/00_reset.sql
\echo '>> 01 bases (una por microservicio)'
\ir sql/01_bases.sql

-- ---------------------------------------------------------------------
-- un servicio a la vez: tablas, datos y exportar a CSV.
-- el orden importa: catalogo va primero porque los demas usan sus ids
-- y sus CSV; ventas va despues de inventarios porque solo vende lo que
-- hay en cada almacen.
-- ---------------------------------------------------------------------
\echo '>> catalogo'
\c andina_catalogo
\ir sql/02_catalogo.sql
\ir sql/07_datos_catalogo.sql
\ir sql/sync/exportar_catalogo.sql

\echo '>> identidad'
\c andina_identidad
\ir sql/03_identidad.sql
\ir sql/07_datos_identidad.sql
\ir sql/sync/exportar_identidad.sql

\echo '>> compras'
\c andina_compras
\ir sql/04_compras.sql
\ir sql/07_datos_compras.sql
\ir sql/sync/exportar_compras.sql

\echo '>> inventarios (fragmentos por sede)'
\c andina_inventarios
\ir sql/05_inventarios.sql
\ir sql/07_datos_inventarios.sql
\ir sql/sync/exportar_inventarios.sql

\echo '>> ventas (fragmentos por sede)'
\c andina_ventas
\ir sql/06_ventas.sql
\ir sql/07_datos_ventas.sql
\ir sql/sync/exportar_ventas.sql

-- ---------------------------------------------------------------------
-- reportes: las mismas tablas (02 a 06) para la copia, los CSV y las
-- vistas
-- ---------------------------------------------------------------------
\echo '>> reportes: copia de lectura'
\c andina_reportes
\ir sql/02_catalogo.sql
\ir sql/03_identidad.sql
\ir sql/04_compras.sql
\ir sql/05_inventarios.sql
\ir sql/06_ventas.sql
\ir sql/sync/importar_reportes.sql
\echo '>> 08 vistas'
\ir sql/08_vistas.sql

-- los roles van al final porque los GRANT ... ON ALL TABLES solo
-- alcanzan a las tablas que ya existen. 09 se conecta a cada base.
\echo '>> 09 roles y permisos'
\ir sql/09_roles.sql

-- desde aqui, las consultas y las pruebas son la evidencia que se
-- entrega
\echo '>> 10 consultas'
\c andina_reportes
\ir sql/10_consultas.sql
\echo '>> 11 pruebas'
\ir sql/11_pruebas.sql
