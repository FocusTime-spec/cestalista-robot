// Dentro del servidor: descifra la respuesta de /api/public/env-export con la llave privada del servidor.
// Uso: node descifrar.js envkey.json respuesta.json  -> imprime JSON {NOMBRE: valor}
const c = require("crypto"), fs = require("fs");
const { pub, prv } = JSON.parse(fs.readFileSync(process.argv[2]));
const r = JSON.parse(fs.readFileSync(process.argv[3]));
const spk = Buffer.from(pub, "base64"), epk = Buffer.from(r.epk, "base64");
const ephKey = c.createPublicKey({ key: Buffer.concat([Buffer.from("302a300506032b656e032100", "hex"), epk]), format: "der", type: "spki" });
const shared = c.diffieHellman({ privateKey: c.createPrivateKey(prv), publicKey: ephKey });
const key = Buffer.from(c.hkdfSync("sha256", shared, Buffer.concat([epk, spk]), "cestalista-env", 32));
const d = c.createDecipheriv("aes-256-gcm", key, Buffer.from(r.iv, "base64"));
d.setAuthTag(Buffer.from(r.tag, "base64"));
process.stdout.write(Buffer.concat([d.update(Buffer.from(r.ct, "base64")), d.final()]).toString());
