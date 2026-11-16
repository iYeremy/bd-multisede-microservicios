#!/usr/bin/env bash
# instancias_locales.sh
# levanta en tu pc un postgresql por microservicio (6 en total), sin docker.
# cada uno es un servidor aparte, con su carpeta de datos y su puerto.
#
#   scripts/instancias_locales.sh iniciar   crea (la primera vez) y arranca las 6
#   scripts/instancias_locales.sh detener   las apaga
#   scripts/instancias_locales.sh estado    muestra cuales estan corriendo
#   scripts/instancias_locales.sh borrar    las apaga y borra sus datos
#
# los datos quedan en .instancias/ (git lo ignora). solo escuchan en
# localhost y entran sin contrasena (trust): es solo para desarrollar.
# puertos 5441 a 5446, para no chocar con el postgresql normal (5432).

set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DATOS="$RAIZ/.instancias"

# servicio:puerto
INSTANCIAS="catalogo:5441 identidad:5442 compras:5443 inventarios:5444 ventas:5445 reportes:5446"

iniciar() {
    mkdir -p "$DATOS"
    for i in $INSTANCIAS; do
        servicio="${i%%:*}"; puerto="${i##*:}"; dir="$DATOS/$servicio"
        if [ ! -d "$dir" ]; then
            echo ">> creando la instancia de $servicio"
            initdb -D "$dir" -U postgres -A trust -E UTF8 --locale=C.UTF-8 >/dev/null
        fi
        if pg_ctl -D "$dir" status >/dev/null 2>&1; then
            echo "   $servicio ya esta corriendo (puerto $puerto)"
        else
            # unix_socket_directories vacio: solo se conecta por localhost:puerto
            pg_ctl -D "$dir" -l "$dir/postgres.log" -w \
                -o "-p $puerto -c listen_addresses=localhost -c unix_socket_directories=''" start >/dev/null
            echo "   $servicio corriendo en localhost:$puerto"
        fi
    done
}

detener() {
    for i in $INSTANCIAS; do
        servicio="${i%%:*}"; dir="$DATOS/$servicio"
        if [ -d "$dir" ] && pg_ctl -D "$dir" status >/dev/null 2>&1; then
            pg_ctl -D "$dir" -m fast stop >/dev/null
            echo "   $servicio detenido"
        fi
    done
}

estado() {
    for i in $INSTANCIAS; do
        servicio="${i%%:*}"; puerto="${i##*:}"; dir="$DATOS/$servicio"
        if [ -d "$dir" ] && pg_ctl -D "$dir" status >/dev/null 2>&1; then
            echo "   $servicio: corriendo (localhost:$puerto)"
        else
            echo "   $servicio: apagado"
        fi
    done
}

case "${1:-}" in
    iniciar) iniciar ;;
    detener) detener ;;
    estado)  estado ;;
    borrar)  detener; rm -rf "$DATOS"; echo "   datos borrados" ;;
    *) echo "uso: $0 {iniciar|detener|estado|borrar}"; exit 1 ;;
esac
