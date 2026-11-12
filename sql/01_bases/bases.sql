-- 01_bases/bases.sql
-- una base de datos por microservicio 

CREATE DATABASE andina_catalogo;     -- sedes, almacenes, productos, proveedores, clientes
CREATE DATABASE andina_identidad;    -- empleados, usuarios y auditoria
CREATE DATABASE andina_compras;      -- ordenes de compra y recepciones
CREATE DATABASE andina_inventarios;  -- existencias (por sede) y transferencias
CREATE DATABASE andina_ventas;       -- pedidos (por sede), pagos y devoluciones
CREATE DATABASE andina_reportes;     -- vistas que traen los datos de las demas con dblink

COMMENT ON DATABASE andina_catalogo    IS 'Microservicio de Catalogo y Terceros (datos maestros)';
COMMENT ON DATABASE andina_identidad   IS 'Microservicio de Identidad y Accesos';
COMMENT ON DATABASE andina_compras     IS 'Microservicio de Compras y Abastecimiento';
COMMENT ON DATABASE andina_inventarios IS 'Microservicio de Inventarios y Transferencias (inventarios fragmentado por sede)';
COMMENT ON DATABASE andina_ventas      IS 'Microservicio de Ventas y Pagos (pedidos y detalles fragmentados por sede)';
COMMENT ON DATABASE andina_reportes    IS 'Microservicio de Reportes Corporativos: vistas materializadas que traen los datos por dblink';

-- nadie entra a ninguna base hasta que 06_roles/roles.sql lo deje
REVOKE ALL ON DATABASE andina_catalogo, andina_identidad, andina_compras,
                       andina_inventarios, andina_ventas, andina_reportes FROM PUBLIC;
