#!/bin/bash
# Cloud Shell: ¿cómo responde Dia a través de ScraperAPI? (gasta ~12 créditos)
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
K=$(grep '^SCRAPERAPI_KEY=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
BS=$(grep '^ADMIN_BRIDGE_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
U=$(python3 -c 'import urllib.parse;print(urllib.parse.quote("https://www.dia.es/api/v1/search-back/search?q=yogur&page=1",safe=""))')
t() { printf "%-10s " "$1"; curl -s -m 70 -o /tmp/d.out -w '[%{http_code}, %{time_total}s] ' "https://api.scraperapi.com/?api_key=$K&url=$U$2"; head -c 140 /tmp/d.out | tr -d '\n'; echo; }
echo "== Dia por ScraperAPI =="
t normal ""
t normal2 ""
t premium "&premium=true"
echo ""
echo "== Últimos registros de Dia guardados (cuando funcionaba en Lovable) =="
curl -s -m 30 -X POST -H "Authorization: Bearer $BS" -H 'Content-Type: application/json' \
 -d '{"op":"crawl-db","payload":{"table":"scraper_logs","chain":[["select",["created_at,status,results_count,duration_ms,error_message"]],["eq",["supermarket","Dia"]],["order",["created_at",{"ascending":false}]],["limit",[6]]]}}' \
 https://project--6bb7450b-5865-4df2-bbb5-6f4045dd928f.lovable.app/api/public/admin/rpc | python3 -c 'import sys,json
d=json.load(sys.stdin).get("data",{}).get("data") or []
for r in d: print(" ",r["created_at"][:16],r["status"],r.get("results_count"),r.get("duration_ms"),(r.get("error_message") or "")[:90])'
IN
