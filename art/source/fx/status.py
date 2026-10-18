#!/usr/bin/env python3
"""Write art/status/FX1.csv and FX2.csv from assets/textures/FX/*.json and the upload manifest (image ids)."""
import csv
import hashlib
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
FX = os.path.join(ROOT, "assets", "textures", "FX")
BATCH = {"FX_Spray": "FX1", "FX_Foam": "FX1"}
SOURCE = {
    "FX_Spray_BowSheet": "BL Newtonian droplet sim (5200 drops, motion blur) + Mantaflow mist from the particles",
    "FX_Spray_SlamBurst": "BL droplet crown sim (6000 drops) + Mantaflow mist from the particles",
    "FX_Spray_Mist": "BL Mantaflow gas sim (res 80), white scattering volume",
    "FX_Spray_Spindrift": "BL droplet sim in a wind field + Mantaflow mist (res 96)",
    "FX_Foam_HullRing": "BL procedural Voronoi bubble-lace + fBm breakup, Cycles render",
    "FX_Foam_WakeRibbon": "BL procedural Voronoi bubble-lace + fBm breakup, Cycles render",
    "FX_Foam_CrestStreak": "BL procedural Voronoi bubble-lace + fBm breakup, Cycles render",
    "FX_Foam_Swash": "BL procedural Voronoi bubble-lace + fBm breakup, Cycles render",
    "FX_Rain_Streak": "BL drop exposure smear, Cycles motion blur, 16 variants",
    "FX_Rain_SplashRing": "BL crown droplet sim + expanding ring",
    "FX_Rain_OnWater": "BL expanding ripple rings, top view",
    "FX_Smoke_Orange": "BL Mantaflow smoke sim (res 80), orange dye volume",
    "FX_Flare_Smoke": "BL Mantaflow smoke sim (res 80), off-white volume",
    "FX_Flare_Head": "BL Mantaflow fire sim (res 72), flame emission ramp",
    "FX_Flare_Sparks": "BL emissive particle sparks, motion blur",
    "FX_Flare_Parachute": "BL emissive star in a scattering haze volume, flicker",
    "FX_Under_MarineSnow": "BL displaced aggregates + fibres, 16 variants",
    "FX_Under_Bubbles": "BL wobbling bubble (rim reflection + glints), loop",
}


def main():
    with open(os.path.join(ROOT, "assets", "manifest.json")) as f:
        man = json.load(f)
    rows = {"FX1": [], "FX2": []}
    for name in sorted(n[:-5] for n in os.listdir(FX) if n.endswith(".json")):
        with open(os.path.join(FX, name + ".json")) as f:
            info = json.load(f)
        with open(os.path.join(FX, name + ".png"), "rb") as f:
            sha = hashlib.sha256(f.read()).hexdigest()
        e = man.get("Image:" + sha, {})
        batch = next((b for p, b in BATCH.items() if name.startswith(p)), "FX2")
        status = "rendered+uploaded (%s)" % e.get("moderation", "?") if e.get("assetId") else "rendered"
        notes = "%s %d px, %s, %d frames; alpha cover %.2f; art/source/fx/build_fx.py; sheet assets/review/FX/contact.png" % (
            info["layout"], info["size"], info["kind"], len(info["frames"]), info["alpha_cover"])
        rows[batch].append([name, "P0", status, e.get("assetId", ""), "BL sim: " + SOURCE.get(name, ""),
                            "owned (rendered in-house from our Blender scenes; no third-party content)",
                            "assisted (code-written Blender sims and shaders by Claude; no AI images)", "", notes])
    for batch, rs in rows.items():
        with open(os.path.join(ROOT, "art", "status", batch + ".csv"), "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["asset", "priority", "status", "assetId", "source", "licence", "ai_used", "reviewer", "notes"])
            w.writerows(rs)
        print(batch, len(rs), "rows")


if __name__ == "__main__":
    main()
