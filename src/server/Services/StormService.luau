--!strict
-- StormService: the server-authoritative storm cycle Calm -> Warning -> Storm -> Clearing -> Calm
-- (GameConfig.Storm timings, docs 06 section 3.4). The continuous state lives in attributes on
-- ReplicatedStorage.Weather (read them through src/shared/Weather.luau); Net StormChanged is only
-- a one-shot cue per phase change: { state, stormId, isGreatStorm, duration, windDirection }.
--
-- API:
--   StormService.ForceStorm(isGreat: boolean?, skipWarning: boolean?)  -- start a storm now
--   StormService.ForceCalm()                                           -- end any storm now
-- Dev chat commands (Studio only): /storm, /storm now, /greatstorm, /calm.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Weather = require(Shared:WaitForChild("Weather"))
local WeatherMath = require(Shared:WaitForChild("WeatherMath"))

local TICK_SECONDS = 0.25
local INTENSITY_PUBLISH_SECONDS = 1 -- the Intensity attribute is informational (debug, tools)

local StormService = {}
StormService.Priority = 20 -- before services that read the weather in their Init

local folder: Folder
local state: string = "Calm"
local stateStart = 0
local stateDuration = 0
local stormId = 0
local isGreat = false
local wind = 0

local function publish()
	-- State last: clients fire Weather.changed on it, and the rest should already be in place.
	folder:SetAttribute("StateStartTime", stateStart)
	folder:SetAttribute("StateDuration", stateDuration)
	folder:SetAttribute("StormId", stormId)
	folder:SetAttribute("WindDirection", wind)
	folder:SetAttribute("IsGreatStorm", isGreat)
	folder:SetAttribute("State", state)
	-- Server-side readers of Weather see the change now, not after deferred attribute signals.
	Weather._apply({
		State = state,
		StateStartTime = stateStart,
		StateDuration = stateDuration,
		StormId = stormId,
		WindDirection = wind,
		IsGreatStorm = isGreat,
	})
end

local function cue()
	Net.event("StormChanged"):FireAllClients({
		state = state,
		stormId = stormId,
		isGreatStorm = isGreat,
		duration = stateDuration,
		windDirection = wind,
	})
end

local function enter(nextState: string, now: number?)
	if nextState == "Warning" then
		-- A new storm: new id, new wind.
		stormId += 1
		wind = WeatherMath.windForStorm(stormId)
	elseif nextState == "Calm" then
		isGreat = false
	end
	state = nextState
	stateStart = now or Workspace:GetServerTimeNow()
	stateDuration = WeatherMath.durationFor(state, isGreat, GameConfig.Storm)
	publish()
	cue()
	print(
		`[StormService] {state} for {stateDuration}s (storm {stormId}{if isGreat
			then ", GREAT"
			else ""})`
	)
end

-- Starts a storm. From Calm or Clearing it begins a new storm at Warning (or straight at Storm
-- with skipWarning). During Warning it only upgrades to a Great Storm. During a Storm, a Great
-- Storm request stretches the current phase to the Great Storm length.
function StormService.ForceStorm(great: boolean?, skipWarning: boolean?)
	local wantGreat = great == true
	if state == "Calm" or state == "Clearing" then
		isGreat = wantGreat
		enter("Warning")
		if skipWarning then
			enter("Storm")
		end
	elseif state == "Warning" then
		isGreat = isGreat or wantGreat
		if skipWarning then
			enter("Storm")
		else
			publish()
		end
	elseif state == "Storm" and wantGreat and not isGreat then
		isGreat = true
		stateDuration = WeatherMath.durationFor("Storm", true, GameConfig.Storm)
		publish()
		cue()
	end
end

function StormService.ForceCalm()
	if state ~= "Calm" then
		enter("Calm")
	end
end

local function runCommand(player: Player?, text: string)
	local command, arg = string.match(string.lower(text), "^%s*/(%a+)%s*(%a*)")
	if command == "storm" then
		StormService.ForceStorm(false, arg == "now")
	elseif command == "greatstorm" then
		StormService.ForceStorm(true, arg == "now")
	elseif command == "calm" then
		StormService.ForceCalm()
	else
		return
	end
	print(`[StormService] dev command /{command} {arg} by {if player then player.Name else "?"}`)
end

local function setupDevCommands()
	if not RunService:IsStudio() then
		return
	end
	-- Studio-only hook for play-test scripts (execute_luau runs in its own module cache, so it
	-- can't call this service directly): ServerStorage.Storm_DevCommand:Invoke("/storm now").
	local devHook = Instance.new("BindableFunction")
	devHook.Name = "Storm_DevCommand"
	devHook.OnInvoke = function(text: string)
		runCommand(nil, text)
		return Weather.getState()
	end
	devHook.Parent = game:GetService("ServerStorage")
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
		for _, alias in { "/storm", "/greatstorm", "/calm" } do
			local command = Instance.new("TextChatCommand")
			command.Name = `Storm_Dev{string.sub(alias, 2)}`
			command.PrimaryAlias = alias
			command.Triggered:Connect(function(source: TextSource, message: string)
				runCommand(Players:GetPlayerByUserId(source.UserId), message)
			end)
			command.Parent = parent
		end
	else
		local function hook(player: Player)
			player.Chatted:Connect(function(message: string)
				runCommand(player, message)
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, player in Players:GetPlayers() do
			hook(player)
		end
	end
end

function StormService.Init()
	local existing = ReplicatedStorage:FindFirstChild(Weather.FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = Weather.FOLDER_NAME
	end
	state = "Calm"
	stateStart = Workspace:GetServerTimeNow()
	stateDuration = WeatherMath.durationFor("Calm", false, GameConfig.Storm)
	wind = WeatherMath.windForStorm(0)
	publish()
	folder:SetAttribute("Intensity", 0)
	folder.Parent = ReplicatedStorage -- parent after the attributes so clients see a full set
	setupDevCommands()
end

function StormService.Start()
	local sinceIntensity = 0
	local lastIntensity = -1
	while true do
		local dt = task.wait(TICK_SECONDS)
		local now = Workspace:GetServerTimeNow()
		if now >= stateStart + stateDuration then
			-- Chain from the scheduled end, so a slow tick never drifts the cycle.
			enter(WeatherMath.nextState(state), math.min(now, stateStart + stateDuration))
		end
		sinceIntensity += dt
		if sinceIntensity >= INTENSITY_PUBLISH_SECONDS then
			sinceIntensity = 0
			local intensity = math.floor(Weather.getIntensity(now) * 100 + 0.5) / 100
			if intensity ~= lastIntensity then
				lastIntensity = intensity
				folder:SetAttribute("Intensity", intensity)
			end
		end
	end
end

return StormService
