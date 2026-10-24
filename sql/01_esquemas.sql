-- =====================================================================
-- 01_esquemas.sql
-- Un esquema por microservicio. El esquema reportes solo tendrá vistas.
-- =====================================================================

CREATE SCHEMA catalogo;
CREATE SCHEMA identidad;
CREATE SCHEMA compras;
CREATE SCHEMA inventarios;
CREATE SCHEMA ventas;
CREATE SCHEMA reportes;

COMMENT ON SCHEMA catalogo    IS 'Microservicio de Catálogo y Terceros (datos maestros)';
COMMENT ON SCHEMA identidad   IS 'Microservicio de Identidad y Accesos';
COMMENT ON SCHEMA compras     IS 'Microservicio de Compras y Abastecimiento';
COMMENT ON SCHEMA inventarios IS 'Microservicio de Inventarios y Transferencias (inventarios fragmentado por sede)';
COMMENT ON SCHEMA ventas      IS 'Microservicio de Ventas y Pagos (pedidos y detalles fragmentados por sede)';
COMMENT ON SCHEMA reportes    IS 'Microservicio de Reportes Corporativos: solo vistas de integración de solo lectura';
