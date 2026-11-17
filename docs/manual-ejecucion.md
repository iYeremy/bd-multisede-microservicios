# Manual de instalación y ejecución

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

## 1. Requisitos

- PostgreSQL 17 o superior (probado en PostgreSQL 18), con la extensión `dblink` (viene en el paquete *contrib* de PostgreSQL). Hace falta la 17 por el permiso `MAINTAIN`, que deja a `svc_reportes` refrescar las vistas materializadas.
- `psql`. Los scripts usan comandos propios de psql (`\c`, `\ir`, `\getenv`, `\if`, `\gset`, `\echo`, `\set`), así que **no se pueden ejecutar desde pgAdmin** (ver sección 4.3).
- `bash`, para los scripts de `scripts/`.
- En local, nada más: `scripts/instancias_locales.sh` crea y arranca las instancias (no hace falta Docker). En la nube, una cuenta de [Neon](https://neon.com) (ver [`despliegue.md`](despliegue.md)).

## 2. Estructura

Cada microservicio tiene **su propia instancia de PostgreSQL**, y en ella su base. Dentro de cada base hay un esquema con el nombre del servicio (por ejemplo `ventas.ped_bogota` en `andina_ventas`). La base de reportes no tiene tablas: sus vistas traen los datos de las otras instancias con `dblink`.

| Instancia local | Base | Esquemas | Contenido |
| --- | --- | --- | --- |
| `localhost:5441` | `andina_catalogo` | `catalogo` | sedes, almacenes, categorías, productos, proveedores, clientes |
| `localhost:5442` | `andina_identidad` | `identidad` | empleados, usuarios, auditoría de accesos |
| `localhost:5443` | `andina_compras` | `compras` | órdenes de compra y recepciones |
| `localhost:5444` | `andina_inventarios` | `inventarios` | inventario fragmentado por sede + transferencias |
| `localhost:5445` | `andina_ventas` | `ventas` | pedidos y detalles fragmentados por sede, pagos, devoluciones |
| `localhost:5446` | `andina_reportes` | `reportes` (vistas) | vistas materializadas que traen los datos por `dblink` (extensión instalada solo aquí) |

```
proyecto/
├── run_all.sql             ejecuta todo en orden, instancia por instancia
├── scripts/
│   ├── instancias_locales.sh   levanta, apaga o borra las 6 instancias locales
│   └── correr.sh               corre los scripts con la configuración de un ambiente
├── config/
│   ├── local.env.example   conexión a las instancias locales (copiar como local.env)
│   └── neon.env.example    conexión a Neon (copiar como neon.env; nunca subirlo)
├── sql/                    cada carpeta tiene su README con la explicación
│   ├── README.md           índice: orden, carpetas, comandos de psql
│   ├── 00_config/          lee la configuración y arma la conexión de cada servicio
│   ├── 01_bases/           reset.sql · crear.sql (la base de cada instancia)
│   ├── 02_tablas/          catalogo · identidad · compras · inventarios · ventas (.sql)
│   ├── 03_dblink/          servidores.sql (instala dblink y registra las otras instancias) · quitar.sql
│   ├── 04_datos/           datos de prueba de cada servicio (semilla fija)
│   ├── 05_reportes/        vistas.sql (vistas materializadas) · refrescar.sql (REFRESH)
│   ├── 06_roles/           un archivo por instancia: roles, usuarios svc_*, GRANT / REVOKE
│   ├── 07_consultas/       consultas.sql: las 20 consultas
│   └── 08_pruebas/         pruebas.sql: restricciones, fragmentos, permisos y aislamiento
└── docs/
    ├── enunciado.pdf             requisitos del proyecto
    ├── evidencias.txt            salida completa de run_all.sql
    ├── despliegue.md             una instancia por servicio: local y Neon
    └── diagramas/                arquitectura, E-R, relacional y los de diccionario y normalización
```

## 3. Ejecución rápida

Desde la carpeta del proyecto:

```bash
# 1. levantar las 6 instancias (la primera vez las crea)
scripts/instancias_locales.sh iniciar

# 2. la configuración de conexión (una sola vez)
cp config/local.env.example config/local.env

# 3. ejecutar todo
scripts/correr.sh config/local.env

# guardar la salida como evidencia
scripts/correr.sh config/local.env > docs/evidencias.txt 2>&1

# al terminar, apagar las instancias
scripts/instancias_locales.sh detener
```

`correr.sh` carga la configuración y lanza `run_all.sql`. Este va instancia por instancia: en cada una borra y crea su base, sus tablas, sus datos y sus roles, así que se puede ejecutar todas las veces que se quiera. Se detiene en el primer error (`ON_ERROR_STOP`), salvo en `08_pruebas/pruebas.sql`: ahí los errores son el resultado esperado de las pruebas de rechazo, y el script los muestra y continúa.

`psql -f run_all.sql` directo no funciona: sin la configuración no sabe a qué instancias conectarse, y avisa.

## 4. Ejecución paso a paso

### 4.1 Orden

`run_all.sql` hace esto. Para hacerlo a mano, primero cargar la configuración (`set -a; . config/local.env; set +a`), abrir psql y correr `\i sql/00_config/conexiones.sql`, que deja listas las conexiones `:conn_<servicio>`.

| Paso | En psql | Qué hace | Comprobación |
| --- | --- | --- | --- |
| 1 | `\c :conn_catalogo_admin` · `\set db andina_catalogo` · `01_bases/reset` · `01_bases/crear` · `\c :conn_catalogo` · `02_tablas/catalogo` · `04_datos/catalogo` · `06_roles/catalogo` | Instancia de catálogo completa | `\dt catalogo.*` |
| 2 | Lo mismo con `identidad` | Empleados, usuarios, auditoría | `\dt identidad.*` |
| 3 | Lo mismo con `compras` | Órdenes y recepciones (lee catálogo con `dblink`) | `\dt compras.*` |
| 4 | Lo mismo con `inventarios` | Los 4 fragmentos de inventario + transferencias | `\d inventarios.inv_cali` (muestra el CHECK de la sede) |
| 5 | Lo mismo con `ventas` | Pedidos y detalles por sede, pagos, devoluciones | `SELECT COUNT(*) FROM ventas.ped_bogota;` → 100 |
| 6 | `\c :conn_reportes_admin` · reset y crear · `\c :conn_reportes` · `03_dblink/servidores` · `05_reportes/vistas` · `05_reportes/refrescar` · `06_roles/reportes` | Instala `dblink`, crea las vistas materializadas y las llena | `\dm reportes.*` |
| 7 | `\c :conn_reportes` · `07_consultas/consultas` | Las 20 consultas | — |
| 8 | `08_pruebas/pruebas` | Las pruebas (cada instancia dentro de su BEGIN … ROLLBACK) | Cada rechazo esperado sale como `ERROR:` justo debajo de su título `-> esperado: ERROR …` |

### 4.2 Por qué este orden

- Catálogo va primero: los demás servicios usan sus ids, y sus datos de prueba leen catálogo con `dblink` (inventarios necesita almacenes y productos, ventas los precios, compras qué vende cada proveedor). Al terminar, cada servicio quita `dblink` de su base.
- Ventas va después de inventarios porque solo vende productos que existen en cada almacén (los lee con `dblink`).
- Reportes va después de todos porque sus vistas traen los datos de las otras instancias.
- `05_reportes/vistas.sql` crea las vistas materializadas **vacías** (`WITH NO DATA`); se llenan cuando corre `05_reportes/refrescar.sql`.
- En cada instancia, los roles van al final porque `GRANT … ON ALL TABLES` solo afecta a las tablas que ya existen.

### 4.3 Sobre pgAdmin

pgAdmin sirve para **mirar** las bases después de ejecutar todo, pero no para ejecutar los scripts: no entiende `\c`, `\ir`, `\getenv`, `\if` ni `\echo`. Para revisar en pgAdmin hay que registrar cada instancia como un servidor aparte (en local, `localhost` con los puertos 5441 a 5446 y usuario `postgres`) y abrir el Query Tool sobre la base que se quiera.

### 4.4 Poner los reportes al día (REFRESH)

Los reportes son **vistas materializadas**: guardan su resultado y solo cambian al refrescarlas. Para actualizarlos sin rehacer todo:

```bash
scripts/correr.sh config/local.env reportes sql/05_reportes/refrescar.sql
```

Hace `REFRESH MATERIALIZED VIEW` de todas las vistas, en orden y en una transacción: cada vista vuelve a traer los datos por `dblink`. Si una instancia no responde, el refresco falla entero y quedan los reportes anteriores. Al final muestra `reportes.vista_ultima_actualizacion`.

Para que corra solo cada cierto tiempo no hace falta `cron`: con el backend encendido, el servicio de reportes refresca las vistas cada `REFRESCO_MINUTOS` (ver [`backend/README.md`](../backend/README.md)).

## 5. Usuarios de prueba

Contraseña de todos: `Andina2026*`. Cada usuario existe **solo en las instancias a las que entra**.

| Usuario | Rol | Instancias donde existe | Alcance |
| --- | --- | --- | --- |
| admin_andina | rol_administrador | todas | Todo, puede crear roles |
| gerente_general | rol_gerencia | reportes | Solo las vistas de `reportes` |
| inventario_bogota | rol_inventario | catálogo, inventarios, reportes | Fragmento `inventarios.inv_bogota` + transferencias + 3 vistas |
| inventario_cedi | rol_inventario | catálogo, inventarios, reportes | Fragmento `inventarios.inv_cedi` + transferencias + 3 vistas |
| compras_cedi | rol_compras | catálogo, compras, reportes | Tablas de `compras` + 1 vista |
| vendedor_bogota | rol_vendedor | catálogo, ventas | `ventas.ped_bogota` / `det_ped_bogota` + pagos y devoluciones |
| vendedor_cali | rol_vendedor | catálogo, ventas | `ventas.ped_cali` / `det_ped_cali` + pagos y devoluciones |
| auditor_interno | rol_auditor | todas | SELECT de todo, salvo `usuarios.password_hash` |

Usuarios técnicos (los que usará el backend): `svc_catalogo`, `svc_identidad`, `svc_compras`, `svc_inventarios`, `svc_ventas` y `svc_reportes`. Cada uno existe **solo en la instancia de su servicio**. Se crean sin contraseña; al desplegar se les asigna con `ALTER ROLE svc_ventas PASSWORD '…';` (las contraseñas reales no van en el repositorio).

Probar un usuario sin cerrar la sesión de superusuario (en la instancia de ventas, `localhost:5445`):

```sql
SET ROLE vendedor_bogota;
SELECT COUNT(*) FROM ventas.ped_bogota;   -- permitido
SELECT COUNT(*) FROM ventas.ped_cali;     -- ERROR: permiso denegado
RESET ROLE;
```

O conectarse directamente: `psql "postgresql://vendedor_bogota:Andina2026*@localhost:5445/andina_ventas"`. Si se intenta con `gerente_general` en esa instancia, la conexión se rechaza: ese usuario no existe ahí (`role "gerente_general" does not exist`).

## 6. Consultar un fragmento por sede

```sql
-- consulta local (solo una sede): en la instancia del servicio, se lee el fragmento directamente
SELECT * FROM inventarios.inv_cali;                              -- en localhost:5444
SELECT * FROM ventas.ped_medellin WHERE estado = 'PENDIENTE';    -- en localhost:5445

-- consulta corporativa (las cuatro sedes): en la instancia de reportes (localhost:5446)
SELECT fragmento, COUNT(*) FROM reportes.vista_inventario_consolidado GROUP BY fragmento;
SELECT * FROM reportes.vista_reporte_corporativo;
```

## 7. Problemas frecuentes

| Síntoma | Causa y solución |
| --- | --- |
| `faltan las variables de conexion` | Se corrió `psql -f run_all.sql` directo. Usar `scripts/correr.sh config/local.env`. |
| `connection refused` o `could not connect to server` | Las instancias no están corriendo. `scripts/instancias_locales.sh estado` y luego `iniciar`. |
| `could not establish connection` (dblink) | `dblink` no pudo llegar a otra instancia: está apagada, o el host, puerto o contraseña del `.env` están mal. |
| `database "…" is being accessed by other users` | Hay otra conexión abierta a esa base (pgAdmin, otra ventana de psql). Cerrarla y volver a ejecutar. |
| `permission denied to create database` o `… to create role` | El usuario del `.env` no tiene permiso para crear bases o roles. En local es `postgres`; en Neon, el dueño del proyecto. |
| `relation "catalogo.productos" does not exist` | Se está en la instancia equivocada: cada tabla vive en la de su servicio (en reportes se lee con `dblink`). Revisar con `SELECT current_database(), current_setting('port');`. |
| Error en `\ir` | Ejecutar con `correr.sh`; `\ir` resuelve las rutas respecto al propio archivo. |
| Las fechas de las consultas no cambian con el día | Es intencional: la fecha de corte es fija (2026-10-15) en `reportes.parametros`. |
