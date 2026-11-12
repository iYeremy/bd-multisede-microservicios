# 07_consultas: las 20 consultas

`consultas.sql` corre en `andina_reportes`. Cada consulta empieza con un `\echo` que imprime su
título en la salida (así se ve en `docs/evidencias.txt`).

## Antes de leerlas

- **"Hoy" es siempre el 15 de octubre de 2026.** Sale de `reportes.parametros` (la fecha de corte),
  así los resultados no cambian según el día en que se corran.
- **Casi todas leen las vistas consolidadas** (`reportes.vista_pedidos_consolidado`,
  `reportes.vista_inventario_consolidado`…), que ya juntan las 4 sedes. Por eso sirven para toda la
  empresa.
- **Cuando necesitan una tabla de otra base, la traen con `dblink`** directamente en el `FROM` o el
  `JOIN` (ver `03_dblink/`):
  ```sql
  JOIN dblink('srv_catalogo', 'SELECT id_sede, nombre FROM catalogo.sedes')
       AS s(id_sede INTEGER, nombre VARCHAR(60)) ON s.id_sede = p.id_sede
  ```
  Se lee como un `JOIN` normal con la tabla `s`.
- **Las vistas `reportes.*` son materializadas:** están tan al día como el último `REFRESH`. Lo que
  se trae por `dblink` en la consulta, en cambio, es lo que hay en ese momento.

## Dónde está cada cosa que pide el enunciado

| Pide | Consultas |
|---|---|
| `JOIN` | 1, 2, 4, 6, 7, 10, 11, 13, 14, 15, 17, 19 |
| `LEFT JOIN` | 7, 12, 17, 20 |
| `NOT EXISTS` | 3, 16 |
| Subconsulta correlacionada | 10, 16 |
| `GROUP BY` / `HAVING` | 6, 8, 11 / 6, 8 |
| CTE (`WITH`), al menos 4 | 4, 5, 11, 15, 17, 19, 20 |
| Funciones de ventana, al menos 3 | 1 (`SUM OVER`), 4 (`ROW_NUMBER`, `DENSE_RANK`), 5 (`LAG`), 17 (`SUM OVER`), 19 (`RANK`) |
| Operaciones de conjuntos, al menos 2 | 18 (`EXCEPT`, `INTERSECT`) + `UNION ALL` en las vistas |

## Herramientas que conviene tener claras

- **CTE (`WITH nombre AS (...)`):** una subconsulta con nombre, escrita arriba. Sirve para armar la
  consulta por pasos y leerla de arriba hacia abajo. El enunciado pide al menos 4.
- **Subconsulta correlacionada:** una subconsulta que usa columnas de la consulta de afuera, así que
  se vuelve a ejecutar por cada fila.
- **Funciones de ventana** (`... OVER (PARTITION BY ... ORDER BY ...)`): calculan algo mirando otras
  filas **sin agruparlas**. Cada fila conserva su detalle y además "sabe" algo de su grupo.
  - `ROW_NUMBER()`: 1, 2, 3… sin empates.
  - `RANK()`: con empates, y salta números (1, 1, 3).
  - `DENSE_RANK()`: con empates, sin saltar (1, 1, 2).
  - `LAG(x)`: el valor de la fila anterior.
  - `SUM(x) OVER (PARTITION BY sede)`: el total de la sede en cada fila.
- **`COALESCE(x, 0)`:** si `x` es `NULL`, usa 0. Es `CASE WHEN x IS NULL THEN 0 ELSE x END` abreviado.
  Hace falta después de un `LEFT JOIN`: cualquier cuenta con `NULL` da `NULL`, y la fila se perdería.
- **`string_agg(DISTINCT x, ', ' ORDER BY x)`:** junta varios valores en un solo texto.
- **`to_char(fecha, 'YYYY-MM')`:** formatea una fecha como texto.

## Una por una

| # | Qué responde | Cómo |
|---|---|---|
| 1 | Cuánto hay de cada producto en cada almacén y cuánto vale | `pct_valor_sede` usa `SUM(...) OVER (PARTITION BY sede)`: suma el valor de toda la sede sin agrupar filas, así cada fila sabe qué % aporta |
| 2 | Productos en cero o bajo el mínimo | Ordenados por lo que más falta |
| 3 | Productos activos que no están en alguna sede | `CROSS JOIN` arma todas las parejas producto-sede y `NOT EXISTS` deja las que no tienen inventario |
| 4 | Top 5 de productos más vendidos por sede y trimestre | CTE `ventas_producto` (unidades por sede, trimestre y producto) → CTE `ranking`. `ROW_NUMBER` corta exactamente 5 (si empatan, gana el nombre); `DENSE_RANK` muestra quiénes están igualados |
| 5 | Ventas por sede y mes, y cuánto cambió frente al mes anterior | `LAG` trae el mes anterior de la misma sede. El primer mes sale `NULL` (no tiene anterior). Octubre solo llega hasta el 15, por eso parece que cae |
| 6 | Clientes que compraron en al menos 2 sedes | `GROUP BY` cliente + `HAVING COUNT(DISTINCT sede) >= 2`. `string_agg` lista las sedes |
| 7 | Pedidos con saldo por pagar | Los pagos se suman primero (subconsulta `pg`), así un pedido con varios pagos no se repite. `LEFT JOIN` deja los pedidos sin pagos y `COALESCE` cambia su `NULL` por 0 |
| 8 | Pedidos con 3 o más productos distintos | `importe_detalle` se calcula con los detalles y `total_registrado` es el guardado: deben coincidir. `MAX(total_registrado)` es solo para mostrarlo (es igual en todas las filas del pedido) |
| 9 | Pedidos pendientes con más de 15 días | Reutiliza `vista_pedidos_pendientes` y filtra con el umbral de `parametros` |
| 10 | Líneas de pedidos pendientes que piden más de lo que hay | Subconsulta correlacionada: por cada línea busca la existencia de ese producto en el almacén del pedido. Si no hay registro, `COALESCE` lo toma como 0 |
| 11 | Cumplimiento de cada proveedor | Una orden cumple si su última recepción llegó hasta la fecha estimada (RN-14). CTE `ultima_recepcion` + CTE `totales`; el `LEFT JOIN` deja a los proveedores sin órdenes recibidas |
| 12 | Compras pendientes de recibir (incluye parciales) | Pedido vs recibido por orden y producto, sumando todas las recepciones de la orden |
| 13 | Transferencias en tránsito | Despachadas y sin recibir. Almacenes y sedes se unen dos veces (origen y destino) con alias distintos |
| 14 | Diferencias entre enviado y recibido | Solo lo ya recibido (`cantidad_recibida` no es `NULL`) donde no llegó lo mismo |
| 15 | Qué mover de una sede a otra | CTE `stock_sede`, que se une **consigo misma**: `ex` es la sede a la que le sobra y `fa` la que le falta, del mismo producto. Se sugiere mover lo menor entre lo que sobra y lo que falta (con `CASE`, porque no usamos `LEAST`) |
| 16 | Productos con existencia pero sin ventas en 90 días | `NOT EXISTS` (ninguna venta confirmada en 90 días) + `HAVING` (que tenga existencia). `ultima_venta` es una subconsulta correlacionada solo para mostrar la última venta (`NULL` = nunca) |
| 17 | Devoluciones por producto y categoría | Dos CTE (vendidas y devueltas) que se juntan. Solo ventas confirmadas y devoluciones aprobadas (RN-34). El % de la categoría usa una función de ventana |
| 18a | Productos que hay en Bogotá y no en Cali | `EXCEPT`: lo de la primera lista que no está en la segunda. Lee los fragmentos directo (por `dblink`): es una consulta por sede |
| 18b | Productos comunes a Medellín y Cali | `INTERSECT`: lo que está en las dos listas |
| 19 | Ranking de vendedores por sede | `RANK` da el puesto dentro de cada sede; si dos empatan comparten puesto y el siguiente se salta |
| 20 | Consolidado corporativo por sede | Cada fuente se resume en su propia CTE (una fila por sede) y al final se juntan. Si se uniera todo en un solo `JOIN`, los totales saldrían multiplicados. `COUNT(DISTINCT ...)` en transferencias evita contar doble las que van entre las dos bodegas del CEDI |
