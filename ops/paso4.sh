#!/bin/bash
# Desde la Cloud Shell (después de "npx vercel login"): copia las claves de Vercel
# al servidor SIN mostrarlas, y lanza la instalación de la app.
set -uo pipefail
IP=$(cat ~/.cestalista-ip); K=~/.ssh/cestalista
W=$(mktemp -d); cd "$W"
echo "[A] Buscando el proyecto de CestaLista en Vercel..."
P=$(npx -y vercel@latest project ls 2>&1 | awk '{print $1}' | grep -ix cestalista | head -1)
P=${P:-cestalista}
echo "   Proyecto: $P"
npx -y vercel@latest link --yes --project "$P" > link.log 2>&1 || { tail -5 link.log; echo "   ERROR enlazando. Captura a Claude."; exit 1; }
echo "[B] Copiando las claves (no se muestran)..."
npx -y vercel@latest env pull .envp --environment=production --yes > pull.log 2>&1 || { tail -5 pull.log; echo "   ERROR copiando claves. Captura a Claude."; exit 1; }
grep -vE '^(VERCEL|VERCEL_[A-Z_]*|NX_[A-Z_]*|TURBO_[A-Z_]*)=' .envp | grep -E '^[A-Z]' > .env.server
echo "   Claves copiadas: $(wc -l < .env.server). Nombres:"
cut -d= -f1 .env.server | tr '\n' ' '; echo
VACIAS=$(grep -cE '^[A-Z0-9_]+=""?$' .env.server || true)
[ "${VACIAS:-0}" = 0 ] || echo "   OJO: $VACIAS claves vienen vacías: $(grep -E '^[A-Z0-9_]+=""?$' .env.server | cut -d= -f1 | tr '\n' ' ')"
scp -q -i $K .env.server ubuntu@"$IP":/tmp/cl.env && ssh -n -i $K ubuntu@"$IP" 'sudo mv /tmp/cl.env /srv/cestalista/.env && sudo chown ubuntu:ubuntu /srv/cestalista/.env && chmod 600 /srv/cestalista/.env'
cd ~ && rm -rf "$W"
echo "[C] Instalando la app en el servidor (5-10 minutos)..."
ssh -n -i $K ubuntu@"$IP" 'curl -fsSL https://raw.githubusercontent.com/FocusTime-spec/cestalista-robot/main/ops/servidor-app.sh | bash'
