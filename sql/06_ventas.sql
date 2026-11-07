-- =====================================================================
-- 06_ventas.sql
-- microservicio de ventas y pagos.
--
-- igual que el inventario, los pedidos van partidos por sede. y los
-- detalles se parten igual que su pedido, asi un pedido y sus lineas
-- siempre quedan en la misma sede:
--     ped_bogota / det_ped_bogota     (id_sede = 1)
--     ped_medellin / det_ped_medellin (id_sede = 2)
--     ped_cali / det_ped_cali         (id_sede = 3)
--     ped_cedi / det_ped_cedi         (id_sede = 4)
-- el CHECK (id_sede = n) no deja meter un pedido en la sede equivocada
-- (RN-25).
--
-- cada sede numera sus pedidos desde 1, asi que puede haber un pedido 15
-- en bogota y otro 15 en cali. por eso un pedido se identifica con
-- (id_sede, id_pedido) y no solo con id_pedido.
--
-- para toda la empresa se usan las vistas vista_pedidos_consolidado y
-- vista_detalle_pedido_consolidado (UNION ALL de las 4 sedes).
-- =====================================================================

-- ---------------------------------------------------------------------
-- pedidos (uno por sede)
-- cada tabla tiene su propio IDENTITY: el vendedor no escribe el numero
-- del pedido, la tabla de su sede le pone el siguiente.
-- ---------------------------------------------------------------------
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
    -- la suma de cantidad x precio de sus lineas (RN-28). se podria
    -- calcular, pero se guarda; la consulta 8 muestra que coincide
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
-- detalles de pedido (uno por sede)
-- la FK usa las dos columnas (id_sede, id_pedido) porque esa es la clave
-- del pedido, y apunta a la tabla de pedidos de la MISMA sede.
-- un producto no se repite dentro del mismo pedido (RN-26).
-- precio_unitario es el precio del dia de la venta: si despues cambia
-- el precio de lista, la venta vieja no cambia (RN-27).
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- pagos y devoluciones van en una sola tabla cada uno (no por sede).
-- apuntan al pedido con (id_sede, id_pedido) pero sin FK: una FK solo
-- puede apuntar a UNA tabla, y el pedido puede estar en cualquiera de
-- las 4. id_sede dice en cual buscarlo. que el pedido exista se revisa
-- con NOT EXISTS en 11_pruebas.sql.
-- ---------------------------------------------------------------------

-- un pedido puede tener varios pagos (RN-30). solo los CONFIRMADO
-- reducen el saldo (RN-31).
CREATE TABLE ventas.pagos (
    id_pago    INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede    INTEGER       NOT NULL,                  -- (id_sede, id_pedido) -> fragmento ped_*
    id_pedido  INTEGER       NOT NULL,
    fecha_pago DATE          NOT NULL,
    valor      NUMERIC(14,2) NOT NULL CHECK (valor > 0),
    medio_pago VARCHAR(20)   NOT NULL CHECK (medio_pago IN ('EFECTIVO', 'TARJETA_DEBITO', 'TARJETA_CREDITO', 'TRANSFERENCIA')),
    estado     VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'CONFIRMADO', 'RECHAZADO'))
);

-- solo se aceptan devoluciones de pedidos confirmados o entregados
-- (RN-32). solo las APROBADA cuentan en el porcentaje (RN-34).
CREATE TABLE ventas.devoluciones (
    id_devolucion   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede         INTEGER      NOT NULL,              -- (id_sede, id_pedido) -> fragmento ped_*
    id_pedido       INTEGER      NOT NULL,
    fecha_solicitud DATE         NOT NULL,
    motivo          VARCHAR(200) NOT NULL,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'SOLICITADA' CHECK (estado IN ('SOLICITADA', 'APROBADA', 'RECHAZADA'))
);

-- productos devueltos. deben estar en el pedido y no superar lo vendido
-- (RN-32, RN-33); se cumple en los datos y se verifica en las pruebas.
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
