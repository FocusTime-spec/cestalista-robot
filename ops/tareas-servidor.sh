#!/bin/bash
# Cloud Shell: comprueba las tareas automáticas en el servidor (por el puente).
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
grep -q '^ADMIN_DB_BRIDGE=' $D/.env || echo 'ADMIN_DB_BRIDGE=1' >> $D/.env
echo "[1/3] Poniendo la app al día..."
bash $D/actualizar.sh | tail -1; sudo systemctl restart cestalista; sleep 6
echo "   Versión: $(git -C $D/app log -1 --format='%h %s' | cut -c1-55)"
CS=$(grep '^CRON_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
BS=$(grep '^ADMIN_BRIDGE_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
echo "[2/3] Alertas de precio (prueba real):"
curl -s -m 120 -X POST -H "Authorization: Bearer $CS" http://127.0.0.1:3000/api/public/hooks/check-price-alerts | cut -c1-300; echo
echo "[3/3] Pruebas gratis terminadas y SIN cobrar (solo contar, no cobra nada):"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for env in live sandbox test; do
  printf "   %-8s " "$env:"
  curl -s -m 30 -X POST -H "Authorization: Bearer $BS" -H 'Content-Type: application/json' \
    -d "{\"op\":\"crawl-db\",\"payload\":{\"table\":\"pro_trials\",\"chain\":[[\"select\",[\"user_id\",{\"count\":\"exact\",\"head\":true}]],[\"lte\",[\"ends_at\",\"$NOW\"]],[\"is\",[\"converted_at\",null]],[\"is\",[\"canceled_at\",null]],[\"eq\",[\"environment\",\"$env\"]]]}}" \
    https://project--6bb7450b-5865-4df2-bbb5-6f4045dd928f.lovable.app/api/public/admin/rpc | grep -o '"count":[0-9null]*\|"error":"[^"]*"'
done
IN
