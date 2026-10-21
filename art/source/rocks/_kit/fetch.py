"""Download each K1 scan (Poly Haven glTF 2k: mesh + diffuse, nor_gl, arm) into build/k1/src/<id>/ and record author."""
import json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import KIT, SRC
UA = {"User-Agent": "MaydayK1/1.0"}

def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()

only = set(sys.argv[1:])
for asset, pid, *_ in KIT:
    if only and asset not in only:
        continue
    d = SRC + pid + "/"
    os.makedirs(d + "textures", exist_ok=True)
    files = json.loads(get("https://api.polyhaven.com/files/" + pid))
    info = json.loads(get("https://api.polyhaven.com/info/" + pid))
    g = files["gltf"]["2k"]["gltf"]
    todo = [(g["url"], d + os.path.basename(g["url"]))] + [(v["url"], d + k) for k, v in g["include"].items()]
    for url, path in todo:
        if not os.path.exists(path):
            open(path, "wb").write(get(url))
    json.dump({"pid": pid, "url": "https://polyhaven.com/a/" + pid, "authors": list(info.get("authors", {})),
               "dimensions_mm": info.get("dimensions"), "polycount": info.get("polycount")}, open(d + "info.json", "w"))
    print(asset, pid, "ok", flush=True)
