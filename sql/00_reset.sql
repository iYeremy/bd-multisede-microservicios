-- =====================================================================
-- 00_reset.sql
-- Borra los esquemas y los roles del proyecto para empezar desde cero.
-- Ejecutar conectado a la base del proyecto (comercializadora) con un
-- usuario superusuario (postgres).
-- =====================================================================

DROP SCHEMA IF EXISTS reportes    CASCADE;
DROP SCHEMA IF EXISTS ventas      CASCADE;
DROP SCHEMA IF EXISTS inventarios CASCADE;
DROP SCHEMA IF EXISTS compras     CASCADE;
DROP SCHEMA IF EXISTS identidad   CASCADE;
DROP SCHEMA IF EXISTS catalogo    CASCADE;

-- Los roles son globales del clúster: antes de borrarlos se eliminan sus
-- privilegios en esta base (DROP OWNED BY) para que DROP ROLE no falle.
DO $$
DECLARE
    r text;
BEGIN
    FOREACH r IN ARRAY ARRAY[
        -- usuarios (LOGIN)
        'admin_andina', 'gerente_general', 'inventario_bogota', 'inventario_cedi',
        'compras_cedi', 'vendedor_bogota', 'vendedor_cali', 'auditor_interno',
        -- roles de grupo (NOLOGIN)
        'rol_administrador', 'rol_gerencia', 'rol_inventario',
        'rol_compras', 'rol_vendedor', 'rol_auditor'
    ]
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('DROP OWNED BY %I', r);
            EXECUTE format('DROP ROLE %I', r);
        END IF;
    END LOOP;
END $$;
