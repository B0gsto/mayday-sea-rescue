"""E1: download the Poly Haven CC0 texture scans the rescue kit atlas is built from (2k PNG maps) into
build/e1/src/<id>/ (data only) and record the authors (info.json). Licence: CC0 1.0 (https://polyhaven.com/license)."""
import json, os, urllib.request
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../.."))
SRC = os.path.join(ROOT, "build/e1/src")
SCANS = ["stretch_poplin", "denim_fabric", "rubberized_track", "metal_plate_02"]
UA = {"User-Agent": "MaydayE1/1.0"}
WANT = {"Diffuse": "diff", "nor_gl": "nor", "Rough": "rough", "Metal": "metal", "AO": "ao"}


def get(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read()


if __name__ == "__main__":
    for pid in SCANS:
        d = os.path.join(SRC, pid)
        os.makedirs(d, exist_ok=True)
        files = json.loads(get("https://api.polyhaven.com/files/" + pid))
        info = json.loads(get("https://api.polyhaven.com/info/" + pid))
        got = []
        for key, short in WANT.items():
            if key in files and "2k" in files[key]:
                url = files[key]["2k"]["png"]["url"]
                path = os.path.join(d, short + ".png")
                if not os.path.exists(path):
                    open(path, "wb").write(get(url))
                got.append(short)
        json.dump({"pid": pid, "url": "https://polyhaven.com/a/" + pid, "authors": list(info.get("authors", {})),
                   "dimensions_mm": info.get("dimensions"), "maps": got}, open(os.path.join(d, "info.json"), "w"))
        print(pid, got, info.get("dimensions"), list(info.get("authors", {})), flush=True)
