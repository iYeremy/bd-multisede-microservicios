# 06_roles: roles, usuarios y permisos

Roles y permisos (sección 8 del enunciado). Como cada microservicio tiene **su propia instancia** de
PostgreSQL, y los roles son de cada instancia, hay **un archivo por instancia**:

| Archivo | Instancia | Usuarios que crea |
|---|---|---|
| `catalogo.sql` | catálogo | admin, auditor, inventario (Bogotá y CEDI), compras, vendedores (Bogotá y Cali), `svc_catalogo` |
| `identidad.sql` | identidad | admin, auditor, `svc_identidad` |
| `compras.sql` | compras | admin, auditor, compras, `svc_compras` |
| `inventarios.sql` | inventarios | admin, auditor, inventario (Bogotá y CEDI), `svc_inventarios` |
| `ventas.sql` | ventas | admin, auditor, vendedores (Bogotá y Cali), `svc_ventas` |
| `reportes.sql` | reportes | admin, auditor, gerente, inventario (Bogotá y CEDI), compras, `svc_reportes` |

Cada instancia crea **solo los roles que usa**. Por ejemplo, `gerente_general` solo existe en la de
reportes: en ventas ni siquiera hay un usuario con ese nombre (prueba 9.2). Algunos, como el
administrador y el auditor, se repiten en varias instancias, con la misma contraseña de ejemplo.

Cada archivo va **al final** de su instancia, porque `GRANT ... ON ALL TABLES` solo alcanza a las
tablas que ya existen.

## Tres tipos de rol

En PostgreSQL usuarios y grupos son lo mismo: **roles**.

| Tipo | Ejemplos | Qué es |
|---|---|---|
| Grupos (`NOLOGIN`) | `rol_vendedor`, `rol_gerencia`… | No se conectan. Juntan los permisos de un cargo |
| Usuarios (`LOGIN`) | `vendedor_bogota`, `gerente_general`… | Personas. `IN ROLE rol_vendedor` los hace miembros del grupo, y heredan sus permisos |
| Usuarios técnicos (`LOGIN`) | `svc_ventas`, `svc_catalogo`… | Uno por microservicio: con este se conectará el backend de ese servicio a **su** base |

- Contraseña de ejemplo de los usuarios: `Andina2026*`.
- Los `svc_*` se crean **sin contraseña** a propósito: la real no va en el repositorio. Al desplegar se
  les pone con `ALTER ROLE svc_ventas PASSWORD '...';`, usando el valor del `.env` del servidor.
- Solo se crean los usuarios necesarios para demostrar los permisos. Las filas de
  `identidad.usuarios` son datos del negocio (para el login de la aplicación), no roles de la base.
- `CREATEROLE` deja al administrador crear y administrar otros roles.

**El permiso se da una vez al grupo** y le sirve a todos sus miembros. Lo que depende de la sede (la
tabla de **su** sede) se le da a cada usuario.

## Dos niveles de permiso

1. **`GRANT CONNECT ON DATABASE`:** quién puede entrar a la base. `01_bases/crear.sql` ya le quitó
   `CONNECT` a `PUBLIC`, así que sin esto nadie entra.
2. **Dentro de la base:** `GRANT USAGE ON SCHEMA` (poder "entrar" al esquema; sin esto los permisos
   de tabla no sirven) y luego `SELECT`, `INSERT`, `UPDATE`… sobre las tablas.

`ALL TABLES` incluye las vistas (también las materializadas).

## A qué base entra cada rol

Cada rol solo existe en las instancias que tienen una x:

| Rol | catálogo | identidad | compras | inventarios | ventas | reportes |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| rol_administrador | x | x | x | x | x | x |
| rol_gerencia | | | | | | x |
| rol_inventario | x | | | x | | x |
| rol_compras | x | | x | | | x |
| rol_vendedor | x | | | | x | |
| rol_auditor | x | x | x | x | x | x |
| svc_\<servicio\> | solo la instancia de su servicio |||||

## Qué puede hacer dentro (matriz de permisos)

S = SELECT, I = INSERT, U = UPDATE, D = DELETE.

| Rol | catálogo | identidad | compras | inventarios | ventas | reportes |
|---|---|---|---|---|---|---|
| rol_administrador | SIUD | SIUD | SIUD | SIUD | SIUD | S |
| rol_gerencia | – | – | – | – | – | S (todas las vistas) |
| rol_inventario | S | – | – | SIU transferencias; SIU **solo el fragmento de su sede** | – | S (3 vistas + última actualización) |
| rol_compras | S | – | SIU | – | – | S (1 vista + última actualización) |
| rol_vendedor | S (productos, clientes) | – | – | – | SIU **solo el fragmento de su sede**; SIU pagos y devoluciones **de su sede**, por las vistas locales (`pagos_bogota`...) | – |
| rol_auditor | S | S (sin `password_hash`) | S | S | S | S |
| svc_\<servicio\> | SIU solo en las tablas de su servicio (`svc_reportes`: lee y refresca las vistas) ||||||

**En resumen:**
- cada servicio solo modifica lo suyo (RN-39);
- vendedor e inventario solo tocan su sede (RN-40);
- gerencia y auditor solo leen (RN-41);
- nadie salvo el administrador tiene `DELETE`: no se borra, se cambia el estado (RN-43).

## Lo que destaca

- **Permiso por sede con fragmentos:** como cada sede tiene su tabla, "solo su sede" es un `GRANT`
  normal. `vendedor_bogota` tiene permiso sobre `ventas.ped_bogota` y no sobre `ventas.ped_cali`, así
  que ni siquiera puede leer los pedidos de Cali (prueba 9.4). Lo mismo con `inventario_cedi` e
  `inv_cedi` (prueba 9.7).
- **Permiso por columna:** `GRANT SELECT (id_usuario, id_empleado, nombre_usuario, ...) ON
  identidad.usuarios TO rol_auditor` deja al auditor ver todo menos `password_hash` (prueba 9.8).
- **Vistas locales para lo que no está fragmentado:** `pagos` y `devoluciones` son una sola tabla
  para las 4 sedes. El vendedor **no** tiene permiso sobre la tabla (leerla da error, prueba 9.9b),
  sino sobre la vista de su sede (`ventas.pagos_bogota`, `devoluciones_bogota`,
  `detalle_devolucion_bogota`). Son vistas actualizables con `WITH CHECK OPTION`: por la vista se
  puede registrar un pago, pero solo de un pedido que exista en el fragmento de su sede (9.9c
  permitido, 9.9d denegado).
- **`REVOKE` a propósito:** al vendedor se le da `DELETE` sobre sus vistas de pagos y devoluciones y
  luego se le quita con `REVOKE`. Se hace en dos pasos para demostrar `REVOKE` (lo pide la sección 8); la prueba
  9.6 comprueba que el `DELETE` queda denegado.
- **`WITH GRANT OPTION`:** el administrador puede conceder sus permisos a otros.
- **El vendedor no puede crear clientes:** `clientes` es de catálogo y el vendedor solo la lee.
- **`svc_inventarios` y `svc_ventas` sí manejan los 4 fragmentos:** es el backend el que decide en
  cuál escribe, según la sede del usuario que hizo login.

## La base de reportes

- **Solo vistas.** Las vistas materializadas guardan su resultado, así que leerlas solo pide permiso
  sobre la vista: gerencia ve los reportes sin poder tocar las otras bases.
- **Gerencia no puede usar `dblink`:** las conexiones a las otras instancias están en el esquema
  privado `remoto` (ver `03_dblink/`). El `REFRESH` corre con los permisos del **dueño** de la vista,
  que sí puede usarlas. La prueba 9.1b muestra a gerencia intentándolo.
- **`GRANT MAINTAIN`** (PostgreSQL 17 o superior): el permiso para hacer `REFRESH` de una vista
  materializada sin ser su dueño. Se le da a `svc_reportes`, para que el backend pueda refrescar los
  reportes cada X minutos. Por esto el proyecto pide PostgreSQL 17 o superior.

## Probar un usuario

```sql
\c andina_ventas
SET ROLE vendedor_bogota;
SELECT COUNT(*) FROM ventas.ped_bogota;   -- permitido
SELECT COUNT(*) FROM ventas.ped_cali;     -- ERROR: permiso denegado
RESET ROLE;
```

`SET ROLE` hace que la sesión actúe como ese usuario, sin reconectarse. Ojo: no revisa `CONNECT`
(eso se revisa solo al conectarse). Para probar `CONNECT`: `psql -U gerente_general -d andina_ventas`
da `User does not have CONNECT privilege`.

## Sin superusuario (Neon)

En Neon quien corre los scripts no es superusuario. Para poder probar a los usuarios con `SET ROLE`
(en `08_pruebas/`), tiene que ser **miembro** de ellos. Por eso, al final de cada archivo:

```sql
\if :no_superusuario
GRANT admin_andina, auditor_interno, ... TO CURRENT_USER WITH INHERIT FALSE, SET TRUE;
\endif
```

- **`SET TRUE`:** puede hacer `SET ROLE` a esos usuarios.
- **`INHERIT FALSE`:** no hereda sus permisos (no los necesita).
- Solo corre si `NO_SUPERUSUARIO=true` en el `.env`. En local no hace falta, porque postgres es
  superusuario.
