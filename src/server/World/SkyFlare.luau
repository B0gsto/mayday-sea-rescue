--!strict
-- SkyFlare: the Legendary / Epic call moment (docs/15 H2), kept when the Rescue Album was cut
-- (docs/16 C13). OperationService calls SkyFlare.announce(op) when a call with a variant appears,
-- and SkyFlare.distress(position) when the Capsized Ferry big call starts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("AudioConfig"))
local RescueVariants = require(Config:WaitForChild("RescueVariants"))

local SkyFlare = {}

-- A Legendary call: a gold flare in the sky over the scene for a full minute, a gold beam
-- standing on the spot that reads across the map. An Epic gets the smaller flare (no beam). Nothing else is said (docs/15 section 1: an icon, no text).
local FLARE_SECONDS = 60
local EPIC_SECONDS = 22

local GOLD = Color3.fromRGB(255, 214, 90)
local DISTRESS_RED = Color3.fromRGB(255, 70, 50)

local function skyFlare(position: Vector3, legendary: boolean, colour: Color3?): Part
	local at = position + Vector3.new(0, 110, 0)
	local model = Instance.new("Model")
	model.Name = if legendary then "LegendaryFlare" else "EpicFlare"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = Workspace
	local ball = Instance.new("Part")
	ball.Name = "Flare"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = colour or GOLD
	local size = if legendary then 14 else 8
	ball.Size = Vector3.new(size, size, size)
	ball.CFrame = CFrame.new(at)
	ball.Parent = model
	local light = Instance.new("PointLight")
	light.Color = colour or Color3.fromRGB(255, 202, 80)
	light.Brightness = if legendary then 7 else 3.5
	light.Range = if legendary then 500 else 240
	light.Shadows = false
	light.Parent = ball
	local beams: { Part } = {}
	if legendary then
		local beam = Instance.new("Part")
		beam.Name = "Beam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 210, 96)
		beam.Transparency = 0.45
		beam.Size = Vector3.new(240, 3, 3)
		beam.CFrame = CFrame.new(at + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		beam.Parent = model
		table.insert(beams, beam)

		-- the beam from the spot itself: a gold column from the sea to well above the sky flare
		local column = Instance.new("Part")
		column.Name = "LightBeam"
		column.Anchored = true
		column.CanCollide = false
		column.CanQuery = false
		column.CanTouch = false
		column.CastShadow = false
		column.Material = Enum.Material.Neon
		column.Color = Color3.fromRGB(255, 214, 110)
		column.Transparency = 0.3
		column.Size = Vector3.new(16, 520, 16)
		column.CFrame = CFrame.new(position + Vector3.new(0, 260, 0))
		column.Parent = model
		table.insert(beams, column)
	end
	local life = if legendary then FLARE_SECONDS else EPIC_SECONDS
	task.delay(life - 4, function()
		TweenService:Create(ball, TweenInfo.new(4), { Transparency = 1 }):Play()
		for _, beam in beams do
			TweenService:Create(beam, TweenInfo.new(4), { Transparency = 1 }):Play()
		end
		light.Enabled = false
		task.delay(4.2, function()
			model:Destroy()
		end)
	end)
	return ball
end

function SkyFlare.announce(op: any)
	local variant = RescueVariants.ById(op.variant)
	if not variant then
		return
	end
	local legendary = variant.rarity == "Legendary"
	if not legendary and variant.rarity ~= "Epic" then
		return
	end
	skyFlare(op.position, legendary)
end

-- The Capsized Ferry's mayday: a red distress flare over the listing ferry and two blasts of
-- its horn, heard across the bay.
function SkyFlare.distress(position: Vector3)
	local ball = skyFlare(position, false, DISTRESS_RED)
	local horn = Instance.new("Sound")
	horn.Name = "FerryHorn"
	horn.SoundId = AudioConfig.id("Horn_Ferry")
	horn.Volume = 1
	horn.RollOffMaxDistance = 3000
	horn.Parent = ball
	horn:Play()
end

return SkyFlare
