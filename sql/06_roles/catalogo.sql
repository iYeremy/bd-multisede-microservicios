-- 06_roles/catalogo.sql
-- roles y permisos de la instancia de catalogo (base andina_catalogo).
-- cada instancia crea solo los roles que usa. ver README.md.

-- grupos
CREATE ROLE rol_administrador NOLOGIN;
CREATE ROLE rol_auditor       NOLOGIN;
CREATE ROLE rol_inventario    NOLOGIN;
CREATE ROLE rol_compras       NOLOGIN;
CREATE ROLE rol_vendedor      NOLOGIN;

-- usuarios (contrasena de ejemplo: Andina2026*)
CREATE ROLE admin_andina      LOGIN PASSWORD 'Andina2026*' CREATEROLE IN ROLE rol_administrador;
CREATE ROLE auditor_interno   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_auditor;
CREATE ROLE inventario_bogota LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE inventario_cedi   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_inventario;
CREATE ROLE compras_cedi      LOGIN PASSWORD 'Andina2026*' IN ROLE rol_compras;
CREATE ROLE vendedor_bogota   LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;
CREATE ROLE vendedor_cali     LOGIN PASSWORD 'Andina2026*' IN ROLE rol_vendedor;

-- usuario tecnico del servicio, sin contrasena: se pone al desplegar
CREATE ROLE svc_catalogo LOGIN;

-- quien entra a esta base
GRANT CONNECT, CREATE ON DATABASE andina_catalogo TO rol_administrador;
GRANT CONNECT ON DATABASE andina_catalogo TO rol_auditor, rol_inventario, rol_compras, rol_vendedor, svc_catalogo;

-- los demas servicios solo leen
GRANT USAGE ON SCHEMA catalogo TO rol_administrador, rol_auditor, rol_inventario,
                                  rol_compras, rol_vendedor, svc_catalogo;
GRANT ALL    ON ALL TABLES IN SCHEMA catalogo TO rol_administrador WITH GRANT OPTION;
GRANT SELECT ON ALL TABLES IN SCHEMA catalogo TO rol_auditor;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA catalogo TO svc_catalogo;

GRANT SELECT ON catalogo.sedes, catalogo.almacenes, catalogo.productos, catalogo.categorias TO rol_inventario;
GRANT SELECT ON catalogo.productos, catalogo.proveedores, catalogo.producto_proveedor,
                catalogo.almacenes, catalogo.sedes TO rol_compras;
GRANT SELECT ON catalogo.productos, catalogo.clientes TO rol_vendedor;

-- sin superusuario (neon): quien corre los scripts necesita ser miembro
-- de los usuarios para poder probarlos con SET ROLE en 08_pruebas
\if :no_superusuario
GRANT admin_andina, auditor_interno, inventario_bogota, inventario_cedi, compras_cedi, vendedor_bogota, vendedor_cali TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;
\endif
