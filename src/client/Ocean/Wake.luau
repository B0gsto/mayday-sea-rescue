--!strict
-- Wake: hull foam and wake trails behind moving boats (ocean round 3), client-local only.
-- Boats are found without touching boat code: any workspace Model holding a VehicleSeat whose
-- seat sits near sea level. Coordination is attributes only:
--   Model attribute OceanWake = false   opt out (e.g. aircraft that carry a VehicleSeat)
--   Model attribute OceanWakeWidth      wake width in studs (default from the model's bounding box)
-- Per boat: a Trail between two stern attachments at the waterline (white foam texture, fading
-- with age) plus a bow-wave ParticleEmitter whose rate follows the boat's speed.
-- Wake Trails (RP-M5): the look follows the owner's "Cos_Wake" cosmetic (model attribute Owner =
-- UserId -> that player's Cos_Wake -> the option's `style` -> Boat/Wake.visual). Re-applied on the
-- scan when the choice or the night factor changes; same two instances per boat (no perf cost).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))
local OceanQuality = require(script.Parent:WaitForChild("OceanQuality"))
local WakeMath = require(Shared:WaitForChild("Boat"):WaitForChild("Wake"))

-- FX1: the wake ribbon foam map (U along the wake) and the bow-sheet spray flipbook; the stock
-- ocean_foam / smoke textures stay until the uploads exist.
local FOAM_ID = if Flipbooks.uploaded("FX_Foam_WakeRibbon")
	then Flipbooks.id("FX_Foam_WakeRibbon")
	else "rbxassetid://107434961132990" -- ocean_foam (approved)
-- A sheet's spray fills about 60 % of its cell, the stock smoke blob nearly all of it.
local BOW_SIZE = if Flipbooks.uploaded("FX_Spray_BowSheet") then 1.7 else 1
local tierScale = 1 -- docs/06 3.5 spray budget for the current ocean tier, refreshed on the scan
local SCAN_PERIOD = 1.0
local MIN_SPEED, FULL_SPEED = 3, 40 -- studs/s -- tune

type Rig = {
	model: Model,
	part: BasePart,
	trail: Trail,
	bow: ParticleEmitter,
	folder: Folder,
	a0: Attachment,
	a1: Attachment,
	centre: Vector3, -- stern waterline centre (part space)
	baseWidth: number,
	styleId: string?,
	night: number,
	bowRate: number,
}

local Wake = {}
local rigs: { [Model]: Rig } = {}
local seaY = 0

local function build(model: Model, seat: BasePart): Rig?
	local cf, size = model:GetBoundingBox()
	local width = model:GetAttribute("OceanWakeWidth")
	local w = if type(width) == "number"
		then width
		else math.clamp(math.min(size.X, size.Z) * 0.8, 2, 16)
	local len = math.max(size.X, size.Z)
	local part = model.PrimaryPart or seat
	local folder = Instance.new("Folder")
	folder.Name = "OceanWakeRig"
	-- Attachments in the part's space at the stern waterline (stern = the part's +Z, Roblox's back).
	local back = part.CFrame:PointToObjectSpace(cf.Position + part.CFrame.LookVector * (-len * 0.5))
	local waterLocal = part.CFrame:PointToObjectSpace(Vector3.new(0, seaY + 0.15, 0)).Y
	local a0 = Instance.new("Attachment")
	a0.Name = "OceanWakeL"
	a0.Position = Vector3.new(back.X - w * 0.5, waterLocal, back.Z)
	local a1 = Instance.new("Attachment")
	a1.Name = "OceanWakeR"
	a1.Position = Vector3.new(back.X + w * 0.5, waterLocal, back.Z)
	a0.Parent, a1.Parent = part, part
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Texture = FOAM_ID
	trail.TextureMode = Enum.TextureMode.Static
	trail.LightInfluence = 1
	trail.FaceCamera = false
	trail.Lifetime = 3.5
	trail.MinLength = 0.5
	trail.WidthScale =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 2.6) })
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(Color3.fromHex("#E8EEEC"))
	trail.Enabled = false
	trail.Parent = folder
	local front = part.CFrame:PointToObjectSpace(cf.Position + part.CFrame.LookVector * (len * 0.5))
	local ab = Instance.new("Attachment")
	ab.Name = "OceanBow"
	ab.Position = Vector3.new(front.X, waterLocal, front.Z)
	ab.Parent = part
	local bow = Instance.new("ParticleEmitter")
	Flipbooks.apply(bow, "FX_Spray_BowSheet")
	bow.Rotation = NumberRange.new(-12, 12)
	bow.Drag = 0.6
	bow.Color = ColorSequence.new(Color3.fromHex("#E2E8E6"))
	bow.LightInfluence = 1
	bow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 3.5),
	})
	bow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	bow.Lifetime = NumberRange.new(0.6, 1.2)
	bow.Speed = NumberRange.new(2, 6)
	bow.SpreadAngle = Vector2.new(70, 20)
	bow.Acceleration = Vector3.new(0, -12, 0)
	bow.Rate = 0
	bow.Parent = ab
	folder.Parent = part
	return {
		model = model,
		part = part,
		trail = trail,
		bow = bow,
		folder = folder,
		a0 = a0,
		a1 = a1,
		centre = Vector3.new(back.X, waterLocal, back.Z),
		baseWidth = w,
		styleId = nil,
		night = -1,
		bowRate = WakeMath.BOW_RATE,
	}
end

-- The owner's Wake cosmetic id (nil = no owner / standard).
local function styleIdOf(model: Model): string?
	local owner = model:GetAttribute("Owner")
	if type(owner) ~= "number" then
		return nil
	end
	local p = Players:GetPlayerByUserId(owner)
	local id = p and p:GetAttribute(Cosmetics.attribute("Wake"))
	return if type(id) == "string" then id else nil
end

local function applyStyle(rig: Rig, night: number)
	local id = styleIdOf(rig.model)
	if id == rig.styleId and math.abs(night - rig.night) < 0.02 then
		return
	end
	rig.styleId, rig.night = id, night
	local option = if id then Cosmetics.option("Wake", id) else nil
	local style = option and option.style
	local v = WakeMath.visual(if type(style) == "table" then style else nil, night)
	local half = rig.baseWidth * v.width * 0.5
	rig.a0.Position = rig.centre - Vector3.new(half, 0, 0)
	rig.a1.Position = rig.centre + Vector3.new(half, 0, 0)
	local trail = rig.trail
	trail.Lifetime = v.lifetime
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, v.widthStart),
		NumberSequenceKeypoint.new(1, v.spread),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, v.transparency[1]),
		NumberSequenceKeypoint.new(v.hold, v.transparency[2]),
		NumberSequenceKeypoint.new(1, v.transparency[3]),
	})
	trail.Color = ColorSequence.new(v.color)
	trail.LightEmission = v.lightEmission
	trail.LightInfluence = v.lightInfluence
	local bow = rig.bow
	bow.Color = ColorSequence.new(v.bowColor)
	bow.LightEmission = v.lightEmission * 0.6
	bow.LightInfluence = v.lightInfluence
	bow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, v.bowSize[1] * BOW_SIZE),
		NumberSequenceKeypoint.new(1, v.bowSize[2] * BOW_SIZE),
	})
	bow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, v.bowTransparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	bow.Lifetime = NumberRange.new(v.bowLife[1], v.bowLife[2])
	bow.Speed = NumberRange.new(v.bowSpeed[1], v.bowSpeed[2])
	bow.SpreadAngle = Vector2.new(v.bowSpread[1], v.bowSpread[2])
	rig.bowRate = v.bowRate
end

local function scan()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("VehicleSeat") then
			local model = d:FindFirstAncestorOfClass("Model")
			if
				model
				and not rigs[model]
				and model:GetAttribute("OceanWake") ~= false
				and math.abs(d.Position.Y - seaY) < 8
			then
				local ok, rig = pcall(build, model, d)
				if ok and rig then
					rigs[model] = rig
				end
			end
		end
	end
	local night = WakeMath.nightFactor(Lighting:GetSunDirection().Y)
	tierScale = Flipbooks.scale("spray", OceanQuality.current().name)
	for model, rig in rigs do
		if not model.Parent or not rig.part.Parent then
			rig.folder:Destroy()
			rigs[model] = nil
		else
			applyStyle(rig, night)
		end
	end
end

function Wake.start(seaLevel: number)
	seaY = seaLevel
	local nextScan = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + SCAN_PERIOD
			scan()
		end
		for _, rig in rigs do
			local v = rig.part.AssemblyLinearVelocity
			local speed = Vector2.new(v.X, v.Z).Magnitude
			local afloat = math.abs(rig.part.Position.Y - seaY) < 8
			local s = if afloat
				then math.clamp((speed - MIN_SPEED) / (FULL_SPEED - MIN_SPEED), 0, 1)
				else 0
			rig.trail.Enabled = s > 0
			rig.bow.Rate = rig.bowRate * s * tierScale
		end
	end)
end

return Wake
