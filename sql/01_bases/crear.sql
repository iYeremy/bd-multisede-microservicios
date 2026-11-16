-- 01_bases/crear.sql
-- crea la base del servicio (:db) en la instancia actual. ver README.md.

CREATE DATABASE :"db";
COMMENT ON DATABASE :"db" IS :'comentario';

-- nadie entra hasta que 06_roles lo deje
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
