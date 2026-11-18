#!/usr/bin/env bash
# servidor.sh
# maneja el backend en el servidor de la nube (una vm con docker) desde tu
# pc, por ssh. las bases estan en neon; en la vm solo corren los 7
# contenedores (docker-compose.neon.yml).
#
#   scripts/servidor.sh iniciar      prende el backend (neon despierta solo)
#   scripts/servidor.sh detener      lo apaga (neon se duerme a los 5 min)
#   scripts/servidor.sh estado       que contenedores corren y /salud
#   scripts/servidor.sh actualizar   compila el ultimo commit en tu pc, sube los binarios y reinicia
#   scripts/servidor.sh logs ventas  el log de un servicio
#
# la direccion va en config/servidor.env (git lo ignora):
#   SERVIDOR=azureuser@<ip publica>
#
# ojo: esto apaga el backend, no la vm. la vm se apaga en el portal de
# azure (detener). igual, la vm apaga el backend sola a las 00:00 de bogota.

set -euo pipefail
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"
[ -f config/servidor.env ] || { echo "falta config/servidor.env con SERVIDOR=usuario@ip"; exit 1; }
# shellcheck disable=SC1091
source config/servidor.env
: "${SERVIDOR:?falta SERVIDOR en config/servidor.env}"

IP="${SERVIDOR#*@}"
COMPOSE="cd ~/andina && sudo docker compose -f docker-compose.neon.yml"
remoto() { ssh -o BatchMode=yes -o ConnectTimeout=15 "$SERVIDOR" "$@"; }
PROGRAMAS="gateway catalogo identidad compras inventarios ventas reportes"

salud() {
    for i in $(seq 1 30); do
        if curl -s -m 5 -o /dev/null -w '%{http_code}' "http://$IP/salud" | grep -q 200; then
            curl -s "http://$IP/salud"; echo
            echo ">> listo: http://$IP"
            return 0
        fi
        sleep 2
    done
    echo ">> /salud no responde 200 todavia:"; curl -s -m 5 "http://$IP/salud"; echo
    return 1
}

case "${1:-}" in
    iniciar)
        remoto "$COMPOSE up -d"
        salud ;;
    detener)
        remoto "$COMPOSE down"
        echo ">> backend apagado. neon se duerme solo en ~5 min" ;;
    estado)
        remoto "$COMPOSE ps --format 'table {{.Service}}\t{{.Status}}'"
        curl -s -m 5 "http://$IP/salud" && echo || echo "(el gateway no responde)" ;;
    actualizar)
        # se compila en TU pc (segundos) y a la vm solo se suben los binarios:
        # compilar en la vm, con su cpu limitada, tarda ~10 minutos
        echo ">> compilando para linux en tu pc (ultimo commit de $(git branch --show-current))"
        TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
        git archive HEAD backend | tar -x -C "$TMP"
        mkdir -p "$TMP/bin"
        for p in $PROGRAMAS; do
            (cd "$TMP/backend" && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags "-s -w" -o "$TMP/bin/$p" "./cmd/$p")
        done
        cp "$TMP/backend/Dockerfile.binario" "$TMP/bin/Dockerfile"
        echo ">> subiendo (rsync: solo lo que cambio, comprimido)"
        remoto "mkdir -p ~/andina/bin ~/andina/config"
        rsync -az --delete "$TMP/bin/" "$SERVIDOR:andina/bin/"
        git archive HEAD docker-compose.neon.yml | remoto "tar -x -C ~/andina"
        rsync -az config/neon.env "$SERVIDOR:andina/config/neon.env"
        remoto "chmod 600 ~/andina/config/neon.env"
        echo ">> armando las imagenes en la vm (solo copiar el binario: segundos)"
        for p in $PROGRAMAS; do
            remoto "sudo docker build -q -t andina/$p --build-arg PROGRAMA=$p ~/andina/bin" >/dev/null
            echo "   $p"
        done
        remoto "$COMPOSE up -d --no-build && sudo docker image prune -f >/dev/null"
        salud ;;
    logs)
        remoto "$COMPOSE logs --tail 50 ${2:-}" ;;
    *)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
