-- Lune: M_Chr_Casualty_Swimmer_Rig.rbxm from the downloaded skinned upload (asset 77856458721407 v2).
-- usage: lune run art/source/characters/M_Chr_Casualty_Swimmer/make_rig_rbxm.luau <raw.rbxm> <out.rbxm>
-- Adds (the importer's AnimationController + InitialPoses are kept): dry + wet SurfaceAppearance (approved Atlas ids, SurfaceVariants like tools/studio/import_asset.luau),
-- ATT_Strobe / ATT_Whistle as Bones under UpperTorso (move with the torso; lights can parent to them), AnimationController
-- + Animator, the CasualtyRig ModuleScript (procedural Bind / TreadWater / Wave), pivot at the feet (Root bone).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local CFrame, Vector3, Instance = roblox.CFrame, roblox.Vector3, roblox.Instance
local HERE = "art/source/characters/M_Chr_Casualty_Swimmer/"
local root = roblox.deserializeModel(fs.readFile(process.args[1]))[1]
local mp = root:FindFirstChildWhichIsA("MeshPart")
assert(mp and mp.HasSkinnedMesh, "no skinned MeshPart")
root.Name = "M_Chr_Casualty_Swimmer_Rig"
-- the MeshPart keeps its uploaded name: the importer's InitialPoses folder (bind pose for the Animation Editor) refers to it
local ATLAS = { ColorMap = { "123844582500467", "83200797500731" }, NormalMap = { "107752150496614", "88731663285161" },
	RoughnessMap = { "104383984523403", "139849180076523" }, MetalnessMap = { "115017343888524", "115017343888524" } }
local function sa(name, wet)
	local s = Instance.new("SurfaceAppearance")
	s.Name = name
	for prop, ids in ATLAS do
		s[prop] = "rbxassetid://" .. ids[wet and 2 or 1]
	end
	s:SetAttribute("TextureSet", "Atlas")
	return s
end
for _, c in mp:GetChildren() do
	if c.ClassName == "SurfaceAppearance" then c:Destroy() end
end
sa("SurfaceAppearance", false).Parent = mp
local store = Instance.new("Configuration"); store.Name = "SurfaceVariants"; store.Parent = mp
sa("SurfaceAppearance_Wet", true).Parent = store
mp:SetAttribute("WetState", false)
mp:AddTag("HasWetVariant")
mp.Anchored = true; mp.CanCollide = false; mp.CanTouch = false; mp.CanQuery = true
mp.RenderFidelity = roblox.Enum.RenderFidelity.Precise
-- bones
local B = {}
for _, d in mp:GetDescendants() do
	if d.ClassName == "Bone" then B[d.Name] = d end
end
local function partSpace(b)            -- bone CFrame in MeshPart space
	local cf = b.CFrame
	local p = b.Parent
	while p and p.ClassName == "Bone" do cf = p.CFrame * cf; p = p.Parent end
	return cf
end
local att = serde.decode("json", fs.readFile("assets/fbx/M_Chr_Casualty_Swimmer/M_Chr_Casualty_Swimmer.attachments.json"))
local ut = partSpace(B.UpperTorso)
for _, a in att.attachments do
	local v = a.roblox_from_bbox_centre
	local nb = Instance.new("Bone")
	nb.Name = a.name
	nb.CFrame = ut:Inverse() * CFrame.new(v[1], v[2], v[3])
	nb.Parent = B.UpperTorso
end
local rootCF = partSpace(B.Root)
mp.PivotOffset = rootCF                 -- Model:GetPivot() = the feet (Root bone, Blender origin), upright
root.PrimaryPart = mp
-- the cloud importer already adds an AnimationController (no Animator) + InitialPoses: reuse it, exactly one Animator
local acs = {}
for _, c in root:GetChildren() do if c.ClassName == "AnimationController" then table.insert(acs, c) end end
local ac = acs[1] or Instance.new("AnimationController")
for i = 2, #acs do acs[i]:Destroy() end
ac.Parent = root
if not ac:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = ac end
local mod = Instance.new("ModuleScript"); mod.Name = "CasualtyRig"
mod.Source = fs.readFile(HERE .. "CasualtyRig.luau"); mod.Parent = root
root:SetAttribute("RigType", "R15SkinnedBones")
root:SetAttribute("Bones", 17)
root:SetAttribute("BindPose", "A-pose, bones axis-aligned (Y up, front -Z)")
root:SetAttribute("PivotAt", "feet (Root bone)")
root:SetAttribute("Waterline", 4.55)
root:SetAttribute("SourceAssetId", "77856458721407")
root:SetAttribute("SourceAssetVersion", 2)
fs.writeFile(process.args[2], roblox.serializeModel({ root }))
print("ok", root.Name, "bones", #(function() local n = {} for _, d in root:GetDescendants() do if d.ClassName == "Bone" then table.insert(n, d) end end return n end)(),
	"pivotOffset", tostring(mp.PivotOffset.Position))
