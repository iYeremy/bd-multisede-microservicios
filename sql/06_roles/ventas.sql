-- 06_roles/ventas.sql
-- roles y permisos de la instancia de ventas (base andina_ventas).
-- cada instancia crea solo los roles que usa. ver README.md.

-- grupos
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;
CREATE ROLE rol_vendedor      NOLOGIN;

-- usuarios (contrasena de ejemplo: Andina2026*)
CREATE ROLE admin_andina    LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE auditor_interno LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;
CREATE ROLE vendedor_bogota LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;
CREATE ROLE vendedor_cali   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;

-- usuario tecnico del servicio, sin contrasena: se pone al desplegar
CREATE ROLE svc_ventas LOGIN;

-- quien entra a esta base
GRANT CONNECT, CREATE ON DATABASE andina_ventas TO rol_administrador;
GRANT CONNECT ON DATABASE andina_ventas TO rol_auditor, rol_vendedor, svc_ventas;

-- cada usuario solo el fragmento de su sede
GRANT USAGE ON SCHEMA ventas TO rol_administrador, rol_auditor, rol_vendedor, svc_ventas;
GRANT ALL    ON ALL TABLES IN SCHEMA ventas TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA ventas TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ventas TO svc_ventas;

GRANT SELECT, INSERT, UPDATE ON ventas.ped_bogota, ventas.det_ped_bogota TO vendedor_bogota;  -- sede 1
GRANT SELECT, INSERT, UPDATE ON ventas.ped_cali,   ventas.det_ped_cali   TO vendedor_cali;    -- sede 3

-- pagos y devoluciones: el vendedor NO tiene permiso sobre las tablas (son de
-- las 4 sedes), solo sobre las vistas locales de su sede (02_tablas/ventas.sql).
-- leer ventas.pagos le da error (prueba 9.9)
GRANT SELECT, INSERT, UPDATE, DELETE ON ventas.pagos_bogota, ventas.devoluciones_bogota, ventas.detalle_devolucion_bogota TO vendedor_bogota;
GRANT SELECT, INSERT, UPDATE, DELETE ON ventas.pagos_cali,   ventas.devoluciones_cali,   ventas.detalle_devolucion_cali   TO vendedor_cali;

-- REVOKE a proposito: no se borra, se cambia el estado (RN-43, prueba 9.6)
REVOKE DELETE ON ventas.pagos_bogota, ventas.devoluciones_bogota, ventas.detalle_devolucion_bogota FROM vendedor_bogota;
REVOKE DELETE ON ventas.pagos_cali,   ventas.devoluciones_cali,   ventas.detalle_devolucion_cali   FROM vendedor_cali;

-- sin superusuario (neon): quien corre los scripts necesita ser miembro
-- de los usuarios para poder probarlos con SET ROLE en 08_pruebas
\if :no_superusuario
GRANT admin_andina, auditor_interno, vendedor_bogota, vendedor_cali TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;
\endif
