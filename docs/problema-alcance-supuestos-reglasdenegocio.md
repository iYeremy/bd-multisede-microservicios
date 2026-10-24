# Documento de problema, alcance, supuestos y reglas de negocio

Proyecto final de Bases de Datos · Universidad Distrital Francisco José de Caldas · Ingeniería de Sistemas

Oct 23, 2026 · @Yeremy

## 1. Descripción del problema

Comercializadora Andina S.A.S. (empresa ficticia) necesita una base de datos que le permita operar cada sede por separado y, al mismo tiempo, obtener reportes consolidados de toda la organización.

### 1.1 Contexto

La empresa vende productos de consumo en tres sedes comerciales y opera un centro de distribución que abastece a las sedes y atiende ventas mayoristas. En cada sede se manejan productos, inventarios, pedidos de venta, pagos, compras a proveedores, transferencias entre almacenes y devoluciones.

### 1.2 Situación actual

Cada área registra su información de forma independiente. Esto genera tres problemas:

- **Información dispersa.** Para saber cuánto inventario hay en total, o cuánto vendió la empresa en un mes, hay que reunir datos de varias sedes a mano.
- **Responsabilidades mezcladas.** No está claro qué área es dueña de cada dato, y cualquier usuario podría modificar información que no le corresponde.
- **Poca trazabilidad.** No es fácil detectar faltantes de inventario, compras retrasadas, transferencias que no llegan o pedidos con saldo pendiente.

### 1.3 Necesidad

La organización necesita que cada sede consulte y registre sus propios datos localmente, que cada área sea responsable solo de su información, y que la gerencia obtenga informes corporativos que integren todas las sedes sin duplicar cifras.

### 1.4 Solución propuesta

Se diseña e implementa en PostgreSQL la **capa de datos** de una arquitectura de microservicios. Cada microservicio (Catálogo y Terceros, Compras y Abastecimiento, Inventarios y Transferencias, Ventas y Pagos, Identidad y Accesos, y Reportes Corporativos) es dueño lógico de sus tablas, que viven en un esquema propio. Los inventarios y los pedidos de venta se fragmentan horizontalmente por sede, y el esquema de reportes los integra mediante vistas de solo lectura.

Una única instancia de PostgreSQL con un esquema por microservicio es una **simulación académica** de esta arquitectura. No equivale a desplegar microservicios independientes, cada uno con su propia base de datos, red y ciclo de despliegue. La simulación permite estudiar la separación de responsabilidades, la fragmentación y la integración de datos sin construir esa infraestructura.

## 2. Objetivos

### 2.1 Objetivo general

Diseñar e implementar en PostgreSQL la capa de datos de un sistema comercial multisede organizado por microservicios, con fragmentación horizontal por sede y vistas de integración para reportes corporativos.

### 2.2 Objetivos específicos

1. Construir el modelo Entidad–Relación y transformarlo a un modelo relacional normalizado hasta tercera forma normal.
2. Asignar cada tabla a un microservicio y crear un esquema PostgreSQL por cada uno.
3. Implementar la integridad de los datos con claves primarias, claves foráneas locales, UNIQUE, NOT NULL y CHECK.
4. Fragmentar horizontalmente por sede los inventarios y los pedidos de venta, y unificarlos con vistas consolidadas.
5. Definir seis roles con privilegios diferenciados por esquema y operación.
6. Crear diez vistas y veinte consultas SQL avanzadas que respondan a las necesidades de información de la empresa.
7. Generar datos de prueba coherentes, de al menos cuatro meses, que permitan verificar consultas, restricciones y permisos.

## 3. Alcance

El proyecto cubre el diseño completo y la implementación en PostgreSQL de la capa de datos; la arquitectura de microservicios se diseña y documenta, pero no se programa.

### 3.1 Sedes y almacenes

| Id | Sede | Ciudad | Tipo de sede | Almacenes |
| --- | --- | --- | --- | --- |
| 1 | Sede Bogotá | Bogotá | Venta | Almacén Bogotá |
| 2 | Sede Medellín | Medellín | Venta | Almacén Medellín |
| 3 | Sede Cali | Cali | Venta | Almacén Cali |
| 4 | CEDI Funza | Funza | Distribución | Bodega general CEDI, Bodega de despacho CEDI |

Son cuatro sedes y cinco almacenes. Cada almacén pertenece a una sola sede.

### 3.2 Microservicios y esquemas

| Microservicio | Esquema | Tablas que administra |
| --- | --- | --- |
| Catálogo y Terceros | `catalogo` | sedes, almacenes, categorias, productos, proveedores, producto\_proveedor, clientes |
| Compras y Abastecimiento | `compras` | ordenes\_compra, detalle\_orden\_compra, recepciones\_compra, detalle\_recepcion |
| Inventarios y Transferencias | `inventarios` | inventarios (fragmentada por sede), transferencias, detalle\_transferencia |
| Ventas y Pagos | `ventas` | pedidos\_venta y detalle\_pedido (fragmentadas por sede), pagos, devoluciones, detalle\_devolucion |
| Identidad y Accesos | `identidad` | empleados, usuarios, auditoria\_accesos |
| Reportes Corporativos | `reportes` | Ninguna tabla; solo vistas y consultas de integración de solo lectura |

### 3.3 Fragmentación horizontal

Se fragmentan dos conjuntos operacionales por sede: los **inventarios** y los **pedidos de venta** (con sus detalles). Cada conjunto tiene un fragmento físico por cada una de las cuatro sedes, definido por la condición `id_sede = n`. Un registro pertenece a un solo fragmento, y una vista `UNION ALL` en el esquema `reportes` reúne los cuatro.

### 3.4 Incluido

- Modelo Entidad–Relación, modelo relacional, normalización hasta 3FN y diccionario de datos.
- Diagrama de arquitectura de microservicios con responsables de datos e interacciones conceptuales.
- Scripts de esquemas, tablas, restricciones, fragmentos, vistas, roles, datos de prueba y consultas.
- Diez vistas, veinte consultas avanzadas y una matriz de pruebas de restricciones y permisos.
- Manual de instalación y ejecución con psql o pgAdmin.

### 3.5 Excluido

- Programación de microservicios, API REST, Docker o interfaces web y móviles.
- Despliegue de varias instancias o servidores de base de datos.
- Sincronización en tiempo real entre servicios.
- Triggers, políticas RLS, autenticación web y pruebas de concurrencia, bloqueo o reversión de transacciones.
- Conciliación automática de movimientos de inventario.

### 3.6 Volumen de datos de prueba

| Elemento | Cantidad mínima |
| --- | --- |
| Sedes / almacenes | 4 / 5 |
| Productos / categorías | 80 / 5 |
| Proveedores | 10 |
| Clientes | 100 |
| Empleados | 20 |
| Pedidos de venta | 300 |
| Órdenes de compra | 60 |
| Transferencias | 25 |
| Devoluciones | 20 |

Los datos cubren del 1 de mayo al 15 de octubre de 2026, unos cinco meses y medio.

## 4. Supuestos

Los siguientes supuestos resuelven lo que el enunciado deja abierto; si alguno cambia, se ajustan las reglas de negocio y los scripts.

### 4.1 Organizacionales

- **S-01.** La empresa es ficticia y opera solo en Colombia; todos los valores están en pesos colombianos (COP).
- **S-02.** El CEDI Funza abastece a las sedes comerciales y también vende al por mayor a clientes empresariales. Por eso tiene inventario **y** pedidos de venta.
- **S-03.** Cada empleado trabaja en una sola sede a la vez.
- **S-04.** Un cliente puede comprar en cualquier sede; los clientes son corporativos, no de una sede.
- **S-05.** Los precios de venta incluyen impuestos y no se manejan descuentos. El total de un pedido es la suma de cantidad × precio unitario de sus detalles.
- **S-06.** Las compras a proveedores pueden llegar a cualquier almacén, aunque normalmente llegan al CEDI.

### 4.2 Técnicos

- **S-07.** Se usa una sola instancia de PostgreSQL 16 con un esquema por microservicio, como simulación académica de la arquitectura.
- **S-08.** La fragmentación se implementa con particionamiento declarativo por lista (`PARTITION BY LIST (id_sede)`). Cada partición es una tabla física que se puede consultar por separado.
- **S-09.** Las claves foráneas solo se declaran dentro de un mismo esquema. Las relaciones entre microservicios se manejan con identificadores compartidos y se documentan.
- **S-10.** No hay triggers. Las consecuencias entre servicios (por ejemplo, que una recepción aumente el inventario) se tratan como eventos conceptuales; en los datos de prueba ya se cargan coherentes.
- **S-11.** Los valores monetarios usan `NUMERIC(14,2)` y las cantidades `INTEGER`. Los productos se manejan en unidades enteras.
- **S-12.** Las contraseñas se guardan como hash de ejemplo; no se implementa autenticación real.

### 4.3 De datos y consultas

- **S-13.** Los datos de prueba son sintéticos y reproducibles: se generan con scripts SQL usando una semilla fija.
- **S-14.** La **fecha de corte** de todas las consultas es el **15 de octubre de 2026**, en lugar de la fecha actual del sistema. Así los resultados no cambian según el día en que se ejecuten.
- **S-15.** Un pedido se considera **antiguo** si sigue pendiente más de **15 días** después de su fecha.
- **S-16.** Un producto es de **baja rotación** si tiene existencia positiva y no registra ventas confirmadas en los **90 días** anteriores a la fecha de corte.
- **S-17.** La existencia registrada en inventario es la cifra oficial; no se recalcula a partir de compras, ventas y transferencias.

## 5. Reglas de negocio

Las reglas se agrupan por microservicio; la última columna de cada tabla indica cómo se garantiza la regla en la base de datos.

### 5.1 Catálogo y Terceros

| Código | Regla | Cómo se garantiza |
| --- | --- | --- |
| RN-01 | Cada sede tiene un identificador único y un tipo: venta o distribución. | PK, CHECK |
| RN-02 | Cada almacén pertenece a una sola sede existente. | FK local a sedes |
| RN-03 | Cada producto tiene un SKU único, una categoría y un estado. | UNIQUE, NOT NULL, FK local |
| RN-04 | El precio de lista de un producto es mayor que cero. | CHECK |
| RN-05 | Un producto puede tener uno o varios proveedores, y un proveedor puede surtir varios productos. Cada par guarda un costo de referencia mayor que cero y un plazo de entrega en días (≥ 0). | PK compuesta, FK locales, CHECK |
| RN-06 | La identificación de un proveedor y el par tipo + número de documento de un cliente son únicos. | UNIQUE |
| RN-07 | Un producto inactivo o descontinuado no recibe pedidos nuevos, pero conserva su historial. | Datos de prueba y documentación |

### 5.2 Compras y Abastecimiento

| Código | Regla | Cómo se garantiza |
| --- | --- | --- |
| RN-08 | Cada orden de compra pertenece a un proveedor, llega a un almacén destino y la registra un empleado. | Identificadores compartidos |
| RN-09 | Una orden tiene uno o más productos, cada uno con cantidad solicitada > 0 y costo unitario > 0. | FK local, CHECK |
| RN-10 | La fecha estimada de entrega no es anterior a la fecha de la orden. | CHECK |
| RN-11 | Una orden puede recibirse en una o varias recepciones (recepción total o parcial). Cada recepción pertenece a una orden existente. | FK local |
| RN-12 | La cantidad recibida de un producto es ≥ 0, y el producto debe estar en el detalle de la orden. | CHECK, datos de prueba |
| RN-13 | Una orden queda **recibida** cuando la suma recibida de cada producto alcanza lo solicitado; si llegó algo pero no todo, queda **parcial**. | Datos de prueba |
| RN-14 | Una orden se recibe **dentro del plazo** si su última recepción ocurre en o antes de la fecha estimada. Los días de retraso son la diferencia entre ambas fechas cuando es positiva. | Regla de consulta |

### 5.3 Inventarios y Transferencias

| Código | Regla | Cómo se garantiza |
| --- | --- | --- |
| RN-15 | Existe a lo sumo un registro de inventario por sede, almacén y producto. | PK compuesta |
| RN-16 | La existencia actual y el stock mínimo son ≥ 0. | CHECK |
| RN-17 | Cada registro de inventario va en el fragmento de su sede, y solo en ese. | Clave de partición `id_sede` |
| RN-18 | Hay **alerta de reabastecimiento** cuando la existencia es cero o menor que el stock mínimo. | Regla de consulta |
| RN-19 | Una transferencia tiene un almacén de origen y uno de destino distintos. | CHECK |
| RN-20 | Las fechas de una transferencia siguen el orden solicitud ≤ despacho ≤ recepción. | CHECK |
| RN-21 | La cantidad enviada es > 0. La cantidad recibida es ≥ 0 y queda vacía hasta que la transferencia se recibe. | CHECK, NULL permitido |
| RN-22 | Una transferencia está **en tránsito** si fue despachada y aún no se ha recibido. | Regla de consulta |
| RN-23 | Si la cantidad recibida difiere de la enviada, la diferencia se registra tal cual y se reporta; no se corrige automáticamente. | Regla de consulta |

### 5.4 Ventas y Pagos

| Código | Regla | Cómo se garantiza |
| --- | --- | --- |
| RN-24 | Cada pedido pertenece a una sede, un almacén de esa sede, un cliente y un empleado. | Identificadores compartidos |
| RN-25 | Cada pedido va en el fragmento de su sede, y solo en ese. | Clave de partición `id_sede` |
| RN-26 | Un pedido tiene uno o más productos, cada uno con cantidad > 0 y precio unitario > 0. Un producto no se repite dentro del mismo pedido. | PK compuesta, CHECK |
| RN-27 | El precio unitario se guarda en el detalle al momento de la venta y no cambia aunque cambie el precio de lista. Lo mismo aplica al costo unitario en compras. | Columna en el detalle |
| RN-28 | El total registrado de un pedido es la suma de cantidad × precio unitario de sus detalles, y es ≥ 0. | CHECK, datos de prueba |
| RN-29 | Una **venta confirmada** es un pedido en estado *confirmado* o *entregado*. Los pedidos *pendientes* y *anulados* no cuentan como ventas. | Regla de consulta |
| RN-30 | Un pedido puede tener varios pagos, cada uno con valor > 0. Solo los pagos *confirmados* reducen el saldo. | CHECK |
| RN-31 | El **saldo pendiente** es el total registrado menos la suma de pagos confirmados, y nunca es negativo. | Datos de prueba |
| RN-32 | Solo se aceptan devoluciones de pedidos confirmados o entregados, sobre productos que estén en el pedido. | Datos de prueba |
| RN-33 | La cantidad devuelta de un producto es > 0 y no supera la cantidad vendida en ese pedido. | CHECK (> 0), datos de prueba |
| RN-34 | Solo las devoluciones *aprobadas* cuentan para el porcentaje de devolución. | Regla de consulta |

### 5.5 Identidad y Accesos

| Código | Regla | Cómo se garantiza |
| --- | --- | --- |
| RN-35 | Cada empleado pertenece a una sede y tiene un número de documento único. | UNIQUE, identificador compartido |
| RN-36 | Cada usuario corresponde a un solo empleado y tiene un nombre de usuario único. | FK local, UNIQUE |
| RN-37 | Cada usuario tiene uno de seis roles: administrador, gerencia, inventario, compras, vendedor o auditor. | CHECK |
| RN-38 | Cada acceso relevante queda en la auditoría con usuario, fecha, acción y objeto consultado. | FK local |

### 5.6 Reglas transversales

| Código | Regla | Cómo se garantiza |
| --- | --- | --- |
| RN-39 | Cada microservicio es dueño de sus tablas. Un rol de un microservicio no puede modificar tablas de otro. | GRANT / REVOKE |
| RN-40 | Un vendedor solo registra pedidos y pagos de su sede, y un responsable de inventario solo actualiza las sedes autorizadas. | GRANT sobre los fragmentos de cada sede |
| RN-41 | Gerencia y auditoría solo consultan; no modifican información operativa. | Solo SELECT |
| RN-42 | Los reportes corporativos se calculan en el esquema `reportes` con vistas de solo lectura, agregando cada fuente por separado antes de unirlas para no duplicar cifras. | Diseño de vistas |
| RN-43 | Ningún registro se borra físicamente si tiene historial; se cambia su estado. | Documentación |

### 5.7 Dominios de estados

| Entidad | Valores permitidos (CHECK) |
| --- | --- |
| Sede | `ACTIVA`, `INACTIVA` · tipo: `VENTA`, `DISTRIBUCION` |
| Almacén | `ACTIVO`, `INACTIVO` · tipo: `PRINCIPAL`, `GENERAL`, `DESPACHO` |
| Categoría, proveedor, cliente | `ACTIVO`, `INACTIVO` |
| Producto | `ACTIVO`, `INACTIVO`, `DESCONTINUADO` |
| Orden de compra | `EMITIDA` → `PARCIAL` → `RECIBIDA`; o `CANCELADA` |
| Recepción de compra | `REGISTRADA`, `ANULADA` |
| Transferencia | `SOLICITADA` → `DESPACHADA` → `RECIBIDA`; o `CANCELADA` |
| Pedido de venta | `PENDIENTE` → `CONFIRMADO` → `ENTREGADO`; o `ANULADO` |
| Pago | `PENDIENTE`, `CONFIRMADO`, `RECHAZADO` · medio: `EFECTIVO`, `TARJETA_DEBITO`, `TARJETA_CREDITO`, `TRANSFERENCIA` |
| Devolución | `SOLICITADA`, `APROBADA`, `RECHAZADA` · condición: `BUENO`, `AVERIADO` |
| Empleado | `ACTIVO`, `INACTIVO` |
| Usuario | `ACTIVO`, `BLOQUEADO`, `INACTIVO` |
| Tipo de documento | `CC`, `CE`, `NIT`, `PASAPORTE` |

## 6. Glosario

| Término | Significado |
| --- | --- |
| CEDI | Centro de distribución: sede que almacena y despacha mercancía a las demás sedes. |
| Microservicio | Componente con una responsabilidad de negocio definida y dueño de sus propios datos. |
| Esquema | Espacio de nombres de PostgreSQL que agrupa las tablas de un microservicio. |
| Fragmentación horizontal | División de las filas de una tabla en varias tablas físicas según una condición, aquí la sede. |
| Partición | Tabla física que contiene un fragmento; en este proyecto, una por sede. |
| Identificador compartido | Clave de una entidad de otro microservicio que se guarda sin FK declarada. |
| SKU | Código único que identifica un producto. |
| Stock mínimo | Existencia por debajo de la cual se debe reabastecer un producto en un almacén. |
| Recepción parcial | Recepción que entrega menos de lo solicitado en la orden de compra. |
| Transferencia en tránsito | Traslado ya despachado que aún no se ha recibido en el destino. |
| Saldo pendiente | Valor de un pedido que falta por pagar con pagos confirmados. |
| Fecha de corte | Fecha fija (15 de octubre de 2026) que usan todas las consultas como "hoy". |
