#!/bin/bash
# Se ejecuta en la Cloud Shell de Oracle. Deja el servidor listo para servir
# https://servidor.cestalista.com con candado (HTTPS gratis de Let's Encrypt):
#  1) abre los puertos 80 y 443 en la red de Oracle
#  2) dentro del servidor: abre el cortafuegos, instala Caddy (HTTPS automático),
#     actualiza la app a la última versión y activa la actualización automática.
# No toca cestalista.com ni Vercel. Se puede repetir sin problema.
set -euo pipefail
T="${OCI_TENANCY:?Abre esto dentro de la Cloud Shell de Oracle}"
IP=$(cat ~/.cestalista-ip)
SHA="${SHA:-main}"
BASE="https://raw.githubusercontent.com/FocusTime-spec/cestalista-robot/$SHA/ops"

echo "[1/3] Abriendo los puertos 80 y 443 en la red de Oracle..."
SUBNET=$(oci network subnet list -c "$T" --display-name "public subnet-cestalista-red" --query "data[0].id" --raw-output)
SL=$(oci network subnet get --subnet-id "$SUBNET" --query 'data."security-list-ids"[0]' --raw-output)
oci network security-list get --security-list-id "$SL" --query 'data."ingress-security-rules"' > /tmp/cl-ing.json
python3 - <<'PY'
import json, re
rules = json.load(open("/tmp/cl-ing.json"))
def camel(o):
    if isinstance(o, dict):
        return {re.sub(r"-(\w)", lambda m: m.group(1).upper(), k): camel(v) for k, v in o.items() if v is not None}
    if isinstance(o, list):
        return [camel(x) for x in o]
    return o
rules = camel(rules)
def tiene(p):
    for r in rules:
        rng = (r.get("tcpOptions") or {}).get("destinationPortRange") or {}
        if r.get("protocol") == "6" and rng.get("min", 0) <= p <= rng.get("max", -1):
            return True
    return False
cambia = False
for p in (80, 443):
    if not tiene(p):
        rules.append({"protocol": "6", "source": "0.0.0.0/0", "isStateless": False,
                      "tcpOptions": {"destinationPortRange": {"min": p, "max": p}},
                      "description": "web CestaLista"})
        cambia = True
json.dump(rules, open("/tmp/cl-ing-new.json", "w"))
open("/tmp/cl-cambia", "w").write("1" if cambia else "0")
PY
if [ "$(cat /tmp/cl-cambia)" = "1" ]; then
  oci network security-list update --security-list-id "$SL" --ingress-security-rules file:///tmp/cl-ing-new.json --force >/dev/null
  echo "   Abiertos."
else
  echo "   Ya estaban abiertos."
fi

echo "[2/3] Preparando el servidor (tarda unos minutos)..."
ssh -n -i ~/.ssh/cestalista -o StrictHostKeyChecking=accept-new ubuntu@"$IP" \
  "curl -fsSL $BASE/servidor-web.sh -o /tmp/servidor-web.sh && BASE=$BASE bash /tmp/servidor-web.sh"

echo "[3/3] Hecho."
echo ""
echo "=========================================================="
echo " SERVIDOR LISTO. Falta solo el paso de Porkbun:"
echo "   Tipo A · Host: servidor · Respuesta: $IP"
echo "=========================================================="
