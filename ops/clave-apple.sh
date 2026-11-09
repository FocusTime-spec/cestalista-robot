#!/bin/bash
# Cloud Shell: pone la contraseña de la cuenta de pruebas de Apple
# (contacto@cestalista.com). La contraseña se escribe aquí, oculta.
IP=$(cat ~/.cestalista-ip)
echo ""
echo "Escribe la contraseña nueva para contacto@cestalista.com"
echo "(mínimo 8 caracteres; no se verá mientras escribes) y pulsa Enter:"
read -rs PW </dev/tty
echo ""
echo "Repítela y pulsa Enter:"
read -rs PW2 </dev/tty
echo ""
[ "$PW" != "$PW2" ] && { echo "No coinciden. Vuelve a pegar la orden."; exit 1; }
[ ${#PW} -lt 8 ] && { echo "Demasiado corta (mínimo 8). Vuelve a pegar la orden."; exit 1; }
B64=$(printf '%s' "$PW" | base64 -w0)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" "B64=$B64 bash -s" <<'IN'
BS=$(grep '^ADMIN_BRIDGE_SECRET=' /srv/cestalista/.env | head -1 | cut -d= -f2- | tr -d '"'"'"'\r')
PW=$(printf '%s' "$B64" | base64 -d)
BODY=$(python3 -c 'import json,sys; print(json.dumps({"op":"review-account-password","payload":{"password":sys.argv[1]}}))' "$PW")
R=$(curl -s -m 40 -X POST -H "Authorization: Bearer $BS" -H 'Content-Type: application/json' -d "$BODY" https://project--6bb7450b-5865-4df2-bbb5-6f4045dd928f.lovable.app/api/public/admin/rpc)
case "$R" in
  *password_updated*) echo "✅ Contraseña cambiada. Ya puedes entrar con contacto@cestalista.com";;
  *account_created*)  echo "✅ La cuenta no existía: creada y lista. Entra con contacto@cestalista.com";;
  *unknown*)          echo "⏳ Lovable aún no tiene el cambio. Pulsa Publish → Update en Lovable y repite.";;
  *)                  echo "❌ Algo ha fallado: $(echo "$R" | cut -c1-200)";;
esac
IN
