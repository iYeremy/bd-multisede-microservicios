-- =====================================================================
-- 01_esquemas.sql
-- un esquema = un microservicio (seccion 9.2 del enunciado).
--
-- un esquema es como una carpeta dentro de la base. todo esta en un
-- solo postgresql, asi que esto es una simulacion: en microservicios de
-- verdad cada servicio tendria su propia base. para respetar esa idea:
--   - las FK solo van dentro de un mismo esquema (S-09).
--   - cada servicio solo modifica sus propias tablas (RN-39).
-- =====================================================================

CREATE SCHEMA catalogo;     -- datos maestros: sedes, almacenes, productos, proveedores, clientes
CREATE SCHEMA identidad;    -- empleados, usuarios y auditoria de accesos
CREATE SCHEMA compras;      -- ordenes de compra y recepciones
CREATE SCHEMA inventarios;  -- existencias (fragmentadas por sede) y transferencias
CREATE SCHEMA ventas;       -- pedidos (fragmentados por sede), pagos y devoluciones
CREATE SCHEMA reportes;     -- solo vistas de lectura que integran a los demas

-- COMMENT ON le pone una descripcion al esquema dentro de la base.
-- se ve con \dn+ en psql o en pgAdmin.
COMMENT ON SCHEMA catalogo    IS 'Microservicio de Catalogo y Terceros (datos maestros)';
COMMENT ON SCHEMA identidad   IS 'Microservicio de Identidad y Accesos';
COMMENT ON SCHEMA compras     IS 'Microservicio de Compras y Abastecimiento';
COMMENT ON SCHEMA inventarios IS 'Microservicio de Inventarios y Transferencias (inventarios fragmentado por sede)';
COMMENT ON SCHEMA ventas      IS 'Microservicio de Ventas y Pagos (pedidos y detalles fragmentados por sede)';
COMMENT ON SCHEMA reportes    IS 'Microservicio de Reportes Corporativos: solo vistas de integracion de solo lectura';
