-- =====================================================================
-- etl/staging.sql
-- prepara andina_reportes para recibir el ETL. se corre conectado a
-- andina_reportes, justo despues de 02 a 06 (que crearon ahi las mismas
-- tablas de cada servicio).
--
-- staging = el lugar donde el ETL deja los datos crudos de cada servicio
-- antes de transformarlos. en reportes son los esquemas catalogo,
-- identidad, compras, inventarios y ventas. tienen las mismas tablas y
-- restricciones que el original (por eso se reusan los scripts 02 a 06)
-- y asi las vistas y consultas usan los mismos nombres.
-- =====================================================================

-- 03_identidad.sql crea 3 tablas, pero reportes solo necesita empleados.
-- usuarios y auditoria_accesos se borran del staging: ahi van las
-- contrasenas y eso no sale de su servicio.
DROP TABLE identidad.auditoria_accesos, identidad.usuarios;

-- se marca cada esquema como staging, para que no se confunda con la
-- base original del servicio (se ve con \dn+)
COMMENT ON SCHEMA catalogo    IS 'Staging del ETL: copia de andina_catalogo';
COMMENT ON SCHEMA identidad   IS 'Staging del ETL: copia de andina_identidad (solo empleados)';
COMMENT ON SCHEMA compras     IS 'Staging del ETL: copia de andina_compras';
COMMENT ON SCHEMA inventarios IS 'Staging del ETL: copia de andina_inventarios';
COMMENT ON SCHEMA ventas      IS 'Staging del ETL: copia de andina_ventas';

-- ---------------------------------------------------------------------
-- control de cargas
-- cada vez que corre cargar.sql se guarda una fila por tabla: cuantas
-- filas habia en el origen y cuantas quedaron en el staging. sirve para
-- saber de cuando son los datos de los reportes y para comprobar que la
-- copia es fiel.
-- va en un esquema aparte (etl) para que el esquema reportes siga
-- teniendo solo vistas.
-- ---------------------------------------------------------------------
CREATE SCHEMA etl;
COMMENT ON SCHEMA etl IS 'Control del ETL de reportes';

CREATE TABLE etl.cargas (
    id_carga      INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_carga   TIMESTAMP   NOT NULL,
    tabla         VARCHAR(60) NOT NULL,
    filas_origen  INTEGER     NOT NULL CHECK (filas_origen >= 0),
    filas_staging INTEGER     NOT NULL CHECK (filas_staging >= 0),
    -- si no cuadra, el INSERT falla y la carga completa se deshace.
    -- CONSTRAINT le pone nombre, asi el error dice cual fue
    CONSTRAINT carga_cuadra CHECK (filas_origen = filas_staging),
    UNIQUE (fecha_carga, tabla)
);

COMMENT ON TABLE etl.cargas IS 'Responsable: Reportes Corporativos. Una fila por tabla en cada carga del ETL';
