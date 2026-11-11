# Scripts SQL

Guía rápida de cada script: qué hace, lo que vale la pena entender y lo que **no es SQL "de
clase"** (comandos de psql, funciones poco comunes, trucos). Para crear tablas y columnas, el
detalle está en `docs/diccionario-datos.md`; aquí va lo que destaca.

> Todo se ejecuta con `psql -U postgres -f run_all.sql` **desde la carpeta del proyecto**.
> Ver `docs/manual-ejecucion.md`.

## Cómo encaja todo

```
run_all.sql
 ├─ \c postgres           00_reset · 01_bases           → borra y crea las 6 bases
 ├─ \c andina_catalogo    02 · 07_datos_catalogo
 ├─ \c andina_identidad   03 · 07_datos_identidad
 ├─ \c andina_compras     04 · 07_datos_compras       (lee catálogo con dblink y luego lo quita)
 ├─ \c andina_inventarios 05 · 07_datos_inventarios   (lee catálogo con dblink y luego lo quita)
 ├─ \c andina_ventas      06 · 07_datos_ventas        (lee catálogo e inventarios con dblink y luego lo quita)
 ├─ \c andina_reportes    dblink/servidores · 08_vistas · refrescar_reportes
 ├─ 09_roles              (hace sus propios \c, base por base)
 ├─ \c andina_reportes    10_consultas
 └─ 11_pruebas            (hace sus propios \c, base por base)
```

**La idea:** cada microservicio tiene su base y una consulta normal **no puede leer otra base**.
`dblink` es la excepción: deja que una base ejecute una consulta en otra y traiga el resultado.
Solo `andina_reportes` lo tiene; sus vistas son **materializadas** (guardan el resultado) y se
refrescan cada X minutos con `sql/refrescar_reportes.sql`.

> Esta es la versión con `dblink`, más simple de explicar. Rompe un poco el aislamiento entre
> servicios: reportes depende de las tablas de los demás. La versión donde ninguna base se conecta
> a otra (un ETL por CSV) está en la rama `feat/microservicios-reales`.

## Comandos de psql que aparecen (no son SQL)

Lo que empieza con `\` lo ejecuta **psql**, el cliente. El servidor nunca lo ve, y por eso
pgAdmin no lo entiende.

| Comando | Qué hace | Dónde |
|---|---|---|
| `\set ON_ERROR_STOP on` | Si algo falla, psql se detiene | `run_all`, `11` (lo apaga y lo vuelve a prender) |
| `\set ON_ERROR_ROLLBACK on` | Dentro de una transacción, si una instrucción falla deshace solo esa y sigue | `11` |
| `\pset pager off` | Muestra todo seguido, sin la pantalla de "más" | `run_all` |
| `\c base` | Se conecta a otra base (cierra la conexión anterior) | `run_all`, `09`, `11` |
| `\ir archivo` | Ejecuta otro archivo con ruta relativa **a este archivo** (`\i` la tomaría relativa a donde se abrió psql) | `run_all`, `07_datos_*`, `11` |
| `\if :{?var} ... \endif` | Ejecuta el bloque solo si la variable de psql existe (`-v var=...`) | `dblink/servidores` |
| `consulta \gset` | Guarda el resultado de la consulta en variables de psql (`:nombre`) | `11` (prueba 12) |
| `\echo 'texto'` | Imprime un título en la salida | todos |

---

## `run_all.sql`
Corre todo en orden. Lo importante es **el orden**:
- catálogo va primero, porque los demás usan sus ids y sus datos de prueba lo leen con `dblink`;
- ventas va después de inventarios, porque solo vende lo que hay en cada almacén;
- reportes va después de todos, porque sus vistas traen los datos de las demás bases;
- los roles van al final, porque `GRANT ... ON ALL TABLES` solo alcanza a las tablas que ya existen.

`SET client_min_messages = warning` oculta los avisos `NOTICE` del reset ("la base no existe, se
omite"). Solo dura en esa conexión: después de cada `\c` vuelve a lo normal.

## `00_reset.sql`
Borra las 6 bases y los roles.
- Se corre conectado a la base **`postgres`**: no se puede borrar la base en la que uno está.
- `DROP DATABASE` falla si hay alguien conectado (pgAdmin abierto, por ejemplo).
- Un rol no se puede borrar si tiene permisos en alguna base. Como las bases ya se borraron, sus
  permisos se fueron con ellas.
- También borra `comercializadora`, la base de la versión anterior (todo en una base con esquemas).

## `01_bases.sql`
Crea las 6 bases (`CREATE DATABASE`), una por microservicio.
- **`REVOKE ALL ON DATABASE ... FROM PUBLIC`**: por defecto cualquier rol puede conectarse a
  cualquier base. Se le quita a todos, y `09_roles.sql` deja entrar solo a quien corresponde.
- `COMMENT ON DATABASE`: una descripción visible con `\l+`.

## `02_catalogo.sql` a `06_ventas.sql` (tablas)
Cada uno crea el esquema de su servicio (`CREATE SCHEMA catalogo`) y sus tablas.
- **El esquema se llama igual que el servicio** (`ventas.ped_bogota` en `andina_ventas`). En las
  consultas de reportes, la tabla que llega por `dblink` se llama `ventas_ped_bogota`.
- **`-- ref: catalogo.sedes`**: un id de otra tabla **sin FK**, porque está en otra base. Es el
  `FK+` del diagrama relacional.
- **`GENERATED ALWAYS AS IDENTITY`**: la base numera sola. Usa una secuencia por debajo sin tener
  que escribirla.
- **`COMMENT ON TABLE`**: documenta el microservicio responsable de cada tabla (requerimiento 18).

Lo que destaca en cada uno:

| Script | Lo que destaca |
|---|---|
| `02_catalogo` | Las tablas "base" que usan todos. `UNIQUE (tipo_documento, num_documento)`: la unicidad es de la pareja |
| `03_identidad` | `usuarios.id_empleado` es FK + `UNIQUE` = relación 1:1 |
| `04_compras` | `CHECK (fecha_estimada >= fecha_orden)`: un CHECK que compara dos columnas |
| `05_inventarios` | **Fragmentación:** 4 tablas iguales con `CHECK (id_sede = n)` y `DEFAULT n`. En transferencias, los CHECK de fechas usan `col IS NULL OR ...` para dejar pasar la fila mientras la fecha no exista |
| `06_ventas` | **Fragmentación derivada:** `det_ped_*` sigue a `ped_*` con una **FK compuesta** `(id_sede, id_pedido)`. Cada `ped_*` tiene su propio IDENTITY, así cada sede numera desde 1. Pagos y devoluciones no tienen FK al pedido: no se sabe en cuál de las 4 tablas está |

## `07_datos_<servicio>.sql` (datos de prueba)
Un script por servicio. Volúmenes y escenarios forzados están en la cabecera de cada uno.

| Truco | Qué hace |
|---|---|
| `setseed(0.2026)` | Fija la semilla de `random()`: los "números al azar" salen siempre iguales, así los datos son reproducibles. **Cada script pone la suya**, porque cada `\c` abre una sesión nueva y la semilla no pasa de una sesión a otra |
| `generate_series(1, 100)` | Genera las filas 1…100 (clientes, pedidos, órdenes) |
| `CREATE TEMP TABLE` | Tablas que desaparecen al cerrar la sesión. Ahí se arma todo y después se reparte a los fragmentos con `WHERE id_sede = n` |
| `dblink('srv_catalogo', 'SELECT ...') AS t(...)` | Cuando un servicio necesita datos de otro (ventas necesita los precios de catálogo), los trae con `dblink` a una tabla temporal. Al terminar, `\ir dblink/quitar.sql` quita `dblink` de esa base, para que el servicio no quede conectado a otra. En el sistema real sería una llamada HTTP |
| `ARRAY['a','b'][i]` | Sacar un valor de una lista por posición (nombres, medios de pago) |
| `ROW_NUMBER() OVER (PARTITION BY id_sede ...)` | Numerar los pedidos de cada sede desde 1, igual que lo hará el IDENTITY de cada fragmento |
| `md5(...)` | Un hash **de ejemplo** para las contraseñas. MD5 no sirve para contraseñas reales; el backend usará bcrypt |
| `UPDATE ... FROM (subconsulta)` | Actualizar filas con valores calculados en otra consulta (el total de cada pedido) |
| `x::int`, `floor()`, `round()`, `lpad()` | Conversión de tipo, redondeos y rellenar con ceros |

## `dblink/servidores.sql` y `dblink/quitar.sql`
**`dblink`** es una extensión de PostgreSQL (viene en el paquete *contrib*) para consultar otra base
desde la base actual:

```sql
SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, nombre FROM catalogo.productos')
         AS t(id_producto INTEGER, nombre VARCHAR(100));
```

- **El primer argumento** dice a qué base conectarse; **el segundo** es la consulta, como texto,
  que se ejecuta **allá**.
- **`AS t(...)` es obligatorio:** `dblink` no sabe qué columnas trae, hay que decirle el nombre y el
  tipo de cada una.
- **`CREATE EXTENSION dblink`** la instala en la base actual. Hay que hacerlo en cada base que la use.
- **Servidores remotos** (`CREATE SERVER srv_catalogo FOREIGN DATA WRAPPER dblink_fdw ...`): en vez
  de repetir los datos de conexión en cada llamada (`'dbname=andina_catalogo user=postgres ...'`),
  cada base se registra una vez con un nombre. **`CREATE USER MAPPING`** guarda con qué usuario (y
  contraseña, si hace falta) se conecta.
- **Sin contraseña en el repo:** por defecto se conecta como `postgres` por el socket local. Si la
  instalación pide contraseña, se pasa al correr: `psql -v dblink_host=localhost -v dblink_password=...`.
- **`quitar.sql`** hace `DROP EXTENSION dblink CASCADE` (también borra los servidores). Lo usan los
  datos de prueba: el servicio usa `dblink` solo mientras arma sus datos.
- **Por qué rompe un poco la arquitectura:** con `dblink` reportes depende de las tablas de los otros
  servicios. Si catálogo cambia una columna, las vistas de reportes se rompen.

## `refrescar_reportes.sql`
Hace `REFRESH MATERIALIZED VIEW` de todas las vistas de reportes. Cada refresco vuelve a ejecutar la
consulta de la vista, o sea, vuelve a traer los datos por `dblink`.
- **En orden:** primero las consolidadas, después las que leen de ellas, al final
  `vista_alertas_reabastecimiento` (lee `vista_inventario_por_sede`) y `vista_ultima_actualizacion`.
- **En una transacción:** o se actualizan todas o ninguna. Si una base no responde, quedan los
  reportes anteriores.
- **Cada X minutos** (no visto en clase): con `cron` en el servidor.
  ```
  */5 * * * * psql -U postgres -d andina_reportes -f /ruta/del/proyecto/sql/refrescar_reportes.sql
  ```
  `*/5 * * * *` = cada 5 minutos. Cuando exista el backend, lo hará el servicio de reportes.

## `08_vistas.sql`
Corre en `andina_reportes`. El esquema `reportes` **solo tiene vistas**, y casi todas son
**materializadas** (no visto en clase):
- **Vista normal:** una consulta guardada con nombre. No guarda datos; cada vez que se lee, se
  ejecuta.
- **Vista materializada** (`CREATE MATERIALIZED VIEW`): ejecuta la consulta y **guarda el
  resultado**, como una tabla. Leerla es rápido, pero no cambia sola: se actualiza con
  `REFRESH MATERIALIZED VIEW` (lo hace `refrescar_reportes.sql`). Es "la vista que se va
  actualizando cada X minutos". Además, así cada lectura de un reporte no tiene que ir por `dblink`
  a las otras bases: `dblink` solo trabaja al refrescar.
- **Cómo se lee cada vista:** arriba, en el `WITH`, hay una CTE por cada tabla de otra base, con su
  llamada a `dblink` (`catalogo_productos AS (SELECT * FROM dblink('srv_catalogo', ...) AS t(...))`).
  Después la consulta usa `catalogo_productos` como si fuera la tabla.
- **`WITH NO DATA`:** la crea vacía, sin ejecutar la consulta. Se llena en el primer `REFRESH`;
  antes, leerla da error ("no ha sido poblada").
- **El orden de refresco importa:** si una vista lee de otra, la de abajo se refresca primero
  (primero las consolidadas, al final `vista_alertas_reabastecimiento`, que lee
  `vista_inventario_por_sede`).
- `parametros` es una vista **normal** (son constantes). `vista_ultima_actualizacion` es una vista
  materializada de una fila con `now()`: como se refresca al final, guarda la hora del último refresco.
- 🔁 `REFRESH ... CONCURRENTLY` deja leer mientras refresca, pero exige un índice UNIQUE (no
  vimos índices). Con estos datos el bloqueo dura casi nada.

- **`reportes.parametros`**: una vista con la fecha de corte fija (2026-10-15) y los umbrales.
  Las consultas la usan en vez de `current_date`, así los resultados no cambian según el día.
- **Vistas consolidadas** (`vista_*_consolidado`): `UNION ALL` de los 4 fragmentos, con una
  columna `fragmento` que dice de qué base y tabla viene cada fila (`andina_ventas.ped_cali`). `UNION ALL` y no `UNION`: no puede
  haber repetidos (el CHECK de cada sede lo impide), así que buscarlos sería trabajo perdido.
- **Las 10 obligatorias**, encima de las consolidadas.
- **`vista_reporte_corporativo`**: agrega **cada fuente por separado** (una CTE por fuente) antes de
  unirlas. Si se uniera todo en un solo JOIN, cada pedido se sumaría una vez por cada línea
  (conteo duplicado; la prueba 10 lo muestra).
- **Permisos:** una vista materializada ya tiene el resultado guardado, así que leerla solo pide
  permiso sobre la vista. Por eso gerencia lee los reportes sin poder usar `dblink` ni entrar a las
  otras bases. El `REFRESH` corre con los permisos del **dueño** de la vista (postgres).
- **`COALESCE(x, 0)`** (no visto en clase; es `CASE WHEN x IS NULL THEN 0 ELSE x END`):
  después de un `LEFT JOIN`, convierte en 0 lo que no tiene pareja. Sin él, un pedido sin pagos
  quedaría con saldo NULL y desaparecería de los reportes.
- `date_trunc('month', fecha)`: lleva una fecha al primer día de su mes, para agrupar por mes.

## `09_roles.sql`
Roles, usuarios y permisos, en dos niveles:
1. **`GRANT CONNECT ON DATABASE`:** a qué bases entra cada rol. La matriz está en la cabecera.
2. **Dentro de cada base** (por eso hay un `\c` por base): `GRANT USAGE ON SCHEMA` y luego
   `SELECT/INSERT/UPDATE` en las tablas. Un `GRANT` sobre tablas solo funciona conectado a la base
   donde están.

Lo que destaca:
- **Grupos (`NOLOGIN`) + usuarios (`LOGIN ... IN ROLE grupo`):** el permiso se da una vez al grupo.
  Lo que depende de la sede (la tabla de su sede) se da al usuario.
- **Usuarios técnicos `svc_*`:** uno por servicio, cada uno entra solo a su base. Se crean **sin
  contraseña**: se les pone al desplegar con `ALTER ROLE svc_x PASSWORD '...'`, sacada del `.env`.
- **Permiso por columna:** `GRANT SELECT (col1, col2, ...) ON identidad.usuarios` deja al auditor
  ver todo menos `password_hash`.
- **`REVOKE` a propósito:** al vendedor se le da `DELETE` y luego se le quita, para demostrar
  `REVOKE` (lo pide la sección 8). La prueba 9.6 lo comprueba.
- **`WITH GRANT OPTION`:** el administrador puede conceder sus permisos a otros.
- **`MAINTAIN`** (PostgreSQL 17+): el permiso para hacer `REFRESH` de una vista materializada sin ser
  su dueño. Se le da a `svc_reportes`, que refrescará los reportes cuando exista el backend. Por esto
  el proyecto necesita PostgreSQL 17 o superior.
- **`REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC`** (en `andina_reportes`): por
  defecto cualquiera puede ejecutar las funciones de `dblink`. Se le quita a todos, así solo
  postgres va a las otras bases (prueba 9.1b).

## `10_consultas.sql`
Las 20 consultas, en `andina_reportes`. Igual que las vistas: cada tabla de otra base llega por
`dblink` en una CTE arriba del `WITH` (`catalogo_productos`, `ventas_pagos`…), y las vistas
`reportes.*` son las materializadas.
La tabla de la cabecera dice en qué consulta aparece cada cosa que pide el enunciado (JOIN, CTE,
ventanas, conjuntos…).
- `string_agg(DISTINCT x, ', ' ORDER BY x)`: junta varios valores en un solo texto (las sedes que
  visitó un cliente, consulta 6).
- `to_char(fecha, 'YYYY-MM')`: formatea una fecha como texto.
- Funciones de ventana: `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, `SUM(...) OVER (PARTITION BY ...)`.
  Calculan sobre otras filas **sin agruparlas**.

## `11_pruebas.sql`
Las pruebas de la sección 11 del enunciado, **agrupadas por base** (cada parte hace su `\c`).
Por eso los números no van en orden: la prueba 9 de permisos está repartida en varias bases.
- **`BEGIN ... ROLLBACK` por base:** nada de lo que hacen las pruebas queda guardado. Una
  transacción no puede abarcar dos bases.
- **Los `ERROR` son el resultado esperado** en las pruebas de rechazo: cada título dice
  `-> esperado: ERROR ...`.
- **`SET ROLE x` / `RESET ROLE`:** actuar como otro usuario sin reconectarse, para probar sus
  permisos. Ojo: `SET ROLE` **no** revisa `CONNECT` (eso se revisa solo al conectarse). Por eso la
  prueba 11.3 usa `has_database_privilege` para mostrar a qué bases entra cada rol.
- **`RETURNING`:** un `INSERT` o `UPDATE` que además muestra lo que guardó.
- **Prueba 9.1b:** gerencia intenta usar `dblink` y recibe "permiso denegado para la función dblink".
- **Prueba 11 (aislamiento):** desde `andina_ventas`, leer `catalogo.productos` da "la relación no
  existe", y nombrar la otra base (`andina_catalogo.catalogo.productos`) da "cross-database
  references are not implemented". Sin `dblink`, PostgreSQL no puede ir a otra base, y ventas no lo
  tiene (se le quitó al terminar sus datos de prueba).
- **Prueba extra (referencias sin FK):** cuenta con `NOT EXISTS` los ids que apuntan a algo que no
  existe (huérfanos). Corre en reportes, que puede leer las demás bases con `dblink`. Todas deben dar 0.
- **Prueba 12 (vistas materializadas y consistencia eventual):** se guarda un pedido nuevo en
  `andina_ventas` y el reporte **no lo ve**. Se corre `refrescar_reportes.sql` y **ahora sí**. Esta
  prueba no va en `ROLLBACK` (el refresco tiene que ver el pedido guardado), así que al final borra
  el pedido y refresca otra vez. `RETURNING id_pedido AS pedido_prueba \gset` guarda el id en
  `:pedido_prueba` para poder borrarlo.
