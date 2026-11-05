#!/bin/bash
# Cloud Shell: ¿qué pasa con Dia en el servidor?
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
echo "Ajustes: $(grep -o '^SCRAPERAPI_[A-Z_]*=' $D/.env | tr '\n' ' ')"
echo "Clave ScraperAPI: $(grep -q '^SCRAPERAPI_KEY=.\{8,\}' $D/.env && echo 'está' || echo 'NO está')"
echo "Créditos hoy: $(cat $D/scraperapi.json 2>/dev/null)"
for s in dia hiperdino ahorramas; do
  printf "%-10s " "$s:"
  curl -s -m 90 -w ' [%{http_code}, %{time_total}s]' "http://127.0.0.1:3000/api/public/$s?q=leche%20$RANDOM&limit=3" | tr -d '\n' | cut -c1-330; echo
done
echo "Errores recientes de Dia:"
sudo journalctl -u cestalista --since "-30 min" --no-pager -o cat | grep -i "dia" | grep -iv "diario\|media\|immedia" | tail -6 | cut -c1-250
IN
