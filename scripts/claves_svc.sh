#!/usr/bin/env bash
# claves_svc.sh
# le pone contrasena al usuario tecnico svc_<servicio> de cada instancia,
# con las SVC_<SERVICIO>_PASSWORD del archivo .env. hace falta en docker y
# en neon (en local no: las instancias entran sin clave). hay que correrlo
# despues de cada scripts/correr.sh, porque el reset borra los usuarios.
#
#   scripts/claves_svc.sh config/docker.env

set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE="${1:?uso: $0 config/<ambiente>.env}"
set -a; . "$ENV_FILE"; set +a

for s in catalogo identidad compras inventarios ventas reportes; do
    S="$(echo "$s" | tr '[:lower:]' '[:upper:]')"
    H="${S}_HOST"; P="${S}_PORT"; U="${S}_USER"; W="${S}_PASSWORD"; C="SVC_${S}_PASSWORD"
    if [ -z "${!C:-}" ]; then
        echo "   svc_$s: sin clave en $ENV_FILE, se deja como esta"
        continue
    fi
    # la clave va como variable de psql (:'clave'), que la escapa bien;
    # asi no aparece en la linea de comandos ni rompe el sql
    echo "ALTER ROLE svc_$s PASSWORD :'clave';" |
        psql -X -q -v ON_ERROR_STOP=1 -v clave="${!C}" \
            "postgresql://${!U}:${!W}@${!H}:${!P}/andina_$s?sslmode=$SSLMODE"
    echo "   svc_$s: clave puesta"
done
