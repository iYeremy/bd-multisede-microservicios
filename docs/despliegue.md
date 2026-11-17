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
| `config/local.env`, `config/neon.env` | Las copias con los datos reales | **No** (están en `.gitignore`) |

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

No hace falta Docker: `scripts/instancias_locales.sh` levanta 6 PostgreSQL como procesos
normales, cada uno en su puerto. Solo escuchan en `localhost` y entran sin contraseña (es solo
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

## 5. Qué cambió respecto a una sola instancia

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

## 6. Seguridad

- **Las contraseñas solo viven en `config/*.env`**, que git ignora.
- **Los usuarios `svc_*` se crean sin contraseña.** Al desplegar se les pone una, con
  `ALTER ROLE svc_ventas PASSWORD '...'` en su instancia, para que el backend se conecte.
- **`dblink` se conecta con el usuario dueño de cada instancia**, guardado en la tabla privada `remoto.servidores` de la base de reportes. Funciona, pero lo más seguro
  sería un usuario de **solo lectura** en cada instancia, solo para reportes. Queda como mejora.
- **Las instancias locales entran sin contraseña** (`trust`), pero solo escuchan en `localhost`.
