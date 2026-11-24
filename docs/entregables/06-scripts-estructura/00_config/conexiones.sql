-- 00_config/conexiones.sql
-- lee la conexion de cada servicio desde las variables de entorno (que
-- carga scripts/correr.sh desde config/*.env) y arma una direccion por
-- servicio. ver README.md.

\getenv admin_db ADMIN_DB
\getenv sslmode SSLMODE
\getenv no_superusuario NO_SUPERUSUARIO

-- si falta algo, se para aqui con un mensaje claro
\if :{?admin_db}
\else
    \echo 'faltan las variables de conexion: correr con scripts/correr.sh config/local.env'
    \quit
\endif

-- catalogo
\getenv catalogo_host CATALOGO_HOST
\getenv catalogo_port CATALOGO_PORT
\getenv catalogo_user CATALOGO_USER
\getenv catalogo_password CATALOGO_PASSWORD
\set catalogo_db andina_catalogo
\set conn_catalogo_admin 'postgresql://' :catalogo_user ':' :catalogo_password '@' :catalogo_host ':' :catalogo_port '/' :admin_db '?sslmode=' :sslmode
\set conn_catalogo 'postgresql://' :catalogo_user ':' :catalogo_password '@' :catalogo_host ':' :catalogo_port '/' :catalogo_db '?sslmode=' :sslmode

-- identidad
\getenv identidad_host IDENTIDAD_HOST
\getenv identidad_port IDENTIDAD_PORT
\getenv identidad_user IDENTIDAD_USER
\getenv identidad_password IDENTIDAD_PASSWORD
\set identidad_db andina_identidad
\set conn_identidad_admin 'postgresql://' :identidad_user ':' :identidad_password '@' :identidad_host ':' :identidad_port '/' :admin_db '?sslmode=' :sslmode
\set conn_identidad 'postgresql://' :identidad_user ':' :identidad_password '@' :identidad_host ':' :identidad_port '/' :identidad_db '?sslmode=' :sslmode

-- compras
\getenv compras_host COMPRAS_HOST
\getenv compras_port COMPRAS_PORT
\getenv compras_user COMPRAS_USER
\getenv compras_password COMPRAS_PASSWORD
\set compras_db andina_compras
\set conn_compras_admin 'postgresql://' :compras_user ':' :compras_password '@' :compras_host ':' :compras_port '/' :admin_db '?sslmode=' :sslmode
\set conn_compras 'postgresql://' :compras_user ':' :compras_password '@' :compras_host ':' :compras_port '/' :compras_db '?sslmode=' :sslmode

-- inventarios
\getenv inventarios_host INVENTARIOS_HOST
\getenv inventarios_port INVENTARIOS_PORT
\getenv inventarios_user INVENTARIOS_USER
\getenv inventarios_password INVENTARIOS_PASSWORD
\set inventarios_db andina_inventarios
\set conn_inventarios_admin 'postgresql://' :inventarios_user ':' :inventarios_password '@' :inventarios_host ':' :inventarios_port '/' :admin_db '?sslmode=' :sslmode
\set conn_inventarios 'postgresql://' :inventarios_user ':' :inventarios_password '@' :inventarios_host ':' :inventarios_port '/' :inventarios_db '?sslmode=' :sslmode

-- ventas
\getenv ventas_host VENTAS_HOST
\getenv ventas_port VENTAS_PORT
\getenv ventas_user VENTAS_USER
\getenv ventas_password VENTAS_PASSWORD
\set ventas_db andina_ventas
\set conn_ventas_admin 'postgresql://' :ventas_user ':' :ventas_password '@' :ventas_host ':' :ventas_port '/' :admin_db '?sslmode=' :sslmode
\set conn_ventas 'postgresql://' :ventas_user ':' :ventas_password '@' :ventas_host ':' :ventas_port '/' :ventas_db '?sslmode=' :sslmode

-- reportes
\getenv reportes_host REPORTES_HOST
\getenv reportes_port REPORTES_PORT
\getenv reportes_user REPORTES_USER
\getenv reportes_password REPORTES_PASSWORD
\set reportes_db andina_reportes
\set conn_reportes_admin 'postgresql://' :reportes_user ':' :reportes_password '@' :reportes_host ':' :reportes_port '/' :admin_db '?sslmode=' :sslmode
\set conn_reportes 'postgresql://' :reportes_user ':' :reportes_password '@' :reportes_host ':' :reportes_port '/' :reportes_db '?sslmode=' :sslmode
