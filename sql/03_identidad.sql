-- =====================================================================
-- 03_identidad.sql
-- Microservicio de Identidad y Accesos: empleados, usuarios y auditoría.
-- id_sede en empleados es un identificador compartido (sin FK) hacia
-- catalogo.sedes.
-- =====================================================================

CREATE TABLE identidad.empleados (
    id_empleado     INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_sede         INTEGER      NOT NULL,              -- † catalogo.sedes
    num_documento   VARCHAR(20)  NOT NULL UNIQUE,
    nombre_completo VARCHAR(120) NOT NULL,
    cargo           VARCHAR(30)  NOT NULL CHECK (cargo IN ('ADMINISTRADOR', 'GERENTE', 'JEFE_INVENTARIO',
                                                           'COMPRADOR', 'VENDEDOR', 'AUDITOR', 'BODEGUERO')),
    correo          VARCHAR(100) NOT NULL UNIQUE,
    estado          VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'INACTIVO'))
);

CREATE TABLE identidad.usuarios (
    id_usuario     INTEGER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empleado    INTEGER      NOT NULL UNIQUE REFERENCES identidad.empleados (id_empleado),  -- 1:1 (RN-36)
    nombre_usuario VARCHAR(40)  NOT NULL UNIQUE,
    password_hash  VARCHAR(100) NOT NULL,
    rol            VARCHAR(15)  NOT NULL CHECK (rol IN ('ADMINISTRADOR', 'GERENCIA', 'INVENTARIO',
                                                         'COMPRAS', 'VENDEDOR', 'AUDITOR')),
    estado         VARCHAR(10)  NOT NULL DEFAULT 'ACTIVO' CHECK (estado IN ('ACTIVO', 'BLOQUEADO', 'INACTIVO')),
    fecha_creacion TIMESTAMP    NOT NULL DEFAULT now()
);

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
