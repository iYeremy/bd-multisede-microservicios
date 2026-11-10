# Scripts SQL

Guía rápida de cada script: qué hace, lo que vale la pena entender y lo que **no es SQL "de
clase"** (comandos de psql, funciones poco comunes, trucos). Para crear tablas y columnas, el
detalle está en `docs/diccionario-datos.md`; aquí va lo que destaca.

> Todo se ejecuta con `psql -U postgres -f run_all.sql` **desde la carpeta del proyecto**.
> Ver `docs/manual-ejecucion.md`.

## Cómo encaja todo

```
run_all.sql
 ├─ \c postgres          00_reset · 01_bases           → borra y crea las 6 bases
 ├─ \c andina_catalogo   02 · 07_datos_catalogo · sync/exportar_catalogo
 ├─ \c andina_identidad  03 · 07_datos_identidad · sync/exportar_identidad
 ├─ \c andina_compras    04 · 07_datos_compras · sync/exportar_compras
 ├─ \c andina_inventarios 05 · 07_datos_inventarios · sync/exportar_inventarios
 ├─ \c andina_ventas     06 · 07_datos_ventas · sync/exportar_ventas
 ├─ \c andina_reportes   02–06 (copia) · sync/importar_reportes · 08_vistas
 ├─ 09_roles             (hace sus propios \c, base por base)
 ├─ \c andina_reportes   10_consultas
 └─ 11_pruebas           (hace sus propios \c, base por base)
```

**Regla de oro:** cada microservicio tiene su base y una consulta **no puede leer otra base**.
Por eso los datos viajan entre bases por archivos CSV (`csv/`), y reportes trabaja sobre su
propia copia.

## Comandos de psql que aparecen (no son SQL)

Lo que empieza con `\` lo ejecuta **psql**, el cliente. El servidor nunca lo ve, y por eso
pgAdmin no lo entiende.

| Comando | Qué hace | Dónde |
|---|---|---|
| `\set ON_ERROR_STOP on` | Si algo falla, psql se detiene | `run_all`, `11` (lo apaga y lo vuelve a prender) |
| `\set ON_ERROR_ROLLBACK on` | Dentro de una transacción, si una instrucción falla deshace solo esa y sigue | `11` |
| `\pset pager off` | Muestra todo seguido, sin la pantalla de "más" | `run_all` |
| `\c base` | Se conecta a otra base (cierra la conexión anterior) | `run_all`, `09`, `11` |
| `\ir archivo` | Ejecuta otro archivo con ruta relativa **a este archivo** (`\i` la tomaría relativa a donde se abrió psql) | `run_all` |
| `\copy ... TO 'archivo'` | Exporta una tabla a un archivo **del computador donde corre psql** | `sync/exportar_*` |
| `\copy ... FROM 'archivo'` | Importa un archivo a una tabla | `sync/importar_reportes`, `07_datos_*` |
| `\echo 'texto'` | Imprime un título en la salida | todos |

`\copy` vs `COPY`: `COPY` es SQL y usa archivos **del servidor** (pide superusuario); `\copy` es
de psql y usa archivos **del cliente**. Por eso usamos `\copy`. La ruta `csv/` es relativa a la
carpeta desde donde se lanzó psql: de ahí que haya que correr todo desde la carpeta del proyecto.

---

## `run_all.sql`
Corre todo en orden. Lo importante es **el orden**:
- catálogo va primero, porque los demás usan sus ids y leen sus CSV;
- ventas va después de inventarios, porque solo vende lo que hay en cada almacén;
- reportes va después de todos, porque carga los CSV que dejan los demás;
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
- **Se corren dos veces:** en la base del servicio y en `andina_reportes`, para crear ahí la copia
  con las mismas columnas y restricciones.
- **El esquema se llama igual que el servicio** para que las tablas tengan el mismo nombre en su
  base y en la copia (`ventas.ped_bogota`). Así las vistas y consultas no cambian.
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
| `\copy tmp_x FROM 'csv/...'` | Cuando un servicio necesita datos de otro (ventas necesita los precios de catálogo), los lee del CSV que publicó el dueño. En el sistema real sería una llamada HTTP |
| `ARRAY['a','b'][i]` | Sacar un valor de una lista por posición (nombres, medios de pago) |
| `ROW_NUMBER() OVER (PARTITION BY id_sede ...)` | Numerar los pedidos de cada sede desde 1, igual que lo hará el IDENTITY de cada fragmento |
| `md5(...)` | Un hash **de ejemplo** para las contraseñas. MD5 no sirve para contraseñas reales; el backend usará bcrypt |
| `UPDATE ... FROM (subconsulta)` | Actualizar filas con valores calculados en otra consulta (el total de cada pedido) |
| `x::int`, `floor()`, `round()`, `lpad()` | Conversión de tipo, redondeos y rellenar con ceros |

## `sync/exportar_<servicio>.sql` y `sync/importar_reportes.sql`
El puente entre bases.
- **Exportar** (en cada base): `\copy tabla TO 'csv/esquema.tabla.csv' WITH (FORMAT csv, HEADER)`.
  `HEADER` pone los nombres de las columnas en la primera línea.
- **Importar** (en `andina_reportes`): lo mismo con `FROM`, en orden de padres a hijas por las FK.
- `\copy FROM` **sí guarda el id** que trae el archivo aunque la columna sea
  `GENERATED ALWAYS AS IDENTITY`. Así la copia queda con los mismos ids que el original.
- De identidad solo se exporta `empleados`: usuarios y auditoría tienen contraseñas y no salen
  de su servicio.

> **Próximo cambio:** esto se convierte en un **ETL** explícito: un script que se puede volver a
> correr cada X minutos, que recarga el staging y refresca **vistas materializadas**
> (`REFRESH MATERIALIZED VIEW`). Esta sección se actualiza cuando esté implementado.

## `08_vistas.sql`
Corre en `andina_reportes`. El esquema `reportes` **solo tiene vistas**.
- **`reportes.parametros`**: una vista con la fecha de corte fija (2026-10-15) y los umbrales.
  Las consultas la usan en vez de `current_date`, así los resultados no cambian según el día.
- **Vistas consolidadas** (`vista_*_consolidado`): `UNION ALL` de los 4 fragmentos, con una
  columna `fragmento` que dice de qué tabla viene cada fila. `UNION ALL` y no `UNION`: no puede
  haber repetidos (el CHECK de cada sede lo impide), así que buscarlos sería trabajo perdido.
- **Las 10 obligatorias**, encima de las consolidadas.
- **`vista_reporte_corporativo`**: agrega **cada fuente por separado** (una CTE por fuente) antes de
  unirlas. Si se uniera todo en un solo JOIN, cada pedido se sumaría una vez por cada línea
  (conteo duplicado; la prueba 10 lo muestra).
- **Permisos:** una vista lee las tablas con los permisos de **su dueño**. Por eso gerencia puede
  leer los reportes sin tener permisos sobre las tablas.
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

## `10_consultas.sql`
Las 20 consultas, en `andina_reportes` (el único lugar con los datos de todos los servicios).
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
- **Prueba 11 (aislamiento):** desde `andina_ventas`, leer `catalogo.productos` da "la relación no
  existe", y nombrar la otra base (`andina_catalogo.catalogo.productos`) da "cross-database
  references are not implemented". Es la evidencia de que cada base está aislada.
- **Prueba extra (referencias sin FK):** cuenta con `NOT EXISTS` los ids que apuntan a algo que no
  existe (huérfanos). Corre en reportes, sobre la copia, porque es el único lugar donde se pueden
  cruzar los datos de varios servicios. Todas deben dar 0.
