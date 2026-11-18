-- 02_tablas/ventas.sql
-- ventas y pagos (base andina_ventas). ver README.md.
-- pedidos y detalles van partidos por sede (ped_*, det_ped_*) con
-- CHECK (id_sede = n) (RN-25). un pedido se identifica con
-- (id_sede, id_pedido): cada sede numera desde 1.

CREATE SCHEMA ventas;
COMMENT ON SCHEMA ventas IS 'Microservicio de Ventas y Pagos (pedidos y detalles fragmentados por sede)';

-- pedidos, uno por sede. cada uno con su propio IDENTITY
CREATE TABLE ventas.ped_bogota (
    id_sede          INTEGER       NOT NULL DEFAULT 1 CHECK (id_sede = 1),  -- ref: catalogo.sedes
    id_pedido        INTEGER       GENERATED ALWAYS AS IDENTITY,
    id_almacen       INTEGER       NOT NULL,            -- ref: catalogo.almacenes (de esta sede, RN-24)
    id_cliente       INTEGER       NOT NULL,            -- ref: catalogo.clientes
    id_empleado      INTEGER       NOT NULL,            -- ref: identidad.empleados
    fecha_pedido     DATE          NOT NULL,
    -- solo CONFIRMADO y ENTREGADO cuentan como venta (RN-29)
    estado           VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'ANULADO')),
    -- suma de cantidad x precio de sus lineas (RN-28)
    total_registrado NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_registrado >= 0),
    PRIMARY KEY (id_sede, id_pedido)
);

CREATE TABLE ventas.ped_medellin (
    id_sede          INTEGER       NOT NULL DEFAULT 2 CHECK (id_sede = 2),
    id_pedido        INTEGER       GENERATED ALWAYS AS IDENTITY,
    id_almacen       INTEGER       NOT NULL,
    id_cliente       INTEGER       NOT NULL,
    id_empleado      INTEGER       NOT NULL,
    fecha_pedido     DATE          NOT NULL,
    estado           VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'ANULADO')),
    total_registrado NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_registrado >= 0),
    PRIMARY KEY (id_sede, id_pedido)
);

CREATE TABLE ventas.ped_cali (
    id_sede          INTEGER       NOT NULL DEFAULT 3 CHECK (id_sede = 3),
    id_pedido        INTEGER       GENERATED ALWAYS AS IDENTITY,
    id_almacen       INTEGER       NOT NULL,
    id_cliente       INTEGER       NOT NULL,
    id_empleado      INTEGER       NOT NULL,
    fecha_pedido     DATE          NOT NULL,
    estado           VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'ANULADO')),
    total_registrado NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_registrado >= 0),
    PRIMARY KEY (id_sede, id_pedido)
);

CREATE TABLE ventas.ped_cedi (
    id_sede          INTEGER       NOT NULL DEFAULT 4 CHECK (id_sede = 4),
    id_pedido        INTEGER       GENERATED ALWAYS AS IDENTITY,
    id_almacen       INTEGER       NOT NULL,
    id_cliente       INTEGER       NOT NULL,
    id_empleado      INTEGER       NOT NULL,
    fecha_pedido     DATE          NOT NULL,
    estado           VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'ANULADO')),
    total_registrado NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_registrado >= 0),
    PRIMARY KEY (id_sede, id_pedido)
);

-- detalles, uno por sede. FK compuesta al pedido de la MISMA sede.
-- precio_unitario = el del dia de la venta (RN-27)
CREATE TABLE ventas.det_ped_bogota (
    id_sede         INTEGER       NOT NULL DEFAULT 1 CHECK (id_sede = 1),
    id_pedido       INTEGER       NOT NULL,
    id_producto     INTEGER       NOT NULL,             -- ref: catalogo.productos
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(14,2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (id_sede, id_pedido, id_producto),
    FOREIGN KEY (id_sede, id_pedido) REFERENCES ventas.ped_bogota (id_sede, id_pedido)
);

CREATE TABLE ventas.det_ped_medellin (
    id_sede         INTEGER       NOT NULL DEFAULT 2 CHECK (id_sede = 2),
    id_pedido       INTEGER       NOT NULL,
    id_producto     INTEGER       NOT NULL,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(14,2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (id_sede, id_pedido, id_producto),
    FOREIGN KEY (id_sede, id_pedido) REFERENCES ventas.ped_medellin (id_sede, id_pedido)
);

CREATE TABLE ventas.det_ped_cali (
    id_sede         INTEGER       NOT NULL DEFAULT 3 CHECK (id_sede = 3),
    id_pedido       INTEGER       NOT NULL,
    id_producto     INTEGER       NOT NULL,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(14,2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (id_sede, id_pedido, id_producto),
    FOREIGN KEY (id_sede, id_pedido) REFERENCES ventas.ped_cali (id_sede, id_pedido)
);

CREATE TABLE ventas.det_ped_cedi (
    id_sede         INTEGER       NOT NULL DEFAULT 4 CHECK (id_sede = 4),
    id_pedido       INTEGER       NOT NULL,
    id_producto     INTEGER       NOT NULL,
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(14,2) NOT NULL CHECK (precio_unitario > 0),
    PRIMARY KEY (id_sede, id_pedido, id_producto),
    FOREIGN KEY (id_sede, id_pedido) REFERENCES ventas.ped_cedi (id_sede, id_pedido)
);

-- pagos y devoluciones: una sola tabla cada uno. apuntan al pedido con
-- (id_sede, id_pedido) SIN FK, porque el pedido puede estar en
-- cualquiera de los 4 fragmentos.

-- varios pagos por pedido (RN-30); solo los CONFIRMADO cuentan (RN-31)
CREATE TABLE ventas.pagos (
    id_pago    INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede    INTEGER       NOT NULL,                  -- (id_sede, id_pedido) -> fragmento ped_*
    id_pedido  INTEGER       NOT NULL,
    fecha_pago DATE          NOT NULL,
    valor      NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    medio_pago VARCHAR(20)   NOT NULL CHECK (medio_pago IN ('EFECTIVO', 'TARJETA_DEBITO', 'TARJETA_CREDITO', 'TRANSFERENCIA')),
    estado     VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO'))
);

-- de pedidos confirmados o entregados (RN-32)
CREATE TABLE ventas.devoluciones (
    id_devolucion   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede         INTEGER      NOT NULL,              -- (id_sede, id_pedido) -> fragmento ped_*
    id_pedido       INTEGER      NOT NULL,
    fecha_solicitud DATE         NOT NULL,
    motivo          VARCHAR(200) NOT NULL,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'SOLICITADA' CHECK (estado IN ('SOLICITADA', 'APROBADA', 'RECHAZADA'))
);

-- productos devueltos (RN-32, RN-33)
CREATE TABLE ventas.detalle_devolucion (
    id_devolucion      INTEGER     NOT NULL REFERENCES ventas.devoluciones (id_devolucion),
    id_producto        INTEGER     NOT NULL,            -- ref: catalogo.productos
    cantidad           INTEGER     NOT NULL CHECK (cantidad > 0),
    condicion_producto VARCHAR(10) NOT NULL CHECK (condicion_producto IN ('BUENO', 'AVERIADO')),
    PRIMARY KEY (id_devolucion, id_producto)
);

COMMENT ON TABLE ventas.ped_bogota         IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 1 (Sede Bogota)';
COMMENT ON TABLE ventas.ped_medellin       IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 2 (Sede Medellin)';
COMMENT ON TABLE ventas.ped_cali           IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE ventas.ped_cedi           IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE ventas.det_ped_bogota     IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 1 (Sede Bogota)';
COMMENT ON TABLE ventas.det_ped_medellin   IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 2 (Sede Medellin)';
COMMENT ON TABLE ventas.det_ped_cali       IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE ventas.det_ped_cedi       IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE ventas.pagos              IS 'Responsable: Ventas y Pagos';
COMMENT ON TABLE ventas.devoluciones       IS 'Responsable: Ventas y Pagos';
COMMENT ON TABLE ventas.detalle_devolucion IS 'Responsable: Ventas y Pagos';
