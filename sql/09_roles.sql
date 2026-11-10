-- =====================================================================
-- 09_roles.sql
-- roles, usuarios y permisos (seccion 8 del enunciado).
--
-- en postgresql los usuarios y los grupos son "roles". aqui hay tres
-- tipos:
--   grupos (NOLOGIN)        no se conectan, solo juntan los permisos de
--                           un cargo (vendedor, compras...).
--   usuarios (LOGIN)        personas; reciben los permisos de su grupo.
--   usuarios tecnicos svc_  uno por microservicio: es el usuario con el
--                           que el backend de ese servicio se conecta a
--                           SU base, y solo a esa.
--
-- los roles son de todo el servidor, pero los permisos se dan base por
-- base. hay dos niveles:
--   1. CONNECT: a que bases puede entrar cada rol.
--   2. dentro de cada base: USAGE en el esquema y SELECT/INSERT/... en
--      las tablas. por eso abajo hay un \c para cada base: un GRANT sobre
--      tablas solo funciona conectado a la base donde estan.
--
-- en resumen: cada servicio solo modifica lo suyo (RN-39), vendedor e
-- inventario solo tocan su sede (RN-40) y gerencia y auditor solo
-- leen (RN-41). nadie salvo el administrador tiene DELETE: no hay
-- borrado fisico, se cambia el estado (RN-43).
--
-- a que base entra cada rol (CONNECT):
--
--  rol               | catalogo | identidad | compras | inventarios | ventas | reportes
--  ------------------+----------+-----------+---------+-------------+--------+---------
--  rol_administrador |    x     |     x     |    x    |      x      |   x    |    x
--  rol_gerencia      |          |           |         |             |        |    x
--  rol_inventario    |    x     |           |         |      x      |        |    x
--  rol_compras       |    x     |           |    x    |             |        |    x
--  rol_vendedor      |    x     |           |         |             |   x    |
--  rol_auditor       |    x     |     x     |    x    |      x      |   x    |    x
--  svc_<servicio>    |  solo la base de su servicio
--
-- y que puede hacer dentro (S = SELECT, I = INSERT, U = UPDATE, D = DELETE):
--
--  rol               | catalogo | identidad | compras | inventarios              | ventas                         | reportes
--  ------------------+----------+-----------+---------+--------------------------+--------------------------------+---------
--  rol_administrador | SIUD     | SIUD      | SIUD    | SIUD                     | SIUD                           | S
--  rol_gerencia      | -        | -         | -       | -                        | -                              | S (vistas)
--  rol_inventario    | S        | -         | -       | SIU transferencias;      | -                              | S (3 vistas)
--                    |          |           |         | SIU solo fragmento sede  |                                |
--  rol_compras       | S        | -         | SIU     | -                        | -                              | S (1 vista)
--  rol_vendedor      | S (2)    | -         | -       | -                        | SIU solo fragmento sede;       | -
--                    |          |           |         |                          | SIU pagos, devoluciones        |
--  rol_auditor       | S        | S (*)     | S       | S                        | S                              | S
--  svc_<servicio>    | SIU solo en las tablas de su servicio (svc_reportes: lee todo en su base)
--
--  (*) el auditor no ve la columna password_hash de identidad.usuarios.
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
-- 3. usuarios tecnicos, uno por microservicio
-- se crean SIN contrasena a proposito: la contrasena real no va en el
-- repositorio. al desplegar se le pone con
--     ALTER ROLE svc_ventas PASSWORD '...';
-- usando el valor que este en el .env del servidor.
-- ---------------------------------------------------------------------
CREATE ROLE svc_catalogo    LOGIN;
CREATE ROLE svc_identidad   LOGIN;
CREATE ROLE svc_compras     LOGIN;
CREATE ROLE svc_inventarios LOGIN;
CREATE ROLE svc_ventas      LOGIN;
CREATE ROLE svc_reportes    LOGIN;

-- ---------------------------------------------------------------------
-- 4. a que base entra cada uno (CONNECT)
-- 01_bases.sql ya le quito CONNECT a PUBLIC, asi que sin esto nadie
-- entra. el administrador ademas puede crear esquemas (CREATE).
-- ---------------------------------------------------------------------
GRANT CONNECT, CREATE ON DATABASE andina_catalogo, andina_identidad, andina_compras,
                                  andina_inventarios, andina_ventas, andina_reportes TO rol_administrador;
GRANT CONNECT ON DATABASE andina_catalogo, andina_identidad, andina_compras,
                          andina_inventarios, andina_ventas, andina_reportes TO rol_auditor;
GRANT CONNECT ON DATABASE andina_reportes                                     TO rol_gerencia;
GRANT CONNECT ON DATABASE andina_catalogo, andina_inventarios, andina_reportes TO rol_inventario;
GRANT CONNECT ON DATABASE andina_catalogo, andina_compras, andina_reportes     TO rol_compras;
GRANT CONNECT ON DATABASE andina_catalogo, andina_ventas                       TO rol_vendedor;

-- cada servicio entra solo a su base
GRANT CONNECT ON DATABASE andina_catalogo    TO svc_catalogo;
GRANT CONNECT ON DATABASE andina_identidad   TO svc_identidad;
GRANT CONNECT ON DATABASE andina_compras     TO svc_compras;
GRANT CONNECT ON DATABASE andina_inventarios TO svc_inventarios;
GRANT CONNECT ON DATABASE andina_ventas      TO svc_ventas;
GRANT CONNECT ON DATABASE andina_reportes    TO svc_reportes;

-- ---------------------------------------------------------------------
-- de aqui en adelante, los permisos dentro de cada base.
-- USAGE permite "entrar" al esquema; sin USAGE no sirve tener permisos
-- sobre las tablas. ALL TABLES incluye las vistas.
-- WITH GRANT OPTION le deja al administrador conceder esos permisos a
-- otros.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 5. base andina_catalogo
--    inventario, compras y vendedor solo leen. el vendedor solo ve
--    productos y clientes (por eso no puede crear clientes).
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 6. base andina_identidad
--    el auditor lee tabla por tabla para excluir password_hash: en
--    usuarios el SELECT es por columnas, sin esa columna.
-- ---------------------------------------------------------------------
\c andina_identidad
GRANT USAGE ON SCHEMA identidad TO rol_administrador, rol_auditor, svc_identidad;
GRANT ALL ON ALL TABLES IN SCHEMA identidad TO rol_administrador WITH GRANT OPTION;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA identidad TO svc_identidad;

GRANT SELECT ON identidad.empleados, identidad.auditoria_accesos TO rol_auditor;
GRANT SELECT (id_usuario, id_empleado, nombre_usuario, rol, estado, fecha_creacion) ON identidad.usuarios TO rol_auditor;

-- ---------------------------------------------------------------------
-- 7. base andina_compras
--    el responsable de compras gestiona ordenes y recepciones.
-- ---------------------------------------------------------------------
\c andina_compras
GRANT USAGE ON SCHEMA compras TO rol_administrador, rol_auditor, rol_compras, svc_compras;
GRANT ALL    ON ALL TABLES IN SCHEMA compras TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA compras TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA compras TO rol_compras, svc_compras;

-- ---------------------------------------------------------------------
-- 8. base andina_inventarios
--    grupo inventario: transferencias.
--    usuario: solo el fragmento de inventario de su sede autorizada,
--    asi inventario_cedi puede actualizar inv_cedi pero no inv_bogota
--    (prueba 9.7).
-- ---------------------------------------------------------------------
\c andina_inventarios
GRANT USAGE ON SCHEMA inventarios TO rol_administrador, rol_auditor, rol_inventario, svc_inventarios;
GRANT ALL    ON ALL TABLES IN SCHEMA inventarios TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA inventarios TO rol_auditor;
-- el servicio si maneja los 4 fragmentos: es el backend el que decide en
-- cual escribe segun la sede del usuario
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA inventarios TO svc_inventarios;

GRANT SELECT, INSERT, UPDATE ON inventarios.transferencias, inventarios.detalle_transferencia TO rol_inventario;
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_bogota TO inventario_bogota;   -- sede 1
GRANT SELECT, INSERT, UPDATE ON inventarios.inv_cedi   TO inventario_cedi;     -- sede 4

-- ---------------------------------------------------------------------
-- 9. base andina_ventas
--    grupo vendedor: pagos y devoluciones.
--    usuario: pedidos y detalles solo en el fragmento de su sede, asi
--    vendedor_bogota no puede ni leer ped_cali (prueba 9.4).
-- ---------------------------------------------------------------------
\c andina_ventas
GRANT USAGE ON SCHEMA ventas TO rol_administrador, rol_auditor, rol_vendedor, svc_ventas;
GRANT ALL    ON ALL TABLES IN SCHEMA ventas TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA ventas TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ventas TO svc_ventas;

GRANT SELECT, INSERT, UPDATE, DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion TO rol_vendedor;

-- se revoca el DELETE concedido arriba: los pagos y devoluciones no se
-- borran, se cambia su estado (RN-43). se hace en dos pasos a proposito,
-- para demostrar REVOKE (lo pide la seccion 8); la prueba 9.6 comprueba
-- que el DELETE queda denegado.
REVOKE DELETE ON ventas.pagos, ventas.devoluciones, ventas.detalle_devolucion FROM rol_vendedor;

GRANT SELECT, INSERT, UPDATE ON ventas.ped_bogota, ventas.det_ped_bogota TO vendedor_bogota;  -- sede 1
GRANT SELECT, INSERT, UPDATE ON ventas.ped_cali,   ventas.det_ped_cali   TO vendedor_cali;    -- sede 3

-- ---------------------------------------------------------------------
-- 10. base andina_reportes
--    aqui estan las copias (catalogo, identidad, compras, inventarios,
--    ventas) y las vistas (reportes).
--    gerencia, inventario y compras solo ven vistas, nunca las copias.
--    una vista lee las tablas con los permisos de su dueno (quien la
--    creo), no con los de quien la consulta. por eso gerencia puede ver
--    los reportes sin tener permiso sobre las tablas de origen.
--    svc_reportes lee todo y puede reemplazar las copias (INSERT y
--    DELETE), porque es el que las refresca cuando se sincroniza.
-- ---------------------------------------------------------------------
\c andina_reportes
GRANT USAGE ON SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes
      TO rol_administrador, rol_auditor, svc_reportes;
GRANT SELECT ON ALL TABLES IN SCHEMA catalogo, identidad, compras, inventarios, ventas, reportes
      TO rol_administrador, rol_auditor, svc_reportes;
GRANT INSERT, DELETE ON ALL TABLES IN SCHEMA catalogo, identidad, compras, inventarios, ventas
      TO svc_reportes;

GRANT USAGE  ON SCHEMA reportes TO rol_gerencia, rol_inventario, rol_compras;
GRANT SELECT ON ALL TABLES IN SCHEMA reportes TO rol_gerencia;
GRANT SELECT ON reportes.vista_alertas_reabastecimiento,
                reportes.vista_transferencias_en_transito,
                reportes.vista_productos_sin_inventario TO rol_inventario;
GRANT SELECT ON reportes.vista_compras_pendientes TO rol_compras;
