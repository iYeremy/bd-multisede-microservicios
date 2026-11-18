#!/usr/bin/env bash
# docker_init.sh
# lo corre el contenedor "init" de docker-compose.yml, una vez, antes de
# arrancar el backend: crea las bases (run_all.sql) y les pone clave a los
# svc_*. si las bases ya existen (el volumen ya tiene datos) no hace nada,
# para no borrar lo que hayas creado. REINICIAR=true fuerza a recrearlas.

set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE=config/docker.env
set -a; . "$ENV_FILE"; set +a

existe=$(psql -X -tA "postgresql://$REPORTES_USER:$REPORTES_PASSWORD@$REPORTES_HOST:$REPORTES_PORT/$ADMIN_DB" \
    -c "SELECT 1 FROM pg_database WHERE datname = 'andina_reportes'")

if [ "$existe" = "1" ] && [ "${REINICIAR:-false}" != "true" ]; then
    echo ">> las bases ya existen: no se toca nada (REINICIAR=true para recrearlas)"
    exit 0
fi

echo ">> creando las bases y cargando los datos (run_all.sql)"
# la salida completa va a un archivo; aqui solo el resumen
scripts/correr.sh "$ENV_FILE" > /tmp/run_all.log 2>&1 || { tail -30 /tmp/run_all.log; exit 1; }
echo "   listo ($(grep -c 'ERROR' /tmp/run_all.log) errores, los esperados de 08_pruebas son 16)"
echo ">> claves de los usuarios tecnicos"
scripts/claves_svc.sh "$ENV_FILE"
