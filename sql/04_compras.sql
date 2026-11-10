-- =====================================================================
-- 04_compras.sql
-- microservicio de compras y abastecimiento: ordenes de compra y sus
-- recepciones, cada una con su detalle.
--
-- se corre en andina_compras (y en andina_reportes para la copia).
--
-- ids que vienen de otros servicios ("ref:", sin FK porque estan en
-- otra base): id_proveedor, id_almacen_destino, id_empleado e
-- id_producto. las FK locales unen cada detalle con su encabezado
-- dentro de compras.
-- =====================================================================

CREATE SCHEMA compras;
COMMENT ON SCHEMA compras IS 'Microservicio de Compras y Abastecimiento';

-- una orden: un proveedor, un almacen destino y el empleado que la emite
-- (RN-08). el estado se actualiza segun lo recibido: PARCIAL si llego
-- una parte, RECIBIDA si llego todo (RN-13).
CREATE TABLE compras.ordenes_compra (
    id_orden_compra    INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_proveedor       INTEGER     NOT NULL,            -- ref: catalogo.proveedores
    id_almacen_destino INTEGER     NOT NULL,            -- ref: catalogo.almacenes
    id_empleado        INTEGER     NOT NULL,            -- ref: identidad.empleados
    fecha_orden        DATE        NOT NULL,
    fecha_estimada     DATE        NOT NULL,
    estado             VARCHAR(10) NOT NULL DEFAULT 'EMITIDA'
                       CHECK (estado IN ('EMITIDA', 'PARCIAL', 'RECIBIDA', 'CANCELADA')),
    -- CHECK de tabla: compara dos columnas de la misma fila
    CHECK (fecha_estimada >= fecha_orden)                                   -- RN-10
);

-- productos de la orden (RN-09). la PK (orden, producto) impide pedir el
-- mismo producto dos veces en la misma orden.
-- costo_unitario es el costo pactado en ESTA orden, no el del catalogo:
-- asi los reportes de periodos anteriores no cambian (RN-27).
CREATE TABLE compras.detalle_orden_compra (
    id_orden_compra     INTEGER       NOT NULL REFERENCES compras.ordenes_compra (id_orden_compra),
    id_producto         INTEGER       NOT NULL,         -- ref: catalogo.productos
    cantidad_solicitada INTEGER       NOT NULL CHECK (cantidad_solicitada > 0),
    costo_unitario      NUMERIC(14,2) NOT NULL CHECK (costo_unitario > 0),
    PRIMARY KEY (id_orden_compra, id_producto)
);

-- una entrega del proveedor. una orden puede tener varias recepciones:
-- asi se registran las compras recibidas por partes (RN-11).
CREATE TABLE compras.recepciones_compra (
    id_recepcion    INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_orden_compra INTEGER     NOT NULL REFERENCES compras.ordenes_compra (id_orden_compra),
    fecha_recepcion DATE        NOT NULL,
    estado          VARCHAR(10) NOT NULL DEFAULT 'REGISTRADA' CHECK (estado IN ('REGISTRADA', 'ANULADA'))
);

-- cuanto llego de cada producto en una recepcion. el producto debe estar
-- en la orden (RN-12); no hay FK hacia el detalle de la orden, la regla
-- se cumple en los datos de prueba.
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
