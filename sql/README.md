# Scripts SQL

Todo se corre de una con `psql -U postgres -f run_all.sql` (ver `docs/manual-ejecucion.md`). Cada
carpeta tiene su README con la explicación del código; los scripts tienen solo comentarios cortos.

## Carpetas, en el orden en que se usan

| Carpeta | Qué hay | Corre en |
|---|---|---|
| [`01_bases/`](01_bases/README.md) | Borrar todo y crear las 6 bases, una por microservicio | `postgres` |
| [`02_tablas/`](02_tablas/README.md) | Las tablas de cada servicio, incluida la fragmentación por sede | la base de cada servicio |
| [`03_dblink/`](03_dblink/README.md) | Instalar y quitar `dblink`, para consultar otra base | donde se necesite |
| [`04_datos/`](04_datos/README.md) | Los datos de prueba de cada servicio | la base de cada servicio |
| [`05_reportes/`](05_reportes/README.md) | Las vistas materializadas de reportes y su refresco | `andina_reportes` |
| [`06_roles/`](06_roles/README.md) | Roles, usuarios y permisos (con la matriz de permisos) | todas (hace sus `\c`) |
| [`07_consultas/`](07_consultas/README.md) | Las 20 consultas | `andina_reportes` |
| [`08_pruebas/`](08_pruebas/README.md) | Las pruebas de verificación | todas (hace sus `\c`) |

## Qué hace run_all.sql

```
\c postgres            01_bases: reset + bases
\c andina_catalogo     02_tablas/catalogo    + 04_datos/catalogo
\c andina_identidad    02_tablas/identidad   + 04_datos/identidad
\c andina_compras      02_tablas/compras     + 04_datos/compras      (usa dblink y lo quita)
\c andina_inventarios  02_tablas/inventarios + 04_datos/inventarios  (usa dblink y lo quita)
\c andina_ventas       02_tablas/ventas      + 04_datos/ventas       (usa dblink y lo quita)
\c andina_reportes     03_dblink/servidores + 05_reportes/vistas + 05_reportes/refrescar
                       06_roles/roles
\c andina_reportes     07_consultas
                       08_pruebas
```

**Por qué ese orden:**
- catálogo va primero: los demás usan sus ids, y sus datos de prueba lo leen;
- ventas va después de inventarios: solo vende lo que hay en cada almacén;
- reportes va después de todos: sus vistas traen los datos de las demás bases;
- los roles van al final: `GRANT ... ON ALL TABLES` solo alcanza a las tablas que ya existen.

## La idea en corto

- **Una base por microservicio.** Una consulta normal no puede leer otra base, así que cada servicio
  es dueño de sus datos.
- **Inventarios y pedidos van partidos por sede** (fragmentación horizontal): una tabla por sede con
  `CHECK (id_sede = n)`.
- **Reportes usa `dblink`** para traer los datos de las otras bases, y los guarda en **vistas
  materializadas** que se refrescan cada X minutos (`05_reportes/refrescar.sql`).

> Esta es la versión con `dblink`, más simple de explicar. Rompe un poco el aislamiento entre
> servicios: reportes depende de las tablas de los demás. La versión donde ninguna base se conecta a
> otra (un ETL por CSV) está en la rama `feat/microservicios-reales`.

## Comandos de psql que aparecen (no son SQL)

Lo que empieza con `\` lo ejecuta **psql**, el cliente. El servidor nunca lo ve, y por eso pgAdmin no
lo entiende: estos scripts se corren con psql.

| Comando | Qué hace | Dónde |
|---|---|---|
| `\set ON_ERROR_STOP on` | Si algo falla, psql se detiene en vez de seguir con todo a medio crear | `run_all`, `08_pruebas` (lo apaga y lo vuelve a prender) |
| `\set ON_ERROR_ROLLBACK on` | Dentro de una transacción, si una instrucción falla deshace solo esa y sigue | `08_pruebas` |
| `\pset pager off` | Muestra todo seguido, sin la pantalla de "más" | `run_all` |
| `\c base` | Se conecta a otra base (cierra la conexión anterior) | `run_all`, `06_roles`, `08_pruebas` |
| `\ir archivo` | Ejecuta otro archivo, con la ruta relativa **a este archivo** (`\i` la tomaría relativa a donde se abrió psql) | `run_all`, `04_datos`, `08_pruebas` |
| `\if :{?var} ... \endif` | Ejecuta el bloque solo si existe la variable de psql (`psql -v var=...`) | `03_dblink/servidores` |
| `consulta \gset` | Guarda el resultado de la consulta en variables de psql (`:nombre`) | `08_pruebas` (prueba 12) |
| `\echo 'texto'` | Imprime un título en la salida | todos |

`SET client_min_messages = warning` (esto sí es SQL) oculta los avisos `NOTICE` del reset ("la base no
existe, se omite"). Solo dura en esa conexión.

## Lo que no vimos en clase y aparece aquí

| Qué | Dónde | Explicado en |
|---|---|---|
| `dblink`, `CREATE SERVER`, `CREATE USER MAPPING` | reportes, datos de prueba | `03_dblink/` |
| Vistas materializadas, `REFRESH`, `WITH NO DATA` | reportes | `05_reportes/` |
| Programar el refresco cada X minutos (`cron`) | reportes | `05_reportes/` |
| `GRANT MAINTAIN` (PostgreSQL 17+) | roles | `06_roles/` |
| `COALESCE` | vistas, consultas | `07_consultas/` |
| `setseed`, `generate_series`, tablas temporales | datos de prueba | `04_datos/` |
| Comandos de psql (`\c`, `\ir`, `\if`, `\gset`) | varios | arriba |
