-- 03_dblink/servidores.sql
-- instala dblink en la base actual y registra las otras bases como
-- servidores remotos (srv_catalogo, srv_ventas...). ver README.md.

CREATE EXTENSION IF NOT EXISTS dblink;

-- cada base se registra una vez con un nombre
CREATE SERVER srv_catalogo    FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_catalogo');
CREATE SERVER srv_identidad   FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_identidad');
CREATE SERVER srv_compras     FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_compras');
CREATE SERVER srv_inventarios FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_inventarios');
CREATE SERVER srv_ventas      FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_ventas');

-- con que usuario se conecta a cada una
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_catalogo    OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_identidad   OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_compras     OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_inventarios OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_ventas      OPTIONS (user 'postgres');

-- opcional: host y contrasena, si se pasan con psql -v (asi no quedan en el repo)
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
