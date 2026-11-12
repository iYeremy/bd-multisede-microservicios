-- 02_tablas/compras.sql
-- compras y abastecimiento (base andina_compras). ver README.md.
-- "ref:" = id de otra base, sin FK.

CREATE SCHEMA compras;
COMMENT ON SCHEMA compras IS 'Microservicio de Compras y Abastecimiento';

-- un proveedor, un almacen destino y quien la emite (RN-08)
CREATE TABLE compras.ordenes_compra (
    id_orden_compra    INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_proveedor       INTEGER     NOT NULL,            -- ref: catalogo.proveedores
    id_almacen_destino INTEGER     NOT NULL,            -- ref: catalogo.almacenes
    id_empleado        INTEGER     NOT NULL,            -- ref: identidad.empleados
    fecha_orden        DATE        NOT NULL,
    fecha_estimada     DATE        NOT NULL,
    estado             VARCHAR(10) NOT NULL DEFAULT 'EMITIDA'
                       CHECK (estado IN ('EMITIDA', 'PARCIAL', 'RECIBIDA', 'CANCELADA')),
    CHECK (fecha_estimada >= fecha_orden)                                   -- RN-10
);

-- productos de la orden (RN-09). costo_unitario = el pactado en esta orden (RN-27)
CREATE TABLE compras.detalle_orden_compra (
    id_orden_compra     INTEGER       NOT NULL REFERENCES compras.ordenes_compra (id_orden_compra),
    id_producto         INTEGER       NOT NULL,         -- ref: catalogo.productos
    cantidad_solicitada INTEGER       NOT NULL CHECK (cantidad_solicitada > 0),
    costo_unitario      NUMERIC(14,2) NOT NULL CHECK (costo_unitario > 0),
    PRIMARY KEY (id_orden_compra, id_producto)
);

-- una orden puede llegar en varias entregas (RN-11)
CREATE TABLE compras.recepciones_compra (
    id_recepcion    INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_orden_compra INTEGER     NOT NULL REFERENCES compras.ordenes_compra (id_orden_compra),
    fecha_recepcion DATE        NOT NULL,
    estado          VARCHAR(10) NOT NULL DEFAULT 'REGISTRADA' CHECK (estado IN ('REGISTRADA', 'ANULADA'))
);

-- cuanto llego de cada producto (RN-12)
CREATE TABLE compras.detalle_recepcion (
    id_recepcion      INTEGER NOT NULL REFERENCES compras.recepciones_compra (id_recepcion),
    id_producto       INTEGER NOT NULL,                 -- ref: catalogo.productos
    cantidad_recibida INTEGER NOT NULL CHECK (cantidad_recibida >= 0),
    PRIMARY KEY (id_recepcion, id_producto)
);

COMMENT ON TABLE compras.ordenes_compra       IS 'Responsable: Compras y Abastecimiento';
COMMENT ON TABLE compras.detalle_orden_compra IS 'Responsable: Compras y Abastecimiento';
COMMENT ON TABLE compras.recepciones_compra   IS 'Responsable: Compras y Abastecimiento';
COMMENT ON TABLE compras.detalle_recepcion    IS 'Responsable: Compras y Abastecimiento';
