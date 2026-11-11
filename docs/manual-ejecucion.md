# Manual de instalación y ejecución

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

## 1. Requisitos

- PostgreSQL 17 o superior (probado en PostgreSQL 18), con la extensión `dblink` (viene en el paquete *contrib* de PostgreSQL). Hace falta la 17 por el permiso `MAINTAIN`, que deja a `svc_reportes` refrescar las vistas materializadas.
- `psql`. Los scripts usan comandos propios de psql (`\c`, `\ir`, `\if`, `\gset`, `\echo`, `\set`), así que **no se pueden ejecutar desde pgAdmin** (ver sección 4.3).
- Un usuario superusuario (normalmente `postgres`), porque los scripts crean bases y roles.

## 2. Estructura

Cada microservicio tiene su propia base de datos. Dentro de cada base hay un esquema con el nombre del servicio (por ejemplo `ventas.ped_bogota` en `andina_ventas`). La base de reportes no tiene tablas: sus vistas traen los datos de las otras bases con `dblink`.

| Base | Esquemas | Contenido |
| --- | --- | --- |
| `andina_catalogo` | `catalogo` | sedes, almacenes, categorías, productos, proveedores, clientes |
| `andina_identidad` | `identidad` | empleados, usuarios, auditoría de accesos |
| `andina_compras` | `compras` | órdenes de compra y recepciones |
| `andina_inventarios` | `inventarios` | inventario fragmentado por sede + transferencias |
| `andina_ventas` | `ventas` | pedidos y detalles fragmentados por sede, pagos, devoluciones |
| `andina_reportes` | `reportes` (vistas) | vistas materializadas que traen los datos por `dblink` (extensión instalada solo aquí) |

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
│   ├── dblink/
│   │   ├── servidores.sql            instala dblink y registra las otras bases (srv_*)
│   │   └── quitar.sql                quita dblink (los datos de prueba lo usan y luego lo quitan)
│   ├── refrescar_reportes.sql    REFRESH de las vistas materializadas (lo que se programa cada X min)
│   ├── 08_vistas.sql             vistas UNION ALL de fragmentos + 10 vistas obligatorias
│   ├── 09_roles.sql              roles, usuarios técnicos svc_*, CONNECT y GRANT / REVOKE por base
│   ├── 10_consultas.sql          las 20 consultas
│   └── 11_pruebas.sql            pruebas de restricciones, fragmentos, permisos y aislamiento
└── docs/
    ├── enunciado.pdf             requisitos del proyecto
    ├── evidencias.txt            salida completa de run_all.sql
    └── diagramas/                arquitectura, E-R y relacional
```

## 3. Ejecución rápida

Desde la carpeta del proyecto:

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
| 1 | `\c andina_catalogo` · `\i sql/02_catalogo.sql` · `\i sql/07_datos_catalogo.sql` | Tablas y datos de catálogo | `\dt catalogo.*` |
| 2 | `\c andina_identidad` · `03_identidad` · `07_datos_identidad` | Empleados, usuarios, auditoría | `\dt identidad.*` |
| 3 | `\c andina_compras` · `04_compras` · `07_datos_compras` | Órdenes y recepciones (lee catálogo con `dblink`) | `\dt compras.*` |
| 4 | `\c andina_inventarios` · `05_inventarios` · `07_datos_inventarios` | Los 4 fragmentos de inventario + transferencias | `\d inventarios.inv_cali` (muestra el CHECK de la sede) |
| 5 | `\c andina_ventas` · `06_ventas` · `07_datos_ventas` | Pedidos y detalles por sede, pagos, devoluciones | `SELECT COUNT(*) FROM ventas.ped_bogota;` → 100 |
| 6 | `\c andina_reportes` · `dblink/servidores` · `08_vistas` · `refrescar_reportes` | Instala `dblink`, crea las vistas materializadas (vacías) y las llena | `\dm reportes.*` |
| 7 | `\i sql/09_roles.sql` | Roles, usuarios y permisos (el script hace sus propios `\c`) | `\du` y `\l+` |
| 8 | `\c andina_reportes` · `\i sql/10_consultas.sql` | Las 20 consultas | — |
| 9 | `\i sql/11_pruebas.sql` | Las pruebas (cada base dentro de su BEGIN … ROLLBACK) | Cada rechazo esperado sale como `ERROR:` justo debajo de su título `-> esperado: ERROR …` |

### 4.2 Por qué este orden

- Catálogo va primero: los demás servicios usan sus ids, y sus datos de prueba leen catálogo con `dblink` (inventarios necesita almacenes y productos, ventas los precios, compras qué vende cada proveedor). Al terminar, cada servicio quita `dblink` de su base.
- Ventas va después de inventarios porque solo vende productos que existen en cada almacén (los lee con `dblink`).
- Reportes va después de todos porque sus vistas traen los datos de las otras bases.
- `08_vistas.sql` crea las vistas materializadas **vacías** (`WITH NO DATA`); se llenan cuando corre `refrescar_reportes.sql`.
- Los roles van al final porque `GRANT … ON ALL TABLES` solo afecta a las tablas que ya existen.

### 4.3 Sobre pgAdmin

pgAdmin sirve para **mirar** las bases después de ejecutar `run_all.sql`, pero no para ejecutar los scripts: no entiende `\c` (cambiar de base), `\ir`, `\if` ni `\echo`. Para revisar en pgAdmin hay que abrir el Query Tool sobre la base que se quiera (`andina_ventas`, `andina_reportes`…).

### 4.4 Poner los reportes al día (REFRESH)

Los reportes son **vistas materializadas**: guardan su resultado y solo cambian al refrescarlas. Para actualizarlos sin rehacer todo:

```bash
psql -U postgres -d andina_reportes -f sql/refrescar_reportes.sql
```

Hace `REFRESH MATERIALIZED VIEW` de todas las vistas, en orden y en una transacción: cada vista vuelve a traer los datos por `dblink`. Si una base no responde, el refresco falla entero y quedan los reportes anteriores. Al final muestra `reportes.vista_ultima_actualizacion`.

Para que corra solo cada 5 minutos en el servidor, una línea en `crontab -e`:

```
*/5 * * * * psql -U postgres -d andina_reportes -f /ruta/del/proyecto/sql/refrescar_reportes.sql
```


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
| `could not establish connection` (dblink) | `dblink` no pudo conectarse a la otra base por el socket local. Correr con `-v dblink_host=localhost -v dblink_password=...` (ver `sql/dblink/servidores.sql`). |
| `permission denied to create database` o `… to create role` | Hay que ejecutar los scripts como superusuario (`postgres`). |
| `relation "catalogo.productos" does not exist` | Se está en la base equivocada: cada tabla vive en la base de su servicio (en `andina_reportes` se lee con `dblink`). Revisar con `SELECT current_database();`. |
| `role "…" cannot be dropped because some objects depend on it` | El rol tiene permisos en una base que no es del proyecto. Ejecutar `DROP OWNED BY <rol>;` en esa base. |
| Error en `\ir` | Ejecutar `run_all.sql` con `-f`; `\ir` resuelve las rutas respecto al propio archivo. |
| Las fechas de las consultas no cambian con el día | Es intencional: la fecha de corte es fija (2026-10-15) en `reportes.parametros`. |
