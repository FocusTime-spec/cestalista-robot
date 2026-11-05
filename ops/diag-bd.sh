#!/bin/bash
# Cloud Shell: ¿el servidor puede leer/escribir en la base de datos? (sin mostrar claves)
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
cd /srv/cestalista/app
cat > /tmp/diag.mjs <<'JS'
const u = process.env.SUPABASE_URL || "", k = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const tipo = k.startsWith("sb_secret_") ? "sb_secret" : k.startsWith("eyJ") ? "jwt" : k ? `otro(${k.slice(0,3)}…)` : "VACÍA";
console.log("SUPABASE_URL:", u ? u.replace(/^https:\/\/([a-z0-9]{4}).*/, "https://$1…") : "VACÍA", "| clave servicio:", tipo, "largo", k.length);
const h = { apikey: k }; // claves nuevas sb_secret_: solo en "apikey"
for (const t of ["retailer_crawl_queue", "retailer_catalog"]) {
  const r = await fetch(`${u}/rest/v1/${t}?select=id&limit=1`, { headers: { ...h, Prefer: "count=exact" } });
  console.log(t, "->", r.status, r.headers.get("content-range"), (await r.text()).slice(0, 160));
}
// Lo mismo que hace la app (cliente oficial)
const { createRequire } = await import("node:module");
const { createClient } = createRequire("/srv/cestalista/app/package.json")("@supabase/supabase-js");
const db = createClient(u, k, { auth: { persistSession: false }, global: { fetch: (i, init) => { const hh = new Headers(init?.headers); if (hh.get("Authorization") === `Bearer ${k}`) hh.delete("Authorization"); hh.set("apikey", k); return fetch(i, { ...init, headers: hh }); } } });
const q = await db.from("retailer_crawl_queue").select("id", { count: "exact", head: true });
console.log("cliente app -> count", q.count, "error", q.error ? JSON.stringify(q.error).slice(0, 200) : "ninguno");
JS
node --env-file=/srv/cestalista/.env /tmp/diag.mjs
grep -o '^[A-Z_]*SUPABASE[A-Z_]*=' /srv/cestalista/.env | tr '\n' ' '; echo
IN
