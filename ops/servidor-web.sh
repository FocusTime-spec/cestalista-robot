#!/bin/bash
# Se ejecuta DENTRO del servidor como "ubuntu" (lo lanza web-servidor.sh).
#  - abre el cortafuegos del servidor (80/443)
#  - instala Caddy: HTTPS gratis y automático para servidor.cestalista.com
#  - deja la actualización automática: cada 5 minutos mira si hay versión
#    nueva en GitHub y, si la hay, la construye; si falla, vuelve a la anterior.
set -euo pipefail
DOM="servidor.cestalista.com"
BASE="${BASE:?}"
D=/srv/cestalista

echo "   · Cortafuegos del servidor..."
for p in 80 443; do
  if ! sudo iptables -C INPUT -p tcp -m state --state NEW --dport $p -j ACCEPT 2>/dev/null; then
    N=$(sudo iptables -L INPUT --line-numbers -n | awk '/REJECT/ {print $1; exit}')
    sudo iptables -I INPUT "${N:-1}" -p tcp -m state --state NEW --dport $p -j ACCEPT
  fi
done
command -v netfilter-persistent >/dev/null && sudo netfilter-persistent save >/dev/null 2>&1 || true

echo "   · Actualizador automático..."
curl -fsSL "$BASE/servidor-app.sh" -o $D/servidor-app.sh
cat > $D/actualizar.sh <<'SH'
#!/bin/bash
# Mira si hay versión nueva de CestaLista en GitHub y la instala.
exec 9>/tmp/cl-actualizar.lock; flock -n 9 || exit 0
APP=/srv/cestalista/app
git -C "$APP" fetch -q origin main || exit 0
OLD=$(git -C "$APP" rev-parse HEAD); NEW=$(git -C "$APP" rev-parse origin/main)
[ "$OLD" = "$NEW" ] && exit 0
echo "$(date '+%F %T') Nueva versión $NEW (antes $OLD)"
if bash /srv/cestalista/servidor-app.sh; then
  echo "$(date '+%F %T') OK"
else
  echo "$(date '+%F %T') FALLÓ: vuelvo a $OLD"
  REF=$OLD bash /srv/cestalista/servidor-app.sh || echo "$(date '+%F %T') ERROR también al volver"
fi
SH
chmod +x $D/actualizar.sh
sudo tee /etc/systemd/system/cestalista-actualizar.service >/dev/null <<UNIT
[Unit]
Description=CestaLista: instalar versión nueva si la hay
[Service]
Type=oneshot
User=ubuntu
ExecStart=/bin/bash -c '$D/actualizar.sh >> $D/actualizar.log 2>&1'
UNIT
sudo tee /etc/systemd/system/cestalista-actualizar.timer >/dev/null <<UNIT
[Unit]
Description=CestaLista: comprobar versión nueva cada 5 minutos
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable -q --now cestalista-actualizar.timer

echo "   · Poniendo la app al día (si hay versión nueva, tarda unos minutos)..."
bash $D/actualizar.sh | tail -3 || true
echo "   Versión: $(git -C $D/app log -1 --format='%h %s' | cut -c1-60)"

echo "   · Instalando Caddy (HTTPS)..."
command -v caddy >/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get -y -qq install caddy >/dev/null
sudo tee /etc/caddy/Caddyfile >/dev/null <<CF
$DOM {
	encode zstd gzip
	reverse_proxy 127.0.0.1:3000
}
CF

echo "   · Esperando a que $DOM apunte aquí (lo de Porkbun)..."
MIA=$(curl -s --max-time 10 https://api.ipify.org || true)
for i in $(seq 1 40); do
  VE=$(getent ahostsv4 $DOM | awk 'NR==1{print $1}' || true)
  [ -n "$VE" ] && [ "$VE" = "$MIA" ] && break
  sleep 15
done
if [ "${VE:-}" != "$MIA" ]; then
  echo "   AVISO: $DOM todavía no apunta a $MIA (apunta a: ${VE:-nada})."
  echo "   Revisa el paso de Porkbun y vuelve a pegar la orden dentro de 10 minutos."
fi
sudo systemctl enable -q caddy && sudo systemctl restart caddy

echo "   · Comprobando el candado..."
OK=""
for i in $(seq 1 20); do
  C=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 https://$DOM/proximamente || true)
  [ "$C" = "200" ] && OK=1 && break
  sleep 6
done
if [ -n "$OK" ]; then echo "   https://$DOM funciona con candado."
else echo "   Aún sin candado (código ${C:-?}). Manda captura a Claude."; sudo journalctl -u caddy -n 5 --no-pager | cut -c1-200; fi
