#!/bin/bash
# Dentro del servidor: abre una dirección de pruebas TEMPORAL de Cloudflare
# (https://algo.trycloudflare.com) que apunta a la app. No abre puertos ni toca cestalista.com.
set -euo pipefail
if ! command -v cloudflared >/dev/null; then
  echo "[1/2] Instalando cloudflared..."
  curl -fsSL -o /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
  sudo dpkg -i /tmp/cloudflared.deb >/dev/null
fi
echo "[2/2] Abriendo la dirección de pruebas..."
pkill -f "cloudflared tunnel --url" 2>/dev/null || true
nohup cloudflared tunnel --no-autoupdate --url http://127.0.0.1:3000 > /tmp/tunel.log 2>&1 &
for i in $(seq 1 30); do
  URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/tunel.log | head -1 || true)
  [ -n "$URL" ] && break; sleep 2
done
echo ""
echo "=========================================================="
if [ -n "${URL:-}" ]; then echo " DIRECCIÓN DE PRUEBAS: $URL"; else echo " No salió la dirección. Manda captura a Claude."; tail -5 /tmp/tunel.log; fi
echo "=========================================================="
