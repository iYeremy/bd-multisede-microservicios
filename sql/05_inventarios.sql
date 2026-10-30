-- =====================================================================
-- 05_inventarios.sql
-- Microservicio de Inventarios y Transferencias.
--
-- FRAGMENTACIÓN HORIZONTAL: el inventario se guarda en una tabla física
-- por sede, todas con las mismas columnas:
--     inv_bogota (1) · inv_medellin (2) · inv_cali (3) · inv_cedi (4)
-- La condición de cada fragmento es id_sede = n y se asegura con un
-- CHECK: una fila con otra sede se rechaza, así un registro nunca puede
-- quedar en dos fragmentos. La vista reportes.vista_inventario_consolidado
-- reúne los cuatro con UNION ALL.
-- =====================================================================

CREATE TABLE inventarios.inv_bogota (
    id_sede             INTEGER   NOT NULL DEFAULT 1 CHECK (id_sede = 1),  -- † catalogo.sedes
    id_almacen          INTEGER   NOT NULL,             -- † catalogo.almacenes
    id_producto         INTEGER   NOT NULL,             -- † catalogo.productos
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
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

CREATE TABLE inventarios.inv_cedi (
    id_sede             INTEGER   NOT NULL DEFAULT 4 CHECK (id_sede = 4),
    id_almacen          INTEGER   NOT NULL,
    id_producto         INTEGER   NOT NULL,
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (id_sede, id_almacen, id_producto)
);

CREATE TABLE inventarios.transferencias (
    id_transferencia   INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_almacen_origen  INTEGER     NOT NULL,            -- † catalogo.almacenes
    id_almacen_destino INTEGER     NOT NULL,            -- † catalogo.almacenes
    fecha_solicitud    DATE        NOT NULL,
    fecha_despacho     DATE,                            -- NULL hasta despachar
    fecha_recepcion    DATE,                            -- NULL hasta recibir
    estado             VARCHAR(10) NOT NULL DEFAULT 'SOLICITADA'
                       CHECK (estado IN ('SOLICITADA', 'DESPACHADA', 'RECIBIDA', 'CANCELADA')),
    CHECK (id_almacen_origen <> id_almacen_destino),                        -- RN-19
    CHECK (fecha_despacho  IS NULL OR fecha_despacho  >= fecha_solicitud),  -- RN-20
    CHECK (fecha_recepcion IS NULL OR (fecha_despacho IS NOT NULL AND fecha_recepcion >= fecha_despacho))
);

CREATE TABLE inventarios.detalle_transferencia (
    id_transferencia  INTEGER NOT NULL REFERENCES inventarios.transferencias (id_transferencia),
    id_producto       INTEGER NOT NULL,                 -- † catalogo.productos
    cantidad_enviada  INTEGER NOT NULL CHECK (cantidad_enviada > 0),
    cantidad_recibida INTEGER CHECK (cantidad_recibida >= 0),  -- NULL hasta recibir (RN-21)
    PRIMARY KEY (id_transferencia, id_producto)
);

COMMENT ON TABLE inventarios.inv_bogota            IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 1 (Sede Bogotá)';
COMMENT ON TABLE inventarios.inv_medellin          IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 2 (Sede Medellín)';
COMMENT ON TABLE inventarios.inv_cali              IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE inventarios.inv_cedi              IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE inventarios.transferencias        IS 'Responsable: Inventarios y Transferencias';
COMMENT ON TABLE inventarios.detalle_transferencia IS 'Responsable: Inventarios y Transferencias';
