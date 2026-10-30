-- =====================================================================
-- 00_reset.sql
-- Borra los esquemas y los roles del proyecto para empezar desde cero.
-- Ejecutar con psql, conectado a la base del proyecto (comercializadora)
-- con un usuario superusuario (postgres).
-- =====================================================================

DROP SCHEMA IF EXISTS reportes    CASCADE;
DROP SCHEMA IF EXISTS ventas      CASCADE;
DROP SCHEMA IF EXISTS inventarios CASCADE;
DROP SCHEMA IF EXISTS compras     CASCADE;
DROP SCHEMA IF EXISTS identidad   CASCADE;
DROP SCHEMA IF EXISTS catalogo    CASCADE;

-- Al borrar los esquemas desaparecen los permisos sobre sus tablas. El
-- único permiso que queda es CREATE sobre la base, concedido a
-- rol_administrador en 09_roles.sql; hay que quitarlo antes del DROP ROLE.
-- \gset guarda el resultado en una variable de psql y \if solo ejecuta
-- el REVOKE si el rol ya existe (en la primera ejecución no existe).
SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_administrador') AS existe_rol_admin \gset
\if :existe_rol_admin
    REVOKE ALL ON DATABASE :"DBNAME" FROM rol_administrador;
\endif

-- Usuarios (LOGIN)
DROP ROLE IF EXISTS admin_andina, gerente_general, inventario_bogota, inventario_cedi,
                    compras_cedi, vendedor_bogota, vendedor_cali, auditor_interno;
-- Roles de grupo (NOLOGIN)
DROP ROLE IF EXISTS rol_administrador, rol_gerencia, rol_inventario,
                    rol_compras, rol_vendedor, rol_auditor;
