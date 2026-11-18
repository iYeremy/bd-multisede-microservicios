# Conclusiones y extensiones

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

## 1. Cumplimiento de los requisitos

Los criterios de aceptación del enunciado (sección 18 de [`analisis.md`](analisis.md)), y dónde se
comprueba cada uno:

| Criterio | Cumple | Dónde se ve |
| --- | --- | --- |
| Problema y alcance documentados | ✓ | [`problema-alcance-supuestos-reglasdenegocio.md`](problema-alcance-supuestos-reglasdenegocio.md) |
| Modelo E-R con entidades y cardinalidades | ✓ | `diagramas/02_modelo_ER/` |
| Modelo relacional normalizado hasta 3FN | ✓ | `diagramas/03_modelo_relacional/` y [`normalizacion.md`](normalizacion.md) |
| Entidades asignadas a su módulo | ✓ | [`distribucion.md`](distribucion.md): cada tabla vive en la instancia de su servicio |
| Al menos 4 sedes y 4 almacenes | ✓ | 4 sedes y 5 almacenes (el CEDI tiene dos bodegas) |
| Catálogo, compras, inventarios, transferencias, ventas, pagos y devoluciones | ✓ | `sql/02_tablas/` |
| Claves y restricciones implementadas | ✓ | Pruebas 1 a 4c de la [`matriz`](matriz-pruebas.md) |
| Historial de precios de compras y ventas | ✓ | `costo_unitario` en el detalle de cada orden y `precio_unitario` en el de cada pedido: el precio queda fijo aunque cambie el de lista |
| Seis roles y sus privilegios | ✓ | `sql/06_roles/` y las 12 pruebas de permisos (9.x) |
| Esquemas de los módulos documentados | ✓ | [`distribucion.md`](distribucion.md) y [`diccionario-datos.md`](diccionario-datos.md) |
| Fragmentación horizontal de dos conjuntos por sede | ✓ | Inventarios (`inv_*`) y pedidos (`ped_*` + `det_ped_*`), con `CHECK (id_sede = n)` |
| Los fragmentos se pueden consultar solos | ✓ | Pruebas 5 y 5b; el backend lee solo el fragmento de la sede de la sesión |
| Vistas consolidadas que integran los fragmentos | ✓ | `vista_*_consolidado` con `UNION ALL`; prueba 6 (304 = 304) |
| Al menos 10 vistas | ✓ | 13 vistas materializadas en reportes |
| Las 20 consultas | ✓ | `sql/07_consultas/` e [`analisis-resultados.md`](analisis-resultados.md) |
| Recursos SQL exigidos | ✓ | Tabla de cobertura en `sql/07_consultas/README.md`: 7 CTE, 5 consultas con funciones de ventana, `EXCEPT`, `INTERSECT`, `UNION ALL`, `NOT EXISTS`, subconsultas correlacionadas |
| Mínimos de volumen y periodo | ✓ | 80 productos, 100 clientes, 300 pedidos, 60 órdenes, 25 transferencias, 22 devoluciones, de mayo a octubre (6 meses) |
| Escenarios para resultados variados | ✓ | Ver la tabla de abajo |
| Pruebas de integridad, fragmentación, consultas y permisos | ✓ | [`matriz-pruebas.md`](matriz-pruebas.md): 37 de 37 |
| El reporte corporativo no duplica | ✓ | Prueba 10: cada total = el de la fuente; con un solo `JOIN` saldría 3,7 veces más |
| Resultados, evidencias, manual y conclusiones | ✓ | `evidencias*.txt`, [`manual-ejecucion.md`](manual-ejecucion.md) y este documento |

**Los 12 escenarios de negocio obligatorios** aparecen en los resultados:

| Escenario | Consulta que lo muestra |
| --- | --- |
| Existencias distintas por sede | 1, 18 |
| Productos sin ventas recientes | 16 (14 productos) |
| Clientes de varias sedes | 6 (63 clientes) |
| Proveedores con retrasos | 11 (dos nunca cumplen) |
| Pedidos con pagos parciales | 7 (61 pedidos con saldo) |
| Compras incompletas | 12 (13 órdenes parciales) |
| Transferencias en tránsito | 13 (4 transferencias) |
| Productos bajo el stock mínimo | 2 (48 alertas) |
| Diferencias entre enviado y recibido | 14 (4 transferencias) |
| Productos con devoluciones | 17 |
| Productos activos sin inventario en una sede | 3 (34 casos) |
| Vendedores con ventas distintas | 19 |

## 2. Lo que se hizo además del enunciado

El enunciado aceptaba una sola base con un esquema por módulo y no pedía backend ni despliegue.
Después se pidieron **microservicios reales**, y el proyecto quedó así:

- **Una instancia de PostgreSQL por servicio**, no solo una base: en local, 6 servidores en
  puertos distintos; en la nube, 6 proyectos de Neon. Los mismos scripts sirven para los dos.
- **Backend en Go:** un programa por microservicio, cada uno conectado solo a su instancia con su
  usuario `svc_*`, y un gateway que valida la sesión y es la única entrada.
- **Un front** que muestra cada pantalla con el fragmento de donde salen los datos, y el estado de
  los servicios en vivo.
- **Docker:** todo el sistema (6 bases + backend) se levanta con un comando.
- **Desplegado:** las bases en Neon y el backend en una VM de Azure.

## 3. Limitaciones

Lo que el sistema **no** hace, o hace de forma simplificada, y por qué:

| Limitación | Consecuencia | Por qué se aceptó |
| --- | --- | --- |
| Reportes usa `dblink` | Reportes depende de cómo están hechas las tablas de los demás: si un servicio cambia una tabla, el refresco se rompe | Es la forma más simple de integrar con SQL, que es lo que evalúa la materia. Es la única excepción a "cada servicio solo ve lo suyo" (supuesto S-18) |
| `dblink` entra con el dueño de cada instancia | Tiene más permisos de los que necesita | Lo correcto sería un usuario de solo lectura por instancia; queda como mejora |
| Los reportes van atrasados | Hasta el siguiente refresco (5 minutos) no muestran lo último | Consistencia eventual, a propósito: los reportes no cargan a las bases del día a día (prueba 12) |
| No hay FK entre bases | La base no impide guardar un id de otra base que no existe | PostgreSQL no lo permite. Se revisa con la prueba extra (0 huérfanos) y en el backend, que valida con catálogo antes de guardar un pedido |
| No hay triggers | Que una recepción sume al inventario no pasa solo | Son dos bases distintas: un trigger no puede tocar la otra. Es trabajo del backend (supuesto S-10) |
| El backend solo **escribe pedidos** | Pagos, recepciones, transferencias y estados se consultan pero no se registran desde la aplicación | Alcance: con los pedidos se demuestra el flujo completo entre servicios |
| Sesiones y bloqueo de login en memoria | Si identidad se reinicia, todos vuelven a entrar | Con una sola copia de identidad es suficiente |
| Sin HTTPS | Entre el navegador y la VM el tráfico no va cifrado (de la VM a Neon sí) | Hace falta un dominio y un certificado; se puede agregar con Caddy |
| Todo el backend en una VM | Si la VM se apaga, se cae todo junto | Es disponibilidad, no arquitectura: cada servicio sigue siendo independiente |
| Latencia en la nube | Cada consulta va de Chile (VM) a Ohio (Neon): ~130 ms por viaje | La suscripción de estudiante solo permite algunas regiones |
| Reiniciar los datos borra todo | `correr.sh` hace `DROP DATABASE` | Para un proyecto con datos de prueba es lo más simple; en producción se usan migraciones |
| Datos de prueba sintéticos | Los análisis describen los datos generados, no una empresa real | Así lo permite el enunciado (13.3) |

## 4. Extensiones futuras

Ordenadas de más a menos útiles:

1. **Completar las escrituras del backend:** registrar pagos, recepciones (y que sumen al
   inventario llamando a inventarios), despachar y recibir transferencias, y cambiar el estado de
   un pedido.
2. **Reportes sin `dblink`:** que cada servicio publique sus cambios (eventos) y reportes los
   guarde en sus propias tablas. Así reportes dejaría de depender de las tablas de los demás.
3. **Un usuario de solo lectura** en cada instancia, solo para reportes.
4. **HTTPS** con Caddy y un dominio, y `COOKIE_SEGURA=true`.
5. **Sesiones en una base o en Redis**, para poder tener más de una copia de identidad.
6. **Migraciones** (archivos numerados que solo agregan cambios) en vez de borrar y crear.
7. **`REFRESH ... CONCURRENTLY`**, para que los reportes se puedan leer mientras se refrescan
   (necesita un índice único en cada vista).
8. **Monitoreo:** métricas de cada servicio (cuánto tarda, cuántos errores) y alertas.

## 5. Conclusiones

- **La fragmentación por sede funciona y se nota en los permisos.** Con una tabla por sede, que un
  vendedor no vea otra sede lo garantiza PostgreSQL con un `GRANT`, no un `WHERE` en el código. Los
  `CHECK` impiden que una fila caiga en el fragmento equivocado, y las vistas consolidadas devuelven
  exactamente la suma de los fragmentos.
- **Separar en instancias tiene un precio, y hay que pagarlo a conciencia.** Al no poder hacer un
  `JOIN` entre bases, se pierden las FK entre servicios y los reportes no pueden ser en tiempo real.
  Se resolvió con `dblink` + vistas materializadas (consistencia eventual) y revisando la
  integridad con consultas, y está medido en las pruebas 10, 12 y la extra.
- **Agregar con cuidado.** La prueba 10 muestra que un solo `JOIN` entre pedidos, compras y
  transferencias multiplica las ventas por 3,7: cada fuente se resume primero y después se juntan.
- **Los datos cuentan una historia coherente:** el CEDI concentra el inventario y las compras,
  Medellín es la sede con más quiebres de stock (y es justo donde hay pedidos que no se pueden
  despachar), dos proveedores nunca cumplen, y buena parte de los faltantes se resolvería moviendo
  mercancía entre sedes antes de comprar.
- **Los permisos son de la base, no de la aplicación.** Incluso con el backend, cada servicio entra
  con un usuario que solo tiene permiso sobre su instancia: si el código tuviera un error, la base
  igual no dejaría leer lo de otro servicio.
