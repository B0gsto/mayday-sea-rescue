--!strict
-- CasualtyAsset: the Person in the Water casualty as a dressed R15 character (docs/14 section 4, replaces
-- M_Chr_Casualty_Swimmer): NpcFactory builds the NpcOutfits "Swimmer" variants (clothes, hair, a lifejacket accessory)
-- in the background; this finishes each once:
--   * pivot at the feet, upright: PivotTo(CFrame.new(x, seaY - Waterline, z)) floats it (Waterline attribute:
--     mid-chest, the lifejacket's freeboard);
--   * ATT_Strobe / ATT_Whistle as Bones on the UpperTorso part (lifejacket shoulders; the client hangs the strobe on it);
--   * HumanoidRootPart anchored, every part non-colliding (victims are scripted, not physics: CONTRACT.md).
-- Poses are client-side (Motor6D.Transform written after the Animator, which plays nothing here): the model is tagged
-- CasualtyRig and its attribute CasualtyPose (Shared.Casualty.CasualtyRig.POSES) drives src/client/Controllers/
-- CasualtyController. Server only. clone() never yields: nil until a variant is built, or when every build failed
-- (RescueService then uses its greybox + NpcFactory upgrade).

local CasualtyRig = require(game:GetService("ReplicatedStorage").Shared.Casualty.CasualtyRig)
local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)
local NpcOutfits = require(game:GetService("ReplicatedStorage").Shared.Config.NpcOutfits)

local CasualtyAsset = {}

CasualtyAsset.ROLE = "Swimmer"
CasualtyAsset.TAG = "CasualtyRig"
CasualtyAsset.WATERLINE = 3.4 -- studs above the feet where the sea sits, when the rig's own measure looks wrong
CasualtyAsset.RETRY_AFTER = 35

local ready: { Model } = {}
local loading = false
local failedAt: number? = nil
local nextPick = 0

local function marker(torso: BasePart, name: string, side: number)
	local s = torso.Size
	local b = Instance.new("Bone")
	b.Name = name
	b.CFrame = CFrame.new(side * 0.3 * s.X, 0.35 * s.Y, -0.5 * s.Z - 0.15) -- on the lifejacket's front
	b.Parent = torso
end

local function finish(model: Model, rootHeight: number): Model?
	local root = model.PrimaryPart
	local torso = model:FindFirstChild("UpperTorso")
	if not (root and torso and torso:IsA("BasePart")) then
		warn("[CasualtyAsset] the R15 build has no HumanoidRootPart / UpperTorso")
		model:Destroy()
		return nil
	end
	root.PivotOffset = CFrame.new(0, -rootHeight, 0) -- pivot = the feet
	CasualtyRig.motorize(model) -- Motor6D joints, so CasualtyController can pose it
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	marker(torso, "ATT_Strobe", -1)
	marker(torso, "ATT_Whistle", 1)
	-- the lifejacket floats them high: sea at mid-chest, so shoulders, collar and arms read from
	-- the helm (shoulders under left only a head and a flat line of arms showing)
	local feetY = root.Position.Y - rootHeight
	local w = torso.Position.Y + torso.Size.Y / 2 - feetY - 1.1
	model.Name = "CasualtyRig"
	model:SetAttribute("Waterline", if w > 2.5 and w < 6 then w else CasualtyAsset.WATERLINE)
	model:SetAttribute("RigType", "R15")
	return model
end

local function load()
	loading = true
	local variants = #NpcOutfits.Roles[CasualtyAsset.ROLE]
	for i = 1, variants do
		local ok, result = pcall(function()
			local m, h = NpcFactory.build(CasualtyAsset.ROLE, { seed = i - 1, storm = false })
			return if m then finish(m, h) else nil
		end)
		if ok and result then
			result.Name = "CasualtyRig_Ready"
			table.insert(ready, result)
		elseif not ok then
			warn(`[CasualtyAsset] building casualty {i} failed: {result}`)
		end
	end
	loading = false
	failedAt = if #ready == 0 then os.clock() else nil
end

-- Starts the background build (server start).
function CasualtyAsset.preload()
	if #ready == 0 and not loading then
		task.spawn(load)
	end
end

-- A fresh dressed casualty (pivot at the feet, root anchored), or nil while building / after a failure.
function CasualtyAsset.clone(): Model?
	if #ready > 0 then
		nextPick = nextPick % #ready + 1
		local m = ready[nextPick]:Clone()
		m.Name = "CasualtyRig"
		return m
	end
	if not loading and (not failedAt or os.clock() - failedAt > CasualtyAsset.RETRY_AFTER) then
		CasualtyAsset.preload()
	end
	return nil
end

return CasualtyAsset
