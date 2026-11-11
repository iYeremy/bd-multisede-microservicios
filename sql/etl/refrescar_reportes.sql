-- =====================================================================
-- etl/refrescar_reportes.sql
-- corre el ETL completo: extraer de cada servicio, cargar el staging y
-- transformar (refrescar las vistas materializadas). es lo que se
-- programa para que corra cada X minutos.
--
-- uso, DESDE LA CARPETA DEL PROYECTO (por la carpeta csv/):
--     psql -U postgres -d postgres -f sql/etl/refrescar_reportes.sql
--
-- para que corra solo cada 5 minutos, una linea en el crontab del
-- servidor (crontab -e):
--     */5 * * * * cd /ruta/del/proyecto && psql -U postgres -d postgres -f sql/etl/refrescar_reportes.sql
-- "*/5 * * * *" = cada 5 minutos, a toda hora, todos los dias. cuando
-- exista el backend, esto lo hara el servicio de reportes.
--
-- ojo con la idea principal: ninguna base se conecta a otra. este
-- script es un proceso aparte (psql) que entra a cada base, saca los
-- datos y los lleva a reportes.
-- =====================================================================

-- si algo falla, se detiene, y como cargar.sql y transformar.sql van en
-- una transaccion, los reportes se quedan con la ultima carga buena.
-- ON_ERROR_ROLLBACK off: si un paso de la carga falla, se cae la carga
-- entera (no solo esa instruccion).
\set ON_ERROR_STOP on
\set ON_ERROR_ROLLBACK off

\echo '>> ETL: extraer de cada servicio'
\c andina_catalogo
\ir extraer_catalogo.sql
\c andina_identidad
\ir extraer_identidad.sql
\c andina_compras
\ir extraer_compras.sql
\c andina_inventarios
\ir extraer_inventarios.sql
\c andina_ventas
\ir extraer_ventas.sql

\echo '>> ETL: cargar el staging de reportes'
\c andina_reportes
\ir cargar.sql

\echo '>> ETL: transformar (refrescar las vistas materializadas)'
\ir transformar.sql

\echo '>> ETL: ultima carga'
SELECT * FROM reportes.vista_ultima_carga;
