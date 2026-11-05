#!/bin/bash
# Cloud Shell: ¿pueden el servidor (Madrid) entrar directo a cada web, sin ScraperAPI?
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
p() { # nombre url
  r=$(curl -s -m 20 -o /tmp/r.out -w '%{http_code}' -A "$UA" -H 'Accept-Language: es-ES,es;q=0.9' -H 'Accept: text/html,application/json,*/*' "$2")
  t=$(wc -c < /tmp/r.out); ok="NO"
  [ "$r" = "200" ] && [ "$t" -gt 2000 ] && ok="SI"
  printf "%-4s %-22s %s  %8s bytes\n" "$ok" "$1" "$r" "$t"
}
echo "¿Entra?  web                  código  tamaño"
p "Dia buscador"        "https://www.dia.es/api/v1/search-back/search?q=leche&page=1"
p "Dia portada"         "https://www.dia.es/"
p "Carrefour portada"   "https://www.carrefour.es/supermercado"
p "Carrefour sitemap"   "https://www.carrefour.es/crs/cdn-static/sitemap-food/index.xml"
p "Carrefour producto"  "https://www.carrefour.es/supermercado/leche-entera-carrefour-brik-1-l/R-521006125/p"
p "Caprabo portada"     "https://www.capraboacasa.com/"
p "Caprabo robots"      "https://www.capraboacasa.com/robots.txt"
p "Gadis portada"       "https://www.gadisline.com/"
p "Ahorramas buscador"  "https://www.ahorramas.com/buscador?q=leche"
p "HiperDino buscador"  "https://www.hiperdino.es/catalogsearch/result/?q=leche"
p "Froiz portada"       "https://supermercado.froiz.com/"
p "Alcampo buscador"    "https://www.compraonline.alcampo.es/search?q=leche"
IN
