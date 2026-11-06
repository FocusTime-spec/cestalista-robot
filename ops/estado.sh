#!/bin/bash
# Cloud Shell: estado general del servidor (robots, créditos, tareas automáticas).
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
BS=$(grep '^ADMIN_BRIDGE_SECRET=' $D/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
q() { curl -s -m 30 -X POST -H "Authorization: Bearer $BS" -H 'Content-Type: application/json' -d "$1" https://project--6bb7450b-5865-4df2-bbb5-6f4045dd928f.lovable.app/api/public/admin/rpc; }
echo "== App: $(systemctl is-active cestalista) · versión $(readlink -f $D/current | xargs basename) · encendido desde $(systemctl show cestalista -p ActiveEnterTimestamp --value | cut -c5-20)"
echo "== Productos guardados por los robots (últimas 24 h):"
python3 - <<'PY'
import re, datetime, json
tot={}; n={}
lim=(datetime.datetime.utcnow()-datetime.timedelta(hours=24)).strftime('%Y-%m-%d %H:%M')
for l in open('/srv/cestalista/robot.log'):
    m=re.match(r'(\S+ \S+) (\w+) (.*)',l)
    if not m or m.group(1)<lim: continue
    s=m.group(2); g=re.search(r'"productsSaved":(\d+)',m.group(3))
    n[s]=n.get(s,0)+1
    if g: tot[s]=tot.get(s,0)+int(g.group(1))
    elif 'skipped' in m.group(3): tot.setdefault(s,0)
for s in sorted(n): print(f"   {s:10} {tot.get(s,0):6} productos en {n[s]} pasadas")
PY
echo "== Catálogo guardado en total:"
for s in Gadis Caprabo Carrefour; do
  printf "   %-10s " "$s"; q "{\"op\":\"crawl-db\",\"payload\":{\"table\":\"retailer_catalog\",\"chain\":[[\"select\",[\"id\",{\"count\":\"exact\",\"head\":true}]],[\"eq\",[\"supermarket\",\"$s\"]]]}}" | grep -o '"count":[0-9]*' | cut -d: -f2
done
echo "== Créditos de ScraperAPI hoy (servidor): $(cat $D/scraperapi.json 2>/dev/null)"
echo "== Avisos push enviados por las tareas automáticas (ayer y hoy):"
q "{\"op\":\"crawl-db\",\"payload\":{\"table\":\"push_sent_log\",\"chain\":[[\"select\",[\"kind,sent_on\"]],[\"gte\",[\"sent_on\",\"$(date -u -d yesterday +%F)\"]],[\"limit\",[500]]]}}" | python3 -c 'import sys,json,collections
d=(json.load(sys.stdin).get("data") or {}).get("data") or []
c=collections.Counter((r["sent_on"],r["kind"]) for r in d)
print("\n".join(f"   {k[0]} {k[1]}: {v}" for k,v in sorted(c.items())) or "   ninguno (normal si no había nada que avisar)")'
echo "== Errores de la app en 24 h (sin contar conexiones cortadas):"
sudo journalctl -u cestalista --since "-24h" --no-pager -o cat | grep -i "error" | grep -v "aborted\|ECONNRESET\|swallowed SSR" | sort | uniq -c | sort -rn | head -6 | cut -c1-200
echo "== Llamadas a tareas automáticas (desde que se activa el registro):"
if ! grep -q "log {" /etc/caddy/Caddyfile; then
  sudo sed -i 's|\treverse_proxy 127.0.0.1:3000|\tlog {\n\t\toutput file /var/log/caddy/access.log {\n\t\t\troll_size 20mb\n\t\t\troll_keep 3\n\t\t}\n\t}\n\treverse_proxy 127.0.0.1:3000|' /etc/caddy/Caddyfile
  sudo mkdir -p /var/log/caddy && sudo chown caddy:caddy /var/log/caddy
  sudo systemctl reload caddy && echo "   (registro activado ahora; mañana ya habrá datos)"
else
  sudo grep -o '"uri":"/api/public/hooks/[a-z-]*","[^}]*' /var/log/caddy/access.log 2>/dev/null | grep -o 'hooks/[a-z-]*' | sort | uniq -c | sed 's/^/   /'
  echo "   respuestas: $(sudo grep '"/api/public/hooks/' /var/log/caddy/access.log 2>/dev/null | grep -o '"status":[0-9]*' | sort | uniq -c | tr '\n' ' ')"
fi
IN
