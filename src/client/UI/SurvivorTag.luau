--!strict
-- SurvivorTag (docs/25 J + K1): the one name tag over every survivor, coloured by rarity (Mythic
-- cycles a rainbow) and, from Epic up in the water, a tall light beam readable from far. Reads the
-- K1 attributes (SurvivorName, Rarity 1-6, Category, Trait, Special, Workplace, Job) and falls back
-- to the WP-26 ones and the model's Name / Common, so a half-migrated server never errors.
--   SurvivorTag.info(model) -> properties for the card
--   SurvivorTag.attach(model, inWater?) -> one BillboardGui per model, destroyed with it
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Style = require(script.Parent:WaitForChild("Kit"):WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Kit"):WaitForChild("Theme"))

local SurvivorTag = {}

local TAG = "SurvivorNameTag"
local BEAM = "SurvivorBeam"
local MAX_DISTANCE = 250 -- studs: a name and a beam read across the bay
local NAME_W, NAME_H = 6, 1.5 -- studs (BillboardGui size is in studs: it shrinks with distance)
local LIFT = 4.2 -- studs over the root, clear of the head
local BEAM_H = 150
local EPIC = 4
local WORK = { 1, 1.25, 1.6, 2.2, 3, 5 } -- docs/25 E work value by tier

local CATEGORY_NAME = { Gatherer = "Fisher" }
local TRAIT_NAME = { NightOwl = "Night owl" }
local EFFECT = {
	Builder = "Build speed",
	Hauler = "Depot refill",
	Gatherer = "Cash per min",
	Mechanic = "Craft speed",
	Medic = "Call pay",
	Rescuer = "Trip cash",
}

export type Info = {
	name: string,
	rarity: number,
	rarityName: string,
	color: Color3,
	category: string,
	typeName: string,
	trait: string,
	traitName: string,
	special: string,
	job: string,
	workplace: string,
	workplaceName: string,
	effect: string,
	work: number,
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF5C5C")),
	ColorSequenceKeypoint.new(0.2, Color3.fromHex("FFC83A")),
	ColorSequenceKeypoint.new(0.4, Color3.fromHex("5BE356")),
	ColorSequenceKeypoint.new(0.6, Color3.fromHex("4FB8FF")),
	ColorSequenceKeypoint.new(0.8, Color3.fromHex("B07CFF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("FF5CB8")),
})

local function text(model: Model, ...: string): string
	for _, key in { ... } do
		local value = model:GetAttribute(key)
		if type(value) == "string" then
			return value
		end
	end
	return ""
end

local function rarityOf(model: Model): number
	for _, key in { "Rarity", "WorkerRarity" } do
		local value = model:GetAttribute(key)
		if type(value) == "number" then
			return math.clamp(math.floor(value), 1, Rarity.MYTHIC)
		end
	end
	return Rarity.COMMON
end

function SurvivorTag.info(model: Model): Info
	local rarity = rarityOf(model)
	local tier = Rarity.TIERS[rarity]
	local category = text(model, "Category", "WorkerCategory")
	local trait = text(model, "Trait")
	local workplace = text(model, "Workplace")
	local name = text(model, "SurvivorName", "WorkerName")
	local building = if workplace ~= "" then DockConfig.Buildings[workplace] else nil
	return {
		name = if name ~= "" then name else model.Name,
		rarity = rarity,
		rarityName = tier.name,
		color = tier.color,
		category = category,
		typeName = CATEGORY_NAME[category] or category,
		trait = trait,
		traitName = if trait ~= "" then (TRAIT_NAME[trait] or trait) else "",
		special = text(model, "Special"),
		job = text(model, "Job"),
		workplace = workplace,
		workplaceName = if workplace == ""
			then "Waiting"
			elseif building then building.name
			else workplace,
		effect = EFFECT[category] or "",
		work = WORK[rarity] or 1,
	}
end

local function rootOf(model: Model): BasePart?
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

-- Two attachments and a soft beam going up from the root: Epic purple, Legendary gold, Mythic rainbow.
-- No texture, so it draws as solid light; FaceCamera keeps it visible from every angle.
local function makeBeam(root: BasePart): Beam
	local old = root:FindFirstChild(BEAM)
	if old and old:IsA("Beam") then
		return old
	end
	local bottom = Instance.new("Attachment")
	bottom.Name = TAG .. "Bottom"
	bottom.Position = Vector3.new(0, 0.2, 0)
	bottom.Parent = root
	local top = Instance.new("Attachment")
	top.Name = TAG .. "Top"
	top.Position = Vector3.new(0, BEAM_H, 0)
	top.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = BEAM
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.Width0 = 3.5
	beam.Width1 = 0.8
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Segments = 1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Brightness = 2
	beam.Enabled = false
	beam.Parent = root
	return beam
end

function SurvivorTag.attach(model: Model, inWater: boolean?): BillboardGui?
	if not model:IsA("Model") then
		return nil
	end
	local existing = model:FindFirstChild(TAG)
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	local root = rootOf(model)
	if not root then
		return nil
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = TAG
	gui.Adornee = root
	gui.Size = UDim2.fromScale(NAME_W, NAME_H)
	gui.StudsOffsetWorldSpace = Vector3.new(0, LIFT, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = model

	local label = Style.label(gui, "", Theme.Text.heading)
	label.Name = "Name"
	label.TextScaled = true
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 64
	cap.MinTextSize = 8
	cap.Parent = label
	local rainbow = Instance.new("UIGradient")
	rainbow.Color = RAINBOW
	rainbow.Enabled = false
	rainbow.Parent = label

	local beam = if inWater == true then makeBeam(root) else nil
	local spinning = false

	local function paint()
		local info = SurvivorTag.info(model)
		label.Text = info.name
		local mythic = info.rarity >= Rarity.MYTHIC
		rainbow.Enabled = mythic
		label.TextColor3 = if mythic then Color3.new(1, 1, 1) else info.color
		if mythic and not spinning then
			spinning = true
			task.spawn(function()
				while rainbow.Parent and rainbow.Enabled do
					rainbow.Rotation = (os.clock() * 70) % 360
					task.wait(1 / 30)
				end
				spinning = false
			end)
		end
		if beam then
			beam.Color = if mythic then RAINBOW else ColorSequence.new(info.color)
			beam.Enabled = info.rarity >= EPIC and model:GetAttribute("OnVehicle") == nil
		end
	end
	paint()

	local conns: { RBXScriptConnection } = {}
	for _, key in { "SurvivorName", "WorkerName", "Rarity", "WorkerRarity", "OnVehicle" } do
		table.insert(conns, model:GetAttributeChangedSignal(key):Connect(paint))
	end
	gui.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
	end)
	return gui
end

-- A wildlife call dresses the same victim model as an animal: drop a tag that was drawn first.
function SurvivorTag.remove(model: Model)
	local gui = model:FindFirstChild(TAG)
	if gui then
		gui:Destroy()
	end
	local root = rootOf(model)
	if not root then
		return
	end
	local beam = root:FindFirstChild(BEAM)
	if beam then
		beam:Destroy()
	end
	for _, name in { TAG .. "Bottom", TAG .. "Top" } do
		local attachment = root:FindFirstChild(name)
		if attachment then
			attachment:Destroy()
		end
	end
end

return SurvivorTag
