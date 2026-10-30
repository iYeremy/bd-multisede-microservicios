-- =====================================================================
-- 04_compras.sql
-- Microservicio de Compras y Abastecimiento.
-- Identificadores compartidos (†, sin FK): id_proveedor, id_almacen_destino,
-- id_empleado e id_producto.
-- =====================================================================

CREATE TABLE compras.ordenes_compra (
    id_orden_compra    INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_proveedor       INTEGER     NOT NULL,            -- † catalogo.proveedores
    id_almacen_destino INTEGER     NOT NULL,            -- † catalogo.almacenes
    id_empleado        INTEGER     NOT NULL,            -- † identidad.empleados
    fecha_orden        DATE        NOT NULL,
    fecha_estimada     DATE        NOT NULL,
    estado             VARCHAR(10) NOT NULL DEFAULT 'EMITIDA'
                       CHECK (estado IN ('EMITIDA', 'PARCIAL', 'RECIBIDA', 'CANCELADA')),
    CHECK (fecha_estimada >= fecha_orden)                                   -- RN-10
);

CREATE TABLE compras.detalle_orden_compra (
    id_orden_compra     INTEGER       NOT NULL REFERENCES compras.ordenes_compra (id_orden_compra),
    id_producto         INTEGER       NOT NULL,         -- † catalogo.productos
    cantidad_solicitada INTEGER       NOT NULL CHECK (cantidad_solicitada > 0),
    costo_unitario      NUMERIC(14,2) NOT NULL CHECK (costo_unitario > 0),  -- histórico (RN-27)
    PRIMARY KEY (id_orden_compra, id_producto)
);

CREATE TABLE compras.recepciones_compra (
    id_recepcion    INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_orden_compra INTEGER     NOT NULL REFERENCES compras.ordenes_compra (id_orden_compra),
    fecha_recepcion DATE        NOT NULL,
    estado          VARCHAR(10) NOT NULL DEFAULT 'REGISTRADA' CHECK (estado IN ('REGISTRADA', 'ANULADA'))
);

CREATE TABLE compras.detalle_recepcion (
    id_recepcion      INTEGER NOT NULL REFERENCES compras.recepciones_compra (id_recepcion),
    id_producto       INTEGER NOT NULL,                 -- † catalogo.productos
    cantidad_recibida INTEGER NOT NULL CHECK (cantidad_recibida >= 0),
    PRIMARY KEY (id_recepcion, id_producto)
);

COMMENT ON TABLE compras.ordenes_compra       IS 'Responsable: Compras y Abastecimiento';
COMMENT ON TABLE compras.detalle_orden_compra IS 'Responsable: Compras y Abastecimiento';
COMMENT ON TABLE compras.recepciones_compra   IS 'Responsable: Compras y Abastecimiento';
COMMENT ON TABLE compras.detalle_recepcion    IS 'Responsable: Compras y Abastecimiento';
