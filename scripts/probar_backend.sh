#!/usr/bin/env bash
# probar_backend.sh
# prueba el backend de punta a punta, como lo haria un navegador: todo
# pasa por el gateway. sirve igual en local y en docker.
#
#   scripts/probar_backend.sh [http://localhost:8080]
#
# las claves de prueba son <usuario>2026 (ver sql/04_datos/identidad.sql).
# ojo: crea un pedido de prueba en la sede de cali.

set -uo pipefail
G="${1:-http://localhost:8080}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
OK=0; FALLAS=0

# revisar "descripcion" codigo_esperado curl...
revisar() {
    local desc="$1" esperado="$2"; shift 2
    local codigo
    codigo=$(curl -s -o "$TMP/cuerpo" -w '%{http_code}' "$@")
    if [ "$codigo" = "$esperado" ]; then
        OK=$((OK + 1)); printf '  ok     %-55s %s\n' "$desc" "$codigo"
    else
        FALLAS=$((FALLAS + 1)); printf '  FALLA  %-55s %s (se esperaba %s): %s\n' "$desc" "$codigo" "$esperado" "$(head -c 150 "$TMP/cuerpo")"
    fi
}
login() { curl -s -c "$TMP/$1" -o /dev/null -X POST "$G/api/identidad/login" -d "{\"usuario\":\"$1\",\"password\":\"${1}2026\"}"; }
como() { local u="$1"; shift; revisar "$1" "$2" -b "$TMP/$u" "${@:3}"; }

echo "== gateway en $G"
revisar "los seis servicios responden (/salud)"            200 "$G/salud"

echo "== login y sesion"
revisar "sin sesion no se entra"                            401 "$G/api/catalogo/productos"
revisar "clave mala"                                        401 -X POST "$G/api/identidad/login" -d '{"usuario":"vendedor_cali","password":"x"}'
revisar "login bien"                                        200 -X POST "$G/api/identidad/login" -d '{"usuario":"vendedor_cali","password":"vendedor_cali2026"}'
for u in admin_andina gerente_general inventario_cali compras_cedi vendedor_cali vendedor_bogota auditor_interno; do login "$u"; done
como vendedor_cali "quien soy"                              200 "$G/api/identidad/yo"
como vendedor_cali "un header falso no da permisos"         403 -H 'X-Usuario-Rol: ADMINISTRADOR' "$G/api/identidad/auditoria"
como auditor_interno "el auditor ve la auditoria"           200 "$G/api/identidad/auditoria"

echo "== cada rol ve lo suyo"
como vendedor_cali   "vendedor: productos"                  200 "$G/api/catalogo/productos"
como vendedor_cali   "vendedor: pedidos de su sede"         200 "$G/api/ventas/pedidos"
como vendedor_cali   "vendedor: no ve compras"              403 "$G/api/compras/ordenes"
como vendedor_cali   "vendedor: no ve reportes"             403 "$G/api/reportes"
como inventario_cali "inventario: su fragmento"             200 "$G/api/inventarios/mi-sede"
como inventario_cali "inventario: alertas"                  200 "$G/api/reportes/vista_alertas_reabastecimiento"
como inventario_cali "inventario: no ve el corporativo"     403 "$G/api/reportes/vista_reporte_corporativo"
como compras_cedi    "compras: ordenes"                     200 "$G/api/compras/ordenes"
como compras_cedi    "compras: detalle de una orden"        200 "$G/api/compras/ordenes/1"
como gerente_general "gerencia: reporte corporativo"        200 "$G/api/reportes/vista_reporte_corporativo"
como gerente_general "gerencia: vista que no existe"        404 "$G/api/reportes/pg_shadow"
como gerente_general "gerencia: no puede refrescar"         403 -X POST "$G/api/reportes/refrescar"

echo "== crear un pedido (vendedor_cali)"
como vendedor_cali "pedido valido"                          201 -X POST "$G/api/ventas/pedidos" -d '{"id_cliente":5,"productos":[{"id_producto":1,"cantidad":3},{"id_producto":17,"cantidad":2}]}'
ID=$(python3 -c "import json; print(json.load(open('$TMP/cuerpo'))['pedido']['id_pedido'])" 2>/dev/null || echo 0)
como vendedor_cali "el pedido $ID se ve en su sede"         200 "$G/api/ventas/pedidos/$ID"
como vendedor_cali "producto descontinuado"                 400 -X POST "$G/api/ventas/pedidos" -d '{"id_cliente":5,"productos":[{"id_producto":39,"cantidad":1}]}'
como vendedor_cali "cliente que no existe"                  400 -X POST "$G/api/ventas/pedidos" -d '{"id_cliente":9999,"productos":[{"id_producto":1,"cantidad":1}]}'
como vendedor_cali "producto repetido"                      400 -X POST "$G/api/ventas/pedidos" -d '{"id_cliente":5,"productos":[{"id_producto":1,"cantidad":1},{"id_producto":1,"cantidad":1}]}'
como gerente_general "gerencia no crea pedidos"             403 -X POST "$G/api/ventas/pedidos" -d '{"id_cliente":5,"productos":[{"id_producto":1,"cantidad":1}]}'

echo "== reportes: consistencia eventual"
como admin_andina "refrescar ahora (admin)"                 200 -X POST "$G/api/reportes/refrescar"
como gerente_general "el pedido nuevo ya esta en reportes"  200 "$G/api/reportes/vista_pedidos_consolidado?sede=3&limite=5000"
if python3 -c "import json,sys; d=json.load(open('$TMP/cuerpo')); sys.exit(0 if any(r['id_pedido']==$ID for r in d['datos']) else 1)"; then
    OK=$((OK + 1)); echo "  ok     el pedido $ID aparece en vista_pedidos_consolidado"
else
    FALLAS=$((FALLAS + 1)); echo "  FALLA  el pedido $ID no aparece en vista_pedidos_consolidado"
fi

echo "== cerrar sesion"
como vendedor_cali "logout"                                 200 -X POST "$G/api/identidad/logout"
como vendedor_cali "despues del logout ya no entra"         401 "$G/api/identidad/yo"

echo
echo "resultado: $OK ok, $FALLAS fallas"
[ "$FALLAS" -eq 0 ]
