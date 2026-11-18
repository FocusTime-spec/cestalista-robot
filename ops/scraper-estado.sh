#!/bin/bash
# Cloud Shell: cómo van los créditos de ScraperAPI (lo que dice la propia
# ScraperAPI) y lo que ha gastado hoy el servidor. No muestra la clave.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
K=$(grep '^SCRAPERAPI_KEY=' $D/.env | cut -d= -f2- | tr -d '"'"'"' \r')
echo "=== Cuenta de ScraperAPI ==="
if [ -z "$K" ]; then echo "No hay clave de ScraperAPI en el servidor"; else
  J=$(curl -s -m 20 "https://api.scraperapi.com/account?api_key=$K")
  python3 - "$J" <<'PY'
import json,sys
try: d=json.loads(sys.argv[1])
except Exception: print("Respuesta rara de ScraperAPI:", sys.argv[1][:200]); sys.exit()
u=d.get("requestCount"); l=d.get("requestLimit")
print(f"Gastados: {u} de {l}" + (f"  ({u*100//l} %)" if u is not None and l else ""))
for k in ("subscriptionDate","concurrentRequests","concurrencyLimit","failedRequestCount"):
    if k in d: print(f"{k}: {d[k]}")
PY
fi
echo ""
echo "=== Ajustes del servidor ==="
grep -E '^SCRAPERAPI_(OFF|ALLOW_HOSTS|DAILY_CREDITS|RESERVE_ROBOT|COUNTER_FILE)=' $D/.env
F=$(grep '^SCRAPERAPI_COUNTER_FILE=' $D/.env | cut -d= -f2-)
[ -n "$F" ] && [ -f "$F" ] && echo "Contador de hoy: $(cat "$F")"
echo ""
echo "=== Errores de ScraperAPI en las últimas 24 h ==="
sudo journalctl -u cestalista --since "24 hours ago" --no-pager 2>/dev/null | grep -iE "scraperapi|403|429|credits" | tail -8
echo "--- fin ---"
IN
