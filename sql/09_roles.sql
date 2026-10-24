-- =====================================================================
-- 09_roles.sql
-- Roles de grupo (NOLOGIN) con los privilegios de cada función, y
-- usuarios (LOGIN) que heredan de ellos.
--
-- Matriz resumida (S = SELECT, I = INSERT, U = UPDATE, D = DELETE):
--
--  Rol               | catalogo | identidad | compras | inventarios              | ventas                         | reportes
--  ------------------+----------+-----------+---------+--------------------------+--------------------------------+---------
--  rol_administrador | SIUD     | SIUD      | SIUD    | SIUD                     | SIUD                           | S
--  rol_gerencia      | -        | -         | -       | -                        | -                              | S
--  rol_inventario    | S        | -         | -       | SIU transferencias;      | -                              | S (3 vistas)
--                    |          |           |         | SIU solo fragmento sede  |                                |
--  rol_compras       | S        | -         | SIU     | -                        | -                              | S (1 vista)
--  rol_vendedor      | S (2)    | -         | -       | -                        | SIU solo fragmento sede;       | -
--                    |          |           |         |                          | SIU pagos, devoluciones        |
--  rol_auditor       | S        | S (*)     | S       | S                        | S                              | S
--
--  (*) el auditor no ve la columna password_hash de identidad.usuarios.
--  Nadie salvo el administrador tiene DELETE: no hay borrado físico (RN-43).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Roles de grupo
-- ---------------------------------------------------------------------
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_gerencia      NOLOGIN;
CREATE ROLE rol_inventario    NOLOGIN;
CREATE ROLE rol_compras       NOLOGIN;
CREATE ROLE rol_vendedor      NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;

-- ---------------------------------------------------------------------
-- 2. Usuarios (contraseña de ejemplo: Andina2026*)
-- ---------------------------------------------------------------------
CREATE ROLE admin_andina      LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE gerente_general   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_gerencia;
CREATE ROLE inventario_bogota LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE inventario_cedi   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE compras_cedi      LOGIN PASSWORD 'Andina2026*' IN ROLE rol_compras;
CREATE ROLE vendedor_bogota   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;
CREATE ROLE vendedor_cali     LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;
CREATE ROLE auditor_interno   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;

-- ---------------------------------------------------------------------
-- 3. Punto de partida: nadie tiene nada por defecto
-- ---------------------------------------------------------------------
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes FROM PUBLIC;

DO $$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO rol_administrador, rol_gerencia, rol_inventario, '
                   'rol_compras, rol_vendedor, rol_auditor', current_database());
    EXECUTE format('GRANT CREATE ON DATABASE %I TO rol_administrador', current_database());
END $$;

-- ---------------------------------------------------------------------
-- 4. Administrador: todo sobre todos los esquemas
-- ---------------------------------------------------------------------
GRANT USAGE, CREATE ON SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes TO rol_administrador;
GRANT ALL ON ALL TABLES    IN SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes TO rol_administrador WITH GRANT OPTION;
GRANT ALL ON ALL SEQUENCES IN SCHEMA catalogo, identidad, compras, inventarios, ventas TO rol_administrador WITH GRANT OPTION;

-- ---------------------------------------------------------------------
-- 5. Gerencia: solo reportes (las vistas acceden a las tablas con los
--    privilegios de su dueño, por eso no necesita permisos en las tablas)
-- ---------------------------------------------------------------------
GRANT USAGE  ON SCHEMA reportes TO rol_gerencia;
GRANT SELECT ON ALL TABLES IN SCHEMA reportes TO rol_gerencia;

-- ---------------------------------------------------------------------
-- 6. Auditor: lectura de todo, sin modificar nada
-- ---------------------------------------------------------------------
GRANT USAGE  ON SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes TO rol_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA catalogo, compras, inventarios, ventas, reportes TO rol_auditor;
GRANT SELECT ON identidad.empleados, identidad.auditoria_accesos TO rol_auditor;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion) ON identidad.usuarios TO rol_auditor;

-- ---------------------------------------------------------------------
-- 7. Responsable de inventario
--    Grupo: transferencias y lectura de catálogo.
--    Usuario: solo el fragmento de inventario de su sede autorizada.
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA catalogo, inventarios, reportes TO rol_inventario;
GRANT SELECT ON catalogo.sedes, catalogo.almacenes, catalogo.productos, catalogo.categorias TO rol_inventario;
GRANT SELECT, INSERT, UPDATE ON inventarios.transferencias, inventarios.detalle_transferencia TO rol_inventario;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA inventarios TO rol_inventario;
GRANT SELECT ON reportes.vista_alertas_reabastecimiento,
                reportes.vista_transferencias_en_transito,
                reportes.vista_productos_sin_inventario TO rol_inventario;

GRANT SELECT, INSERT, UPDATE ON inventarios.inv_bogota TO inventario_bogota;   -- sede 1
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_cedi   TO inventario_cedi;     -- sede 4

-- ---------------------------------------------------------------------
-- 8. Responsable de compras: gestiona órdenes y recepciones
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA catalogo, compras, reportes TO rol_compras;
GRANT SELECT ON catalogo.productos, catalogo.proveedores, catalogo.producto_proveedor,
                catalogo.almacenes, catalogo.sedes TO rol_compras;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA compras TO rol_compras;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA compras TO rol_compras;
GRANT SELECT ON reportes.vista_compras_pendientes TO rol_compras;

-- ---------------------------------------------------------------------
-- 9. Vendedor
--    Grupo: pagos y devoluciones, lectura de productos y clientes.
--    Usuario: pedidos y detalles solo en el fragmento de su sede.
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA catalogo, ventas TO rol_vendedor;
GRANT SELECT ON catalogo.productos, catalogo.clientes TO rol_vendedor;
GRANT SELECT, INSERT, UPDATE, DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion TO rol_vendedor;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ventas TO rol_vendedor;

-- Se revoca el DELETE concedido arriba: los pagos y devoluciones no se
-- borran, se cambia su estado (RN-43). Demostración de REVOKE.
REVOKE DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion FROM rol_vendedor;

GRANT SELECT, INSERT, UPDATE ON ventas.ped_bogota, ventas.det_ped_bogota TO vendedor_bogota;  -- sede 1
GRANT SELECT, INSERT, UPDATE ON ventas.ped_cali,   ventas.det_ped_cali   TO vendedor_cali;    -- sede 3
REVOKE USAGE ON SEQUENCE ventas.seq_ped_medellin, ventas.seq_ped_cali, ventas.seq_ped_cedi FROM rol_vendedor;
REVOKE USAGE ON SEQUENCE ventas.seq_ped_bogota FROM rol_vendedor;
GRANT  USAGE ON SEQUENCE ventas.seq_ped_bogota TO vendedor_bogota;
GRANT  USAGE ON SEQUENCE ventas.seq_ped_cali   TO vendedor_cali;
