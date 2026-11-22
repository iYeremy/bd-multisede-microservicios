# Matriz de pruebas

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Cada prueba con lo que se esperaba y lo que **de verdad** salió. Hay dos grupos:

1. **Pruebas de la base de datos** (`sql/08_pruebas/pruebas.sql`): restricciones, fragmentos,
   permisos y aislamiento entre instancias. Salida completa en [`evidencias.txt`](../../evidencias.txt)
   (local) y [`evidencias-neon.txt`](../../evidencias-neon.txt) (Neon): dan **exactamente lo mismo**.
2. **Pruebas del backend** (`scripts/probar_backend.sh` y `go test`): lo mismo visto desde la
   aplicación. Salida en [`evidencias-backend.txt`](../../evidencias-backend.txt).

Las pruebas que modifican datos van dentro de `BEGIN ... ROLLBACK`: no dejan nada guardado.

**Resultado: las 40 pruebas de la base y las 31 del backend dan lo esperado.**

Cómo leer la tabla: **Como** es el usuario con el que corre la prueba (`SET ROLE`; `postgres` es el dueño). **Evidencia** lleva a la línea de [`evidencias.txt`](../../evidencias.txt) donde está el resultado y a la línea de `pruebas.sql` donde está el SQL completo.

---

## 1. Pruebas de la base de datos

### 1.1 Integridad (restricciones)

| # | Instancia | Como | SQL ejecutado | Esperado | Obtenido | Evidencia | ✓ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | catálogo | `postgres` | `INSERT INTO catalogo.productos (sku, ...) VALUES ('PAP-099', ...)` y `SELECT ... WHERE sku = 'PAP-099'` | Se guarda y se ve | `INSERT 0 1` y la consulta lo devuelve | [evid. L1728](../../evidencias.txt#L1728) · [sql L13](../../../sql/08_pruebas/pruebas.sql#L13) | ✓ |
| 2 | catálogo | `postgres` | `INSERT INTO catalogo.productos (sku, ...) VALUES ('ALI-001', ...)` (SKU que ya existe) | Error de `UNIQUE` | `duplicate key value violates unique constraint "productos_sku_key"` | [evid. L1736](../../evidencias.txt#L1736) · [sql L22](../../../sql/08_pruebas/pruebas.sql#L22) | ✓ |
| 3 | compras | `postgres` | `INSERT INTO compras.detalle_orden_compra (..., cantidad_solicitada, ...) VALUES (1, 80, -5, 1000)` | Error de `CHECK` | `violates check constraint "detalle_orden_compra_cantidad_solicitada_check"` | [evid. L1753](../../evidencias.txt#L1753) · [sql L49](../../../sql/08_pruebas/pruebas.sql#L49) | ✓ |
| 3b | inventarios | `postgres` | `UPDATE inventarios.inv_bogota SET existencia_actual = -1 WHERE id_producto = 1` | Error de `CHECK` | `violates check constraint "inv_bogota_existencia_actual_check"` | [evid. L1764](../../evidencias.txt#L1764) · [sql L65](../../../sql/08_pruebas/pruebas.sql#L65) | ✓ |
| 4 | catálogo | `postgres` | `INSERT INTO catalogo.productos (..., id_categoria, ...) VALUES ('XXX-001', ..., 999, ...)` | Error de FK | `violates foreign key constraint "productos_id_categoria_fkey"` | [evid. L1740](../../evidencias.txt#L1740) · [sql L28](../../../sql/08_pruebas/pruebas.sql#L28) | ✓ |
| 4c | ventas | `postgres` | `INSERT INTO ventas.det_ped_bogota (id_sede, id_pedido, ...) VALUES (1, 99999, ...)` | Error de la FK compuesta `(id_sede, id_pedido)` | `violates foreign key constraint "det_ped_bogota_id_sede_id_pedido_fkey"` | [evid. L1807](../../evidencias.txt#L1807) · [sql L117](../../../sql/08_pruebas/pruebas.sql#L117) | ✓ |
| extra | reportes | `postgres` | Por cada id compartido: `SELECT COUNT(*) ... WHERE NOT EXISTS (...)` leyendo por `dblink` | 0 huérfanos en cada una | Las 13 referencias dan **0** | [evid. L1936](../../evidencias.txt#L1936) · [sql L267](../../../sql/08_pruebas/pruebas.sql#L267) | ✓ |

### 1.2 Fragmentación por sede

| # | Instancia | Como | SQL ejecutado | Esperado | Obtenido | Evidencia | ✓ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 4b | inventarios | `postgres` | `INSERT INTO inventarios.inv_bogota (id_sede, ...) VALUES (2, 2, 1, 10, 5)` | Error del `CHECK (id_sede = 1)` | `violates check constraint "inv_bogota_id_sede_check"` | [evid. L1768](../../evidencias.txt#L1768) · [sql L69](../../../sql/08_pruebas/pruebas.sql#L69) | ✓ |
| 5 | inventarios | `postgres` | `SELECT COUNT(*), MIN(id_sede), MAX(id_sede)` de `inv_bogota` e `inv_cali`, y su `INTERSECT` | Cada uno con una sola sede, sin filas en común | `inv_bogota`: 72 filas, solo sede 1 · `inv_cali`: 64, solo sede 3 · filas repetidas: **0** | [evid. L1772](../../evidencias.txt#L1772) · [sql L75](../../../sql/08_pruebas/pruebas.sql#L75) | ✓ |
| 5b | ventas | `postgres` | `SELECT COUNT(*), MIN(fecha_pedido), MAX(fecha_pedido)` de `ped_bogota` y `ped_cali` | Pedidos distintos por sede | 100 y 70 pedidos, cada uno de su sede | [evid. L1811](../../evidencias.txt#L1811) · [sql L123](../../../sql/08_pruebas/pruebas.sql#L123) | ✓ |
| 6 | reportes | `postgres` | `SELECT fragmento, id_sede, COUNT(*) FROM reportes.vista_inventario_consolidado GROUP BY ...` vs la suma de los 4 fragmentos | Salen las 4 sedes y el total cuadra | 72 + 69 + 64 + 99 = **304** en la vista = 304 en los fragmentos | [evid. L1869](../../evidencias.txt#L1869) · [sql L190](../../../sql/08_pruebas/pruebas.sql#L190) | ✓ |
| 8 | inventarios | `postgres` | `inv_bogota EXCEPT inv_medellin`, al revés, e `INTERSECT` | Cuántos son de una, de la otra o de las dos | Solo Bogotá 10 · solo Medellín 7 · en ambas 62 | [evid. L1785](../../evidencias.txt#L1785) · [sql L90](../../../sql/08_pruebas/pruebas.sql#L90) | ✓ |

### 1.3 Consultas avanzadas

| # | Instancia | Como | SQL ejecutado | Esperado | Obtenido | Evidencia | ✓ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 7a | reportes | `postgres` | `WITH ventas_sede AS (SELECT id_sede, SUM(total_registrado) ...) SELECT ...` | Una fila por sede | 4 filas | [evid. L1884](../../evidencias.txt#L1884) · [sql L206](../../../sql/08_pruebas/pruebas.sql#L206) | ✓ |
| 7b | reportes | `postgres` | `SUM(SUM(total_vendido)) OVER ()` para el % y `ROW_NUMBER() OVER (ORDER BY ... DESC)` para el puesto | Una fila por sede con su % | CEDI 39,6 % · Bogotá 25,0 % · Medellín 19,0 % · Cali 16,5 % | [evid. L1894](../../evidencias.txt#L1894) · [sql L219](../../../sql/08_pruebas/pruebas.sql#L219) | ✓ |
| 10 | reportes | `postgres` | Cada total de `vista_reporte_corporativo` contra el mismo total calculado en la fuente | Iguales | Ventas $48.868.680 = $48.868.680 · unidades 32.913 = 32.913 · órdenes 58 = 58 · pendientes 32 = 32 | [evid. L1920](../../evidencias.txt#L1920) · [sql L240](../../../sql/08_pruebas/pruebas.sql#L240) | ✓ |
| 10b | reportes | `postgres` | Contraejemplo: pedidos, órdenes y transferencias en un solo `JOIN` | Las ventas salen infladas | $179.923.155 (**3,7 veces** el valor real) | [evid. L1929](../../evidencias.txt#L1929) · [sql L259](../../../sql/08_pruebas/pruebas.sql#L259) | ✓ |

### 1.4 Permisos por rol

| # | Instancia | Como | SQL ejecutado | Esperado | Obtenido | Evidencia | ✓ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 9.1 | reportes | `gerente_general` | `SELECT * FROM reportes.vista_reporte_corporativo` | Permitido | 4 filas | [evid. L1904](../../evidencias.txt#L1904) · [sql L228](../../../sql/08_pruebas/pruebas.sql#L228) | ✓ |
| 9.1b | reportes | `gerente_general` | `SELECT * FROM dblink(remoto.servidor('ventas'), ...)` | Denegado | `permission denied for schema remoto` | [evid. L1914](../../evidencias.txt#L1914) · [sql L232](../../../sql/08_pruebas/pruebas.sql#L232) | ✓ |
| 9.2 | ventas | `gerente_general` | `SET ROLE gerente_general` en la instancia de ventas | Ni siquiera existe ahí | `role "gerente_general" does not exist` | [evid. L1818](../../evidencias.txt#L1818) · [sql L130](../../../sql/08_pruebas/pruebas.sql#L130) | ✓ |
| 9.3 | ventas | `vendedor_bogota` | `INSERT INTO ventas.ped_bogota (...)` y su detalle | Permitido | `INSERT 0 1` (pedido y detalle) | [evid. L1820](../../evidencias.txt#L1820) · [sql L135](../../../sql/08_pruebas/pruebas.sql#L135) | ✓ |
| 9.4 | ventas | `vendedor_bogota` | `SELECT COUNT(*) FROM ventas.ped_cali` | Denegado | `permission denied for table ped_cali` | [evid. L1829](../../evidencias.txt#L1829) · [sql L145](../../../sql/08_pruebas/pruebas.sql#L145) | ✓ |
| 9.5 | catálogo | `vendedor_bogota` | `UPDATE catalogo.productos SET precio_lista = 1 WHERE id_producto = 1` | Denegado | `permission denied for table productos` | [evid. L1745](../../evidencias.txt#L1745) · [sql L35](../../../sql/08_pruebas/pruebas.sql#L35) | ✓ |
| 9.6 | ventas | `vendedor_bogota` | `DELETE FROM ventas.pagos_bogota WHERE id_pago = ...` | Denegado (`REVOKE DELETE`) | `permission denied for view pagos_bogota` | [evid. L1831](../../evidencias.txt#L1831) · [sql L148](../../../sql/08_pruebas/pruebas.sql#L148) | ✓ |
| 9.7 | inventarios | `inventario_cedi` | `UPDATE inventarios.inv_cedi SET existencia_actual = existencia_actual + 10 ...` | Permitido | `UPDATE 1` | [evid. L1793](../../evidencias.txt#L1793) · [sql L101](../../../sql/08_pruebas/pruebas.sql#L101) | ✓ |
| 9.7b | inventarios | `inventario_cedi` | `UPDATE inventarios.inv_bogota SET existencia_actual = 0 ...` | Denegado | `permission denied for table inv_bogota` | [evid. L1793](../../evidencias.txt#L1793) · [sql L101](../../../sql/08_pruebas/pruebas.sql#L101) | ✓ |
| 9.8 | identidad | `auditor_interno` | `SELECT nombre_usuario, rol, estado FROM identidad.usuarios` | Permitido | 3 filas | [evid. L1855](../../evidencias.txt#L1855) · [sql L175](../../../sql/08_pruebas/pruebas.sql#L175) | ✓ |
| 9.8c | identidad | `auditor_interno` | `SELECT password_hash FROM identidad.usuarios` | Denegado (permiso por columna) | `permission denied for table usuarios` | [evid. L1855](../../evidencias.txt#L1855) · [sql L175](../../../sql/08_pruebas/pruebas.sql#L175) | ✓ |
| 9.8b | compras | `auditor_interno` | `UPDATE compras.ordenes_compra SET estado = 'CANCELADA' ...` | Denegado (solo lectura) | `permission denied for table ordenes_compra` | [evid. L1756](../../evidencias.txt#L1756) · [sql L53](../../../sql/08_pruebas/pruebas.sql#L53) | ✓ |
| 9.9a | ventas | `vendedor_bogota` | `SELECT COUNT(*), MIN(id_sede), MAX(id_sede) FROM ventas.pagos_bogota` | Permitido, solo pagos de su sede | 108 pagos, todos de la sede 1 | [evid. L1833](../../evidencias.txt#L1833) · [sql L153](../../../sql/08_pruebas/pruebas.sql#L153) | ✓ |
| 9.9b | ventas | `vendedor_bogota` | `SELECT COUNT(*) FROM ventas.pagos` (la tabla de las 4 sedes) | Denegado | `permission denied for table pagos` | [evid. L1839](../../evidencias.txt#L1839) · [sql L156](../../../sql/08_pruebas/pruebas.sql#L156) | ✓ |
| 9.9c | ventas | `vendedor_bogota` | `INSERT INTO ventas.pagos_bogota (...) VALUES (1, 1, ...)` | Permitido | Se guarda el pago (sede 1, pedido 1) | [evid. L1841](../../evidencias.txt#L1841) · [sql L159](../../../sql/08_pruebas/pruebas.sql#L159) | ✓ |
| 9.9d | ventas | `vendedor_bogota` | `INSERT INTO ventas.pagos_bogota (...) VALUES (3, 1, ...)` (pedido de Cali) | Denegado por la vista | `new row violates check option for view "pagos_bogota"` | [evid. L1848](../../evidencias.txt#L1848) · [sql L164](../../../sql/08_pruebas/pruebas.sql#L164) | ✓ |

### 1.5 Aislamiento entre instancias y consistencia eventual

| # | Instancia | Como | SQL ejecutado | Esperado | Obtenido | Evidencia | ✓ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 11.1 | ventas | `postgres` | `SELECT * FROM catalogo.productos` | No existe en esta instancia | `relation "catalogo.productos" does not exist` | [evid. L1958](../../evidencias.txt#L1958) · [sql L351](../../../sql/08_pruebas/pruebas.sql#L351) | ✓ |
| 11.2 | ventas | `postgres` | `SELECT * FROM andina_catalogo.catalogo.productos` | PostgreSQL no lo permite | `cross-database references are not implemented` | [evid. L1962](../../evidencias.txt#L1962) · [sql L354](../../../sql/08_pruebas/pruebas.sql#L354) | ✓ |
| 11.3 | reportes | `postgres` | A cada instancia, por `dblink`: `SELECT rolname FROM pg_roles WHERE has_database_privilege(...)` | Igual a la matriz de `06_roles/README.md` | Coincide: `gerente_general` solo existe en reportes; en identidad solo admin, auditor y `svc_identidad` | [evid. L1966](../../evidencias.txt#L1966) · [sql L358](../../../sql/08_pruebas/pruebas.sql#L358) | ✓ |
| 12.1 | reportes | `postgres` | `SELECT COUNT(*) FROM reportes.vista_pedidos_consolidado WHERE id_sede = 1` | Lo del último refresco | 100 | [evid. L1980](../../evidencias.txt#L1980) · [sql L396](../../../sql/08_pruebas/pruebas.sql#L396) | ✓ |
| 12.2 | ventas | `postgres` | `INSERT INTO ventas.ped_bogota (...)` y `SELECT COUNT(*) FROM ventas.ped_bogota` | Queda guardado en ventas | 101 en ventas | [evid. L1987](../../evidencias.txt#L1987) · [sql L402](../../../sql/08_pruebas/pruebas.sql#L402) | ✓ |
| 12.3 | reportes | `postgres` | El mismo `SELECT` de 12.1, sin refrescar | **Todavía no** lo ve | 100 | [evid. L1995](../../evidencias.txt#L1995) · [sql L410](../../../sql/08_pruebas/pruebas.sql#L410) | ✓ |
| 12.4–12.5 | reportes | `postgres` | `REFRESH MATERIALIZED VIEW ...` (las 14) y el mismo `SELECT` | Ahora sí lo ve | 101 | [evid. L2024](../../evidencias.txt#L2024) · [sql L419](../../../sql/08_pruebas/pruebas.sql#L419) | ✓ |
| 12.6 | ventas / reportes | `postgres` | `DELETE` del pedido de prueba y `REFRESH` | Queda como antes | `DELETE 1` | [evid. L2030](../../evidencias.txt#L2030) · [sql L424](../../../sql/08_pruebas/pruebas.sql#L424) | ✓ |

---

## 2. Pruebas del backend

`scripts/probar_backend.sh` hace lo mismo que un navegador: todo entra por el gateway. Se corrió en
cuatro ambientes y dio **31 de 31** en todos: local, Docker contra Neon y la VM de Azure contra
Neon (Docker con las bases locales dio 30 de 30, antes de agregar la prueba del bloqueo de login).

| Grupo | Qué se prueba | Esperado | ✓ |
| --- | --- | --- | --- |
| Salud | Los 6 servicios responden y llegan a su base | `/salud` 200 | ✓ |
| Sesión | Sin sesión no se entra | 401 | ✓ |
| Sesión | Clave mala | 401 | ✓ |
| Sesión | Login correcto | 200 y cookie de sesión | ✓ |
| Sesión | 5 claves malas seguidas | 429: usuario bloqueado 15 min | ✓ |
| Sesión | Mandar `X-Usuario-Rol: ADMINISTRADOR` a mano | No da permisos (403): el gateway borra ese encabezado | ✓ |
| Roles | El vendedor ve productos y los pedidos de su sede | 200 | ✓ |
| Roles | El vendedor intenta ver compras o reportes | 403 | ✓ |
| Roles | Inventario ve su fragmento y sus alertas | 200 | ✓ |
| Roles | Inventario intenta ver el reporte corporativo | 403 | ✓ |
| Roles | Compras ve las órdenes y su detalle | 200 | ✓ |
| Roles | Gerencia ve el reporte corporativo | 200 | ✓ |
| Roles | Gerencia pide una vista que no existe | 404 (solo se aceptan vistas de una lista) | ✓ |
| Roles | Gerencia intenta refrescar los reportes | 403 (solo el administrador) | ✓ |
| Pedidos | El vendedor de Cali crea un pedido | 201, guardado en `ventas.ped_cali` | ✓ |
| Pedidos | Producto descontinuado | 400, no se guarda | ✓ |
| Pedidos | Cliente que no existe | 400, no se guarda | ✓ |
| Pedidos | Producto repetido en el pedido | 400, no se guarda | ✓ |
| Pedidos | Gerencia intenta crear un pedido | 403 | ✓ |
| Reportes | El pedido nuevo aparece en el reporte tras refrescar | Sí (consistencia eventual) | ✓ |
| Sesión | Logout, y después intentar entrar | 401 | ✓ |

**Fallos a propósito (local):** con catálogo apagado, `/salud` lo marca `caido`, crear un pedido da
503 y no guarda nada, y la lista de pedidos sigue funcionando, con un aviso y con ids en vez de
nombres.

**Desde afuera (VM):** solo responde el puerto 80 (gateway); los servicios (`8101`…) y PostgreSQL
(`5432`) no se alcanzan, y `/interno/...` da 404 por el gateway.

**Pruebas de Go** (`cd backend && go test ./...`, sin base de datos):

| Paquete | Qué prueba |
| --- | --- |
| `gateway` | Borra los `X-Usuario-*` falsos, nunca reenvía `/interno`, y sirve el front con su `Content-Security-Policy` |
| `plataforma` | `ConRol` (401 sin sesión, 403 con otro rol), `SedeDe` (solo el administrador cambia de sede) y que **ningún servicio importe el código de otro** |
| `identidad` | Claves MD5 y bcrypt, sesiones que vencen, y el bloqueo tras 5 claves malas (con un reloj falso, sin esperar 15 min) |
| `ventas` | La validación de un pedido nuevo (cantidades, repetidos, límites) |
