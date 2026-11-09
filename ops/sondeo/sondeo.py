"""Sondeo 8: tiempo de cada supermercado para una búsqueda en cestalista.com."""
import time, json, urllib.request, urllib.parse, ssl
ctx=ssl.create_default_context(); out=[]
def p(*a): out.append(" ".join(str(x) for x in a))
S=["mercadona","dia","alcampo","consum","ahorramas","bm","masymas","hiperdino","carrefour","gadis","caprabo","froiz"]
for q in ["galletas príncipe","leche entera","huevos"]:
    p(f"\n== {q}")
    for ronda in (1,2):
        for s in S:
            u=f"https://cestalista.com/api/public/{s}?q={urllib.parse.quote(q)}&limit=30"
            t=time.time()
            try:
                with urllib.request.urlopen(urllib.request.Request(u,headers={"User-Agent":"Mozilla/5.0"}),timeout=60,context=ctx) as r:
                    b=r.read(); code=r.status
                try: n=len(json.loads(b).get("results",[]))
                except Exception: n="?"
            except urllib.error.HTTPError as e: code=e.code; n="-"
            except Exception as e: code=str(e)[:30]; n="-"
            p(f"  r{ronda} {s:10} {time.time()-t:6.1f}s  {code}  {n} resultados")
open("ops/sondeo/resultado.txt","w").write("\n".join(out))
