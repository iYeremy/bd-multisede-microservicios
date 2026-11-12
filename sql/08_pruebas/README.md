# 08_pruebas: las pruebas de verificación

`pruebas.sql` tiene las pruebas mínimas de la sección 11 del enunciado, más algunas extra. El script
hace sus propios `\c`: las pruebas van **agrupadas por base**, porque cada una tiene que correr donde
está lo que prueba. Por eso los números no van en orden (la prueba 9, de permisos, está repartida en
varias bases).

## Cómo funcionan

- **Muchas pruebas DEBEN fallar** (SKU repetido, permiso denegado…). El `ERROR` que muestra psql es la
  evidencia de que la base lo rechazó. Cada título dice qué se espera: `-> esperado: ERROR ...`.
- **Para que un error no tumbe todo**, el script cambia dos opciones de psql al empezar:
  - `\set ON_ERROR_STOP off`: si algo falla, sigue con lo siguiente.
  - `\set ON_ERROR_ROLLBACK on`: dentro de una transacción, deshace solo la instrucción que falló.
    Sin esto, el primer error "rompe" la transacción y todo lo que sigue también falla.

  Al final las deja como estaban.
- **`BEGIN ... ROLLBACK` por base:** lo que las pruebas insertan o cambian se deshace al final, así el
  script se puede correr las veces que sea sin ensuciar los datos. Hay uno por base porque una
  transacción no puede abarcar dos bases.
- **`SET ROLE usuario` / `RESET ROLE`:** la sesión actúa como ese usuario, con sus permisos, sin tener
  que reconectarse. `RESET ROLE` vuelve a ser postgres.
- **`RETURNING`:** un `INSERT` o `UPDATE` que además muestra lo que guardó.

## Las pruebas

| # | Base | Qué prueba | Resultado esperado |
|---|---|---|---|
| 1 | catálogo | Crear un producto válido y consultarlo | Se crea y se ve |
| 2 | catálogo | Repetir un SKU | ERROR de `UNIQUE` |
| 3 | compras | Cantidad pedida negativa | ERROR de `CHECK` |
| 3b | inventarios | Existencia negativa | ERROR de `CHECK` |
| 4 | catálogo | Producto con una categoría que no existe | ERROR de FK |
| 4b | inventarios | Meter una fila de Medellín en `inv_bogota` | ERROR del `CHECK (id_sede = 1)` |
| 4c | ventas | Detalle de un pedido que no existe | ERROR de la FK compuesta |
| 5 | inventarios / ventas | Los fragmentos de dos sedes tienen filas distintas | Cada fragmento con una sola sede; `INTERSECT` entre fragmentos = 0 |
| 6 | reportes | La vista consolidada junta las 4 sedes | Salen las 4 sedes y el total = la suma de los fragmentos |
| 7a | reportes | Consulta con CTE (`WITH`): ventas por sede | Resultado |
| 7b | reportes | Función de ventana: participación de cada sede | Resultado con % |
| 8 | inventarios | Bogotá vs Medellín con `EXCEPT` e `INTERSECT` | Cuántos productos tiene solo una, solo la otra, o las dos |
| 9.1 | reportes | Gerencia lee el reporte corporativo | Permitido |
| 9.1b | reportes | Gerencia intenta usar `dblink` | ERROR: permiso denegado para la función dblink |
| 9.2 | ventas | Gerencia inserta un pago | ERROR: permiso denegado |
| 9.3 | ventas | `vendedor_bogota` crea un pedido en su fragmento | Permitido (el `DEFAULT` pone la sede y el IDENTITY el número) |
| 9.4 | ventas | `vendedor_bogota` lee los pedidos de Cali | ERROR: permiso denegado |
| 9.5 | catálogo | `vendedor_bogota` cambia un precio | ERROR: permiso denegado (ventas no toca catálogo, RN-39) |
| 9.6 | ventas | `vendedor_bogota` borra un pago | ERROR: permiso denegado (por el `REVOKE DELETE`) |
| 9.7 | inventarios | `inventario_cedi` actualiza su fragmento y el de Bogotá | El suyo sí; el de Bogotá, ERROR |
| 9.8 | identidad | El auditor lee usuarios y luego `password_hash` | Lo primero sí; `password_hash`, ERROR |
| 9.8b | compras | El auditor modifica una orden | ERROR: permiso denegado |
| 10 | reportes | El reporte corporativo no duplica ventas ni cantidades | Cada total del reporte = el mismo total sacado de la fuente. Después, el contraejemplo: con un solo `JOIN` el valor sale inflado |
| extra | reportes | Ids sin FK que apuntan a algo que no existe (huérfanos) | Las 13 filas en 0 |
| 11 | ventas | Desde ventas, leer `catalogo.productos` y `andina_catalogo.catalogo.productos` | ERROR "la relación no existe" y ERROR "cross-database references are not implemented" |
| 11.3 | ventas | A qué base puede entrar cada rol (`has_database_privilege`) | Coincide con la matriz de `06_roles/README.md` |
| 12 | ventas / reportes | Vistas materializadas y consistencia eventual | Ver abajo |

## Prueba extra: referencias sin FK

Entre bases no hay FK, así que la base no impide guardar un id que no existe. Esta prueba lo revisa
a mano: por cada identificador compartido, `NOT EXISTS` cuenta las filas que apuntan a algo que no
está (huérfanos). Las que dicen "de su sede" revisan además que el almacén o el empleado sean de la
misma sede que la fila. Corre en reportes, porque es la única base que puede leer las demás (con
`dblink`).

## Prueba 11: cada base está aislada

Conectados a `andina_ventas`, las tablas de catálogo **no existen**: están en otra base. Y nombrar la
otra base (`andina_catalogo.catalogo.productos`) da "cross-database references are not implemented":
PostgreSQL no deja ir a otra base sin `dblink`, y ventas no lo tiene (se lo quitó al terminar sus
datos de prueba).

## Prueba 12: el reporte no cambia hasta el REFRESH

1. Se cuentan los pedidos de Bogotá en el reporte: **100**.
2. Se guarda un pedido nuevo en `andina_ventas` (en ventas ya hay 101).
3. El reporte **sigue en 100**: la vista materializada tiene guardado el resultado anterior.
4. Se corre `05_reportes/refrescar.sql`.
5. Ahora el reporte dice **101**.
6. Limpieza: se borra el pedido de prueba y se refresca otra vez.

Esta prueba **no va en `BEGIN ... ROLLBACK`**: el refresco tiene que ver el pedido guardado de
verdad. Por eso al final lo borra (es el único `DELETE` del proyecto, y es solo limpieza).
`RETURNING id_pedido AS pedido_prueba \gset` guarda el id que devuelve el `INSERT` en la variable de
psql `:pedido_prueba`, para poder borrarlo después.

## Al final: volumen de datos

Un conteo de cada tabla (leído por `dblink` desde cada base) para comparar con los mínimos de la
sección 10 del enunciado: 300 pedidos, 80 productos, 100 clientes, etc.
