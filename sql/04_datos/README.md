# 04_datos: los datos de prueba

Un script por servicio, que se corre **conectado a la base de su servicio**, justo después de crear
sus tablas.

| Archivo | Base | Qué carga |
|---|---|---|
| `catalogo.sql` | `andina_catalogo` | 4 sedes, 5 almacenes, 5 categorías, 80 productos, 10 proveedores, 100 clientes |
| `identidad.sql` | `andina_identidad` | 20 empleados, 12 usuarios, 60 accesos de auditoría |
| `compras.sql` | `andina_compras` | 60 órdenes de compra con detalle y recepciones |
| `inventarios.sql` | `andina_inventarios` | existencias de los 5 almacenes (en el fragmento de su sede) y 25 transferencias |
| `ventas.sql` | `andina_ventas` | 300 pedidos con detalle (en el fragmento de su sede), pagos y 22 devoluciones |

- **Periodo:** del 1 de mayo al 15 de octubre de 2026 (más de 4 meses, sección 10 del enunciado).
- **Fecha de corte:** 15 de octubre de 2026. Las consultas la usan como "hoy".

## Trucos que se repiten

| Truco | Qué hace |
|---|---|
| `SELECT setseed(0.2026);` | Fija la semilla de `random()`. Los "números al azar" salen siempre iguales, así los datos son reproducibles: corras cuando corras, da lo mismo. **Cada script pone la suya**, porque cada `\c` abre una sesión nueva y la semilla no pasa de una a otra |
| `generate_series(1, 100)` | Genera las filas 1…100. Con ese número `i` se arma cada fila (clientes, órdenes…) |
| `CREATE TEMP TABLE` | Tablas temporales: desaparecen al cerrar la sesión. Ahí se arman los datos primero y después se reparten a los fragmentos |
| `ARRAY['a','b','c'][i]` | Sacar un valor de una lista por posición (nombres, medios de pago) |
| `x % 10` | Módulo (el residuo). Sirve para repartir: "cada 10 clientes, una empresa" |
| `floor(random() * n)::int` | Un entero al azar entre 0 y n-1 (`::int` convierte a entero) |
| `md5(texto)` | Un hash **de ejemplo** para las contraseñas. MD5 no sirve para contraseñas reales; el backend usará bcrypt |
| `UPDATE ... FROM (subconsulta)` | Actualizar cada fila con un valor calculado en otra consulta (el total de cada pedido) |
| `VALUES (...), (...) AS u(col1, col2)` | Una tabla escrita a mano dentro de la consulta |

## Datos que vienen de otro servicio: dblink

Compras, inventarios y ventas necesitan cosas de otros servicios para armar sus datos:
- **inventarios** necesita los almacenes (con su sede) y los productos de catálogo;
- **ventas** necesita los precios de catálogo y qué productos hay en cada almacén (inventarios), para
  vender solo lo que existe;
- **compras** necesita qué productos vende cada proveedor y a qué costo (catálogo).

Como esos datos están en otra base, se traen con **dblink** (ver `03_dblink/`) a tablas temporales:

```sql
\ir ../03_dblink/servidores.sql          -- instala dblink en esta base

CREATE TEMP TABLE tmp_productos AS
SELECT * FROM dblink('srv_catalogo', 'SELECT id_producto, precio_lista FROM catalogo.productos')
         AS t(id_producto INTEGER, precio_lista NUMERIC(14,2));
...
\ir ../03_dblink/quitar.sql              -- al final, se quita
```

Al terminar, cada uno **quita dblink de su base**, así el servicio no se queda conectado a otra base.
En el sistema real esto sería una llamada HTTP al otro servicio.

Los ids que no hace falta leer se escriben a mano (sedes 1 a 4, clientes 1 a 100, vendedores de cada
sede): son fijos y los crean los scripts de catálogo e identidad.

## Cómo se reparten las filas en los fragmentos

Inventarios y ventas arman primero todo en una tabla temporal y después hacen un `INSERT` por sede:

```sql
INSERT INTO inventarios.inv_bogota (...) SELECT ... FROM tmp_inv WHERE id_sede = 1;
INSERT INTO inventarios.inv_medellin (...) SELECT ... FROM tmp_inv WHERE id_sede = 2;
...
```

Si una fila tuviera otra sede, el `CHECK (id_sede = n)` del fragmento la rechazaría.

**El truco de los ids de pedido:** cada `ped_*` tiene su propio IDENTITY, que numera 1, 2, 3… en el
orden de inserción. El script calcula los mismos números antes, con
`ROW_NUMBER() OVER (PARTITION BY id_sede ORDER BY fecha_pedido, ...)` (numera desde 1 dentro de cada
sede), y los usa en los detalles. Después inserta los pedidos **en ese mismo orden y sin indicar el
número**, así el IDENTITY les pone justo esos ids y la FK de los detalles encuentra su pedido.

## Escenarios forzados a propósito

Para que las 20 consultas den resultados interesantes (sección 10 del enunciado):

| Escenario | Dónde | Para qué consulta |
|---|---|---|
| Productos que nunca se venden: 19, 35, 53, 70, 78 | ventas | 16 (baja rotación) |
| Productos sin ventas desde julio: 12, 27, 44, 58, 75 | ventas | 16 |
| Descontinuados (39, 80) e inactivo (64) | catálogo | 3, 16 |
| Huecos de surtido: Bogotá no tiene los múltiplos de 9, Medellín los de 7, Cali los de 5 | inventarios | 3, 18 |
| ~6 % de existencias en cero y ~14 % bajo el mínimo | inventarios | 2 (alertas) |
| Proveedores 3 y 7 siempre se retrasan | compras | 11 |
| Órdenes parciales (llegó la mitad) | compras | 12 |
| 4 transferencias despachadas y sin recibir | inventarios | 13 |
| Transferencias que llegan con 1 a 3 unidades menos | inventarios | 14 |
| Pedidos viejos que siguen pendientes | ventas | 9 |
| Pagos parciales, anticipos del 30 % y pagos rechazados | ventas | 7 |
| Antes de agosto el precio de venta era 5 % menor | ventas | muestra el precio histórico (RN-27) |
| El CEDI vende al por mayor (hasta 30 unidades por línea) | ventas | S-02 |

## Nota: los datos cambian si cambia el orden de las filas

`ORDER BY random()` (elegir productos al azar para cada pedido) reparte los números al azar **en el
orden en que PostgreSQL recorre las filas**. Si cambia la forma en que se arman las tablas
temporales, ese orden puede cambiar y salen otros productos, aunque la semilla sea la misma. Por eso
los datos de esta rama no son idénticos a los de la rama del ETL (los volúmenes sí). Dentro de una
misma rama siempre salen iguales.
