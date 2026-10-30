-- =====================================================================
-- 06_ventas.sql
-- Microservicio de Ventas y Pagos.
--
-- FRAGMENTACIÓN HORIZONTAL: los pedidos se guardan en una tabla física
-- por sede, y sus detalles se fragmentan con la MISMA condición
-- (fragmentación derivada), así un pedido y sus detalles quedan en el
-- mismo fragmento y se enlazan con una FK local:
--     ped_bogota / det_ped_bogota     (id_sede = 1)
--     ped_medellin / det_ped_medellin (id_sede = 2)
--     ped_cali / det_ped_cali         (id_sede = 3)
--     ped_cedi / det_ped_cedi         (id_sede = 4)
-- Un CHECK (id_sede = n) en cada fragmento impide guardar una fila en
-- la sede equivocada.
--
-- id_pedido es un consecutivo DENTRO de cada sede: la PK es
-- (id_sede, id_pedido). Cada fragmento tiene su propia columna IDENTITY,
-- así cada sede numera sus pedidos desde 1 y el vendedor no tiene que
-- indicar el número al insertar.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Fragmentos de pedidos_venta
-- ---------------------------------------------------------------------
CREATE TABLE ventas.ped_bogota (
    id_sede          INTEGER       NOT NULL DEFAULT 1 CHECK (id_sede = 1),  -- † catalogo.sedes
    id_pedido        INTEGER       GENERATED ALWAYS AS IDENTITY,
    id_almacen       INTEGER       NOT NULL,            -- † catalogo.almacenes
    id_cliente       INTEGER       NOT NULL,            -- † catalogo.clientes
    id_empleado      INTEGER       NOT NULL,            -- † identidad.empleados
    fecha_pedido     DATE          NOT NULL,
    estado           VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'ANULADO')),
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

-- ---------------------------------------------------------------------
-- Fragmentos de detalle_pedido (cada uno con FK a su fragmento de pedidos)
-- ---------------------------------------------------------------------
CREATE TABLE ventas.det_ped_bogota (
    id_sede         INTEGER       NOT NULL DEFAULT 1 CHECK (id_sede = 1),
    id_pedido       INTEGER       NOT NULL,
    id_producto     INTEGER       NOT NULL,             -- † catalogo.productos
    cantidad        INTEGER       NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(14,2) NOT NULL CHECK (precio_unitario > 0),  -- histórico (RN-27)
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

-- ---------------------------------------------------------------------
-- Pagos y devoluciones NO se fragmentan. Identifican el pedido con su
-- clave compuesta (id_sede, id_pedido); como el pedido puede estar en
-- cualquiera de los cuatro fragmentos, no se declara FK y la referencia
-- se comprueba con NOT EXISTS en 11_pruebas.sql.
-- ---------------------------------------------------------------------
CREATE TABLE ventas.pagos (
    id_pago    INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede    INTEGER       NOT NULL,                  -- (id_sede, id_pedido) → fragmento ped_*
    id_pedido  INTEGER       NOT NULL,
    fecha_pago DATE          NOT NULL,
    valor      NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    medio_pago VARCHAR(20)   NOT NULL CHECK (medio_pago IN ('EFECTIVO', 'TARJETA_DEBITO', 'TARJETA_CREDITO', 'TRANSFERENCIA')),
    estado     VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO'))
);

CREATE TABLE ventas.devoluciones (
    id_devolucion   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede         INTEGER      NOT NULL,              -- (id_sede, id_pedido) → fragmento ped_*
    id_pedido       INTEGER      NOT NULL,
    fecha_solicitud DATE         NOT NULL,
    motivo          VARCHAR(200) NOT NULL,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'SOLICITADA' CHECK (estado IN ('SOLICITADA', 'APROBADA', 'RECHAZADA'))
);

CREATE TABLE ventas.detalle_devolucion (
    id_devolucion      INTEGER     NOT NULL REFERENCES ventas.devoluciones (id_devolucion),
    id_producto        INTEGER     NOT NULL,            -- † catalogo.productos
    cantidad           INTEGER     NOT NULL CHECK (cantidad > 0),
    condicion_producto VARCHAR(10) NOT NULL CHECK (condicion_producto IN ('BUENO', 'AVERIADO')),
    PRIMARY KEY (id_devolucion, id_producto)
);

COMMENT ON TABLE ventas.ped_bogota         IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 1 (Sede Bogotá)';
COMMENT ON TABLE ventas.ped_medellin       IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 2 (Sede Medellín)';
COMMENT ON TABLE ventas.ped_cali           IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE ventas.ped_cedi           IS 'Responsable: Ventas y Pagos. Fragmento de pedidos_venta: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE ventas.det_ped_bogota     IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 1 (Sede Bogotá)';
COMMENT ON TABLE ventas.det_ped_medellin   IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 2 (Sede Medellín)';
COMMENT ON TABLE ventas.det_ped_cali       IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE ventas.det_ped_cedi       IS 'Responsable: Ventas y Pagos. Fragmento de detalle_pedido: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE ventas.pagos              IS 'Responsable: Ventas y Pagos';
COMMENT ON TABLE ventas.devoluciones       IS 'Responsable: Ventas y Pagos';
COMMENT ON TABLE ventas.detalle_devolucion IS 'Responsable: Ventas y Pagos';
