# 01_bases: crear y borrar la base de cada instancia

Cada microservicio tiene **su propia instancia** de PostgreSQL, y en cada una se crea **solo su
base**. `run_all.sql` repite estos dos scripts una vez por instancia.

| Archivo | Qué hace |
|---|---|
| `reset.sql` | Borra la base del servicio y los roles del proyecto **en la instancia actual** |
| `crear.sql` | Crea la base del servicio y le quita a todos el permiso de entrar |

## Una instancia y una base por microservicio

| Servicio | Base | Instancia local |
|---|---|---|
| Catálogo y Terceros | `andina_catalogo` | `localhost:5441` |
| Identidad y Accesos | `andina_identidad` | `localhost:5442` |
| Compras y Abastecimiento | `andina_compras` | `localhost:5443` |
| Inventarios y Transferencias | `andina_inventarios` | `localhost:5444` |
| Ventas y Pagos | `andina_ventas` | `localhost:5445` |
| Reportes Corporativos | `andina_reportes` | `localhost:5446` |

**La regla:** una consulta de PostgreSQL **no puede leer tablas de otra base**, y mucho menos de
otro servidor. Eso hace que cada servicio sea dueño de sus datos de verdad. La única forma de
saltarse eso es `dblink`, y en este proyecto solo lo usa reportes (ver `03_dblink/`).

## Cómo se usan desde run_all.sql

Para cada servicio:

```sql
\c :conn_ventas_admin                 -- la base de administracion de SU instancia
\set db andina_ventas                 -- que base crear
\set comentario 'Microservicio de Ventas y Pagos (...)'
\ir sql/01_bases/reset.sql
\ir sql/01_bases/crear.sql
\c :conn_ventas                       -- ya dentro de andina_ventas
```

- **`:"db"`** pone el valor de la variable como nombre (entre comillas dobles) y **`:'comentario'`**
  como texto (entre comillas simples). Así el mismo script sirve para las 6 instancias.
- **Se corre desde la base de administración** (`postgres` en local, `neondb` en Neon), porque no se
  puede borrar la base en la que uno está conectado.

## reset.sql

- **`DROP DATABASE IF EXISTS :"db"`:** borra la base con todo lo de adentro. `IF EXISTS` evita el
  error la primera vez.
- **Los roles son de cada instancia:** el script borra todos los nombres de roles del proyecto con
  `IF EXISTS`, porque no todas las instancias tienen todos. Primero los usuarios y después los
  grupos de los que heredan.
- **Si dice "está siendo usada por otros usuarios":** hay otra conexión abierta a esa base (pgAdmin,
  otra ventana de psql). Hay que cerrarla.

## crear.sql

- **`CREATE DATABASE`** y **`COMMENT ON DATABASE`** (la descripción se ve con `\l+`).
- **`REVOKE ALL ON DATABASE ... FROM PUBLIC`:** por defecto cualquier rol puede conectarse a
  cualquier base. Se le quita, y después `06_roles/` deja entrar a cada rol solo a lo que le toca.
