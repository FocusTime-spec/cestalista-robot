#!/bin/bash
# Cloud Shell: pone los robots de Gadis y Caprabo a funcionar EN EL SERVIDOR,
# sin ScraperAPI (gratis). Cada 3 minutos procesa un lote de cada uno.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
set -e
D=/srv/cestalista
echo "[1/4] Modo sin ScraperAPI en el servidor..."
grep -q '^SCRAPERAPI_OFF=' $D/.env || echo 'SCRAPERAPI_OFF=1' >> $D/.env
echo "[2/4] Poniendo la app al día..."
bash $D/actualizar.sh | tail -2 || true
sudo systemctl restart cestalista; sleep 6
echo "   Versión: $(git -C $D/app log -1 --format='%h %s' | cut -c1-60)"
echo "[3/4] Creando el robot..."
cat > $D/robot.sh <<'SH'
#!/bin/bash
# Lanza un lote de cada robot de catálogo contra la app local.
CS=$(grep '^CRON_SECRET=' /srv/cestalista/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
for s in gadis caprabo; do
  r=$(curl -s -m 120 -X POST -H "Authorization: Bearer $CS" "http://127.0.0.1:3000/api/public/hooks/crawl-$s")
  echo "$(date '+%F %T') $s $(echo "$r" | tr -d '\n' | cut -c1-220)"
done
SH
chmod +x $D/robot.sh
sudo tee /etc/systemd/system/cestalista-robot.service >/dev/null <<UNIT
[Unit]
Description=CestaLista: robots de catálogo (Gadis, Caprabo)
[Service]
Type=oneshot
User=ubuntu
ExecStart=/bin/bash -c '$D/robot.sh >> $D/robot.log 2>&1; tail -n 3000 $D/robot.log > $D/robot.tmp && mv $D/robot.tmp $D/robot.log'
UNIT
sudo tee /etc/systemd/system/cestalista-robot.timer >/dev/null <<UNIT
[Unit]
Description=CestaLista: robots cada 3 minutos
[Timer]
OnBootSec=3min
OnUnitActiveSec=3min
[Install]
WantedBy=timers.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable -q --now cestalista-robot.timer
echo "[4/4] Primera pasada de prueba..."
bash $D/robot.sh
echo ""
echo "======================================"
echo " ROBOTS FUNCIONANDO EN EL SERVIDOR"
echo "======================================"
IN
