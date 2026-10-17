--!strict
-- CasualtyAsset: the rigged swimmer casualty (M_Chr_Casualty_Swimmer_Rig = asset 77856458721407 v2: the LOD0 mesh
-- skinned to 17 R15 bones, art/status/CH1.csv). AssetLoader loads and prepares the upload (Atlas SurfaceAppearance,
-- dry + wet); this finishes it once the way make_rig_rbxm.luau builds assets/models/M_Chr_Casualty_Swimmer_Rig.rbxm:
--   * pivot at the feet (the Root bone), upright: PivotTo(CFrame.new(x, seaY - Waterline, z)) floats it;
--   * ATT_Strobe / ATT_Whistle as Bones under UpperTorso (they follow the torso; the client hangs the strobe on it);
--   * exactly one AnimationController + Animator; always wet (a casualty in the water is soaked);
--   * the skinned MeshPart anchored and non-colliding (victims are scripted, not physics: CONTRACT.md).
-- Poses are client-side (Bone.Transform doesn't replicate): the model is tagged CasualtyRig and its attribute
-- CasualtyPose ("TreadWater" | "Wave" | "Panic" | "Sit") drives src/client/Controllers/CasualtyController.
-- Server only. clone() never yields: nil until the background load is done, or when it failed (greybox fallback).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
)
local AssetLoader = require(script.Parent.AssetLoader)

local CasualtyAsset = {}

CasualtyAsset.ASSET = "M_Chr_Casualty_Swimmer_Rig"
CasualtyAsset.TAG = "CasualtyRig"
CasualtyAsset.WATERLINE = 4.55 -- studs above the feet where the sea sits (chin and lifejacket collar clear)
CasualtyAsset.RETRY_AFTER = 35

local ready: Model? = nil
local loading = false
local failedAt: number? = nil

-- Bone CFrame in its MeshPart's space (bind pose).
local function partSpace(b: Bone): CFrame
	local cf = b.CFrame
	local p = b.Parent
	while p and p:IsA("Bone") do
		cf = p.CFrame * cf
		p = p.Parent
	end
	return cf
end

local function finish(source: Model): Model?
	local model = source:Clone()
	local mesh: MeshPart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and d.HasSkinnedMesh then
			mesh = d
			break
		end
	end
	if not mesh then
		warn("[CasualtyAsset] no skinned MeshPart in the upload")
		model:Destroy()
		return nil
	end
	local bones: { [string]: Bone } = {}
	for _, d in mesh:GetDescendants() do
		if d:IsA("Bone") then
			bones[d.Name] = d
		end
	end
	local rootBone, torso = bones.Root, bones.UpperTorso
	if not (rootBone and torso and bones.Head) then
		warn("[CasualtyAsset] the upload has no Root / UpperTorso / Head bones")
		model:Destroy()
		return nil
	end
	local feet = partSpace(rootBone).Position
	mesh.PivotOffset = CFrame.new(feet) -- pivot = the feet, upright (bones are axis-aligned at bind)
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.CastShadow = true
	model.PrimaryPart = mesh
	-- markers (AssetLoader made any ATT_* into Attachments on the part: re-home them as torso bones)
	for _, a in mesh:GetChildren() do
		if a:IsA("Attachment") and not a:IsA("Bone") and string.sub(a.Name, 1, 4) == "ATT_" then
			a:Destroy()
		end
	end
	local torsoCF = partSpace(torso)
	local markers: { [string]: Vector3 } = AssetIds.Attachments[CasualtyAsset.ASSET] or {}
	for name, v in markers do
		if not bones[name] then
			local b = Instance.new("Bone")
			b.Name = name
			b.CFrame = torsoCF:Inverse() * CFrame.new(feet + v)
			b.Parent = torso
		end
	end
	local controllers = {}
	for _, c in model:GetDescendants() do
		if c:IsA("AnimationController") then
			table.insert(controllers, c)
		end
	end
	local ac = controllers[1] or Instance.new("AnimationController")
	for i = 2, #controllers do
		controllers[i]:Destroy()
	end
	ac.Parent = model
	if not ac:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = ac
	end
	AssetLoader.setWet(model, true)
	model.Name = "CasualtyRig"
	model:SetAttribute("Waterline", CasualtyAsset.WATERLINE)
	model:SetAttribute("RigType", "R15SkinnedBones")
	return model
end

local function load()
	loading = true
	local ok, result = pcall(function()
		local template = AssetLoader.getTemplate(CasualtyAsset.ASSET, "LOD0")
		return if template then finish(template) else nil
	end)
	loading = false
	if ok and result then
		local folder = ServerStorage:FindFirstChild("AssetTemplates") or ServerStorage
		result.Name = "CasualtyRig_Ready"
		result.Parent = folder
		ready = result
		failedAt = nil
	else
		if not ok then
			warn(`[CasualtyAsset] preparing the rig failed: {result}`)
		end
		failedAt = os.clock()
	end
end

-- Starts the background load (server start).
function CasualtyAsset.preload()
	if not ready and not loading then
		task.spawn(load)
	end
end

-- A fresh rigged casualty (pivot at the feet, anchored, wet), or nil while loading / after a failure.
function CasualtyAsset.clone(): Model?
	if ready then
		local m = ready:Clone()
		m.Name = "CasualtyRig"
		return m
	end
	if not loading and (not failedAt or os.clock() - failedAt > CasualtyAsset.RETRY_AFTER) then
		CasualtyAsset.preload()
	end
	return nil
end

return CasualtyAsset
