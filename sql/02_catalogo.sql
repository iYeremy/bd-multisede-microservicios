-- =====================================================================
-- 02_catalogo.sql
-- Microservicio de Catálogo y Terceros: 7 tablas de datos maestros.
-- Todas las FK de este esquema son locales.
-- =====================================================================

CREATE TABLE catalogo.sedes (
    id_sede     INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(60)  NOT NULL UNIQUE,
    ciudad      VARCHAR(60)  NOT NULL,
    direccion   VARCHAR(120) NOT NULL,
    tipo_sede   VARCHAR(15)  NOT NULL CHECK (tipo_sede IN ('VENTA', 'DISTRIBUCION')),
    estado      VARCHAR(10)  NOT NULL DEFAULT 'ACTIVA' CHECK (estado IN ('ACTIVA', 'INACTIVA'))
);

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

-- Relación N:M producto–proveedor (RN-05)
CREATE TABLE catalogo.producto_proveedor (
    id_producto        INTEGER       NOT NULL REFERENCES catalogo.productos (id_producto),
    id_proveedor       INTEGER       NOT NULL REFERENCES catalogo.proveedores (id_proveedor),
    costo_referencia   NUMERIC(14,2) NOT NULL CHECK (costo_referencia > 0),
    plazo_entrega_dias INTEGER       NOT NULL CHECK (plazo_entrega_dias >= 0),
    PRIMARY KEY (id_producto, id_proveedor)
);

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

CREATE INDEX idx_almacenes_sede      ON catalogo.almacenes (id_sede);
CREATE INDEX idx_productos_categoria ON catalogo.productos (id_categoria);
CREATE INDEX idx_prod_prov_proveedor ON catalogo.producto_proveedor (id_proveedor);

COMMENT ON TABLE catalogo.sedes              IS 'Responsable: Catálogo y Terceros';
COMMENT ON TABLE catalogo.almacenes          IS 'Responsable: Catálogo y Terceros';
COMMENT ON TABLE catalogo.categorias         IS 'Responsable: Catálogo y Terceros';
COMMENT ON TABLE catalogo.productos          IS 'Responsable: Catálogo y Terceros';
COMMENT ON TABLE catalogo.proveedores        IS 'Responsable: Catálogo y Terceros';
COMMENT ON TABLE catalogo.producto_proveedor IS 'Responsable: Catálogo y Terceros';
COMMENT ON TABLE catalogo.clientes           IS 'Responsable: Catálogo y Terceros';
