# Análisis del Proyecto Final de Bases de Datos
## Sistema de gestión comercial multisede basado en una arquitectura de microservicios

## 1. Descripción general del proyecto

### 1.1. Contexto del problema

Una empresa comercial cuenta con varias sedes de venta y un centro de distribución. Cada sede administra productos, inventarios, pedidos, compras y transferencias de mercancía. La organización necesita consultar la información correspondiente a cada sede de manera independiente y, al mismo tiempo, obtener reportes corporativos que integren los datos de toda la empresa.

La información debe organizarse de forma que las diferentes áreas del negocio tengan responsabilidades claramente delimitadas. Esto implica separar la administración del catálogo de productos y terceros, las compras, los inventarios, las ventas, la identidad de los usuarios y la generación de reportes.

Además, la distribución de los datos debe permitir que la información operacional se encuentre organizada por sede cuando corresponda, sin perder la posibilidad de realizar consultas consolidadas.

### 1.2. Problema que se busca resolver

El proyecto busca representar y resolver las necesidades de gestión de información de una empresa comercial multisede mediante una solución de bases de datos estructurada, íntegra y distribuida lógicamente.

El sistema debe permitir:

- Administrar las sedes, los almacenes y las entidades comerciales relacionadas.
- Mantener un catálogo de productos, categorías, proveedores y clientes.
- Registrar las compras, las recepciones de mercancía y las relaciones con los proveedores.
- Controlar las existencias y los niveles mínimos de inventario.
- Registrar los pedidos de venta, sus detalles y los pagos asociados.
- Gestionar las transferencias de productos entre almacenes.
- Registrar las devoluciones de productos vendidos.
- Separar las responsabilidades de los diferentes módulos del sistema.
- Controlar el acceso a la información mediante usuarios, roles y permisos.
- Consultar información operacional de una sede específica.
- Obtener informes consolidados que integren información de todas las sedes.
- Verificar la integridad de los datos y la consistencia de los resultados mediante pruebas.

### 1.3. Objetivo general

Diseñar, implementar y verificar una solución de bases de datos para la gestión comercial de una empresa multisede, organizada mediante una arquitectura de microservicios, que permita administrar las operaciones comerciales, preservar la integridad de la información, distribuir los datos operacionales por sede y generar consultas y reportes corporativos consolidados.

### 1.4. Objetivos específicos

1. Definir el modelo conceptual Entidad–Relación de la organización, incluyendo las entidades, sus atributos, las relaciones y las cardinalidades.
2. Transformar el modelo conceptual en un modelo relacional normalizado hasta la tercera forma normal (3FN).
3. Establecer las entidades, los atributos, las claves y las restricciones necesarias para representar las operaciones comerciales.
4. Delimitar las responsabilidades de los módulos de datos y sus relaciones de información.
5. Implementar restricciones de integridad que permitan prevenir registros inválidos, duplicados o inconsistentes.
6. Representar la distribución horizontal de los datos operacionales por sede.
7. Permitir consultas locales y corporativas sobre los datos distribuidos.
8. Definir roles y permisos diferenciados según las responsabilidades de los usuarios.
9. Crear vistas SQL para facilitar la consulta de información recurrente y consolidada.
10. Desarrollar las veinte consultas SQL avanzadas exigidas por el proyecto.
11. Generar datos de prueba suficientes para demostrar los distintos escenarios comerciales.
12. Verificar mediante pruebas el funcionamiento de las restricciones, los permisos, la fragmentación y las consultas.

---

## 2. Alcance del sistema

### 2.1. Funcionalidades incluidas

El sistema contempla la administración de las siguientes áreas:

- **Organización:** sedes, almacenes y sus estados.
- **Catálogo comercial:** productos, categorías y unidades de medida.
- **Terceros:** proveedores y clientes.
- **Compras y abastecimiento:** órdenes de compra, detalles, recepciones y cantidades recibidas.
- **Inventarios:** existencias actuales, stock mínimo y ubicación de los productos.
- **Transferencias:** movimientos de mercancía entre almacenes, cantidades enviadas y recibidas.
- **Ventas:** pedidos, detalles, clientes, empleados y precios históricos.
- **Pagos:** pagos asociados a pedidos, medios de pago, estados y saldos pendientes.
- **Devoluciones:** solicitudes, motivos, productos y cantidades devueltas.
- **Identidad y accesos:** empleados, usuarios, roles y auditoría de accesos.
- **Reportes:** vistas locales y consolidadas para analizar las operaciones de la empresa.
- **Distribución de datos:** fragmentos operacionales por sede y consultas que integren dichos fragmentos.
- **Seguridad de la base de datos:** administración de roles, privilegios y restricciones de acceso.

### 2.2. Requisitos y límites explícitos

El proyecto exige diseñar y representar una arquitectura de microservicios e implementar y probar su capa de datos.

No exige:

- Programar microservicios funcionales.
- Construir API REST.
- Utilizar Docker.
- Desarrollar interfaces web o móviles.
- Desplegar infraestructura adicional para ejecutar servicios independientes.
- Implementar autenticación web.
- Implementar políticas de seguridad por filas (RLS).
- Realizar pruebas de concurrencia o demostraciones de bloqueo.
- Implementar automatización mediante triggers.
- Desarrollar mecanismos complejos de conciliación de movimientos de inventario.
- Implementar sincronización de datos en tiempo real entre los componentes.

La arquitectura debe quedar documentada y representada conceptualmente. La implementación de los datos, las consultas, las restricciones y los permisos sí debe poder ejecutarse y verificarse.

---

## 3. Requisitos mínimos del sistema

La solución debe cumplir, como mínimo, las siguientes condiciones:

| Elemento | Requisito |
|---|---|
| Sedes | Cuatro o más, incluida una sede de distribución. |
| Almacenes | Cuatro o más asociados a las sedes. |
| Productos | Catálogo con identificador y SKU único. |
| Categorías | Cinco o más categorías en los datos de prueba. |
| Proveedores | Diez o más registros de prueba. |
| Clientes | Cien o más registros de prueba. |
| Empleados | Veinte o más registros de prueba. |
| Pedidos de venta | Trescientos o más, con detalles y estados diferentes. |
| Órdenes de compra | Sesenta o más, con sus recepciones asociadas. |
| Transferencias | Veinticinco o más, con sus respectivos detalles. |
| Devoluciones | Veinte o más, con sus respectivos detalles. |
| Periodo de prueba | Al menos cuatro meses de registros. |
| Fragmentación | Fragmentación horizontal por sede de dos conjuntos operacionales. |
| Vistas | Diez o más vistas SQL. |
| Consultas | Veinte consultas SQL obligatorias. |
| Normalización | Hasta tercera forma normal. |
| Seguridad | Roles, permisos y pruebas de accesos permitidos y denegados. |
| Integración | Consultas y vistas consolidadas entre sedes y módulos. |

Estos valores representan mínimos. Pueden existir más registros, entidades o estructuras siempre que se mantengan los requisitos establecidos.

---

## 4. Modelo conceptual del negocio

El modelo conceptual debe representar las entidades principales, sus atributos relevantes, las relaciones entre ellas y las cardinalidades.

### 4.1. Entidades principales

- **Sede:** representa una ubicación de la empresa.
- **Almacén:** representa un lugar físico donde se almacenan productos.
- **Categoría:** clasifica los productos.
- **Producto:** representa un artículo comercializable o administrado por la empresa.
- **Proveedor:** representa una entidad que suministra productos.
- **Cliente:** representa a quien realiza compras.
- **Empleado:** representa al personal de la empresa.
- **Usuario:** representa una cuenta con acceso al sistema.
- **Orden de compra:** registra una solicitud de abastecimiento a un proveedor.
- **Detalle de orden de compra:** registra los productos, cantidades y costos solicitados.
- **Recepción de compra:** registra la recepción total o parcial de una orden.
- **Detalle de recepción:** registra las cantidades recibidas por producto.
- **Inventario:** representa las existencias registradas de un producto en una ubicación.
- **Transferencia:** representa el traslado de mercancía entre almacenes.
- **Detalle de transferencia:** registra las cantidades enviadas y recibidas por producto.
- **Pedido de venta:** representa una operación comercial asociada a una sede, un cliente y un empleado.
- **Detalle de pedido:** contiene los productos, las cantidades y los precios de una venta.
- **Pago:** registra un pago asociado a un pedido.
- **Devolución:** representa una solicitud de devolución asociada a un pedido.
- **Detalle de devolución:** identifica los productos y las cantidades devueltas.
- **Auditoría de accesos:** registra acciones relacionadas con el acceso y la consulta de información.

### 4.2. Relaciones y cardinalidades esperadas

Las siguientes relaciones se derivan de las entidades y operaciones descritas en el documento:

| Relación | Cardinalidad esperada | Descripción |
|---|---|---|
| Sede - Almacén | 1:N | Una sede puede tener varios almacenes. |
| Sede - Empleado | 1:N | Una sede puede tener varios empleados. |
| Categoría - Producto | 1:N | Una categoría puede clasificar varios productos. |
| Producto - Proveedor | N:M | Un producto puede tener varios proveedores y un proveedor puede suministrar varios productos. |
| Proveedor - Orden de compra | 1:N | Un proveedor puede estar asociado a múltiples órdenes. |
| Orden de compra - Detalle de orden | 1:N | Una orden contiene uno o varios productos. |
| Orden de compra - Recepción | 1:N | Una orden puede tener varias recepciones. |
| Recepción - Detalle de recepción | 1:N | Una recepción registra cantidades por producto. |
| Almacén - Inventario | 1:N | Un almacén puede tener existencias registradas de distintos productos. |
| Producto - Inventario | 1:N | Un producto puede tener registros de inventario en distintas ubicaciones. |
| Almacén - Transferencia | 1:N | Un almacén puede intervenir en múltiples transferencias como origen o destino. |
| Transferencia - Detalle de transferencia | 1:N | Una transferencia puede contener varios productos. |
| Cliente - Pedido de venta | 1:N | Un cliente puede realizar varios pedidos. |
| Empleado - Pedido de venta | 1:N | Un empleado puede gestionar varios pedidos. |
| Sede - Pedido de venta | 1:N | Una sede puede registrar múltiples pedidos. |
| Pedido de venta - Detalle de pedido | 1:N | Un pedido puede contener varios productos. |
| Pedido de venta - Pago | 1:N | Un pedido puede tener varios pagos. |
| Pedido de venta - Devolución | 1:N | Un pedido puede estar relacionado con devoluciones. |
| Devolución - Detalle de devolución | 1:N | Una devolución puede incluir varios productos. |
| Empleado - Usuario | 1:N o 1:1 | La cardinalidad definitiva debe establecerse según las reglas de cuentas del sistema. |
| Usuario - Auditoría de accesos | 1:N | Un usuario puede generar múltiples registros de auditoría. |

Las cardinalidades deberán quedar explícitas en el diagrama Entidad–Relación. Las relaciones entre módulos deben distinguirse de las relaciones que pueden garantizarse mediante claves foráneas locales.

---

## 5. Organización lógica por módulos de datos

La solución debe separar las responsabilidades en seis módulos principales. Cada entidad y cada vista debe tener un responsable lógico claramente identificado.

### 5.1. Catálogo y Terceros

**Responsabilidad:** mantener los datos maestros y de referencia de la organización y sus participantes comerciales.

Entidades:

- `Sedes`
- `Almacenes`
- `Categorias`
- `Productos`
- `Proveedores`
- `Producto_Proveedor`
- `Clientes`

Requisitos principales:

- Identificar de manera única cada sede.
- Asociar almacenes con sus respectivas sedes.
- Clasificar los productos mediante categorías.
- Mantener un SKU único para cada producto.
- Registrar el estado de los productos y las entidades que lo requieran.
- Representar la relación entre productos y proveedores.
- Conservar la información de identificación y contacto de clientes y proveedores.

### 5.2. Compras y Abastecimiento

**Responsabilidad:** registrar las solicitudes de compra y controlar el cumplimiento de las recepciones.

Entidades:

- `Ordenes_Compra`
- `Detalle_Orden_Compra`
- `Recepciones_Compra`
- `Detalle_Recepcion`

Requisitos principales:

- Asociar cada orden con un proveedor, un almacén de destino y un empleado.
- Registrar fechas de orden y fechas estimadas.
- Conservar los productos, cantidades solicitadas y costos unitarios.
- Registrar recepciones completas y parciales.
- Asociar las recepciones con las órdenes correspondientes.
- Comparar las cantidades solicitadas con las cantidades recibidas.
- Analizar retrasos y cumplimiento de los proveedores.

### 5.3. Inventarios y Transferencias

**Responsabilidad:** administrar las existencias registradas y los traslados de mercancía.

Entidades:

- `Inventarios`
- `Transferencias`
- `Detalle_Transferencia`

Requisitos principales:

- Registrar las existencias de cada producto por sede y almacén.
- Mantener el stock mínimo de cada producto en cada ubicación.
- Registrar la fecha de actualización del inventario.
- Identificar los almacenes de origen y destino de una transferencia.
- Registrar las fechas de solicitud, despacho y recepción.
- Conservar las cantidades enviadas y recibidas.
- Detectar faltantes, excesos, transferencias pendientes y diferencias de recepción.
- Permitir consultas de inventario por sede y consultas corporativas consolidadas.

### 5.4. Ventas y Pagos

**Responsabilidad:** registrar los pedidos comerciales, sus productos, los pagos y las devoluciones.

Entidades:

- `Pedidos_Venta`
- `Detalle_Pedido`
- `Pagos`
- `Devoluciones`
- `Detalle_Devolucion`

Requisitos principales:

- Asociar cada pedido con una sede, un almacén, un cliente y un empleado.
- Registrar la fecha, el estado y el total registrado del pedido.
- Permitir varios productos en un mismo pedido.
- Conservar la cantidad y el precio unitario de cada producto.
- Registrar varios pagos asociados a un pedido.
- Identificar pagos confirmados y saldos pendientes.
- Registrar devoluciones vinculadas a pedidos existentes.
- Conservar el motivo, el estado, las cantidades y la condición de los productos devueltos.
- Proporcionar información suficiente para analizar las ventas y las devoluciones por sede, producto y periodo.

### 5.5. Identidad y Accesos

**Responsabilidad:** administrar las cuentas de acceso y la información necesaria para controlar los privilegios.

Entidades:

- `Empleados`
- `Usuarios`
- `Auditoria_Accesos`

Requisitos principales:

- Asociar empleados con las sedes correspondientes.
- Registrar la información de identificación y el cargo de los empleados.
- Mantener nombres de usuario únicos.
- Conservar contraseñas en forma de hash, no como contraseñas en texto plano.
- Registrar el rol y el estado de cada usuario.
- Registrar acciones de acceso, fecha y hora, y objetos consultados.
- Diferenciar las operaciones permitidas para cada tipo de usuario.

### 5.6. Reportes Corporativos

**Responsabilidad:** ofrecer consultas de solo lectura que integren información de diferentes módulos y sedes.

No requiere tablas de negocio adicionales. Su contenido se compone de vistas y consultas consolidadas.

Requisitos principales:

- Integrar información procedente de los módulos operacionales.
- Mostrar resultados por sede y resultados corporativos.
- Identificar la procedencia de los datos.
- Evitar la duplicación de cantidades e importes por relaciones uno a muchos.
- Facilitar el análisis de inventarios, ventas, pedidos pendientes, compras y transferencias.
- Mantener el carácter de solo lectura de los reportes corporativos.

---

## 6. Requisitos funcionales

### RF-01. Administración de sedes

El sistema debe registrar e identificar de manera única cada sede, incluyendo nombre, ciudad, dirección, tipo y estado.

Cada sede debe estar relacionada con sus almacenes, empleados y operaciones comerciales.

### RF-02. Administración de almacenes

El sistema debe permitir registrar los almacenes y asociarlos con sus respectivas sedes.

Debe conservar el nombre, el tipo y el estado de cada almacén.

### RF-03. Administración del catálogo

El sistema debe permitir registrar productos y categorías, mantener un SKU único por producto y conservar su categoría, unidad de medida, precio de lista y estado.

### RF-04. Gestión de proveedores

El sistema debe registrar la identificación, razón social, ciudad, correo, teléfono y estado de los proveedores.

Debe permitir representar qué proveedores suministran cada producto, incluyendo el costo de referencia y el plazo de entrega en días.

### RF-05. Gestión de clientes

El sistema debe almacenar la información de identificación y contacto de los clientes, incluyendo tipo y número de documento, nombre completo, correo, teléfono y estado.

### RF-06. Gestión de compras

El sistema debe registrar órdenes de compra relacionadas con un proveedor, un almacén de destino y un empleado.

Cada orden debe incluir sus fechas y estado, además de uno o varios detalles con productos, cantidades solicitadas y costos unitarios.

### RF-07. Gestión de recepciones

El sistema debe permitir registrar recepciones totales y parciales de las órdenes de compra.

Debe almacenar las cantidades recibidas por producto y permitir compararlas con las cantidades originalmente solicitadas.

### RF-08. Consulta de inventario

El sistema debe mantener las existencias registradas y el stock mínimo por producto, sede y almacén.

Debe permitir consultar la existencia actual, identificar faltantes y estimar la valorización del inventario.

### RF-09. Gestión de transferencias

El sistema debe registrar los traslados de productos entre almacenes, identificando origen, destino, fechas, estado y cantidades enviadas y recibidas.

Debe permitir identificar transferencias en tránsito y diferencias entre cantidades enviadas y recibidas.

### RF-10. Gestión de ventas

El sistema debe registrar pedidos vinculados a una sede, un almacén, un cliente y un empleado.

Cada pedido debe admitir varios productos, con sus cantidades y precios unitarios históricos.

### RF-11. Gestión de pagos

El sistema debe permitir registrar múltiples pagos por pedido, incluyendo fecha, valor, medio de pago y estado.

Debe permitir identificar los pagos confirmados y calcular los saldos pendientes.

### RF-12. Gestión de devoluciones

El sistema debe registrar devoluciones relacionadas con pedidos existentes, incluyendo fecha de solicitud, motivo, estado, productos, cantidades y condición de los productos devueltos.

### RF-13. Gestión de usuarios y accesos

El sistema debe distinguir los roles administrativos, gerenciales, operacionales y de auditoría.

Cada rol debe disponer únicamente de los privilegios autorizados para sus funciones.

### RF-14. Consultas locales

El sistema debe permitir consultar por separado los datos operacionales de cada sede o fragmento.

### RF-15. Consultas consolidadas

El sistema debe permitir integrar datos de varias sedes y módulos para generar informes corporativos.

### RF-16. Vistas SQL

El sistema debe ofrecer al menos diez vistas para consultas recurrentes, análisis operacionales y reportes consolidados.

### RF-17. Consultas analíticas

El sistema debe permitir consultas que utilicen agrupaciones, subconsultas, expresiones de tabla comunes (CTE), operaciones de conjuntos y funciones de ventana.

### RF-18. Verificación de integridad

El sistema debe rechazar las operaciones que incumplan las restricciones definidas para las entidades y relaciones.

### RF-19. Datos de prueba

El sistema debe contar con datos suficientes y variados para comprobar todas las consultas obligatorias y los escenarios operacionales.

### RF-20. Documentación de la arquitectura

El proyecto debe documentar los responsables de los datos, las dependencias entre módulos, los límites de cada componente y la procedencia de la información consolidada.

---

## 7. Reglas de negocio

Las siguientes reglas sintetizan las condiciones explícitas del proyecto. Los aspectos que no están definidos completamente deben establecerse como supuestos documentados, sin presentarlos como reglas originales del enunciado.

### 7.1. Organización y catálogo

1. Cada sede debe identificarse de manera única.
2. Cada almacén debe estar asociado a una sede.
3. Cada producto debe tener un SKU único.
4. Cada producto debe estar asociado a una categoría.
5. Un producto puede relacionarse con uno o varios proveedores.
6. Las entidades que incluyen un estado deben permitir distinguir su condición operativa.
7. Los productos inactivos deben poder diferenciarse de los productos activos en las consultas.

### 7.2. Compras y recepciones

8. Cada orden de compra debe estar asociada a un proveedor.
9. Cada orden de compra debe identificar el almacén de destino y el empleado responsable.
10. Cada orden debe contener sus productos, cantidades solicitadas y costos unitarios.
11. Las recepciones deben quedar asociadas con la orden correspondiente.
12. Una orden puede recibirse completamente o mediante varias recepciones parciales.
13. Las cantidades solicitadas y recibidas deben poder compararse por producto.
14. Los datos deben permitir evaluar los plazos de entrega y los retrasos de los proveedores.

### 7.3. Inventarios y transferencias

15. Las existencias deben registrarse por producto y ubicación.
16. Cada registro de inventario debe incluir la existencia actual y el stock mínimo.
17. Debe ser posible identificar existencias iguales a cero o inferiores al stock mínimo.
18. Las transferencias deben identificar almacenes de origen y destino.
19. Cada detalle de transferencia debe conservar las cantidades enviadas y recibidas.
20. Debe ser posible identificar transferencias despachadas que todavía no han sido recibidas.
21. Deben poder detectarse diferencias entre las cantidades enviadas y recibidas.
22. Los datos deben permitir analizar posibles redistribuciones de productos entre sedes.

### 7.4. Ventas, pagos y devoluciones

23. Cada pedido debe estar asociado a una sede, un cliente y un empleado.
24. Cada pedido puede incluir varios productos.
25. El precio unitario registrado en el detalle de venta debe conservarse para los informes históricos.
26. El costo unitario registrado en el detalle de compra debe conservarse para los informes históricos.
27. Un pedido puede tener varios pagos.
28. Los pagos deben distinguirse por su estado.
29. Los saldos pendientes deben calcularse a partir del valor del pedido y los pagos que correspondan según las reglas de negocio documentadas.
30. Las devoluciones deben estar asociadas a pedidos existentes.
31. Las cantidades vendidas y devueltas deben poder compararse por producto y periodo.

### 7.5. Integridad, permisos y distribución

32. Las claves primarias deben identificar de manera única los registros.
33. Las claves foráneas deben garantizar las relaciones locales que corresponda asegurar en la base de datos.
34. Las restricciones UNIQUE deben impedir duplicidades en los atributos que deban ser únicos.
35. Las restricciones NOT NULL deben proteger los atributos obligatorios.
36. Las restricciones CHECK deben validar cantidades, valores y estados según las reglas definidas.
37. Cada módulo debe tener un responsable lógico de sus datos.
38. Un rol de un módulo no debe disponer de permisos de modificación sobre las tablas administradas por otro módulo.
39. Los reportes corporativos deben ser de solo lectura.
40. Los fragmentos horizontales deben evitar la duplicación de registros entre sedes.
41. Las consultas consolidadas deben integrar los fragmentos y evitar duplicaciones en los resultados.
42. Los supuestos adicionales sobre estados, transiciones, pagos, devoluciones y cantidades deben documentarse explícitamente.

---

## 8. Requisitos de integridad y normalización

### 8.1. Claves primarias

Cada entidad debe contar con una clave primaria adecuada.

En los detalles de operaciones y en los registros de inventario deben definirse claves que permitan identificar los registros de manera inequívoca. Cuando se utilicen claves compuestas, estas deben documentarse y ser coherentes con la distribución de los datos.

### 8.2. Claves foráneas

Las claves foráneas deben utilizarse cuando corresponda para garantizar la integridad referencial.

Deben identificarse especialmente las relaciones entre:

- Sedes y almacenes.
- Categorías y productos.
- Productos y proveedores.
- Proveedores y órdenes de compra.
- Órdenes de compra y sus detalles.
- Órdenes de compra y recepciones.
- Productos y registros de inventario.
- Transferencias y sus detalles.
- Pedidos y sus detalles.
- Pedidos y pagos.
- Pedidos y devoluciones.
- Empleados y usuarios.
- Usuarios y registros de auditoría.

El documento permite que las relaciones entre módulos con datos separados se representen mediante identificadores compartidos, sin exigir que todas se materialicen como claves foráneas entre bases independientes. En el esquema académico debe quedar documentado cuáles relaciones se garantizan en PostgreSQL y cuáles se representan lógicamente.

### 8.3. Restricciones UNIQUE

Deben utilizarse para evitar duplicidades donde sean necesarias.

Como mínimo, el SKU de los productos debe ser único. También deben definirse las restricciones de unicidad aplicables a identificadores comerciales, nombres de usuario y demás atributos que lo requieran.

### 8.4. Restricciones NOT NULL

Los atributos obligatorios no deben admitir valores nulos.

Su definición debe corresponder a las reglas de negocio de cada entidad. Por ejemplo, los registros operacionales deben conservar los identificadores y valores indispensables para identificar y comprender la operación.

### 8.5. Restricciones CHECK

Deben emplearse para validar cantidades, valores y estados.

Entre los casos que deben contemplarse se encuentran:

- Impedir cantidades negativas cuando las reglas de negocio no las permitan.
- Validar valores monetarios conforme a las reglas establecidas.
- Restringir los estados a los valores admitidos.
- Validar otros atributos que requieran condiciones específicas.

Las condiciones exactas deben quedar definidas y documentadas en el modelo.

### 8.6. Normalización hasta tercera forma normal

El modelo relacional debe normalizarse hasta 3FN.

El análisis debe demostrar que:

- Cada tabla representa una entidad o relación con significado definido.
- Los atributos almacenan valores atómicos.
- Las dependencias funcionales están correctamente identificadas.
- Los atributos que no son clave dependen de la clave correspondiente.
- No existen dependencias transitivas indebidas entre atributos no clave.
- Las relaciones de muchos a muchos están representadas adecuadamente.
- Los datos históricos de los detalles de compra y venta no dependen exclusivamente de los valores actuales del catálogo.

La documentación debe incluir el modelo relacional, el proceso de normalización y el diccionario de datos.

---

## 9. Distribución de los datos y fragmentación horizontal

### 9.1. Requisito de distribución

El proyecto exige aplicar una estrategia de fragmentación horizontal por sede a dos conjuntos de datos operacionales.

El enunciado propone inventarios y pedidos de venta como ejemplos. La distribución debe poder demostrarse mediante tablas físicas separadas por sede o mediante una estrategia de particionamiento equivalente.

No es suficiente realizar una consulta que filtre por sede mediante `WHERE` si los datos no están físicamente fragmentados o distribuidos mediante una estrategia equivalente verificable.

### 9.2. Condiciones de fragmentación

La documentación debe especificar:

- Qué entidades o conjuntos operacionales están fragmentados.
- Qué sedes están cubiertas.
- Cuál es la condición que determina la pertenencia de un registro a cada fragmento.
- Cómo se evita que un registro aparezca duplicado en fragmentos diferentes.
- Qué claves identifican los registros.
- Cómo se consultan los fragmentos de manera individual.
- Cómo se integran los fragmentos para las consultas corporativas.
- Qué vistas unificadas exponen la información consolidada.

### 9.3. Cobertura de sedes

La solución debe incluir como mínimo cuatro sedes, incluida una sede de distribución.

Los fragmentos y las consultas de integración deben permitir demostrar la cobertura de las cuatro sedes.

La sede de distribución debe poder identificarse y participar en las operaciones de abastecimiento o traslado de mercancía que correspondan a las reglas documentadas.

### 9.4. Consultas locales y corporativas

Deben existir dos niveles de consulta:

**Consultas locales:**

- Inventario de una sede.
- Pedidos registrados en una sede.
- Existencias y alertas de reabastecimiento de una sede.
- Operaciones de compra o transferencia que correspondan a una sede.

**Consultas corporativas:**

- Inventario de todas las sedes.
- Ventas consolidadas.
- Comparación de productos entre sedes.
- Clientes con compras multisede.
- Reportes generales de compras, pedidos, transferencias y devoluciones.

### 9.5. Integración de datos

Los reportes consolidados deben integrar los fragmentos mediante consultas y vistas SQL de solo lectura.

El esquema de reportes debe identificar la procedencia de los datos y reunir la información necesaria para las consultas institucionales.

No se exige implementar sincronización en tiempo real.

### 9.6. Alcance de la arquitectura

Una única instancia de PostgreSQL con esquemas separados constituye una simulación académica de la arquitectura de datos de microservicios.

Esto no equivale a desplegar microservicios independientes. La documentación debe explicar esta diferencia y representar conceptualmente las interacciones entre los módulos.

---

## 10. Requisitos de seguridad, usuarios y permisos

### 10.1. Roles obligatorios

#### Administrador

- Crear esquemas y usuarios.
- Administrar permisos.
- Consultar toda la información.
- Administrar las estructuras de la base de datos según sus privilegios.

#### Gerencia

- Consultar reportes consolidados.
- Consultar resultados de las sedes.
- No modificar información operacional.

#### Responsable de inventario

- Consultar y actualizar los datos de inventario y transferencias.
- Limitar sus operaciones a las sedes autorizadas.

#### Responsable de compras

- Gestionar órdenes de compra y recepciones.
- Operar únicamente dentro de las autorizaciones establecidas.

#### Vendedor

- Registrar y consultar pedidos y pagos de su sede.
- No gestionar las tablas pertenecientes a otros módulos.

#### Auditor

- Consultar la información y los reportes autorizados.
- No modificar los datos operacionales.

### 10.2. Requisitos de implementación de permisos

Deben entregarse scripts que incluyan:

- `CREATE ROLE`
- `GRANT`
- `REVOKE`

También debe presentarse una matriz que indique los permisos de cada rol por esquema y operación.

Las operaciones que deben considerarse son:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

Los privilegios concretos deben corresponder a las responsabilidades descritas para cada rol.

### 10.3. Pruebas de seguridad

Deben demostrarse, como mínimo, dos accesos permitidos y dos accesos denegados.

Las pruebas deben mostrar que los privilegios efectivos corresponden con la matriz de permisos y que un usuario no puede modificar datos para los que carece de autorización.

No se exige implementar autenticación web ni políticas RLS.

---

## 11. Consultas SQL obligatorias

El proyecto exige desarrollar y ejecutar veinte consultas. Cada una debe incluir:

1. La instrucción SQL.
2. El resultado obtenido.
3. Una breve interpretación del resultado.

Las consultas consolidadas deben integrar información de varias sedes cuando corresponda.

### Consulta 1. Inventario por producto y sede

Mostrar:

- Producto.
- Categoría.
- Sede.
- Almacén.
- Existencia actual.
- Stock mínimo.
- Valorización estimada del inventario.

El cálculo de valorización debe basarse en un criterio de precio claramente identificado y documentado.

### Consulta 2. Alertas de reabastecimiento

Identificar productos cuya existencia sea igual a cero o inferior al stock mínimo en un almacén.

Los resultados deben ordenarse por nivel de faltante para facilitar la identificación de los casos más críticos.

### Consulta 3. Productos ausentes por sede

Encontrar los productos activos que no cuentan con un registro de inventario en una o más sedes.

La ausencia de un registro debe distinguirse de la existencia de un registro cuyo valor de existencias sea cero.

### Consulta 4. Ranking de productos por sede

Mostrar los cinco productos más vendidos de cada sede y periodo.

Debe utilizarse `DENSE_RANK()` o `ROW_NUMBER()` para establecer el ranking correspondiente.

La consulta debe considerar las ventas del periodo seleccionado y conservar la separación por sede.

### Consulta 5. Ventas mensuales y variación

Calcular los valores vendidos por sede y mes.

Debe utilizarse `LAG()` para comparar cada mes con el mes anterior y estimar la variación.

El resultado debe permitir analizar la evolución mensual de las ventas.

### Consulta 6. Clientes con compras multisede

Identificar los clientes que hayan realizado compras en al menos dos sedes.

Debe mostrarse el conjunto de sedes visitadas y el total comprado según el criterio de ventas establecido.

### Consulta 7. Pedidos con pagos pendientes

Mostrar:

- Pedido.
- Cliente.
- Valor total.
- Pagos confirmados acumulados.
- Saldo por pagar.

Los pagos no confirmados no deben contabilizarse como pagos confirmados.

La consulta debe aplicar un criterio documentado para determinar el saldo pendiente.

### Consulta 8. Pedidos con diversidad de productos

Consultar los pedidos que contengan tres o más productos distintos.

Debe calcularse la suma de las unidades y el importe registrado de los productos incluidos en cada pedido.

La diversidad debe calcularse con base en productos distintos, no únicamente en la cantidad total de unidades.

### Consulta 9. Pedidos antiguos sin completar

Identificar pedidos pendientes cuya antigüedad supere un umbral definido.

El umbral y la fecha de referencia deben quedar documentados para que el resultado sea reproducible.

### Consulta 10. Demanda frente al inventario

Detectar detalles de pedidos pendientes cuya cantidad solicitada supere la existencia registrada del producto en el almacén asociado.

El resultado debe permitir identificar posibles faltantes para atender la demanda pendiente.

### Consulta 11. Cumplimiento de proveedores

Calcular por proveedor:

- Total de órdenes.
- Órdenes recibidas dentro del plazo.
- Promedio de días de retraso.

La medición debe basarse en las fechas de orden, fechas estimadas y recepciones disponibles, con un criterio explícito para los casos de recepción parcial.

### Consulta 12. Compras pendientes de recibir

Comparar las cantidades solicitadas con las cantidades recibidas por orden y producto.

Deben incluirse las órdenes con recepción parcial y distinguirse las cantidades pendientes de recepción.

### Consulta 13. Transferencias en tránsito

Listar las transferencias despachadas que todavía no han sido recibidas.

Debe mostrarse:

- Identificador de transferencia.
- Almacén de origen.
- Almacén de destino.
- Productos.
- Cantidades.
- Días transcurridos desde el despacho.

### Consulta 14. Diferencias entre enviado y recibido

Encontrar transferencias en las que las cantidades recibidas sean diferentes de las enviadas.

Las diferencias deben identificarse por producto y transferencia.

### Consulta 15. Redistribución de productos

Buscar pares de sedes en los que una tenga excedente sobre el stock mínimo y otra tenga faltante para el mismo producto.

El resultado debe mostrar el producto, las sedes involucradas y las cantidades relevantes para analizar una posible redistribución.

### Consulta 16. Productos de baja rotación

Encontrar productos con existencia positiva que no hayan registrado ventas confirmadas durante los últimos noventa días.

El análisis debe considerar la existencia de inventario y el historial de ventas dentro del periodo definido.

### Consulta 17. Devoluciones por producto y categoría

Calcular, para un periodo:

- Cantidades vendidas.
- Cantidades devueltas.
- Porcentaje de devolución.

El resultado debe permitir analizar los productos y categorías con mayores niveles de devolución.

La fórmula y el tratamiento de productos sin ventas durante el periodo deben documentarse.

### Consulta 18. Comparación de surtido entre sedes

Utilizar `EXCEPT` o `INTERSECT` para identificar:

- Productos presentes en una sede y ausentes en otra.
- Productos comunes entre dos sedes.

La comparación debe basarse en un criterio consistente de presencia de productos.

### Consulta 19. Clasificación de vendedores

Mostrar por sede el total vendido y el puesto de cada empleado.

Debe utilizarse `RANK()` o `ROW_NUMBER()` para clasificar a los empleados según el criterio de ventas establecido.

### Consulta 20. Consolidado corporativo

Generar un informe por sede que incluya:

- Productos activos.
- Unidades en inventario.
- Ventas.
- Pedidos pendientes.
- Compras.
- Transferencias.

Deben utilizarse CTE o subconsultas agregadas para evitar conteos duplicados por relaciones uno a muchos.

El resultado debe representar correctamente los datos de todas las sedes y permitir una lectura general de la situación comercial de la empresa.

### 11.1. Cobertura de características SQL

En el conjunto de consultas deben observarse, como mínimo:

- `JOIN`.
- `LEFT JOIN`.
- `NOT EXISTS`.
- Subconsultas correlacionadas.
- `GROUP BY`.
- `HAVING`.
- Al menos cuatro CTE.
- Al menos tres funciones de ventana.
- Al menos dos operaciones de conjuntos entre `UNION`, `INTERSECT` o `EXCEPT`.

La cobertura de estas características debe poder identificarse en las consultas entregadas.

---

## 12. Vistas SQL obligatorias

Deben crearse al menos diez vistas SQL. Las vistas deben tener nombres claros, ejecutarse sin errores y producir datos coherentes con las tablas de origen.

### 12.1. `vista_inventario_por_sede`

Debe exponer la información del inventario organizada por producto, categoría, sede y almacén, incluyendo las existencias y el stock mínimo.

### 12.2. `vista_alertas_reabastecimiento`

Debe identificar los productos cuya existencia sea igual a cero o inferior al stock mínimo.

### 12.3. `vista_productos_sin_inventario`

Debe identificar los productos activos que no cuentan con registro de inventario en las sedes correspondientes.

### 12.4. `vista_ventas_mensuales_por_sede`

Debe consolidar las ventas por sede y mes para facilitar su análisis temporal.

### 12.5. `vista_pedidos_pendientes`

Debe presentar los pedidos que se encuentren en estados pendientes, según los estados definidos y documentados.

### 12.6. `vista_saldos_pendientes`

Debe presentar los valores de los pedidos, los pagos confirmados acumulados y los saldos pendientes.

### 12.7. `vista_compras_pendientes`

Debe mostrar las cantidades solicitadas, recibidas y pendientes de recibir por orden y producto.

### 12.8. `vista_transferencias_en_transito`

Debe mostrar las transferencias despachadas que aún no han sido recibidas, junto con sus almacenes, productos y tiempos transcurridos.

### 12.9. `vista_devoluciones_por_producto`

Debe facilitar el análisis de las cantidades devueltas por producto y su relación con las ventas correspondientes.

### 12.10. `vista_reporte_corporativo`

Debe integrar información relevante de las sedes, incluyendo productos activos, inventarios, ventas, pedidos pendientes, compras y transferencias.

### 12.11. Condiciones generales de las vistas

Las vistas deben:

- Contar con nombres descriptivos.
- Ser reproducibles mediante los scripts entregados.
- Devolver información coherente con las tablas de origen.
- Identificar si sus datos son locales o consolidados.
- Respetar la separación de responsabilidades entre módulos.
- Evitar duplicaciones causadas por relaciones uno a muchos.
- Ser consultables con los permisos correspondientes.
- Identificar los fragmentos o módulos de los que procede la información corporativa.

No se exige implementar mecanismos de sincronización en tiempo real.

---

## 13. Datos de prueba y escenarios necesarios

### 13.1. Volumen mínimo

Los datos de prueba deben cubrir, como mínimo:

| Entidad o conjunto | Cantidad mínima |
|---|---:|
| Sedes | 4 |
| Almacenes | 4 |
| Productos | 80 |
| Categorías | 5 |
| Proveedores | 10 |
| Clientes | 100 |
| Empleados | 20 |
| Pedidos de venta | 300 |
| Órdenes de compra | 60 |
| Transferencias | 25 |
| Devoluciones | 20 |
| Periodo histórico | 4 meses |

Las órdenes de compra deben contar con los registros de recepción correspondientes y los pedidos, transferencias y devoluciones deben tener sus respectivos detalles.

### 13.2. Variedad de estados

Los datos deben incluir operaciones en distintos estados para que las consultas no se limiten a registros completos o exitosos.

Deben contemplarse, según las entidades correspondientes:

- Productos activos e inactivos.
- Pedidos pendientes y completados.
- Pagos confirmados y situaciones con pagos parciales.
- Órdenes de compra completamente recibidas y parcialmente recibidas.
- Transferencias recibidas y transferencias en tránsito.
- Devoluciones en distintos estados.

Los valores concretos admitidos para cada estado deben definirse de forma coherente y documentarse.

### 13.3. Escenarios de negocio obligatorios

Los datos de prueba deben incluir:

1. Sedes con existencias diferentes para un mismo producto.
2. Productos que no registren ventas recientes.
3. Clientes que hayan comprado en varias sedes.
4. Proveedores con retrasos en las entregas.
5. Pedidos con pagos parciales.
6. Compras incompletas.
7. Transferencias que permanezcan en tránsito.
8. Productos con existencias inferiores al stock mínimo.
9. Diferencias entre cantidades enviadas y recibidas en transferencias.
10. Productos con devoluciones registradas.
11. Productos activos sin registros de inventario en determinadas sedes.
12. Empleados con distintos volúmenes de ventas.

Los registros pueden ser sintéticos, siempre que sean coherentes entre sí y permitan comprobar los resultados de las consultas.

### 13.4. Reproducibilidad

Los scripts de carga o generación de datos deben entregarse de manera que permitan reproducir los escenarios.

Los datos deben mantener coherencia entre las claves, las relaciones, las cantidades, las fechas y los estados.

---

## 14. Pruebas mínimas de verificación

El proyecto debe incluir una matriz de pruebas que registre:

- Identificador de la prueba.
- Objetivo.
- Instrucción SQL ejecutada.
- Resultado esperado.
- Resultado obtenido.
- Evidencia correspondiente.
- Estado de cumplimiento.

### Prueba 1. Registro válido de producto

Crear un producto que cumpla las restricciones y consultar su registro para verificar que la operación se realizó correctamente.

### Prueba 2. SKU duplicado

Intentar registrar un producto con un SKU existente y comprobar que la restricción UNIQUE rechaza la operación.

### Prueba 3. Cantidad negativa

Intentar registrar una cantidad negativa en un campo protegido por CHECK y verificar que se rechaza.

### Prueba 4. Clave foránea inexistente

Intentar registrar una referencia a una clave inexistente en una relación con FK local y comprobar que PostgreSQL rechaza la operación.

### Prueba 5. Fragmentos de sedes diferentes

Consultar por separado los fragmentos de dos sedes y demostrar que contienen registros diferenciados.

### Prueba 6. Consolidación del inventario

Ejecutar la vista consolidada de inventarios y verificar que integra los fragmentos correspondientes a las cuatro sedes.

### Prueba 7. Consulta avanzada con CTE

Ejecutar una consulta que utilice una CTE y comprobar que produce el resultado esperado.

### Prueba 8. Función de ventana

Ejecutar una consulta con una función de ventana y verificar la clasificación o comparación generada.

### Prueba 9. Operación de conjuntos

Comparar dos sedes mediante `EXCEPT` o `INTERSECT` y explicar qué representan los registros obtenidos.

### Prueba 10. Permisos

Comprobar accesos permitidos y denegados para al menos dos roles.

### Prueba 11. Reporte corporativo

Ejecutar el reporte corporativo y verificar que las relaciones uno a muchos no provocan duplicaciones en ventas, unidades, compras o transferencias.

### 14.1. Criterios de aceptación de las pruebas

Una prueba se considera satisfactoria cuando:

- La operación ejecutada corresponde con el objetivo de la prueba.
- El resultado obtenido coincide con el esperado.
- Las restricciones rechazan las operaciones inválidas.
- Las consultas recuperan los registros que corresponden al escenario.
- Los permisos permiten o deniegan las operaciones según lo establecido.
- La evidencia permite verificar el resultado sin depender únicamente de una afirmación escrita.

---

## 15. Requisitos no funcionales

Los siguientes aspectos corresponden a cualidades y condiciones de la solución que se desprenden del alcance del proyecto.

### 15.1. Integridad de los datos

La información debe mantener coherencia entre las entidades, las operaciones y sus detalles. Las restricciones deben impedir los registros inválidos contemplados en las reglas de negocio.

### 15.2. Consistencia de los reportes

Los informes deben presentar resultados coherentes con los datos de origen. Las agregaciones no deben duplicar cantidades ni valores monetarios.

### 15.3. Separación de responsabilidades

Cada módulo debe tener límites y un responsable lógico de sus datos. La separación debe reflejarse en los esquemas, los permisos y la documentación.

### 15.4. Trazabilidad

Los registros deben conservar la información histórica necesaria para analizar las operaciones comerciales. La auditoría de accesos debe registrar los eventos contemplados en el modelo.

### 15.5. Seguridad

Los privilegios deben limitarse a las funciones de cada rol. Los usuarios no deben modificar tablas de módulos para los que carezcan de autorización.

### 15.6. Reproducibilidad

La estructura, los datos de prueba, las vistas, las consultas, los roles y los permisos deben poder recrearse mediante los scripts entregados.

### 15.7. Mantenibilidad documental

Los esquemas, las entidades, los fragmentos, las vistas y las consultas deben contar con nombres claros y documentación suficiente para comprender su función.

### 15.8. Verificabilidad

Los requisitos deben poder comprobarse mediante consultas, resultados, pruebas y evidencias reproducibles.

El enunciado no establece objetivos numéricos de rendimiento, disponibilidad, escalabilidad, concurrencia o recuperación ante desastres. Por tanto, estos no deben considerarse criterios obligatorios de aceptación salvo que se definan expresamente como extensiones.

---

## 16. Arquitectura y documentación requerida

### 16.1. Diagrama de arquitectura

Debe representar los seis módulos:

1. Catálogo y Terceros.
2. Compras y Abastecimiento.
3. Inventarios y Transferencias.
4. Ventas y Pagos.
5. Identidad y Accesos.
6. Reportes Corporativos.

El diagrama debe identificar:

- Los límites de cada módulo.
- Las entidades principales administradas.
- Los datos que pertenecen a cada módulo.
- Las dependencias de información.
- Las consultas locales.
- Los vínculos conceptuales entre módulos.
- La procedencia de los reportes corporativos.
- La separación entre los datos operacionales y las consultas de integración.

La comunicación mediante API u otros mecanismos solo debe representarse conceptualmente.

### 16.2. Esquemas de datos

Cada microservicio de datos debe tener un esquema PostgreSQL propio.

Los nombres de referencia propuestos por el documento son:

- `catalogo`
- `compras`
- `inventarios`
- `ventas`
- `identidad`
- `reportes`

El esquema `reportes` debe contener únicamente vistas y consultas de integración, sin tablas adicionales de negocio.

La organización definitiva debe conservar la separación por responsabilidades y permitir identificar claramente la propiedad lógica de cada entidad.

### 16.3. Modelo relacional y diccionario de datos

El modelo relacional debe incluir:

- Tablas.
- Atributos.
- Tipos de datos.
- Claves primarias.
- Claves foráneas aplicables.
- Restricciones.
- Cardinalidades.
- Dependencias entre entidades.
- Pertenencia de cada tabla a su módulo.
- Normalización hasta 3FN.

El diccionario de datos debe explicar el propósito de cada entidad y atributo, incluyendo sus restricciones y relaciones relevantes.

---

## 17. Entregables finales

La entrega debe contener una carpeta organizada con los siguientes elementos:

1. **Documento de análisis:** descripción del problema, alcance, supuestos y reglas de negocio.
2. **Diagrama de arquitectura:** módulos, responsables de los datos e interacciones conceptuales.
3. **Modelo conceptual Entidad–Relación:** entidades, relaciones y cardinalidades.
4. **Modelo relacional:** transformación del modelo conceptual y normalización hasta tercera forma normal.
5. **Diccionario de datos:** descripción de las tablas, atributos, tipos, claves y restricciones.
6. **Documentación de la distribución:** esquemas, módulos, fragmentos por sede y vistas de integración.
7. **Scripts de estructura:** creación de esquemas, tablas, claves y restricciones.
8. **Scripts de datos de prueba:** inserción o generación reproducible de los registros.
9. **Scripts de seguridad:** creación de usuarios y roles, concesión y revocación de permisos.
10. **Scripts de fragmentación:** definición de los fragmentos horizontales y las vistas unificadas.
11. **Scripts de vistas:** implementación de las diez o más vistas SQL.
12. **Scripts de consultas:** las veinte consultas avanzadas, identificadas y numeradas.
13. **Resultados y evidencias:** salidas de las consultas y resultados de las pruebas de restricciones y permisos.
14. **Análisis de resultados:** interpretación de las consultas y justificación de las decisiones de distribución.
15. **Manual de instalación y ejecución:** instrucciones para preparar y ejecutar la solución de datos mediante PostgreSQL, pgAdmin o psql.
16. **Conclusiones y extensiones:** cumplimiento de los requisitos, limitaciones identificadas y posibles ampliaciones futuras.

---

## 18. Criterios generales de aceptación

La solución se considerará completa cuando cumpla los siguientes criterios:

- [ ] El problema y el alcance están documentados.
- [ ] El modelo Entidad–Relación representa las entidades y cardinalidades necesarias.
- [ ] El modelo relacional está definido y normalizado hasta 3FN.
- [ ] Las entidades están asignadas a sus respectivos módulos de datos.
- [ ] Se incluyen al menos cuatro sedes y cuatro almacenes.
- [ ] El catálogo, las compras, los inventarios, las transferencias, las ventas, los pagos y las devoluciones están representados.
- [ ] Las claves y restricciones de integridad están implementadas.
- [ ] Se conserva el historial de precios unitarios de compras y ventas.
- [ ] Se definen los seis roles funcionales y sus privilegios.
- [ ] Se documentan los esquemas de los módulos.
- [ ] Se demuestra la fragmentación horizontal de dos conjuntos operacionales por sede.
- [ ] Los fragmentos pueden consultarse individualmente.
- [ ] Las vistas consolidadas integran los fragmentos correspondientes.
- [ ] Existen al menos diez vistas SQL funcionales.
- [ ] Se ejecutan las veinte consultas obligatorias.
- [ ] Las consultas cubren los recursos SQL avanzados exigidos.
- [ ] Los datos de prueba cumplen los mínimos de volumen y periodo.
- [ ] Los datos incluyen los escenarios necesarios para producir resultados variados.
- [ ] Se ejecutan las pruebas de integridad, fragmentación, consultas y permisos.
- [ ] El reporte corporativo no presenta duplicaciones por las relaciones entre entidades.
- [ ] Se entregan los resultados, las evidencias, el manual y las conclusiones.

---

## 19. Aspectos que deben definirse como supuestos de negocio

El enunciado establece las funcionalidades y las consultas requeridas, pero no determina todos los detalles operacionales. Los siguientes puntos deben quedar definidos en la documentación para que el modelo y los resultados sean coherentes.

### 19.1. Estados de las operaciones

Deben establecerse los valores admitidos para productos, pedidos, órdenes de compra, recepciones, pagos, transferencias, devoluciones, sedes y usuarios, según corresponda.

También debe documentarse cuáles estados se consideran pendientes, confirmados, completados o inactivos para cada consulta.

### 19.2. Cálculo del total de los pedidos

Debe establecerse cómo se relaciona el total registrado del pedido con los importes calculados a partir de sus detalles.

Si existen diferencias entre el total registrado y la suma de los detalles, debe definirse qué valor se utiliza en cada informe.

### 19.3. Cálculo de saldos pendientes

Debe definirse qué estados de pago se incluyen en el acumulado y cómo se determina el saldo por pagar.

También debe documentarse el tratamiento de pedidos con pagos parciales, pagos no confirmados o importes que excedan el saldo calculado.

### 19.4. Inventario y movimientos

El proyecto exige registrar existencias y transferencias, pero no define un mecanismo completo de actualización automática de inventarios.

Debe quedar explícito qué representa la existencia almacenada, cómo se interpreta respecto a las transferencias y qué limitaciones tiene el modelo en relación con la conciliación de movimientos.

No debe suponerse que registrar una compra, recepción, venta o transferencia modifica automáticamente las existencias si ese comportamiento no se encuentra implementado y documentado.

### 19.5. Recepciones parciales

Debe definirse cómo se determina la cantidad recibida acumulada de una orden y cómo se identifican las cantidades pendientes.

En el cálculo del cumplimiento de proveedores también debe establecerse qué fecha se utiliza cuando existen varias recepciones.

### 19.6. Valorización del inventario

Debe definirse el precio de referencia empleado para calcular la valorización estimada del inventario.

El precio de lista del producto, el costo de referencia del proveedor y los costos históricos de compra no son necesariamente equivalentes. La interpretación utilizada debe ser consistente y estar documentada.

### 19.7. Devoluciones

Debe definirse cómo se relacionan los productos devueltos con las cantidades vendidas, cómo se calculan los porcentajes de devolución y qué estados se consideran para el análisis.

También debe aclararse si una devolución registrada implica o no una modificación del inventario, dado que el enunciado no exige automatizar esa operación.

### 19.8. Presencia de productos en una sede

Debe definirse si un producto se considera presente cuando tiene un registro de inventario, cuando posee existencias positivas o cuando está disponible para la venta.

Esta definición afecta las consultas de productos ausentes y la comparación de surtido entre sedes.

### 19.9. Autorizaciones por sede

Deben identificarse las sedes autorizadas para cada responsable de inventario y los alcances de los demás roles.

La matriz de permisos debe reflejar las autorizaciones establecidas. El enunciado exige privilegios diferenciados, pero no determina todos los detalles de asignación para cada usuario.

### 19.10. Límites de las relaciones entre módulos

Debe documentarse qué relaciones se garantizan mediante claves foráneas locales y cuáles se representan mediante identificadores compartidos.

Esta distinción es necesaria para comprender las garantías de integridad de la solución y las limitaciones de una arquitectura académica basada en una instancia de PostgreSQL.

---

## 20. Resultado esperado del proyecto

Al finalizar, debe existir una solución de datos funcional, documentada y verificable que represente las operaciones de una empresa comercial con múltiples sedes y un centro de distribución.

La solución debe permitir administrar las entidades comerciales, registrar y consultar las operaciones de compra y venta, analizar las existencias, identificar faltantes, controlar pagos y devoluciones, seguir transferencias y comparar el desempeño de las sedes.

La información debe estar organizada en módulos con responsabilidades delimitadas y contar con una estrategia demostrable de fragmentación horizontal para dos conjuntos operacionales. Al mismo tiempo, debe ser posible integrar los datos mediante vistas y consultas SQL para generar reportes corporativos de solo lectura.

El proyecto debe demostrar que el modelo relacional conserva la integridad de la información, que los roles cuentan con privilegios diferenciados, que las consultas avanzadas responden a los escenarios planteados y que los resultados pueden comprobarse mediante datos de prueba y evidencias reproducibles.

El resultado final no consiste únicamente en un conjunto de tablas. Debe incluir el análisis del problema, los modelos de datos, la arquitectura documentada, las restricciones, la distribución de los registros, las vistas, las consultas, las pruebas y la interpretación de los resultados.

La solución debe cumplir el alcance académico definido en el enunciado, sin requerir el despliegue de microservicios independientes ni de interfaces de usuario.

