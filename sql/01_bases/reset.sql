-- 01_bases/reset.sql
-- borra la base del servicio (:db) y los roles del proyecto en la
-- instancia actual. se corre conectado a la base de administracion
-- (postgres en local, neondb en neon). ver README.md.

DROP DATABASE IF EXISTS :"db";

-- cada instancia tiene sus propios roles. IF EXISTS: no todas tienen todos
DROP ROLE IF EXISTS admin_andina, gerente_general, inventario_bogota, inventario_cedi,
                    compras_cedi, vendedor_bogota, vendedor_cali, auditor_interno;
DROP ROLE IF EXISTS svc_catalogo, svc_identidad, svc_compras,
                    svc_inventarios, svc_ventas, svc_reportes;
DROP ROLE IF EXISTS rol_administrador, rol_gerencia, rol_inventario,
                    rol_compras, rol_vendedor, rol_auditor;
