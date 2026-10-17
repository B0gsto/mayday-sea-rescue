"""CH6: writes the Studio pass inputs for M_Chr_Bosun (run from anywhere; system python3).
  assets/review/M_Chr_Bosun/studio/import-a.luau   rename the inserted model; ATT_HarnessHandle / ATT_TowRing as Attachments
                                                   under the Harness LOD0 MeshPart, ATT_Mouth under BodyHead LOD0 (offsets
                                                   from the LOD0 bbox centre, attachments json); install _G.ImportAsset
  assets/review/M_Chr_Bosun/studio/import-b.luau   partSets discovered by name (M_Chr_Bosun_<Set...>_LODn), _G.ImportAsset(cfg),
                                                   neutral grey stage (deck + 2 backdrop walls, Night key SpotLight) under
                                                   workspace.LookDev.BosunStage, feet grounded by raycast, face -Z, Fur
                                                   DoubleSided, Fur wet ALB id check, preload of every SurfaceAppearance
                                                   (dry + stored wet); installs _G.BosunPreload / _G.BosunShot; returns JSON
  assets/review/M_Chr_Bosun/studio/preload.luau    re-runnable preload check (studio_pass.sh loops it until allOk)
  assets/review/M_Chr_Bosun/shots.json             4 presets x dry/wet x EV -0.5/0/+0.5 hero 3/4 front, side views, fur close-ups

White-ghost fix (CH6 pass 1): the maps were fine, Studio's auto-generated TexturePack assets for the SurfaceAppearances were
still "being generated" while the shots ran, so the fur rendered as the bare MeshPart grey with no alpha cut-out. Everything
now preloads (time-boxed, failures reported) before and during the shots."""
import glob, hashlib, json, os, re, sys

G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
A = "M_Chr_Bosun"
R = G + "assets/review/%s/" % A
T = (-46.0, 6.0, -9.0)   # quay spot: Terrain top Y 6 (raycast hit in CH6 pass 1; the quay box LandTopY 4 is buried), dog faces -Z
EYE = 4.5                # 1.5 m eye level in studs above the ground
EV = (-0.5, 0.0, 0.5)    # exposure ladder, added to every preset's own ExposureCompensation
PRESETS = ("Clear", "Overcast", "Storm", "Night")
MAPS = ("ALB", "NOR", "RGH", "MET")


def lua(v):
    if isinstance(v, dict):
        return "{" + ", ".join("[%s] = %s" % (json.dumps(k), lua(x)) for k, x in v.items()) + "}"
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, bool):
        return "true" if v else "false"
    return json.dumps(v)


# ---------------------------------------------------------------- texture sets from the manifest
m = json.load(open(G + "assets/manifest.json"))
TEX = r"T_\w+?_([A-Za-z][A-Za-z0-9]*)_(ALB|NOR|RGH|MET)(_Wet)?\.png$"
sets, names = {}, {}
for e in m.values():
    r = re.match(rf"assets/textures/{A}/{TEX}", e.get("source", ""))
    if r and e.get("imageId"):
        s = sets.setdefault(r[1], {})
        (s.setdefault("Wet", {}) if r[3] else s)[r[2]] = str(e["imageId"])
        names[str(e["imageId"])] = os.path.basename(e["source"])
by_sha = {(e.get("sha") or k.split(":", 1)[-1]): e for k, e in m.items() if e.get("imageId")}
for f in sorted(glob.glob(G + "assets/textures/%s/*.png" % A)):   # identical bytes dedupe in the manifest (Fur MET == Body MET)
    r = re.match(TEX, os.path.basename(f))
    e = by_sha.get(hashlib.sha256(open(f, "rb").read()).hexdigest())
    if r and e:
        s = sets.setdefault(r[1], {})
        (s.setdefault("Wet", {}) if r[3] else s)[r[2]] = str(e["imageId"])   # current bytes win over older uploads of the same source
        names.setdefault(str(e["imageId"]), os.path.basename(f))
    elif r:
        sys.exit("not uploaded (no manifest entry for these bytes): %s -> run upload_ch6.sh" % os.path.basename(f))
for need in ("Fur", "Body", "Harness"):
    if need not in sets:
        sys.exit("texture set %s missing from the manifest" % need)
sets["Fur"]["alphaMode"] = "Transparency"

# Guard against the id mix-up suspected in pass 1: Fur Wet ALB must be the bytes of T_Bosun_Fur_ALB_Wet.png and must not be
# any NOR/RGH/MET id (dry or wet, any set); every ALB id differs from every non-ALB id.
fw = G + "assets/textures/%s/T_Bosun_Fur_ALB_Wet.png" % A
fw_entry = by_sha.get(hashlib.sha256(open(fw, "rb").read()).hexdigest())
fur_wet_alb = sets["Fur"].get("Wet", {}).get("ALB")
assert fw_entry and str(fw_entry["imageId"]) == fur_wet_alb, "Fur.Wet.ALB %s != manifest id of the current wet ALB bytes" % fur_wet_alb
alb_ids, non_alb = set(), set()
for s in sets.values():
    for d in (s, s.get("Wet", {})):
        for k in MAPS:
            if d.get(k):
                (alb_ids if k == "ALB" else non_alb).add(d[k])
assert not (alb_ids & non_alb), "ALB ids shared with non-ALB maps: %s" % sorted(alb_ids & non_alb)

# ---------------------------------------------------------------- attachments (hosted on named LOD0 parts)
atts = json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (A, A)))["attachments"]
HOST = {"ATT_HarnessHandle": "Harness", "ATT_TowRing": "Harness", "ATT_Mouth": "BodyHead"}
markers = [{"name": a["name"], "c": a["roblox_from_bbox_centre"], "look": a.get("look", [0, 0, -1]),
            "up": a.get("up", [0, 1, 0]), "host": HOST.get(a["name"], "Body")} for a in atts]
cfg = {"name": A, "source": "Workspace/" + A, "tier": "hero", "sets": sets}
print("sets", {k: sorted(x for x in v if x != "alphaMode") for k, v in sets.items()},
      "furWetALB", fur_wet_alb, "markers", [(a["name"], a["host"]) for a in markers])

BBOX = """
local function lod0Box(model: Instance): (Vector3, Vector3)
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

# ---------------------------------------------------------------- import-a
a = BBOX + """
_G.ImportAssetConfig = nil
local model: Model? = nil
for _, c in workspace:GetChildren() do
\tif c:IsA("Model") and string.sub(c.Name, 1, 11) == "M_Chr_Bosun" then model = c end
end
assert(model, "inserted M_Chr_Bosun model not found")
model.Name = "M_Chr_Bosun"
local mn, mx = lod0Box(model)
local centre = (mn + mx) / 2
local made, warns = {}, {}
-- host = the LOD0 MeshPart whose name has _<host> right after the asset prefix (M_Chr_Bosun_Harness_LOD0, ..._BodyHead_LOD0)
local function host(word: string): MeshPart?
\tlocal best: MeshPart? = nil
\tfor _, p in model:GetDescendants() do
\t\tif p:IsA("MeshPart") and string.match(p.Name, "_LOD0$") and string.find(p.Name, "M_Chr_Bosun_" .. word, 1, true) then
\t\t\tif not best or p.Size.Magnitude > best.Size.Magnitude then best = p end
\t\tend
\tend
\treturn best
end
for _, m in MARKERS do
\tlocal old = model:FindFirstChild(m.name, true)
\tif old then old:Destroy() end
\tlocal pos = centre + Vector3.new(m.c[1], m.c[2], m.c[3])
\tlocal look, up = Vector3.new(m.look[1], m.look[2], m.look[3]), Vector3.new(m.up[1], m.up[2], m.up[3])
\tlocal cf = CFrame.lookAt(pos, pos + look, up)
\tlocal h = host(m.host)
\tif h then
\t\tlocal att = Instance.new("Attachment")
\t\tatt.Name = m.name
\t\tatt.Parent = h
\t\tatt.WorldCFrame = cf
\t\ttable.insert(made, m.name .. " -> " .. h.Name)
\telse -- fallback: a marker part; import_asset hosts it on the nearest visual part
\t\tlocal p = Instance.new("Part")
\t\tp.Name = m.name; p.Size = Vector3.one * 0.1; p.Anchored = true; p.Transparency = 1; p.CFrame = cf
\t\tp.Parent = model
\t\ttable.insert(warns, "no LOD0 MeshPart M_Chr_Bosun_" .. m.host .. "*: " .. m.name .. " left to nearest-part rule")
\tend
end
_G.BosunPre = {centre = {centre.X, centre.Y, centre.Z}, size = {mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z},
\tattachments = made, warnings = warns}
""".replace("MARKERS", lua(markers)) + open(G + "tools/studio/import_asset.luau").read()

# ---------------------------------------------------------------- import-b
b = BBOX + """
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local A = "M_Chr_Bosun"
local CFG: any = CFG_TABLE
local IDNAMES: {[string]: string} = IDNAMES_TABLE
local FUR_WET_ALB = "FURWETALB"
local NON_ALB: {[string]: boolean} = NONALB_TABLE
local T = Vector3.new(T_VEC)
local MAPPROPS = {"ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap"}
local function now(): number return DateTime.now().UnixTimestampMillis / 1000 end
local function digits(uri: string?): string return if uri then (string.match(uri, "(%d+)%s*$") or uri) else "" end

-- 0. clean leftovers of an earlier run in this session
local lookDev: Instance = workspace:FindFirstChild("LookDev") or (function()
\tlocal f = Instance.new("Folder"); f.Name = "LookDev"; f.Parent = workspace
\treturn f
end)()
for _, n in {A, "BosunStage"} do
\tlocal old = lookDev:FindFirstChild(n)
\tif old then old:Destroy() end
end

-- 1. partSets by name pattern: M_Chr_Bosun_<Word>_LODn -> the longest set name that prefixes <Word> (Fur*, Body*, Harness*)
local src = workspace:FindFirstChild(A)
assert(src, "Workspace.M_Chr_Bosun not found (run import-a first)")
local partSets, unmatched = {}, {}
for _, p in src:GetDescendants() do
\tif p:IsA("MeshPart") then
\t\tlocal word = string.match(p.Name, "^M_Chr_Bosun_(%w+)_LOD%d$")
\t\tlocal best: string? = nil
\t\tif word then
\t\t\tfor setName in CFG.sets do
\t\t\t\tif string.sub(word, 1, #setName) == setName and (not best or #setName > #best) then best = setName end
\t\t\tend
\t\tend
\t\tif best then partSets[p.Name] = best elseif not string.find(p.Name, "_COL") then table.insert(unmatched, p.Name) end
\tend
end
CFG.partSets = partSets
local report = _G.ImportAsset(CFG)
local found = lookDev:FindFirstChild(A)
assert(found and found:IsA("Model"), "import failed: " .. HttpService:JSONEncode(report))
local model: Model = found

-- 2. neutral stage: grey seamless deck on the quay + two backdrop walls (behind the hero 3/4 and the side camera)
local stage = Instance.new("Folder"); stage.Name = "BosunStage"; stage.Parent = lookDev
local function slab(name: string, size: Vector3, cf: CFrame, grey: number): Part
\tlocal p = Instance.new("Part")
\tp.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf
\tp.Material = Enum.Material.SmoothPlastic; p.Color = Color3.new(grey, grey, grey); p.Reflectance = 0
\tp.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
\tp.CastShadow = false; p.CanCollide = true; p.CanTouch = false
\tp.Parent = stage
\treturn p
end
local rpQuay = RaycastParams.new(); rpQuay.FilterType = Enum.RaycastFilterType.Exclude
rpQuay.FilterDescendantsInstances = {lookDev}
local qhit = workspace:Raycast(T + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), rpQuay)
local quayTop = if qhit and math.abs(qhit.Position.Y - T.Y) < 1.5 then qhit.Position.Y else T.Y
local deckTop = quayTop + 0.05 -- just above the terrain (no z-fight)
slab("Deck", Vector3.new(64, 1, 64), CFrame.new(T.X, deckTop - 0.5, T.Z), 0.42)
slab("WallW", Vector3.new(1, 24, 64), CFrame.new(T.X - 8.5, deckTop + 12, T.Z), 0.5)
slab("WallN", Vector3.new(64, 24, 1), CFrame.new(T.X, deckTop + 12, T.Z + 8.5), 0.5)
-- Night practical key: invisible lamp head 3 m (9 studs) up, front-left, warm white, aimed at the chest
local lamp = Instance.new("Part")
lamp.Name = "NightKeyLamp"; lamp.Anchored = true; lamp.Size = Vector3.one * 0.4; lamp.Transparency = 1
lamp.CanCollide = false; lamp.CanQuery = false; lamp.CanTouch = false; lamp.CastShadow = false
lamp.CFrame = CFrame.lookAt(Vector3.new(T.X - 3.5, deckTop + 9, T.Z - 5), Vector3.new(T.X, deckTop + 1.6, T.Z - 0.6))
lamp.Parent = stage
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front; spot.Angle = 50; spot.Range = 24; spot.Brightness = 4
spot.Color = Color3.fromRGB(255, 228, 192); spot.Shadows = true; spot.Enabled = false
spot.Parent = lamp

-- 3. ground the feet on the deck by raycast and face the mouth to -Z
local mn, mx = lod0Box(model)
local c = (mn + mx) / 2
local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances = {model}
local hit = workspace:Raycast(Vector3.new(T.X, deckTop + 40, T.Z), Vector3.new(0, -80, 0), rp)
local top = if hit then hit.Position.Y else deckTop
local feet = Vector3.new(c.X, mn.Y, c.Z)
local mouth = model:FindFirstChild("ATT_Mouth", true)
local yaw = 0
if mouth and mouth:IsA("Attachment") then
\tlocal d = mouth.WorldPosition - c
\tyaw = math.atan2(-d.X, -d.Z) -- rotation that takes d onto -Z
end
model:PivotTo(CFrame.new(Vector3.new(T.X, top, T.Z)) * CFrame.Angles(0, -yaw, 0) * CFrame.new(-feet) * model:GetPivot())
local mn2, mx2 = lod0Box(model)

-- 4. fur double-sided
local ds = {}
for _, p in model:GetDescendants() do
\tif p:IsA("MeshPart") and partSets[p.Name] == "Fur" then
\t\tlocal ok, err = pcall(function() (p :: any).DoubleSided = true end)
\t\tlocal okr, val = pcall(function() return (p :: any).DoubleSided end)
\t\ttable.insert(ds, p.Name .. "=" .. (if ok then "set" else "fail:" .. tostring(err)) .. "/" .. tostring(okr and val))
\tend
end

-- 5. map ids actually on the SurfaceAppearances; Fur wet ALB must be FUR_WET_ALB and never a NOR/RGH/MET id
local function readMap(sa: SurfaceAppearance, prop: string): string?
\tlocal ok, v = pcall(function() return (sa :: any)[prop] end)
\tif ok and type(v) == "string" and v ~= "" then return v end
\tlocal ok2, cv = pcall(function() return (sa :: any)[prop .. "Content"] end)
\tif ok2 and cv and cv.Uri and cv.Uri ~= "" then return cv.Uri end
\treturn nil
end
local idCheck = {ok = true, parts = {}}
for _, p in model:GetDescendants() do
\tif p:IsA("MeshPart") and partSets[p.Name] then
\t\tlocal store = p:FindFirstChild("SurfaceVariants")
\t\tlocal wet = store and store:FindFirstChild("SurfaceAppearance_Wet")
\t\tlocal dry = p:FindFirstChildOfClass("SurfaceAppearance")
\t\tlocal row: any = {part = p.Name, set = partSets[p.Name],
\t\t\tdryAlpha = if dry then dry.AlphaMode.Name else "none", wetAlpha = if wet and wet:IsA("SurfaceAppearance") then wet.AlphaMode.Name else "none"}
\t\tif wet and wet:IsA("SurfaceAppearance") then
\t\t\tlocal alb = digits(readMap(wet, "ColorMap"))
\t\t\trow.wetALB = alb .. " " .. (IDNAMES[alb] or "?")
\t\t\tif partSets[p.Name] == "Fur" and (alb ~= FUR_WET_ALB or NON_ALB[alb]) then
\t\t\t\tidCheck.ok = false; row.error = "Fur wet ALB is " .. alb .. ", expected " .. FUR_WET_ALB
\t\t\tend
\t\t\tif partSets[p.Name] == "Fur" and (row.wetAlpha ~= "Transparency" or row.dryAlpha ~= "Transparency") then
\t\t\t\tidCheck.ok = false; row.error = (row.error or "") .. " AlphaMode not Transparency"
\t\t\tend
\t\telseif partSets[p.Name] == "Fur" and string.match(p.Name, "_LOD0$") then
\t\t\tidCheck.ok = false; row.error = "no stored wet variant"
\t\tend
\t\ttable.insert(idCheck.parts, row)
\tend
end

-- 6. preload: every SurfaceAppearance (dry on the parts + wet stored in SurfaceVariants), time-boxed; reports failed ids
local function preload(timeout: number, activeOnly: boolean?): any
\tlocal mdl = lookDev:FindFirstChild(A)
\tlocal sas = {}
\tif mdl then
\t\tfor _, d in mdl:GetDescendants() do
\t\t\tif d:IsA("SurfaceAppearance") and (not activeOnly or (d.Parent and d.Parent:IsA("MeshPart"))) then table.insert(sas, d) end
\t\tend
\tend
\tlocal statuses: {[string]: string} = {}
\tlocal done, perr = false, nil
\tlocal t0 = now()
\ttask.spawn(function()
\t\tlocal ok, err = pcall(function()
\t\t\tContentProvider:PreloadAsync(sas, function(id: string, st: Enum.AssetFetchStatus) statuses[id] = st.Name end)
\t\tend)
\t\tif not ok then perr = tostring(err) end
\t\tdone = true
\tend)
\twhile not done and now() - t0 < timeout do task.wait(0.25) end
\tlocal failed, known, n = {}, {}, 0
\tfor _, sa in sas do
\t\tfor _, prop in MAPPROPS do
\t\t\tlocal uri = readMap(sa, prop)
\t\t\tif uri then
\t\t\t\tn += 1
\t\t\t\tknown[uri] = true
\t\t\t\tlocal okf, fs = pcall(function() return ContentProvider:GetAssetFetchStatus(uri) end)
\t\t\t\tlocal st = statuses[uri] or (if okf then fs.Name else "unknown")
\t\t\t\tif st ~= "Success" and not (okf and fs.Name == "Success") then
\t\t\t\t\tlocal id = digits(uri)
\t\t\t\t\ttable.insert(failed, {id = id, file = IDNAMES[id] or "not in manifest", status = st, prop = prop, sa = sa:GetFullName()})
\t\t\t\tend
\t\t\tend
\t\tend
\tend
\tlocal other = {} -- ids the engine fetched on its own (e.g. Studio's generated TexturePack for a SurfaceAppearance)
\tfor id, st in statuses do
\t\tif not known[id] and st ~= "Success" then table.insert(other, id .. "=" .. st) end
\tend
\treturn {allOk = done and perr == nil and #failed == 0 and #other == 0, finished = done, seconds = now() - t0,
\t\tsurfaceAppearances = #sas, maps = n, failed = failed, otherFailed = other, error = perr}
end
_G.BosunPreload = preload

-- 7. per-shot driver: preset + wet, identical exposure offset on top of the preset, Night key on, preload of the active maps
_G.BosunShot = function(preset: string, wet: boolean, ev: number): string
\tlocal r = _G.LookDev.apply(preset, wet)
\tlocal base = Lighting.ExposureCompensation
\tLighting.ExposureCompensation = base + ev
\tlocal lampNow = stage:FindFirstChild("NightKeyLamp")
\tlocal key = lampNow and lampNow:FindFirstChildOfClass("SpotLight")
\tif key then key.Enabled = preset == "Night" end
\tlocal pr = preload(6, true)
\tlocal bad = {}
\tfor _, f in pr.failed do table.insert(bad, f.id .. ":" .. f.status) end
\tfor _, o in pr.otherFailed do table.insert(bad, o) end
\treturn string.format("%s | EC %.2f%+.2f | key %s | preload %s %.1fs %s", r, base, ev, if key and key.Enabled then "on" else "off",
\t\tif pr.allOk then "ok" else "FAIL", pr.seconds, table.concat(bad, ","))
end

local pre = preload(40, false)
local m2 = if mouth and mouth:IsA("Attachment") then mouth.WorldPosition else Vector3.zero
local atts = {}
for _, d in model:GetDescendants() do
\tif d:IsA("Attachment") and string.sub(d.Name, 1, 4) == "ATT_" then
\t\tlocal w = d.WorldPosition
\t\ttable.insert(atts, string.format("%s @ %s (%.2f, %.2f, %.2f)", d.Name, d.Parent and d.Parent.Name or "?", w.X, w.Y, w.Z))
\tend
end
return HttpService:JSONEncode({report = report, pre = _G.BosunPre, partSets = partSets, unmatched = unmatched,
\tquayHit = if qhit then qhit.Instance:GetFullName() else "none", quayTop = quayTop, deckTop = deckTop,
\tfeetHit = if hit then hit.Instance:GetFullName() else "none", feetY = mn2.Y, yawDeg = math.deg(yaw),
\tbboxMin = {mn2.X, mn2.Y, mn2.Z}, bboxMax = {mx2.X, mx2.Y, mx2.Z}, mouth = {m2.X, m2.Y, m2.Z}, attachments = atts,
\tdoubleSided = ds, idCheck = idCheck, preload = pre})
"""
b = (b.replace("CFG_TABLE", lua(cfg)).replace("IDNAMES_TABLE", lua(names)).replace("FURWETALB", fur_wet_alb)
     .replace("NONALB_TABLE", lua({i: True for i in sorted(non_alb)}))
     .replace("T_VEC", "%s, %s, %s" % T))
pre = 'return game:GetService("HttpService"):JSONEncode(_G.BosunPreload(40, false))\n'
os.makedirs(R + "studio", exist_ok=True)
open(R + "studio/import-a.luau", "w").write(a)
open(R + "studio/import-b.luau", "w").write(b)
open(R + "studio/preload.luau", "w").write(pre)


# ---------------------------------------------------------------- shots
def off(d):
    return [round(T[0] + d[0], 2), round(T[1] + d[1], 2), round(T[2] + d[2], 2)]


look = off((0.0, 1.3, -0.4))                        # chest/shoulder of the dog (bbox centre ~1.4 up, head at -Z)
hero = off((4.6, EYE, -4.8))                        # 3/4 front, 6.6 studs (2.2 m) horizontal, 1.5 m eye level
side = off((7.0, EYE, -0.4))                        # right side, 7 studs (2.3 m)
ccam, clook = off((2.4, 3.6, -4.2)), off((0.0, 2.0, -1.6))   # wet ruff / chest close-up, ~3.4 studs
evn = {-0.5: "EVm05", 0.0: "EV0", 0.5: "EVp05"}


def shot(name, cam, lk, preset, wet, ev):
    return {"name": "%s_%s_%s_%s" % (A, preset, "wet" if wet else "dry", name), "cam": cam, "look": lk,
            "settle": 2.0 if wet else 1.5, "lua": "return _G.BosunShot('%s', %s, %s)" % (preset, "true" if wet else "false", ev)}


shots = []
for p in PRESETS:                                   # one sheet row per preset: dry EV-/0/+, wet EV-/0/+
    for wet in (False, True):
        for ev in EV:
            shots.append(shot(evn[ev], hero, look, p, wet, ev))
for p in PRESETS:
    for wet in (False, True):
        shots.append(shot("Side", side, look, p, wet, 0.0))
for wet in (False, True):
    shots.append(shot("FurClose", ccam, clook, "Overcast", wet, 0.0))
json.dump(shots, open(R + "shots.json", "w"), indent=1)
print("shots", len(shots), "hero", hero, "side", side, "look", look)
