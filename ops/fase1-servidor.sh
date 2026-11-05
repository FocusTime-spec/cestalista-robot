#!/bin/bash
# Cloud Shell. Fase 1 (antes de cambiar el dominio):
#  - actualizaciones sin cortes (releases + cambio de golpe)
#  - ScraperAPI solo para Carrefour, Dia e HiperDino; tope diario para el robot de Carrefour
#  - robot de Carrefour encendido (además de Gadis y Caprabo)
SHA="${SHA:-main}"
BASE="https://raw.githubusercontent.com/FocusTime-spec/cestalista-robot/$SHA/ops"
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" "BASE=$BASE bash -s" <<'IN'
set -e
D=/srv/cestalista
echo "[1/4] Ajustes..."
setv() { grep -q "^$1=" $D/.env && sed -i "s|^$1=.*|$1=$2|" $D/.env || echo "$1=$2" >> $D/.env; }
setv SCRAPERAPI_OFF 1
setv SCRAPERAPI_ALLOW_HOSTS carrefour.es,dia.es,hiperdino.es
setv SCRAPERAPI_DAILY_CREDITS 1000
setv SCRAPERAPI_COUNTER_FILE $D/scraperapi.json
setv CRAWL_DB_BRIDGE 1
curl -fsSL "$BASE/servidor-app.sh" -o $D/servidor-app.sh
sed -i 's/for s in gadis caprabo; do/for s in gadis caprabo carrefour; do/' $D/robot.sh
echo "[2/4] Construyendo la versión nueva (unos minutos)..."
cd $D/app && git fetch -q origin main && git reset -q --hard origin/main
bash $D/servidor-app.sh | tail -8
echo "[3/4] Pasada de robots (Gadis, Caprabo, Carrefour)..."
bash $D/robot.sh
echo "[4/4] Créditos de ScraperAPI gastados hoy en el servidor: $(cat $D/scraperapi.json 2>/dev/null || echo 0)"
IN
