# 00_config: a dónde se conecta cada servicio

Cada microservicio vive en **su propia instancia** de PostgreSQL, así que los scripts necesitan
saber el host, el puerto, el usuario y la contraseña de cada una. `conexiones.sql` los lee de las
variables de entorno y arma una dirección por servicio.

| Archivo | Qué hace |
|---|---|
| `conexiones.sql` | Lee la configuración y arma `:conn_<servicio>` y `:conn_<servicio>_admin` |

## De dónde salen los datos

De un archivo `config/<ambiente>.env` (ver `docs/despliegue.md`). `scripts/correr.sh` lo carga
como variables de entorno antes de llamar a psql:

```bash
scripts/correr.sh config/local.env
```

## Cómo funciona

- **`\getenv variable NOMBRE`** (comando de psql): copia la variable de entorno `NOMBRE` a una
  variable de psql. Por ejemplo, `\getenv ventas_port VENTAS_PORT`.
- **`\set conn_ventas 'postgresql://' :ventas_user ':' :ventas_password '@' ...`**: `\set` pega
  varios pedazos en uno solo. Queda una dirección del tipo
  `postgresql://postgres:@localhost:5445/andina_ventas?sslmode=disable`.
- **Dos direcciones por servicio:**
  - `:conn_ventas_admin` va a la base de administración (`postgres` en local, `neondb` en Neon).
    Desde ahí se borra y se crea `andina_ventas`, porque no se puede borrar la base en la que uno
    está conectado.
  - `:conn_ventas` va a `andina_ventas`.
- **`\c :conn_ventas`** conecta a esa instancia. Se usa el formato `postgresql://...` porque no
  lleva espacios: `\c` no acepta una dirección con espacios guardada en una variable.
- **Si falta la configuración** (por ejemplo, si se corrió `psql -f run_all.sql` directo, sin
  `correr.sh`), el script avisa y se detiene (`\quit`).

También quedan disponibles `:ventas_host`, `:ventas_port`, `:ventas_user`, `:ventas_password` y
`:ventas_db`, que usa `03_dblink/servidores.sql` para registrar las otras instancias.
