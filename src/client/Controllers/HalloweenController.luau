--!strict
-- HalloweenController: the client side of the Ghost Ship seasonal event (docs/15 H7). Reads
-- ReplicatedStorage.HalloweenState (HalloweenService) plus the per-player Halloween_State view,
-- builds World/HalloweenWorld (pumpkins, the spectral ferry, the stall with its clock and days left,
-- white sheets over the Ghost Ship casualties) and turns the world to a purple-green foggy night
-- only during the nightly window (a Ghost Ship call, or the 15-minute witching hour at :45; config
-- in Config/SeasonalEvents). Onboarding players (cold open + first three calls) keep the day.
-- The stall's world prompts call Halloween_Buy; the server checks the distance and the candy.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local HalloweenWorld =
	require(script.Parent.Parent:WaitForChild("World"):WaitForChild("HalloweenWorld"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))
local WeatherController = require(script.Parent:WaitForChild("WeatherController"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local SeasonalEvents = require(Shared:WaitForChild("Config"):WaitForChild("SeasonalEvents"))
local SeasonalRules = require(Shared:WaitForChild("SeasonalRules"))

local EVENT = SeasonalEvents.Halloween
local player = Players.LocalPlayer

-- RP-P1: the pumpkins, ferry lanterns and stall wares light 23 PointLights at High. Keep the
-- nearest (first built) ones only on the lower tiers; the Neon parts still read.
local LIGHT_CAP = { High = 99, Medium = 14, Low = 6 }

local TICK = 0.25
local FOG_DENSITY = 0.5
local FOG_HAZE = 2.6
local FOG_COLOR = Color3.fromRGB(78, 58, 108) -- purple
local FOG_DECAY = Color3.fromRGB(46, 96, 70) -- green

local HalloweenController = {}
HalloweenController.Priority = 112 -- after EventController: the night and fog override run last

local folder: Folder
local state: { [string]: any } = { candy = 0, owned = {} }
local world: HalloweenWorld.World? = nil
local worldRoot: Instance? = nil
local atmosphere: Atmosphere? = nil
local night = false
local prevWitching: boolean? = nil
local prevGhost: boolean? = nil

local function attr(name: string, default: any): any
	local value = folder:GetAttribute(name)
	return if value == nil then default else value
end

-- The event's neon lanterns stay lit by day, just dimmer (stored once per light).
local function dimWorld(on: boolean)
	if not worldRoot then
		return
	end
	for _, d in worldRoot:GetDescendants() do
		if d:IsA("PointLight") then
			local base = d:GetAttribute("BaseBrightness")
			if type(base) ~= "number" then
				base = d.Brightness
				d:SetAttribute("BaseBrightness", base)
			end
			local brightness = base :: number
			d.Brightness = if on then brightness else brightness * 0.3
		end
	end
end

local function ghostLightOn(): boolean
	local events = ReplicatedStorage:FindFirstChild("EventState")
	return events ~= nil
		and events:GetAttribute("Event") == "GhostLight"
		and events:GetAttribute("Phase") == "Active"
end

local function setNight(on: boolean)
	if night == on then
		return
	end
	night = on
	-- another live event (Ghost Light) may be keeping the night; its own controller owns that
	WeatherController.SetBasePreset(if on or ghostLightOn() then "Night" else "Clear")
	dimWorld(on)
end

local function buy(itemId: string)
	local net = ReplicatedStorage:FindFirstChild("Net")
	local buyFn = net and net:FindFirstChild("Halloween_Buy")
	if not buyFn or not buyFn:IsA("RemoteFunction") then
		return
	end
	local ok, granted = pcall(function()
		return buyFn:InvokeServer(itemId)
	end)
	AudioController.play(if ok and granted == true then "UI_Pickup" else "UI_Fail")
end

local function capLights(root: Instance)
	local left = LIGHT_CAP[OceanQuality.current().name] or LIGHT_CAP.High
	for _, d in root:GetDescendants() do
		if d:IsA("PointLight") then
			left -= 1
			if left < 0 then
				d:Destroy()
			end
		end
	end
end

local function build()
	if world then
		return
	end
	world = HalloweenWorld.build(Workspace, { buy = buy })
	worldRoot = Workspace:FindFirstChild("HalloweenWorld")
	if worldRoot then
		capLights(worldRoot)
		dimWorld(night)
	end
end

local function close()
	if world then
		world.destroy()
		world = nil
		worldRoot = nil
	end
	-- a Ghost Light running at the same time keeps its night; otherwise give the day back
	WeatherController.SetBasePreset(if ghostLightOn() then "Night" else "Clear")
	night = false
end

function HalloweenController.Init()
	-- a quality drop mid-event trims the lanterns too (they are only removed, never re-added)
	OceanQuality.onChanged(function()
		if worldRoot then
			capLights(worldRoot)
		end
	end)
	folder = ReplicatedStorage:WaitForChild("HalloweenState")
	local net = ReplicatedStorage:WaitForChild("Net")
	local remote = net:WaitForChild("Halloween_State", 30) :: RemoteEvent?
	if remote then
		remote.OnClientEvent:Connect(function(view)
			if type(view) == "table" then
				state = view
			end
		end)
	end
	local getFn = net:WaitForChild("Halloween_Get", 30) :: RemoteFunction?
	if getFn then
		task.spawn(function()
			local ok, view = pcall(function()
				return getFn:InvokeServer()
			end)
			if ok and type(view) == "table" then
				state = view
			end
		end)
	end
end

function HalloweenController.Start()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

	RunService.RenderStepped:Connect(function()
		if not night or not atmosphere then
			return
		end
		atmosphere.Density = math.max(atmosphere.Density, FOG_DENSITY)
		atmosphere.Haze = math.max(atmosphere.Haze, FOG_HAZE)
		atmosphere.Glare = math.min(atmosphere.Glare, 0.05)
		atmosphere.Color = atmosphere.Color:Lerp(FOG_COLOR, 0.35)
		atmosphere.Decay = atmosphere.Decay:Lerp(FOG_DECAY, 0.35)
	end)

	while true do
		if attr("Active", false) == true then
			build()
			local onboarding = Onboarding.newPlayerHud(
				player:GetAttribute("ColdOpenDone") == true,
				player:GetAttribute("OpsCompletedTotal") :: number?
			)
			local now = attr("Now", os.time()) :: number
			local ghost = attr("GhostShipOp", "") ~= ""
			local witching = SeasonalRules.witching(EVENT, now)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local at = if root and root:IsA("BasePart") then root.Position else Vector3.zero
			if prevWitching ~= nil then
				if witching and not prevWitching and not onboarding then
					AudioController.play("Wind_Light", at + Vector3.new(60, 25, 0), 0.45, 0.9)
					AudioController.play("Bell_Buoy", at + Vector3.new(180, 10, 0), 0.6, 0.8)
					AudioController.play("Halloween_Sting", nil, 1, 1)
				end
				if ghost and not prevGhost then
					AudioController.play("GhostShip_Call", at + Vector3.new(0, 40, -80), 1, 0.9)
				end
			end
			prevWitching = witching
			prevGhost = ghost
			setNight(SeasonalRules.night(EVENT, now, ghost, onboarding))
			if world then
				world.update(
					Workspace:GetServerTimeNow(),
					attr("DaysLeft", 0) :: number,
					state.candy or 0,
					state.owned or {},
					attr("GhostShipOp", "") :: string
				)
			end
		else
			close()
		end
		task.wait(TICK)
	end
end

return HalloweenController
