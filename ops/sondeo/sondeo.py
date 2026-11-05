"""Sondeo 3: rutas de API de zona/CP y prueba de cambio de precio."""
import re, json, urllib.request, urllib.parse, ssl
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
ctx = ssl.create_default_context()
def get(url, headers=None, data=None, method=None):
    h = {"User-Agent": UA, "Accept": "application/json, text/plain, */*", "Accept-Language": "es-ES"}; h.update(headers or {})
    if isinstance(data, (dict, list)): data = json.dumps(data).encode(); h["Content-Type"] = "application/json"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=h, method=method), timeout=25, context=ctx) as r:
            return r.status, dict(r.headers), r.read(6_000_000).decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers or {}), (e.read(3000) or b"").decode("utf-8", "replace")
    except Exception as e:
        return 0, {}, str(e)[:200]
out = []
def p(*a): out.append(" ".join(str(x) for x in a))
def js_de(home):
    _, _, html = get(home, headers={"Accept": "text/html"})
    t = html
    for s in re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', html)[:30]:
        u = urllib.parse.urljoin(home, s)
        if urllib.parse.urlparse(u).netloc == urllib.parse.urlparse(home).netloc:
            t += get(u)[2]
    # chunks importados
    for c in set(re.findall(r'"\./(chunk-[A-Z0-9]+\.js)"', t))[:60] if False else list(set(re.findall(r'"\./(chunk-[A-Z0-9]+\.js)"', t)))[:60]:
        t += get(urllib.parse.urljoin(home, c))[2]
    return t
TPL = re.compile(r'`\$\{[^}]+\}(/[^`]{3,120})`')
for name, home in [("Consum", "https://tienda.consum.es/"), ("Masymas", "https://tienda.masymas.com/")]:
    t = js_de(home)
    rutas = sorted(set(m for m in TPL.findall(t) if re.search(r"zone|zip|shipping|area|store|centre|center", m, re.I)))
    p(f"\n===== {name}: {len(t)} bytes JS; rutas con zona/CP:")
    for r in rutas[:50]: p("   ", r)
    # headers personalizados
    hs = sorted(set(re.findall(r'["\'](x-[a-z0-9-]{3,40})["\']', t, re.I)))
    p("  cabeceras x-:", hs[:30])
    zs = sorted(set(re.findall(r'(?:defaultZoneId|defaultShippingZoneId|defaultZipCode)["\']?\s*[:=]\s*["\']?([0-9A-Za-z]+)', t)))
    p("  valores por defecto:", zs[:10])
# Consum: config general
for base in ["https://tienda.consum.es", "https://tienda.masymas.com"]:
    for path in ["/api/rest/V1.0/shopping/cart/zone", "/api/rest/V2.0/shopping/cart/zone", "/api/rest/V1.0/commons/zipCode/46001/cities",
                 "/api/rest/V1.0/shipping/area", "/api/rest/V1.0/shipping/areas", "/api/rest/V1.0/commons/config", "/api/rest/V1.0/shopping/zone",
                 "/api/rest/V1.0/shipping/zone/zipcode/46001", "/api/rest/V1.0/shipping/shippingArea/zipCode/46001"]:
        st, hd, body = get(base + path)
        p(f"{base}{path} -> {st} {body[:220]!r}")
# Alcampo: rutas
t = js_de("https://www.compraonline.alcampo.es/")
rutas = sorted(set(re.findall(r'["`](/api/[a-zA-Z0-9_\-/${}.]+)["`]', t)))
p("\n===== Alcampo rutas /api:")
for r in rutas[:80]: p("   ", r)
open("ops/sondeo/resultado.txt", "w").write("\n".join(out))
