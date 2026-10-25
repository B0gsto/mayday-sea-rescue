--!strict
-- SkyFlare: the Capsized Ferry's distress flare. OperationService calls SkyFlare.distress(position) when
-- the big call starts. (The Legendary / Epic call flares went with the rare variants, WP-20 2026-10-25.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("AudioConfig"))

local SkyFlare = {}

local LIFE = 22 -- seconds
local DISTRESS_RED = Color3.fromRGB(255, 70, 50)

local function skyFlare(position: Vector3, colour: Color3): Part
	local model = Instance.new("Model")
	model.Name = "DistressFlare"
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
	ball.Color = colour
	ball.Size = Vector3.new(8, 8, 8)
	ball.CFrame = CFrame.new(position + Vector3.new(0, 110, 0))
	ball.Parent = model
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Brightness = 3.5
	light.Range = 240
	light.Shadows = false
	light.Parent = ball
	task.delay(LIFE - 4, function()
		TweenService:Create(ball, TweenInfo.new(4), { Transparency = 1 }):Play()
		light.Enabled = false
		task.delay(4.2, function()
			model:Destroy()
		end)
	end)
	return ball
end

-- The Capsized Ferry's mayday: a red distress flare over the listing ferry and two blasts of
-- its horn, heard across the bay.
function SkyFlare.distress(position: Vector3)
	local ball = skyFlare(position, DISTRESS_RED)
	local horn = Instance.new("Sound")
	horn.Name = "FerryHorn"
	horn.SoundId = AudioConfig.id("Horn_Ferry")
	horn.Volume = 1
	horn.RollOffMaxDistance = 3000
	horn.Parent = ball
	horn:Play()
end

return SkyFlare
