--!strict
-- EventController: the client side of the server-clock events (docs/15 H1). Reads
-- ReplicatedStorage.EventState (EventService): the Great Storm's harbour siren and the Ghost
-- Light's night fog. The clocks are rows in the phone's Events app (EventCalendar), not HUD chips. Late joiners read the same attributes, so they join
-- the event in progress.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local WeatherController = require(script.Parent:WaitForChild("WeatherController"))

local TICK = 0.2
local FOG_DENSITY = 0.55
local FOG_HAZE = 2.2

local EventController = {}
EventController.Priority = 110 -- after WeatherController: the fog override runs after its blend

local folder: Folder
local atmosphere: Atmosphere?
local ghost = false
local lastSiren = 0

local function attr(name: string, default: any): any
	local value = folder:GetAttribute(name)
	return if value == nil then default else value
end

local function setGhost(on: boolean)
	if ghost == on then
		return
	end
	ghost = on
	if on then
		WeatherController.SetBasePreset("Night")
	else
		WeatherController.SetBasePreset("Overcast")
	end
end

function EventController.Init()
	folder = ReplicatedStorage:WaitForChild("EventState")
end

function EventController.Start()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

	RunService.RenderStepped:Connect(function()
		if ghost and atmosphere then
			-- WeatherController rewrites the atmosphere from its presets; the fog wins per frame
			atmosphere.Density = math.max(atmosphere.Density, FOG_DENSITY)
			atmosphere.Haze = math.max(atmosphere.Haze, FOG_HAZE)
			atmosphere.Glare = math.min(atmosphere.Glare, 0.05)
		end
	end)

	while true do
		local event = attr("Event", "") :: string
		local phase = attr("Phase", "") :: string
		local startAt = attr("StartAt", 0) :: number
		if event == "GreatStorm" and phase == "Before" and startAt ~= lastSiren then
			lastSiren = startAt
			AudioController.play("Siren_HiLo", nil, 0.55)
		end
		setGhost(event == "GhostLight" and phase == "Active")
		task.wait(TICK)
	end
end

return EventController
