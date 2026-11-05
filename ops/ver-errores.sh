#!/bin/bash
# Cloud Shell: enseña el contexto de los errores de la app (sin claves).
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
echo "== Errores (última hora), con 4 líneas de antes =="
sudo journalctl -u cestalista --since "-60 min" --no-pager -o cat | grep -v '^\s*at ' | grep -B4 -i "aborted\|swallowed" | tail -40 | cut -c1-230
echo ""
echo "== Cuántos 'swallowed SSR error' en las últimas 24 h: $(sudo journalctl -u cestalista --since '-24h' --no-pager | grep -c 'swallowed SSR')"
echo "== Primeras líneas de la pila del último error =="
sudo journalctl -u cestalista --since "-60 min" --no-pager -o cat | grep -A8 "Error: aborted" | tail -9 | cut -c1-200
IN
