# Scripts SQL

Cada microservicio vive en **su propia instancia** de PostgreSQL. Todo se corre de una con:

```bash
scripts/instancias_locales.sh iniciar     # levanta las 6 instancias en tu pc
scripts/correr.sh config/local.env        # corre run_all.sql contra ellas
```

(ver `docs/despliegue.md` para Neon). Cada carpeta tiene su README con la explicación del código; los
scripts tienen solo comentarios cortos.

## Carpetas, en el orden en que se usan

| Carpeta | Qué hay | Corre en |
|---|---|---|
| [`00_config/`](00_config/README.md) | Leer a dónde se conecta cada servicio (host, puerto, usuario, clave) | — |
| [`01_bases/`](01_bases/README.md) | Borrar y crear la base de cada instancia | la base de administración de cada instancia |
| [`02_tablas/`](02_tablas/README.md) | Las tablas de cada servicio, incluida la fragmentación por sede | la base de cada servicio |
| [`03_dblink/`](03_dblink/README.md) | Instalar y quitar `dblink`, para consultar otra base | donde se necesite |
| [`04_datos/`](04_datos/README.md) | Los datos de prueba de cada servicio | la base de cada servicio |
| [`05_reportes/`](05_reportes/README.md) | Las vistas materializadas de reportes y su refresco | `andina_reportes` |
| [`06_roles/`](06_roles/README.md) | Roles, usuarios y permisos, un archivo por instancia (con la matriz de permisos) | cada instancia |
| [`07_consultas/`](07_consultas/README.md) | Las 20 consultas | `andina_reportes` |
| [`08_pruebas/`](08_pruebas/README.md) | Las pruebas de verificación | todas (hace sus `\c`) |

## Qué hace run_all.sql

```
00_config/conexiones                 lee config/*.env: la direccion de cada instancia
para cada servicio (catalogo, identidad, compras, inventarios, ventas):
  \c :conn_<servicio>_admin           01_bases: reset + crear
  \c :conn_<servicio>                 02_tablas + 04_datos + 06_roles   (compras, inventarios
                                      y ventas usan dblink en sus datos y lo quitan)
reportes:
  \c :conn_reportes_admin             01_bases: reset + crear
  \c :conn_reportes                   03_dblink/servidores + 05_reportes/vistas + refrescar
                                      + 06_roles/reportes
  \c :conn_reportes                   07_consultas
                                      08_pruebas (hace sus \c)
```

**Por qué ese orden:**
- catálogo va primero: los demás usan sus ids, y sus datos de prueba lo leen;
- ventas va después de inventarios: solo vende lo que hay en cada almacén;
- reportes va después de todos: sus vistas traen los datos de las demás instancias;
- en cada instancia los roles van al final: `GRANT ... ON ALL TABLES` solo alcanza a las tablas que
  ya existen.

## La idea en corto

- **Una instancia de PostgreSQL por microservicio**, cada una con su base y sus roles. Una consulta
  normal no puede leer otra base, así que cada servicio es dueño de sus datos.
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
| `\c :conn_ventas` | Se conecta a otra instancia o base (cierra la conexión anterior). `:conn_ventas` es una dirección `postgresql://...` | `run_all`, `08_pruebas` |
| `\getenv var NOMBRE` | Copia una variable de entorno a una variable de psql | `00_config` |
| `\ir archivo` | Ejecuta otro archivo, con la ruta relativa **a este archivo** (`\i` la tomaría relativa a donde se abrió psql) | `run_all`, `04_datos`, `08_pruebas` |
| `\if :var ... \endif` | Ejecuta el bloque solo si la variable es verdadera (o, con `:{?var}`, si existe) | `00_config`, `06_roles` |
| `consulta \gset` | Guarda el resultado de la consulta en variables de psql (`:nombre`) | `08_pruebas` (prueba 12) |
| `\echo 'texto'` | Imprime un título en la salida | todos |

`SET client_min_messages = warning` (esto sí es SQL) oculta los avisos `NOTICE` del reset ("la base no
existe, se omite"). Solo dura en esa conexión.

## Lo que no vimos en clase y aparece aquí

| Qué | Dónde | Explicado en |
|---|---|---|
| `dblink` y las conexiones guardadas (`remoto.servidor(...)`) | reportes, datos de prueba | `03_dblink/` |
| Vistas materializadas, `REFRESH`, `WITH NO DATA` | reportes | `05_reportes/` |
| Programar el refresco cada X minutos (`cron`) | reportes | `05_reportes/` |
| `GRANT MAINTAIN` (PostgreSQL 17+) | roles | `06_roles/` |
| `COALESCE` | vistas, consultas | `07_consultas/` |
| `setseed`, `generate_series`, tablas temporales | datos de prueba | `04_datos/` |
| Comandos de psql (`\c`, `\ir`, `\if`, `\gset`) | varios | arriba |
