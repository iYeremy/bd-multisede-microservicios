# Backend (Go)

Cada microservicio es **su propio programa**: se compila aparte, corre como un proceso aparte,
escucha en su propio puerto y se conecta **solo a su instancia** de PostgreSQL, con su usuario
técnico `svc_<servicio>`. Delante de todos va el **gateway**, la única puerta de entrada.

```
navegador ─► gateway :8080 ─► catalogo :8101 ─► instancia catalogo (localhost:5441)
                           └► (los demás servicios llegan en las siguientes fases)
```

## Cómo correrlo en tu PC

```bash
scripts/instancias_locales.sh iniciar        # las 6 instancias de PostgreSQL
scripts/correr.sh config/local.env           # crea las bases y carga los datos (si no lo has hecho)
scripts/backend.sh iniciar                   # compila y arranca el gateway y los servicios
curl localhost:8080/api/catalogo/productos   # pasa por el gateway y llega a catalogo
curl localhost:8080/salud                    # estado de los seis servicios
scripts/backend.sh detener
```

Los ejecutables quedan en `backend/bin/` y los logs en `backend/logs/` (git ignora los dos).
La configuración sale de los **mismos** `config/*.env` que usan los scripts SQL, más las
variables del final (`TOKEN_INTERNO`, `PUERTO_GATEWAY`, `SVC_<SERVICIO>_PASSWORD`).

## Carpetas

| Carpeta | Qué hay |
| --- | --- |
| `cmd/<programa>/` | El `main` de cada programa. Es corto: solo dice qué servicio arrancar. |
| `internal/plataforma/` | Lo que comparten todos (solo "plomería", sin reglas de negocio): leer el `.env`, conectarse a la base, responder JSON, el log de cada petición y las llamadas entre servicios. |
| `internal/gateway/` | Reenvía `/api/<servicio>/...` al servicio que toca y arma `/salud`. |
| `internal/servicios/<servicio>/` | Un microservicio: `servicio.go` tiene el SQL y `http.go` las rutas. |

## Reglas que sigue el código

- **Un servicio nunca usa el código de otro.** Si ventas necesita un producto, se lo pide a
  catálogo por HTTP. La prueba `internal/plataforma/arquitectura_test.go` falla si alguien
  importa el paquete de otro servicio (`cd backend && go test ./...`).
- **Rutas públicas y rutas internas.** `/api/...` llega desde el navegador por el gateway.
  `/interno/...` es solo para otros servicios: pide la clave `X-Token-Interno`, y el gateway
  nunca la reenvía.
- **Los servicios solo escuchan en `127.0.0.1`.** Desde otra máquina solo se llega al gateway.
- **El SQL va escrito a mano** (con `pgx`, sin ORM) y los valores siempre como parámetros (`$1`),
  así no hay inyección SQL.
- **El dinero va en centavos** (`precio_centavos`, entero) para no tener errores de redondeo.
- **Los errores de la base se traducen** a un código HTTP claro (403 sin permiso, 400 datos
  inválidos, 503 base caída). El detalle técnico va al log, nunca al usuario.

## Qué pasa si algo se cae

| Qué se cae | Qué responde |
| --- | --- |
| El proceso de catálogo | El gateway: `503 Servicio catalogo no disponible`. Los demás siguen. |
| La instancia de la base de catálogo | Catálogo: `503 La base de datos no responde`. Cuando la base vuelve, se reconecta solo. |
| Cualquiera | `/salud` lo muestra como `caido` o `sin base de datos`. |
