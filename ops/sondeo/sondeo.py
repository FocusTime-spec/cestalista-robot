"""Sondeo: ¿algún supermercado cambia precios según código postal / tienda?
Descarga la portada y sus JS y busca rutas de API relacionadas con CP/tienda/zona."""
import re, json, urllib.request, urllib.parse, ssl, sys
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
ctx = ssl.create_default_context()
def get(url, data=None, headers=None, method=None, timeout=20):
    h = {"User-Agent": UA, "Accept": "*/*", "Accept-Language": "es-ES,es;q=0.9"}
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
            return r.status, dict(r.headers), r.read(3_000_000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers or {}), (e.read(20000) or b"").decode("utf-8", "replace")
    except Exception as e:
        return 0, {}, str(e)[:200]
KW = re.compile(r"""["'`](/?(?:[a-zA-Z0-9_\-./{}$]*?)(?:postal|zip|zipcode|postcode|codigo-?postal|cp=|zone|zona|warehouse|almacen|store-?id|storeId|shop-?id|centro|delivery-?area|region)[a-zA-Z0-9_\-./{}$?=&]*)["'`]""", re.I)
SITES = {
 "Dia": "https://www.dia.es/",
 "Consum": "https://tienda.consum.es/",
 "Masymas": "https://tienda.masymas.com/",
 "BM": "https://www.online.bmsupermercados.es/",
 "Alcampo": "https://www.compraonline.alcampo.es/",
 "Ahorramas": "https://www.ahorramas.com/",
 "HiperDino": "https://www.hiperdino.es/",
 "Froiz": "https://supermercado.froiz.com/",
 "Carrefour": "https://www.carrefour.es/supermercado",
 "Caprabo": "https://www.capraboacasa.com/",
 "Gadis": "https://www.gadisline.com/",
}
out = []
def p(*a): out.append(" ".join(str(x) for x in a))
for name, home in SITES.items():
    p(f"\n===== {name} {home}")
    st, hd, html = get(home)
    p("portada:", st, len(html))
    host = urllib.parse.urlparse(home).netloc
    srcs = re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', html)[:25]
    found = set(m for m in KW.findall(html) if len(m) < 140)
    for s in srcs:
        u = urllib.parse.urljoin(home, s)
        if urllib.parse.urlparse(u).netloc.split(".")[-2:] != host.split(".")[-2:]:
            continue
        st2, _, js = get(u)
        for m in KW.findall(js):
            if len(m) < 140 and ("/" in m or "=" in m):
                found.add(m)
    for f in sorted(found)[:40]:
        p("   ", f)
# Pruebas concretas de catálogo
def aktios(base, extra=""):
    st, hd, body = get(f"{base}/api/rest/V1.0/catalog/searcher/products?q=leche&limit=3&offset=0{extra}", headers={"Accept": "application/json"})
    try:
        j = json.loads(body); prods = j.get("catalog", {}).get("products", [])
        return st, [(x.get("productData", {}).get("name"), x.get("priceData", {}).get("prices", [{}])[0].get("value", {}).get("centAmount")) for x in prods[:3]], list(j.keys())
    except Exception:
        return st, body[:200], None
p("\n===== Aktios (Consum/Masymas/BM)")
for base in ["https://tienda.consum.es", "https://tienda.masymas.com", "https://www.online.bmsupermercados.es"]:
    p(base, aktios(base))
    st, hd, body = get(f"{base}/api/rest/V1.0/shopping/postalcode/46001", headers={"Accept": "application/json"})
    p("  postalcode/46001:", st, body[:200].replace("\n", " "))
p("\n===== Dia directo")
st, hd, body = get("https://www.dia.es/api/v1/search-back/search?q=leche&page=1", headers={"Accept": "application/json"})
p(st, body[:300].replace("\n", " "))
p("\n===== Alcampo (Ocado)")
for u in ["https://www.compraonline.alcampo.es/api/v5/products/search?term=leche&limit=3",
          "https://www.compraonline.alcampo.es/api/webproductpagews/v5/products/bop?retailerProductIds=1",
          "https://www.compraonline.alcampo.es/api/v1/postcode/28001"]:
    st, hd, body = get(u, headers={"Accept": "application/json"})
    p(u, st, body[:250].replace("\n", " "))
open("ops/sondeo/resultado.txt", "w").write("\n".join(out))
print("\n".join(out))
