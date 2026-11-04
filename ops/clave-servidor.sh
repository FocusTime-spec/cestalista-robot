#!/bin/bash
# Dentro del servidor: crea (una sola vez) un par de llaves X25519 para recibir
# las claves de Vercel cifradas. Enseña SOLO la parte pública (no es secreta).
set -euo pipefail
K=/srv/cestalista/envkey.json
if [ ! -f "$K" ]; then
  node -e '
    const c=require("crypto"); const {publicKey,privateKey}=c.generateKeyPairSync("x25519");
    const pub=publicKey.export({format:"der",type:"spki"}).subarray(-32).toString("base64");
    const prv=privateKey.export({format:"pem",type:"pkcs8"});
    require("fs").writeFileSync(process.argv[1], JSON.stringify({pub,prv}), {mode:0o600});' "$K"
fi
echo ""
echo "LLAVE PUBLICA DEL SERVIDOR (no es secreta, cópiala y pégasela a Claude):"
node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1])).pub)' "$K"
