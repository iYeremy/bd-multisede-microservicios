# 01_bases: crear y borrar las bases

Aquí se arma el "terreno": una base de datos por microservicio, y nada más.

| Archivo | Qué hace |
|---|---|
| `reset.sql` | Borra las 6 bases y todos los roles del proyecto |
| `bases.sql` | Crea las 6 bases y le quita a todos el permiso de entrar |

## Una base por microservicio

| Base | Servicio |
|---|---|
| `andina_catalogo` | Catálogo y Terceros |
| `andina_identidad` | Identidad y Accesos |
| `andina_compras` | Compras y Abastecimiento |
| `andina_inventarios` | Inventarios y Transferencias |
| `andina_ventas` | Ventas y Pagos |
| `andina_reportes` | Reportes Corporativos |

**La regla:** una consulta de PostgreSQL **no puede leer tablas de otra base**. Eso es lo que hace
que cada servicio sea dueño de sus datos de verdad: ventas no puede hacer un `JOIN` con
`catalogo.productos`, porque esa tabla está en otra base. La única forma de saltarse eso es
`dblink`, y en este proyecto solo lo usa reportes (ver `03_dblink/`).

Las 6 bases pueden estar en el mismo servidor PostgreSQL o en servidores distintos. Para los
scripts da igual: solo cambia a dónde se conecta cada `\c`.

## reset.sql

- **Se corre conectado a la base `postgres`** (la que trae PostgreSQL), porque no se puede borrar la
  base en la que uno está conectado. `run_all.sql` hace `\c postgres` antes.
- **`DROP DATABASE IF EXISTS`:** borra la base con todo lo de adentro. `IF EXISTS` evita el error la
  primera vez, cuando todavía no existen.
- **Si dice "está siendo usada por otros usuarios":** hay otra conexión abierta a esa base (pgAdmin,
  otra ventana de psql). Hay que cerrarla.
- **Los roles se borran al final:** un rol no se puede borrar mientras tenga permisos en alguna base.
  Como las bases ya se borraron, sus permisos se fueron con ellas. Primero los usuarios y después
  los grupos de los que heredan.
- **`comercializadora`:** era la base de la versión vieja del proyecto (todo en una sola base con
  esquemas). Se borra porque sus permisos no dejarían borrar los roles.

## bases.sql

- **`CREATE DATABASE`:** crea cada base vacía.
- **`COMMENT ON DATABASE`:** una descripción que se ve con `\l+` en psql.
- **`REVOKE ALL ON DATABASE ... FROM PUBLIC`:** por defecto cualquier rol puede conectarse a
  cualquier base (`PUBLIC` es el grupo al que pertenecen todos). Se le quita, y después
  `06_roles/roles.sql` deja entrar a cada rol solo a las bases que le tocan.
