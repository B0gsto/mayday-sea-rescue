"""K1 -> art/status/K1.csv (one row per kit piece; ids and moderation from assets/manifest.json)."""
import csv, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import KIT, ROOT, SRC, WORK, size  # noqa: E402
man = json.load(open(ROOT + "assets/manifest.json"))
studio = os.path.exists(ROOT + "assets/review/K1/studio.png")


def mid(path):
    for e in man.values():
        if isinstance(e, dict) and e.get("source") == path:
            return str(e.get("assetId")), e.get("moderation")
    return "", "missing"


rows = [["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"]]
for a, pid, budget, tris, tier, zone, tex in KIT:
    info = json.load(open(WORK + a + ".json")); src = json.load(open(SRC + pid + "/info.json"))
    ids = {l: mid("assets/fbx/%s/%s.fbx" % (a, a + l)) for l in ("_LOD0", "_LOD1", "_LOD2")}
    imgs = [e for e in man.values() if isinstance(e, dict) and e.get("source", "").startswith("assets/textures/%s/" % a)]
    mods = {m for _, m in ids.values()} | {e.get("moderation") for e in imgs}
    state = "all Approved" if mods == {"Approved"} else "moderation " + "/".join(sorted(str(m) for m in mods))
    rows.append([a, "P0", "built+validated+exported+turntable+uploaded (%s)%s; AD review pending" % (state, "+Studio pass (2026-10-17)" if studio else ""),
                 ids["_LOD0"][0], "scan:%s (Poly Haven, %s) decimated + HP normal re-bake + graded/zoned maps: art/source/rocks/_kit (K1 Opus 2026-10-17)" % (src["url"], ", ".join(src["authors"])),
                 "CC0 1.0 (https://polyhaven.com/license); reference photos art/reference/M_Rock_Kit/SOURCES.md (not shipped)",
                 "assisted (code-written pipeline and procedural lichen/barnacle/wrack zoning by Claude on a real CC0 scan; no AI images)", "",
                 "LOD1 %s, LOD2 %s. LOD0 %d tris (HP %d), %s class, %.2f x %.2f x %.2f m (scan scale), %s zone%s, 1 set T_%s_Granite at %d (+_Wet), _COL hull. Masters 2048 (scan 2k)."
                 % (ids["_LOD1"][0], ids["_LOD2"][0], info["lp_tris"], info["hp_tris"], budget, *info["size_m"], zone,
                    " (ATT_Waterline)" if zone == "shore" else "", tex, size(a))])
csv.writer(open(ROOT + "art/status/K1.csv", "w", newline="")).writerows(rows)
print("K1.csv rows", len(rows) - 1)
