#!/bin/bash
# Cloud Shell: ¿pasan por el servidor los correos de cuentas (confirmación, contraseña)?
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
echo "== Llamadas al webhook de correos de cuentas (últimos 7 días):"
sudo grep -h '"/lovable/email' /var/log/caddy/access.log* 2>/dev/null | grep -o '"ts":[0-9.]*\|"uri":"[^"]*"\|"status":[0-9]*' | paste - - - | tail -10
echo "== Mensajes de la app sobre correos (24 h):"
sudo journalctl -u cestalista --since "-24h" --no-pager -o cat | grep -i "AUTH-EMAIL\|email" | tail -12 | cut -c1-230
echo "== Claves presentes en el servidor:"
for k in LOVABLE_API_KEY SUPABASE_SERVICE_ROLE_KEY SUPABASE_URL; do grep -q "^$k=." /srv/cestalista/.env && echo "   $k: sí" || echo "   $k: NO"; done
IN
