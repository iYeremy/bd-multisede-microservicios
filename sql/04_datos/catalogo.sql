-- 04_datos/catalogo.sql
-- datos de prueba de catalogo (base andina_catalogo). ver README.md.

-- los ids se ponen solos en orden: sede 1 = bogota, 2 = medellin, 3 = cali,
-- 4 = CEDI; almacenes 1 a 5 (4 y 5 son del CEDI). los demas servicios usan estos ids
INSERT INTO catalogo.sedes (nombre, ciudad, direccion, tipo_sede) VALUES
    ('Sede Bogotá',   'Bogotá',   'Calle 72 # 10-34',          'VENTA'),
    ('Sede Medellín', 'Medellín', 'Carrera 43A # 1-50',        'VENTA'),
    ('Sede Cali',     'Cali',     'Avenida 6N # 23-45',        'VENTA'),
    ('CEDI Funza',    'Funza',    'Parque Industrial km 2 vía Funza', 'DISTRIBUCION');

INSERT INTO catalogo.almacenes (id_sede, nombre, tipo_almacen) VALUES
    (1, 'Almacén Bogotá',           'PRINCIPAL'),
    (2, 'Almacén Medellín',         'PRINCIPAL'),
    (3, 'Almacén Cali',             'PRINCIPAL'),
    (4, 'Bodega general CEDI',      'GENERAL'),
    (4, 'Bodega de despacho CEDI',  'DESPACHO');

INSERT INTO catalogo.categorias (nombre, descripcion) VALUES
    ('Alimentos',           'Abarrotes y alimentos no perecederos'),
    ('Bebidas',             'Bebidas no alcohólicas y alcohólicas'),
    ('Aseo personal',       'Productos de higiene y cuidado personal'),
    ('Limpieza del hogar',  'Detergentes, desinfectantes y accesorios'),
    ('Papelería y oficina', 'Útiles escolares y de oficina');

-- 16 productos por categoria: ALI 1-16, BEB 17-32, ASE 33-48, LIM 49-64, PAP 65-80
INSERT INTO catalogo.productos (sku, nombre, id_categoria, unidad_medida, precio_lista, estado) VALUES
    ('ALI-001', 'Arroz blanco 1 kg',              1, 'KG',       4800, 'ACTIVO'),
    ('ALI-002', 'Azúcar refinada 1 kg',           1, 'KG',       4200, 'ACTIVO'),
    ('ALI-003', 'Aceite vegetal 1 L',             1, 'BOTELLA', 11500, 'ACTIVO'),
    ('ALI-004', 'Pasta spaghetti 500 g',          1, 'PAQUETE',  3600, 'ACTIVO'),
    ('ALI-005', 'Lenteja 500 g',                  1, 'PAQUETE',  4100, 'ACTIVO'),
    ('ALI-006', 'Fríjol rojo 500 g',              1, 'PAQUETE',  6200, 'ACTIVO'),
    ('ALI-007', 'Café molido 500 g',              1, 'PAQUETE', 18900, 'ACTIVO'),
    ('ALI-008', 'Chocolate de mesa 500 g',        1, 'PAQUETE',  9800, 'ACTIVO'),
    ('ALI-009', 'Atún en lata 170 g',             1, 'UND',      6900, 'ACTIVO'),
    ('ALI-010', 'Harina de maíz 1 kg',            1, 'KG',       3900, 'ACTIVO'),
    ('ALI-011', 'Sal refinada 1 kg',              1, 'KG',       2300, 'ACTIVO'),
    ('ALI-012', 'Avena en hojuelas 500 g',        1, 'PAQUETE',  5400, 'ACTIVO'),
    ('ALI-013', 'Galletas de soda x6',            1, 'PAQUETE',  4700, 'ACTIVO'),
    ('ALI-014', 'Panela 1 kg',                    1, 'KG',       4500, 'ACTIVO'),
    ('ALI-015', 'Salsa de tomate 400 g',          1, 'UND',      5600, 'ACTIVO'),
    ('ALI-016', 'Mayonesa 400 g',                 1, 'UND',      7900, 'ACTIVO'),
    ('BEB-001', 'Agua sin gas 600 ml',            2, 'BOTELLA',  1800, 'ACTIVO'),
    ('BEB-002', 'Gaseosa cola 1.5 L',             2, 'BOTELLA',  5200, 'ACTIVO'),
    ('BEB-003', 'Gaseosa naranja 1.5 L',          2, 'BOTELLA',  5000, 'ACTIVO'),
    ('BEB-004', 'Jugo de mango 1 L',              2, 'BOTELLA',  4900, 'ACTIVO'),
    ('BEB-005', 'Jugo de naranja 1 L',            2, 'BOTELLA',  5300, 'ACTIVO'),
    ('BEB-006', 'Té helado limón 500 ml',         2, 'BOTELLA',  3200, 'ACTIVO'),
    ('BEB-007', 'Bebida energizante 250 ml',      2, 'UND',      4800, 'ACTIVO'),
    ('BEB-008', 'Cerveza lager six pack',         2, 'PAQUETE', 16500, 'ACTIVO'),
    ('BEB-009', 'Agua con gas 600 ml',            2, 'BOTELLA',  2100, 'ACTIVO'),
    ('BEB-010', 'Leche entera 1 L',               2, 'UND',      4300, 'ACTIVO'),
    ('BEB-011', 'Kumis 1 L',                      2, 'UND',      5900, 'ACTIVO'),
    ('BEB-012', 'Bebida de soya 1 L',             2, 'UND',      7200, 'ACTIVO'),
    ('BEB-013', 'Malta 330 ml',                   2, 'UND',      2400, 'ACTIVO'),
    ('BEB-014', 'Bebida hidratante 500 ml',       2, 'BOTELLA',  3900, 'ACTIVO'),
    ('BEB-015', 'Café listo para tomar 250 ml',   2, 'UND',      4600, 'ACTIVO'),
    ('BEB-016', 'Vino tinto 750 ml',              2, 'BOTELLA', 38000, 'ACTIVO'),
    ('ASE-001', 'Jabón de tocador x3',            3, 'PAQUETE',  7800, 'ACTIVO'),
    ('ASE-002', 'Shampoo 400 ml',                 3, 'BOTELLA', 16900, 'ACTIVO'),
    ('ASE-003', 'Acondicionador 400 ml',          3, 'BOTELLA', 17500, 'ACTIVO'),
    ('ASE-004', 'Crema dental 100 ml',            3, 'UND',      6200, 'ACTIVO'),
    ('ASE-005', 'Cepillo dental',                 3, 'UND',      5500, 'ACTIVO'),
    ('ASE-006', 'Desodorante roll-on',            3, 'UND',     13900, 'ACTIVO'),
    ('ASE-007', 'Talco para pies 120 g',          3, 'UND',      8900, 'DESCONTINUADO'),
    ('ASE-008', 'Papel higiénico x12',            3, 'PAQUETE', 22500, 'ACTIVO'),
    ('ASE-009', 'Toallas húmedas x50',            3, 'PAQUETE',  8700, 'ACTIVO'),
    ('ASE-010', 'Enjuague bucal 500 ml',          3, 'BOTELLA', 15800, 'ACTIVO'),
    ('ASE-011', 'Crema corporal 400 ml',          3, 'BOTELLA', 19900, 'ACTIVO'),
    ('ASE-012', 'Máquina de afeitar x3',          3, 'PAQUETE', 12400, 'ACTIVO'),
    ('ASE-013', 'Gel antibacterial 500 ml',       3, 'BOTELLA',  9900, 'ACTIVO'),
    ('ASE-014', 'Protector solar 120 ml',         3, 'UND',     32900, 'ACTIVO'),
    ('ASE-015', 'Toallas higiénicas x10',         3, 'PAQUETE',  6800, 'ACTIVO'),
    ('ASE-016', 'Pañales etapa 3 x30',            3, 'PAQUETE', 45900, 'ACTIVO'),
    ('LIM-001', 'Detergente en polvo 1 kg',       4, 'KG',      14500, 'ACTIVO'),
    ('LIM-002', 'Suavizante 1 L',                 4, 'BOTELLA', 11900, 'ACTIVO'),
    ('LIM-003', 'Blanqueador 1 L',                4, 'BOTELLA',  5800, 'ACTIVO'),
    ('LIM-004', 'Lavaloza líquido 500 ml',        4, 'BOTELLA',  7600, 'ACTIVO'),
    ('LIM-005', 'Limpiavidrios 500 ml',           4, 'BOTELLA',  8900, 'ACTIVO'),
    ('LIM-006', 'Desinfectante multiusos 1 L',    4, 'BOTELLA',  9400, 'ACTIVO'),
    ('LIM-007', 'Esponja de cocina x3',           4, 'PAQUETE',  4200, 'ACTIVO'),
    ('LIM-008', 'Bolsas de basura x10',           4, 'PAQUETE',  5900, 'ACTIVO'),
    ('LIM-009', 'Escoba plástica',                4, 'UND',     12900, 'ACTIVO'),
    ('LIM-010', 'Trapero de algodón',             4, 'UND',     14900, 'ACTIVO'),
    ('LIM-011', 'Guantes de caucho',              4, 'UND',      6300, 'ACTIVO'),
    ('LIM-012', 'Ambientador en aerosol',         4, 'UND',     10900, 'ACTIVO'),
    ('LIM-013', 'Jabón en barra para ropa x3',    4, 'PAQUETE',  6900, 'ACTIVO'),
    ('LIM-014', 'Toallas de cocina x3',           4, 'PAQUETE', 10500, 'ACTIVO'),
    ('LIM-015', 'Insecticida en aerosol',         4, 'UND',     16800, 'ACTIVO'),
    ('LIM-016', 'Cera para pisos 1 L',            4, 'BOTELLA', 13500, 'INACTIVO'),
    ('PAP-001', 'Cuaderno cuadriculado 100 h',    5, 'UND',      6500, 'ACTIVO'),
    ('PAP-002', 'Resma papel carta',              5, 'PAQUETE', 21900, 'ACTIVO'),
    ('PAP-003', 'Bolígrafo negro x12',            5, 'CAJA',    14400, 'ACTIVO'),
    ('PAP-004', 'Lápiz grafito x12',              5, 'CAJA',     9600, 'ACTIVO'),
    ('PAP-005', 'Borrador de nata x5',            5, 'PAQUETE',  4500, 'ACTIVO'),
    ('PAP-006', 'Carpeta legajadora',             5, 'UND',      2800, 'ACTIVO'),
    ('PAP-007', 'Marcador permanente x4',         5, 'PAQUETE', 11200, 'ACTIVO'),
    ('PAP-008', 'Resaltador x4',                  5, 'PAQUETE',  9900, 'ACTIVO'),
    ('PAP-009', 'Cinta adhesiva transparente',    5, 'UND',      3500, 'ACTIVO'),
    ('PAP-010', 'Pegante en barra 40 g',          5, 'UND',      5200, 'ACTIVO'),
    ('PAP-011', 'Tijeras escolares',              5, 'UND',      4900, 'ACTIVO'),
    ('PAP-012', 'Colores x24',                    5, 'CAJA',    18500, 'ACTIVO'),
    ('PAP-013', 'Calculadora básica',             5, 'UND',     24900, 'ACTIVO'),
    ('PAP-014', 'Grapadora metálica',             5, 'UND',     19800, 'ACTIVO'),
    ('PAP-015', 'Notas adhesivas x5',             5, 'PAQUETE',  8400, 'ACTIVO'),
    ('PAP-016', 'Disquete 3.5" x10',              5, 'CAJA',    15000, 'DESCONTINUADO');

INSERT INTO catalogo.proveedores (identificacion, razon_social, ciudad, correo, telefono) VALUES
    ('900111001-1', 'Alimentos del Valle S.A.S.',       'Cali',         'ventas@alimvalle.co',      '6023334455'),
    ('900111002-2', 'Distribuidora La Sabana Ltda.',    'Bogotá',       'pedidos@lasabana.co',      '6017778899'),
    ('900111003-3', 'Bebidas Andinas S.A.',             'Medellín',     'comercial@bebandinas.co',  '6045556677'),
    ('900111004-4', 'Higiene Total S.A.S.',             'Bogotá',       'contacto@higienetotal.co', '6012223344'),
    ('900111005-5', 'Químicos del Caribe S.A.',         'Barranquilla', 'ventas@quimcaribe.co',     '6053332211'),
    ('900111006-6', 'Papelera Nacional S.A.S.',         'Bogotá',       'ventas@papelnal.co',       '6019998877'),
    ('900111007-7', 'Importadora El Puerto Ltda.',      'Cartagena',    'import@elpuerto.co',       '6056665544'),
    ('900111008-8', 'Granos y Cereales del Huila S.A.', 'Neiva',        'granos@cerhuila.co',       '6088887766'),
    ('900111009-9', 'Lácteos de la Montaña S.A.S.',     'Manizales',    'ventas@lacmontana.co',     '6064443322'),
    ('900111010-0', 'Comercial Santander Ltda.',        'Bucaramanga',  'info@comsantander.co',     '6071112233');

-- proveedor principal para todos y uno segundo para los de id par (RN-05)
INSERT INTO catalogo.producto_proveedor (id_producto, id_proveedor, costo_referencia, plazo_entrega_dias)
SELECT p.id_producto, ((p.id_producto - 1) % 10) + 1,
       round(p.precio_lista * 0.65, 0), 5 + ((((p.id_producto - 1) % 10) + 1) % 4) * 3
FROM catalogo.productos p
UNION ALL
SELECT p.id_producto, ((p.id_producto + 4) % 10) + 1,
       round(p.precio_lista * 0.68, 0), 5 + ((((p.id_producto + 4) % 10) + 1) % 4) * 3
FROM catalogo.productos p
WHERE p.id_producto % 2 = 0;

-- 100 clientes: cada 10 es una empresa (NIT); 48 y 97 inactivos
INSERT INTO catalogo.clientes (tipo_documento, num_documento, nombre_completo, correo, telefono, estado)
SELECT CASE WHEN i % 10 = 0 THEN 'NIT' WHEN i % 23 = 0 THEN 'CE' ELSE 'CC' END,
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
FROM generate_series(1, 100) AS i
ORDER BY i;
