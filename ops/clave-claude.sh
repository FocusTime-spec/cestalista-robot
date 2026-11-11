#!/bin/bash
# Cloud Shell: pone la clave de la API de Claude (Anthropic) en el servidor,
# para calorías, pasos de recetas y funciones Pro. La clave se escribe aquí,
# oculta; nunca se pega en el chat.
IP=$(cat ~/.cestalista-ip)
echo ""
echo "Pega tu clave de la API de Claude (empieza por sk-ant-...)."
echo "No se verá mientras la pegas. Luego pulsa Enter:"
read -rs K </dev/tty
echo ""
K=$(printf '%s' "$K" | tr -d ' \r\n')
case "$K" in sk-ant-*) ;; *) echo "❌ Eso no parece una clave de Claude (debe empezar por sk-ant-). Vuelve a pegar la orden."; exit 1;; esac
B64=$(printf '%s' "$K" | base64 -w0)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" "B64=$B64 bash -s" <<'IN'
K=$(printf '%s' "$B64" | base64 -d)
C=$(curl -s -o /dev/null -w '%{http_code}' -m 30 https://api.anthropic.com/v1/models -H "x-api-key: $K" -H "anthropic-version: 2023-06-01")
if [ "$C" != "200" ]; then echo "❌ Anthropic no acepta la clave (código $C). Revisa que esté bien copiada y vuelve a pegar la orden."; exit 1; fi
ENVF=/srv/cestalista/.env
sudo sed -i '/^ANTHROPIC_API_KEY=/d' "$ENVF"
printf 'ANTHROPIC_API_KEY=%s\n' "$K" | sudo tee -a "$ENVF" >/dev/null
sudo systemctl restart cestalista
sleep 6
systemctl is-active -q cestalista && echo "✅ Clave guardada en el servidor y app reiniciada. Las funciones con IA ya usan tu Claude." || echo "❌ La app no ha arrancado bien. Manda captura a Claude."
IN
