#!/bin/bash
# Paso 2: comprobar que entramos al servidor nuevo, borrar el viejo y subir el nuevo a 4 OCPU / 24 GB (gratis).
set -uo pipefail
T="${OCI_TENANCY:?Abre esto dentro de la Cloud Shell de Oracle}"
IP=$(cat ~/.cestalista-ip)
echo "1/3 Pruebo a entrar en el servidor nuevo ($IP)..."
for i in 1 2 3 4 5 6; do
  if ssh -i ~/.ssh/cestalista -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 ubuntu@"$IP" 'echo "   Dentro: $(hostname), $(nproc) procesadores, $(free -g | awk "/Mem/{print \$2}") GB"'; then OK=1; break; fi
  echo "   Aún arrancando, espero 20 s..."; sleep 20
done
[ "${OK:-0}" = 1 ] || { echo "   NO puedo entrar todavía. No borro nada. Manda captura a Claude."; exit 1; }
echo "2/3 Borro el servidor viejo (cestalista-server)..."
OLD=$(oci compute instance list -c "$T" --display-name cestalista-server --query "data[?\"lifecycle-state\"!='TERMINATED'] | [0].id" --raw-output)
if [ -n "$OLD" ] && [ "$OLD" != "null" ]; then
  oci compute instance terminate --instance-id "$OLD" --preserve-boot-volume false --force --wait-for-state TERMINATED --max-wait-seconds 900 >/dev/null && echo "   Borrado." || { echo "   ERROR al borrar. Manda captura a Claude."; exit 1; }
else echo "   Ya no existía."; fi
echo "3/3 Subo el servidor nuevo a 4 OCPU / 24 GB (gratis; se reinicia 1-2 min)..."
NEW=$(oci compute instance list -c "$T" --display-name cestalista-servidor --query "data[?\"lifecycle-state\"=='RUNNING'] | [0].id" --raw-output)
oci compute instance update --instance-id "$NEW" --shape-config '{"ocpus":4,"memoryInGBs":24}' --force --wait-for-state RUNNING --max-wait-seconds 900 >/dev/null \
  && echo "   Hecho." || echo "   No se pudo ampliar ahora (no pasa nada, sigue con 3/18). Manda captura a Claude."
echo ""
echo "======================================"
echo " PASO 2 TERMINADO"
echo "======================================"
