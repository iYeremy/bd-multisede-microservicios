# Manual de instalación y ejecución

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

## 1. Requisitos

- PostgreSQL 12 o superior (probado en PostgreSQL 18).
- `psql`. Los scripts usan comandos propios de psql (`\ir`, `\echo`, `\set`, `\if`); ver la nota sobre pgAdmin en la sección 4.
- Un usuario superusuario (normalmente `postgres`), porque los scripts crean roles.

## 2. Estructura

```
proyecto/
├── run_all.sql               ejecuta todo en orden (\ir)
├── sql/
│   ├── 00_reset.sql          DROP de esquemas y roles
│   ├── 01_esquemas.sql       6 esquemas, uno por microservicio
│   ├── 02_catalogo.sql       7 tablas de Catálogo y Terceros
│   ├── 03_identidad.sql      empleados, usuarios, auditoría
│   ├── 04_compras.sql        órdenes, detalles y recepciones
│   ├── 05_inventarios.sql    inventario fragmentado (4 tablas, una por sede) + transferencias
│   ├── 06_ventas.sql         pedidos y detalles fragmentados (4+4 tablas), pagos, devoluciones
│   ├── 07_datos.sql          datos de prueba reproducibles (semilla fija)
│   ├── 08_vistas.sql         vistas UNION ALL de fragmentos + 10 vistas obligatorias
│   ├── 09_roles.sql          6 roles de grupo, 8 usuarios, GRANT / REVOKE
│   ├── 10_consultas.sql      las 20 consultas
│   └── 11_pruebas.sql        pruebas de restricciones, fragmentos y permisos
└── docs/
    ├── enunciado.pdf         requisitos del proyecto
    ├── evidencias.txt        salida completa de run_all.sql
    └── diagramas/            diagrama de arquitectura de microservicios
```

## 3. Ejecución rápida

```bash
# 1. Crear la base (una sola vez)
createdb -U postgres comercializadora

# 2. Ejecutar todo desde la carpeta del proyecto
psql -U postgres -d comercializadora -f run_all.sql

# Guardar la salida como evidencia
psql -U postgres -d comercializadora -f run_all.sql > docs/evidencias.txt 2>&1
```

`run_all.sql` empieza con `00_reset.sql`, así que se puede ejecutar todas las veces que se quiera. Se detiene en el primer error (`ON_ERROR_STOP`), salvo en `11_pruebas.sql`: ahí los errores son el resultado esperado de las pruebas de rechazo, y el script los muestra y continúa.

## 4. Ejecución paso a paso

Conectarse a la base y ejecutar cada script en este orden. El orden importa: cada paso depende de los anteriores.

```bash
psql -U postgres -d comercializadora
```

| Paso | Comando en psql | Qué crea | Comprobación |
| --- | --- | --- | --- |
| 0 | `\i sql/00_reset.sql` | Borra esquemas y roles anteriores | — |
| 1 | `\i sql/01_esquemas.sql` | catalogo, identidad, compras, inventarios, ventas, reportes | `\dn` |
| 2 | `\i sql/02_catalogo.sql` | sedes, almacenes, categorias, productos, proveedores, producto_proveedor, clientes | `\dt catalogo.*` |
| 3 | `\i sql/03_identidad.sql` | empleados, usuarios, auditoria_accesos | `\dt identidad.*` |
| 4 | `\i sql/04_compras.sql` | ordenes_compra, detalle_orden_compra, recepciones_compra, detalle_recepcion | `\dt compras.*` |
| 5 | `\i sql/05_inventarios.sql` | inv_bogota, inv_medellin, inv_cali, inv_cedi; transferencias, detalle_transferencia | `\dt inventarios.*` |
| 6 | `\i sql/06_ventas.sql` | ped_bogota … ped_cedi; det_ped_bogota … det_ped_cedi (id_pedido IDENTITY por sede); pagos, devoluciones, detalle_devolucion | `\d ventas.ped_bogota` (muestra el CHECK de la sede) |
| 7 | `\i sql/07_datos.sql` | Datos de prueba | `SELECT COUNT(*) FROM ventas.ped_bogota;` → 100 |
| 8 | `\i sql/08_vistas.sql` | 4 vistas de apoyo + 10 vistas obligatorias en `reportes` | `\dv reportes.*` |
| 9 | `\i sql/09_roles.sql` | Roles, usuarios y permisos | `\du` y `\dp ventas.*` |
| 10 | `\i sql/10_consultas.sql` | Ejecuta las 20 consultas | — |
| 11 | `\i sql/11_pruebas.sql` | Ejecuta las pruebas (dentro de BEGIN … ROLLBACK) | Cada rechazo esperado sale como `ERROR:` justo debajo de su título `-> esperado: ERROR …` |

Por qué este orden:

- Las tablas de catálogo e identidad van primero porque son los datos maestros; las demás tablas los referencian con identificadores compartidos.
- Dentro de cada script la tabla padre se crea antes que sus detalles (FK locales).
- Los datos se cargan antes de las vistas solo por claridad; las vistas también se pueden crear con las tablas vacías.
- Los roles van después de las vistas porque `GRANT … ON ALL TABLES` solo afecta a los objetos que ya existen.

En pgAdmin: abrir el Query Tool sobre la base `comercializadora`, abrir cada archivo en el orden de la tabla y ejecutarlo con F5. Los comandos que empiezan con `\` son de psql y pgAdmin no los entiende:

- `00_reset.sql`: en la primera ejecución basta con los `DROP SCHEMA`; si los roles ya existen, ejecutar antes `REVOKE ALL ON DATABASE comercializadora FROM rol_administrador;` y después los `DROP ROLE`.
- `09_roles.sql`: cambiar `:"DBNAME"` por `comercializadora`.
- `10_consultas.sql` y `11_pruebas.sql`: borrar los `\echo` y `\set`, o ejecutar las consultas una por una. En las pruebas de rechazo, ejecutar cada instrucción por separado, porque un error dentro de la transacción la aborta.

## 5. Usuarios de prueba

Contraseña de todos: `Andina2026*`.

| Usuario | Rol | Alcance |
| --- | --- | --- |
| admin_andina | rol_administrador | Todo, puede crear roles |
| gerente_general | rol_gerencia | Solo SELECT sobre `reportes` |
| inventario_bogota | rol_inventario | Fragmento `inventarios.inv_bogota` + transferencias |
| inventario_cedi | rol_inventario | Fragmento `inventarios.inv_cedi` + transferencias |
| compras_cedi | rol_compras | Esquema `compras` |
| vendedor_bogota | rol_vendedor | Fragmentos `ventas.ped_bogota` / `det_ped_bogota` + pagos y devoluciones |
| vendedor_cali | rol_vendedor | Fragmentos `ventas.ped_cali` / `det_ped_cali` + pagos y devoluciones |
| auditor_interno | rol_auditor | SELECT de todo, salvo `usuarios.password_hash` |

Probar un usuario sin cerrar la sesión de superusuario:

```sql
SET ROLE vendedor_bogota;
SELECT COUNT(*) FROM ventas.ped_bogota;   -- permitido
SELECT COUNT(*) FROM ventas.ped_cali;     -- ERROR: permiso denegado
RESET ROLE;
```

O conectarse directamente: `psql -U vendedor_bogota -d comercializadora -h localhost`.

## 6. Consultar un fragmento por sede

```sql
-- Consulta local (solo una sede): se lee el fragmento directamente
SELECT * FROM inventarios.inv_cali;
SELECT * FROM ventas.ped_medellin WHERE estado = 'PENDIENTE';

-- Consulta corporativa (las cuatro sedes)
SELECT fragmento, COUNT(*) FROM reportes.vista_inventario_consolidado GROUP BY fragmento;
SELECT * FROM reportes.vista_reporte_corporativo;
```

## 7. Problemas frecuentes

| Síntoma | Causa y solución |
| --- | --- |
| `role "…" cannot be dropped because some objects depend on it` | El rol tiene permisos en otra base. Ejecutar `DROP OWNED BY <rol>;` en esa base, o usar una sola base para el proyecto. |
| `permission denied to create role` | Hay que ejecutar los scripts como superusuario (`postgres`). |
| Error en `\ir` | Ejecutar `run_all.sql` con `-f`; `\ir` resuelve las rutas respecto al propio archivo. |
| Las fechas de las consultas no cambian con el día | Es intencional: la fecha de corte es fija (2026-10-15) en `reportes.parametros`. |
