"""CH1 clothed Studio pass inputs (system python3) -> build/ch1/studio2/: import.luau (import_asset config from the CURRENT
atlas bytes; Atlas dry + _Wet), preload.luau, place.luau (floating at sea level + standing clone on a pontoon), shots_calm.json,
shots_storm.json. Only the clothed M_Chr_Casualty_Swimmer is used (never M_Chr_HumanBase_*)."""
import glob, hashlib, json, os, re, sys
G = "/Users/bogdan/RobloxProjects/MaydaySeaRescue/"
A = "M_Chr_Casualty_Swimmer"
S = G + "build/ch1/studio2/"
m = json.load(open(G + "assets/manifest.json"))
by_sha = {e["sha"]: e for e in m.values() if isinstance(e, dict) and e.get("imageId")}
atlas = {}
for f in sorted(glob.glob(G + "assets/textures/%s/T_CasualtySwimmer_Atlas_*.png" % A)):
    r = re.match(r"T_CasualtySwimmer_Atlas_(ALB|NOR|RGH|MET)(_Wet)?\.png$", os.path.basename(f))
    e = by_sha.get(hashlib.sha256(open(f, "rb").read()).hexdigest())
    if not e or e.get("moderation") != "Approved":
        sys.exit("not uploaded/approved: " + f)
    (atlas.setdefault("Wet", {}) if r[2] else atlas)[r[1]] = str(e["imageId"])
def lua(v):
    if isinstance(v, dict):
        return "{" + ", ".join("[%s] = %s" % (json.dumps(k), lua(x)) for k, x in v.items()) + "}"
    return json.dumps(v)
cfg = {"name": A, "source": "Workspace/%s_LOD0" % A, "tier": "hero", "anchored": True, "sets": {"Atlas": atlas}}
open(S + "import.luau", "w").write("_G.ImportAssetConfig = " + lua(cfg) + "\n" + open(G + "tools/studio/import_asset.luau").read())
open(S + "preload.luau", "w").write("""
local CP = game:GetService("ContentProvider")
local ids, bad = {}, {}
for _, sa in workspace:GetDescendants() do
\tif sa:IsA("SurfaceAppearance") then table.insert(ids, sa) end
end
CP:PreloadAsync(ids, function(id, st) if st ~= Enum.AssetFetchStatus.Success then table.insert(bad, id .. " " .. tostring(st)) end end)
return "preload " .. #ids .. " SurfaceAppearances, failed: " .. table.concat(bad, "; ")
""")
open(S + "place.luau", "w").write("""
local sea = workspace:GetAttribute("SeaLevel") or 0
local sp = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local o = sp and sp.Position or Vector3.zero
local spot
for r = 160, 640, 80 do
  for a = 0, 330, 30 do
    local p = o + Vector3.new(math.cos(math.rad(a)) * r, 0, math.sin(math.rad(a)) * r)
    local hit = workspace:Raycast(Vector3.new(p.X, sea + 300, p.Z), Vector3.new(0, -600, 0))
    if not hit or hit.Position.Y < sea - 3 or hit.Material == Enum.Material.Water then spot = Vector3.new(p.X, sea, p.Z) break end
  end
  if spot then break end
end
spot = spot or Vector3.new(o.X + 300, sea, o.Z)
workspace:SetAttribute("CH1Spot", spot)
local ld = workspace:FindFirstChild("LookDev")
local sw = ld:FindFirstChild("M_Chr_Casualty_Swimmer")
sw:PivotTo(CFrame.new(spot + Vector3.new(0, -2.9, 0)) * CFrame.Angles(math.rad(40), 0, 0))
local pad = Instance.new("Part") pad.Name = "CH1_Pontoon" pad.Anchored = true pad.Size = Vector3.new(10, 1, 10)
pad.Material = Enum.Material.WoodPlanks pad.Color = Color3.fromRGB(110, 98, 84)
pad.CFrame = CFrame.new(spot + Vector3.new(14, 0.5, 0)) pad.Parent = ld
local st = sw:Clone() st.Name = "CH1_Stand" st.Parent = ld
st:PivotTo(CFrame.new(spot + Vector3.new(14, 1, 0)))
workspace:SetAttribute("CH1Stand", spot + Vector3.new(14, 1, 0))
-- wash foam round the floating body: flat foam sprites on the water (Mayday_ocean_foam_alpha), topped up by an emitter
local fp = Instance.new("Part") fp.Name = "CH1_WashFoam" fp.Anchored = true fp.CanCollide = false fp.Transparency = 1
fp.Size = Vector3.new(2.6, 0.1, 4.2) fp.CFrame = CFrame.new(spot + Vector3.new(0, 0.05, 0.6)) fp.Parent = ld
local pe = Instance.new("ParticleEmitter") pe.Texture = "rbxassetid://107434961132990" pe.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
pe.EmissionDirection = Enum.NormalId.Top pe.Speed = NumberRange.new(0.02, 0.06) pe.Rate = 2.5 pe.Lifetime = NumberRange.new(4, 7)
pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.3)})
pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 1)})
pe.Rotation = NumberRange.new(0, 360) pe.RotSpeed = NumberRange.new(-6, 6) pe.Color = ColorSequence.new(Color3.fromRGB(200, 206, 204))
pe.LightInfluence = 1 pe.LightEmission = 0 pe.Brightness = 0.8 pe.Parent = fp pe:Emit(10)
return "spot " .. tostring(spot) .. " sea " .. sea
""")
# ATT_Strobe (assets/fbx/<A>/<A>.attachments.json, offset from the LOD0 bbox centre): the game adds a flashing PointLight
# there; the shots build the same client-side (Attachment + PointLight + small Neon lens), flashing ~55/min, held ON
# for the capture so every still shows the flash.
_att = {a["name"]: a for a in json.load(open(G + "assets/fbx/%s/%s.attachments.json" % (A, A)))["attachments"]}
_so = _att["ATT_Strobe"]["roblox_from_bbox_centre"]
STROBE = ("if not _G.CH1Strobe then _G.CH1Strobe = true local ld = workspace:WaitForChild('LookDev') "
          "for _, nm in {'%s', 'CH1_Stand'} do local mdl = ld:FindFirstChild(nm) "
          "local mp = mdl and mdl:FindFirstChildWhichIsA('MeshPart', true) if mp then "
          "local a = Instance.new('Attachment') a.Name = 'ATT_Strobe' a.Position = Vector3.new(%g, %g, %g) a.Parent = mp "
          "local l = Instance.new('PointLight') l.Name = 'StrobeLight' l.Color = Color3.fromRGB(235, 245, 255) "
          "l.Brightness = 0.9 l.Range = 4.5 l.Shadows = false l.Parent = a "
          "local s = Instance.new('Part') s.Name = 'StrobeLens' s.Shape = Enum.PartType.Ball s.Size = Vector3.new(0.13, 0.13, 0.13) "
          "s.Material = Enum.Material.Neon s.Color = Color3.fromRGB(240, 248, 255) s.Anchored = true s.CanCollide = false "
          "s.CastShadow = false s.Parent = mdl "
          "task.spawn(function() while s.Parent do local on = _G.CH1StrobeHold or (os.clock() %% 1.1) < 0.16 "
          "l.Enabled = on s.Transparency = on and 0 or 0.7 s.CFrame = a.WorldCFrame task.wait(0.03) end end) end end end "
          "_G.CH1StrobeHold = true " % (A, _so[0], _so[1], _so[2]))
PRE = ("Clear", "Overcast", "Storm", "Night")
def shot(name, base, cam, look, preset, wet, fov=50, extra=""):
    return {"name": name, "cam": [0, 0, 0], "look": [0, 0, 0], "settle": 2.0,
            "lua": STROBE + "local p = workspace:GetAttribute('%s') workspace.CurrentCamera.FieldOfView = %d %s"
                   "_G.LookDev.shot({p.X+%g, p.Y+%g, p.Z+%g}, {p.X+%g, p.Y+%g, p.Z+%g}) return _G.LookDev.apply('%s', %s)"
                   % (base, fov, extra, *cam, *look, preset, "true" if wet else "false")}
FACE_F = (0, 0.95, 3.2)            # floating face (pivot tilted 40 deg back), studs from CH1Spot
FACE_S = (0, 4.95, 0)              # standing face, from CH1Stand (front -Z)
calm = []
for P in PRE:
    for wet in (False, True):
        calm.append(shot("Float_%s_%s" % (P, "wet" if wet else "dry"), "CH1Spot", (-5, 2.4, -6), (0, 0.4, 1.6), P, wet))
yaw = "local ld = workspace.LookDev local s = workspace:GetAttribute('CH1Stand') ld.CH1_Stand:PivotTo(CFrame.new(s) * CFrame.Angles(0, math.rad(%d), 0)) "
for i, a in enumerate((0, 90, 180, 270)):
    calm.append(shot("Stand_Overcast_dry_%03d" % a, "CH1Stand", (0, 3.3, -9), (0, 2.7, 0), "Overcast", False, 40, yaw % a))
for P in PRE:
    calm.append(shot("Stand_%s_wet" % P, "CH1Stand", (4, 3.6, -8), (0, 2.7, 0), P, True, 40, yaw % 0))
for wet in (False, True):
    calm.append(shot("Face_1m_Overcast_%s" % ("wet" if wet else "dry"), "CH1Stand", (0.8, 5.1, -2.9), FACE_S, "Overcast", wet, 40, yaw % 0))
calm.append(shot("Face_1m_Night_wet", "CH1Stand", (0.8, 5.1, -2.9), FACE_S, "Night", True, 40, yaw % 0))
calm.append(shot("FloatFace_1m_Overcast_wet", "CH1Spot", (0.9, 2.6, 0.7), FACE_F, "Overcast", True, 40))
storm = [shot("StormSea_Float_dry", "CH1Spot", (-5, 2.4, -6), (0, 0.4, 1.6), "Storm", False),
         shot("StormSea_Float_wet", "CH1Spot", (-5, 2.4, -6), (0, 0.4, 1.6), "Storm", True),
         shot("StormSea_FloatFace_1m_wet", "CH1Spot", (0.9, 2.6, 0.7), FACE_F, "Storm", True, 40),
         shot("StormSea_Stand_wet", "CH1Stand", (4, 3.6, -8), (0, 2.7, 0), "Storm", True, 40, yaw % 0)]
json.dump(calm, open(S + "shots_calm.json", "w"), indent=1)
json.dump(storm, open(S + "shots_storm.json", "w"), indent=1)
print("atlas", atlas, "shots", len(calm), len(storm))
