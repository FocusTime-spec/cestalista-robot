#!/bin/bash
# Cloud Shell: los robots del servidor guardan por el puente de Lovable.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
grep -q '^CRAWL_DB_BRIDGE=' $D/.env || echo 'CRAWL_DB_BRIDGE=1' >> $D/.env
grep -q '^ADMIN_BRIDGE_SECRET=' $D/.env && echo "Clave del puente: SÍ está" || echo "Clave del puente: NO está"
echo "Poniendo la app al día..."
bash $D/actualizar.sh | tail -1
sudo systemctl restart cestalista; sleep 6
echo "Versión: $(git -C $D/app log -1 --format='%h %s' | cut -c1-50)"
CS=$(grep '^ADMIN_BRIDGE_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
echo -n "Puente de Lovable: "
curl -s -m 30 -X POST -H "Authorization: Bearer $CS" -H 'Content-Type: application/json' \
  -d '{"op":"crawl-db","payload":{"table":"retailer_crawl_queue","chain":[["select",["id",{"count":"exact","head":true}]]]}}' \
  https://project--6bb7450b-5865-4df2-bbb5-6f4045dd928f.lovable.app/api/public/admin/rpc | cut -c1-200; echo
echo "Pasada del robot:"
bash $D/robot.sh
IN
