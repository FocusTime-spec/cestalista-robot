#!/bin/bash
# Se ejecuta DENTRO del servidor (como root). Prepara lo básico, sin secretos:
# actualizaciones, memoria extra (swap), Node 22, git, protección contra ataques
# y una llave de solo lectura para que el servidor pueda descargar el código de GitHub.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "[1/6] Actualizando el sistema (tarda unos minutos)..."
apt-get update -qq && apt-get -y -qq -o Dpkg::Options::=--force-confold upgrade >/dev/null
echo "[2/6] Instalando herramientas..."
apt-get -y -qq install git curl ca-certificates fail2ban unattended-upgrades jq >/dev/null
systemctl enable --now fail2ban >/dev/null 2>&1 || true
echo "[3/6] Memoria extra (swap 4 GB)..."
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q /swapfile /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
fi
echo "[4/6] Instalando Node 22..."
if ! node -v 2>/dev/null | grep -q '^v22'; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null 2>&1
  apt-get -y -qq install nodejs >/dev/null
fi
echo "   Node $(node -v), npm $(npm -v)"
echo "[5/6] Carpeta de la web..."
mkdir -p /srv/cestalista && chown ubuntu:ubuntu /srv/cestalista
echo "[6/6] Llave de solo lectura para GitHub..."
sudo -u ubuntu bash -c '
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  [ -f ~/.ssh/github_deploy ] || ssh-keygen -t ed25519 -N "" -C cestalista-servidor-github -f ~/.ssh/github_deploy -q
  grep -q "Host github.com" ~/.ssh/config 2>/dev/null || printf "Host github.com\n  IdentityFile ~/.ssh/github_deploy\n  IdentitiesOnly yes\n  StrictHostKeyChecking accept-new\n" >> ~/.ssh/config
  chmod 600 ~/.ssh/config'
echo ""
echo "=================================================================="
echo " SERVIDOR PREPARADO. Esta es la LLAVE PÚBLICA para GitHub"
echo " (no es secreta; cópiala entera, desde ssh-ed25519 hasta el final):"
echo ""
cat /home/ubuntu/.ssh/github_deploy.pub
echo ""
echo "=================================================================="
