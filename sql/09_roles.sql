-- =====================================================================
-- 09_roles.sql
-- roles, usuarios y permisos (seccion 8 del enunciado).
--
-- en postgresql los usuarios y los grupos son "roles". aqui hay dos tipos:
--   grupos (NOLOGIN)   no se conectan, solo juntan los permisos de un
--                      cargo (vendedor, compras...).
--   usuarios (LOGIN)   se conectan y reciben los permisos de su grupo.
-- asi un permiso se da una vez al grupo y le sirve a todos. lo que
-- depende de la sede (la tabla de su sede) se le da al usuario.
--
-- en resumen: cada servicio solo modifica lo suyo (RN-39), vendedor e
-- inventario solo tocan su sede (RN-40) y gerencia y auditor solo
-- leen (RN-41).
--
-- matriz resumida (S = SELECT, I = INSERT, U = UPDATE, D = DELETE):
--
--  rol               | catalogo | identidad | compras | inventarios              | ventas                         | reportes
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
--  nadie salvo el administrador tiene DELETE: no hay borrado fisico,
--  se cambia el estado (RN-43).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. roles de grupo
-- ---------------------------------------------------------------------
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_gerencia      NOLOGIN;
CREATE ROLE rol_inventario    NOLOGIN;
CREATE ROLE rol_compras       NOLOGIN;
CREATE ROLE rol_vendedor      NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;

-- ---------------------------------------------------------------------
-- 2. usuarios (contrasena de ejemplo: Andina2026*)
-- IN ROLE x los hace miembros del grupo x. CREATEROLE le permite al
-- administrador crear y administrar otros roles.
-- solo se crean los usuarios necesarios para demostrar los permisos;
-- los de identidad.usuarios son datos del negocio, no roles de la base.
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
-- 3. punto de partida: nadie tiene nada por defecto
-- PUBLIC es el grupo implicito al que pertenecen todos los roles. se le
-- quita todo para que cada permiso sea solo el que se concede abajo.
-- ---------------------------------------------------------------------
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes FROM PUBLIC;

-- CONNECT sobre la base ya lo tiene PUBLIC por defecto, asi todos los
-- usuarios pueden conectarse. el administrador ademas puede crear
-- esquemas. :"DBNAME" es la variable de psql con el nombre de la base
-- actual (comercializadora); en pgAdmin hay que escribir el nombre.
GRANT CREATE ON DATABASE :"DBNAME" TO rol_administrador;

-- ---------------------------------------------------------------------
-- 4. administrador: todo sobre todos los esquemas
-- USAGE permite "entrar" al esquema (ver sus objetos); sin USAGE no
-- sirve tener permisos sobre las tablas. ALL TABLES incluye las vistas.
-- WITH GRANT OPTION le deja conceder esos permisos a otros.
-- ---------------------------------------------------------------------
GRANT USAGE, CREATE ON SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes TO rol_administrador;
GRANT ALL ON ALL TABLES    IN SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes TO rol_administrador WITH GRANT OPTION;

-- ---------------------------------------------------------------------
-- 5. gerencia: solo reportes.
--    una vista lee las tablas con los permisos de su dueno (quien la
--    creo), no con los de quien la consulta. por eso gerencia puede ver
--    los reportes sin tener ningun permiso sobre las tablas de origen.
-- ---------------------------------------------------------------------
GRANT USAGE  ON SCHEMA reportes TO rol_gerencia;
GRANT SELECT ON ALL TABLES IN SCHEMA reportes TO rol_gerencia;

-- ---------------------------------------------------------------------
-- 6. auditor: lectura de todo, sin modificar nada.
--    identidad se concede tabla por tabla para excluir password_hash:
--    en usuarios el SELECT es por columnas, sin esa columna.
-- ---------------------------------------------------------------------
GRANT USAGE  ON SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes TO rol_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA catalogo, compras, inventarios, ventas, reportes TO rol_auditor;
GRANT SELECT ON identidad.empleados, identidad.auditoria_accesos TO rol_auditor;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion) ON identidad.usuarios TO rol_auditor;

-- ---------------------------------------------------------------------
-- 7. responsable de inventario
--    grupo: transferencias, lectura del catalogo y 3 vistas.
--    usuario: solo el fragmento de inventario de su sede autorizada.
--    asi inventario_cedi puede actualizar inv_cedi pero no inv_bogota
--    (prueba 9.7).
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA catalogo, inventarios, reportes TO rol_inventario;
GRANT SELECT ON catalogo.sedes, catalogo.almacenes, catalogo.productos, catalogo.categorias TO rol_inventario;
GRANT SELECT, INSERT, UPDATE ON inventarios.transferencias, inventarios.detalle_transferencia TO rol_inventario;
GRANT SELECT ON reportes.vista_alertas_reabastecimiento,
                reportes.vista_transferencias_en_transito,
                reportes.vista_productos_sin_inventario TO rol_inventario;

GRANT SELECT, INSERT, UPDATE ON inventarios.inv_bogota TO inventario_bogota;   -- sede 1
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_cedi   TO inventario_cedi;     -- sede 4

-- ---------------------------------------------------------------------
-- 8. responsable de compras: gestiona ordenes y recepciones de todo el
--    esquema compras; del catalogo solo lee.
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA catalogo, compras, reportes TO rol_compras;
GRANT SELECT ON catalogo.productos, catalogo.proveedores, catalogo.producto_proveedor,
                catalogo.almacenes, catalogo.sedes TO rol_compras;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA compras TO rol_compras;
GRANT SELECT ON reportes.vista_compras_pendientes TO rol_compras;

-- ---------------------------------------------------------------------
-- 9. vendedor
--    grupo: pagos y devoluciones, lectura de productos y clientes
--    (clientes es de catalogo, por eso el vendedor no puede crearlos).
--    usuario: pedidos y detalles solo en el fragmento de su sede, asi
--    vendedor_bogota no puede ni leer ped_cali (prueba 9.4).
-- ---------------------------------------------------------------------
GRANT USAGE ON SCHEMA catalogo, ventas TO rol_vendedor;
GRANT SELECT ON catalogo.productos, catalogo.clientes TO rol_vendedor;
GRANT SELECT, INSERT, UPDATE, DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion TO rol_vendedor;

-- se revoca el DELETE concedido arriba: los pagos y devoluciones no se
-- borran, se cambia su estado (RN-43). se hace en dos pasos a proposito,
-- para demostrar REVOKE (lo pide la seccion 8); la prueba 9.6 comprueba
-- que el DELETE queda denegado.
REVOKE DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion FROM rol_vendedor;

GRANT SELECT, INSERT, UPDATE ON ventas.ped_bogota, ventas.det_ped_bogota TO vendedor_bogota;  -- sede 1
GRANT SELECT, INSERT, UPDATE ON ventas.ped_cali,   ventas.det_ped_cali   TO vendedor_cali;    -- sede 3
