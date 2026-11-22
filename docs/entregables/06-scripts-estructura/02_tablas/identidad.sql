-- 02_tablas/identidad.sql
-- identidad y accesos (base andina_identidad). ver README.md.
-- "ref:" = id de otra base, sin FK.

CREATE SCHEMA identidad;
COMMENT ON SCHEMA identidad IS 'Microservicio de Identidad y Accesos';

-- cada empleado trabaja en una sede (RN-35, S-03)
CREATE TABLE identidad.empleados (
    id_empleado     INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede         INTEGER      NOT NULL,              -- ref: catalogo.sedes
    num_documento   VARCHAR(20)  NOT NULL UNIQUE,
    nombre_completo VARCHAR(120) NOT NULL,
    cargo           VARCHAR(30)  NOT NULL CHECK (cargo IN ('ADMINISTRADOR', 'GERENTE', 'JEFE_INVENTARIO',
                                                           'COMPRADOR', 'VENDEDOR', 'AUDITOR', 'BODEGUERO')),
    correo          VARCHAR(100) NOT NULL UNIQUE,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

-- FK + UNIQUE en id_empleado = relacion 1:1 con empleados (RN-36)
CREATE TABLE identidad.usuarios (
    id_usuario     INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empleado    INTEGER      NOT NULL UNIQUE REFERENCES identidad.empleados (id_empleado),
    nombre_usuario VARCHAR(40)  NOT NULL UNIQUE,
    password_hash  VARCHAR(100) NOT NULL,
    rol            VARCHAR(15)  NOT NULL CHECK (rol IN ('ADMINISTRADOR', 'GERENCIA', 'INVENTARIO',
                                                         'COMPRAS', 'VENDEDOR', 'AUDITOR')),
    estado         VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'BLOQUEADO', 'INACTIVO')),
    fecha_creacion TIMESTAMP    NOT NULL DEFAULT now()
);

-- quien hizo que y cuando (RN-38)
CREATE TABLE identidad.auditoria_accesos (
    id_auditoria      INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario        INTEGER      NOT NULL REFERENCES identidad.usuarios (id_usuario),
    fecha_hora        TIMESTAMP    NOT NULL DEFAULT now(),
    accion            VARCHAR(10)  NOT NULL CHECK (accion IN ('LOGIN', 'LOGOUT', 'SELECT', 'INSERT', 'UPDATE', 'DELETE')),
    objeto_consultado VARCHAR(100) NOT NULL
);

COMMENT ON TABLE identidad.empleados         IS 'Responsable: Identidad y Accesos';
COMMENT ON TABLE identidad.usuarios          IS 'Responsable: Identidad y Accesos';
COMMENT ON TABLE identidad.auditoria_accesos IS 'Responsable: Identidad y Accesos';
