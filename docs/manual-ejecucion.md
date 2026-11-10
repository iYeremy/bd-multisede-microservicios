# Manual de instalación y ejecución

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

## 1. Requisitos

- PostgreSQL 12 o superior (probado en PostgreSQL 18).
- `psql`. Los scripts usan comandos propios de psql (`\c`, `\ir`, `\copy`, `\echo`, `\set`), así que **no se pueden ejecutar desde pgAdmin** (ver sección 4.3).
- Un usuario superusuario (normalmente `postgres`), porque los scripts crean bases y roles.

## 2. Estructura

Cada microservicio tiene su propia base de datos. Dentro de cada base hay un esquema con el nombre del servicio, por eso las tablas se llaman igual en su base y en la copia de reportes (por ejemplo `ventas.ped_bogota`).

| Base | Esquemas | Contenido |
| --- | --- | --- |
| `andina_catalogo` | `catalogo` | sedes, almacenes, categorías, productos, proveedores, clientes |
| `andina_identidad` | `identidad` | empleados, usuarios, auditoría de accesos |
| `andina_compras` | `compras` | órdenes de compra y recepciones |
| `andina_inventarios` | `inventarios` | inventario fragmentado por sede + transferencias |
| `andina_ventas` | `ventas` | pedidos y detalles fragmentados por sede, pagos, devoluciones |
| `andina_reportes` | `catalogo`, `identidad`, `compras`, `inventarios`, `ventas` (copias) y `reportes` (vistas) | copia de solo lectura de los demás servicios + las vistas de integración |

```
proyecto/
├── run_all.sql                   ejecuta todo en orden (\c + \ir)
├── sql/
│   ├── 00_reset.sql              DROP de las 6 bases y de los roles
│   ├── 01_bases.sql              CREATE DATABASE, una por microservicio
│   ├── 02_catalogo.sql           7 tablas de Catálogo y Terceros
│   ├── 03_identidad.sql          empleados, usuarios, auditoría
│   ├── 04_compras.sql            órdenes, detalles y recepciones
│   ├── 05_inventarios.sql        inventario fragmentado (4 tablas, una por sede) + transferencias
│   ├── 06_ventas.sql             pedidos y detalles fragmentados (4+4 tablas), pagos, devoluciones
│   ├── 07_datos_catalogo.sql     datos de prueba de cada servicio (semilla fija)
│   ├── 07_datos_identidad.sql
│   ├── 07_datos_compras.sql
│   ├── 07_datos_inventarios.sql
│   ├── 07_datos_ventas.sql
│   ├── sync/
│   │   ├── exportar_<servicio>.sql   cada servicio deja sus tablas en csv/
│   │   └── importar_reportes.sql     reportes carga esos CSV en su copia
│   ├── 08_vistas.sql             vistas UNION ALL de fragmentos + 10 vistas obligatorias
│   ├── 09_roles.sql              roles, usuarios técnicos svc_*, CONNECT y GRANT / REVOKE por base
│   ├── 10_consultas.sql          las 20 consultas
│   └── 11_pruebas.sql            pruebas de restricciones, fragmentos, permisos y aislamiento
├── csv/                          lo genera run_all.sql (git lo ignora)
└── docs/
    ├── enunciado.pdf             requisitos del proyecto
    ├── evidencias.txt            salida completa de run_all.sql
    └── diagramas/                arquitectura, E-R y relacional
```

## 3. Ejecución rápida

Desde la **carpeta del proyecto** (los CSV se escriben en `csv/`, una ruta relativa a donde se lanza psql):

```bash
# ejecutar todo (no hace falta crear ninguna base antes)
psql -U postgres -f run_all.sql

# guardar la salida como evidencia
psql -U postgres -f run_all.sql > docs/evidencias.txt 2>&1
```

`run_all.sql` se conecta primero a la base `postgres` (la que trae PostgreSQL) y desde ahí borra y crea las 6 bases, así que se puede ejecutar todas las veces que se quiera. Se detiene en el primer error (`ON_ERROR_STOP`), salvo en `11_pruebas.sql`: ahí los errores son el resultado esperado de las pruebas de rechazo, y el script los muestra y continúa.

Si PostgreSQL pide contraseña, psql la reutiliza en cada `\c` porque solo cambia la base. También se puede definir `PGPASSWORD` antes de ejecutar.

> El reset también borra la base `comercializadora` de la versión anterior del proyecto (todo en una sola base), porque sus permisos impedirían borrar los roles.

## 4. Ejecución paso a paso

### 4.1 Orden

Abrir psql desde la carpeta del proyecto (`psql -U postgres`) y ejecutar en este orden. Cada `\c` cambia de base: cada script corre en la base de su servicio.

| Paso | Comandos en psql | Qué hace | Comprobación |
| --- | --- | --- | --- |
| 0 | `\c postgres` · `\i sql/00_reset.sql` · `\i sql/01_bases.sql` | Borra y crea las 6 bases | `\l andina_*` |
| 1 | `\c andina_catalogo` · `\i sql/02_catalogo.sql` · `\i sql/07_datos_catalogo.sql` · `\i sql/sync/exportar_catalogo.sql` | Tablas y datos de catálogo; deja sus CSV | `\dt catalogo.*` |
| 2 | `\c andina_identidad` · `03_identidad` · `07_datos_identidad` · `sync/exportar_identidad` | Empleados, usuarios, auditoría | `\dt identidad.*` |
| 3 | `\c andina_compras` · `04_compras` · `07_datos_compras` · `sync/exportar_compras` | Órdenes y recepciones | `\dt compras.*` |
| 4 | `\c andina_inventarios` · `05_inventarios` · `07_datos_inventarios` · `sync/exportar_inventarios` | Los 4 fragmentos de inventario + transferencias | `\d inventarios.inv_cali` (muestra el CHECK de la sede) |
| 5 | `\c andina_ventas` · `06_ventas` · `07_datos_ventas` · `sync/exportar_ventas` | Pedidos y detalles por sede, pagos, devoluciones | `SELECT COUNT(*) FROM ventas.ped_bogota;` → 100 |
| 6 | `\c andina_reportes` · `02` a `06` · `sync/importar_reportes` · `08_vistas` | Crea las mismas tablas, carga la copia desde los CSV y crea las vistas | `\dn+` y `\dv reportes.*` |
| 7 | `\i sql/09_roles.sql` | Roles, usuarios y permisos (el script hace sus propios `\c`) | `\du` y `\l+` |
| 8 | `\c andina_reportes` · `\i sql/10_consultas.sql` | Las 20 consultas | — |
| 9 | `\i sql/11_pruebas.sql` | Las pruebas (cada base dentro de su BEGIN … ROLLBACK) | Cada rechazo esperado sale como `ERROR:` justo debajo de su título `-> esperado: ERROR …` |

### 4.2 Por qué este orden

- Catálogo va primero: los demás servicios usan sus ids y leen sus CSV para armar sus datos de prueba (inventarios necesita almacenes y productos, ventas los precios, compras qué vende cada proveedor).
- Ventas va después de inventarios porque solo vende productos que existen en cada almacén (lee los CSV de inventario).
- Reportes va después de todos porque su copia se carga con los CSV que dejan los demás.
- Los roles van al final porque `GRANT … ON ALL TABLES` solo afecta a las tablas que ya existen.

### 4.3 Sobre pgAdmin

pgAdmin sirve para **mirar** las bases después de ejecutar `run_all.sql`, pero no para ejecutar los scripts: no entiende `\c` (cambiar de base), `\copy` (leer y escribir los CSV), `\ir` ni `\echo`. Para revisar en pgAdmin hay que abrir el Query Tool sobre la base que se quiera (`andina_ventas`, `andina_reportes`…).

## 5. Usuarios de prueba

Contraseña de todos: `Andina2026*`.

| Usuario | Rol | Bases a las que entra | Alcance |
| --- | --- | --- | --- |
| admin_andina | rol_administrador | todas | Todo, puede crear roles |
| gerente_general | rol_gerencia | reportes | Solo las vistas de `reportes` |
| inventario_bogota | rol_inventario | catálogo, inventarios, reportes | Fragmento `inventarios.inv_bogota` + transferencias + 3 vistas |
| inventario_cedi | rol_inventario | catálogo, inventarios, reportes | Fragmento `inventarios.inv_cedi` + transferencias + 3 vistas |
| compras_cedi | rol_compras | catálogo, compras, reportes | Tablas de `compras` + 1 vista |
| vendedor_bogota | rol_vendedor | catálogo, ventas | `ventas.ped_bogota` / `det_ped_bogota` + pagos y devoluciones |
| vendedor_cali | rol_vendedor | catálogo, ventas | `ventas.ped_cali` / `det_ped_cali` + pagos y devoluciones |
| auditor_interno | rol_auditor | todas | SELECT de todo, salvo `usuarios.password_hash` |

Usuarios técnicos (los que usará el backend): `svc_catalogo`, `svc_identidad`, `svc_compras`, `svc_inventarios`, `svc_ventas` y `svc_reportes`. Cada uno entra **solo** a la base de su servicio. Se crean sin contraseña; al desplegar se les asigna con `ALTER ROLE svc_ventas PASSWORD '…';` usando el valor del `.env` del servidor (las contraseñas reales no van en el repositorio).

Probar un usuario sin cerrar la sesión de superusuario:

```sql
\c andina_ventas
SET ROLE vendedor_bogota;
SELECT COUNT(*) FROM ventas.ped_bogota;   -- permitido
SELECT COUNT(*) FROM ventas.ped_cali;     -- ERROR: permiso denegado
RESET ROLE;
```

O conectarse directamente: `psql -U vendedor_bogota -d andina_ventas -h localhost`. Si se intenta `psql -U gerente_general -d andina_ventas`, la conexión se rechaza (`User does not have CONNECT privilege`).

## 6. Consultar un fragmento por sede

```sql
-- consulta local (solo una sede): en la base del servicio, se lee el fragmento directamente
\c andina_inventarios
SELECT * FROM inventarios.inv_cali;
\c andina_ventas
SELECT * FROM ventas.ped_medellin WHERE estado = 'PENDIENTE';

-- consulta corporativa (las cuatro sedes): en la base de reportes
\c andina_reportes
SELECT fragmento, COUNT(*) FROM reportes.vista_inventario_consolidado GROUP BY fragmento;
SELECT * FROM reportes.vista_reporte_corporativo;
```

## 7. Problemas frecuentes

| Síntoma | Causa y solución |
| --- | --- |
| `database "…" is being accessed by other users` | Hay otra conexión abierta a esa base (pgAdmin, otra ventana de psql). Cerrarla y volver a ejecutar. |
| `csv/…: No such file or directory` | psql no se lanzó desde la carpeta del proyecto. Hacer `cd` a la carpeta y volver a ejecutar. |
| `permission denied to create database` o `… to create role` | Hay que ejecutar los scripts como superusuario (`postgres`). |
| `relation "catalogo.productos" does not exist` | Se está en la base equivocada: cada tabla vive en la base de su servicio (o en la copia de `andina_reportes`). Revisar con `SELECT current_database();`. |
| `role "…" cannot be dropped because some objects depend on it` | El rol tiene permisos en una base que no es del proyecto. Ejecutar `DROP OWNED BY <rol>;` en esa base. |
| Error en `\ir` | Ejecutar `run_all.sql` con `-f`; `\ir` resuelve las rutas respecto al propio archivo. |
| Las fechas de las consultas no cambian con el día | Es intencional: la fecha de corte es fija (2026-10-15) en `reportes.parametros`. |
