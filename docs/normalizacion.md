# Normalización hasta tercera forma normal

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Este documento cubre la parte de normalización del entregable 4. El modelo relacional está en `docs/diagramas/03_modelo_relacional/` y el diccionario de datos en [`diccionario-datos.md`](diccionario-datos.md).

## 1. Criterios

| Forma normal | Condición |
| --- | --- |
| **1FN** | Todos los atributos son atómicos, no hay grupos repetitivos y cada tabla tiene clave primaria. |
| **2FN** | Está en 1FN y ningún atributo **no primo** depende de solo una parte de una clave candidata (no hay dependencias parciales). |
| **3FN** | Está en 2FN y, para toda dependencia funcional no trivial `X → A`, **X es superclave o A es un atributo primo** (no hay dependencias transitivas de atributos no primos). |

- Un **atributo primo** es el que forma parte de alguna clave candidata. La 3FN se evalúa sobre **todas** las claves candidatas, no solo sobre la PK declarada.
- Las tablas fragmentadas (`inv_*`, `ped_*`, `det_ped_*`) tienen la misma estructura en las cuatro sedes, así que se analizan como una sola relación lógica: `inventarios`, `pedidos_venta` y `detalle_pedido`.

## 2. Proceso de normalización: el pedido de venta

Este ejemplo muestra cómo se llega a las tablas de ventas desde el documento que se usa en el negocio. Las tablas de compras (orden y detalle), transferencias y devoluciones se obtienen con el mismo procedimiento.

### 2.1 Forma no normalizada

Un pedido, tal como aparece en el documento impreso, junta datos del pedido, de la sede, del almacén, del cliente, del vendedor y una lista de productos:

```
PEDIDO (id_sede, id_pedido, fecha_pedido, estado, total_registrado,
        nombre_sede, ciudad_sede,
        id_almacen, nombre_almacen,
        id_cliente, num_documento_cliente, nombre_cliente,
        id_empleado, nombre_empleado,
        { id_producto, sku, nombre_producto, nombre_categoria, cantidad, precio_unitario } )
```

Las llaves `{ }` marcan un **grupo repetitivo**: un pedido tiene varios productos.

### 2.2 Primera forma normal

Se separa el grupo repetitivo en su propia relación. Cada fila de esa nueva relación es un producto dentro de un pedido, así que su clave une la del pedido con la del producto:

```
PEDIDO (id_sede, id_pedido, fecha_pedido, estado, total_registrado,
        nombre_sede, ciudad_sede, id_almacen, nombre_almacen,
        id_cliente, num_documento_cliente, nombre_cliente,
        id_empleado, nombre_empleado)

LINEA_PEDIDO (id_sede, id_pedido, id_producto,
              sku, nombre_producto, nombre_categoria, cantidad, precio_unitario)
```

Todos los valores son atómicos y no hay grupos repetitivos.

### 2.3 Segunda forma normal

En `LINEA_PEDIDO` hay **dependencias parciales**: `sku`, `nombre_producto` y `nombre_categoria` dependen solo de `id_producto`, no de toda la clave. Se llevan a una relación de productos:

```
LINEA_PEDIDO (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
PRODUCTO     (id_producto, sku, nombre_producto, nombre_categoria)
```

`cantidad` y `precio_unitario` sí dependen de la clave completa: el mismo producto se vende en distintas cantidades y a distintos precios según el pedido. `precio_unitario` **no** depende solo de `id_producto`, porque es el precio al momento de la venta y puede diferir del precio de lista actual (RN-27).

`PEDIDO` no tiene dependencias parciales: los datos de sede, almacén, cliente y empleado no dependen de una parte de la clave `(id_sede, id_pedido)`, salvo los de la sede, que se tratan en el paso siguiente.

### 2.4 Tercera forma normal

Quedan **dependencias transitivas** a través de identificadores que no son clave:

| En | Dependencia | Se lleva a |
| --- | --- | --- |
| PEDIDO | `id_cliente → num_documento_cliente, nombre_cliente` | `clientes` |
| PEDIDO | `id_empleado → nombre_empleado` | `empleados` |
| PEDIDO | `id_almacen → nombre_almacen` | `almacenes` |
| PEDIDO | `id_sede → nombre_sede, ciudad_sede` | `sedes` |
| PRODUCTO | `id_categoria → nombre_categoria` (se agrega `id_categoria`) | `categorias` |

Resultado, que coincide con el modelo implementado:

```
pedidos_venta  (id_sede, id_pedido, id_almacen, id_cliente, id_empleado,
                fecha_pedido, estado, total_registrado)
detalle_pedido (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
productos      (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado)
categorias     (id_categoria, nombre, descripcion, estado)
clientes       (id_cliente, tipo_documento, num_documento, nombre_completo, correo, telefono, estado)
empleados      (id_empleado, id_sede, num_documento, nombre_completo, cargo, correo, estado)
almacenes      (id_almacen, id_sede, nombre, tipo_almacen, estado)
sedes          (id_sede, nombre, ciudad, direccion, tipo_sede, estado)
```

En `pedidos_venta` quedan juntos `id_sede` e `id_almacen`, y un almacén pertenece a una sola sede. Esa dependencia se analiza en la sección 4.2: no viola la 3FN.

## 3. Verificación tabla por tabla

Se listan las claves candidatas y las dependencias funcionales no triviales de cada tabla. Una dependencia que sale de una clave candidata siempre cumple la 3FN.

### 3.1 Catálogo y Terceros

| Tabla | Claves candidatas | Dependencias funcionales | Forma normal |
| --- | --- | --- | --- |
| sedes | `id_sede`, `nombre` | Clave → ciudad, direccion, tipo_sede, estado | 3FN |
| almacenes | `id_almacen`, `(id_sede, nombre)` | Clave → todos los atributos | 3FN |
| categorias | `id_categoria`, `nombre` | Clave → descripcion, estado | 3FN |
| productos | `id_producto`, `sku` | Clave → nombre, id_categoria, unidad_medida, precio_lista, estado | 3FN |
| proveedores | `id_proveedor`, `identificacion` | Clave → razon_social, ciudad, correo, telefono, estado | 3FN |
| producto_proveedor | `(id_producto, id_proveedor)` | `(id_producto, id_proveedor)` → costo_referencia, plazo_entrega_dias | 3FN |
| clientes | `id_cliente`, `(tipo_documento, num_documento)` | Clave → nombre_completo, correo, telefono, estado | 3FN |

- `producto_proveedor` resuelve la relación N:M entre productos y proveedores. Sus dos atributos dependen del **par**: el mismo producto tiene distinto costo y plazo según el proveedor.
- En `proveedores` y `sedes`, `ciudad` no determina ningún otro atributo, así que no genera dependencias transitivas.

### 3.2 Identidad y Accesos

| Tabla | Claves candidatas | Dependencias funcionales | Forma normal |
| --- | --- | --- | --- |
| empleados | `id_empleado`, `num_documento`, `correo` | Clave → id_sede, nombre_completo, cargo, estado | 3FN |
| usuarios | `id_usuario`, `id_empleado`, `nombre_usuario` | Clave → password_hash, rol, estado, fecha_creacion | 3FN |
| auditoria_accesos | `id_auditoria` | Clave → id_usuario, fecha_hora, accion, objeto_consultado | 3FN |

`usuarios.rol` no se deduce de `empleados.cargo`. El cargo es el puesto de trabajo y el rol es el perfil de acceso a la base de datos; sus dominios son distintos (por ejemplo, `BODEGUERO` es un cargo que no tiene rol propio).

### 3.3 Compras y Abastecimiento

| Tabla | Claves candidatas | Dependencias funcionales | Forma normal |
| --- | --- | --- | --- |
| ordenes_compra | `id_orden_compra` | Clave → id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado | 3FN |
| detalle_orden_compra | `(id_orden_compra, id_producto)` | Clave → cantidad_solicitada, costo_unitario | 3FN |
| recepciones_compra | `id_recepcion` | Clave → id_orden_compra, fecha_recepcion, estado | 3FN |
| detalle_recepcion | `(id_recepcion, id_producto)` | Clave → cantidad_recibida | 3FN |

`costo_unitario` depende de la orden **y** del producto: es el costo pactado en esa orden y no se toma de `producto_proveedor.costo_referencia` (RN-27).

### 3.4 Inventarios y Transferencias

| Tabla | Claves candidatas | Dependencias funcionales | Forma normal |
| --- | --- | --- | --- |
| inventarios (`inv_*`) | `(id_almacen, id_producto)` | `(id_almacen, id_producto)` → existencia_actual, stock_minimo, fecha_actualizacion · **`id_almacen → id_sede`** | **1FN** en sentido estricto (ver 4.1) |
| transferencias | `id_transferencia` | Clave → id_almacen_origen, id_almacen_destino, fechas, estado | 3FN |
| detalle_transferencia | `(id_transferencia, id_producto)` | Clave → cantidad_enviada, cantidad_recibida | 3FN |

En `transferencias`, `estado` no es una dependencia de las fechas: una transferencia sin fecha de despacho puede estar `SOLICITADA` o `CANCELADA`.

### 3.5 Ventas y Pagos

| Tabla | Claves candidatas | Dependencias funcionales | Forma normal |
| --- | --- | --- | --- |
| pedidos_venta (`ped_*`) | `(id_sede, id_pedido)`, `(id_almacen, id_pedido)` | Clave → id_cliente, id_empleado, fecha_pedido, estado, total_registrado · **`id_almacen → id_sede`** | **3FN** (no FNBC, ver 4.2) |
| detalle_pedido (`det_ped_*`) | `(id_sede, id_pedido, id_producto)` | Clave → cantidad, precio_unitario | 3FN |
| pagos | `id_pago` | Clave → id_sede, id_pedido, fecha_pago, valor, medio_pago, estado | 3FN |
| devoluciones | `id_devolucion` | Clave → id_sede, id_pedido, fecha_solicitud, motivo, estado | 3FN |
| detalle_devolucion | `(id_devolucion, id_producto)` | Clave → cantidad, condicion_producto | 3FN |

En `detalle_pedido`, `pagos` y `devoluciones`, `id_sede` no es redundante: forma parte de la referencia al pedido, porque `id_pedido` solo es único dentro de cada sede.

## 4. Casos que requieren justificación

### 4.1 `id_sede` en inventarios: redundancia controlada

**Dependencia:** cada almacén pertenece a una sola sede (RN-02), así que `id_almacen → id_sede`. Lo contrario no se cumple: el CEDI tiene dos almacenes (4 y 5).

**Consecuencia:** la PK declarada `(id_sede, id_almacen, id_producto)` es una superclave, no una clave mínima. La única clave candidata es `(id_almacen, id_producto)`. Entonces `id_sede` es un atributo no primo que depende de una **parte** de la clave, y en sentido estricto la relación no cumple la 2FN.

**Por qué se conserva:**

1. Es la **clave de fragmentación**: el `CHECK (id_sede = n)` de cada fragmento se define sobre esta columna y es lo que garantiza que un registro no quede en dos fragmentos (RN-17).
2. El enunciado propone `Inventarios = (id_sede, id_almacen, id_producto, …)` y el requerimiento 6 pide guardar las existencias "por sede y almacén".
3. Dentro de un fragmento, `id_sede` es constante, así que no puede tomar valores distintos para el mismo almacén. La anomalía de actualización que evita la 2FN no aparece mientras un almacén no cambie de sede.

**Cómo se controla:** `11_pruebas.sql` comprueba con `NOT EXISTS` que cada fila tenga un almacén que pertenezca a la sede de su fragmento (resultado esperado: 0 filas). La base de datos no lo impide por sí sola, porque `almacenes` está en el esquema `catalogo` y entre microservicios no se declaran FK (S-09).

**Alternativa evaluada:** quitar `id_sede` y fragmentar por almacén, con `CHECK (id_almacen = 1)` en Bogotá, … y `CHECK (id_almacen IN (4, 5))` en el CEDI. La tabla quedaría en 3FN y la fragmentación seguiría siendo por sede, pero se apartaría de la estructura del enunciado y el `CHECK` dependería de los identificadores de los almacenes. Se mantiene la versión del enunciado.

> **Pendiente:** confirmar con el profesor cuál de las dos versiones prefiere.

### 4.2 `id_sede` en pedidos_venta: cumple 3FN

Aquí también se cumple `id_almacen → id_sede`, pero la situación es distinta:

- `id_pedido` es único dentro de cada fragmento, y el almacén determina el fragmento. Por eso `(id_almacen, id_pedido)` también es clave candidata, además de `(id_sede, id_pedido)`.
- `id_sede` forma parte de una clave candidata, así que es **atributo primo**. La 3FN acepta `X → A` cuando A es primo, por lo que la relación **cumple la 3FN**.
- No cumple la **FNBC**, porque `id_almacen` no es superclave. El proyecto exige hasta 3FN.

La misma prueba de `11_pruebas.sql` verifica que el almacén y el empleado de cada pedido sean de la sede del pedido.

`id_empleado → id_sede` **no** se toma como dependencia de la tabla: un empleado trabaja en una sede a la vez (S-03), pero puede cambiar de sede, y sus pedidos anteriores conservan la sede donde se registraron. `id_sede` registra un hecho histórico del pedido.

### 4.3 Valores derivados que se almacenan

| Columna | Se puede calcular a partir de | Por qué se guarda |
| --- | --- | --- |
| `pedidos_venta.total_registrado` | Σ cantidad × precio_unitario de `detalle_pedido` (RN-28) | Es el total que quedó registrado en el pedido. La consulta 8 lo muestra junto al importe calculado de los detalles. |
| `ordenes_compra.estado` (`PARCIAL`, `RECIBIDA`) | Las cantidades recibidas frente a las solicitadas (RN-13) | Permite consultar el estado de una orden sin recalcular sus recepciones. |

Estos valores dependen de **otras tablas**, no de atributos de su propia tabla, así que no son dependencias funcionales internas y no afectan la 3FN. Son redundancia controlada: se mantienen coherentes en los datos de prueba porque no se usan triggers (S-10).

### 4.4 Atomicidad (1FN)

- `nombre_completo` y `direccion` se guardan como un solo valor porque el sistema nunca consulta sus partes por separado (nombres, apellidos, calle, número).
- Cada cliente y cada proveedor tiene un solo `telefono` y un solo `correo`. Si tuvieran varios, irían en una tabla aparte.
- Las listas de productos de órdenes, recepciones, transferencias, pedidos y devoluciones se separaron en sus tablas de detalle.

### 4.5 Datos históricos

`precio_unitario` (ventas) y `costo_unitario` (compras) se guardan en el detalle y no se toman del catálogo. Si el precio de lista o el costo de referencia cambian, los reportes de periodos anteriores siguen mostrando el valor de la transacción (requerimiento 12, RN-27). No es redundancia: son datos distintos que dependen de claves distintas.

## 5. Resumen

| Resultado | Tablas |
| --- | --- |
| Cumplen 3FN (y FNBC) | Las otras 20 de las 22 tablas lógicas |
| Cumple 3FN, no FNBC | `pedidos_venta` |
| Redundancia controlada, no cumple 2FN en sentido estricto | `inventarios` (`id_sede`, clave de fragmentación) |

Las dos excepciones vienen de la misma decisión: conservar `id_sede` como clave de fragmentación en los conjuntos que se dividen por sede.
