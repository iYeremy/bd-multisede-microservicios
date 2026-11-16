-- 06_roles/identidad.sql
-- roles y permisos de la instancia de identidad (base andina_identidad).
-- cada instancia crea solo los roles que usa. ver README.md.

-- grupos
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;

-- usuarios (contrasena de ejemplo: Andina2026*)
CREATE ROLE admin_andina    LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE auditor_interno LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;

-- usuario tecnico del servicio, sin contrasena: se pone al desplegar
CREATE ROLE svc_identidad LOGIN;

-- quien entra a esta base
GRANT CONNECT, CREATE ON DATABASE andina_identidad TO rol_administrador;
GRANT CONNECT ON DATABASE andina_identidad TO rol_auditor, svc_identidad;

-- el auditor no ve password_hash (SELECT por columnas)
GRANT USAGE ON SCHEMA identidad TO rol_administrador, rol_auditor, svc_identidad;
GRANT ALL ON ALL TABLES IN SCHEMA identidad TO rol_administrador WITH GRANT OPTION;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA identidad TO svc_identidad;

GRANT SELECT ON identidad.empleados, identidad.auditoria_accesos TO rol_auditor;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion) ON identidad.usuarios TO rol_auditor;

-- sin superusuario (neon): quien corre los scripts necesita ser miembro
-- de los usuarios para poder probarlos con SET ROLE en 08_pruebas
\if :no_superusuario
GRANT admin_andina, auditor_interno TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;
\endif
