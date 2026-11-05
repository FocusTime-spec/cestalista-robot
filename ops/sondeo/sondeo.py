"""Sondeo 6: Alcampo (regiones) e HiperDino (tiendas)."""
import re, json, urllib.request, urllib.parse, ssl
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
ctx = ssl.create_default_context()
def get(url, headers=None, data=None, method=None):
    h = {"User-Agent": UA, "Accept": "*/*", "Accept-Language": "es-ES"}; h.update(headers or {})
    if isinstance(data, (dict, list)): data = json.dumps(data).encode(); h["Content-Type"] = "application/json"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=h, method=method), timeout=25, context=ctx) as r:
            return r.status, dict(r.headers), r.read(8_000_000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers or {}), (e.read(3000) or b"").decode("utf-8", "replace")
    except Exception as e:
        return 0, {}, str(e)[:200]
out = []
def p(*a): out.append(" ".join(str(x) for x in a))
# --- Alcampo
home = "https://www.compraonline.alcampo.es/"
st, hd, html = get(home)
t = html
for s in re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', html)[:30]:
    u = urllib.parse.urljoin(home, s)
    if "alcampo" in urllib.parse.urlparse(u).netloc: t += get(u)[2]
p("== Alcampo JS bytes", len(t))
seen = 0
for m in re.finditer(r"ecomdeliverydestinations|customersessions|regions?/|/region|changeRegion|setRegion|postcode", t):
    frag = t[max(0, m.start()-140): m.end()+180].replace("\n", " ")
    if "/" not in frag: continue
    p("  ...", frag, "...")
    seen += 1
    if seen > 25: break
p("Set-Cookie portada:", [c.split(";")[0][:60] for k, c in hd.items() if k.lower() == "set-cookie"])
# lista de regiones (adivinanzas)
for path in ["/api/ecomdeliverydestinations/v1/regions", "/api/customersessions/v1/regions", "/api/address/v1/regions",
             "/api/ecomdeliverydestinations/v2/postcode/28001", "/api/address/v3/address-lookup/by-postcode?countryCode=ES&postcode=08001"]:
    s2, _, b = get(home.rstrip("/") + path, headers={"Accept": "application/json"})
    p(path, s2, b[:250].replace("\n", " "))
# --- HiperDino doofinder
s3, _, b = get("https://eu1-search.doofinder.com/6/98bc6bfc3b241d1e43c90f646cfb077d/_search?query=leche&rpp=3", headers={"Origin": "https://www.hiperdino.es", "Referer": "https://www.hiperdino.es/"})
p("\n== HiperDino doofinder", s3)
try:
    j = json.loads(b); r0 = j["results"][0]
    p("claves:", sorted(r0.keys()))
    p("ejemplo:", json.dumps({k: r0[k] for k in list(r0)[:40]}, ensure_ascii=False)[:1500])
    p("facets:", list((j.get("facets") or {}).keys()))
except Exception as e:
    p("err", e, b[:300])
# HiperDino portada: zonas/tiendas
st, hd, html = get("https://www.hiperdino.es/")
for m in list(re.finditer(r"postcodePickupShop|store_?[Cc]ode|zona|isla", html))[:12]:
    p("  hd...", html[max(0, m.start()-120): m.end()+160].replace("\n", " "))
open("ops/sondeo/resultado.txt", "w").write("\n".join(out))
