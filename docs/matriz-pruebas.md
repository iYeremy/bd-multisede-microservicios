# Matriz de pruebas

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Cada prueba con lo que se esperaba y lo que **de verdad** salió. Hay dos grupos:

1. **Pruebas de la base de datos** (`sql/08_pruebas/pruebas.sql`): restricciones, fragmentos,
   permisos y aislamiento entre instancias. Salida completa en [`evidencias.txt`](evidencias.txt)
   (local) y [`evidencias-neon.txt`](evidencias-neon.txt) (Neon): dan **exactamente lo mismo**.
2. **Pruebas del backend** (`scripts/probar_backend.sh` y `go test`): lo mismo visto desde la
   aplicación. Salida en [`evidencias-backend.txt`](evidencias-backend.txt).

Las pruebas que modifican datos van dentro de `BEGIN ... ROLLBACK`: no dejan nada guardado.

**Resultado: las 37 pruebas de la base y las 31 del backend dan lo esperado.**

---

## 1. Pruebas de la base de datos

### 1.1 Integridad (restricciones)

| # | Instancia | Qué se hace | Esperado | Obtenido | ✓ |
| --- | --- | --- | --- | --- | --- |
| 1 | catálogo | Crear un producto válido y consultarlo | Se guarda y se ve | `INSERT 0 1` y la consulta lo devuelve | ✓ |
| 2 | catálogo | Crear otro producto con un SKU que ya existe | Error de `UNIQUE` | `duplicate key value violates unique constraint "productos_sku_key"` | ✓ |
| 3 | compras | Detalle de orden con cantidad negativa | Error de `CHECK` | `violates check constraint "detalle_orden_compra_cantidad_solicitada_check"` | ✓ |
| 3b | inventarios | Existencia negativa en `inv_bogota` | Error de `CHECK` | `violates check constraint "inv_bogota_existencia_actual_check"` | ✓ |
| 4 | catálogo | Producto con una categoría que no existe | Error de FK | `violates foreign key constraint "productos_id_categoria_fkey"` | ✓ |
| 4c | ventas | Detalle de un pedido que no existe | Error de la FK compuesta `(id_sede, id_pedido)` | `violates foreign key constraint "det_ped_bogota_id_sede_id_pedido_fkey"` | ✓ |
| extra | reportes | Ids compartidos entre bases (sin FK posible) que apuntan a algo que no existe | 0 huérfanos en cada una | Las 13 referencias dan **0** | ✓ |

### 1.2 Fragmentación por sede

| # | Instancia | Qué se hace | Esperado | Obtenido | ✓ |
| --- | --- | --- | --- | --- | --- |
| 4b | inventarios | Meter una fila de Medellín en `inv_bogota` | Error del `CHECK (id_sede = 1)` | `violates check constraint "inv_bogota_id_sede_check"` | ✓ |
| 5 | inventarios | Comparar `inv_bogota` e `inv_cali` | Cada uno con una sola sede, sin filas en común | `inv_bogota`: 72 filas, solo sede 1 · `inv_cali`: 64, solo sede 3 · filas repetidas: **0** | ✓ |
| 5b | ventas | Comparar `ped_bogota` y `ped_cali` | Pedidos distintos por sede | 100 y 70 pedidos, cada uno de su sede | ✓ |
| 6 | reportes | La vista consolidada junta los 4 fragmentos | Salen las 4 sedes y el total cuadra | 72 + 69 + 64 + 99 = **304** filas en la vista = 304 en los fragmentos | ✓ |
| 8 | inventarios | Surtido Bogotá vs Medellín con `EXCEPT` / `INTERSECT` | Cuántos son de una, de la otra o de las dos | Solo Bogotá 10 · solo Medellín 7 · en ambas 62 | ✓ |

### 1.3 Consultas avanzadas

| # | Instancia | Qué se hace | Esperado | Obtenido | ✓ |
| --- | --- | --- | --- | --- | --- |
| 7a | reportes | Consulta con CTE (`WITH`): ventas confirmadas por sede | Una fila por sede | 4 filas | ✓ |
| 7b | reportes | Función de ventana: % de cada sede en las ventas | Una fila por sede con su % | CEDI 39,6 % · Bogotá 25,0 % · Medellín 19,0 % · Cali 16,5 % | ✓ |
| C1–C20 | reportes | Las 20 consultas del enunciado | Corren sin error y dan resultados variados | Las 20 corren (21 contando 18a y 18b); ver [`analisis-resultados.md`](analisis-resultados.md) | ✓ |
| 10 | reportes | El reporte corporativo no duplica | Cada total del reporte = el mismo total de la fuente | Ventas $48.868.680 = $48.868.680 · unidades 32.913 = 32.913 · órdenes 58 = 58 · pendientes 32 = 32 | ✓ |
| 10b | reportes | Contraejemplo: todo en un solo `JOIN` | Las ventas salen infladas | $179.923.155 (**3,7 veces** el valor real) | ✓ |

### 1.4 Permisos por rol

| # | Instancia | Rol | Qué intenta | Esperado | Obtenido | ✓ |
| --- | --- | --- | --- | --- | --- | --- |
| 9.1 | reportes | gerencia | Leer el reporte corporativo | Permitido | 4 filas | ✓ |
| 9.1b | reportes | gerencia | Usar `dblink` con las conexiones guardadas | Denegado | `permission denied for schema remoto` | ✓ |
| 9.2 | ventas | gerencia | Actuar en la instancia de ventas | Ni siquiera existe ahí | `role "gerente_general" does not exist` | ✓ |
| 9.3 | ventas | vendedor Bogotá | Crear un pedido en `ped_bogota` | Permitido | `INSERT 0 1` (pedido y detalle) | ✓ |
| 9.4 | ventas | vendedor Bogotá | Leer los pedidos de Cali | Denegado | `permission denied for table ped_cali` | ✓ |
| 9.5 | catálogo | vendedor Bogotá | Cambiar el precio de un producto | Denegado | `permission denied for table productos` | ✓ |
| 9.6 | ventas | vendedor Bogotá | Borrar un pago | Denegado (`REVOKE DELETE`) | `permission denied for table pagos` | ✓ |
| 9.7 | inventarios | inventario CEDI | Actualizar `inv_cedi` | Permitido | `UPDATE 1` | ✓ |
| 9.7b | inventarios | inventario CEDI | Actualizar `inv_bogota` | Denegado | `permission denied for table inv_bogota` | ✓ |
| 9.8 | identidad | auditor | Leer usuarios (sin la clave) | Permitido | 3 filas | ✓ |
| 9.8c | identidad | auditor | Leer `password_hash` | Denegado (permiso por columna) | `permission denied for table usuarios` | ✓ |
| 9.8b | compras | auditor | Modificar una orden de compra | Denegado (solo lectura) | `permission denied for table ordenes_compra` | ✓ |

### 1.5 Aislamiento entre instancias y consistencia eventual

| # | Instancia | Qué se hace | Esperado | Obtenido | ✓ |
| --- | --- | --- | --- | --- | --- |
| 11.1 | ventas | Leer `catalogo.productos` | No existe en esta instancia | `relation "catalogo.productos" does not exist` | ✓ |
| 11.2 | ventas | Nombrar la otra base: `andina_catalogo.catalogo.productos` | PostgreSQL no lo permite | `cross-database references are not implemented` | ✓ |
| 11.3 | reportes | Qué usuarios existen y pueden entrar en cada instancia | Igual a la matriz de `06_roles/README.md` | Coincide. Por ejemplo, `gerente_general` solo existe en reportes, y en identidad solo hay admin, auditor y `svc_identidad` | ✓ |
| 12.1 | reportes | Pedidos de Bogotá en el reporte | Lo del último refresco | 100 | ✓ |
| 12.2 | ventas | Se crea un pedido nuevo | Queda guardado en ventas | 101 en ventas | ✓ |
| 12.3 | reportes | El reporte, sin refrescar | **Todavía no** lo ve | 100 | ✓ |
| 12.4–12.5 | reportes | `REFRESH` de las vistas | Ahora sí lo ve | 101 | ✓ |
| 12.6 | ventas / reportes | Limpieza | Se borra el pedido y se refresca | `DELETE 1` | ✓ |

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
