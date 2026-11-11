-- =====================================================================
-- run_all.sql
-- ejecuta todo el proyecto en orden: borra, crea las 6 bases, crea las
-- tablas y los datos de cada servicio, corre el ETL hacia reportes y
-- crea sus vistas, da los permisos, corre las 20 consultas y las pruebas.
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
--      con sus tablas y sus datos. ninguna base se conecta a otra.
--   2. ETL hacia reportes (carpeta sql/etl/):
--        E  extraer: cada base deja sus tablas en CSV (extraer_*.sql)
--        L  cargar: andina_reportes las mete en su staging (cargar.sql)
--        T  transformar: se refrescan las vistas materializadas
--           (transformar.sql)
--   3. las consultas corren en andina_reportes, donde esta todo junto.
--
-- despues, para poner los reportes al dia, solo se corre el ETL:
--     psql -U postgres -d postgres -f sql/etl/refrescar_reportes.sql
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
-- un servicio a la vez: tablas, datos y extraer a CSV (paso E del ETL;
-- se hace aqui de una vez porque los datos de prueba de otros servicios
-- leen esos CSV).
-- el orden importa: catalogo va primero porque los demas usan sus ids
-- y sus CSV; ventas va despues de inventarios porque solo vende lo que
-- hay en cada almacen.
-- ---------------------------------------------------------------------
\echo '>> catalogo'
\c andina_catalogo
\ir sql/02_catalogo.sql
\ir sql/07_datos_catalogo.sql
\ir sql/etl/extraer_catalogo.sql

\echo '>> identidad'
\c andina_identidad
\ir sql/03_identidad.sql
\ir sql/07_datos_identidad.sql
\ir sql/etl/extraer_identidad.sql

\echo '>> compras'
\c andina_compras
\ir sql/04_compras.sql
\ir sql/07_datos_compras.sql
\ir sql/etl/extraer_compras.sql

\echo '>> inventarios (fragmentos por sede)'
\c andina_inventarios
\ir sql/05_inventarios.sql
\ir sql/07_datos_inventarios.sql
\ir sql/etl/extraer_inventarios.sql

\echo '>> ventas (fragmentos por sede)'
\c andina_ventas
\ir sql/06_ventas.sql
\ir sql/07_datos_ventas.sql
\ir sql/etl/extraer_ventas.sql

-- ---------------------------------------------------------------------
-- reportes: el staging (las mismas tablas 02 a 06), las vistas
-- materializadas (vacias) y la primera corrida de L y T
-- ---------------------------------------------------------------------
\echo '>> reportes: staging'
\c andina_reportes
\ir sql/02_catalogo.sql
\ir sql/03_identidad.sql
\ir sql/04_compras.sql
\ir sql/05_inventarios.sql
\ir sql/06_ventas.sql
\ir sql/etl/staging.sql
\echo '>> 08 vistas (materializadas, todavia vacias)'
\ir sql/08_vistas.sql
\echo '>> ETL: cargar el staging y transformar'
\ir sql/etl/cargar.sql
\ir sql/etl/transformar.sql

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
