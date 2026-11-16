#!/usr/bin/env bash
# backend.sh
# compila y arranca en tu pc los programas del backend (el gateway y cada
# microservicio que ya exista en backend/cmd/), cada uno como un proceso
# aparte.
#
#   scripts/backend.sh iniciar [config/local.env]   compila y arranca todos
#   scripts/backend.sh detener                      los apaga
#   scripts/backend.sh estado                       cuales estan corriendo
#
# los ejecutables quedan en backend/bin/ y los logs en backend/logs/
# (git ignora los dos). las instancias de postgresql tienen que estar
# corriendo: scripts/instancias_locales.sh iniciar

set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$RAIZ/backend/bin"
LOGS="$RAIZ/backend/logs"
# todo se corre desde la raiz del proyecto: asi encuentra config/local.env
cd "$RAIZ"

programas() { ls "$RAIZ/backend/cmd"; }

iniciar() {
    local config="${1:-config/local.env}"
    [ -f "$RAIZ/$config" ] || { echo "no existe $config (copia el .example)"; exit 1; }
    mkdir -p "$BIN" "$LOGS"
    echo ">> compilando"
    (cd "$RAIZ/backend" && for p in $(programas); do go build -o "$BIN/$p" "./cmd/$p"; done)
    for p in $(programas); do
        if [ -f "$BIN/$p.pid" ] && kill -0 "$(cat "$BIN/$p.pid")" 2>/dev/null; then
            echo "   $p ya esta corriendo"
            continue
        fi
        # sin subshell: asi $! es el pid del programa y no el de otra shell
        nohup "$BIN/$p" -config "$config" > "$LOGS/$p.log" 2>&1 &
        echo $! > "$BIN/$p.pid"
        echo "   $p arrancado (log: backend/logs/$p.log)"
    done
    sleep 1
    estado
}

detener() {
    for p in $(programas); do
        if [ -f "$BIN/$p.pid" ] && kill -0 "$(cat "$BIN/$p.pid")" 2>/dev/null; then
            kill "$(cat "$BIN/$p.pid")" && echo "   $p detenido"
        fi
        rm -f "$BIN/$p.pid"
    done
}

estado() {
    for p in $(programas); do
        if [ -f "$BIN/$p.pid" ] && kill -0 "$(cat "$BIN/$p.pid")" 2>/dev/null; then
            echo "   $p: corriendo"
        else
            echo "   $p: apagado (si fallo al arrancar, mira backend/logs/$p.log)"
        fi
    done
}

case "${1:-}" in
    iniciar) iniciar "${2:-}" ;;
    detener) detener ;;
    estado)  estado ;;
    *) echo "uso: $0 {iniciar [config/local.env]|detener|estado}"; exit 1 ;;
esac
