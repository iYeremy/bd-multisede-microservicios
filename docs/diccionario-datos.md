# Diccionario de datos

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Este documento cubre la parte de diccionario de datos del entregable 4. Se generó a partir de los scripts `sql/02` a `sql/08`, que son la fuente de verdad.

Cada microservicio tiene su **propia base de datos** (`andina_<servicio>`) y dentro de ella un esquema con el nombre del servicio. Por eso cada tabla se nombra `esquema.tabla` (por ejemplo `ventas.ped_bogota`), igual en su base y en las consultas por `dblink` de `andina_reportes`.

## Convenciones

| Marca | Significado |
| --- | --- |
| **PK** | Clave primaria o parte de ella |
| **FK → tabla** | Clave foránea declarada en PostgreSQL (siempre dentro de la misma base: una FK no puede apuntar a otra base) |
| **ref → esquema.tabla** | Identificador compartido: guarda el id de una tabla de otro microservicio (que vive en otra base), **sin FK**. Se valida con `NOT EXISTS` en `11_pruebas.sql`, desde `andina_reportes` con `dblink`. En los scripts aparece como el comentario `-- ref:`. |
| **UQ** | Restricción `UNIQUE`. Si dice `UQ (a, b)`, la unicidad es de la combinación. |
| **IDENTITY** | `GENERATED ALWAYS AS IDENTITY`: PostgreSQL asigna el número al insertar. |
| Nulo: **No** | La columna es `NOT NULL` |

Tipos usados: `INTEGER` para identificadores y cantidades (unidades enteras, S-11), `NUMERIC(14,2)` para valores en pesos colombianos, `VARCHAR(n)` para texto, `DATE` para fechas de negocio y `TIMESTAMP` para registros con hora.

## Resumen de tablas

| Base · esquema (microservicio) | Tablas |
| --- | --- |
| `andina_catalogo` · `catalogo` (Catálogo y Terceros) | sedes, almacenes, categorias, productos, proveedores, producto_proveedor, clientes |
| `andina_identidad` · `identidad` (Identidad y Accesos) | empleados, usuarios, auditoria_accesos |
| `andina_compras` · `compras` (Compras y Abastecimiento) | ordenes_compra, detalle_orden_compra, recepciones_compra, detalle_recepcion |
| `andina_inventarios` · `inventarios` (Inventarios y Transferencias) | inv_bogota, inv_medellin, inv_cali, inv_cedi, transferencias, detalle_transferencia |
| `andina_ventas` · `ventas` (Ventas y Pagos) | ped_bogota, ped_medellin, ped_cali, ped_cedi, det_ped_bogota, det_ped_medellin, det_ped_cali, det_ped_cedi, pagos, devoluciones, detalle_devolucion |
| `andina_reportes` · `reportes` (Reportes Corporativos) | Ninguna tabla: vistas materializadas que traen los datos por `dblink` (sección 7) |

En total hay 31 tablas físicas, que corresponden a 22 tablas lógicas.

---

## 1. Base `andina_catalogo` (esquema `catalogo`)

### 1.1 sedes
Sedes de la empresa: tres de venta y un centro de distribución.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_sede | INTEGER | No | PK | IDENTITY | | Identificador de la sede (1 Bogotá, 2 Medellín, 3 Cali, 4 CEDI Funza) |
| nombre | VARCHAR(60) | No | UQ | | | Nombre de la sede |
| ciudad | VARCHAR(60) | No | | | | Ciudad donde está ubicada |
| direccion | VARCHAR(120) | No | | | | Dirección física |
| tipo_sede | VARCHAR(15) | No | | | `VENTA`, `DISTRIBUCION` | Función de la sede (RN-01) |
| estado | VARCHAR(10) | No | | `ACTIVA` | `ACTIVA`, `INACTIVA` | Estado de la sede |

### 1.2 almacenes
Lugares físicos donde se guarda la mercancía. Cada uno pertenece a una sede (RN-02).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_almacen | INTEGER | No | PK | IDENTITY | | Identificador del almacén |
| id_sede | INTEGER | No | FK → sedes · UQ (id_sede, nombre) | | | Sede a la que pertenece |
| nombre | VARCHAR(60) | No | UQ (id_sede, nombre) | | | Nombre del almacén, único dentro de su sede |
| tipo_almacen | VARCHAR(15) | No | | | `PRINCIPAL`, `GENERAL`, `DESPACHO` | Función del almacén |
| estado | VARCHAR(10) | No | | `ACTIVO` | `ACTIVO`, `INACTIVO` | Estado del almacén |

### 1.3 categorias
Agrupación de los productos.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_categoria | INTEGER | No | PK | IDENTITY | | Identificador de la categoría |
| nombre | VARCHAR(60) | No | UQ | | | Nombre de la categoría |
| descripcion | VARCHAR(200) | Sí | | | | Descripción opcional |
| estado | VARCHAR(10) | No | | `ACTIVO` | `ACTIVO`, `INACTIVO` | Estado de la categoría |

### 1.4 productos
Catálogo de productos que se compran, almacenan y venden.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_producto | INTEGER | No | PK | IDENTITY | | Identificador del producto |
| sku | VARCHAR(20) | No | UQ | | | Código único del producto (RN-03) |
| nombre | VARCHAR(100) | No | | | | Nombre del producto |
| id_categoria | INTEGER | No | FK → categorias | | | Categoría a la que pertenece |
| unidad_medida | VARCHAR(10) | No | | | `UND`, `CAJA`, `PAQUETE`, `BOTELLA`, `KG` | Unidad en que se maneja |
| precio_lista | NUMERIC(14,2) | No | | | `> 0` | Precio de venta vigente (RN-04). Las ventas guardan su propio precio (RN-27). |
| estado | VARCHAR(15) | No | | `ACTIVO` | `ACTIVO`, `INACTIVO`, `DESCONTINUADO` | Un producto inactivo o descontinuado no recibe pedidos nuevos (RN-07) |

### 1.5 proveedores
Empresas que surten los productos.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_proveedor | INTEGER | No | PK | IDENTITY | | Identificador del proveedor |
| identificacion | VARCHAR(20) | No | UQ | | | NIT o identificación tributaria (RN-06) |
| razon_social | VARCHAR(100) | No | | | | Nombre legal |
| ciudad | VARCHAR(60) | No | | | | Ciudad del proveedor |
| correo | VARCHAR(100) | No | | | | Correo de contacto |
| telefono | VARCHAR(20) | Sí | | | | Teléfono de contacto |
| estado | VARCHAR(10) | No | | `ACTIVO` | `ACTIVO`, `INACTIVO` | Estado del proveedor |

### 1.6 producto_proveedor
Relación N:M entre productos y proveedores (RN-05).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_producto | INTEGER | No | PK · FK → productos | | | Producto suministrado |
| id_proveedor | INTEGER | No | PK · FK → proveedores | | | Proveedor que lo suministra |
| costo_referencia | NUMERIC(14,2) | No | | | `> 0` | Costo habitual de ese proveedor para ese producto |
| plazo_entrega_dias | INTEGER | No | | | `>= 0` | Días que tarda el proveedor en entregar |

### 1.7 clientes
Clientes de la empresa. Son corporativos: pueden comprar en cualquier sede (S-04).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_cliente | INTEGER | No | PK | IDENTITY | | Identificador del cliente |
| tipo_documento | VARCHAR(10) | No | UQ (tipo_documento, num_documento) | | `CC`, `CE`, `NIT`, `PASAPORTE` | Tipo de documento |
| num_documento | VARCHAR(20) | No | UQ (tipo_documento, num_documento) | | | Número de documento (RN-06) |
| nombre_completo | VARCHAR(120) | No | | | | Nombre de la persona o razón social |
| correo | VARCHAR(100) | Sí | | | | Correo de contacto |
| telefono | VARCHAR(20) | Sí | | | | Teléfono de contacto |
| estado | VARCHAR(10) | No | | `ACTIVO` | `ACTIVO`, `INACTIVO` | Estado del cliente |

---

## 2. Base `andina_identidad` (esquema `identidad`)

### 2.1 empleados
Personal de la empresa. Cada empleado trabaja en una sede (RN-35).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_empleado | INTEGER | No | PK | IDENTITY | | Identificador del empleado |
| id_sede | INTEGER | No | ref → catalogo.sedes | | | Sede donde trabaja |
| num_documento | VARCHAR(20) | No | UQ | | | Documento de identidad |
| nombre_completo | VARCHAR(120) | No | | | | Nombre del empleado |
| cargo | VARCHAR(30) | No | | | `ADMINISTRADOR`, `GERENTE`, `JEFE_INVENTARIO`, `COMPRADOR`, `VENDEDOR`, `AUDITOR`, `BODEGUERO` | Puesto de trabajo |
| correo | VARCHAR(100) | No | UQ | | | Correo corporativo |
| estado | VARCHAR(10) | No | | `ACTIVO` | `ACTIVO`, `INACTIVO` | Estado del empleado |

### 2.2 usuarios
Cuentas de acceso. Un empleado tiene como máximo un usuario (relación 1:1, RN-36).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_usuario | INTEGER | No | PK | IDENTITY | | Identificador del usuario |
| id_empleado | INTEGER | No | FK → empleados · UQ | | | Empleado dueño de la cuenta. El `UNIQUE` hace la relación 1:1. |
| nombre_usuario | VARCHAR(40) | No | UQ | | | Nombre para iniciar sesión |
| password_hash | VARCHAR(100) | No | | | | Hash de la contraseña (S-12). El auditor no puede leerlo. |
| rol | VARCHAR(15) | No | | | `ADMINISTRADOR`, `GERENCIA`, `INVENTARIO`, `COMPRAS`, `VENDEDOR`, `AUDITOR` | Perfil de acceso (RN-37) |
| estado | VARCHAR(10) | No | | `ACTIVO` | `ACTIVO`, `BLOQUEADO`, `INACTIVO` | Estado de la cuenta |
| fecha_creacion | TIMESTAMP | No | | `now()` | | Fecha en que se creó la cuenta |

### 2.3 auditoria_accesos
Registro de las acciones relevantes de los usuarios (RN-38).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_auditoria | INTEGER | No | PK | IDENTITY | | Identificador del registro |
| id_usuario | INTEGER | No | FK → usuarios | | | Usuario que realizó la acción |
| fecha_hora | TIMESTAMP | No | | `now()` | | Momento de la acción |
| accion | VARCHAR(10) | No | | | `LOGIN`, `LOGOUT`, `SELECT`, `INSERT`, `UPDATE`, `DELETE` | Tipo de acción |
| objeto_consultado | VARCHAR(100) | No | | | | Tabla o vista sobre la que actuó |

---

## 3. Base `andina_compras` (esquema `compras`)

### 3.1 ordenes_compra
Pedidos de mercancía a los proveedores (RN-08).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_orden_compra | INTEGER | No | PK | IDENTITY | | Identificador de la orden |
| id_proveedor | INTEGER | No | ref → catalogo.proveedores | | | Proveedor al que se compra |
| id_almacen_destino | INTEGER | No | ref → catalogo.almacenes | | | Almacén donde se recibe la mercancía |
| id_empleado | INTEGER | No | ref → identidad.empleados | | | Empleado que emite la orden |
| fecha_orden | DATE | No | | | | Fecha de emisión |
| fecha_estimada | DATE | No | | | `>= fecha_orden` (RN-10) | Fecha de entrega prometida |
| estado | VARCHAR(10) | No | | `EMITIDA` | `EMITIDA`, `PARCIAL`, `RECIBIDA`, `CANCELADA` | Avance de la orden según lo recibido (RN-13) |

### 3.2 detalle_orden_compra
Productos de cada orden (RN-09).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_orden_compra | INTEGER | No | PK · FK → ordenes_compra | | | Orden a la que pertenece la línea |
| id_producto | INTEGER | No | PK · ref → catalogo.productos | | | Producto solicitado |
| cantidad_solicitada | INTEGER | No | | | `> 0` | Unidades pedidas |
| costo_unitario | NUMERIC(14,2) | No | | | `> 0` | Costo pactado en esta orden. Es histórico (RN-27). |

### 3.3 recepciones_compra
Entregas recibidas de una orden. Una orden puede tener varias recepciones (RN-11).

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_recepcion | INTEGER | No | PK | IDENTITY | | Identificador de la recepción |
| id_orden_compra | INTEGER | No | FK → ordenes_compra | | | Orden que se recibe |
| fecha_recepcion | DATE | No | | | | Fecha en que llegó la mercancía |
| estado | VARCHAR(10) | No | | `REGISTRADA` | `REGISTRADA`, `ANULADA` | Estado de la recepción |

### 3.4 detalle_recepcion
Cantidades recibidas por producto en cada recepción.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_recepcion | INTEGER | No | PK · FK → recepciones_compra | | | Recepción a la que pertenece la línea |
| id_producto | INTEGER | No | PK · ref → catalogo.productos | | | Producto recibido. Debe estar en el detalle de la orden (RN-12). |
| cantidad_recibida | INTEGER | No | | | `>= 0` | Unidades recibidas |

---

## 4. Base `andina_inventarios` (esquema `inventarios`)

### 4.1 inv_bogota, inv_medellin, inv_cali, inv_cedi (fragmentos de `inventarios`)
Existencias por sede, almacén y producto (RN-15). Son **cuatro tablas físicas con la misma estructura**, una por sede. Cada fragmento acepta solo filas de su sede (RN-17).

| Fragmento | Condición | Sede |
| --- | --- | --- |
| inv_bogota | `id_sede = 1` | Bogotá |
| inv_medellin | `id_sede = 2` | Medellín |
| inv_cali | `id_sede = 3` | Cali |
| inv_cedi | `id_sede = 4` | CEDI Funza |

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_sede | INTEGER | No | PK · ref → catalogo.sedes | n (la sede del fragmento) | `= n` | Sede del registro. Es la **clave de fragmentación**. |
| id_almacen | INTEGER | No | PK · ref → catalogo.almacenes | | | Almacén donde está la mercancía. Debe pertenecer a la sede. |
| id_producto | INTEGER | No | PK · ref → catalogo.productos | | | Producto |
| existencia_actual | INTEGER | No | | | `>= 0` (RN-16) | Unidades disponibles registradas. Es la cifra oficial (S-17). |
| stock_minimo | INTEGER | No | | | `>= 0` (RN-16) | Nivel bajo el cual se genera alerta (RN-18) |
| fecha_actualizacion | TIMESTAMP | No | | `now()` | | Última actualización del registro |

La redundancia de `id_sede` se justifica en [`normalizacion.md`](normalizacion.md), sección 4.1.

### 4.2 transferencias
Traslados de mercancía entre almacenes.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_transferencia | INTEGER | No | PK | IDENTITY | | Identificador de la transferencia |
| id_almacen_origen | INTEGER | No | ref → catalogo.almacenes | | `<> id_almacen_destino` (RN-19) | Almacén que despacha |
| id_almacen_destino | INTEGER | No | ref → catalogo.almacenes | | | Almacén que recibe |
| fecha_solicitud | DATE | No | | | | Fecha en que se pidió el traslado |
| fecha_despacho | DATE | Sí | | | `>= fecha_solicitud` (RN-20) | Fecha de salida. Vacía hasta despachar. |
| fecha_recepcion | DATE | Sí | | | Solo si hay despacho, y `>= fecha_despacho` (RN-20) | Fecha de llegada. Vacía hasta recibir. |
| estado | VARCHAR(10) | No | | `SOLICITADA` | `SOLICITADA`, `DESPACHADA`, `RECIBIDA`, `CANCELADA` | Avance del traslado. `DESPACHADA` sin recepción significa en tránsito (RN-22). |

### 4.3 detalle_transferencia
Productos y cantidades de cada transferencia.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_transferencia | INTEGER | No | PK · FK → transferencias | | | Transferencia a la que pertenece la línea |
| id_producto | INTEGER | No | PK · ref → catalogo.productos | | | Producto trasladado |
| cantidad_enviada | INTEGER | No | | | `> 0` (RN-21) | Unidades despachadas |
| cantidad_recibida | INTEGER | Sí | | | `>= 0` (RN-21) | Unidades que llegaron. Vacía hasta recibir. Puede diferir de la enviada (RN-23). |

---

## 5. Base `andina_ventas` (esquema `ventas`)

### 5.1 ped_bogota, ped_medellin, ped_cali, ped_cedi (fragmentos de `pedidos_venta`)
Pedidos de venta. Son **cuatro tablas físicas con la misma estructura**, una por sede, con las condiciones `id_sede = 1` a `id_sede = 4` (RN-25). Cada fragmento numera sus pedidos por separado, así que un pedido se identifica con `(id_sede, id_pedido)`.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_sede | INTEGER | No | PK · ref → catalogo.sedes | n (la sede del fragmento) | `= n` | Sede donde se registró el pedido. Es la **clave de fragmentación**. |
| id_pedido | INTEGER | No | PK | IDENTITY (propio de cada fragmento) | | Número del pedido dentro de su sede |
| id_almacen | INTEGER | No | ref → catalogo.almacenes | | | Almacén que despacha. Debe ser de la sede del pedido (RN-24). |
| id_cliente | INTEGER | No | ref → catalogo.clientes | | | Cliente que compra |
| id_empleado | INTEGER | No | ref → identidad.empleados | | | Vendedor que registra el pedido |
| fecha_pedido | DATE | No | | | | Fecha del pedido |
| estado | VARCHAR(10) | No | | `PENDIENTE` | `PENDIENTE`, `CONFIRMADO`, `ENTREGADO`, `ANULADO` | Solo `CONFIRMADO` y `ENTREGADO` cuentan como venta (RN-29) |
| total_registrado | NUMERIC(14,2) | No | | `0` | `>= 0` | Σ cantidad × precio_unitario de sus detalles (RN-28). Valor derivado que se almacena. |

### 5.2 det_ped_bogota, det_ped_medellin, det_ped_cali, det_ped_cedi (fragmentos de `detalle_pedido`)
Productos de cada pedido (RN-26). Se fragmentan con la **misma condición** que los pedidos (fragmentación derivada), así cada detalle queda en el mismo fragmento que su pedido y se enlaza con una FK local.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_sede | INTEGER | No | PK · FK (id_sede, id_pedido) → ped_\<sede\> | n (la sede del fragmento) | `= n` | Sede del pedido |
| id_pedido | INTEGER | No | PK · FK (id_sede, id_pedido) → ped_\<sede\> | | | Pedido al que pertenece la línea |
| id_producto | INTEGER | No | PK · ref → catalogo.productos | | | Producto vendido. No se repite dentro del pedido (RN-26). |
| cantidad | INTEGER | No | | | `> 0` | Unidades vendidas |
| precio_unitario | NUMERIC(14,2) | No | | | `> 0` | Precio al momento de la venta. Es histórico (RN-27). |

### 5.3 pagos
Pagos de los pedidos. Un pedido puede tener varios pagos (RN-30). No se fragmenta.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_pago | INTEGER | No | PK | IDENTITY | | Identificador del pago |
| id_sede | INTEGER | No | ref → ped_\<sede\> (con id_pedido) | | | Sede del pedido. Indica en qué fragmento está. |
| id_pedido | INTEGER | No | ref → ped_\<sede\> (con id_sede) | | | Pedido que se paga |
| fecha_pago | DATE | No | | | | Fecha del pago |
| valor | NUMERIC(14,2) | No | | | `> 0` | Monto pagado |
| medio_pago | VARCHAR(20) | No | | | `EFECTIVO`, `TARJETA_DEBITO`, `TARJETA_CREDITO`, `TRANSFERENCIA` | Forma de pago |
| estado | VARCHAR(10) | No | | `PENDIENTE` | `PENDIENTE`, `CONFIRMADO`, `RECHAZADO` | Solo los confirmados reducen el saldo (RN-30, RN-31) |

`(id_sede, id_pedido)` no tiene FK porque el pedido puede estar en cualquiera de los cuatro fragmentos, y una FK solo puede apuntar a una tabla.

### 5.4 devoluciones
Solicitudes de devolución sobre pedidos existentes (RN-32). No se fragmenta.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_devolucion | INTEGER | No | PK | IDENTITY | | Identificador de la devolución |
| id_sede | INTEGER | No | ref → ped_\<sede\> (con id_pedido) | | | Sede del pedido |
| id_pedido | INTEGER | No | ref → ped_\<sede\> (con id_sede) | | | Pedido que se devuelve |
| fecha_solicitud | DATE | No | | | | Fecha de la solicitud |
| motivo | VARCHAR(200) | No | | | | Razón de la devolución |
| estado | VARCHAR(10) | No | | `SOLICITADA` | `SOLICITADA`, `APROBADA`, `RECHAZADA` | Solo las aprobadas cuentan en el porcentaje de devolución (RN-34) |

### 5.5 detalle_devolucion
Productos y cantidades de cada devolución.

| Columna | Tipo | Nulo | Clave | Default | Restricciones | Descripción |
| --- | --- | --- | --- | --- | --- | --- |
| id_devolucion | INTEGER | No | PK · FK → devoluciones | | | Devolución a la que pertenece la línea |
| id_producto | INTEGER | No | PK · ref → catalogo.productos | | | Producto devuelto. Debe estar en el pedido (RN-32). |
| cantidad | INTEGER | No | | | `> 0` | Unidades devueltas. No supera lo vendido (RN-33). |
| condicion_producto | VARCHAR(10) | No | | | `BUENO`, `AVERIADO` | Estado en que llegó el producto |

---

## 6. Reglas que la base de datos no impone

Estas reglas están en el modelo, pero no hay una restricción que las haga cumplir. Se respetan en los datos de prueba, y las que son referencias se comprueban con `NOT EXISTS` en `11_pruebas.sql`.

| Regla | Motivo |
| --- | --- |
| Todos los identificadores compartidos (ref) existen en su tabla de origen | No se declaran FK entre microservicios: están en bases distintas (S-09) |
| `pagos` y `devoluciones` apuntan a un pedido existente | El pedido puede estar en cualquiera de los cuatro fragmentos |
| El almacén de un inventario o de un pedido pertenece a la sede de la fila | Entre servicios no hay FK |
| El producto recibido estaba en la orden (RN-12) y el producto devuelto estaba en el pedido (RN-32) | `detalle_recepcion` y `detalle_devolucion` no tienen FK hacia la línea correspondiente |
| Una orden, una recepción, una transferencia, un pedido y una devolución tienen al menos una línea | Una FK no puede exigir un mínimo de filas hijas |
| `total_registrado` y el estado de las órdenes coinciden con sus detalles | No se usan triggers (S-10) |

---

## 7. Base `andina_reportes`

Reportes no tiene tablas. Su base tiene la extensión `dblink` (con un servidor remoto registrado por cada base: `srv_catalogo`, `srv_ventas`…) y el esquema `reportes`, con solo vistas (`08_vistas.sql`). Las de la tabla de abajo son **materializadas**: traen los datos de las otras bases por `dblink`, guardan el resultado y se actualizan con `REFRESH MATERIALIZED VIEW` (`sql/refrescar_reportes.sql`). `parametros` es una vista normal.


### Vistas del esquema `reportes`

| Vista | Tipo | Fuentes | Contenido |
| --- | --- | --- | --- |
| parametros | Apoyo | — | Fecha de corte (2026-10-15) y umbrales de 15 y 90 días (S-14 a S-16) |
| vista_inventario_consolidado | Consolidación | `inv_*` | `UNION ALL` de los 4 fragmentos de inventario, con la columna `fragmento` (base y tabla de origen, p. ej. `andina_inventarios.inv_cali`) |
| vista_pedidos_consolidado | Consolidación | `ped_*` | `UNION ALL` de los 4 fragmentos de pedidos |
| vista_detalle_pedido_consolidado | Consolidación | `det_ped_*` | `UNION ALL` de los 4 fragmentos de detalle |
| vista_inventario_por_sede | Obligatoria 1 | Inventarios, Catálogo | Existencias por producto, sede y almacén |
| vista_alertas_reabastecimiento | Obligatoria 2 | Inventarios, Catálogo | Productos en cero o bajo el stock mínimo |
| vista_productos_sin_inventario | Obligatoria 3 | Inventarios, Catálogo | Productos activos sin registro en alguna sede |
| vista_ventas_mensuales_por_sede | Obligatoria 4 | Ventas, Catálogo | Ventas confirmadas por sede y mes |
| vista_pedidos_pendientes | Obligatoria 5 | Ventas, Identidad, Catálogo | Pedidos pendientes con cliente, vendedor y antigüedad |
| vista_saldos_pendientes | Obligatoria 6 | Ventas, Catálogo | Total, pagos confirmados y saldo por pedido |
| vista_compras_pendientes | Obligatoria 7 | Compras, Catálogo | Cantidades solicitadas frente a recibidas |
| vista_transferencias_en_transito | Obligatoria 8 | Inventarios, Catálogo | Traslados despachados y no recibidos |
| vista_devoluciones_por_producto | Obligatoria 9 | Ventas, Catálogo | Cantidades vendidas, devueltas y porcentaje |
| vista_reporte_corporativo | Obligatoria 10 | Compras, Ventas, Inventarios, Catálogo | Resumen por sede sin conteos duplicados (RN-42) |
| vista_ultima_actualizacion | Control | — | Hora del último `REFRESH` de los reportes |
