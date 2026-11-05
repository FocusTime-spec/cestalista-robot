"""Sondeo 5: CP -> tienda (zona) en Aktios y comparación de precios entre tiendas."""
import json, urllib.request, ssl
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
ctx = ssl.create_default_context()
def get(url, headers=None):
    h = {"User-Agent": UA, "Accept": "application/json", "Accept-Language": "es-ES"}; h.update(headers or {})
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=25, context=ctx) as r:
            return r.status, r.read(4_000_000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, (e.read(2000) or b"").decode("utf-8", "replace")
    except Exception as e:
        return 0, str(e)[:200]
out = []
def p(*a): out.append(" ".join(str(x) for x in a))
TERMS = ["leche", "platano", "pollo", "tomate", "aceite", "huevos", "manzana", "pan", "yogur", "atun"]
def precios(base, zone=None):
    m = {}
    for q in TERMS:
        st, b = get(f"{base}/api/rest/V1.0/catalog/searcher/products?q={q}&limit=20&offset=0", {"X-TOL-ZONE": str(zone)} if zone else {})
        try:
            for x in json.loads(b)["catalog"]["products"]:
                m[str(x.get("code") or x.get("id"))] = (x["productData"]["name"], x["priceData"]["prices"][0]["value"]["centAmount"])
        except Exception:
            pass
    return m
def zona(base, cp):
    for met in ("D", "T"):
        st, b = get(f"{base}/api/rest/V1.0/shipping/area?zipCode={cp}&shippingMethod={met}")
        try:
            arr = json.loads(b)
            for g in arr:
                for a in g.get("shippingAreas", []):
                    z = a.get("zone") or {}
                    if z.get("id"): return met, z["id"], z.get("name"), a.get("shippingZoneId"), g.get("groupName")
        except Exception:
            pass
    return None
PLAN = {
 "https://tienda.consum.es": ["46001", "08001", "30001", "03001", "12001", "02001", "43001", "17001"],
 "https://tienda.masymas.com": ["46001", "33001", "03001", "30001", "24001", "02001"],
 "https://www.online.bmsupermercados.es": ["28001", "48001", "20001", "01001", "31001", "39001"],
}
for base, cps in PLAN.items():
    p(f"\n===== {base}")
    ref = precios(base); p("sin zona:", len(ref), "productos")
    for cp in cps:
        z = zona(base, cp)
        if not z: p(f"  {cp}: sin tienda"); continue
        m = precios(base, z[1])
        com = [k for k in m if k in ref]
        dif = [f"{ref[k][0][:22]} {ref[k][1]}->{m[k][1]}" for k in com if m[k][1] != ref[k][1]]
        p(f"  {cp} {z[4]} -> {z[0]} zona {z[1]} ({z[2]}): {len(m)} prod, {len(dif)}/{len(com)} distintos {dif[:3]}")
open("ops/sondeo/resultado.txt", "w").write("\n".join(out))
