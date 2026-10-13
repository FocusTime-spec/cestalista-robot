"""Robot de CestaLista: pide a Oracle el servidor gratis (Always Free) hasta conseguirlo.
Solo usa la API de Oracle con la llave guardada en el secreto OCI_PRIVATE_KEY.
Si el servidor ya existe, no hace nada. Nunca pide nada que no sea Always Free."""
import base64, datetime, email.utils, hashlib, json, os, sys, urllib.parse, urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

REGION = "eu-madrid-1"
TENANCY = os.environ["OCI_TENANCY"]
USER = os.environ["OCI_USER"]
FINGERPRINT = os.environ["OCI_FINGERPRINT"]
KEY = serialization.load_pem_private_key(os.environ["OCI_PRIVATE_KEY"].encode(), password=None)
NAME = "cestalista-server"
SUBNET_NAME = "public subnet-cestalista-red"
SSH_KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmu+CDOIV+BK8STE5syxXo5s4uY3VkMxtNYY26SZVSk cestalista-deploy"
# Tamaños gratis, de mayor a menor (el máximo gratis es 4 OCPU / 24 GB).
SIZES = [(4, 24), (2, 12), (1, 6)]
IAAS = f"https://iaas.{REGION}.oraclecloud.com/20160918"
IDENTITY = f"https://identity.{REGION}.oci.oraclecloud.com/20160918"

def call(method, url, body=None):
    u = urllib.parse.urlparse(url)
    path = u.path + (("?" + u.query) if u.query else "")
    date = email.utils.formatdate(usegmt=True)
    headers = {"date": date, "host": u.netloc}
    signed = ["date", "(request-target)", "host"]
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["content-type"] = "application/json"
        headers["content-length"] = str(len(data))
        headers["x-content-sha256"] = base64.b64encode(hashlib.sha256(data).digest()).decode()
        signed += ["content-length", "content-type", "x-content-sha256"]
    lines = []
    for h in signed:
        lines.append(f"(request-target): {method.lower()} {path}" if h == "(request-target)" else f"{h}: {headers[h]}")
    sig = base64.b64encode(KEY.sign("\n".join(lines).encode(), padding.PKCS1v15(), hashes.SHA256())).decode()
    headers["authorization"] = (f'Signature version="1",keyId="{TENANCY}/{USER}/{FINGERPRINT}",'
                                f'algorithm="rsa-sha256",headers="{" ".join(signed)}",signature="{sig}"')
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"null")

def q(d): return urllib.parse.urlencode(d)

st, insts = call("GET", f"{IAAS}/instances?" + q({"compartmentId": TENANCY, "displayName": NAME}))
if st != 200: print("Error leyendo instancias:", st, insts); sys.exit(1)
alive = [i for i in insts if i["lifecycleState"] not in ("TERMINATED", "TERMINATING")]
if alive:
    print(f"YA EXISTE: {NAME} ({alive[0]['lifecycleState']}). No hago nada.")
    open(os.environ.get("GITHUB_OUTPUT", "/dev/null"), "a").write("done=yes\n"); sys.exit(0)

st, ads = call("GET", f"{IDENTITY}/availabilityDomains?" + q({"compartmentId": TENANCY}))
st2, subnets = call("GET", f"{IAAS}/subnets?" + q({"compartmentId": TENANCY, "displayName": SUBNET_NAME}))
st3, images = call("GET", f"{IAAS}/images?" + q({"compartmentId": TENANCY, "operatingSystem": "Canonical Ubuntu",
    "operatingSystemVersion": "24.04", "shape": "VM.Standard.A1.Flex", "sortBy": "TIMECREATED", "sortOrder": "DESC"}))
if st != 200 or st2 != 200 or st3 != 200 or not subnets or not images:
    print("Error preparando:", st, st2, st3, len(subnets or []), len(images or [])); sys.exit(1)
images = [i for i in images if "Minimal" not in i["displayName"]] or images
subnet, image = subnets[0]["id"], images[0]["id"]
print("Imagen:", images[0]["displayName"])

for ad in ads:
    for ocpus, mem in SIZES:
        body = {"availabilityDomain": ad["name"], "compartmentId": TENANCY, "displayName": NAME,
                "shape": "VM.Standard.A1.Flex", "shapeConfig": {"ocpus": ocpus, "memoryInGBs": mem},
                "sourceDetails": {"sourceType": "image", "imageId": image},
                "createVnicDetails": {"subnetId": subnet, "assignPublicIp": True},
                "metadata": {"ssh_authorized_keys": SSH_KEY}}
        st, res = call("POST", f"{IAAS}/instances", body)
        if st in (200, 201):
            print(f"¡CONSEGUIDO! {ocpus} OCPU / {mem} GB en {ad['name']}")
            open(os.environ.get("GITHUB_OUTPUT", "/dev/null"), "a").write(f"done=new\nsize={ocpus} OCPU / {mem} GB\n")
            sys.exit(0)
        msg = (res or {}).get("message", "")
        print(f"{ocpus}/{mem} en {ad['name']}: {st} {msg[:120]}")
        if "capacity" not in msg.lower() and st not in (429, 500, 503):
            sys.exit(1)  # error de verdad (no de falta de hueco): parar y avisar
print("Sin hueco esta vez. Lo vuelvo a intentar en el siguiente turno.")
