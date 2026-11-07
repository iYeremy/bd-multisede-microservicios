-- =====================================================================
-- 00_reset.sql
-- borra los esquemas y los roles del proyecto para empezar desde cero.
-- se corre con psql, conectado a la base del proyecto (comercializadora)
-- con un superusuario (postgres), porque hay que borrar roles.
-- =====================================================================

-- DROP SCHEMA ... CASCADE borra el esquema con todo lo que tiene dentro
-- (tablas, vistas, permisos). IF EXISTS evita el error en la primera
-- ejecucion, cuando todavia no existen.
-- se borra primero reportes porque sus vistas leen de los demas esquemas.
DROP SCHEMA IF EXISTS reportes    CASCADE;
DROP SCHEMA IF EXISTS ventas      CASCADE;
DROP SCHEMA IF EXISTS inventarios CASCADE;
DROP SCHEMA IF EXISTS compras     CASCADE;
DROP SCHEMA IF EXISTS identidad   CASCADE;
DROP SCHEMA IF EXISTS catalogo    CASCADE;

-- un rol no se puede borrar mientras tenga algun permiso. al borrar los
-- esquemas desaparecen los permisos sobre sus tablas, pero queda uno:
-- CREATE sobre la base, que 09_roles.sql le da a rol_administrador.
-- ese hay que quitarlo antes del DROP ROLE.
--
-- comandos de psql usados:
--   \gset   guarda cada columna del resultado en una variable de psql
--           con el mismo nombre (aqui :existe_rol_admin = t o f).
--   \if     ejecuta el bloque solo si la variable es verdadera; en la
--           primera ejecucion el rol no existe y el REVOKE fallaria.
--   :"DBNAME"  variable automatica de psql con el nombre de la base
--              actual, entre comillas dobles como identificador.
SELECT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_administrador') AS existe_rol_admin \gset
\if :existe_rol_admin
    REVOKE ALL ON DATABASE :"DBNAME" FROM rol_administrador;
\endif

-- primero los usuarios (LOGIN) y despues los roles de grupo (NOLOGIN)
-- de los que heredan sus permisos.
DROP ROLE IF EXISTS admin_andina, gerente_general, inventario_bogota, inventario_cedi,
                    compras_cedi, vendedor_bogota, vendedor_cali, auditor_interno;
DROP ROLE IF EXISTS rol_administrador, rol_gerencia, rol_inventario,
                    rol_compras, rol_vendedor, rol_auditor;
