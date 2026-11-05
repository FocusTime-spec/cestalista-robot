#!/bin/bash
# Cloud Shell. Fase 2 (DESPUÉS de cambiar cestalista.com en Porkbun):
# el servidor atiende cestalista.com y www.cestalista.com con candado.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
MIA=$(curl -s --max-time 10 https://api.ipify.org)
echo "[1/3] Comprobando que cestalista.com ya apunta aquí ($MIA)..."
for i in $(seq 1 40); do
  A=$(getent ahostsv4 cestalista.com | awk 'NR==1{print $1}'); W=$(getent ahostsv4 www.cestalista.com | awk 'NR==1{print $1}')
  [ "$A" = "$MIA" ] && [ "$W" = "$MIA" ] && break
  sleep 15
done
if [ "$A" != "$MIA" ] || [ "$W" != "$MIA" ]; then
  echo "   Todavía no: cestalista.com -> ${A:-nada}, www -> ${W:-nada}. Revisa Porkbun y repite en 10 minutos."; exit 1
fi
echo "   OK"
echo "[2/3] Candado para cestalista.com y www..."
sudo tee /etc/caddy/Caddyfile >/dev/null <<'CF'
(cestalista) {
	encode zstd gzip
	header {
		X-Content-Type-Options "nosniff"
		Referrer-Policy "strict-origin-when-cross-origin"
		Permissions-Policy "camera=(), microphone=(), geolocation=(self)"
		Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
		X-Frame-Options "DENY"
		Content-Security-Policy "frame-ancestors 'none'"
		-Server
	}
	reverse_proxy 127.0.0.1:3000
}
cestalista.com, www.cestalista.com, servidor.cestalista.com {
	import cestalista
}
CF
sudo systemctl reload caddy || sudo systemctl restart caddy
echo "[3/3] Comprobando..."
for i in $(seq 1 20); do
  C1=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 https://cestalista.com/proximamente)
  C2=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 https://www.cestalista.com/proximamente)
  [ "$C1" = "200" ] && [ "$C2" = "200" ] && break
  sleep 6
done
echo "   https://cestalista.com -> $C1   https://www.cestalista.com -> $C2"
[ "$C1" = "200" ] && [ "$C2" = "200" ] && echo "" && echo "=== CESTALISTA.COM YA VA POR EL SERVIDOR ===" || { echo "Algo falla: manda captura."; sudo journalctl -u caddy -n 6 --no-pager | cut -c1-220; }
IN
