#!/bin/bash
# Crea el servidor nuevo de CestaLista desde la Cloud Shell de Oracle (Always Free).
# - Crea una llave SSH propia en ~/.ssh/cestalista (se queda guardada en la Cloud Shell).
# - Crea "cestalista-servidor" con 3 OCPU / 18 GB (junto al viejo de 1/6 suman 4/24: gratis).
# - No toca el servidor viejo. Si ya existe uno con ese nombre, no crea otro.
set -euo pipefail
NAME="cestalista-servidor"; OCPUS="${OCPUS:-3}"; MEM="${MEM:-18}"
T="${OCI_TENANCY:?No encuentro OCI_TENANCY: abre esto dentro de la Cloud Shell de Oracle}"
echo "1/5 Llave SSH..."
mkdir -p ~/.ssh && chmod 700 ~/.ssh
[ -f ~/.ssh/cestalista ] || ssh-keygen -t rsa -b 4096 -N "" -C cestalista-cloudshell -f ~/.ssh/cestalista -q
echo "   OK (~/.ssh/cestalista)"
echo "2/5 Compruebo que no exista ya..."
YA=$(oci compute instance list -c "$T" --display-name "$NAME" --query "data[?\"lifecycle-state\"!='TERMINATED'] | length(@)" --raw-output 2>/dev/null || echo 0)
if [ "${YA:-0}" != "0" ]; then echo "   Ya existe $NAME. No creo otro."; else
echo "3/5 Busco red, imagen y zona..."
SUBNET=$(oci network subnet list -c "$T" --display-name "public subnet-cestalista-red" --query "data[0].id" --raw-output)
IMAGE=$(oci compute image list -c "$T" --operating-system "Canonical Ubuntu" --operating-system-version "24.04" --shape VM.Standard.A1.Flex --sort-by TIMECREATED --sort-order DESC --query "data[?!contains(\"display-name\",'Minimal')] | [0].id" --raw-output)
AD=$(oci compute instance list -c "$T" --display-name cestalista-server --query "data[0].\"availability-domain\"" --raw-output)
[ -n "$AD" ] && [ "$AD" != "null" ] || AD=$(oci iam availability-domain list -c "$T" --query "data[0].name" --raw-output)
echo "   red=${SUBNET:0:30}... imagen=${IMAGE:0:30}... zona=$AD"
echo "4/5 Creo $NAME ($OCPUS OCPU / $MEM GB, Always Free)..."
oci compute instance launch -c "$T" --availability-domain "$AD" --display-name "$NAME" \
  --shape VM.Standard.A1.Flex --shape-config "{\"ocpus\":$OCPUS,\"memoryInGBs\":$MEM}" \
  --image-id "$IMAGE" --subnet-id "$SUBNET" --assign-public-ip true \
  --ssh-authorized-keys-file ~/.ssh/cestalista.pub \
  --wait-for-state RUNNING --max-wait-seconds 900 --query "data.id" --raw-output > /tmp/cl-id || { echo "   ERROR al crear (manda captura a Claude)"; exit 1; }
fi
echo "5/5 Dirección del servidor..."
ID=$(oci compute instance list -c "$T" --display-name "$NAME" --query "data[?\"lifecycle-state\"=='RUNNING'] | [0].id" --raw-output)
IP=$(oci compute instance list-vnics --instance-id "$ID" --query "data[0].\"public-ip\"" --raw-output)
echo "$IP" > ~/.cestalista-ip
echo ""
echo "======================================"
echo " LISTO: $NAME en $IP"
echo "======================================"
