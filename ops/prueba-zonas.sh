#!/bin/bash
# Cloud Shell: desde el servidor, pregunta a Mercadona la zona de precios de
# varios códigos postales y comprueba que el catálogo de cada zona existe.
IP=$(cat ~/.cestalista-ip)
ssh -n -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
echo "CP     provincia     zona  catálogo  leche 1L (precio)"
for par in 28001:Madrid 08001:Barcelona 46001:Valencia 41001:Sevilla 03001:Alicante 15001:Coruña 33001:Asturias 30001:Murcia 48001:Bizkaia 50001:Zaragoza 35001:LasPalmas 07001:Baleares 47001:Valladolid 18001:Granada; do
  cp=${par%%:*}; pr=${par#*:}
  wh=$(curl -s -m 10 -D - -o /dev/null -X PUT -H 'Content-Type: application/json' \
    -d "{\"new_postal_code\":\"$cp\"}" https://tienda.mercadona.es/api/postal-codes/actions/change-pc/ \
    | awk -F': ' 'tolower($1)=="x-customer-wh"{print $2}' | tr -d '\r')
  r=$(curl -s -m 10 -w '\n%{http_code}' -X POST \
    "https://7uzjkl1dj0-dsn.algolia.net/1/indexes/products_prod_${wh:-mad1}_es/query?x-algolia-application-id=7UZJKL1DJ0&x-algolia-api-key=9d8f2e39e90df472b4f2e559a116fe17" \
    -d '{"params":"query=leche%20entera&hitsPerPage=1"}')
  code=$(echo "$r" | tail -1)
  precio=$(echo "$r" | head -1 | grep -o '"unit_price":"[0-9.]*"' | head -1 | cut -d'"' -f4)
  printf "%s  %-12s  %-5s %-8s  %s\n" "$cp" "$pr" "${wh:-??}" "$code" "${precio:--}"
done
echo ""
echo "App del servidor (versión nueva):"
curl -s -m 20 "http://127.0.0.1:3000/api/public/mercadona-zona?cp=15001"; echo
tail -3 /srv/cestalista/actualizar.log 2>/dev/null
IN
