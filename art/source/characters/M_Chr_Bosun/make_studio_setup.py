"""CH6: writes the Studio pass inputs for M_Chr_Bosun.
  assets/review/M_Chr_Bosun/studio/import-a.luau  rename the inserted model, ATT_* marker parts from the attachments json
                                                  (bbox-centre offsets), install _G.ImportAsset
  assets/review/M_Chr_Bosun/studio/import-b.luau  _G.ImportAsset(cfg), ground the feet on the quay (raycast), face -Z,
                                                  Fur DoubleSided; returns the report + placement as JSON
  assets/review/M_Chr_Bosun/shots.json            4 presets x dry/wet + 2 Overcast fur close-ups (AlphaMode Transparency / Overlay)"""
import glob, hashlib, json, os, re
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
A = "M_Chr_Bosun"
R = G + "assets/review/%s/" % A
T = (-46.0, 6.0, -9.0)          # quay spot: raycast hit Terrain at Y 6 in CH6 (quay box top is LandTopY 4), east of QuaySpawn; dog faces -Z


def lua(v):
    if isinstance(v, dict):
        return "{" + ", ".join("[%s] = %s" % (json.dumps(k), lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    return json.dumps(v)


m = json.load(open(G + "assets/manifest.json"))
sets = {}
for e in m.values():
    r = re.match(rf"assets/textures/{A}/T_\w+?_([A-Za-z][A-Za-z0-9]*)_(ALB|NOR|RGH|MET)(_Wet)?\.png$", e.get("source", ""))
    if r and e.get("imageId"):
        s = sets.setdefault(r[1], {})
        (s.setdefault("Wet", {}) if r[3] else s)[r[2]] = e["imageId"]
by_sha = {e.get("sha"): e for e in m.values() if e.get("imageId")}
for f in sorted(glob.glob(G + "assets/textures/%s/*.png" % A)):   # identical bytes dedupe in the manifest (Fur MET == Body MET)
    r = re.match(r"T_\w+?_([A-Za-z][A-Za-z0-9]*)_(ALB|NOR|RGH|MET)(_Wet)?\.png$", os.path.basename(f))
    e = by_sha.get(hashlib.sha256(open(f, "rb").read()).hexdigest())
    if r and e:
        s = sets.setdefault(r[1], {})
        (s.setdefault("Wet", {}) if r[3] else s).setdefault(r[2], e["imageId"])
sets["Fur"]["alphaMode"] = "Transparency"
parts = {}
for lod in ("LOD0", "LOD1", "LOD2"):
    for p, s in (("BodyHead", "Body"), ("BodyFore", "Body"), ("BodyHind", "Body"), ("Harness", "Harness"),
                 ("FurFront", "Fur"), ("FurRear", "Fur")):
        parts["%s_%s_%s" % (A, p, lod)] = s
atts = json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (A, A)))["attachments"]
markers = [{"name": a["name"], "c": a["roblox_from_bbox_centre"], "o": a["roblox_from_origin"]} for a in atts]
cfg = {"name": A, "source": "Workspace/" + A, "tier": "hero", "sets": sets, "partSets": parts}
print("sets", {k: sorted(x for x in v if x != "alphaMode") for k, v in sets.items()}, "markers", [a["name"] for a in markers])

BBOX = """
local function lod0Box(model)
\tlocal mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
\tfor _, p in model:GetDescendants() do
\t\tif p:IsA("MeshPart") and string.find(p.Name, "_LOD0") and not string.find(p.Name, "_COL") then
\t\t\tlocal h = p.Size / 2
\t\t\tfor _, sx in {-1, 1} do for _, sy in {-1, 1} do for _, sz in {-1, 1} do
\t\t\t\tlocal w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
\t\t\t\tmn = mn:Min(w); mx = mx:Max(w)
\t\t\tend end end
\t\tend
\tend
\treturn mn, mx
end
"""
a = BBOX + """
_G.ImportAssetConfig = nil
local model
for _, c in workspace:GetChildren() do
\tif c:IsA("Model") and string.sub(c.Name, 1, 11) == "M_Chr_Bosun" then model = c end
end
assert(model, "inserted M_Chr_Bosun model not found")
model.Name = "M_Chr_Bosun"
local mn, mx = lod0Box(model)
local centre = (mn + mx) / 2
_G.BosunPre = {centre = {centre.X, centre.Y, centre.Z}, size = {mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z}}
for _, m in MARKERS do
\tlocal p = Instance.new("Part")
\tp.Name = m.name; p.Size = Vector3.one * 0.1; p.Anchored = true; p.Transparency = 1
\tp.CFrame = CFrame.new(centre + Vector3.new(m.c[1], m.c[2], m.c[3]))
\tp.Parent = model
end
""".replace("MARKERS", lua(markers)) + open(G + "tools/studio/import_asset.luau").read()

b = BBOX + """
local HttpService = game:GetService("HttpService")
local report = _G.ImportAsset(CFG)
local model = workspace.LookDev:FindFirstChild("M_Chr_Bosun")
local mn, mx = lod0Box(model)
local c = (mn + mx) / 2
local T = Vector3.new(TX, TY + 40, TZ)
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = {workspace.LookDev}
local hit = workspace:Raycast(T, Vector3.new(0, -80, 0), rp)
local top = if hit then hit.Position.Y else TY
local feet = Vector3.new(c.X, mn.Y, c.Z)
-- facing: the mouth attachment should point to -Z
local mouth = model:FindFirstChild("ATT_Mouth", true)
local yaw = 0
if mouth then
\tlocal d = mouth.WorldPosition - c
\tyaw = math.atan2(-d.X, -d.Z) -- rotation that takes d onto -Z
end
local target = Vector3.new(TX, top, TZ)
model:PivotTo(CFrame.new(target) * CFrame.Angles(0, -yaw, 0) * CFrame.new(-feet) * model:GetPivot())
local mn2, mx2 = lod0Box(model)
local ds = {}
for _, p in model:GetDescendants() do
\tif p:IsA("MeshPart") and string.find(p.Name, "_Fur") then
\t\tlocal ok, err = pcall(function() (p :: any).DoubleSided = true end)
\t\tlocal okr, val = pcall(function() return (p :: any).DoubleSided end)
\t\ttable.insert(ds, p.Name .. "=" .. (if ok then "set" else "fail:" .. tostring(err)) .. "/" .. tostring(okr and val))
\tend
end
local m2 = if mouth then mouth.WorldPosition else Vector3.zero
return HttpService:JSONEncode({report = report, pre = _G.BosunPre, quayHit = hit and hit.Instance:GetFullName() or "none",
\tquayTop = top, yawDeg = math.deg(yaw), bboxMin = {mn2.X, mn2.Y, mn2.Z}, bboxMax = {mx2.X, mx2.Y, mx2.Z},
\tmouth = {m2.X, m2.Y, m2.Z}, doubleSided = ds})
""".replace("CFG", lua(cfg)).replace("TX", str(T[0])).replace("TY", str(T[1])).replace("TZ", str(T[2]))
open(R + "studio/import-a.luau", "w").write(a)
open(R + "studio/import-b.luau", "w").write(b)

def off(d):
    return [round(T[0] + d[0], 2), round(T[1] + d[1], 2), round(T[2] + d[2], 2)]

cam, look = off((4.2, 2.4, -5.2)), off((0.0, 1.15, -0.2))         # 3/4 front, ~7.1 studs
ccam, clook = off((2.0, 2.3, -3.6)), off((0.0, 1.7, -1.3))        # fur ruff close-up, ~3.1 studs
shots = []
for p in ("Clear", "Overcast", "Storm", "Night"):
    for wet in (False, True):
        shots.append({"name": "%s_%s_%s" % (A, p, "wet" if wet else "dry"), "cam": cam, "look": look, "settle": 1.5,
                      "lua": "return _G.LookDev.apply('%s', %s)" % (p, "true" if wet else "false")})
ALPHA = ("local n = 0 for _, d in workspace.LookDev:GetDescendants() do if d:IsA('SurfaceAppearance') then "
         "local mp = d:FindFirstAncestorWhichIsA('MeshPart') if mp and string.find(mp.Name, '_Fur') then "
         "d.AlphaMode = Enum.AlphaMode.%s n += 1 end end end return _G.LookDev.apply('Overcast', false) .. ' alpha %s x' .. n")
for mode in ("Transparency", "Overlay"):
    shots.append({"name": "%s_Overcast_dry_Alpha_%s" % (A, mode), "cam": ccam, "look": clook, "settle": 1.5,
                  "lua": ALPHA % (mode, mode)})
json.dump(shots, open(R + "shots.json", "w"), indent=1)
print("shots", len(shots), "cam", cam, "look", look)
