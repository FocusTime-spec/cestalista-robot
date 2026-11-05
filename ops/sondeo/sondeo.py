"""Sondeo 2: contexto alrededor de zona/tienda en el JS de cada web."""
import re, urllib.request, urllib.parse, ssl
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
ctx = ssl.create_default_context()
def get(url, headers=None, data=None, method=None):
    h = {"User-Agent": UA, "Accept": "*/*", "Accept-Language": "es-ES"}; h.update(headers or {})
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=h, method=method), timeout=25, context=ctx) as r:
            return r.status, dict(r.headers), r.read(6_000_000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers or {}), (e.read(5000) or b"").decode("utf-8", "replace")
    except Exception as e:
        return 0, {}, str(e)[:200]
out = []
def p(*a): out.append(" ".join(str(x) for x in a))
def textos(home):
    st, _, html = get(home)
    res = [(home, html)]
    for s in re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', html)[:30]:
        u = urllib.parse.urljoin(home, s)
        if urllib.parse.urlparse(u).netloc == urllib.parse.urlparse(home).netloc:
            res.append((u, get(u)[2]))
    return res
PLAN = {
 "Consum": ("https://tienda.consum.es/", r"shippingZoneId|zoneId|cart/zone|x-tol-zone|zipCode"),
 "Masymas": ("https://tienda.masymas.com/", r"cart/zone|zoneId|x-tol|searcher/products"),
 "Alcampo": ("https://www.compraonline.alcampo.es/", r"retailerRegionId|regionId|/api/[a-z-]+/v\d+/products|products/search"),
 "Gadis": ("https://www.gadisline.com/", r"storeZones|stores/postal-codes|checkPostalCode|storeId|apiUrl|baseUrl"),
 "HiperDino": ("https://www.hiperdino.es/", r"searchZone|storeId|postcodePickupShop|doofinder"),
}
for name, (home, pat) in PLAN.items():
    p(f"\n===== {name}")
    vistos = 0
    for u, t in textos(home):
        for m in re.finditer(pat, t):
            frag = t[max(0, m.start()-160): m.end()+160].replace("\n", " ")
            p(f"  [{u.rsplit('/',1)[-1][:30]}] ...{frag}...")
            vistos += 1
            if vistos >= 14: break
        if vistos >= 14: break
open("ops/sondeo/resultado.txt", "w").write("\n".join(out))
