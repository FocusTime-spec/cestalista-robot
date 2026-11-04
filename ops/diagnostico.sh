#!/bin/bash
# Dentro del servidor: muestra qué claves hay (solo SI/VACÍA, nunca su valor) y el error de la API.
ENVF=/srv/cestalista/.env
echo "== Claves en el servidor =="
while IFS= read -r line; do
  k="${line%%=*}"; v="${line#*=}"; v="${v%\"}"; v="${v#\"}"
  [ -n "$v" ] && printf "  %-34s SI (%s caracteres)\n" "$k" "${#v}" || printf "  %-34s VACIA\n" "$k"
done < <(grep -E '^[A-Z]' "$ENVF")
echo "== Respuesta de /api/public/recipes =="
curl -s --max-time 30 http://127.0.0.1:3000/api/public/recipes | head -c 300; echo
echo "== Últimos mensajes de la app =="
sudo journalctl -u cestalista -n 15 --no-pager | cut -c1-200
