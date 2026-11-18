# Backend (Go)

Cada microservicio es **su propio programa**: se compila aparte, corre como un proceso (o
contenedor) aparte, escucha en su propio puerto y se conecta **solo a su instancia** de
PostgreSQL con su usuario técnico `svc_<servicio>`. Delante va el **gateway**, la única puerta
de entrada: valida la sesión y reenvía cada petición al servicio que toca.

```
navegador ─► gateway :8080 ─┬─► identidad   :8102 ─► instancia identidad
                            ├─► catalogo    :8101 ─► instancia catalogo
                            ├─► compras     :8103 ─► instancia compras
                            ├─► inventarios :8104 ─► instancia inventarios
                            ├─► ventas      :8105 ─► instancia ventas
                            └─► reportes    :8106 ─► instancia reportes ─dblink─► las demás
```

## Cómo correrlo

**En tu PC (procesos sueltos):**
```bash
scripts/instancias_locales.sh iniciar        # las 6 instancias de PostgreSQL
scripts/correr.sh config/local.env           # crea las bases y carga los datos
scripts/backend.sh iniciar                   # compila y arranca los 7 programas
scripts/probar_backend.sh                    # 31 pruebas de punta a punta
scripts/backend.sh detener catalogo          # apagar uno, para ver los fallos
scripts/backend.sh detener                   # apagar todos
```

**En Docker (todo en contenedores, incluidas las bases):**
```bash
cp config/docker.env.example config/docker.env
docker compose up --build -d
scripts/probar_backend.sh
docker compose stop catalogo                 # apagar uno
docker compose down                          # apagar todo (los datos quedan; -v los borra)
```

**Backend en Docker contra Neon (las bases ya están en Neon):**
```bash
scripts/claves_svc.sh config/neon.env        # contraseñas de los svc_* (tras cada correr.sh)
docker compose -f docker-compose.neon.yml up --build -d
scripts/probar_backend.sh
docker compose -f docker-compose.neon.yml down   # SIEMPRE al terminar: si no, Neon no se duerme
```

**En la nube (VM de Azure + Neon):** `scripts/servidor.sh iniciar | detener | estado | actualizar`
(ver `docs/despliegue.md`, sección 6).

Las salidas de todas las formas están en [`docs/evidencias-backend.txt`](../docs/evidencias-backend.txt).

**Pruebas de Go:** `cd backend && go test ./...`

## Usuarios de prueba

Los 12 de `identidad.usuarios`. La clave es el usuario seguido de `2026`, por ejemplo
`vendedor_cali` / `vendedor_cali2026`. Los datos de prueba traen hashes MD5; la primera vez que
alguien entra, identidad lo cambia por **bcrypt**.

## Rutas

| Método | Ruta | Roles | Qué hace |
| --- | --- | --- | --- |
| POST | `/api/identidad/login` | todos | `{"usuario","password"}`, deja la cookie `sesion`. 5 claves malas seguidas bloquean ese usuario 15 min (`429`) |
| POST | `/api/identidad/logout` | todos | cierra la sesión |
| GET | `/api/identidad/yo` | todos | quién soy |
| GET | `/api/identidad/auditoria` | AUDITOR, ADMIN | últimos accesos |
| GET | `/api/catalogo/productos`, `/clientes`, `/sedes` | según la ruta | datos maestros |
| GET | `/api/inventarios/mi-sede[?bajos=true]` | INVENTARIO, ADMIN | el fragmento `inv_<sede>` |
| GET | `/api/inventarios/transferencias` | INVENTARIO, ADMIN | traslados |
| GET | `/api/compras/ordenes[/{id}]` | COMPRAS, ADMIN | órdenes, con lo pedido y lo recibido |
| GET | `/api/ventas/pedidos[/{id}]` | VENDEDOR, ADMIN | pedidos del fragmento `ped_<sede>` |
| POST | `/api/ventas/pedidos` | VENDEDOR | `{"id_cliente", "productos":[{"id_producto","cantidad"}]}` |
| GET | `/api/reportes[/{vista}]` | GERENCIA, AUDITOR, ADMIN (+ algunas INVENTARIO y COMPRAS) | las vistas materializadas |
| POST | `/api/reportes/refrescar` | ADMIN | `REFRESH` ahora |
| GET | `/salud` | público | estado de los 6 servicios |

El ADMINISTRADOR puede pedir otra sede con `?sede=N`. Para los demás, la sede **siempre** sale de
la sesión.

## Carpetas

| Carpeta | Qué hay |
| --- | --- |
| `cmd/<programa>/` | El `main` de cada programa. Es corto: solo dice qué servicio arrancar. |
| `internal/plataforma/` | Lo que comparten todos (solo "plomería"): config, conexión a la base, JSON, log, roles y llamadas entre servicios. |
| `internal/gateway/` | Valida la sesión, reenvía `/api/<servicio>/...` y arma `/salud`. |
| `internal/servicios/<servicio>/` | Un microservicio: `servicio.go` tiene el SQL y `http.go` las rutas. |
| `Dockerfile` | Una receta para los 7 programas (`--build-arg PROGRAMA=...`). |

## Reglas que sigue el código

- **Un servicio nunca usa el código de otro.** Si ventas necesita un producto, se lo pide a
  catálogo por HTTP. `internal/plataforma/arquitectura_test.go` falla si alguien lo rompe.
- **`/api/...` es público, `/interno/...` es entre servicios.** Lo interno pide la clave
  `X-Token-Interno`, y el gateway nunca lo reenvía.
- **El gateway autentica, cada servicio autoriza.** El gateway borra los `X-Usuario-*` que mande
  el navegador y pone los de la sesión; cada servicio revisa el rol.
- **SQL a mano con `pgx`**, los valores siempre como parámetros (`$1`). Los nombres de tabla
  (fragmentos, vistas) solo salen de un mapa o de una lista blanca, escapados con `Sanitize()`.
- **El dinero va en centavos** (enteros) para no tener errores de redondeo.
- **Las lecturas a otro servicio se reintentan una vez; las escrituras no.**

## Qué pasa si algo se cae

| Qué se cae | Qué pasa |
| --- | --- |
| catalogo | Crear un pedido da `503` y no se guarda nada. Inventario, compras y pedidos siguen, con ids en lugar de nombres y un aviso. |
| identidad | No se puede validar la sesión: el gateway responde `503` a todo menos `/salud`. |
| la instancia de un servicio | Ese servicio responde `503 La base de datos no responde`; se reconecta solo cuando vuelve. |
| una instancia, durante el refresco | El refresco falla entero (una transacción) y los reportes quedan con los datos anteriores. |
| cualquiera | `/salud` lo muestra como `caido` o `sin base de datos`. |

## Lo que no hace (todavía)

- Solo escribe **pedidos**. Pagos, recepciones, transferencias y cambios de estado solo se leen.
- Las **sesiones** y el bloqueo de login viven en la memoria de identidad: si se reinicia, todos
  vuelven a iniciar sesión. Con varias copias de identidad habría que guardarlas en una base o en
  Redis.
- No hay **HTTPS** propio: en un servidor iría un proxy delante (Caddy, nginx) y
  `COOKIE_SEGURA=true`.
