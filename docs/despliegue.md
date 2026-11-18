# Despliegue: una instancia de PostgreSQL por servicio

Proyecto final de Bases de Datos · Comercializadora Andina S.A.S.

Cada microservicio tiene **su propia instancia** de PostgreSQL: un servidor aparte, con sus
propios usuarios y su propia contraseña. No solo una base aparte: un servidor aparte.

| Servicio | Base | Instancia local | En la nube (Neon) |
| --- | --- | --- | --- |
| Catálogo y Terceros | `andina_catalogo` | `localhost:5441` | proyecto `andina-catalogo` |
| Identidad y Accesos | `andina_identidad` | `localhost:5442` | proyecto `andina-identidad` |
| Compras y Abastecimiento | `andina_compras` | `localhost:5443` | proyecto `andina-compras` |
| Inventarios y Transferencias | `andina_inventarios` | `localhost:5444` | proyecto `andina-inventarios` |
| Ventas y Pagos | `andina_ventas` | `localhost:5445` | proyecto `andina-ventas` |
| Reportes Corporativos | `andina_reportes` | `localhost:5446` | proyecto `andina-reportes` |

**Lo que se gana:** si se cae una instancia, las otras siguen. Además, cada una tiene solo los
usuarios que usa: `gerente_general`, por ejemplo, solo existe en la de reportes.

---

## 1. La configuración: un archivo por ambiente

Los datos de conexión de las 6 instancias van en un archivo `.env`:

| Archivo | Para qué | ¿Se sube a git? |
| --- | --- | --- |
| `config/local.env.example` | Plantilla para las instancias locales | Sí |
| `config/neon.env.example` | Plantilla para Neon | Sí |
| `config/docker.env.example` | Plantilla para todo en Docker | Sí |
| `config/local.env`, `config/neon.env`, `config/docker.env` | Las copias con los datos reales | **No** (están en `.gitignore`) |

Cada servicio tiene 4 datos: `HOST`, `PORT`, `USER` y `PASSWORD`. Por ejemplo:

```
VENTAS_HOST=localhost
VENTAS_PORT=5445
VENTAS_USER=postgres
VENTAS_PASSWORD=
```

Hay además 3 datos generales:
- `ADMIN_DB`: la base desde la que se crean las demás (`postgres` en local, `neondb` en Neon).
- `SSLMODE`: `disable` en local, `require` en Neon.
- `NO_SUPERUSUARIO`: `true` en Neon, donde no eres superusuario.

El backend lee el mismo archivo y usa unos datos más: `TOKEN_INTERNO`, `SVC_<SERVICIO>_PASSWORD`,
`PUERTO_GATEWAY` y `REFRESCO_MINUTOS` (ver la sección 5). Los valores van sin comillas ni espacios.

**Las contraseñas nunca van en el repositorio**, solo en tu archivo `.env`.

## 2. Cómo se corre

Siempre con `scripts/correr.sh`: carga el `.env` y llama a psql.

```bash
scripts/correr.sh config/local.env                                    # todo (run_all.sql)
scripts/correr.sh config/local.env reportes sql/05_reportes/refrescar.sql  # un archivo, en la base de un servicio
```

`run_all.sql` lee la configuración con `\getenv` (`sql/00_config/conexiones.sql`) y arma una
dirección por servicio, del tipo `postgresql://usuario:clave@host:puerto/base`. Después va
instancia por instancia, con un `\c` a cada una: borra y crea su base, sus tablas, sus datos y
sus roles.

---

## 3. En tu computador

No hace falta Docker (aunque también se puede, ver la sección 5):
`scripts/instancias_locales.sh` levanta 6 PostgreSQL como procesos normales, cada uno en su puerto. Solo escuchan en `localhost` y entran sin contraseña (es solo
para desarrollar).

```bash
scripts/instancias_locales.sh iniciar        # la primera vez las crea; luego solo las arranca
cp config/local.env.example config/local.env
scripts/correr.sh config/local.env           # arma todo
scripts/instancias_locales.sh detener        # al terminar
```

| Comando | Qué hace |
| --- | --- |
| `iniciar` | Crea las instancias (la primera vez) y las arranca |
| `detener` | Las apaga |
| `estado` | Dice cuáles están corriendo |
| `borrar` | Las apaga y borra sus datos (`.instancias/`) |

Los puertos son 5441 a 5446, para no chocar con el PostgreSQL normal del sistema (5432).

---

## 4. En la nube: Neon

[Neon](https://neon.com) es PostgreSQL administrado: no hay que instalar ni mantener servidores.
**Un proyecto de Neon = una instancia.** El plan gratis alcanza de sobra: hasta 100 proyectos,
1 GB por proyecto y 100 horas de cómputo por proyecto al mes. `dblink` está soportado.

### Pasos

1. **Crear 6 proyectos** en Neon (`andina-catalogo`, `andina-identidad`…), con PostgreSQL 17 o
   superior. Todos en la misma región, para que `dblink` sea rápido.
2. En cada proyecto, entrar a **Connect**, **desactivar "Connection pooling"** (el host no debe
   tener `-pooler`) y copiar host, usuario y contraseña.
3. `cp config/neon.env.example config/neon.env` y llenar los datos de cada proyecto.
4. Correr todo:
   ```bash
   scripts/correr.sh config/neon.env > docs/evidencias-neon.txt 2>&1
   ```
5. Revisar que salgan los mismos errores esperados que en local (las pruebas de rechazo).

### Lo que cambia en Neon

| Qué | Por qué | Cómo se resolvió |
| --- | --- | --- |
| No eres superusuario | Neon no lo permite | `NO_SUPERUSUARIO=true`: quien corre los scripts se hace miembro de los usuarios de prueba, para poder usar `SET ROLE` en las pruebas |
| `dblink` no puede usar `CREATE SERVER` | El conector `dblink_fdw` es del superusuario interno de Neon | Las conexiones a las otras instancias se guardan en una tabla privada (`remoto.servidores`), con usuario y clave sacados del `.env`. Lo mismo se usa en local |
| No se puede quitar el permiso de usar `dblink` | Sus funciones son del superusuario interno | No hace falta: las conexiones están en un esquema privado, y sin contraseña `dblink` no deja conectarse a quien no es superusuario |
| Conexión cifrada | Neon solo acepta SSL | `SSLMODE=require` |
| Las bases "se duermen" | Tras 5 minutos sin uso se apagan | La primera consulta tarda un poco más. No afecta los resultados |
| No hay `cron` en el servidor | El servidor no es nuestro | El servicio de reportes del backend refresca las vistas solo, cada `REFRESCO_MINUTOS` (ver abajo) |

### El refresco de los reportes en Neon

Lo hace el **servicio de reportes** del backend: mientras está encendido, refresca todas las vistas
cada `REFRESCO_MINUTOS` (5 por defecto), y el administrador puede forzarlo con
`POST /api/reportes/refrescar`. Con el backend apagado no se refresca nada, y así Neon puede
dormirse (no gasta horas de cómputo). A mano, sin backend:
`scripts/correr.sh config/neon.env reportes sql/05_reportes/refrescar.sql`.

> **Probado en local y en Neon:** las dos dan exactamente los mismos resultados en las 20 consultas
> y en todas las pruebas (`docs/evidencias.txt` y `docs/evidencias-neon.txt`, con los hosts de Neon
> ocultos). En Neon, la corrida completa tarda unos 2 minutos.

---

## 5. El backend

El backend (`backend/`, en Go) son 7 programas: el **gateway** y un programa por microservicio.
Cada servicio se conecta **solo a su instancia**, con su usuario `svc_<servicio>`, y le pide a los
demás lo que necesita por HTTP. Lo único que se publica hacia afuera es el gateway (puerto 8080).
El detalle de las rutas y de las reglas está en [`backend/README.md`](../backend/README.md).

Hay tres formas de correrlo, y las tres pasan las mismas 31 pruebas de
`scripts/probar_backend.sh` ([`evidencias-backend.txt`](evidencias-backend.txt)):

| Forma | Bases | Programas | Comando |
| --- | --- | --- | --- |
| Local | `instancias_locales.sh` (5441–5446) | procesos sueltos | `scripts/backend.sh iniciar` |
| Docker | 6 contenedores `postgres:18` | 7 contenedores | `docker compose up --build -d` |
| Docker + Neon | los 6 proyectos de Neon | 7 contenedores | `docker compose -f docker-compose.neon.yml up --build -d` |

### Las contraseñas de los `svc_*`

Los scripts SQL crean los `svc_*` **sin contraseña**. Las contraseñas van en el `.env`
(`SVC_VENTAS_PASSWORD`…), junto con `TOKEN_INTERNO` (la clave que usan los servicios entre ellos),
y se ponen en cada instancia con:

```bash
scripts/claves_svc.sh config/neon.env     # ALTER ROLE svc_<servicio> PASSWORD ... en cada instancia
```

Hay que correrlo otra vez cada vez que se rehacen las bases con `correr.sh`, porque este borra y
vuelve a crear los usuarios. En Docker no hace falta: el contenedor `init` lo hace solo.

### En Docker

- `docker-compose.yml`: 6 contenedores de PostgreSQL (uno por servicio, con su volumen), un
  contenedor `init` que corre `run_all.sql` y `claves_svc.sh` la primera vez, y los 7 programas.
  Las bases se publican solo en `127.0.0.1:6441`–`6446`, para entrar con psql; los servicios no se
  publican. La configuración va en `config/docker.env` (copiar de `docker.env.example`).
- `docker-compose.neon.yml`: solo los 7 programas, con `config/neon.env`. Es lo que correría en
  un servidor en la nube: las bases ya están en Neon.
- Una sola receta (`backend/Dockerfile`) sirve para los 7 programas: compila el que se le pida
  (`PROGRAMA`) y lo deja en una imagen mínima, sin shell, que corre sin ser root.

```bash
docker compose ps                  # qué está corriendo
docker compose logs -f ventas      # el log de un servicio
docker compose stop catalogo       # apagar uno, para ver los fallos
docker compose down                # apagar todo (los datos quedan; con -v se borran)
```

### Neon y las horas gratis

Neon apaga cada proyecto a los **5 minutos sin conexiones**, y el plan gratis solo cuenta las horas
en que está encendido. El backend tiene conexiones abiertas todo el tiempo y refresca los reportes
cada `REFRESCO_MINUTOS`, así que **mientras el backend está encendido, Neon no se duerme**. Por
eso se enciende solo para probar o presentar, y al terminar:

```bash
docker compose -f docker-compose.neon.yml down    # se cierran las conexiones; Neon se duerme solo
```

La primera petición después de un rato tarda unos segundos más, mientras Neon despierta.
`probar_backend.sh` espera a que `/salud` responda antes de empezar.

Antes de presentar conviene volver a dejar los datos como al principio (las pruebas crean
pedidos):

```bash
scripts/correr.sh config/neon.env && scripts/claves_svc.sh config/neon.env
```

## 6. En la nube: el backend en una VM de Azure

Las bases ya están en Neon; falta dónde corran los 7 programas. Se usa **una VM de Azure con
Docker**, con la misma `docker-compose.neon.yml` de la sección 5.

```
navegador ──► :80  VM de Azure (Ubuntu 24.04, Docker)
                    └─ gateway ─► 6 contenedores ──► 6 proyectos de Neon (sslmode=require)
```

**¿Correr los 7 programas en una sola máquina rompe los microservicios?** No. Cada servicio sigue
siendo un programa aparte, con su propia base, que habla con los demás solo por HTTP y se puede
actualizar solo (`docker compose up -d --build ventas`). Para moverlo a otra máquina basta con
cambiar `URL_VENTAS`. Lo que se pierde es disponibilidad (si se apaga la VM, se cae todo junto),
y eso es un tema de infraestructura, no de arquitectura.

### Por qué Azure for Students

| | |
| --- | --- |
| Sin tarjeta de crédito | se entra con el correo de la universidad |
| No puede cobrar | la suscripción tiene **límite de gasto de $0**: si se acaba el crédito (USD 100), se apaga |
| Gratis | el tamaño `B2ats_v2` tiene 750 horas al mes gratis; solo el disco y la IP pública usan un poco del crédito |

Se probaron también AWS (pide tarjeta y hay acciones que pasan la cuenta a pago), Oracle Cloud
(pide tarjeta y casi nunca hay máquinas libres) y Render (en el plan gratis los servicios no se
hablan por una red privada: habría que exponer los 6).

### La VM

| Campo | Valor |
| --- | --- |
| Región | **Chile Central**: la suscripción de estudiante solo deja algunas regiones (*Policy → Assignments → Allowed resource deployment regions*); las de EE. UU. no estaban |
| Tamaño | `Standard_B2ats_v2` (2 vCPU, 1 GiB), con 2 GB de swap para poder compilar |
| Imagen | Ubuntu Server 24.04 LTS, x64 |
| Acceso | llave SSH (sin contraseña); puertos abiertos: 22 y 80 |
| Docker | lo instala `cloud-init` al crear la VM (*Advanced → Custom data*): `docker.io`, `docker-compose-v2` |

En la VM, `~/andina/.env` tiene `PUERTO_PUBLICO=80`, para que el gateway quede en el puerto 80.

### Manejarla desde el PC

`config/servidor.env` (git lo ignora) tiene `SERVIDOR=azureuser@<ip>`, y:

```bash
scripts/servidor.sh iniciar      # prende el backend; Neon despierta solo
scripts/servidor.sh estado
scripts/probar_backend.sh http://<ip>
scripts/servidor.sh detener      # SIEMPRE al terminar: Neon se duerme a los 5 min
scripts/servidor.sh actualizar   # copia el último commit, recompila de a una imagen y reinicia
```

**Por si se olvida apagar:** la región no permite el apagado automático de Azure, así que la VM
tiene un `cron` (`/etc/cron.d/andina-apagado`) que hace `docker compose down` todos los días a las
00:00 de Bogotá. Lo que más importa apagar es el backend, no la VM: con el backend prendido, Neon
no se duerme y gasta las horas gratis del mes.

Contra la VM, las 31 pruebas pasan desde Bogotá en ~35 s (cada petición va Bogotá → Chile → Ohio).

### Velocidad y la ruta de red

Desde dentro de la VM, el gateway responde en ~1 ms; lo lento es el camino. Se midió que la ruta
Bogotá → Chile Central a veces pierde paquetes, y una descarga puede quedarse varios segundos
esperando el reenvío. Para notarlo menos:

- **gzip:** el gateway comprime todo lo que es texto (el front y el JSON de la API), así viajan de 3
  a 9 veces menos bytes (`app.js`: 52 KB → 16 KB).
- **ETag:** si un archivo del front no cambió, el navegador no lo vuelve a bajar (responde `304`).
- **Actualizar sin compilar en la VM:** `servidor.sh actualizar` compila en el PC (segundos) y sube
  solo los binarios; la VM arma cada imagen con `backend/Dockerfile.binario`, que solo copia el
  programa. Compilar allá, con su CPU limitada, tardaba ~10 minutos.

**Alternativa si hiciera falta:** un túnel de Cloudflare (`cloudflared`). El navegador se conecta a
Cloudflare cerca de Bogotá y Cloudflare lleva el tráfico a la VM por su red, que suele tener mejor
ruta. Además da HTTPS sin certificado propio y no hace falta abrir el puerto 80.

## 7. Qué cambió respecto a una sola instancia

| Parte | Antes (6 bases en un servidor) | Ahora (6 instancias) |
| --- | --- | --- |
| Conexión | `\c andina_ventas` | `\c :conn_ventas`: la dirección de **su** instancia, sacada del `.env` |
| `01_bases/` | Un script creaba las 6 bases | `crear.sql` crea solo la base de la instancia actual |
| `03_dblink/` | Servidores remotos (`CREATE SERVER`) por el socket local | Una tabla privada `remoto.servidores` con la conexión de cada instancia, y `dblink(remoto.servidor('catalogo'), ...)` |
| `06_roles/` | Un script, roles compartidos | **Un archivo por instancia** con solo los roles que usa |
| Prueba 9.2 | Gerencia sin permiso en ventas | Gerencia **ni existe** en la instancia de ventas |
| Prueba 11.3 | `CONNECT` de cada rol en las 6 bases | Desde reportes se le pregunta por `dblink` a cada instancia qué usuarios tiene |

Lo que **no** cambió: las tablas, los datos, las vistas, las 20 consultas y sus resultados (dan
exactamente lo mismo).

## 8. Seguridad

- **Las contraseñas solo viven en `config/*.env`**, que git ignora.
- **Los usuarios `svc_*` se crean sin contraseña.** Al desplegar se les pone una con
  `scripts/claves_svc.sh` (sección 5), sacada del `.env`, para que el backend se conecte.
- **En la VM solo están abiertos el 22 (SSH, solo con llave) y el 80.** Mejor aún: limitar el 22
  a tu IP en el grupo de seguridad de red de la VM. Sin dominio no hay HTTPS: el tráfico entre el
  navegador y la VM va sin cifrar (de la VM a Neon sí va cifrado).
- **Solo el gateway está expuesto.** Los servicios no publican puerto; sus rutas `/interno`
  además piden `TOKEN_INTERNO`, y el gateway nunca las reenvía.
- **Las claves de la aplicación van con bcrypt.** Los datos de prueba traen MD5; identidad lo
  cambia por bcrypt la primera vez que cada usuario entra. 5 claves malas seguidas bloquean al
  usuario 15 minutos.
- **`dblink` se conecta con el usuario dueño de cada instancia**, guardado en la tabla privada `remoto.servidores` de la base de reportes. Funciona, pero lo más seguro
  sería un usuario de **solo lectura** en cada instancia, solo para reportes. Queda como mejora.
- **Las instancias locales entran sin contraseña** (`trust`), pero solo escuchan en `localhost`.
