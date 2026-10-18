"""HP2a -> art/status/HP2a.csv (one row per prop + the shared atlas row; ids and moderation from assets/manifest.json)."""
import csv, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../../../..")) + "/"
sys.path.insert(0, HERE)
from refs import REFS  # noqa: E402
import atlas  # noqa: E402
man = json.load(open(ROOT + "assets/manifest.json"))
tris = json.load(open(ROOT + "build/hp2a/tris.json"))
SETS = {a: s for a, s in (("Metal", "Metal"),)}


def mid(path):
    hit = [e for e in man.values() if isinstance(e, dict) and e.get("source") == path]
    return (str(hit[-1].get("assetId")), hit[-1].get("moderation")) if hit else ("", "missing")


srcs = []
for pid in ("rust_coarse_01", "rusty_painted_metal", "metal_plate_02", "green_metal_rust", "rubberized_track"):
    i = json.load(open(ROOT + "build/hp2a/src/%s/info.json" % pid))
    srcs.append("%s (%s)" % (i["url"], ", ".join(i["authors"])))
LIC = "maps: CC0 1.0 Poly Haven scans (https://polyhaven.com/license) + procedural; model owned"
AI = "assisted (code-generated models and procedural/scan-composited maps by Claude; no AI images)"
imgs = [e for e in man.values() if isinstance(e, dict) and e.get("source", "").startswith("assets/textures/%s/" % atlas.ATLAS_ASSET)]
img_mod = {e.get("moderation") for e in imgs}
rows = [["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"]]
rows.append([atlas.ATLAS_ASSET, "P0", "maps built + check_textures PASS + uploaded (%s); AD review pending" % "/".join(sorted(map(str, img_mod))), "",
             "blender/numpy: art/source/harbour/M_Hbr_PropAtlas/maketex.py from Poly Haven scans " + "; ".join(srcs),
             LIC, AI, "", "2 sets T_HbrProps_Metal_* and T_HbrProps_Rope_* (+_Wet) at 1024 (masters 2048 = scan res, in masters/); "
             "Rope ALB alpha = net cards (gen_asset_ids: AlphaMode Transparency for this set); signal masks T_HbrProps_<Set>_signal.png. %d maps uploaded." % len(imgs)])
for a in REFS:
    l0, m0 = mid("assets/fbx/%s/%s_LOD0.fbx" % (a, a))
    l1, m1 = mid("assets/fbx/%s/%s_LOD1.fbx" % (a, a))
    mods = {m0, m1} | img_mod
    state = "all Approved" if mods == {"Approved"} else "moderation " + "/".join(sorted(str(m) for m in mods))
    att = json.load(open(ROOT + "assets/fbx/%s/%s.attachments.json" % (a, a)))["attachments"]
    rows.append([a, "P0", "built+validated+exported+uploaded (%s)+overcast dry/wet renders; Studio pass + AD review pending" % state, l0,
                 "blender:art/source/harbour/%s/build.py -> M_Hbr_PropAtlas/props.py (HP2a Opus 2026-10-18)" % a, LIC, AI, "",
                 "LOD1 %s. LOD0 %d tris (LOD1 half), small_prop, atlas %s; ref %s; attachments %s; sheet assets/review/HP2a/contact.png"
                 % (l1, tris.get(a, 0), atlas.ATLAS_ASSET, REFS[a], ", ".join(x["name"] for x in att) or "none")])
csv.writer(open(ROOT + "art/status/HP2a.csv", "w", newline="")).writerows(rows)
print("HP2a.csv rows", len(rows) - 1)
