-- 04_datos/identidad.sql
-- datos de prueba de identidad (base andina_identidad). ver README.md.

-- semilla fija: el "azar" sale siempre igual
SELECT setseed(0.2026);

-- vendedores: 3-5 bogota, 8-10 medellin, 12-14 cali, 18-19 CEDI
INSERT INTO identidad.empleados (id_sede, num_documento, nombre_completo, cargo, correo) VALUES
    (1, '79100001', 'Ricardo Acosta Peña',      'ADMINISTRADOR',   'racosta@andina.co'),
    (1, '52100002', 'Mónica Salazar Ríos',      'GERENTE',         'msalazar@andina.co'),
    (1, '80100003', 'Julián Cárdenas Mora',     'VENDEDOR',        'jcardenas@andina.co'),
    (1, '52100004', 'Diana Patiño Leal',        'VENDEDOR',        'dpatino@andina.co'),
    (1, '10100005', 'Óscar Beltrán Niño',       'VENDEDOR',        'obeltran@andina.co'),
    (1, '52100006', 'Adriana Quintero Gil',     'JEFE_INVENTARIO', 'aquintero@andina.co'),
    (2, '71100007', 'Hernán Restrepo Úsuga',    'JEFE_INVENTARIO', 'hrestrepo@andina.co'),
    (2, '43100008', 'Catalina Ochoa Mejía',     'VENDEDOR',        'cochoa@andina.co'),
    (2, '71100009', 'Esteban Zapata Arango',    'VENDEDOR',        'ezapata@andina.co'),
    (2, '43100010', 'Marcela Henao Vélez',      'VENDEDOR',        'mhenao@andina.co'),
    (3, '16100011', 'Fernando Caicedo Lasso',   'JEFE_INVENTARIO', 'fcaicedo@andina.co'),
    (3, '31100012', 'Liliana Mosquera Rivas',   'VENDEDOR',        'lmosquera@andina.co'),
    (3, '16100013', 'Gustavo Valencia Cuero',   'VENDEDOR',        'gvalencia@andina.co'),
    (3, '31100014', 'Yolanda Ibarra Paz',       'VENDEDOR',        'yibarra@andina.co'),
    (4, '80100015', 'Mauricio Rincón Suárez',   'JEFE_INVENTARIO', 'mrincon@andina.co'),
    (4, '52100016', 'Sandra Forero Vega',       'COMPRADOR',       'sforero@andina.co'),
    (4, '80100017', 'Iván Castañeda Ruiz',      'COMPRADOR',       'icastaneda@andina.co'),
    (4, '10100018', 'Pedro Galindo Rey',        'VENDEDOR',        'pgalindo@andina.co'),
    (4, '52100019', 'Gloria Barrera Pinzón',    'VENDEDOR',        'gbarrera@andina.co'),
    (1, '79100020', 'Tomás Villamil Ortega',    'AUDITOR',         'tvillamil@andina.co');

-- 12 de los 20 empleados tienen usuario. md5 = hash de ejemplo (S-12)
INSERT INTO identidad.usuarios (id_empleado, nombre_usuario, password_hash, rol, fecha_creacion)
SELECT u.emp, u.usr, md5(u.usr || '2026'), u.rol, TIMESTAMP '2026-04-20 08:00' + u.id * INTERVAL '1 hour'
FROM (VALUES
    ( 1,  1, 'admin_andina',        'ADMINISTRADOR'),
    ( 2,  2, 'gerente_general',     'GERENCIA'),
    ( 3,  6, 'inventario_bogota',   'INVENTARIO'),
    ( 4,  7, 'inventario_medellin', 'INVENTARIO'),
    ( 5, 11, 'inventario_cali',     'INVENTARIO'),
    ( 6, 15, 'inventario_cedi',     'INVENTARIO'),
    ( 7, 16, 'compras_cedi',        'COMPRAS'),
    ( 8,  3, 'vendedor_bogota',     'VENDEDOR'),
    ( 9,  8, 'vendedor_medellin',   'VENDEDOR'),
    (10, 12, 'vendedor_cali',       'VENDEDOR'),
    (11, 18, 'vendedor_cedi',       'VENDEDOR'),
    (12, 20, 'auditor_interno',     'AUDITOR')
) AS u(id, emp, usr, rol)
ORDER BY u.id;

-- 60 accesos al azar en el periodo
INSERT INTO identidad.auditoria_accesos (id_usuario, fecha_hora, accion, objeto_consultado)
SELECT 1 + floor(random() * 12)::int,
       TIMESTAMP '2026-05-01 07:00' + (random() * 167) * INTERVAL '1 day',
       (ARRAY['LOGIN', 'SELECT', 'SELECT', 'INSERT', 'UPDATE', 'LOGOUT'])[1 + floor(random() * 6)::int],
       (ARRAY['reportes.vista_reporte_corporativo', 'ventas.ped_bogota', 'inventarios.inv_cedi',
              'compras.ordenes_compra', 'ventas.pagos', 'catalogo.productos'])[1 + floor(random() * 6)::int]
FROM generate_series(1, 60);
