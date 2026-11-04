#!/bin/bash
# Dentro del servidor: pide a la app de Vercel las claves CIFRADAS para este servidor,
# las descifra aquí mismo y rehace el archivo de claves. Nunca se muestran.
set -euo pipefail
ENVF=/srv/cestalista/.env; K=/srv/cestalista/envkey.json; T=$(mktemp -d)
NAMES=$(grep -E '^[A-Z]' "$ENVF" | cut -d= -f1 | paste -sd, -)
echo "[1/3] Pidiendo las claves cifradas a Vercel..."
curl -fsS --max-time 60 "https://www.cestalista.com/api/public/env-export?names=$NAMES" -o "$T/r.json" || { echo "   ERROR: Vercel no responde (¿ya se publicó el cambio?)."; rm -rf "$T"; exit 1; }
echo "   Recibidas: $(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1])).n)' "$T/r.json") claves"
echo "[2/3] Descifrando..."
curl -fsSL https://raw.githubusercontent.com/FocusTime-spec/cestalista-robot/main/ops/descifrar.js -o "$T/d.js"
node "$T/d.js" "$K" "$T/r.json" > "$T/env.json"
node -e '
  const fs=require("fs"); const got=JSON.parse(fs.readFileSync(process.argv[1]));
  const lines=fs.readFileSync(process.argv[2],"utf8").split("\n").filter(l=>/^[A-Z]/.test(l));
  const out=[]; let rep=0, keep=0;
  for (const l of lines) { const k=l.split("=")[0];
    if (got[k]!=null && got[k]!=="") { out.push(k+"="+JSON.stringify(got[k])); rep++; } else { out.push(l); keep++; } }
  fs.writeFileSync(process.argv[2], out.join("\n")+"\n", {mode:0o600});
  console.log("   Claves reales puestas: "+rep+" | sin cambios: "+keep);' "$T/env.json" "$ENVF"
rm -rf "$T"
echo "[3/3] Reconstruyendo la app con las claves buenas..."
curl -fsSL https://raw.githubusercontent.com/FocusTime-spec/cestalista-robot/main/ops/servidor-app.sh | bash
