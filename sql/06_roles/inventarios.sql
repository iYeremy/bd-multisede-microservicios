-- 06_roles/inventarios.sql
-- roles y permisos de la instancia de inventarios (base andina_inventarios).
-- cada instancia crea solo los roles que usa. ver README.md.

-- grupos
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;
CREATE ROLE rol_inventario    NOLOGIN;

-- usuarios (contrasena de ejemplo: Andina2026*)
CREATE ROLE admin_andina      LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE auditor_interno   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;
CREATE ROLE inventario_bogota LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE inventario_cedi   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;

-- usuario tecnico del servicio, sin contrasena: se pone al desplegar
CREATE ROLE svc_inventarios LOGIN;

-- quien entra a esta base
GRANT CONNECT, CREATE ON DATABASE andina_inventarios TO rol_administrador;
GRANT CONNECT ON DATABASE andina_inventarios TO rol_auditor, rol_inventario, svc_inventarios;

-- cada usuario solo el fragmento de su sede
GRANT USAGE ON SCHEMA inventarios TO rol_administrador, rol_auditor, rol_inventario, svc_inventarios;
GRANT ALL    ON ALL TABLES IN SCHEMA inventarios TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA inventarios TO rol_auditor;
-- el servicio maneja los 4 fragmentos; el backend decide en cual escribe
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA inventarios TO svc_inventarios;

GRANT SELECT, INSERT, UPDATE ON inventarios.transferencias, inventarios.detalle_transferencia TO rol_inventario;
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_bogota TO inventario_bogota;   -- sede 1
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_cedi   TO inventario_cedi;     -- sede 4

-- sin superusuario (neon): quien corre los scripts necesita ser miembro
-- de los usuarios para poder probarlos con SET ROLE en 08_pruebas
\if :no_superusuario
GRANT admin_andina, auditor_interno, inventario_bogota, inventario_cedi TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;
\endif
