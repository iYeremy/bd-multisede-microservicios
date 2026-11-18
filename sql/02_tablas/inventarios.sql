-- 02_tablas/inventarios.sql
-- inventarios y transferencias (base andina_inventarios). ver README.md.
-- el inventario va partido por sede: inv_bogota (1), inv_medellin (2),
-- inv_cali (3), inv_cedi (4). el CHECK (id_sede = n) no deja meter filas
-- de otra sede (RN-17).

CREATE SCHEMA inventarios;
COMMENT ON SCHEMA inventarios IS 'Microservicio de Inventarios y Transferencias (inventarios fragmentado por sede)';

CREATE TABLE inventarios.inv_bogota (
    id_sede             INTEGER   NOT NULL DEFAULT 1 CHECK (id_sede = 1),  -- ref: catalogo.sedes
    id_almacen          INTEGER   NOT NULL,             -- ref: catalogo.almacenes
    id_producto         INTEGER   NOT NULL,             -- ref: catalogo.productos
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),  -- RN-16
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
    -- un registro por sede, almacen y producto (RN-15)
    PRIMARY KEY (id_sede, id_almacen, id_producto)
);

CREATE TABLE inventarios.inv_medellin (
    id_sede             INTEGER   NOT NULL DEFAULT 2 CHECK (id_sede = 2),
    id_almacen          INTEGER   NOT NULL,
    id_producto         INTEGER   NOT NULL,
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (id_sede, id_almacen, id_producto)
);

CREATE TABLE inventarios.inv_cali (
    id_sede             INTEGER   NOT NULL DEFAULT 3 CHECK (id_sede = 3),
    id_almacen          INTEGER   NOT NULL,
    id_producto         INTEGER   NOT NULL,
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (id_sede, id_almacen, id_producto)
);

-- el CEDI tiene dos almacenes (4 y 5)
CREATE TABLE inventarios.inv_cedi (
    id_sede             INTEGER   NOT NULL DEFAULT 4 CHECK (id_sede = 4),
    id_almacen          INTEGER   NOT NULL,
    id_producto         INTEGER   NOT NULL,
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (id_sede, id_almacen, id_producto)
);

-- no se fragmenta: puede ir de una sede a otra. las fechas quedan NULL hasta que pasa cada paso
CREATE TABLE inventarios.transferencias (
    id_transferencia   INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen_origen  INTEGER     NOT NULL,            -- ref: catalogo.almacenes
    id_almacen_destino INTEGER     NOT NULL,            -- ref: catalogo.almacenes
    fecha_solicitud    DATE        NOT NULL,
    fecha_despacho     DATE,
    fecha_recepcion    DATE,
    estado             VARCHAR(10) NOT NULL DEFAULT 'SOLICITADA'
                       CHECK (estado IN ('SOLICITADA', 'DESPACHADA', 'RECIBIDA', 'CANCELADA')),
    -- origen y destino distintos (RN-19)
    CHECK (id_almacen_origen <> id_almacen_destino),
    -- solicitud <= despacho <= recepcion (RN-20)
    CHECK (fecha_despacho  IS NULL OR fecha_despacho  >= fecha_solicitud),
    CHECK (fecha_recepcion IS NULL OR (fecha_despacho IS NOT NULL AND fecha_recepcion >= fecha_despacho))
);

-- cantidad_recibida queda NULL mientras esta en transito (RN-21, RN-23)
CREATE TABLE inventarios.detalle_transferencia (
    id_transferencia  INTEGER NOT NULL REFERENCES inventarios.transferencias (id_transferencia),
    id_producto       INTEGER NOT NULL,                 -- ref: catalogo.productos
    cantidad_enviada  INTEGER NOT NULL CHECK (cantidad_enviada > 0),
    cantidad_recibida INTEGER CHECK (cantidad_recibida >= 0),
    PRIMARY KEY (id_transferencia, id_producto)
);

-- cada fragmento documenta su condicion
COMMENT ON TABLE inventarios.inv_bogota            IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 1 (Sede Bogota)';
COMMENT ON TABLE inventarios.inv_medellin          IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 2 (Sede Medellin)';
COMMENT ON TABLE inventarios.inv_cali              IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE inventarios.inv_cedi              IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE inventarios.transferencias        IS 'Responsable: Inventarios y Transferencias';
COMMENT ON TABLE inventarios.detalle_transferencia IS 'Responsable: Inventarios y Transferencias';
