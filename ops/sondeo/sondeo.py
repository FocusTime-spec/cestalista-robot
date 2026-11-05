"""Sondeo 7: Alcampo, código postal -> región."""
import json, urllib.request, ssl, http.cookiejar
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
out = []
CSRF = ""
def p(*a): out.append(" ".join(str(x) for x in a))
B = "https://www.compraonline.alcampo.es"
def sesion():
    cj = http.cookiejar.CookieJar()
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj), urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    op.addheaders = [("User-Agent", UA), ("Accept-Language", "es-ES")]
    html = op.open(B + "/", timeout=25).read().decode("utf-8", "replace")
    vid = next((c.value for c in cj if c.name == "VISITORID"), "")
    import re
    m = re.search(r'"csrf[^"]*"\s*:\s*\{?[^}]*?"token"\s*:\s*"([^"]+)"', html) or re.search(r'csrf[-_]?token["\']?\s*[:=]\s*["\']([^"\']+)', html, re.I)
    global CSRF; CSRF = m.group(1) if m else ""
    p("cookies:", [c.name for c in cj], "csrf:", bool(CSRF), [html[x.start()-60:x.start()+120] for x in re.finditer("csrf", html, re.I)][:3])
    return op, vid, cj
def call(op, vid, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(B + path, data=data, method=method, headers={"Accept": "application/json", "Content-Type": "application/json", "visitor-id": vid, "visitorid": vid, "x-csrf-token": CSRF, "Origin": B, "Referer": B + "/"})
    try:
        r = op.open(req, timeout=25); return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, (e.read() or b"").decode("utf-8", "replace")
for cp in ["08001", "41001"]:
    op, vid, cj = sesion()
    p(f"\n===== CP {cp} visitor={vid[:10]}")
    st, b = call(op, vid, "PUT", "/api/address/v1/addresses/by-postcode", {"postcode": cp})
    p("by-postcode", st, b[:900])
    st, b = call(op, vid, "GET", "/api/customersessions/v2/sessions/active")
    p("session active", st, b[:600])
    try:
        lst = json.loads(b) if b.startswith("[") or b.startswith("{") else None
    except Exception:
        lst = None
open("ops/sondeo/resultado.txt", "w").write("\n".join(out))
