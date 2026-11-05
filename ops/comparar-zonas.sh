#!/bin/bash
# Cloud Shell: compara precios del MISMO producto de Mercadona entre zonas.
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' <<'IN'
cat > /tmp/zonas.js <<'JS'
const Z = { Madrid: "mad3", Coruna: "4804", Barcelona: "bcn1", Sevilla: "svq1", Baleares: "3842", LasPalmas: "4701" };
const Q = ["leche entera","huevos","aceite de oliva","platano","pechuga de pollo","arroz","pan de molde","tomate","yogur natural","atun en aceite","manzana","patatas","cafe molido","agua mineral","detergente","queso tierno","macarrones","cerveza","naranjas","salmon"];
const url = (wh) => `https://7uzjkl1dj0-dsn.algolia.net/1/indexes/products_prod_${wh}_es/query?x-algolia-application-id=7UZJKL1DJ0&x-algolia-api-key=9d8f2e39e90df472b4f2e559a116fe17`;
const buscar = async (wh, q) => { const r = await fetch(url(wh), { method: "POST", body: JSON.stringify({ params: `query=${encodeURIComponent(q)}&hitsPerPage=10` }) }); const d = await r.json(); const m = {}; for (const h of d.hits || []) m[h.id] = { n: h.display_name, p: parseFloat(h.price_instructions?.unit_price || "0") }; return m; };
(async () => {
  const dif = {}, tot = {};
  for (const q of Q) {
    const base = await buscar("mad3", q);
    for (const [zona, wh] of Object.entries(Z)) {
      if (zona === "Madrid") continue;
      const otra = await buscar(wh, q);
      for (const [id, b] of Object.entries(base)) {
        const o = otra[id]; if (!o || !b.p || !o.p) continue;
        tot[zona] = (tot[zona] || 0) + 1;
        if (Math.abs(o.p - b.p) > 0.001) { dif[zona] = dif[zona] || []; dif[zona].push(`${b.n.slice(0,28)}: ${b.p}€ -> ${o.p}€`); }
      }
    }
  }
  for (const zona of Object.keys(Z)) { if (zona === "Madrid") continue;
    const d = dif[zona] || []; console.log(`\n${zona}: ${d.length} de ${tot[zona] || 0} productos con precio distinto a Madrid`);
    d.slice(0, 4).forEach((x) => console.log("   " + x)); }
})();
JS
node /tmp/zonas.js
IN
