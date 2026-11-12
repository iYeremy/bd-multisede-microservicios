# 05_reportes: las vistas de reportes

Todo esto corre en `andina_reportes`. Reportes **no tiene tablas**: solo vistas que traen los datos
de las otras bases con `dblink` (ver `03_dblink/`).

| Archivo | Qué hace |
|---|---|
| `vistas.sql` | Crea las 14 vistas: 3 que juntan los fragmentos, las 10 del enunciado y la hora del último refresco (más `parametros`) |
| `refrescar.sql` | Pone los reportes al día: `REFRESH` de todas las vistas, en orden |

## Vista normal vs vista materializada

- **Vista normal** (`CREATE VIEW`): una consulta guardada con nombre. No guarda datos: cada vez que
  alguien la lee, se vuelve a ejecutar su consulta.
- **Vista materializada** (`CREATE MATERIALIZED VIEW`): ejecuta la consulta y **guarda el resultado**,
  como si fuera una tabla. Leerla es rápido, pero **no cambia sola**: se actualiza con
  `REFRESH MATERIALIZED VIEW`.

Casi todas las vistas de reportes son materializadas. Así:
- es "la vista que se va actualizando cada X tiempo": se refresca cada X minutos con `refrescar.sql`;
- leer un reporte no tiene que ir por `dblink` a las otras bases cada vez: `dblink` solo trabaja al
  refrescar;
- si una base se cae, los reportes siguen mostrando lo último que se guardó.

El costo: entre un refresco y otro, los reportes pueden ir un poco atrasados (**consistencia
eventual**). `reportes.vista_ultima_actualizacion` dice de cuándo son los datos.

**`WITH NO DATA`:** al final de cada `CREATE MATERIALIZED VIEW`. Crea la vista vacía, sin ejecutar la
consulta todavía. Se llena en el primer `REFRESH` (`run_all.sql` corre `refrescar.sql` justo
después). Antes de eso, leerla da error ("no ha sido poblada").

## Cómo se lee cada vista

Cuando una vista necesita una tabla de otra base, la trae con `dblink` directamente en el `FROM` o en
el `JOIN`, pidiendo solo las columnas que usa:

```sql
FROM reportes.vista_inventario_consolidado i
JOIN dblink('srv_catalogo', 'SELECT id_producto, nombre, precio_lista FROM catalogo.productos')
     AS p(id_producto INTEGER, nombre VARCHAR(100), precio_lista NUMERIC(14,2))
     ON p.id_producto = i.id_producto
```

Se lee como un `JOIN` normal con la tabla `p`: lo único raro es que `p` viene de otra base.

## a. parámetros y consolidadas

- **`reportes.parametros`** (vista normal): la fecha de corte fija (2026-10-15) y los umbrales (15 días
  para pedido antiguo, 90 para baja rotación). Las consultas la usan en vez de `current_date`, así
  los resultados no cambian según el día en que se corran.
- **`vista_inventario_consolidado`**, **`vista_pedidos_consolidado`** y
  **`vista_detalle_pedido_consolidado`**: juntan los 4 fragmentos de cada cosa con `UNION ALL`. Son la
  **reconstrucción** de la tabla completa a partir de sus pedazos.
  - Cada parte del `UNION ALL` trae un fragmento por `dblink`.
  - La columna `fragmento` dice de qué base y tabla viene cada fila (`andina_ventas.ped_cali`). La
    sección 6 del enunciado pide que se vea la procedencia.
  - **`UNION ALL` y no `UNION`:** `UNION` quita repetidos, y para eso tiene que compararlo todo. Aquí
    no puede haber repetidos (el `CHECK` de cada fragmento lo impide), así que sería trabajo perdido.

## b. las 10 vistas del enunciado

| Vista | Qué muestra | Lo que hay que entender |
|---|---|---|
| 1. `vista_inventario_por_sede` | Existencias por producto, sede y almacén, con su valor | Une el consolidado con catálogo para mostrar nombres. Valor = existencia × precio de lista |
| 2. `vista_alertas_reabastecimiento` | Productos en cero o bajo el mínimo | Se apoya en la vista 1, que ya trae los nombres |
| 3. `vista_productos_sin_inventario` | Productos activos sin registro en alguna sede | `CROSS JOIN` arma todas las parejas producto-sede y `NOT EXISTS` deja las que no están en ningún fragmento |
| 4. `vista_ventas_mensuales_por_sede` | Ventas confirmadas por sede y mes | `date_trunc('month', fecha)` lleva cada fecha al día 1 de su mes, para agrupar por mes |
| 5. `vista_pedidos_pendientes` | Pedidos pendientes y cuántos días llevan | Restar dos `DATE` da los días. `CROSS JOIN parametros` (una sola fila) le pega la fecha de corte a cada pedido |
| 6. `vista_saldos_pendientes` | Total, pagado y saldo de cada pedido | Los pagos se suman **primero** por pedido y después se unen, así un pedido con varios pagos no se repite. `LEFT JOIN` deja los pedidos sin pagos, y `COALESCE(pagado, 0)` cambia su `NULL` por 0 |
| 7. `vista_compras_pendientes` | Solicitado vs recibido por orden y producto | El mismo patrón de la 6: sumar primero, `LEFT JOIN` y `COALESCE` |
| 8. `vista_transferencias_en_transito` | Traslados despachados y sin recibir | Almacenes y sedes se unen **dos veces** con alias distintos (`ao`/`so` para el origen, `ad`/`sd` para el destino), porque una transferencia tiene dos almacenes |
| 9. `vista_devoluciones_por_producto` | Unidades vendidas, devueltas y % | Usa `WITH` (CTE): `vendidas` y `devueltas` se calculan aparte y luego se unen por producto |
| 10. `vista_reporte_corporativo` | Resumen por sede | Ver abajo |

### El reporte corporativo y el conteo duplicado

Si se unen pedidos, inventario y compras en un solo `JOIN`, cada pedido se repite una vez por cada
fila del otro lado, y las sumas salen infladas. Por eso **cada fuente se resume aparte** (una CTE por
fuente, con una fila por sede) y al final se juntan por sede. La prueba 10 de `08_pruebas/` comprueba
que los totales cuadran, y muestra el contraejemplo con el `JOIN` directo.

- `COUNT(CASE WHEN ... THEN 1 END)`: cuenta solo las filas que cumplen la condición (las demás dan
  `NULL`, y `COUNT` no cuenta los `NULL`).
- `COALESCE(x, 0)`: si una sede no tiene compras, por ejemplo, el `LEFT JOIN` le deja `NULL`; con
  `COALESCE` sale 0.

## c. hora del último refresco

`vista_ultima_actualizacion` es una vista materializada de una sola fila: `SELECT now()`. Como
`refrescar.sql` la refresca al final, guarda la hora del último refresco. (`now()` da la hora en que
empezó la transacción.)

## refrescar.sql

- Hace `REFRESH MATERIALIZED VIEW` de cada vista: vuelve a ejecutar su consulta (o sea, vuelve a traer
  los datos por `dblink`) y reemplaza el resultado guardado.
- **El orden importa:** si una vista lee de otra, la de abajo se refresca primero. Si no, tomaría sus
  datos viejos.
  1. las consolidadas;
  2. las que leen de ellas o traen datos por `dblink`;
  3. `vista_alertas_reabastecimiento`, que lee `vista_inventario_por_sede`;
  4. `vista_ultima_actualizacion`.
- **Todo en una transacción** (`BEGIN ... COMMIT`): o se actualizan todas o ninguna. Si una base no
  responde, el refresco falla entero y quedan los reportes anteriores.
- Mientras refresca, las vistas quedan bloqueadas para leer un momento (con estos datos, casi nada).
  `REFRESH ... CONCURRENTLY` evitaría eso, pero exige un índice `UNIQUE`, que no vimos.
- **Cada X minutos** (no visto en clase): con `cron` en el servidor.
  ```
  */5 * * * * psql -U postgres -d andina_reportes -f /ruta/del/proyecto/sql/05_reportes/refrescar.sql
  ```
  `*/5 * * * *` = cada 5 minutos, a toda hora, todos los días. Cuando exista el backend, lo hará el
  servicio de reportes.

## Permisos

Una vista materializada ya tiene el resultado guardado, así que leerla solo pide permiso sobre la
vista. Por eso gerencia lee los reportes sin poder usar `dblink` ni entrar a las otras bases. El
`REFRESH` corre con los permisos del **dueño** de la vista (postgres). Ver `06_roles/`.
