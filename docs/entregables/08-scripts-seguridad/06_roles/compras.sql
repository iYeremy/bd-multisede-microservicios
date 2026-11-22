-- 06_roles/compras.sql
-- roles y permisos de la instancia de compras (base andina_compras).
-- cada instancia crea solo los roles que usa. ver README.md.

-- grupos
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;
CREATE ROLE rol_compras       NOLOGIN;

-- usuarios (contrasena de ejemplo: Andina2026*)
CREATE ROLE admin_andina    LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE auditor_interno LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;
CREATE ROLE compras_cedi    LOGIN PASSWORD 'Andina2026*' IN ROLE rol_compras;

-- usuario tecnico del servicio, sin contrasena: se pone al desplegar
CREATE ROLE svc_compras LOGIN;

-- quien entra a esta base
GRANT CONNECT, CREATE ON DATABASE andina_compras TO rol_administrador;
GRANT CONNECT ON DATABASE andina_compras TO rol_auditor, rol_compras, svc_compras;

GRANT USAGE ON SCHEMA compras TO rol_administrador, rol_auditor, rol_compras, svc_compras;
GRANT ALL    ON ALL TABLES IN SCHEMA compras TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA compras TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA compras TO rol_compras, svc_compras;

-- sin superusuario (neon): quien corre los scripts necesita ser miembro
-- de los usuarios para poder probarlos con SET ROLE en 08_pruebas
\if :no_superusuario
GRANT admin_andina, auditor_interno, compras_cedi TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;
\endif
