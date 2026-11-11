-- =====================================================================
-- 02_catalogo.sql
-- microservicio de catalogo y terceros: las tablas "base" que usan
-- todos los demas (sedes, almacenes, productos, clientes...).
--
-- se corre en la base andina_catalogo. reportes lee estas tablas con
-- dblink.
--
-- aqui las FK son normales porque todo esta dentro de catalogo. los
-- otros servicios guardan los id de estas tablas pero sin FK
-- (identificadores compartidos, S-09): una FK no puede apuntar a otra
-- base.
--
-- cosas que se repiten en todos los scripts de tablas:
--   GENERATED ALWAYS AS IDENTITY  la base pone el numero sola al
--                                 insertar (1, 2, 3...)
--   CHECK (col IN (...))          solo deja guardar esos valores
--   DEFAULT                       valor que se usa si no se indica uno
--   NUMERIC(14,2)                 plata en pesos con 2 decimales
-- =====================================================================

CREATE SCHEMA catalogo;
COMMENT ON SCHEMA catalogo IS 'Microservicio de Catalogo y Terceros (datos maestros)';

-- sedes de la empresa: 3 de venta y el CEDI de Funza (RN-01)
CREATE TABLE catalogo.sedes (
    id_sede     INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(60)  NOT NULL UNIQUE,
    ciudad      VARCHAR(60)  NOT NULL,
    direccion   VARCHAR(120) NOT NULL,
    tipo_sede   VARCHAR(15)  NOT NULL CHECK (tipo_sede IN ('VENTA', 'DISTRIBUCION')),
    estado      VARCHAR(10)  NOT NULL DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'INACTIVA'))
);

-- lugar fisico donde esta la mercancia. cada almacen pertenece a una
-- sede (RN-02); el CEDI tiene dos (bodega general y de despacho).
-- UNIQUE (id_sede, nombre): el nombre no se repite dentro de una sede.
CREATE TABLE catalogo.almacenes (
    id_almacen   INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede      INTEGER     NOT NULL REFERENCES catalogo.sedes (id_sede),
    nombre       VARCHAR(60) NOT NULL,
    tipo_almacen VARCHAR(15) NOT NULL CHECK (tipo_almacen IN ('PRINCIPAL', 'GENERAL', 'DESPACHO')),
    estado       VARCHAR(10) NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    UNIQUE (id_sede, nombre)
);

CREATE TABLE catalogo.categorias (
    id_categoria INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(60)  NOT NULL UNIQUE,
    descripcion  VARCHAR(200),
    estado       VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- sku unico, una categoria y un estado (RN-03). precio_lista es el
-- precio vigente; cada venta guarda su propio precio en el detalle
-- (RN-27), asi cambiar este valor no altera el historico.
CREATE TABLE catalogo.productos (
    id_producto   INTEGER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku           VARCHAR(20)   NOT NULL UNIQUE,
    nombre        VARCHAR(100)  NOT NULL,
    id_categoria  INTEGER       NOT NULL REFERENCES catalogo.categorias (id_categoria),
    unidad_medida VARCHAR(10)   NOT NULL CHECK (unidad_medida IN ('UND', 'CAJA', 'PAQUETE', 'BOTELLA', 'KG')),
    precio_lista  NUMERIC(14,2) NOT NULL CHECK (precio_lista > 0),
    estado        VARCHAR(15)   NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO', 'DESCONTINUADO'))
);

CREATE TABLE catalogo.proveedores (
    id_proveedor   INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    identificacion VARCHAR(20)  NOT NULL UNIQUE,
    razon_social   VARCHAR(100) NOT NULL,
    ciudad         VARCHAR(60)  NOT NULL,
    correo         VARCHAR(100) NOT NULL,
    telefono       VARCHAR(20),
    estado         VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- un producto puede tener varios proveedores y un proveedor vende
-- varios productos (N:M, RN-05). esta tabla guarda cada pareja una
-- sola vez. costo y plazo son de la pareja: el mismo producto puede
-- costar distinto segun quien lo venda.
CREATE TABLE catalogo.producto_proveedor (
    id_producto        INTEGER       NOT NULL REFERENCES catalogo.productos (id_producto),
    id_proveedor       INTEGER       NOT NULL REFERENCES catalogo.proveedores (id_proveedor),
    costo_referencia   NUMERIC(14,2) NOT NULL CHECK (costo_referencia > 0),
    plazo_entrega_dias INTEGER       NOT NULL CHECK (plazo_entrega_dias >= 0),
    PRIMARY KEY (id_producto, id_proveedor)
);

-- los clientes son de toda la empresa, no de una sede (S-04).
-- un documento es unico por tipo: UNIQUE (tipo_documento, num_documento).
CREATE TABLE catalogo.clientes (
    id_cliente      INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo_documento  VARCHAR(10)  NOT NULL CHECK (tipo_documento IN ('CC', 'CE', 'NIT', 'PASAPORTE')),
    num_documento   VARCHAR(20)  NOT NULL,
    nombre_completo VARCHAR(120) NOT NULL,
    correo          VARCHAR(100),
    telefono        VARCHAR(20),
    estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    UNIQUE (tipo_documento, num_documento)
);

-- cada tabla registra que microservicio es su responsable (requerimiento 18)
COMMENT ON TABLE catalogo.sedes              IS 'Responsable: Catalogo y Terceros';
COMMENT ON TABLE catalogo.almacenes          IS 'Responsable: Catalogo y Terceros';
COMMENT ON TABLE catalogo.categorias         IS 'Responsable: Catalogo y Terceros';
COMMENT ON TABLE catalogo.productos          IS 'Responsable: Catalogo y Terceros';
COMMENT ON TABLE catalogo.proveedores        IS 'Responsable: Catalogo y Terceros';
COMMENT ON TABLE catalogo.producto_proveedor IS 'Responsable: Catalogo y Terceros';
COMMENT ON TABLE catalogo.clientes           IS 'Responsable: Catalogo y Terceros';
