-- 01_bases/reset.sql
-- borra las 6 bases y los roles para empezar de cero.
-- se corre conectado a la base postgres

DROP DATABASE IF EXISTS andina_reportes;
DROP DATABASE IF EXISTS andina_ventas;
DROP DATABASE IF EXISTS andina_inventarios;
DROP DATABASE IF EXISTS andina_compras;
DROP DATABASE IF EXISTS andina_identidad;
DROP DATABASE IF EXISTS andina_catalogo;

-- base de la version vieja (todo en una sola base); ya no se usa
DROP DATABASE IF EXISTS comercializadora;

-- primero los usuarios (LOGIN), despues los grupos (NOLOGIN)
DROP ROLE IF EXISTS admin_andina, gerente_general, inventario_bogota, inventario_cedi,
                    compras_cedi, vendedor_bogota, vendedor_cali, auditor_interno;
DROP ROLE IF EXISTS svc_catalogo, svc_identidad, svc_compras,
                    svc_inventarios, svc_ventas, svc_reportes;
DROP ROLE IF EXISTS rol_administrador, rol_gerencia, rol_inventario,
                    rol_compras, rol_vendedor, rol_auditor;
