"""Sondeo 4: ¿cambia el precio en Consum/Masymas/BM con X-TOL-ZONE?"""
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
TERMS = ["leche", "platano", "pollo", "tomate", "aceite", "huevos"]
def precios(base, headers):
    m = {}
    for q in TERMS:
        st, b = get(f"{base}/api/rest/V1.0/catalog/searcher/products?q={q}&limit=15&offset=0", headers)
        try:
            for x in json.loads(b)["catalog"]["products"]:
                m[str(x.get("code") or x.get("id"))] = (x["productData"]["name"], x["priceData"]["prices"][0]["value"]["centAmount"])
        except Exception:
            pass
    return m
for base in ["https://tienda.consum.es", "https://tienda.masymas.com", "https://www.online.bmsupermercados.es"]:
    p(f"\n===== {base}")
    ref = precios(base, {})
    p("sin zona:", len(ref), "productos")
    for z in ["1", "2", "3", "4", "5", "6", "8", "10", "12", "15", "20", "25", "30", "40", "50", "100"]:
        for hdr in ({"X-TOL-ZONE": z}, {"X-TOL-SHIPPING-ZONE": z}):
            m = precios(base, hdr)
            comunes = [k for k in m if k in ref]
            dif = [f"{ref[k][0][:24]} {ref[k][1]}->{m[k][1]}" for k in comunes if m[k][1] != ref[k][1]]
            p(f"  {list(hdr)[0]}={z}: {len(m)} prod, {len(comunes)} comunes, {len(dif)} distintos {dif[:3]}")
    for path in ["/api/rest/V1.0/shipping/area?zipCode=46001", "/api/rest/V1.0/shipping/area?zipcode=46001",
                 "/api/rest/V1.0/shipping/area?postalCode=46001", "/api/rest/V1.0/shipping/config",
                 "/api/rest/V1.0/shipping/area?zipCode=46001&shippingMethod=D", "/api/rest/V1.0/shipping/area?shippingMethod=T"]:
        st, b = get(base + path)
        p(f"  {path} -> {st} {b[:300]!r}")
open("ops/sondeo/resultado.txt", "w").write("\n".join(out))
