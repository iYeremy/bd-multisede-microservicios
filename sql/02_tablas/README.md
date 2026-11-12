# 02_tablas: las tablas de cada microservicio

Un archivo por servicio. Cada uno se corre **conectado a la base de su servicio** (`run_all.sql`
hace el `\c` antes) y crea dentro un esquema con el mismo nombre.

| Archivo | Base | Tablas |
|---|---|---|
| `catalogo.sql` | `andina_catalogo` | sedes, almacenes, categorias, productos, proveedores, producto_proveedor, clientes |
| `identidad.sql` | `andina_identidad` | empleados, usuarios, auditoria_accesos |
| `compras.sql` | `andina_compras` | ordenes_compra, detalle_orden_compra, recepciones_compra, detalle_recepcion |
| `inventarios.sql` | `andina_inventarios` | inv_bogota, inv_medellin, inv_cali, inv_cedi, transferencias, detalle_transferencia |
| `ventas.sql` | `andina_ventas` | ped_* (4), det_ped_* (4), pagos, devoluciones, detalle_devolucion |

El detalle de cada columna está en `docs/diccionario-datos.md`. Aquí va lo que hay que entender.

## Lo que se repite en todos

- **`CREATE SCHEMA ventas`** dentro de `andina_ventas`: el esquema se llama igual que el servicio,
  así una tabla se nombra `ventas.ped_bogota` en cualquier parte.
- **`GENERATED ALWAYS AS IDENTITY`**: la base pone el número sola al insertar (1, 2, 3…). Por debajo
  usa una secuencia, pero no hay que escribirla.
- **`CHECK (col IN (...))`**: solo deja guardar esos valores (los estados).
- **`DEFAULT`**: el valor que se usa si el `INSERT` no manda uno.
- **`NUMERIC(14,2)`**: plata en pesos, exacta. Nunca `float`, que redondea raro.
- **`COMMENT ON TABLE`**: deja escrito en la base qué microservicio es responsable de cada tabla
  (requerimiento 18). Se ve con `\dt+`.

## FK sí, FK no: el `-- ref:`

- **Dentro de una base, FK normales.** Por ejemplo `almacenes.id_sede` tiene FK a `sedes`, porque
  las dos están en `andina_catalogo`.
- **Entre bases, no hay FK.** Una FK no puede apuntar a otra base. Cuando una tabla guarda el id de
  otro servicio, la columna lleva el comentario **`-- ref: catalogo.sedes`**: guarda el id, pero la
  base no revisa que exista. A eso se le llama **identificador compartido**, y en el diagrama
  relacional es el `FK+` (línea punteada).
- Que esos ids existan se revisa en `08_pruebas/` con `NOT EXISTS` (la "prueba extra" de huérfanos).

## catalogo.sql

Son las tablas "base": todos los demás servicios usan sus ids.
- `UNIQUE (id_sede, nombre)` en almacenes: el nombre no se repite **dentro de una sede**.
- `producto_proveedor` es la tabla intermedia de una relación N:M (un producto, varios proveedores, y
  al revés). Su PK es la pareja `(id_producto, id_proveedor)`, y el costo y el plazo son **de la
  pareja**: el mismo producto puede costar distinto según quién lo venda.
- `UNIQUE (tipo_documento, num_documento)` en clientes: la unicidad es de la combinación.
- `precio_lista` es el precio de hoy. Cada venta guarda su propio precio en el detalle (RN-27), así
  cambiar este valor no altera las ventas viejas.

## identidad.sql

- `usuarios.id_empleado` tiene **FK + `UNIQUE`**: eso hace que la relación sea **1:1** (un empleado
  tiene como máximo un usuario, y no todos tienen).
- `rol` (perfil de acceso) es distinto de `cargo` (puesto de trabajo).
- `password_hash` en los datos de prueba es un hash de ejemplo (md5). El login de verdad lo hará el
  backend.

## compras.sql

- `CHECK (fecha_estimada >= fecha_orden)`: un CHECK **de tabla**, que compara dos columnas de la
  misma fila.
- La PK `(id_orden_compra, id_producto)` del detalle impide pedir el mismo producto dos veces en una
  orden.
- `costo_unitario` es el costo pactado **en esa orden**, no el de catálogo: así los reportes de meses
  pasados no cambian.
- Una orden puede tener **varias recepciones**: así se registran las compras que llegan por partes.

## inventarios.sql: la fragmentación horizontal

El inventario **no va en una sola tabla**: va partido por sede.

```
inv_bogota   → CHECK (id_sede = 1)
inv_medellin → CHECK (id_sede = 2)
inv_cali     → CHECK (id_sede = 3)
inv_cedi     → CHECK (id_sede = 4)   (el CEDI tiene dos almacenes: 4 y 5)
```

- Las 4 tablas tienen **las mismas columnas**. Lo único que cambia es el número del `CHECK`.
- Si alguien intenta meter una fila de Cali en `inv_bogota`, el `CHECK` la rechaza (prueba 4b). Así
  una fila nunca queda en dos fragmentos.
- `DEFAULT 1` en `inv_bogota.id_sede`: si el `INSERT` no manda la sede, se pone la del fragmento.
- Para ver el inventario de toda la empresa se juntan las 4 con `UNION ALL`
  (`reportes.vista_inventario_consolidado`).
- **Ojo:** `id_almacen` ya dice de qué sede es, así que `id_sede` sobra un poco. Se deja porque es la
  columna sobre la que va el `CHECK` que parte la tabla (ver `docs/normalizacion.md`, sección 4.1).

**Transferencias** no se fragmentan, porque un traslado puede ir de una sede a otra.
- Tiene dos columnas de almacén (origen y destino), con `CHECK (origen <> destino)`.
- Las fechas quedan `NULL` hasta que pasa cada paso. Los CHECK de orden de fechas usan
  `fecha IS NULL OR ...` para dejar pasar la fila mientras esa fecha no exista.
- `cantidad_recibida` queda `NULL` mientras la transferencia va en camino, y puede ser distinta de
  la enviada (llegó menos).

## ventas.sql: fragmentación por sede y derivada

- **Pedidos partidos por sede**, igual que el inventario: `ped_bogota`, `ped_medellin`, `ped_cali` y
  `ped_cedi`, cada uno con su `CHECK (id_sede = n)`.
- **Cada `ped_*` tiene su propio IDENTITY**, así cada sede numera sus pedidos desde 1. Puede haber un
  pedido 15 en Bogotá y otro 15 en Cali, por eso **la PK es `(id_sede, id_pedido)`**.
- **Fragmentación derivada:** los detalles se parten **igual que su pedido** (`det_ped_bogota` para
  los pedidos de Bogotá…). La FK es **compuesta**, `(id_sede, id_pedido)`, y apunta al pedido de la
  **misma** sede.
- `precio_unitario` en el detalle es el precio del día de la venta (histórico, RN-27).
- `total_registrado` es la suma de los detalles. Se podría calcular, pero se guarda: es lo que se
  cobró. La consulta 8 muestra que cuadra.
- **Pagos y devoluciones** van en una sola tabla cada uno, no por sede. Apuntan al pedido con
  `(id_sede, id_pedido)` pero **sin FK**: una FK solo puede apuntar a una tabla, y el pedido puede
  estar en cualquiera de las 4. `id_sede` dice en cuál buscarlo.
