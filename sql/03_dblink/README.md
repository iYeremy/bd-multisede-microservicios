# 03_dblink: consultar otra base

Una consulta normal de PostgreSQL no puede leer tablas de otra base, y menos de otra instancia.
**`dblink`** es la excepción: es una extensión (viene con PostgreSQL, en el paquete *contrib*) que
deja ejecutar una consulta en **otra base** y traer el resultado como si fuera una tabla.

| Archivo | Qué hace |
|---|---|
| `servidores.sql` | Instala `dblink` en la base actual y guarda cómo conectarse a cada una de las otras instancias |
| `quitar.sql` | Quita `dblink` y las conexiones guardadas de la base actual |

## Cómo se usa

```sql
SELECT p.id_producto, p.nombre
FROM dblink(remoto.servidor('catalogo'), 'SELECT id_producto, nombre FROM catalogo.productos')
     AS p(id_producto INTEGER, nombre VARCHAR(100));
```

- **Primer argumento:** a dónde conectarse. `remoto.servidor('catalogo')` devuelve la conexión a la
  instancia de catálogo (ver abajo).
- **Segundo argumento:** la consulta, como texto. **Se ejecuta allá**, en la otra instancia.
- **`AS p(...)` es obligatorio:** `dblink` no sabe qué columnas trae, así que hay que decirle el
  nombre y el tipo de cada una, en el mismo orden del `SELECT`. `p` es el alias, como el de
  cualquier tabla.
- Se puede usar en el `FROM` o en un `JOIN`, como una tabla más:
  ```sql
  FROM reportes.vista_inventario_consolidado i
  JOIN dblink(remoto.servidor('catalogo'), 'SELECT id_producto, nombre FROM catalogo.productos')
       AS p(id_producto INTEGER, nombre VARCHAR(100)) ON p.id_producto = i.id_producto
  ```

## servidores.sql: dónde está cada instancia

`dblink` necesita la conexión completa de la otra instancia: host, puerto, base, usuario, contraseña
y SSL. Para no repetirla en cada consulta, se guarda una sola vez:

1. **`CREATE EXTENSION IF NOT EXISTS dblink`:** instala `dblink` en la base actual. Hay que hacerlo en
   cada base que lo vaya a usar.
2. **Un esquema privado `remoto`** (`REVOKE ALL ON SCHEMA remoto FROM PUBLIC`): solo su dueño lo
   puede usar, porque las conexiones llevan contraseña.
3. **La tabla `remoto.servidores`:** una fila por servicio, con su cadena de conexión
   (`host=... port=... dbname=... user=... sslmode=... password=...`).
4. **La función `remoto.servidor('catalogo')`:** devuelve la conexión de ese servicio. Es una
   consulta de una línea (`SELECT conexion FROM remoto.servidores WHERE nombre = ...`) guardada con
   nombre, para escribir `dblink(remoto.servidor('catalogo'), ...)` en vez de toda la conexión.

- **De dónde salen los datos:** `:'ventas_host'`, `:'ventas_password'`… son variables de psql que
  vienen de `config/*.env` (ver `00_config/`). **La contraseña nunca queda en el repositorio**: solo
  dentro de la base, en la tabla privada.
- **La contraseña solo se agrega si existe** (`CASE WHEN ... <> ''`). En local va vacía, porque las
  instancias entran sin clave y postgres es superusuario. En Neon sí hace falta: si quien conecta no
  es superusuario, `dblink` exige contraseña.

### ¿Por qué no `CREATE SERVER`?

La forma "de libro" de registrar otra base para `dblink` es `CREATE SERVER ... FOREIGN DATA WRAPPER
dblink_fdw` más un `CREATE USER MAPPING`. Funciona si eres superusuario, pero **en Neon no**: el
conector `dblink_fdw` es del superusuario interno de Neon y nadie más lo puede usar (`permission
denied for foreign-data wrapper dblink_fdw`). La tabla `remoto.servidores` hace lo mismo y funciona
igual con y sin superusuario, así que local y Neon usan el mismo código.

## quitar.sql

`DROP SCHEMA remoto CASCADE` (la tabla y la función) y `DROP EXTENSION dblink`.

Lo usan los datos de prueba (`04_datos/`): ventas, compras e inventarios usan `dblink` **solo
mientras arman sus datos** (por ejemplo, ventas necesita los precios de catálogo) y al terminar se lo
quitan. Así, al final, la única base con `dblink` y conexiones guardadas es `andina_reportes`.

## Quién usa dblink

| Base | Para qué | Se queda con dblink |
|---|---|---|
| `andina_compras`, `andina_inventarios`, `andina_ventas` | Leer catálogo (e inventarios) para armar los datos de prueba | No, lo quitan al terminar |
| `andina_reportes` | Traer los datos de todas las instancias para los reportes | Sí |

## Por qué "rompe un poco" la arquitectura

En microservicios, cada servicio es dueño de sus datos y nadie más los lee directamente. Con
`dblink`, reportes **sí** lee las tablas de los otros servicios. Eso tiene un costo:
- reportes depende de cómo están hechas esas tablas: si catálogo cambia una columna, las vistas de
  reportes se rompen;
- reportes guarda usuario y contraseña de las otras instancias;
- las bases ya no están del todo aisladas.

Es la versión más simple de explicar. La alternativa donde ninguna base se conecta a otra (un ETL
que pasa los datos por CSV) está en la rama `feat/microservicios-reales`.

## Seguridad

- **Las conexiones están en el esquema privado `remoto`:** gerencia, por ejemplo, puede leer los
  reportes pero no ver ni usar esas conexiones. La prueba 9.1b lo muestra: al intentarlo recibe
  "permiso denegado para el esquema remoto".
- **Sin esas conexiones, nadie que no sea superusuario puede usar `dblink`**, porque `dblink` exige
  contraseña a quien no es superusuario, y las contraseñas de las otras instancias no las tiene.
- **Las vistas sí funcionan para todos:** el `REFRESH` corre con los permisos del dueño de las vistas,
  que sí puede usar `remoto`.
