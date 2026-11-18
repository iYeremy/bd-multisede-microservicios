#!/usr/bin/env bash
# servidor.sh
# maneja el backend en el servidor de la nube (una vm con docker) desde tu
# pc, por ssh. las bases estan en neon; en la vm solo corren los 7
# contenedores (docker-compose.neon.yml).
#
#   scripts/servidor.sh iniciar      prende el backend (neon despierta solo)
#   scripts/servidor.sh detener      lo apaga (neon se duerme a los 5 min)
#   scripts/servidor.sh estado       que contenedores corren y /salud
#   scripts/servidor.sh actualizar   copia el codigo de esta rama, recompila y reinicia
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
        echo ">> copiando el codigo (lo que esta en el ultimo commit de $(git branch --show-current))"
        git archive HEAD backend docker-compose.neon.yml | remoto "mkdir -p ~/andina && tar -x -C ~/andina"
        scp -q config/neon.env "$SERVIDOR:andina/config/neon.env"
        remoto "chmod 600 ~/andina/config/neon.env"
        echo ">> compilando de a una imagen (la vm tiene poca memoria)"
        for s in gateway catalogo identidad compras inventarios ventas reportes; do
            remoto "$COMPOSE build -q $s" >/dev/null
            echo "   $s"
        done
        remoto "$COMPOSE up -d"
        salud ;;
    logs)
        remoto "$COMPOSE logs --tail 50 ${2:-}" ;;
    *)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
