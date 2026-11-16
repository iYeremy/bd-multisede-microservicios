#!/usr/bin/env bash
# correr.sh
# corre un script sql con la configuracion de conexion de un ambiente.
#
#   scripts/correr.sh config/local.env                 corre todo (run_all.sql)
#   scripts/correr.sh config/neon.env                  lo mismo, contra neon
#   scripts/correr.sh config/local.env reportes sql/05_reportes/refrescar.sql
#       corre un archivo conectado a la base de un servicio
#
# carga las variables del archivo .env y se las pasa a psql, que las lee
# con \getenv (ver sql/00_config/).

set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${1:?uso: $0 config/<ambiente>.env [servicio archivo.sql]}"
[ -f "$ENV_FILE" ] || { echo "no existe $ENV_FILE (copia el .example)"; exit 1; }

set -a; . "$ENV_FILE"; set +a

if [ $# -ge 3 ]; then
    # un archivo suelto, conectado a la base de un servicio
    S="$(echo "$2" | tr '[:lower:]' '[:upper:]')"
    H="${S}_HOST"; P="${S}_PORT"; U="${S}_USER"; W="${S}_PASSWORD"
    exec psql -X "postgresql://${!U}:${!W}@${!H}:${!P}/andina_$2?sslmode=$SSLMODE" -f "$3"
else
    # todo el proyecto: arranca conectado a catalogo; run_all hace sus \c
    exec psql -X "postgresql://$CATALOGO_USER:$CATALOGO_PASSWORD@$CATALOGO_HOST:$CATALOGO_PORT/$ADMIN_DB?sslmode=$SSLMODE" -f run_all.sql
fi
