#!/bin/bash
# Cloud Shell: pone en el servidor la clave de notificaciones de Apple (.p8)
# para que lleguen los avisos a la app de iPhone. Antes hay que subir el
# archivo AuthKey_XXXXXXXXXX.p8 a Cloud Shell (menú ⚙ / ⋮ → Upload).
# La clave nunca se pega en el chat.
IP=$(cat ~/.cestalista-ip)
F=$(ls -t ~/AuthKey_*.p8 2>/dev/null | head -1)
if [ -z "$F" ]; then
  echo "❌ No encuentro el archivo AuthKey_....p8 en Cloud Shell."
  echo "   Súbelo con el menú de Cloud Shell → Upload y vuelve a pegar la orden."
  exit 1
fi
grep -q "BEGIN PRIVATE KEY" "$F" || { echo "❌ $F no parece una clave de Apple (.p8). Revisa el archivo."; exit 1; }
KID=$(basename "$F" .p8 | sed 's/^AuthKey_//')
echo ""
echo "Archivo encontrado: $(basename "$F")  →  Key ID: $KID"
echo ""
echo "Escribe tu Team ID de Apple (10 letras/números, sale arriba a la derecha"
echo "en developer.apple.com → Account → Membership details) y pulsa Enter:"
read -r TEAM </dev/tty
TEAM=$(printf '%s' "$TEAM" | tr -d ' \r\n' | tr 'a-z' 'A-Z')
[[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]] || { echo "❌ El Team ID tiene que ser de 10 caracteres. Vuelve a pegar la orden."; exit 1; }
B64=$(base64 -w0 "$F")
ssh -i ~/.ssh/cestalista ubuntu@"$IP" "KID=$KID TEAM=$TEAM B64=$B64 bash -s" <<'IN'
ENVF=/srv/cestalista/.env
sudo sed -i '/^APNS_KEY_ID=/d;/^APNS_TEAM_ID=/d;/^APNS_KEY_B64=/d' "$ENVF"
printf 'APNS_KEY_ID=%s\nAPNS_TEAM_ID=%s\nAPNS_KEY_B64=%s\n' "$KID" "$TEAM" "$B64" | sudo tee -a "$ENVF" >/dev/null
sudo systemctl restart cestalista
sleep 6
systemctl is-active -q cestalista && echo "✅ Clave de Apple guardada en el servidor y app reiniciada. Los avisos ya pueden salir hacia iPhone." || echo "❌ La app no ha arrancado bien. Manda captura a Claude."
IN
