#!/bin/bash
# Cloud Shell: usa los créditos de ScraperAPI que ya se pagan (plan Hobby, 100.000/mes):
# tope diario 3.000 (≈93.000/mes) y 1.000 reservados cada día para el robot de Carrefour.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
D=/srv/cestalista
sed -i '/^SCRAPERAPI_DAILY_CREDITS=/d;/^SCRAPERAPI_RESERVE_ROBOT=/d' $D/.env
echo 'SCRAPERAPI_DAILY_CREDITS=3000' >> $D/.env
echo 'SCRAPERAPI_RESERVE_ROBOT=1000' >> $D/.env
bash $D/actualizar.sh | tail -1; sudo systemctl restart cestalista; sleep 8
echo "Webs con ScraperAPI: $(grep '^SCRAPERAPI_ALLOW_HOSTS=' $D/.env | cut -d= -f2)"
echo "Tope diario: $(grep '^SCRAPERAPI_DAILY_CREDITS=' $D/.env | cut -d= -f2) · reserva robot: $(grep '^SCRAPERAPI_RESERVE_ROBOT=' $D/.env | cut -d= -f2)"
echo "Gastado hoy: $(cat $D/scraperapi.json)"
echo "Probando el robot de Carrefour..."
bash $D/robot.sh | grep carrefour | cut -c1-220
echo "LISTO"
IN
