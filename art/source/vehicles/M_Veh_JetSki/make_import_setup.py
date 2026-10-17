"""V1 (from the V2 RIB script): writes assets/review/M_Veh_JetSki/studio/import-setup.luau + import-closeup.luau
(renames the inserted models, imports the jet ski and the close-up set with tools/studio/import_asset.luau, explicit
partSets, both at the same CFrame: shared frame) and assets/review/M_Veh_JetSki/shots.json (FOV 40; heroes at about
17 studs in the four presets dry and wet, first person from ATT_EyePoint dry and wet, three close-ups)."""
import hashlib
import json
import os
import re

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
R = G + "assets/review/M_Veh_JetSki/"
m = json.load(open(G + "assets/manifest.json"))
FLOOR = float(os.environ.get("MAYDAY_JET_Y", "40"))
CF = [0, FLOOR, 0, 0]


def _sha(path):
    try:
        return hashlib.sha256(open(G + path, "rb").read()).hexdigest()
    except OSError:
        return ""


def sets_for(asset):
    """Image ids per set: the manifest entry whose sha matches the file on disk."""
    sets, cur = {}, {}
    for e in m.values():
        src = e.get("source", "")
        if src not in cur:
            cur[src] = _sha(src)
        if cur[src] and e.get("sha") and not cur[src].startswith(e["sha"]) and not e["sha"].startswith(cur[src][:40]):
            continue
        r = re.match(rf"assets/textures/{asset}/T_\w+?_([A-Za-z][A-Za-z0-9]*)_(ALB|NOR|RGH|MET)(_Wet)?\.png$", src)
        if r and e.get("imageId"):
            s = sets.setdefault(r[1], {})
            (s.setdefault("Wet", {}) if r[3] else s)[r[2]] = e["imageId"]
    return sets


def lua(v):
    if isinstance(v, dict):
        return "{" + ", ".join("[%s] = %s" % (json.dumps(k), lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    return json.dumps(v)


def atts(asset):
    try:
        d = json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (asset, asset)))
        return [{"name": a["name"], "pos": a["roblox_from_origin"]} for a in d.get("attachments", [])]
    except OSError:
        return []


parts = {}
for lod in ("LOD0", "LOD1", "LOD2"):
    for p, s in (("Hull", "Hull"), ("Seat", "Hull"), ("Decals", "Hull"), ("Sled", "Sled"), ("Fittings", "Sled"), ("Bars", "Sled")):
        parts["M_Veh_JetSki_%s_%s" % (p, lod)] = s
jet = {"name": "M_Veh_JetSki", "source": "Workspace/M_Veh_JetSki", "tier": "hero", "sets": sets_for("M_Veh_JetSki"),
       "partSets": parts, "attachments": atts("M_Veh_JetSki"), "cframe": CF}
cu = {"name": "M_Veh_JetSki_CloseUp", "source": "Workspace/M_Veh_JetSki_CloseUp", "tier": "hero",
      "sets": sets_for("M_Veh_JetSki_CloseUp"),
      "partSets": {"M_Veh_JetSki_CloseUp_%s_LOD0" % p: "CloseUp" for p in ("Bars", "Console", "Display")},
      "attachments": atts("M_Veh_JetSki_CloseUp"), "cframe": CF}
for c in (jet, cu):
    n = sum(len([k for k in s if k != "Wet"]) + len(s.get("Wet", {})) for s in c["sets"].values())
    print(c["name"], "sets", sorted(c["sets"]), "maps", n)
pre = """for _, c in workspace:GetChildren() do
\tif c:IsA("Model") and (c.Name == "M_Veh_JetSki_LOD0") then c.Name = "M_Veh_JetSki" end
\tif c:IsA("Model") and (c.Name == "M_Veh_JetSki_CloseUp_LOD0") then c.Name = "M_Veh_JetSki_CloseUp" end
end
"""
src = open(G + "tools/studio/import_asset.luau").read()
os.makedirs(R + "studio", exist_ok=True)
open(R + "studio/import-setup.luau", "w").write(pre + "_G.ImportAssetConfig = " + lua(jet) + "\n" + src)
open(R + "studio/import-closeup.luau", "w").write(
    "local r = _G.ImportAsset(" + lua(cu) + ")\nreturn game:GetService('HttpService'):JSONEncode(r)\n")

# ---------------------------------------------------------------- shots.json
fo = json.load(open(G + "art/source/vehicles/M_Veh_JetSki/frame_offset.json"))


def rb(p):
    """Blender final frame -> Roblox world on the stand (bbox centred on x / z, bottom on the floor)."""
    return [round(-p[0], 2), round(FLOOR + p[2], 2), round(p[1], 2)]


def shot(name, cam, look, preset, wet, night=False, settle=2.0):
    q = lambda v: ", ".join(str(x) for x in v)  # noqa: E731
    code = ("workspace.CurrentCamera.FieldOfView = 40 _G.LookDev.shot({%s}, {%s}) _G.JetSpot(%s) local st = _G.JetStand() "
            "local r = _G.LookDev.apply('%s', %s) return r .. \"; \" .. st"
            % (q(cam), q(look), "true" if night else "false", preset, "true" if wet else "false"))
    return {"name": name, "cam": cam, "look": look, "settle": settle, "lua": code}


C = [0, FLOOR + 1.6, 0]
views = {"Clear": [11.0, FLOOR + 6.5, -12.5], "Overcast": [-13.5, FLOOR + 6.0, -9.5], "Storm": [12.5, FLOOR + 7.0, 10.5],
         "Night": [-11.5, FLOOR + 6.5, -12.0]}
shots = []
for pre_, cam in views.items():
    for wet in (False, True):
        shots.append(shot("M_Veh_JetSki_%s_%s" % (pre_, "wet" if wet else "dry"), cam, C, pre_, wet,
                          night=(pre_ == "Night"), settle=4.0 if len(shots) < 2 else 2.0))   # first wet swap needs time to fetch
eye, disp = fo["eye"], fo["display"]
# V1 fix round: look along the rider's view (forward -Y, EYE_PITCH below level, pwc.py) so the bars, display and kill
# cord sit in the lower-middle of the frame; the game's first-person camera should use the same pitch at ATT_EyePoint
import math  # noqa: E402
pitch = math.radians(fo.get("eye_pitch_deg", -30.0))
ahead = [eye[0], eye[1] - 4.0 * math.cos(pitch), eye[2] + 4.0 * math.sin(pitch)]
for wet in (False, True):
    shots.append(shot("M_Veh_JetSki_CloseUp_FirstPerson_%s" % ("wet" if wet else "dry"), rb(eye), rb(ahead), "Overcast", wet))
shots.append(shot("M_Veh_JetSki_Closeup_sled", [-4.5, FLOOR + 4.8, 11.0], [0, FLOOR + 1.2, 5.2], "Overcast", False))
shots.append(shot("M_Veh_JetSki_Closeup_side_decals", [-6.2, FLOOR + 1.6, -1.2], [-1.9, FLOOR + 1.3, -1.6], "Overcast", False))
shots.append(shot("M_Veh_JetSki_Closeup_display", rb([disp[0] - 0.6, disp[1] + 1.1, disp[2] + 1.6]), rb(disp), "Overcast", False))
json.dump(shots, open(R + "shots.json", "w"), indent=1)
print("shots", len(shots))
