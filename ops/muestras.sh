#!/bin/bash
# Cloud Shell: guarda en ~/muestras.json lo que devuelve cada súper para varias búsquedas (para afinar el comparador).
IP=$(cat ~/.cestalista-ip)
ssh -i ~/.ssh/cestalista ubuntu@"$IP" 'bash -s' > ~/muestras.json <<'IN'
python3 - <<'PY'
import json, urllib.request, urllib.parse, concurrent.futures as cf
S="mercadona dia alcampo consum ahorramas bm masymas hiperdino carrefour caprabo gadis froiz".split()
Q=["leche","leche entera","aceite de oliva","huevos","arroz","yogur natural","pan de molde","atun"]
def get(a):
    s,q=a
    try:
        d=json.load(urllib.request.urlopen(f"http://127.0.0.1:3000/api/public/{s}?q={urllib.parse.quote(q)}&limit=60",timeout=60))
        return s,q,[{k:p.get(k) for k in ("name","brand","price","packaging","unitPrice","unitFormat")} for p in d.get("results") or []]
    except Exception as e: return s,q,str(e)
out={}
with cf.ThreadPoolExecutor(12) as ex:
    for s,q,r in ex.map(get,[(s,q) for q in Q for s in S]): out.setdefault(q,{})[s]=r
print(json.dumps(out,ensure_ascii=False))
PY
IN
echo "Listo: $(wc -c < ~/muestras.json) bytes guardados en muestras.json"
