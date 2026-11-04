#!/bin/bash
# Desde la Cloud Shell: entra al servidor y lo prepara (sin secretos).
set -uo pipefail
IP=$(cat ~/.cestalista-ip)
echo "Entrando en el servidor ($IP)... (unos 5 minutos)"
ssh -n -i ~/.ssh/cestalista -o StrictHostKeyChecking=accept-new ubuntu@"$IP" \
  'curl -fsSL https://raw.githubusercontent.com/FocusTime-spec/cestalista-robot/main/ops/servidor-base.sh | sudo bash'
