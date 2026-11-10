-- =====================================================================
-- 00_reset.sql
-- borra las 6 bases y los roles del proyecto para empezar desde cero.
-- se corre conectado a la base "postgres" (la que trae postgresql por
-- defecto) con un superusuario, porque una base no se puede borrar
-- mientras uno esta conectado a ella.
--
-- si da error "esta siendo usada por otros usuarios", cierra pgAdmin u
-- otra ventana de psql que este conectada a esa base.
-- =====================================================================

-- DROP DATABASE borra la base con todo lo que tiene dentro (tablas,
-- vistas, permisos). IF EXISTS evita el error la primera vez, cuando
-- todavia no existen.
DROP DATABASE IF EXISTS andina_reportes;
DROP DATABASE IF EXISTS andina_ventas;
DROP DATABASE IF EXISTS andina_inventarios;
DROP DATABASE IF EXISTS andina_compras;
DROP DATABASE IF EXISTS andina_identidad;
DROP DATABASE IF EXISTS andina_catalogo;

-- base de la version anterior del proyecto (todo en una sola base con
-- 6 esquemas). ya no se usa, y si sigue ahi sus permisos no dejarian
-- borrar los roles de abajo.
DROP DATABASE IF EXISTS comercializadora;

-- un rol no se puede borrar mientras tenga permisos en alguna base. como
-- las bases ya se borraron, sus permisos se fueron con ellas.
-- primero los usuarios (LOGIN) y despues los grupos (NOLOGIN).
DROP ROLE IF EXISTS admin_andina, gerente_general, inventario_bogota, inventario_cedi,
                    compras_cedi, vendedor_bogota, vendedor_cali, auditor_interno;
DROP ROLE IF EXISTS svc_catalogo, svc_identidad, svc_compras,
                    svc_inventarios, svc_ventas, svc_reportes;
DROP ROLE IF EXISTS rol_administrador, rol_gerencia, rol_inventario,
                    rol_compras, rol_vendedor, rol_auditor;
