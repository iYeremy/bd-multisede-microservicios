-- 06_roles/reportes.sql
-- roles y permisos de la instancia de reportes (base andina_reportes).
-- cada instancia crea solo los roles que usa. ver README.md.

-- grupos
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;
CREATE ROLE rol_gerencia      NOLOGIN;
CREATE ROLE rol_inventario    NOLOGIN;
CREATE ROLE rol_compras       NOLOGIN;

-- usuarios (contrasena de ejemplo: Andina2026*)
CREATE ROLE admin_andina      LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE auditor_interno   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;
CREATE ROLE gerente_general   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_gerencia;
CREATE ROLE inventario_bogota LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE inventario_cedi   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE compras_cedi      LOGIN PASSWORD 'Andina2026*' IN ROLE rol_compras;

-- usuario tecnico del servicio, sin contrasena: se pone al desplegar
CREATE ROLE svc_reportes LOGIN;

-- quien entra a esta base
GRANT CONNECT, CREATE ON DATABASE andina_reportes TO rol_administrador;
GRANT CONNECT ON DATABASE andina_reportes TO rol_auditor, rol_gerencia, rol_inventario, rol_compras, svc_reportes;

-- solo vistas. las conexiones a las otras instancias estan en el esquema
-- privado remoto (03_dblink): solo el dueno de las vistas las puede usar

GRANT USAGE  ON SCHEMA reportes TO rol_administrador, rol_auditor, rol_gerencia,
                                   rol_inventario, rol_compras, svc_reportes;
GRANT SELECT ON ALL TABLES IN SCHEMA reportes TO rol_administrador, rol_auditor, rol_gerencia, svc_reportes;
GRANT MAINTAIN ON ALL TABLES IN SCHEMA reportes TO svc_reportes;

GRANT SELECT ON reportes.vista_alertas_reabastecimiento,
                reportes.vista_transferencias_en_transito,
                reportes.vista_productos_sin_inventario,
                reportes.vista_ultima_actualizacion TO rol_inventario;
GRANT SELECT ON reportes.vista_compras_pendientes,
                reportes.vista_ultima_actualizacion TO rol_compras;

-- sin superusuario (neon): quien corre los scripts necesita ser miembro
-- de los usuarios para poder probarlos con SET ROLE en 08_pruebas
\if :no_superusuario
GRANT admin_andina, auditor_interno, gerente_general, inventario_bogota, inventario_cedi, compras_cedi TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;
\endif
