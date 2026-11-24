# Análisis de resultados

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Este documento interpreta lo que **dicen** las 20 consultas sobre el negocio y justifica las
decisiones de distribución. El **cómo** está hecha cada consulta (qué JOIN, qué CTE, qué función de
ventana) está en [`sql/07_consultas/README.md`](../../../sql/07_consultas/README.md), y la salida completa
en [`evidencias.txt`](../../evidencias.txt). La matriz de pruebas está en
[`matriz-pruebas.md`](../../matriz-pruebas.md).

**Antes de leer los números:**
- Los datos son de prueba, generados con una semilla fija: siempre salen iguales. Sirven para que
  cada consulta tenga casos que mostrar; no describen una empresa real.
- Todas las consultas usan una **fecha de corte fija: 15 de octubre de 2026**
  (`reportes.parametros`), así los resultados no cambian según el día en que se corran. Octubre
  solo tiene medio mes de datos.
- Todas corren en la base de **reportes**, sobre las vistas materializadas que traen los datos de
  las otras cinco instancias por `dblink`.

**Volumen:** 4 sedes, 5 almacenes (el CEDI tiene dos bodegas), 80 productos, 100 clientes,
10 proveedores, 20 empleados, 300 pedidos con 876 líneas, 340 pagos, 22 devoluciones, 60 órdenes de
compra, 70 recepciones, 25 transferencias y 304 registros de inventario, entre mayo y octubre de 2026.

---

## 1. Inventario

### Consulta 1. Inventario por producto y sede (304 filas)
Una fila por producto y almacén, con su valor y el % que aporta al valor de su sede. Las 304 filas
son exactamente la suma de los cuatro fragmentos (72 Bogotá + 69 Medellín + 64 Cali + 99 CEDI), lo
mismo que comprueba la prueba 6. El CEDI tiene casi 100 registros porque surte a todas las sedes y
tiene dos bodegas.

### Consulta 2. Alertas de reabastecimiento (48 alertas)
| Sede | Bajo el mínimo | Sin existencia | Total |
| --- | --- | --- | --- |
| Cali | 14 | 2 | 16 |
| Bogotá | 10 | 3 | 13 |
| Medellín | 7 | **6** | 13 |
| CEDI Funza | 5 | 1 | 6 |

**Lectura:** Medellín es la sede con más productos **en cero** (6), y eso se confirma en la consulta
10: todas las líneas de pedidos pendientes que no se pueden despachar son de Medellín. El faltante
más grande es del CEDI (galletas de soda: 15 unidades contra un mínimo de 67), lo que importa porque
el CEDI es el que reabastece a las demás.

### Consulta 3. Productos activos ausentes por sede (34)
Cali no tiene 15 productos activos del catálogo, Medellín 11, Bogotá 8 y el **CEDI ninguno**: el
centro de distribución tiene el surtido completo, que es lo esperable de una bodega central.

### Consulta 15. Redistribución entre sedes (117 sugerencias, 41 productos)
Para 41 productos hay una sede a la que le sobra y otra a la que le falta. Las sedes con faltantes
que se pueden cubrir así son Cali (42 sugerencias), Medellín (35) y Bogotá (35); el CEDI casi no
necesita (5). **Lectura:** antes de comprarle a un proveedor, buena parte de los faltantes se
resuelve con una transferencia interna, que es más barata y más rápida.

### Consulta 16. Productos de baja rotación (14)
14 productos tienen existencias pero no se vendieron en los últimos 90 días. **5 nunca se vendieron**
(acondicionador, gaseosa naranja, limpiavidrios, carpeta legajadora y grapadora), y tienen entre 200
y 570 unidades. Hay además dos descontinuados (talco y disquetes) y uno inactivo con stock.
**Lectura:** es inventario inmovilizado: candidatos a promoción, liquidación o a no volver a pedir.

---

## 2. Ventas

### Consulta 5. Ventas mensuales y variación (LAG)
| Sede | Mejor mes | Ventas del mejor mes |
| --- | --- | --- |
| CEDI Funza | junio | $5.865.490 |
| Bogotá | julio | $3.891.770 |
| Cali | agosto | $2.524.500 |
| Medellín | julio | $2.229.840 |

Todas las sedes crecen hasta mitad de año y bajan desde septiembre. La caída de **octubre no es
real del todo**: el corte es el 15, así que el mes está a la mitad. Los saltos más grandes (Bogotá
+225 % en junio, CEDI −72 % en julio) muestran por qué conviene `LAG`: compara cada mes con el
anterior **de la misma sede**, sin mezclar sedes.

### Consulta 4. Top 5 por sede y trimestre (60 filas = 4 sedes × 3 trimestres × 5)
`ROW_NUMBER` corta exactamente cinco por grupo y `DENSE_RANK` deja ver los empates: en Bogotá, en el
segundo trimestre, el puesto 2 y el 3 tienen las mismas unidades (13) y comparten nivel. Los
productos líderes cambian de un trimestre a otro: no hay un producto estrella fijo.

### Consulta 8. Pedidos con 3 o más productos distintos (177 de 300)
El 59 % de los pedidos lleva tres productos o más. En todos, el importe calculado desde el detalle
es **igual** al total guardado en el pedido: los totales son consistentes.

### Consulta 19. Ranking de vendedores (RANK)
La vendedora con más ventas es del CEDI (Gloria Barrera, $10,8 millones en 26 pedidos), casi el
doble que el mejor de Bogotá ($5,6 millones). En Medellín, la primera (25 pedidos) vende más que el segundo,
que tiene más pedidos (27): **vender más pedidos no es lo mismo que vender más**, cuenta el valor
de cada uno.

### Consulta 20. Consolidado corporativo
| Sede | Unidades | Ventas | Órdenes de compra | Compras |
| --- | --- | --- | --- | --- |
| Bogotá | 3.879 | $12.190.605 | 4 | $4.231.320 |
| Medellín | 4.108 | $9.293.325 | 4 | $7.785.240 |
| Cali | 3.774 | $8.036.665 | 4 | $7.274.130 |
| CEDI Funza | **21.152** | **$19.348.085** | **46** | **$67.821.310** |
| **Total** | 32.913 | $48.868.680 | 58 | $87.112.000 |

El CEDI concentra el **64 %** de las unidades, el **40 %** de las ventas y el **79 %** de las
órdenes de compra: compra para todos y después reparte. Entre las sedes de venta, Bogotá es la que
más vende. Los totales coinciden **exactamente** con los de las fuentes (prueba 10); si se hiciera
con un solo `JOIN`, las ventas saldrían en $179.923.155, **3,7 veces** el valor real, porque cada
pedido se repetiría por cada orden de compra y cada transferencia de su sede.

---

## 3. Clientes y cobro

### Consulta 6. Clientes que compran en varias sedes (63 de 100)
38 clientes compraron en 2 sedes, 22 en 3 y 3 en las 4. **Lectura:** casi dos de cada tres clientes
son de varias sedes. Por eso los clientes **no** se fragmentan por sede: viven una sola vez en
catálogo y cada sede los referencia por su id.

### Consulta 7. Pedidos con pagos pendientes (61)
61 pedidos tienen saldo (32 pendientes y 29 confirmados), por **$9.301.604,50**. Varios
del CEDI tienen pagado solo un 30 % o un 50 % (por ejemplo, el 43: $581.140 por cobrar). Es la lista
para gestionar cartera.

### Consulta 9. Pedidos pendientes con más de 15 días (22)
Bogotá 8, CEDI 7, Cali 4 y Medellín 3. El más viejo lleva **158 días** (CEDI, del 10 de mayo).
**Lectura:** son pedidos que deberían cerrarse o anularse.

### Consulta 10. Pedidos pendientes que piden más de lo que hay (6 líneas)
Las 6 son de **Medellín** (cuadernos, harina de maíz, toallas de cocina y marcadores), justo los
productos que la consulta 2 marca sin existencia. **Lectura:** cruzar ventas con inventario explica
por qué esos pedidos siguen pendientes.

### Consulta 17. Devoluciones por producto y categoría (julio a octubre)
Alimentos es la categoría con más devoluciones (2,6 % de lo vendido), con dos productos muy por
encima: harina de maíz (15 %) y pasta (12 %). Papelería no tiene devoluciones. **Lectura:** el
problema no es la categoría completa sino dos productos: probablemente un lote o un proveedor.

---

## 4. Compras y proveedores

### Consulta 11. Cumplimiento de proveedores
| Proveedor | Recibidas | A tiempo | Retraso promedio |
| --- | --- | --- | --- |
| Bebidas Andinas | 5 | **0** | 6,6 días |
| Importadora El Puerto | 4 | **0** | 5,0 días |
| Químicos del Caribe | 5 | **5** | 0 |
| Alimentos del Valle | 4 | 4 | 0 |
| Lácteos de la Montaña | 4 | 4 | 0 |

**Lectura:** dos proveedores nunca cumplen la fecha y tres cumplen siempre. Es el dato para
negociar plazos o cambiar de proveedor.

### Consulta 12. Compras pendientes de recibir (16 órdenes, 1.915 unidades)
13 órdenes llegaron a medias (`PARCIAL`) y 3 no han llegado (`EMITIDA`). En las 40 líneas de las
parciales llegó justo la mitad de cada producto: el proveedor despachó en dos entregas y falta la
segunda.

---

## 5. Transferencias

### Consulta 13. En tránsito (13 líneas)
Hay 4 transferencias despachadas sin recibir, con 13 a 39 días en camino. La más vieja, la 20
(CEDI → Cali), salió el 6 de septiembre y lleva **39 días**. **Lectura:** más de un mes en camino es una
alerta: mercancía perdida o una recepción que nadie registró.

### Consulta 14. Diferencias entre enviado y recibido (4)
En 4 transferencias llegó menos de lo enviado (de 1 a 3 unidades, 8 en total): atún, kumis, papel
higiénico y agua con gas. Es **merma** en el transporte, y queda trazada porque se guardan las dos
cantidades.

### Consulta 18. Surtido entre sedes (EXCEPT / INTERSECT)
Bogotá tiene 15 productos que Cali no tiene, y Medellín y Cali comparten 55. Junto con la prueba 8
(Bogotá y Medellín comparten 62; 10 solo están en Bogotá y 7 solo en Medellín), muestra que las
sedes **no** tienen el mismo surtido: por eso el inventario es por sede y no uno solo.

---

## 6. Justificación de las decisiones de distribución

### Una instancia de PostgreSQL por microservicio
Cada servicio tiene su propio servidor, su base y sus usuarios. Se comprobó que el aislamiento es
real: desde ventas, `catalogo.productos` **no existe** (prueba 11.1), PostgreSQL no permite nombrar
otra base (11.2), y la gerencia **ni siquiera existe** como usuario en la instancia de ventas (9.2).
Si una instancia se cae, las otras siguen: eso se vio en vivo con el backend (al apagar catálogo,
ventas sigue mostrando pedidos y solo no deja crear nuevos).

### Por qué se fragmentaron inventarios y pedidos, y por sede
- Son los dos conjuntos **operacionales** de más volumen y que más se escriben (cada venta, cada
  movimiento de bodega).
- Cada sede trabaja **solo con lo suyo**: un vendedor de Bogotá nunca necesita los pedidos de Cali.
  Con una tabla por sede, eso se vuelve un permiso de PostgreSQL (`GRANT` sobre `ped_bogota`) y no
  un `WHERE` que alguien podría olvidar (prueba 9.4: leer `ped_cali` da error de permiso).
- Cada fragmento tiene `CHECK (id_sede = n)`: una fila de otra sede no entra (prueba 4b).
- Los fragmentos no se cruzan: 0 filas repetidas entre `inv_bogota` e `inv_cali` (prueba 5), y la
  vista consolidada suma exactamente los cuatro (304 = 304, prueba 6).
- El **detalle** de cada pedido se fragmenta igual que su pedido (fragmentación derivada): `det_ped_cali`
  apunta a `ped_cali` con una FK compuesta `(id_sede, id_pedido)` (prueba 4c).

### Lo que no se fragmentó, y por qué
- **Catálogo** (productos, clientes, proveedores, sedes): son datos maestros que usan todas las
  sedes. La consulta 6 lo muestra: 63 de 100 clientes compran en varias sedes.
- **Transferencias:** cada una involucra **dos** sedes (origen y destino); partirla obligaría a
  repetirla o a escoger una de las dos.
- **Pagos y devoluciones:** cuelgan de un pedido por `(id_sede, id_pedido)`, y son pocos.

### Reportes: `dblink` + vistas materializadas
- Una consulta no puede leer otra base, así que reportes trae los datos con `dblink` y los guarda
  en **vistas materializadas** que se refrescan cada pocos minutos.
- **Ventaja:** los reportes no cargan a las bases operativas en cada consulta, y si una instancia
  está caída, los reportes siguen mostrando lo último que se trajo.
- **Costo, aceptado a propósito:** los reportes pueden ir unos minutos atrasados (**consistencia
  eventual**). La prueba 12 lo demuestra paso a paso: un pedido nuevo no aparece en el reporte
  (100 pedidos) hasta el `REFRESH` (101).
- **Costo 2:** `dblink` acopla reportes a las tablas de los demás servicios. Es la única base que
  se conecta a otras, y se documenta como la excepción (supuesto S-18).
- Entre bases no hay FK: la integridad de los ids compartidos se revisa a mano con `NOT EXISTS`.
  Las 13 referencias dan **0 huérfanos** (prueba extra).

### El backend
Encima de las bases, cada microservicio es un programa en Go que entra **solo a su instancia** con
su usuario `svc_*`, y le pide a los demás lo que necesita por HTTP. Así la regla "cada servicio es
dueño de sus datos" no depende de la disciplina de quien programa: sin la contraseña de otra
instancia, no hay forma de leerla. El detalle está en [`backend/README.md`](../../../backend/README.md).
