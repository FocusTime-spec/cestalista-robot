#!/bin/bash
# Cloud Shell: añade el robot del catálogo de Dia a los robots del servidor
# (se lanza con los demás cada 3 minutos). Sin créditos de ScraperAPI no hace
# nada y espera; cuando se renueven, empieza solo.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
echo "[1/3] Poniendo la app al día..."
bash $D/actualizar.sh 2>&1 | tail -2 || true
sudo systemctl restart cestalista; sleep 8
echo "   Versión: $(git -C $D/app log -1 --format='%h %s' | cut -c1-70)"
echo "[2/3] Añadiendo Dia al robot..."
if grep -qE '^for s in .*\bdia\b' $D/robot.sh; then
  echo "   Ya estaba."
else
  sed -i -E 's/^for s in (.*); do/for s in \1 dia; do/' $D/robot.sh
fi
grep -E '^for s in' $D/robot.sh | sed 's/^/   /'
echo "[3/3] Primera pasada de prueba de Dia..."
CS=$(grep '^CRON_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
curl -s -m 150 -X POST -H "Authorization: Bearer $CS" "http://127.0.0.1:3000/api/public/hooks/crawl-dia" | cut -c1-300
echo ""
echo "--- fin ---"
IN
