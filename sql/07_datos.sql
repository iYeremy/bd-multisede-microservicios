-- =====================================================================
-- 07_datos.sql
-- Datos de prueba sintéticos y reproducibles (semilla fija).
-- Periodo: 1 de mayo al 15 de octubre de 2026. Fecha de corte: 2026-10-15.
--
-- Escenarios que se garantizan a propósito:
--   * Productos que nunca se venden ........ 19, 35, 53, 70, 78
--   * Productos sin ventas desde julio ..... 12, 27, 44, 58, 75 (baja rotación)
--   * Productos descontinuados / inactivos . 39, 80 / 64
--   * Proveedores con retrasos ............. 3 y 7
--   * Huecos de surtido: Bogotá no tiene los múltiplos de 9, Medellín los
--     de 7 y Cali los de 5.
--   * Pedidos con pagos parciales, pedidos pendientes antiguos, compras
--     parciales, transferencias en tránsito y con diferencias.
-- =====================================================================

SELECT setseed(0.2026);

-- ---------------------------------------------------------------------
-- CATÁLOGO
-- ---------------------------------------------------------------------
INSERT INTO catalogo.sedes (id_sede, nombre, ciudad, direccion, tipo_sede) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Sede Bogotá',   'Bogotá',   'Calle 72 # 10-34',          'VENTA'),
    (2, 'Sede Medellín', 'Medellín', 'Carrera 43A # 1-50',        'VENTA'),
    (3, 'Sede Cali',     'Cali',     'Avenida 6N # 23-45',        'VENTA'),
    (4, 'CEDI Funza',    'Funza',    'Parque Industrial km 2 vía Funza', 'DISTRIBUCION');

INSERT INTO catalogo.almacenes (id_almacen, id_sede, nombre, tipo_almacen) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'Almacén Bogotá',           'PRINCIPAL'),
    (2, 2, 'Almacén Medellín',         'PRINCIPAL'),
    (3, 3, 'Almacén Cali',             'PRINCIPAL'),
    (4, 4, 'Bodega general CEDI',      'GENERAL'),
    (5, 4, 'Bodega de despacho CEDI',  'DESPACHO');

INSERT INTO catalogo.categorias (id_categoria, nombre, descripcion) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Alimentos',           'Abarrotes y alimentos no perecederos'),
    (2, 'Bebidas',             'Bebidas no alcohólicas y alcohólicas'),
    (3, 'Aseo personal',       'Productos de higiene y cuidado personal'),
    (4, 'Limpieza del hogar',  'Detergentes, desinfectantes y accesorios'),
    (5, 'Papelería y oficina', 'Útiles escolares y de oficina');

INSERT INTO catalogo.productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado) OVERRIDING SYSTEM VALUE VALUES
    ( 1, 'ALI-001', 'Arroz blanco 1 kg',              1, 'KG',       4800, 'ACTIVO'),
    ( 2, 'ALI-002', 'Azúcar refinada 1 kg',           1, 'KG',       4200, 'ACTIVO'),
    ( 3, 'ALI-003', 'Aceite vegetal 1 L',             1, 'BOTELLA', 11500, 'ACTIVO'),
    ( 4, 'ALI-004', 'Pasta spaghetti 500 g',          1, 'PAQUETE',  3600, 'ACTIVO'),
    ( 5, 'ALI-005', 'Lenteja 500 g',                  1, 'PAQUETE',  4100, 'ACTIVO'),
    ( 6, 'ALI-006', 'Fríjol rojo 500 g',              1, 'PAQUETE',  6200, 'ACTIVO'),
    ( 7, 'ALI-007', 'Café molido 500 g',              1, 'PAQUETE', 18900, 'ACTIVO'),
    ( 8, 'ALI-008', 'Chocolate de mesa 500 g',        1, 'PAQUETE',  9800, 'ACTIVO'),
    ( 9, 'ALI-009', 'Atún en lata 170 g',             1, 'UND',      6900, 'ACTIVO'),
    (10, 'ALI-010', 'Harina de maíz 1 kg',            1, 'KG',       3900, 'ACTIVO'),
    (11, 'ALI-011', 'Sal refinada 1 kg',              1, 'KG',       2300, 'ACTIVO'),
    (12, 'ALI-012', 'Avena en hojuelas 500 g',        1, 'PAQUETE',  5400, 'ACTIVO'),
    (13, 'ALI-013', 'Galletas de soda x6',            1, 'PAQUETE',  4700, 'ACTIVO'),
    (14, 'ALI-014', 'Panela 1 kg',                    1, 'KG',       4500, 'ACTIVO'),
    (15, 'ALI-015', 'Salsa de tomate 400 g',          1, 'UND',      5600, 'ACTIVO'),
    (16, 'ALI-016', 'Mayonesa 400 g',                 1, 'UND',      7900, 'ACTIVO'),
    (17, 'BEB-001', 'Agua sin gas 600 ml',            2, 'BOTELLA',  1800, 'ACTIVO'),
    (18, 'BEB-002', 'Gaseosa cola 1.5 L',             2, 'BOTELLA',  5200, 'ACTIVO'),
    (19, 'BEB-003', 'Gaseosa naranja 1.5 L',          2, 'BOTELLA',  5000, 'ACTIVO'),
    (20, 'BEB-004', 'Jugo de mango 1 L',              2, 'BOTELLA',  4900, 'ACTIVO'),
    (21, 'BEB-005', 'Jugo de naranja 1 L',            2, 'BOTELLA',  5300, 'ACTIVO'),
    (22, 'BEB-006', 'Té helado limón 500 ml',         2, 'BOTELLA',  3200, 'ACTIVO'),
    (23, 'BEB-007', 'Bebida energizante 250 ml',      2, 'UND',      4800, 'ACTIVO'),
    (24, 'BEB-008', 'Cerveza lager six pack',         2, 'PAQUETE', 16500, 'ACTIVO'),
    (25, 'BEB-009', 'Agua con gas 600 ml',            2, 'BOTELLA',  2100, 'ACTIVO'),
    (26, 'BEB-010', 'Leche entera 1 L',               2, 'UND',      4300, 'ACTIVO'),
    (27, 'BEB-011', 'Kumis 1 L',                      2, 'UND',      5900, 'ACTIVO'),
    (28, 'BEB-012', 'Bebida de soya 1 L',             2, 'UND',      7200, 'ACTIVO'),
    (29, 'BEB-013', 'Malta 330 ml',                   2, 'UND',      2400, 'ACTIVO'),
    (30, 'BEB-014', 'Bebida hidratante 500 ml',       2, 'BOTELLA',  3900, 'ACTIVO'),
    (31, 'BEB-015', 'Café listo para tomar 250 ml',   2, 'UND',      4600, 'ACTIVO'),
    (32, 'BEB-016', 'Vino tinto 750 ml',              2, 'BOTELLA', 38000, 'ACTIVO'),
    (33, 'ASE-001', 'Jabón de tocador x3',            3, 'PAQUETE',  7800, 'ACTIVO'),
    (34, 'ASE-002', 'Shampoo 400 ml',                 3, 'BOTELLA', 16900, 'ACTIVO'),
    (35, 'ASE-003', 'Acondicionador 400 ml',          3, 'BOTELLA', 17500, 'ACTIVO'),
    (36, 'ASE-004', 'Crema dental 100 ml',            3, 'UND',      6200, 'ACTIVO'),
    (37, 'ASE-005', 'Cepillo dental',                 3, 'UND',      5500, 'ACTIVO'),
    (38, 'ASE-006', 'Desodorante roll-on',            3, 'UND',     13900, 'ACTIVO'),
    (39, 'ASE-007', 'Talco para pies 120 g',          3, 'UND',      8900, 'DESCONTINUADO'),
    (40, 'ASE-008', 'Papel higiénico x12',            3, 'PAQUETE', 22500, 'ACTIVO'),
    (41, 'ASE-009', 'Toallas húmedas x50',            3, 'PAQUETE',  8700, 'ACTIVO'),
    (42, 'ASE-010', 'Enjuague bucal 500 ml',          3, 'BOTELLA', 15800, 'ACTIVO'),
    (43, 'ASE-011', 'Crema corporal 400 ml',          3, 'BOTELLA', 19900, 'ACTIVO'),
    (44, 'ASE-012', 'Máquina de afeitar x3',          3, 'PAQUETE', 12400, 'ACTIVO'),
    (45, 'ASE-013', 'Gel antibacterial 500 ml',       3, 'BOTELLA',  9900, 'ACTIVO'),
    (46, 'ASE-014', 'Protector solar 120 ml',         3, 'UND',     32900, 'ACTIVO'),
    (47, 'ASE-015', 'Toallas higiénicas x10',         3, 'PAQUETE',  6800, 'ACTIVO'),
    (48, 'ASE-016', 'Pañales etapa 3 x30',            3, 'PAQUETE', 45900, 'ACTIVO'),
    (49, 'LIM-001', 'Detergente en polvo 1 kg',       4, 'KG',      14500, 'ACTIVO'),
    (50, 'LIM-002', 'Suavizante 1 L',                 4, 'BOTELLA', 11900, 'ACTIVO'),
    (51, 'LIM-003', 'Blanqueador 1 L',                4, 'BOTELLA',  5800, 'ACTIVO'),
    (52, 'LIM-004', 'Lavaloza líquido 500 ml',        4, 'BOTELLA',  7600, 'ACTIVO'),
    (53, 'LIM-005', 'Limpiavidrios 500 ml',           4, 'BOTELLA',  8900, 'ACTIVO'),
    (54, 'LIM-006', 'Desinfectante multiusos 1 L',    4, 'BOTELLA',  9400, 'ACTIVO'),
    (55, 'LIM-007', 'Esponja de cocina x3',           4, 'PAQUETE',  4200, 'ACTIVO'),
    (56, 'LIM-008', 'Bolsas de basura x10',           4, 'PAQUETE',  5900, 'ACTIVO'),
    (57, 'LIM-009', 'Escoba plástica',                4, 'UND',     12900, 'ACTIVO'),
    (58, 'LIM-010', 'Trapero de algodón',             4, 'UND',     14900, 'ACTIVO'),
    (59, 'LIM-011', 'Guantes de caucho',              4, 'UND',      6300, 'ACTIVO'),
    (60, 'LIM-012', 'Ambientador en aerosol',         4, 'UND',     10900, 'ACTIVO'),
    (61, 'LIM-013', 'Jabón en barra para ropa x3',    4, 'PAQUETE',  6900, 'ACTIVO'),
    (62, 'LIM-014', 'Toallas de cocina x3',           4, 'PAQUETE', 10500, 'ACTIVO'),
    (63, 'LIM-015', 'Insecticida en aerosol',         4, 'UND',     16800, 'ACTIVO'),
    (64, 'LIM-016', 'Cera para pisos 1 L',            4, 'BOTELLA', 13500, 'INACTIVO'),
    (65, 'PAP-001', 'Cuaderno cuadriculado 100 h',    5, 'UND',      6500, 'ACTIVO'),
    (66, 'PAP-002', 'Resma papel carta',              5, 'PAQUETE', 21900, 'ACTIVO'),
    (67, 'PAP-003', 'Bolígrafo negro x12',            5, 'CAJA',    14400, 'ACTIVO'),
    (68, 'PAP-004', 'Lápiz grafito x12',              5, 'CAJA',     9600, 'ACTIVO'),
    (69, 'PAP-005', 'Borrador de nata x5',            5, 'PAQUETE',  4500, 'ACTIVO'),
    (70, 'PAP-006', 'Carpeta legajadora',             5, 'UND',      2800, 'ACTIVO'),
    (71, 'PAP-007', 'Marcador permanente x4',         5, 'PAQUETE', 11200, 'ACTIVO'),
    (72, 'PAP-008', 'Resaltador x4',                  5, 'PAQUETE',  9900, 'ACTIVO'),
    (73, 'PAP-009', 'Cinta adhesiva transparente',    5, 'UND',      3500, 'ACTIVO'),
    (74, 'PAP-010', 'Pegante en barra 40 g',          5, 'UND',      5200, 'ACTIVO'),
    (75, 'PAP-011', 'Tijeras escolares',              5, 'UND',      4900, 'ACTIVO'),
    (76, 'PAP-012', 'Colores x24',                    5, 'CAJA',    18500, 'ACTIVO'),
    (77, 'PAP-013', 'Calculadora básica',             5, 'UND',     24900, 'ACTIVO'),
    (78, 'PAP-014', 'Grapadora metálica',             5, 'UND',     19800, 'ACTIVO'),
    (79, 'PAP-015', 'Notas adhesivas x5',             5, 'PAQUETE',  8400, 'ACTIVO'),
    (80, 'PAP-016', 'Disquete 3.5" x10',              5, 'CAJA',    15000, 'DESCONTINUADO');

INSERT INTO catalogo.proveedores (id_proveedor, identificacion, razon_social, ciudad, correo, telefono) OVERRIDING SYSTEM VALUE VALUES
    ( 1, '900111001-1', 'Alimentos del Valle S.A.S.',       'Cali',         'ventas@alimvalle.co',      '6023334455'),
    ( 2, '900111002-2', 'Distribuidora La Sabana Ltda.',    'Bogotá',       'pedidos@lasabana.co',      '6017778899'),
    ( 3, '900111003-3', 'Bebidas Andinas S.A.',             'Medellín',     'comercial@bebandinas.co',  '6045556677'),
    ( 4, '900111004-4', 'Higiene Total S.A.S.',             'Bogotá',       'contacto@higienetotal.co', '6012223344'),
    ( 5, '900111005-5', 'Químicos del Caribe S.A.',         'Barranquilla', 'ventas@quimcaribe.co',     '6053332211'),
    ( 6, '900111006-6', 'Papelera Nacional S.A.S.',         'Bogotá',       'ventas@papelnal.co',       '6019998877'),
    ( 7, '900111007-7', 'Importadora El Puerto Ltda.',      'Cartagena',    'import@elpuerto.co',       '6056665544'),
    ( 8, '900111008-8', 'Granos y Cereales del Huila S.A.', 'Neiva',        'granos@cerhuila.co',       '6088887766'),
    ( 9, '900111009-9', 'Lácteos de la Montaña S.A.S.',     'Manizales',    'ventas@lacmontana.co',     '6064443322'),
    (10, '900111010-0', 'Comercial Santander Ltda.',        'Bucaramanga',  'info@comsantander.co',     '6071112233');

-- Cada producto tiene un proveedor principal y los pares un segundo proveedor.
INSERT INTO catalogo.producto_proveedor (id_producto, id_proveedor, costo_referencia, plazo_entrega_dias)
SELECT p.id_producto, ((p.id_producto - 1) % 10) + 1,
       round(p.precio_lista * 0.65, 0), 5 + ((((p.id_producto - 1) % 10) + 1) % 4) * 3
FROM catalogo.productos p
UNION ALL
SELECT p.id_producto, ((p.id_producto + 4) % 10) + 1,
       round(p.precio_lista * 0.68, 0), 5 + ((((p.id_producto + 4) % 10) + 1) % 4) * 3
FROM catalogo.productos p
WHERE p.id_producto % 2 = 0;

INSERT INTO catalogo.clientes (id_cliente, tipo_documento, num_documento, nombre_completo, correo, telefono, estado) OVERRIDING SYSTEM VALUE
SELECT i,
       CASE WHEN i % 10 = 0 THEN 'NIT' WHEN i % 23 = 0 THEN 'CE' ELSE 'CC' END,
       CASE WHEN i % 10 = 0 THEN (900200000 + i * 37)::text ELSE (1010200000 + i * 7919)::text END,
       CASE WHEN i % 10 = 0
            THEN (ARRAY['Distribuidora', 'Supermercado', 'Tienda', 'Minimercado', 'Droguería'])[1 + (i / 10) % 5]
                 || ' ' || (ARRAY['El Progreso', 'La Economía', 'San Jorge', 'Los Andes', 'La Esperanza',
                                  'El Ahorro', 'Santa Fe', 'La 80', 'El Vecino', 'Mi Barrio'])[i / 10] || ' S.A.S.'
            ELSE (ARRAY['Ana', 'Carlos', 'Luisa', 'Andrés', 'María', 'Jorge', 'Paula', 'Felipe', 'Laura', 'Diego',
                        'Camila', 'Juan', 'Valentina', 'Santiago', 'Daniela', 'Mateo', 'Sofía', 'Sebastián', 'Natalia', 'David'])[1 + i % 20]
                 || ' ' || (ARRAY['Gómez', 'Rodríguez', 'Martínez', 'López', 'García', 'Pérez', 'Sánchez', 'Ramírez', 'Torres', 'Díaz',
                                  'Vargas', 'Rojas', 'Moreno', 'Castro', 'Herrera', 'Jiménez', 'Ruiz', 'Mendoza', 'Ortiz', 'Silva'])[1 + (i * 3 + i / 20) % 20]
                 || ' ' || (ARRAY['Gómez', 'Rodríguez', 'Martínez', 'López', 'García', 'Pérez', 'Sánchez', 'Ramírez', 'Torres', 'Díaz',
                                  'Vargas', 'Rojas', 'Moreno', 'Castro', 'Herrera', 'Jiménez', 'Ruiz', 'Mendoza', 'Ortiz', 'Silva'])[1 + (i * 7 + i / 7) % 20]
       END,
       'cliente' || i || '@correo.co',
       '3' || lpad(((i * 104729) % 1000000000)::text, 9, '0'),
       CASE WHEN i IN (48, 97) THEN 'INACTIVO' ELSE 'ACTIVO' END
FROM generate_series(1, 100) AS i;

-- ---------------------------------------------------------------------
-- IDENTIDAD
-- ---------------------------------------------------------------------
INSERT INTO identidad.empleados (id_empleado, id_sede, num_documento, nombre_completo, cargo, correo) OVERRIDING SYSTEM VALUE VALUES
    ( 1, 1, '79100001', 'Ricardo Acosta Peña',      'ADMINISTRADOR',   'racosta@andina.co'),
    ( 2, 1, '52100002', 'Mónica Salazar Ríos',      'GERENTE',         'msalazar@andina.co'),
    ( 3, 1, '80100003', 'Julián Cárdenas Mora',     'VENDEDOR',        'jcardenas@andina.co'),
    ( 4, 1, '52100004', 'Diana Patiño Leal',        'VENDEDOR',        'dpatino@andina.co'),
    ( 5, 1, '10100005', 'Óscar Beltrán Niño',       'VENDEDOR',        'obeltran@andina.co'),
    ( 6, 1, '52100006', 'Adriana Quintero Gil',     'JEFE_INVENTARIO', 'aquintero@andina.co'),
    ( 7, 2, '71100007', 'Hernán Restrepo Úsuga',    'JEFE_INVENTARIO', 'hrestrepo@andina.co'),
    ( 8, 2, '43100008', 'Catalina Ochoa Mejía',     'VENDEDOR',        'cochoa@andina.co'),
    ( 9, 2, '71100009', 'Esteban Zapata Arango',    'VENDEDOR',        'ezapata@andina.co'),
    (10, 2, '43100010', 'Marcela Henao Vélez',      'VENDEDOR',        'mhenao@andina.co'),
    (11, 3, '16100011', 'Fernando Caicedo Lasso',   'JEFE_INVENTARIO', 'fcaicedo@andina.co'),
    (12, 3, '31100012', 'Liliana Mosquera Rivas',   'VENDEDOR',        'lmosquera@andina.co'),
    (13, 3, '16100013', 'Gustavo Valencia Cuero',   'VENDEDOR',        'gvalencia@andina.co'),
    (14, 3, '31100014', 'Yolanda Ibarra Paz',       'VENDEDOR',        'yibarra@andina.co'),
    (15, 4, '80100015', 'Mauricio Rincón Suárez',   'JEFE_INVENTARIO', 'mrincon@andina.co'),
    (16, 4, '52100016', 'Sandra Forero Vega',       'COMPRADOR',       'sforero@andina.co'),
    (17, 4, '80100017', 'Iván Castañeda Ruiz',      'COMPRADOR',       'icastaneda@andina.co'),
    (18, 4, '10100018', 'Pedro Galindo Rey',        'VENDEDOR',        'pgalindo@andina.co'),
    (19, 4, '52100019', 'Gloria Barrera Pinzón',    'VENDEDOR',        'gbarrera@andina.co'),
    (20, 1, '79100020', 'Tomás Villamil Ortega',    'AUDITOR',         'tvillamil@andina.co');

INSERT INTO identidad.usuarios (id_usuario, id_empleado, nombre_usuario, password_hash, rol, fecha_creacion) OVERRIDING SYSTEM VALUE
SELECT u.id, u.emp, u.usr, md5(u.usr || '2026'), u.rol, TIMESTAMP '2026-04-20 08:00' + u.id * INTERVAL '1 hour'
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
) AS u(id, emp, usr, rol);

INSERT INTO identidad.auditoria_accesos (id_usuario, fecha_hora, accion, objeto_consultado)
SELECT 1 + floor(random() * 12)::int,
       TIMESTAMP '2026-05-01 07:00' + (random() * 167) * INTERVAL '1 day',
       (ARRAY['LOGIN', 'SELECT', 'SELECT', 'INSERT', 'UPDATE', 'LOGOUT'])[1 + floor(random() * 6)::int],
       (ARRAY['reportes.vista_reporte_corporativo', 'ventas.pedidos_venta', 'inventarios.inventarios',
              'compras.ordenes_compra', 'ventas.pagos', 'catalogo.productos'])[1 + floor(random() * 6)::int]
FROM generate_series(1, 60);

-- ---------------------------------------------------------------------
-- INVENTARIOS (se insertan por la tabla padre; PostgreSQL enruta cada
-- fila al fragmento de su sede)
-- ---------------------------------------------------------------------
INSERT INTO inventarios.inventarios (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT a.id_sede, a.id_almacen, p.id_producto,
       CASE
           WHEN a.id_almacen = 4 THEN CASE WHEN x.r < 0.06 THEN floor(x.r2 * x.minimo)::int
                                           ELSE x.minimo + 50 + floor(x.r2 * 350)::int END
           WHEN a.id_almacen = 5 THEN floor(x.r2 * 60)::int
           WHEN x.r < 0.06 THEN 0
           WHEN x.r < 0.20 THEN floor(x.r2 * x.minimo)::int
           ELSE x.minimo + floor(x.r2 * 100)::int
       END,
       x.minimo,
       TIMESTAMP '2026-10-15 18:00' - floor(x.r2 * 20) * INTERVAL '1 day'
FROM catalogo.almacenes a
CROSS JOIN catalogo.productos p
CROSS JOIN LATERAL (
    SELECT random() AS r, random() AS r2,
           CASE a.id_almacen WHEN 4 THEN 40 + floor(random() * 41)::int
                             WHEN 5 THEN floor(random() * 11)::int
                             ELSE 10 + floor(random() * 21)::int END AS minimo,
           p.id_producto AS _correlacion
) x
WHERE (a.id_almacen = 1 AND p.id_producto % 9 <> 0)
   OR (a.id_almacen = 2 AND p.id_producto % 7 <> 0)
   OR (a.id_almacen = 3 AND p.id_producto % 5 <> 0)
   OR (a.id_almacen = 4 AND p.id_producto <> 80)
   OR (a.id_almacen = 5 AND p.id_producto <= 20);

-- Los productos sin rotación deben tener existencia positiva
UPDATE inventarios.inventarios
SET existencia_actual = stock_minimo + 25
WHERE id_producto IN (19, 35, 53, 70, 78, 12, 27, 44, 58, 75)
  AND existencia_actual = 0;

-- ---------------------------------------------------------------------
-- VENTAS: 300 pedidos (Bogotá 100, Medellín 80, Cali 70, CEDI 50)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_ped_base AS
SELECT s.id_sede, s.id_almacen,
       1 + floor(random() * 100)::int                                         AS id_cliente,
       s.vendedores[1 + floor(random() * array_length(s.vendedores, 1))::int] AS id_empleado,
       DATE '2026-05-01' + floor(random() * 168)::int                          AS fecha_pedido,
       random()                                                               AS r_estado,
       1 + floor(random() * 5)::int                                           AS nlineas
FROM (VALUES (1, 1, 100, ARRAY[3, 4, 5]),
             (2, 2,  80, ARRAY[8, 9, 10]),
             (3, 3,  70, ARRAY[12, 13, 14]),
             (4, 4,  50, ARRAY[18, 19])) AS s(id_sede, id_almacen, cant, vendedores)
CROSS JOIN LATERAL generate_series(1, s.cant) AS g(n);

-- Consecutivo por sede en orden cronológico y estado según antigüedad
CREATE TEMP TABLE tmp_ped AS
SELECT b.*,
       ROW_NUMBER() OVER (PARTITION BY b.id_sede ORDER BY b.fecha_pedido, b.id_cliente, b.r_estado)::int AS id_pedido,
       CASE
           WHEN b.r_estado < 0.05 THEN 'ANULADO'
           WHEN DATE '2026-10-15' - b.fecha_pedido > 30 THEN
               CASE WHEN b.r_estado < 0.09 THEN 'PENDIENTE' WHEN b.r_estado < 0.20 THEN 'CONFIRMADO' ELSE 'ENTREGADO' END
           WHEN DATE '2026-10-15' - b.fecha_pedido > 15 THEN
               CASE WHEN b.r_estado < 0.25 THEN 'PENDIENTE' WHEN b.r_estado < 0.55 THEN 'CONFIRMADO' ELSE 'ENTREGADO' END
           ELSE
               CASE WHEN b.r_estado < 0.55 THEN 'PENDIENTE' WHEN b.r_estado < 0.80 THEN 'CONFIRMADO' ELSE 'ENTREGADO' END
       END AS estado
FROM tmp_ped_base b;

INSERT INTO ventas.pedidos_venta (id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT id_sede, id_pedido, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, 0
FROM tmp_ped;

-- Detalles: productos distintos que existen en el almacén del pedido.
-- El precio se guarda en el detalle (antes de agosto la lista era 5 % menor).
INSERT INTO ventas.detalle_pedido (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT p.id_sede, p.id_pedido, x.id_producto,
       1 + floor(random() * CASE WHEN p.id_sede = 4 THEN 30 ELSE 8 END)::int,
       round(x.precio_lista * CASE WHEN p.fecha_pedido < DATE '2026-08-01' THEN 0.95 ELSE 1 END, 0)
FROM tmp_ped p
CROSS JOIN LATERAL (
    SELECT pr.id_producto, pr.precio_lista
    FROM catalogo.productos pr
    JOIN inventarios.inventarios i ON i.id_producto = pr.id_producto AND i.id_almacen = p.id_almacen
    WHERE pr.id_producto <> ALL (ARRAY[19, 35, 53, 70, 78])
      AND (p.fecha_pedido < DATE '2026-07-01'
           OR pr.id_producto <> ALL (ARRAY[12, 27, 44, 58, 75, 39, 64, 80]))
    ORDER BY random()
    LIMIT p.nlineas
) x;

UPDATE ventas.pedidos_venta pv
SET total_registrado = d.total
FROM (SELECT id_sede, id_pedido, SUM(cantidad * precio_unitario) AS total
      FROM ventas.detalle_pedido GROUP BY id_sede, id_pedido) d
WHERE pv.id_sede = d.id_sede AND pv.id_pedido = d.id_pedido;

SELECT setval('ventas.seq_ped_bogota',   (SELECT max(id_pedido) FROM ventas.ped_bogota));
SELECT setval('ventas.seq_ped_medellin', (SELECT max(id_pedido) FROM ventas.ped_medellin));
SELECT setval('ventas.seq_ped_cali',     (SELECT max(id_pedido) FROM ventas.ped_cali));
SELECT setval('ventas.seq_ped_cedi',     (SELECT max(id_pedido) FROM ventas.ped_cedi));

-- Pagos: entregados pagados (1 o 2 cuotas), confirmados con saldo en
-- algunos casos, pendientes con anticipo y anulados con pago rechazado.
CREATE TEMP TABLE tmp_pag AS
SELECT id_sede, id_pedido, fecha_pedido, estado, total_registrado AS total, random() AS r,
       (ARRAY['EFECTIVO', 'TARJETA_DEBITO', 'TARJETA_CREDITO', 'TRANSFERENCIA'])[1 + floor(random() * 4)::int] AS medio
FROM ventas.pedidos_venta;

INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT id_sede, id_pedido, LEAST(fecha_pedido + 1, DATE '2026-10-15'),
       CASE
           WHEN estado = 'ENTREGADO'  AND r < 0.3 THEN round(total / 2, 2)
           WHEN estado = 'ENTREGADO'              THEN total
           WHEN estado = 'CONFIRMADO' AND r < 0.4 THEN total
           WHEN estado = 'CONFIRMADO'             THEN round(total / 2, 2)
           WHEN estado = 'PENDIENTE'              THEN round(total * 0.3, 2)
           ELSE total
       END,
       medio,
       CASE WHEN estado = 'ANULADO' THEN 'RECHAZADO' ELSE 'CONFIRMADO' END
FROM tmp_pag
WHERE estado IN ('ENTREGADO', 'CONFIRMADO')
   OR (estado = 'PENDIENTE' AND r < 0.35)
   OR (estado = 'ANULADO'   AND r < 0.5);

INSERT INTO ventas.pagos (id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT id_sede, id_pedido, LEAST(fecha_pedido + 8, DATE '2026-10-15'),
       total - round(total / 2, 2), medio,
       CASE WHEN estado = 'ENTREGADO' THEN 'CONFIRMADO' ELSE 'PENDIENTE' END
FROM tmp_pag
WHERE (estado = 'ENTREGADO' AND r < 0.3)
   OR (estado = 'CONFIRMADO' AND r >= 0.7);

-- Devoluciones: 22 pedidos confirmados o entregados, 1 o 2 productos cada una
CREATE TEMP TABLE tmp_dev AS
SELECT (ROW_NUMBER() OVER ())::int AS id_devolucion, x.*
FROM (SELECT id_sede, id_pedido, fecha_pedido
      FROM ventas.pedidos_venta
      WHERE estado IN ('ENTREGADO', 'CONFIRMADO') AND fecha_pedido <= DATE '2026-10-10'
      ORDER BY random()
      LIMIT 22) x;

INSERT INTO ventas.devoluciones (id_devolucion, id_sede, id_pedido, fecha_solicitud, motivo, estado) OVERRIDING SYSTEM VALUE
SELECT id_devolucion, id_sede, id_pedido,
       LEAST(fecha_pedido + 2 + id_devolucion % 6, DATE '2026-10-15'),
       (ARRAY['Producto defectuoso', 'Empaque dañado', 'Producto equivocado',
              'Fecha de vencimiento próxima', 'Cliente insatisfecho'])[1 + id_devolucion % 5],
       CASE WHEN id_devolucion % 7 = 0 THEN 'RECHAZADA'
            WHEN id_devolucion % 5 = 0 THEN 'SOLICITADA'
            ELSE 'APROBADA' END
FROM tmp_dev;

INSERT INTO ventas.detalle_devolucion (id_devolucion, id_producto, cantidad, condicion_producto)
SELECT d.id_devolucion, dp.id_producto, GREATEST(1, dp.cantidad / 2),
       CASE WHEN d.id_devolucion % 3 = 0 THEN 'BUENO' ELSE 'AVERIADO' END
FROM tmp_dev d
CROSS JOIN LATERAL (
    SELECT id_producto, cantidad
    FROM ventas.detalle_pedido dp
    WHERE dp.id_sede = d.id_sede AND dp.id_pedido = d.id_pedido
    ORDER BY cantidad DESC, id_producto
    LIMIT 1 + d.id_devolucion % 2
) dp;

-- ---------------------------------------------------------------------
-- COMPRAS: 60 órdenes repartidas en el periodo
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_oc AS
SELECT o.*,
       o.fecha_orden + 5 + (o.id_proveedor % 4) * 3 AS fecha_estimada,
       CASE WHEN o.id_proveedor IN (3, 7) THEN 3 + o.id_orden_compra % 8   -- proveedores con retraso
            ELSE -2 + o.id_orden_compra % 4 END                            -- entre 2 días antes y 1 después
            AS retraso
FROM (SELECT i AS id_orden_compra,
             1 + (i * 7) % 10                                   AS id_proveedor,
             CASE WHEN i % 5 = 0 THEN 1 + (i / 5) % 3 ELSE 4 END AS id_almacen_destino,
             CASE WHEN i % 2 = 0 THEN 16 ELSE 17 END             AS id_empleado,
             DATE '2026-05-01' + ((i - 1) * 163) / 59            AS fecha_orden
      FROM generate_series(1, 60) AS i) o;

ALTER TABLE tmp_oc ADD COLUMN estado VARCHAR(10);
UPDATE tmp_oc SET estado = CASE
    WHEN id_orden_compra IN (17, 41)                                 THEN 'CANCELADA'
    WHEN fecha_estimada > DATE '2026-10-15' OR id_orden_compra = 50  THEN 'EMITIDA'
    WHEN id_orden_compra % 7 = 0 OR fecha_orden > DATE '2026-09-20'  THEN 'PARCIAL'
    ELSE 'RECIBIDA' END;

INSERT INTO compras.ordenes_compra (id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado) OVERRIDING SYSTEM VALUE
SELECT id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado
FROM tmp_oc;

INSERT INTO compras.detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
SELECT o.id_orden_compra, pp.id_producto,
       (2 + floor(random() * 10)::int) * 10,
       round(pp.costo_referencia * (0.97 + random() * 0.06)::numeric, 0)
FROM tmp_oc o
CROSS JOIN LATERAL (
    SELECT id_producto, costo_referencia
    FROM catalogo.producto_proveedor pp
    WHERE pp.id_proveedor = o.id_proveedor
    ORDER BY random()
    LIMIT 2 + o.id_orden_compra % 3
) pp;

-- Recepciones: las órdenes recibidas llegan en 1 o 2 entregas;
-- las parciales tienen una sola entrega con la mitad de lo pedido.
CREATE TEMP TABLE tmp_rec AS
SELECT (ROW_NUMBER() OVER (ORDER BY id_orden_compra, nro))::int AS id_recepcion, x.*
FROM (
    SELECT id_orden_compra, 1 AS nro, estado, (id_orden_compra % 3 = 0) AS dos_entregas,
           GREATEST(fecha_orden, LEAST(fecha_estimada + retraso
                    - CASE WHEN estado = 'RECIBIDA' AND id_orden_compra % 3 = 0 THEN 5 ELSE 0 END,
                    DATE '2026-10-15')) AS fecha_recepcion
    FROM tmp_oc WHERE estado IN ('RECIBIDA', 'PARCIAL')
    UNION ALL
    SELECT id_orden_compra, 2, estado, TRUE,
           GREATEST(fecha_orden, LEAST(fecha_estimada + retraso, DATE '2026-10-15'))
    FROM tmp_oc WHERE estado = 'RECIBIDA' AND id_orden_compra % 3 = 0
) x;

INSERT INTO compras.recepciones_compra (id_recepcion, id_orden_compra, fecha_recepcion, estado) OVERRIDING SYSTEM VALUE
SELECT id_recepcion, id_orden_compra, fecha_recepcion, 'REGISTRADA' FROM tmp_rec;

INSERT INTO compras.detalle_recepcion (id_recepcion, id_producto, cantidad_recibida)
SELECT r.id_recepcion, d.id_producto,
       CASE
           WHEN r.estado = 'PARCIAL'                   THEN d.cantidad_solicitada / 2
           WHEN NOT r.dos_entregas                     THEN d.cantidad_solicitada
           WHEN r.nro = 1                              THEN round(d.cantidad_solicitada * 0.6)::int
           ELSE d.cantidad_solicitada - round(d.cantidad_solicitada * 0.6)::int
       END
FROM tmp_rec r
JOIN compras.detalle_orden_compra d ON d.id_orden_compra = r.id_orden_compra;

-- ---------------------------------------------------------------------
-- TRANSFERENCIAS: 25 (la mayoría del CEDI hacia las sedes)
-- ---------------------------------------------------------------------
CREATE TEMP TABLE tmp_tr AS
SELECT t.*,
       CASE WHEN t.estado IN ('SOLICITADA', 'CANCELADA') THEN NULL
            ELSE t.fecha_solicitud + 1 + t.id_transferencia % 2 END AS fecha_despacho
FROM (SELECT i AS id_transferencia,
             CASE WHEN i % 6 = 0 THEN 1 ELSE 4 END           AS origen,
             CASE WHEN i % 6 = 0 THEN 2 ELSE 1 + i % 3 END   AS destino,
             DATE '2026-05-05' + ((i - 1) * 13) / 2          AS fecha_solicitud,
             CASE WHEN i IN (20, 22, 23, 24) THEN 'DESPACHADA'
                  WHEN i IN (21, 25)         THEN 'SOLICITADA'
                  WHEN i = 11                THEN 'CANCELADA'
                  ELSE 'RECIBIDA' END                        AS estado
      FROM generate_series(1, 25) AS i) t;

INSERT INTO inventarios.transferencias (id_transferencia, id_almacen_origen, id_almacen_destino,
                                        fecha_solicitud, fecha_despacho, fecha_recepcion, estado) OVERRIDING SYSTEM VALUE
SELECT id_transferencia, origen, destino, fecha_solicitud, fecha_despacho,
       CASE WHEN estado = 'RECIBIDA' THEN fecha_despacho + 2 + id_transferencia % 3 END,
       estado
FROM tmp_tr;

INSERT INTO inventarios.detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida)
SELECT x.id_transferencia, x.id_producto, x.enviada,
       CASE WHEN x.estado = 'RECIBIDA' THEN x.enviada END
FROM (
SELECT t.id_transferencia, t.estado, sel.id_producto, 10 + floor(random() * 40)::int AS enviada
FROM tmp_tr t
CROSS JOIN LATERAL (
    SELECT i.id_producto
    FROM inventarios.inventarios i
    WHERE i.id_almacen = t.origen AND i.existencia_actual > 0
    ORDER BY random()
    LIMIT 2 + t.id_transferencia % 3
) sel
) x;

-- Diferencias entre enviado y recibido en algunas transferencias recibidas
UPDATE inventarios.detalle_transferencia dt
SET cantidad_recibida = dt.cantidad_enviada - (1 + dt.id_transferencia % 3)
FROM inventarios.transferencias t
WHERE t.id_transferencia = dt.id_transferencia
  AND t.estado = 'RECIBIDA'
  AND t.id_transferencia % 4 = 0
  AND dt.id_producto = (SELECT min(id_producto) FROM inventarios.detalle_transferencia d2
                        WHERE d2.id_transferencia = dt.id_transferencia);

-- ---------------------------------------------------------------------
-- Sincroniza las secuencias de identidad después de usar valores explícitos
-- ---------------------------------------------------------------------
DO $$
DECLARE
    c record;
BEGIN
    FOR c IN
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE is_identity = 'YES'
          AND table_schema IN ('catalogo', 'identidad', 'compras', 'inventarios', 'ventas')
    LOOP
        EXECUTE format(
            'SELECT setval(pg_get_serial_sequence(%L, %L), COALESCE((SELECT max(%I) FROM %I.%I), 0) + 1, false)',
            c.table_schema || '.' || c.table_name, c.column_name,
            c.column_name, c.table_schema, c.table_name);
    END LOOP;
END $$;

DROP TABLE tmp_ped_base, tmp_ped, tmp_pag, tmp_dev, tmp_oc, tmp_rec, tmp_tr;

ANALYZE;
