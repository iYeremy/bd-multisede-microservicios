-- 03_dblink/servidores.sql
-- instala dblink en la base actual y guarda como conectarse a la base de
-- cada otro servicio (cada una vive en su propia instancia). los datos
-- salen de la configuracion (00_config). ver README.md.

CREATE EXTENSION IF NOT EXISTS dblink;

-- esquema privado: solo el dueno puede ver las conexiones (llevan clave)
CREATE SCHEMA remoto;
REVOKE ALL ON SCHEMA remoto FROM PUBLIC;

-- una fila por servicio con su cadena de conexion
CREATE TABLE remoto.servidores (
    nombre   VARCHAR(20) PRIMARY KEY,
    conexion TEXT        NOT NULL
);

-- la clave solo se agrega si existe (en local las instancias no piden)
INSERT INTO remoto.servidores (nombre, conexion) VALUES
    ('catalogo', 'host=' || :'catalogo_host' || ' port=' || :'catalogo_port' || ' dbname=' || :'catalogo_db'
         || ' user=' || :'catalogo_user' || ' sslmode=' || :'sslmode'
         || CASE WHEN :'catalogo_password' <> '' THEN ' password=' || :'catalogo_password' ELSE '' END),
    ('identidad', 'host=' || :'identidad_host' || ' port=' || :'identidad_port' || ' dbname=' || :'identidad_db'
         || ' user=' || :'identidad_user' || ' sslmode=' || :'sslmode'
         || CASE WHEN :'identidad_password' <> '' THEN ' password=' || :'identidad_password' ELSE '' END),
    ('compras', 'host=' || :'compras_host' || ' port=' || :'compras_port' || ' dbname=' || :'compras_db'
         || ' user=' || :'compras_user' || ' sslmode=' || :'sslmode'
         || CASE WHEN :'compras_password' <> '' THEN ' password=' || :'compras_password' ELSE '' END),
    ('inventarios', 'host=' || :'inventarios_host' || ' port=' || :'inventarios_port' || ' dbname=' || :'inventarios_db'
         || ' user=' || :'inventarios_user' || ' sslmode=' || :'sslmode'
         || CASE WHEN :'inventarios_password' <> '' THEN ' password=' || :'inventarios_password' ELSE '' END),
    ('ventas', 'host=' || :'ventas_host' || ' port=' || :'ventas_port' || ' dbname=' || :'ventas_db'
         || ' user=' || :'ventas_user' || ' sslmode=' || :'sslmode'
         || CASE WHEN :'ventas_password' <> '' THEN ' password=' || :'ventas_password' ELSE '' END);

-- remoto.servidor('catalogo') devuelve la conexion de catalogo, para
-- usarla asi: dblink(remoto.servidor('catalogo'), 'SELECT ...')
CREATE FUNCTION remoto.servidor(p_nombre TEXT) RETURNS TEXT
LANGUAGE sql STABLE
AS 'SELECT conexion FROM remoto.servidores WHERE nombre = p_nombre';

REVOKE EXECUTE ON FUNCTION remoto.servidor(TEXT) FROM PUBLIC;
