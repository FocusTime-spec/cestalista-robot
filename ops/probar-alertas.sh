#!/bin/bash
# Cloud Shell: lanza la tarea de alertas de precio en el servidor y enseña el resultado.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
grep -q '^SELF_BASE_URL=' $D/.env || echo 'SELF_BASE_URL=http://127.0.0.1:3000' >> $D/.env
echo "Poniendo la app al día..."
for t in 1 2 3; do bash $D/actualizar.sh | tail -1; git -C $D/app log -1 --format=%s | grep -q "SELF_BASE_URL" && break; sleep 20; done
sudo systemctl restart cestalista
echo "Versión: $(git -C $D/app log -1 --format='%h %s' | cut -c1-55)"
CS=$(grep '^CRON_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
for i in $(seq 1 15); do [ "$(curl -s -o /dev/null -w '%{http_code}' -m 5 http://127.0.0.1:3000/proximamente)" = "200" ] && break; sleep 2; done
echo "Alertas de precio (puede tardar hasta 4 minutos)..."
curl -s -m 280 -w '\n[código %{http_code}, %{time_total}s]\n' -X POST -H "Authorization: Bearer $CS" http://127.0.0.1:3000/api/public/hooks/check-price-alerts | cut -c1-400
echo "Últimos errores de la app:"
sudo journalctl -u cestalista --since "-10 min" --no-pager | grep -i "error\|invalid" | tail -5 | cut -c1-250
IN
