# Entregables

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Esta carpeta tiene **lo que pide la sección 12 del [enunciado](../enunciado.pdf)**, una carpeta por
entregable y en el mismo orden, para revisarlo punto por punto. Son **copias**: los originales
siguen en `docs/` y `sql/`. Se arma con:

```bash
scripts/armar_entregables.sh     # borra y vuelve a copiar todo (menos este README)
```

Los scripts SQL copiados son para leerlos; para **ejecutar** la solución se usa la raíz del
proyecto (`scripts/correr.sh config/local.env`, ver el entregable 14).

---

## 1. Los 15 entregables (sección 12 del enunciado)

| # | Lo que pide el enunciado | Carpeta | Qué hay adentro | ✓ |
| --- | --- | --- | --- | --- |
| 1 | Documento con descripción del problema, alcance, supuestos y reglas de negocio | [01](01-problema-alcance-supuestos-reglas/) | `problema-alcance-supuestos-reglasdenegocio.md`: problema, objetivos, alcance, 18 supuestos y las reglas de negocio (RN-xx) con dónde se implementa cada una | ✓ |
| 2 | Diagrama de arquitectura de microservicios con responsables de cada grupo de datos e interacciones conceptuales | [02](02-diagrama-arquitectura/) | El diagrama (PNG y draw.io): los 6 servicios, sus tablas, qué rol escribe y lee en cada uno, y las vistas de reportes con su procedencia | ✓ |
| 3 | Modelo conceptual Entidad–Relación con cardinalidades | [03](03-modelo-entidad-relacion/) | El diagrama E-R (PNG y draw.io) | ✓ |
| 4 | Modelo relacional, normalización hasta 3FN y diccionario de datos | [04](04-modelo-relacional-normalizacion-diccionario/) | Diagrama relacional; `normalizacion.md` (de 0FN a 3FN con el pedido, tabla por tabla, y las redundancias justificadas); `diccionario-datos.md` (cada tabla y columna con tipo, claves y restricciones) | ✓ |
| 5 | Descripción de esquemas, servicios, fragmentos por sede y vistas de integración | [05](05-esquemas-servicios-fragmentos-vistas/) | `distribucion.md`: instancias y bases, por qué **no** es la simulación académica, condición de fragmentación, cobertura, cómo se evita la duplicación, claves, vistas unificadas, locales y corporativas con su procedencia. `despliegue.md`: cómo se levanta cada instancia | ✓ |
| 6 | Scripts SQL de creación de esquemas, tablas, claves y restricciones | [06](06-scripts-estructura/) | `run_all.sql` y `00_config`, `01_bases`, `02_tablas`, `03_dblink` | ✓ |
| 7 | Scripts de inserción o generación reproducible de datos de prueba | [07](07-scripts-datos-prueba/) | `04_datos`: un script por servicio, con semilla fija (siempre los mismos datos) | ✓ |
| 8 | Scripts de usuarios, roles, concesión y revocación de permisos | [08](08-scripts-seguridad/) | `06_roles`: un script por instancia con `CREATE ROLE`, `GRANT` y `REVOKE`, y en su README la **matriz de permisos** por rol, esquema y operación | ✓ |
| 9 | Scripts de fragmentación de datos y vistas unificadas por sede | [09](09-scripts-fragmentacion-vistas-unificadas/) | `fragmentos/`: las tablas por sede con su `CHECK (id_sede = n)` (inventarios y ventas) y las vistas locales por sede; `vistas-unificadas/`: las vistas `UNION ALL` que juntan los fragmentos | ✓ |
| 10 | Scripts de al menos diez vistas SQL | [10](10-scripts-vistas/) | `05_reportes`: las 10 vistas del enunciado + 3 unificadas + la de última actualización, y `refrescar.sql` | ✓ |
| 11 | Scripts de las veinte consultas avanzadas numeradas | [11](11-scripts-consultas/) | `07_consultas/consultas.sql` (Consulta 1 a 20) y su README con qué recurso SQL usa cada una | ✓ |
| 12 | Resultados y evidencias de las consultas y de las pruebas de restricciones y permisos | [12](12-resultados-evidencias/) | `matriz-pruebas.md` (SQL, esperado, obtenido y evidencia de cada prueba); `evidencias.txt` (local) y `evidencias-neon.txt` (Neon) con la salida completa; `evidencias-backend.txt`; `08_pruebas` | ✓ |
| 13 | Análisis de resultados, interpretación de consultas y justificación de decisiones de distribución | [13](13-analisis-resultados/) | `analisis-resultados.md` | ✓ |
| 14 | Manual de instalación y ejecución con PostgreSQL, pgAdmin o psql | [14](14-manual-instalacion-ejecucion/) | `manual-ejecucion.md` (con psql; explica por qué no con pgAdmin) y `despliegue.md` (local, Docker y nube) | ✓ |
| 15 | Conclusiones, limitaciones y posibles extensiones | [15](15-conclusiones-limitaciones-extensiones/) | `conclusiones.md` | ✓ |

---

## 2. Verificación de los requisitos del enunciado

Cada sección del enunciado, y dónde se comprueba que se cumple.

| Sección | Requisito | Dónde se comprueba | ✓ |
| --- | --- | --- | --- |
| 2 | 4 sedes (una de distribución) y 4+ almacenes | 4 sedes y 5 almacenes: `07-scripts-datos-prueba/04_datos/catalogo.sql` | ✓ |
| 2 | Catálogos, compras, ventas, pagos, inventarios, transferencias y devoluciones | `06-scripts-estructura/02_tablas/` | ✓ |
| 2, 9.2 | Fragmentación horizontal por sede de dos conjuntos | Inventarios (`inv_*`) y pedidos (`ped_*` + `det_ped_*`) | ✓ |
| 2 | Consultas por sede y corporativas | Por sede: los fragmentos y las vistas locales; corporativas: reportes | ✓ |
| 3 | Las tablas sugeridas, con PK, FK, tipos, restricciones y cardinalidades | Todas, incluidas `producto_proveedor`, `detalle_recepcion` y `detalle_devolucion`: diccionario y diagrama relacional (entregable 4) | ✓ |
| 3 | Qué relaciones son FK y cuáles identificadores compartidos | Diccionario (columna "Clave": `FK` vs `ref`) y diagrama relacional (línea continua vs punteada) | ✓ |
| 4 | Los 18 requerimientos específicos | Tabla de abajo | ✓ |
| 5 | Las 20 consultas, con JOIN, LEFT JOIN, NOT EXISTS, subconsultas correlacionadas, GROUP BY, HAVING, 4+ CTE, 3+ funciones de ventana y 2+ operaciones de conjuntos | Tabla de cobertura en `11-scripts-consultas/07_consultas/README.md` (7 con CTE, 5 con ventana, `EXCEPT` e `INTERSECT`) | ✓ |
| 5 | Mostrar la instrucción SQL, el resultado y una breve interpretación | SQL: `consultas.sql` · resultado: `evidencias.txt` · interpretación: `analisis-resultados.md` | ✓ |
| 6 | 10+ vistas con esos nombres, de uso local y de consulta consolidada | 13 consolidadas en reportes + 12 locales por sede en ventas (`pagos_<sede>`...) | ✓ |
| 6 | Identificar de qué fragmentos o microservicios vienen los datos de las vistas | `distribucion.md`, sección 4, y `COMMENT ON` en la base | ✓ |
| 7 | Cada microservicio con su esquema; reportes solo con vistas | Cada servicio con su instancia, su base y su esquema; reportes sin tablas de negocio | ✓ |
| 7 | Un rol de un servicio no modifica tablas de otro | Cada instancia tiene solo sus usuarios (pruebas 9.2, 9.5, 11.3) | ✓ |
| 7 | Explicar en el informe la diferencia con la simulación académica | `distribucion.md` ("No es una simulación académica") y `conclusiones.md`, sección 2 | ✓ |
| 8 | Seis roles, scripts CREATE ROLE / GRANT / REVOKE, matriz de permisos | `08-scripts-seguridad/06_roles/` y su README | ✓ |
| 8 | 2+ accesos permitidos y 2+ denegados | 16 pruebas de permisos (9.x) en `matriz-pruebas.md` | ✓ |
| 8 | El vendedor solo con pedidos y pagos **de su sede** | Pedidos: fragmentos (9.4). Pagos y devoluciones: vistas locales (9.9a–9.9d) | ✓ |
| 9.2 | Condición de fragmentación, cobertura, cómo se evita la duplicación, claves y vista unificada (no solo un `WHERE`) | `distribucion.md`, sección 3; `CHECK (id_sede = n)` en cada fragmento (prueba 4b) | ✓ |
| 10 | Datos mínimos (4 meses, 80 productos, 100 clientes, 300 pedidos, 60 órdenes, 25 transferencias, 20 devoluciones) | 6 meses; volumen al final de `evidencias.txt`; los 12 escenarios en `conclusiones.md` | ✓ |
| 11 | Matriz con SQL, esperado, obtenido y evidencia; las 10 pruebas mínimas | `matriz-pruebas.md`: 40 pruebas de la base, todas dan lo esperado | ✓ |

### Los 18 requerimientos específicos (sección 4)

| # | Requerimiento | Cómo se cumple | ✓ |
| --- | --- | --- | --- |
| 1 | Administración por sede | `sedes` con PK; `almacenes.id_sede` y `empleados.id_sede` la asocian con sus almacenes y empleados | ✓ |
| 2 | Microservicios | 6 servicios, cada uno con su propia instancia, base y esquema (`distribucion.md`) | ✓ |
| 3 | Catálogo: SKU único, categoría, estado; varios proveedores por producto | `sku UNIQUE` (prueba 2), FK a `categorias` (prueba 4), `CHECK` de estado; `producto_proveedor` (N:M) | ✓ |
| 4 | Compras: proveedor, productos, cantidades, costos y fechas | `ordenes_compra` + `detalle_orden_compra` | ✓ |
| 5 | Recepciones totales o parciales | `recepciones_compra` + `detalle_recepcion`; 13 órdenes parciales (consulta 12) | ✓ |
| 6 | Existencias por sede y almacén, con stock mínimo | Fragmentos `inv_<sede>` con `existencia_actual` y `stock_minimo` | ✓ |
| 7 | Ventas: sede, cliente, empleado y varios productos con cantidad y precio | `ped_<sede>` + `det_ped_<sede>` | ✓ |
| 8 | Varios pagos por venta; pagos confirmados y saldos | `pagos`; `vista_saldos_pendientes` y consulta 7 | ✓ |
| 9 | Transferencias: productos, origen, destino, fechas y cantidades | `transferencias` + `detalle_transferencia` (enviada y recibida) | ✓ |
| 10 | Devoluciones de pedidos existentes, con productos y motivo | `devoluciones` (motivo) + `detalle_devolucion` (`condicion_producto`) | ✓ |
| 11 | PK, FK, UNIQUE, NOT NULL y CHECK | En todas las tablas; pruebas 1, 2, 3, 3b, 4, 4b y 4c | ✓ |
| 12 | Históricos de precios | `precio_unitario` en el detalle del pedido y `costo_unitario` en el de la orden: no cambian si cambia el precio de lista | ✓ |
| 13 | Permisos diferenciados por rol | `06_roles/`; 16 pruebas de permisos | ✓ |
| 14 | Vistas para reportes y consolidación | 13 vistas en reportes (+ 12 locales) | ✓ |
| 15 | Inventarios y pedidos fragmentados por sede, con consulta consolidada | Fragmentos + `vista_inventario_consolidado` y `vista_pedidos_consolidado` (prueba 6) | ✓ |
| 16 | SQL avanzado | Las 20 consultas (tabla de cobertura en `07_consultas/README.md`) | ✓ |
| 17 | Datos suficientes, variados y coherentes | `04_datos/`; 0 huérfanos (prueba extra) | ✓ |
| 18 | Cada entidad y vista con un responsable lógico; interacciones e integración explicadas | `COMMENT ON` con el responsable en cada tabla y vista; diagrama de arquitectura; `distribucion.md` | ✓ |

---

## 3. Lo que se agregó además del enunciado

El profesor pidió después **microservicios reales**, con backend y despliegue en la nube:

- **Una instancia de PostgreSQL por servicio** (no la simulación con esquemas).
- **Backend en Go:** un programa por microservicio y un gateway (`backend/`), con su
  `README.md`.
- **Front** servido por el gateway.
- **Docker** (`docker-compose.yml`, `docker-compose.neon.yml`).
- **Despliegue:** las bases en Neon y el backend en una VM de Azure (`docs/despliegue.md`,
  sección 6).
- Las pruebas del backend: `12-resultados-evidencias/evidencias-backend.txt`.
