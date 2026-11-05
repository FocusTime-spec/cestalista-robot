#!/bin/bash
# Cloud Shell: ¿el servidor puede leer/escribir en la base de datos? (sin mostrar claves)
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
cd /srv/cestalista/app
cat > /tmp/diag.mjs <<'JS'
const u = process.env.SUPABASE_URL || "", k = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const tipo = k.startsWith("sb_secret_") ? "sb_secret" : k.startsWith("eyJ") ? "jwt" : k ? `otro(${k.slice(0,3)}…)` : "VACÍA";
console.log("SUPABASE_URL:", u ? u.replace(/^https:\/\/([a-z0-9]{4}).*/, "https://$1…") : "VACÍA", "| clave servicio:", tipo, "largo", k.length);
const h = { apikey: k, Authorization: `Bearer ${k}` };
for (const t of ["retailer_crawl_queue", "retailer_catalog"]) {
  const r = await fetch(`${u}/rest/v1/${t}?select=id&limit=1`, { headers: { ...h, Prefer: "count=exact" } });
  console.log(t, "->", r.status, r.headers.get("content-range"), (await r.text()).slice(0, 160));
}
JS
node --env-file=/srv/cestalista/.env /tmp/diag.mjs
grep -o '^[A-Z_]*SUPABASE[A-Z_]*=' /srv/cestalista/.env | tr '\n' ' '; echo
IN
