#!/bin/bash
# Cloud Shell: robots de catálogo, uso de ScraperAPI y qué se usa de Lovable (solo lee).
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
echo "== AJUSTES: $(grep -oE '^(SCRAPERAPI_OFF|SCRAPERAPI_[A-Z_]+|CRAWL_DB_BRIDGE|ADMIN_DB_BRIDGE|SNAPSHOTS_ON_LOVABLE|SCRAPE_CAP_[A-Z]+)=[^ ]{0,6}' $D/.env | grep -v KEY | tr '\n' ' ')"
echo "== ROBOT: $(grep -o 'for s in [a-z ]*' $D/robot.sh 2>/dev/null) · timer $(systemctl is-active cestalista-robot.timer)"
echo "== ÚLTIMAS PASADAS"; tail -n 400 $D/robot.log 2>/dev/null | awk '{print $3}' | sort | uniq -c
for s in carrefour gadis caprabo froiz; do echo "-- $s: $(grep " $s " $D/robot.log 2>/dev/null | tail -1 | cut -c1-230)"; done
echo "== CRÉDITOS SCRAPERAPI (últimos días)"; ls $D/*.json 2>/dev/null | head; cat $D/scraperapi*.json 2>/dev/null | head -c 600; echo
echo "== PRODUCTOS EN CATÁLOGO"
BS=$(grep '^ADMIN_BRIDGE_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
for s in Carrefour Gadis Caprabo Froiz; do
  printf "   %-10s " "$s:"
  curl -s -m 30 -X POST -H "Authorization: Bearer $BS" -H 'Content-Type: application/json' \
   -d "{\"op\":\"crawl-db\",\"payload\":{\"table\":\"retailer_catalog\",\"chain\":[[\"select\",[\"id\",{\"count\":\"exact\",\"head\":true}]],[\"eq\",[\"supermarket\",\"$s\"]]]}}" \
   https://project--6bb7450b-5865-4df2-bbb5-6f4045dd928f.lovable.app/api/public/admin/rpc | grep -o '"count":[0-9null]*\|"error":"[^"]*"'
  printf "   %-10s cola pendiente " ""
  curl -s -m 30 -X POST -H "Authorization: Bearer $BS" -H 'Content-Type: application/json' \
   -d "{\"op\":\"crawl-db\",\"payload\":{\"table\":\"retailer_crawl_queue\",\"chain\":[[\"select\",[\"url\",{\"count\":\"exact\",\"head\":true}]],[\"eq\",[\"supermarket\",\"$s\"]]]}}" \
   https://project--6bb7450b-5865-4df2-bbb5-6f4045dd928f.lovable.app/api/public/admin/rpc | grep -o '"count":[0-9null]*\|"error":"[^"]*"'
done
echo "== TAREAS PROGRAMADAS EN EL SERVIDOR"; systemctl list-timers --no-pager | grep -i cestalista | awk '{print $NF, $(NF-1)}'
echo "== DIA DIRECTO (sin ScraperAPI, 1 prueba)"
curl -s -m 8 -o /dev/null -w '   HTTP %{http_code} en %{time_total}s\n' -H 'Accept: application/json' -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36' -H 'Referer: https://www.dia.es/' 'https://www.dia.es/api/v1/search-back/search?q=leche&page=1'
for u in https://www.ahorramas.com/buscador?q=leche "https://www.hiperdino.es/c9495/catalogsearch/result/?q=leche" https://www.carrefour.es/supermercado/; do
  curl -s -m 8 -o /dev/null -w "   %{http_code} %{time_total}s $u\n" -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36' -H 'Accept-Language: es-ES' "$u"
done
IN
