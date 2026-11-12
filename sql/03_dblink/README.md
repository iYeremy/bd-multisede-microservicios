# 03_dblink: consultar otra base

Una consulta normal de PostgreSQL no puede leer tablas de otra base. **`dblink`** es la excepción:
es una extensión (viene con PostgreSQL, en el paquete *contrib*) que deja ejecutar una consulta en
**otra base** y traer el resultado como si fuera una tabla.

| Archivo | Qué hace |
|---|---|
| `servidores.sql` | Instala `dblink` en la base actual y registra las otras bases con un nombre |
| `quitar.sql` | Quita `dblink` de la base actual |

## Cómo se usa

```sql
SELECT p.id_producto, p.nombre
FROM dblink('srv_catalogo', 'SELECT id_producto, nombre FROM catalogo.productos')
     AS p(id_producto INTEGER, nombre VARCHAR(100));
```

- **Primer argumento:** a qué base conectarse (`srv_catalogo` = `andina_catalogo`).
- **Segundo argumento:** la consulta, como texto. **Se ejecuta allá**, en la otra base.
- **`AS p(...)` es obligatorio:** `dblink` no sabe qué columnas trae, así que hay que decirle el
  nombre y el tipo de cada una, en el mismo orden del `SELECT`. `p` es el alias, como el de
  cualquier tabla.
- Se puede usar en el `FROM` o en un `JOIN`, como una tabla más:
  ```sql
  FROM reportes.vista_inventario_consolidado i
  JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre FROM catalogo.productos')
       AS p(id_producto INTEGER, nombre VARCHAR(100)) ON p.id_producto = i.id_producto
  ```

## servidores.sql

- **`CREATE EXTENSION IF NOT EXISTS dblink`:** la instala en la base actual. Hay que hacerlo en cada
  base que la vaya a usar.
- **`CREATE SERVER srv_catalogo FOREIGN DATA WRAPPER dblink_fdw OPTIONS (dbname 'andina_catalogo')`:**
  registra la otra base con un nombre. Sin esto, cada llamada tendría que llevar los datos de
  conexión completos (`'dbname=andina_catalogo user=postgres ...'`). `dblink_fdw` es el "conector"
  que trae la extensión.
- **`CREATE USER MAPPING FOR CURRENT_USER SERVER ... OPTIONS (user 'postgres')`:** con qué usuario se
  conecta a esa base. `CURRENT_USER` es quien corre el script (postgres).
- **Sin `host` ni `port`** se conecta al mismo servidor, por el socket local.
- **Si tu PostgreSQL pide contraseña** para conectarse, se le pasa al correr y no queda en el repo:
  ```
  psql -U postgres -v dblink_host=localhost -v dblink_password=... -f run_all.sql
  ```
  `\if :{?dblink_host}` es un comando de psql: ejecuta el bloque solo si esa variable existe.

## quitar.sql

`DROP EXTENSION dblink CASCADE`. `CASCADE` borra también lo que depende de la extensión (los
servidores `srv_*` y sus `USER MAPPING`).

Lo usan los datos de prueba (`04_datos/`): ventas, compras e inventarios usan `dblink` **solo
mientras arman sus datos** (por ejemplo, ventas necesita los precios de catálogo) y al terminar se lo
quitan. Así, al final, la única base con `dblink` es `andina_reportes`.

## Quién usa dblink

| Base | Para qué | Se queda con dblink |
|---|---|---|
| `andina_compras`, `andina_inventarios`, `andina_ventas` | Leer catálogo (e inventarios) para armar los datos de prueba | No, lo quitan al terminar |
| `andina_reportes` | Traer los datos de todas las bases para los reportes | Sí |

## Por qué "rompe un poco" la arquitectura

En microservicios, cada servicio es dueño de sus datos y nadie más los lee directamente. Con
`dblink`, reportes **sí** lee las tablas de los otros servicios. Eso tiene un costo:
- reportes depende de cómo están hechas esas tablas: si catálogo cambia una columna, las vistas de
  reportes se rompen;
- las bases ya no están del todo aisladas.

Es la versión más simple de explicar. La alternativa donde ninguna base se conecta a otra (un ETL
que pasa los datos por CSV) está en la rama `feat/microservicios-reales`.

## Seguridad

Por defecto, cualquier usuario puede ejecutar las funciones de `dblink`. En `andina_reportes`,
`06_roles/roles.sql` se las quita a todos (`REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM
PUBLIC`), así solo postgres va a las otras bases. La prueba 9.1b lo muestra: gerencia lo intenta y
recibe "permiso denegado para la función dblink".
