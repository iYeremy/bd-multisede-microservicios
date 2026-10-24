# Modelo relacional

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Oct 23, 2026 · @Yeremy

## 1. Convenciones y decisiones de diseño

El modelo tiene 22 relaciones en cinco esquemas; los pedidos de venta, sus detalles y los inventarios están particionados por sede.

### 1.1 Notación

- **Negrita**: atributo que forma parte de la clave primaria.
- *Cursiva*: clave foránea local, declarada dentro del mismo esquema.
- † : identificador compartido. Apunta a una relación de otro microservicio y **no** tiene FK declarada (S-09).
- Los nombres de tablas y atributos van en minúsculas con guion bajo, y se escriben como `esquema.tabla` en los scripts.

### 1.2 Decisiones de diseño

1. **Claves sustitutas.** Casi todas las relaciones usan una clave entera generada con `GENERATED ALWAYS AS IDENTITY`. Las relaciones de detalle usan clave compuesta (cabecera + producto), lo que impide repetir un producto en la misma orden o pedido.
2. **Pedido identificado por sede.** El número de pedido es un consecutivo **dentro de cada sede**, como la numeración de un punto de venta. La clave de un pedido es (`id_sede`, `id_pedido`): el pedido 15 de Bogotá y el pedido 15 de Cali son distintos. Así la clave de partición forma parte de la clave primaria, como exige PostgreSQL, sin introducir dependencias transitivas.
3. **Fragmentación derivada.** `detalle_pedido` se particiona con la misma condición que `pedidos_venta`, de modo que un pedido y sus detalles quedan en el mismo fragmento.
4. **Pagos y devoluciones sin fragmentar.** Referencian el pedido con la clave compuesta (`id_sede`, `id_pedido`). PostgreSQL (desde la versión 12) permite FK hacia tablas particionadas.
5. **Inventarios con `id_sede`.** La clave es (`id_sede`, `id_almacen`, `id_producto`). Como cada almacén pertenece a una sola sede, `id_sede` es redundante. Se conserva a propósito: es la clave de fragmentación y permite otorgar permisos por sede (RN-40). Es una desnormalización controlada que se justifica en la sección de normalización.
6. **Históricos.** El precio unitario de venta y el costo unitario de compra se guardan en los detalles (RN-27).
7. **Total registrado.** `pedidos_venta.total_registrado` es un dato derivado de los detalles. Se almacena para conservar el valor histórico del pedido y reportar el importe registrado.
8. **FK solo locales.** Las claves foráneas se declaran únicamente dentro de un esquema. Las referencias entre microservicios se listan en la sección 8.

## 2. Esquema `catalogo` (Catálogo y Terceros)

Siete relaciones con los datos maestros que usan todos los demás microservicios.

| Relación | Esquema relacional | FK y únicos |
| --- | --- | --- |
| sedes | sedes (**id\_sede**, nombre, ciudad, direccion, tipo\_sede, estado) | UNIQUE (nombre) |
| almacenes | almacenes (**id\_almacen**, *id\_sede*, nombre, tipo\_almacen, estado) | id\_sede → sedes · UNIQUE (id\_sede, nombre) |
| categorias | categorias (**id\_categoria**, nombre, descripcion, estado) | UNIQUE (nombre) |
| productos | productos (**id\_producto**, sku, nombre, *id\_categoria*, unidad\_medida, precio\_lista, estado) | id\_categoria → categorias · UNIQUE (sku) |
| proveedores | proveedores (**id\_proveedor**, identificacion, razon\_social, ciudad, correo, telefono, estado) | UNIQUE (identificacion) |
| producto\_proveedor | producto\_proveedor (***id\_producto***, ***id\_proveedor***, costo\_referencia, plazo\_entrega\_dias) | id\_producto → productos · id\_proveedor → proveedores |
| clientes | clientes (**id\_cliente**, tipo\_documento, num\_documento, nombre\_completo, correo, telefono, estado) | UNIQUE (tipo\_documento, num\_documento) |

`producto_proveedor` resuelve la relación muchos a muchos entre productos y proveedores (RN-05).

## 3. Esquema `compras` (Compras y Abastecimiento)

Cuatro relaciones: dos cabeceras con sus detalles, para órdenes y para recepciones.

| Relación | Esquema relacional | FK y únicos |
| --- | --- | --- |
| ordenes\_compra | ordenes\_compra (**id\_orden\_compra**, id\_proveedor†, id\_almacen\_destino†, id\_empleado†, fecha\_orden, fecha\_estimada, estado) | — |
| detalle\_orden\_compra | detalle\_orden\_compra (***id\_orden\_compra***, **id\_producto†**, cantidad\_solicitada, costo\_unitario) | id\_orden\_compra → ordenes\_compra |
| recepciones\_compra | recepciones\_compra (**id\_recepcion**, *id\_orden\_compra*, fecha\_recepcion, estado) | id\_orden\_compra → ordenes\_compra |
| detalle\_recepcion | detalle\_recepcion (***id\_recepcion***, **id\_producto†**, cantidad\_recibida) | id\_recepcion → recepciones\_compra |

Una orden puede tener varias recepciones, lo que permite registrar entregas parciales (RN-11). Que el producto recibido esté en el detalle de la orden se garantiza con los datos de prueba: forzarlo con FK exigiría repetir `id_orden_compra` en `detalle_recepcion` y rompería la segunda forma normal.

## 4. Esquema `inventarios` (Inventarios y Transferencias)

Tres relaciones; `inventarios` es la primera de las dos particionadas por sede.

| Relación | Esquema relacional | FK, únicos y partición |
| --- | --- | --- |
| inventarios | inventarios (**id\_sede†**, **id\_almacen†**, **id\_producto†**, existencia\_actual, stock\_minimo, fecha\_actualizacion) | PARTITION BY LIST (id\_sede) |
| transferencias | transferencias (**id\_transferencia**, id\_almacen\_origen†, id\_almacen\_destino†, fecha\_solicitud, fecha\_despacho, fecha\_recepcion, estado) | — |
| detalle\_transferencia | detalle\_transferencia (***id\_transferencia***, **id\_producto†**, cantidad\_enviada, cantidad\_recibida) | id\_transferencia → transferencias |

En `inventarios` toda la clave está formada por identificadores compartidos, porque sedes, almacenes y productos pertenecen a Catálogo. `cantidad_recibida` y las fechas de despacho y recepción admiten NULL hasta que ocurre cada evento (RN-21).

## 5. Esquema `ventas` (Ventas y Pagos)

Cinco relaciones; los pedidos y sus detalles se particionan por sede, y pagos y devoluciones los referencian con la clave compuesta del pedido.

| Relación | Esquema relacional | FK, únicos y partición |
| --- | --- | --- |
| pedidos\_venta | pedidos\_venta (**id\_sede†**, **id\_pedido**, id\_almacen†, id\_cliente†, id\_empleado†, fecha\_pedido, estado, total\_registrado) | PARTITION BY LIST (id\_sede) |
| detalle\_pedido | detalle\_pedido (***id\_sede***, ***id\_pedido***, **id\_producto†**, cantidad, precio\_unitario) | (id\_sede, id\_pedido) → pedidos\_venta · PARTITION BY LIST (id\_sede) |
| pagos | pagos (**id\_pago**, *id\_sede*, *id\_pedido*, fecha\_pago, valor, medio\_pago, estado) | (id\_sede, id\_pedido) → pedidos\_venta |
| devoluciones | devoluciones (**id\_devolucion**, *id\_sede*, *id\_pedido*, fecha\_solicitud, motivo, estado) | (id\_sede, id\_pedido) → pedidos\_venta |
| detalle\_devolucion | detalle\_devolucion (***id\_devolucion***, **id\_producto†**, cantidad, condicion\_producto) | id\_devolucion → devoluciones |

Cada fragmento de `pedidos_venta` tiene su propia secuencia como valor por defecto de `id_pedido`. Así, cuando un vendedor inserta en el fragmento de su sede, recibe el siguiente consecutivo de esa sede. Que el almacén del pedido pertenezca a su sede se controla con los datos de prueba, porque almacenes está en otro esquema.

## 6. Esquema `identidad` (Identidad y Accesos)

Tres relaciones: el personal, sus cuentas de usuario y el registro de accesos.

| Relación | Esquema relacional | FK y únicos |
| --- | --- | --- |
| empleados | empleados (**id\_empleado**, id\_sede†, num\_documento, nombre\_completo, cargo, correo, estado) | UNIQUE (num\_documento) · UNIQUE (correo) |
| usuarios | usuarios (**id\_usuario**, *id\_empleado*, nombre\_usuario, password\_hash, rol, estado, fecha\_creacion) | id\_empleado → empleados · UNIQUE (id\_empleado) · UNIQUE (nombre\_usuario) |
| auditoria\_accesos | auditoria\_accesos (**id\_auditoria**, *id\_usuario*, fecha\_hora, accion, objeto\_consultado) | id\_usuario → usuarios |

El UNIQUE sobre `usuarios.id_empleado` hace que la relación empleado–usuario sea uno a uno (RN-36). El esquema `reportes` no aparece en el modelo relacional porque solo contiene vistas.

## 7. Fragmentos por sede

Doce particiones físicas: cuatro por cada relación particionada, una por sede.

| Sede | id\_sede | inventarios | pedidos\_venta | detalle\_pedido |
| --- | --- | --- | --- | --- |
| Sede Bogotá | 1 | inventarios.inv\_bogota | ventas.ped\_bogota | ventas.det\_ped\_bogota |
| Sede Medellín | 2 | inventarios.inv\_medellin | ventas.ped\_medellin | ventas.det\_ped\_medellin |
| Sede Cali | 3 | inventarios.inv\_cali | ventas.ped\_cali | ventas.det\_ped\_cali |
| CEDI Funza | 4 | inventarios.inv\_cedi | ventas.ped\_cedi | ventas.det\_ped\_cedi |

Cada partición se define con `FOR VALUES IN (n)`. PostgreSQL rechaza cualquier fila cuyo `id_sede` no coincida con una partición, de modo que un registro no puede quedar en dos fragmentos ni en ninguno. No se crea partición por defecto, para que una sede desconocida produzca error en vez de quedar oculta.

## 8. Referencias entre microservicios

Hay 18 identificadores compartidos sin FK declarada; casi todos apuntan a Catálogo, que es el microservicio de datos maestros.

| Relación de origen | Atributo | Referencia a |
| --- | --- | --- |
| compras.ordenes\_compra | id\_proveedor | catalogo.proveedores |
| compras.ordenes\_compra | id\_almacen\_destino | catalogo.almacenes |
| compras.ordenes\_compra | id\_empleado | identidad.empleados |
| compras.detalle\_orden\_compra | id\_producto | catalogo.productos |
| compras.detalle\_recepcion | id\_producto | catalogo.productos |
| inventarios.inventarios | id\_sede | catalogo.sedes |
| inventarios.inventarios | id\_almacen | catalogo.almacenes |
| inventarios.inventarios | id\_producto | catalogo.productos |
| inventarios.transferencias | id\_almacen\_origen | catalogo.almacenes |
| inventarios.transferencias | id\_almacen\_destino | catalogo.almacenes |
| inventarios.detalle\_transferencia | id\_producto | catalogo.productos |
| ventas.pedidos\_venta | id\_sede | catalogo.sedes |
| ventas.pedidos\_venta | id\_almacen | catalogo.almacenes |
| ventas.pedidos\_venta | id\_cliente | catalogo.clientes |
| ventas.pedidos\_venta | id\_empleado | identidad.empleados |
| ventas.detalle\_pedido | id\_producto | catalogo.productos |
| ventas.detalle\_devolucion | id\_producto | catalogo.productos |
| identidad.empleados | id\_sede | catalogo.sedes |

Como la base no garantiza estas referencias, se comprueban con consultas `NOT EXISTS` en el script de pruebas; cada una debe devolver cero filas.
