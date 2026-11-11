-- =====================================================================
-- 01_bases.sql
-- una base de datos por microservicio.
--
-- cada servicio tiene su propia base y nadie mas entra en ella. en
-- postgresql una consulta NO puede leer tablas de otra base, asi que un
-- servicio de verdad no puede meterle la mano a los datos de otro: si
-- ventas necesita algo de catalogo, se lo tiene que pedir al servicio
-- de catalogo (en el backend, por HTTP).
--
-- las 6 bases pueden estar en el mismo servidor o en servidores
-- distintos; para los scripts da igual, solo cambia a donde se conecta
-- cada \c.
--
-- dentro de cada base hay un esquema con el nombre del servicio (por
-- ejemplo andina_ventas tiene el esquema ventas). asi las tablas se
-- llaman igual en su base y en las consultas por dblink de reportes.
-- =====================================================================

CREATE DATABASE andina_catalogo;     -- datos maestros: sedes, almacenes, productos, proveedores, clientes
CREATE DATABASE andina_identidad;    -- empleados, usuarios y auditoria de accesos
CREATE DATABASE andina_compras;      -- ordenes de compra y recepciones
CREATE DATABASE andina_inventarios;  -- existencias (fragmentadas por sede) y transferencias
CREATE DATABASE andina_ventas;       -- pedidos (fragmentados por sede), pagos y devoluciones
CREATE DATABASE andina_reportes;     -- vistas de reportes, que traen los datos por dblink

-- COMMENT ON le pone una descripcion a la base. se ve con \l+ en psql.
COMMENT ON DATABASE andina_catalogo    IS 'Microservicio de Catalogo y Terceros (datos maestros)';
COMMENT ON DATABASE andina_identidad   IS 'Microservicio de Identidad y Accesos';
COMMENT ON DATABASE andina_compras     IS 'Microservicio de Compras y Abastecimiento';
COMMENT ON DATABASE andina_inventarios IS 'Microservicio de Inventarios y Transferencias (inventarios fragmentado por sede)';
COMMENT ON DATABASE andina_ventas      IS 'Microservicio de Ventas y Pagos (pedidos y detalles fragmentados por sede)';
COMMENT ON DATABASE andina_reportes    IS 'Microservicio de Reportes Corporativos: vistas materializadas que traen los datos por dblink';

-- por defecto cualquier rol se puede conectar a cualquier base (PUBLIC
-- tiene CONNECT). se le quita, asi a cada base solo entra quien
-- 09_roles.sql deje entrar.
REVOKE ALL ON DATABASE andina_catalogo, andina_identidad, andina_compras,
                       andina_inventarios, andina_ventas, andina_reportes FROM PUBLIC;
