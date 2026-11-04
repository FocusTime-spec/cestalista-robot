#!/bin/bash
# Se ejecuta DENTRO del servidor como "ubuntu". Descarga CestaLista de GitHub,
# la construye para servidor Node y la deja funcionando como servicio (puerto 3000).
set -euo pipefail
APP=/srv/cestalista/app; ENVF=/srv/cestalista/.env
[ -f "$ENVF" ] || { echo "Falta $ENVF (las claves). Para."; exit 1; }
echo "[1/5] Descargando el código de GitHub..."
if [ -d "$APP/.git" ]; then git -C "$APP" fetch -q origin main && git -C "$APP" reset -q --hard origin/main
else git clone -q git@github.com:FocusTime-spec/cestalista.git "$APP"; fi
echo "   Versión: $(git -C "$APP" log -1 --format='%h %s' | cut -c1-70)"
echo "[2/5] Instalando dependencias (tarda unos minutos)..."
# Vercel instala con bun (bun.lock), así que usamos lo mismo para tener las mismas versiones.
[ -x ~/.bun/bin/bun ] || { curl -fsSL https://bun.sh/install | bash >/dev/null 2>&1; }
export PATH="$HOME/.bun/bin:$PATH"
cd "$APP" && { bun install --frozen-lockfile >/tmp/cl-install.log 2>&1 || bun install >>/tmp/cl-install.log 2>&1 || { tail -20 /tmp/cl-install.log; echo "   ERROR instalando."; exit 1; }; }
echo "[3/5] Construyendo la app..."
cp "$ENVF" "$APP/.env.production"
NITRO_PRESET=node-server npx vite build > /tmp/cl-build.log 2>&1 || { tail -25 /tmp/cl-build.log; echo "   ERROR al construir."; exit 1; }
rm -f "$APP/.env.production"
echo "[4/5] Creando el servicio..."
sudo tee /etc/systemd/system/cestalista.service >/dev/null <<UNIT
[Unit]
Description=CestaLista (app)
After=network-online.target
[Service]
User=ubuntu
WorkingDirectory=$APP
EnvironmentFile=$ENVF
Environment=NODE_ENV=production PORT=3000 HOST=127.0.0.1
ExecStart=/usr/bin/node $APP/.output/server/index.mjs
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload && sudo systemctl enable -q cestalista && sudo systemctl restart cestalista
echo "[5/5] Comprobando..."
sleep 5
for p in / /proximamente /guias /api/public/recipes; do
  printf "   %-22s %s\n" "$p" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 http://127.0.0.1:3000$p)"
done
echo ""
echo "======================================"
echo " APP INSTALADA EN EL SERVIDOR"
echo "======================================"
