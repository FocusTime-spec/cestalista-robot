#!/bin/bash
# Cloud Shell: salud del servidor + prueba real de cada supermercado (solo lee, no cambia nada).
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
echo "== SERVIDOR"
echo "   App: $(systemctl is-active cestalista) · versión $(readlink -f $D/current | xargs basename) · en marcha desde $(systemctl show cestalista -p ActiveEnterTimestamp --value | cut -c5-20)"
echo "   Encendido: $(uptime -p) · carga: $(cut -d' ' -f1-3 /proc/loadavg)"
free -m | awk '/Mem/{printf "   Memoria: %d de %d MB usados\n",$3,$2}'
df -h / | awk 'NR==2{print "   Disco: "$3" de "$2" usados ("$5")"}'
echo "   Última actualización: $(tail -1 $D/actualizar.log 2>/dev/null | cut -c1-150)"
echo "   Créditos ScraperAPI hoy: $(cat $D/scraperapi.json 2>/dev/null)"
echo "== RESPUESTA DE CADA SUPERMERCADO (productos encontrados · segundos)"
for s in mercadona dia alcampo consum ahorramas bm masymas hiperdino carrefour caprabo gadis froiz; do
  line="   $(printf '%-10s' $s)"
  for q in leche huevos tomate; do
    r=$(curl -s -m 40 -w '\n%{http_code} %{time_total}' "http://127.0.0.1:3000/api/public/$s?q=$q&limit=20")
    code=$(echo "$r" | tail -1 | cut -d' ' -f1); t=$(echo "$r" | tail -1 | cut -d' ' -f2 | cut -c1-4)
    n=$(echo "$r" | head -n -1 | python3 -c 'import sys,json
try:
  d=json.load(sys.stdin); r=d.get("results") or []; print(len(r), ("viejo" if d.get("stale") else ""), (str(d.get("error"))[:60] if d.get("error") else ""))
except Exception as e: print("?")' 2>/dev/null)
    line="$line | $q: $n ($code, ${t}s)"
  done
  echo "$line"
done
echo "== ERRORES DE LA APP EN 24 H"
sudo journalctl -u cestalista --since "-24h" --no-pager -o cat | grep -iE "error|fail" | grep -v "aborted\|ECONNRESET\|swallowed SSR" | sed 's/[0-9a-f]\{8\}-[0-9a-f-]\{27\}//g' | cut -c1-160 | sort | uniq -c | sort -rn | head -12
IN
