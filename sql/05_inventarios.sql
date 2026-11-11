-- =====================================================================
-- 05_inventarios.sql
-- microservicio de inventarios y transferencias. se corre en
-- andina_inventarios (y en andina_reportes para el staging del ETL).
--
-- la idea principal: el inventario no va en una sola tabla, va partido
-- por sede (fragmentacion horizontal). cada sede tiene su propia tabla:
--     inv_bogota (1), inv_medellin (2), inv_cali (3), inv_cedi (4)
-- las 4 tienen las mismas columnas. lo unico que cambia es el numero
-- de sede en el CHECK: en inv_bogota solo pueden entrar filas con
-- id_sede = 1, asi una fila nunca queda en dos tablas (RN-17).
--
-- para ver el inventario de toda la empresa se juntan las 4 con la
-- vista reportes.vista_inventario_consolidado (UNION ALL), en la base
-- de reportes.
--
-- ojo: id_almacen ya dice de que sede es, asi que id_sede sobra un
-- poco. se deja porque es la columna que usa el CHECK para partir la
-- tabla (ver docs/normalizacion.md, seccion 4.1).
-- =====================================================================

CREATE SCHEMA inventarios;
COMMENT ON SCHEMA inventarios IS 'Microservicio de Inventarios y Transferencias (inventarios fragmentado por sede)';

CREATE TABLE inventarios.inv_bogota (
    -- DEFAULT 1: si el INSERT no indica la sede, se usa la del fragmento
    id_sede             INTEGER   NOT NULL DEFAULT 1 CHECK (id_sede = 1),  -- ref: catalogo.sedes
    id_almacen          INTEGER   NOT NULL,             -- ref: catalogo.almacenes
    id_producto         INTEGER   NOT NULL,             -- ref: catalogo.productos
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),  -- RN-16
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
    -- un solo registro por sede, almacen y producto (RN-15)
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

-- el CEDI tiene dos almacenes (4 y 5), ambos en este fragmento
CREATE TABLE inventarios.inv_cedi (
    id_sede             INTEGER   NOT NULL DEFAULT 4 CHECK (id_sede = 4),
    id_almacen          INTEGER   NOT NULL,
    id_producto         INTEGER   NOT NULL,
    existencia_actual   INTEGER   NOT NULL CHECK (existencia_actual >= 0),
    stock_minimo        INTEGER   NOT NULL CHECK (stock_minimo >= 0),
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (id_sede, id_almacen, id_producto)
);

-- traslado entre dos almacenes. no se fragmenta: puede ir de una sede a
-- otra. las dos columnas de almacen son dos relaciones distintas con
-- almacenes (origen y destino), por eso hay dos identificadores.
-- las fechas quedan vacias (NULL) hasta que ocurre cada paso.
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
    -- orden de las fechas: solicitud <= despacho <= recepcion (RN-20).
    -- "col IS NULL OR ..." deja pasar la fila mientras la fecha no exista;
    -- no se puede recibir algo que no se ha despachado.
    CHECK (fecha_despacho  IS NULL OR fecha_despacho  >= fecha_solicitud),
    CHECK (fecha_recepcion IS NULL OR (fecha_despacho IS NOT NULL AND fecha_recepcion >= fecha_despacho))
);

-- productos de cada transferencia. cantidad_recibida queda NULL
-- mientras esta en transito y puede diferir de la enviada (RN-21, RN-23).
CREATE TABLE inventarios.detalle_transferencia (
    id_transferencia  INTEGER NOT NULL REFERENCES inventarios.transferencias (id_transferencia),
    id_producto       INTEGER NOT NULL,                 -- ref: catalogo.productos
    cantidad_enviada  INTEGER NOT NULL CHECK (cantidad_enviada > 0),
    cantidad_recibida INTEGER CHECK (cantidad_recibida >= 0),
    PRIMARY KEY (id_transferencia, id_producto)
);

-- el comentario de cada fragmento documenta su condicion
COMMENT ON TABLE inventarios.inv_bogota            IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 1 (Sede Bogota)';
COMMENT ON TABLE inventarios.inv_medellin          IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 2 (Sede Medellin)';
COMMENT ON TABLE inventarios.inv_cali              IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 3 (Sede Cali)';
COMMENT ON TABLE inventarios.inv_cedi              IS 'Responsable: Inventarios y Transferencias. Fragmento de inventario: id_sede = 4 (CEDI Funza)';
COMMENT ON TABLE inventarios.transferencias        IS 'Responsable: Inventarios y Transferencias';
COMMENT ON TABLE inventarios.detalle_transferencia IS 'Responsable: Inventarios y Transferencias';
