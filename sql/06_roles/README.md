# 06_roles: roles, usuarios y permisos

`roles.sql` crea los roles y da los permisos (sección 8 del enunciado). Va **al final** de la
creación, porque `GRANT ... ON ALL TABLES` solo alcanza a las tablas que ya existen. El script hace
sus propios `\c`, uno por base.

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

Los roles son de todo el servidor, pero los permisos se dan **base por base**:

1. **`GRANT CONNECT ON DATABASE`:** a qué bases puede entrar cada rol. `01_bases/bases.sql` ya le
   quitó `CONNECT` a `PUBLIC`, así que sin esto nadie entra.
2. **Dentro de cada base:** `GRANT USAGE ON SCHEMA` (poder "entrar" al esquema; sin esto los permisos
   de tabla no sirven) y luego `SELECT`, `INSERT`, `UPDATE`… sobre las tablas. Por eso el script hace
   un `\c` a cada base: un `GRANT` sobre tablas solo funciona conectado a la base donde están.

`ALL TABLES` incluye las vistas (también las materializadas).

## A qué base entra cada rol

| Rol | catálogo | identidad | compras | inventarios | ventas | reportes |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| rol_administrador | x | x | x | x | x | x |
| rol_gerencia | | | | | | x |
| rol_inventario | x | | | x | | x |
| rol_compras | x | | x | | | x |
| rol_vendedor | x | | | | x | |
| rol_auditor | x | x | x | x | x | x |
| svc_\<servicio\> | solo la base de su servicio |||||

## Qué puede hacer dentro (matriz de permisos)

S = SELECT, I = INSERT, U = UPDATE, D = DELETE.

| Rol | catálogo | identidad | compras | inventarios | ventas | reportes |
|---|---|---|---|---|---|---|
| rol_administrador | SIUD | SIUD | SIUD | SIUD | SIUD | S |
| rol_gerencia | – | – | – | – | – | S (todas las vistas) |
| rol_inventario | S | – | – | SIU transferencias; SIU **solo el fragmento de su sede** | – | S (3 vistas + última actualización) |
| rol_compras | S | – | SIU | – | – | S (1 vista + última actualización) |
| rol_vendedor | S (productos, clientes) | – | – | – | SIU **solo el fragmento de su sede**; SIU pagos y devoluciones | – |
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
- **`REVOKE` a propósito:** al vendedor se le da `DELETE` sobre pagos y devoluciones y luego se le
  quita con `REVOKE`. Se hace en dos pasos para demostrar `REVOKE` (lo pide la sección 8); la prueba
  9.6 comprueba que el `DELETE` queda denegado.
- **`WITH GRANT OPTION`:** el administrador puede conceder sus permisos a otros.
- **El vendedor no puede crear clientes:** `clientes` es de catálogo y el vendedor solo la lee.
- **`svc_inventarios` y `svc_ventas` sí manejan los 4 fragmentos:** es el backend el que decide en
  cuál escribe, según la sede del usuario que hizo login.

## La base de reportes

- **Solo vistas.** Las vistas materializadas guardan su resultado, así que leerlas solo pide permiso
  sobre la vista: gerencia ve los reportes sin poder tocar las otras bases.
- **`REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC`:** por defecto cualquiera puede
  ejecutar las funciones de `dblink` (están en el esquema `public`). Se le quita a todos, así solo
  postgres va a las otras bases. El `REFRESH` corre con los permisos del **dueño** de la vista
  (postgres), por eso sigue funcionando. La prueba 9.1b muestra a gerencia intentándolo.
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
