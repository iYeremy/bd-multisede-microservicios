-- =====================================================================
-- 06_ventas.sql
-- Microservicio de Ventas y Pagos.
--
-- FRAGMENTACIÓN HORIZONTAL: pedidos_venta se particiona por LIST (id_sede)
-- y detalle_pedido se particiona con la MISMA condición (fragmentación
-- derivada), así un pedido y sus detalles quedan en el mismo fragmento.
--     ped_bogota / det_ped_bogota     (id_sede = 1)
--     ped_medellin / det_ped_medellin (id_sede = 2)
--     ped_cali / det_ped_cali         (id_sede = 3)
--     ped_cedi / det_ped_cedi         (id_sede = 4)
--
-- id_pedido es un consecutivo DENTRO de cada sede: la PK es
-- (id_sede, id_pedido). Cada fragmento tiene su propia secuencia como
-- valor por defecto, que se usa cuando se inserta directamente en el
-- fragmento (así trabaja el vendedor de cada sede).
-- =====================================================================

CREATE TABLE ventas.pedidos_venta (
    id_sede          INTEGER       NOT NULL,            -- † catalogo.sedes (clave de fragmentación)
    id_pedido        INTEGER       NOT NULL,
    id_almacen       INTEGER       NOT NULL,            -- † catalogo.almacenes
    id_cliente       INTEGER       NOT NULL,            -- † catalogo.clientes
    id_empleado      INTEGER       NOT NULL,            -- † identidad.empleados
    fecha_pedido     DATE          NOT NULL,
    estado           VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'ANULADO')),
    total_registrado NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_registrado >= 0),
    PRIMARY KEY (id_sede, id_pedido)
) PARTITION BY LIST (id_sede);

CREATE TABLE ventas.ped_bogota   PARTITION OF ventas.pedidos_venta FOR VALUES IN (1);
CREATE TABLE ventas.ped_medellin PARTITION OF ventas.pedidos_venta FOR VALUES IN (2);
CREATE TABLE ventas.ped_cali     PARTITION OF ventas.pedidos_venta FOR VALUES IN (3);
CREATE TABLE ventas.ped_cedi     PARTITION OF ventas.pedidos_venta FOR VALUES IN (4);

-- Consecutivo por sede
CREATE SEQUENCE ventas.seq_ped_bogota;
CREATE SEQUENCE ventas.seq_ped_medellin;
CREATE SEQUENCE ventas.seq_ped_cali;
CREATE SEQUENCE ventas.seq_ped_cedi;

ALTER TABLE ventas.ped_bogota   ALTER COLUMN id_pedido SET DEFAULT nextval('ventas.seq_ped_bogota');
ALTER TABLE ventas.ped_medellin ALTER COLUMN id_pedido SET DEFAULT nextval('ventas.seq_ped_medellin');
ALTER TABLE ventas.ped_cali     ALTER COLUMN id_pedido SET DEFAULT nextval('ventas.seq_ped_cali');
ALTER TABLE ventas.ped_cedi     ALTER COLUMN id_pedido SET DEFAULT nextval('ventas.seq_ped_cedi');

ALTER TABLE ventas.ped_bogota   ALTER COLUMN id_sede SET DEFAULT 1;
ALTER TABLE ventas.ped_medellin ALTER COLUMN id_sede SET DEFAULT 2;
ALTER TABLE ventas.ped_cali     ALTER COLUMN id_sede SET DEFAULT 3;
ALTER TABLE ventas.ped_cedi     ALTER COLUMN id_sede SET DEFAULT 4;

CREATE TABLE ventas.detalle_pedido (
    id_sede         INTEGER       NOT NULL,
    id_pedido       INTEGER       NOT NULL,
    id_producto     INTEGER       NOT NULL,             -- † catalogo.productos
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(14,2) NOT NULL CHECK (precio_unitario > 0),  -- histórico (RN-27)
    PRIMARY KEY (id_sede, id_pedido, id_producto),
    FOREIGN KEY (id_sede, id_pedido) REFERENCES ventas.pedidos_venta (id_sede, id_pedido)
) PARTITION BY LIST (id_sede);

CREATE TABLE ventas.det_ped_bogota   PARTITION OF ventas.detalle_pedido FOR VALUES IN (1);
CREATE TABLE ventas.det_ped_medellin PARTITION OF ventas.detalle_pedido FOR VALUES IN (2);
CREATE TABLE ventas.det_ped_cali     PARTITION OF ventas.detalle_pedido FOR VALUES IN (3);
CREATE TABLE ventas.det_ped_cedi     PARTITION OF ventas.detalle_pedido FOR VALUES IN (4);

-- Pagos y devoluciones NO se fragmentan; referencian el pedido con su
-- clave compuesta (FK hacia tabla particionada, PostgreSQL >= 12).
CREATE TABLE ventas.pagos (
    id_pago    INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede    INTEGER       NOT NULL,
    id_pedido  INTEGER       NOT NULL,
    fecha_pago DATE          NOT NULL,
    valor      NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    medio_pago VARCHAR(20)   NOT NULL CHECK (medio_pago IN ('EFECTIVO', 'TARJETA_DEBITO', 'TARJETA_CREDITO', 'TRANSFERENCIA')),
    estado     VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO')),
    FOREIGN KEY (id_sede, id_pedido) REFERENCES ventas.pedidos_venta (id_sede, id_pedido)
);

CREATE TABLE ventas.devoluciones (
    id_devolucion   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede         INTEGER      NOT NULL,
    id_pedido       INTEGER      NOT NULL,
    fecha_solicitud DATE         NOT NULL,
    motivo          VARCHAR(200) NOT NULL,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'SOLICITADA' CHECK (estado IN ('SOLICITADA', 'APROBADA', 'RECHAZADA')),
    FOREIGN KEY (id_sede, id_pedido) REFERENCES ventas.pedidos_venta (id_sede, id_pedido)
);

CREATE TABLE ventas.detalle_devolucion (
    id_devolucion      INTEGER     NOT NULL REFERENCES ventas.devoluciones (id_devolucion),
    id_producto        INTEGER     NOT NULL,            -- † catalogo.productos
    cantidad           INTEGER     NOT NULL CHECK (cantidad > 0),
    condicion_producto VARCHAR(10) NOT NULL CHECK (condicion_producto IN ('BUENO', 'AVERIADO')),
    PRIMARY KEY (id_devolucion, id_producto)
);

CREATE INDEX idx_pedidos_cliente ON ventas.pedidos_venta (id_cliente);
CREATE INDEX idx_pedidos_fecha   ON ventas.pedidos_venta (fecha_pedido);
CREATE INDEX idx_pagos_pedido    ON ventas.pagos (id_sede, id_pedido);
CREATE INDEX idx_devol_pedido    ON ventas.devoluciones (id_sede, id_pedido);

COMMENT ON TABLE ventas.pedidos_venta      IS 'Responsable: Ventas y Pagos. Fragmentada por id_sede';
COMMENT ON TABLE ventas.ped_bogota         IS 'Fragmento de pedidos_venta: id_sede = 1 (Sede Bogotá)';
COMMENT ON TABLE ventas.ped_medellin       IS 'Fragmento de pedidos_venta: id_sede = 2 (Sede Medellín)';
COMMENT ON TABLE ventas.ped_cali           IS 'Fragmento de pedidos_venta: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE ventas.ped_cedi           IS 'Fragmento de pedidos_venta: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE ventas.detalle_pedido     IS 'Responsable: Ventas y Pagos. Fragmentación derivada de pedidos_venta';
COMMENT ON TABLE ventas.pagos              IS 'Responsable: Ventas y Pagos';
COMMENT ON TABLE ventas.devoluciones       IS 'Responsable: Ventas y Pagos';
COMMENT ON TABLE ventas.detalle_devolucion IS 'Responsable: Ventas y Pagos';
