-- 06_roles/roles.sql
-- roles, usuarios y permisos (seccion 8 del enunciado). la matriz de
-- permisos y la explicacion estan en README.md.

-- 1. grupos: juntan los permisos de un cargo
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_gerencia      NOLOGIN;
CREATE ROLE rol_inventario    NOLOGIN;
CREATE ROLE rol_compras       NOLOGIN;
CREATE ROLE rol_vendedor      NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;

-- 2. usuarios (contrasena de ejemplo: Andina2026*). IN ROLE = miembro del grupo
CREATE ROLE admin_andina      LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE gerente_general   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_gerencia;
CREATE ROLE inventario_bogota LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE inventario_cedi   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE compras_cedi      LOGIN PASSWORD 'Andina2026*' IN ROLE rol_compras;
CREATE ROLE vendedor_bogota   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;
CREATE ROLE vendedor_cali     LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;
CREATE ROLE auditor_interno   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;

-- 3. usuarios tecnicos, uno por servicio. sin contrasena: se pone al desplegar
CREATE ROLE svc_catalogo    LOGIN;
CREATE ROLE svc_identidad   LOGIN;
CREATE ROLE svc_compras     LOGIN;
CREATE ROLE svc_inventarios LOGIN;
CREATE ROLE svc_ventas      LOGIN;
CREATE ROLE svc_reportes    LOGIN;

-- 4. a que base entra cada uno
GRANT CONNECT, CREATE ON DATABASE andina_catalogo, andina_identidad, andina_compras,
                                  andina_inventarios, andina_ventas, andina_reportes TO rol_administrador;
GRANT CONNECT ON DATABASE andina_catalogo, andina_identidad, andina_compras,
                          andina_inventarios, andina_ventas, andina_reportes TO rol_auditor;
GRANT CONNECT ON DATABASE andina_reportes                                     TO rol_gerencia;
GRANT CONNECT ON DATABASE andina_catalogo, andina_inventarios, andina_reportes TO rol_inventario;
GRANT CONNECT ON DATABASE andina_catalogo, andina_compras, andina_reportes     TO rol_compras;
GRANT CONNECT ON DATABASE andina_catalogo, andina_ventas                       TO rol_vendedor;

-- cada servicio, solo a su base
GRANT CONNECT ON DATABASE andina_catalogo    TO svc_catalogo;
GRANT CONNECT ON DATABASE andina_identidad   TO svc_identidad;
GRANT CONNECT ON DATABASE andina_compras     TO svc_compras;
GRANT CONNECT ON DATABASE andina_inventarios TO svc_inventarios;
GRANT CONNECT ON DATABASE andina_ventas      TO svc_ventas;
GRANT CONNECT ON DATABASE andina_reportes    TO svc_reportes;

-- de aqui en adelante, permisos dentro de cada base (un \c por base)

-- 5. andina_catalogo: los demas solo leen
\c andina_catalogo
GRANT USAGE ON SCHEMA catalogo TO rol_administrador, rol_auditor, rol_inventario,
                                  rol_compras, rol_vendedor, svc_catalogo;
GRANT ALL    ON ALL TABLES IN SCHEMA catalogo TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA catalogo TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA catalogo TO svc_catalogo;

GRANT SELECT ON catalogo.sedes, catalogo.almacenes, catalogo.productos, catalogo.categorias TO rol_inventario;
GRANT SELECT ON catalogo.productos, catalogo.proveedores, catalogo.producto_proveedor,
                catalogo.almacenes, catalogo.sedes TO rol_compras;
GRANT SELECT ON catalogo.productos, catalogo.clientes TO rol_vendedor;

-- 6. andina_identidad: el auditor no ve password_hash (SELECT por columnas)
\c andina_identidad
GRANT USAGE ON SCHEMA identidad TO rol_administrador, rol_auditor, svc_identidad;
GRANT ALL ON ALL TABLES IN SCHEMA identidad TO rol_administrador WITH GRANT OPTION;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA identidad TO svc_identidad;

GRANT SELECT ON identidad.empleados, identidad.auditoria_accesos TO rol_auditor;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion) ON identidad.usuarios TO rol_auditor;

-- 7. andina_compras
\c andina_compras
GRANT USAGE ON SCHEMA compras TO rol_administrador, rol_auditor, rol_compras, svc_compras;
GRANT ALL    ON ALL TABLES IN SCHEMA compras TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA compras TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA compras TO rol_compras, svc_compras;

-- 8. andina_inventarios: cada usuario solo el fragmento de su sede
\c andina_inventarios
GRANT USAGE ON SCHEMA inventarios TO rol_administrador, rol_auditor, rol_inventario, svc_inventarios;
GRANT ALL    ON ALL TABLES IN SCHEMA inventarios TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA inventarios TO rol_auditor;
-- el servicio maneja los 4 fragmentos; el backend decide en cual escribe
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA inventarios TO svc_inventarios;

GRANT SELECT, INSERT, UPDATE ON inventarios.transferencias, inventarios.detalle_transferencia TO rol_inventario;
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_bogota TO inventario_bogota;   -- sede 1
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_cedi   TO inventario_cedi;     -- sede 4

-- 9. andina_ventas: cada usuario solo el fragmento de su sede
\c andina_ventas
GRANT USAGE ON SCHEMA ventas TO rol_administrador, rol_auditor, rol_vendedor, svc_ventas;
GRANT ALL    ON ALL TABLES IN SCHEMA ventas TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA ventas TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ventas TO svc_ventas;

GRANT SELECT, INSERT, UPDATE, DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion TO rol_vendedor;

-- REVOKE a proposito: no se borra, se cambia el estado (RN-43, prueba 9.6)
REVOKE DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion FROM rol_vendedor;

GRANT SELECT, INSERT, UPDATE ON ventas.ped_bogota, ventas.det_ped_bogota TO vendedor_bogota;  -- sede 1
GRANT SELECT, INSERT, UPDATE ON ventas.ped_cali,   ventas.det_ped_cali   TO vendedor_cali;    -- sede 3

-- 10. andina_reportes: solo vistas. dblink solo para postgres
\c andina_reportes
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

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
