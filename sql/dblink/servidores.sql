-- =====================================================================
-- dblink/servidores.sql
-- prepara dblink en la base donde se corre: instala la extension y
-- registra las otras bases como "servidores remotos".
--
-- dblink es una extension de postgresql que deja, desde una base,
-- ejecutar una consulta en OTRA base y traer el resultado como si fuera
-- una tabla:
--     SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, nombre FROM catalogo.productos')
--              AS t(id_producto INTEGER, nombre VARCHAR(100));
-- el AS t(...) es obligatorio: dblink no sabe que columnas trae, hay que
-- decirle el nombre y el tipo de cada una.
--
-- ojo con la arquitectura: con dblink una base SI lee los datos de otra.
-- eso acopla los servicios (si catalogo cambia una columna, reportes se
-- rompe). por eso solo lo usan reportes y, mientras se generan, los
-- datos de prueba (y ahi se quita al terminar, ver dblink/quitar.sql).
-- la version sin dblink (ETL con CSV) esta en la rama feat/microservicios-reales.
-- =====================================================================

-- CREATE EXTENSION instala dblink en esta base (viene con postgresql,
-- en el paquete "contrib"). IF NOT EXISTS: si ya esta, no hace nada.
CREATE EXTENSION IF NOT EXISTS dblink;

-- ---------------------------------------------------------------------
-- servidores remotos
-- en vez de escribir los datos de conexion en cada llamada
-- ('dbname=andina_catalogo user=postgres ...'), cada base se registra
-- una vez con un nombre (srv_catalogo...) y dblink usa ese nombre.
-- dblink_fdw es el "conector" que trae la extension.
-- sin host ni port se conecta al mismo servidor postgresql, por el
-- socket local.
-- ---------------------------------------------------------------------
CREATE SERVER srv_catalogo    FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_catalogo');
CREATE SERVER srv_identidad   FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_identidad');
CREATE SERVER srv_compras     FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_compras');
CREATE SERVER srv_inventarios FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_inventarios');
CREATE SERVER srv_ventas      FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_ventas');

-- con que usuario se conecta: el mismo que corre el script (postgres).
-- USER MAPPING guarda el usuario (y la contrasena, si hace falta) para
-- cada servidor.
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_catalogo    OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_identidad   OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_compras     OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_inventarios OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_ventas      OPTIONS (user 'postgres');

-- ---------------------------------------------------------------------
-- opcional: host y contrasena
-- si postgresql no acepta la conexion por el socket local sin
-- contrasena, se pasan al correr psql (asi nada queda en el repo):
--     psql -U postgres -v dblink_host=localhost -v dblink_password=... -f run_all.sql
-- :{?variable} es true si la variable de psql existe.
-- ---------------------------------------------------------------------
\if :{?dblink_host}
ALTER SERVER srv_catalogo    OPTIONS (ADD host :'dblink_host');
ALTER SERVER srv_identidad   OPTIONS (ADD host :'dblink_host');
ALTER SERVER srv_compras     OPTIONS (ADD host :'dblink_host');
ALTER SERVER srv_inventarios OPTIONS (ADD host :'dblink_host');
ALTER SERVER srv_ventas      OPTIONS (ADD host :'dblink_host');
\endif

\if :{?dblink_password}
ALTER USER MAPPING FOR CURRENT_USER SERVER srv_catalogo    OPTIONS (ADD password :'dblink_password');
ALTER USER MAPPING FOR CURRENT_USER SERVER srv_identidad   OPTIONS (ADD password :'dblink_password');
ALTER USER MAPPING FOR CURRENT_USER SERVER srv_compras     OPTIONS (ADD password :'dblink_password');
ALTER USER MAPPING FOR CURRENT_USER SERVER srv_inventarios OPTIONS (ADD password :'dblink_password');
ALTER USER MAPPING FOR CURRENT_USER SERVER srv_ventas      OPTIONS (ADD password :'dblink_password');
\endif
