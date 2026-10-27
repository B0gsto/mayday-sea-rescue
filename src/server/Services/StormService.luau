--!strict
-- StormService: the server-authoritative storm cycle Calm -> Warning -> Storm -> Clearing -> Calm
-- (GameConfig.Storm timings, docs 06 section 3.4). The continuous state lives in attributes on
-- ReplicatedStorage.Weather (read them through src/shared/Weather.luau); Net StormChanged is only
-- a one-shot cue per phase change: { state, stormId, isGreatStorm, duration, windDirection }.
--
-- API:
--   StormService.ForceStorm(isGreat: boolean?, skipWarning: boolean?, warningSeconds?: number)
--   StormService.ForceCalm()                                           -- end any storm now
--   StormService.QueueSummon(player, tier) -> (ok, reason)  use one of the player's Storm Tickets
-- Dev chat commands (Studio only): /storm, /storm now, /greatstorm, /calm.
-- Day/night: every client runs Lighting.ClockTime from DayClock itself (WeatherController; the dev offset is the Workspace
-- attribute DayClockOffset, DevService "clock"); the server writes it only every 10 s for its own readers (CottageRig's
-- sun check), the same value clients compute. Storms blend over it on the client.
--
-- Storm Summon (RP-M2, docs/04 section 5): the Call the Storm / Call the Great Storm products grant a
-- Storm Ticket on the profile (flag shop.ticketStorm / ticketGreat) and queue it. The ticket is used up
-- only when its storm starts, so a storm that never runs (queue full, buyer left, server shut down)
-- stays a ticket the player can use in any server. Queue of two; at least 8 minutes between summoned
-- storms and none within 2 minutes of a natural storm; the natural storm clock is never reset.
-- Weather attributes: SummonQueue (number queued), SummonedBy (display name, "" when anonymous or
-- natural), GreatStormCallers (names, comma separated, for the station board). Player attribute
-- StormCaller = true for 24 hours after their storm starts. Both products are ready=false (docs/16 C9).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataService = require(script.Parent:WaitForChild("DataService"))
local DayClock = require(Shared:WaitForChild("DayClock"))
local Effects = require(Shared:WaitForChild("MonetizationEffects"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))
local Net = require(Shared:WaitForChild("Net"))
local Weather = require(Shared:WaitForChild("Weather"))
local WeatherMath = require(Shared:WaitForChild("WeatherMath"))

local TICK_SECONDS = 0.25
local INTENSITY_PUBLISH_SECONDS = 1 -- the Intensity attribute is informational (debug, tools)
-- Always sunny (user, 2026-10-22): Calm never rolls into a storm and summoned storms wait (their
-- tickets stay saved). ForceStorm (dev /storm) still runs a full cycle back to Calm.
local ALWAYS_SUNNY = true

local StormService = {}
StormService.Priority = 20 -- before services that read the weather in their Init

-- Dev board preview: storms roll on this server (ALWAYS_SUNNY off) until a dev sets Calm again.
local devStorms = false
local function sunny(): boolean
	return ALWAYS_SUNNY and not devStorms
end
function StormService.SetDevStorms(on: boolean)
	devStorms = on
end

local folder: Folder
local state: string = "Calm"
local stateStart = 0
local stateDuration = 0
local stormId = 0
local isGreat = false
local wind = 0

-- Storm Summon state (docs/04 section 5)
type Summon = { player: Player, tier: string }
local queue: { Summon } = {}
local current: Summon? = nil -- the summoned storm now running (nil for a natural storm)
local naturalEnd = -math.huge -- when the last natural storm cleared
local naturalWarningAt = 0 -- the natural clock: when the next natural storm is due
local lastSummonEnd = -math.huge
local greatCallers: { string } = {}

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

local function enter(nextState: string, now: number?, duration: number?)
	if nextState == "Warning" then
		-- A new storm: new id, new wind.
		stormId += 1
		wind = WeatherMath.windForStorm(stormId)
	elseif nextState == "Calm" then
		isGreat = false
	end
	local wasSummoned = current ~= nil
	state = nextState
	stateStart = now or Workspace:GetServerTimeNow()
	stateDuration = duration or WeatherMath.durationFor(state, isGreat, GameConfig.Storm)
	if nextState == "Calm" then
		if wasSummoned then
			-- back to the natural clock where it was (docs/04 section 5 rule 2)
			current = nil
			lastSummonEnd = stateStart
			stateDuration = math.max(Effects.Summon.NaturalBuffer, naturalWarningAt - stateStart)
		else
			naturalEnd = stateStart
		end
		naturalWarningAt = stateStart + stateDuration
	end
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
function StormService.ForceStorm(great: boolean?, skipWarning: boolean?, warningSeconds: number?)
	local wantGreat = great == true
	if state == "Calm" or state == "Clearing" then
		isGreat = wantGreat
		current = nil
		enter("Warning", nil, warningSeconds)
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

local function shopOf(player: Player): { [string]: any }?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local shop = data.flags.shop
	if type(shop) ~= "table" then
		shop = {}
		data.flags.shop = shop
	end
	return shop
end

local function publishQueue()
	if folder then
		folder:SetAttribute("SummonQueue", #queue)
	end
end

local function queuedBy(player: Player, tier: string): number
	local n = 0
	for _, entry in queue do
		if entry.player == player and entry.tier == tier then
			n += 1
		end
	end
	return n
end

-- Queues one of the player's unused Storm Tickets. Never takes a ticket here: it is used up only
-- when the storm starts.
function StormService.QueueSummon(player: Player, tier: string): (boolean, string)
	if not Effects.ticketField(tier) then
		return false, "BadTier"
	end
	local shop = shopOf(player)
	if not shop then
		return false, "NoData"
	end
	if Effects.tickets(shop, tier) <= queuedBy(player, tier) then
		return false, "NoTicket"
	end
	if #queue >= Effects.Summon.QueueMax then
		return false, "QueueFull"
	end
	table.insert(queue, { player = player, tier = tier })
	publishQueue()
	return true, "ok"
end

local function displayName(player: Player): string
	local shop = shopOf(player)
	return if shop and shop.anon == true then "" else player.DisplayName
end

local function startSummon(entry: Summon, pushNatural: boolean)
	local shop = shopOf(entry.player)
	if not shop or not Effects.takeTicket(shop, entry.tier) then
		return -- the ticket is gone (used elsewhere): nothing to run
	end
	DataService.MarkDirty(entry.player)
	task.spawn(DataService.Save, entry.player, false)
	local great = entry.tier == "GreatStorm"
	local now = Workspace:GetServerTimeNow()
	if pushNatural then
		naturalWarningAt = now
			+ Effects.summonSeconds(entry.tier, GameConfig.Storm :: any)
			+ Effects.Summon.NaturalBuffer
	end
	shop.callerHour = math.floor(os.time() / 3600) + Effects.Summon.CallerTitleHours
	entry.player:SetAttribute("StormCaller", true)
	local name = displayName(entry.player)
	folder:SetAttribute("SummonedBy", name)
	if great and name ~= "" then
		table.insert(greatCallers, name)
		folder:SetAttribute("GreatStormCallers", table.concat(greatCallers, ", "))
	end
	isGreat = great
	current = entry
	enter("Warning", now)
end

-- A new player's cold open holds a new storm back (OperationService.ColdOpenHoldsWeather).
-- Lazy: OperationService loads after this service.
local function coldOpenHold(): boolean
	local module = script.Parent:FindFirstChild("OperationService")
	local ok, ops = pcall(require, module :: ModuleScript)
	if not ok or type(ops) ~= "table" or type((ops :: any).ColdOpenHoldsWeather) ~= "function" then
		return false
	end
	local fine, held = pcall((ops :: any).ColdOpenHoldsWeather)
	return fine and held == true
end

-- A LiveOps CalmSeas hour holds every new storm (G60); the replicated state is written by
-- LiveOpsService, which also clears a storm already rolling when the hour starts.
local function liveOpsCalm(): boolean
	local live = ReplicatedStorage:FindFirstChild("LiveOpsState")
	return live ~= nil
		and live:GetAttribute("Event") == "CalmSeas"
		and live:GetAttribute("Phase") == "Active"
end

local function stepSummons(now: number)
	if sunny() or #queue == 0 or state ~= "Calm" then
		return
	end
	if liveOpsCalm() then
		return -- the relaxed hour: no storm, the paid queue waits (the ticket is not used)
	end
	local head = queue[1]
	local decision = Effects.summonDecision({
		state = state,
		now = now,
		naturalEnd = naturalEnd,
		naturalWarningAt = naturalWarningAt,
		lastSummonEnd = lastSummonEnd,
		total = Effects.summonSeconds(head.tier, GameConfig.Storm :: any),
	})
	if decision == "Wait" or coldOpenHold() then
		return
	end
	table.remove(queue, 1)
	publishQueue()
	startSummon(head, decision == "StartPushNatural")
end

-- The Great Storm's guaranteed big call (docs/04 section 5), once its storm phase begins.
local function bigCallForGreatSummon()
	local module = script.Parent:FindFirstChild("OperationService")
	if not module then
		return
	end
	local ok, ops = pcall(require, module :: ModuleScript)
	if ok and type(ops) == "table" and type((ops :: any).ForceBigCall) == "function" then
		local fine, err = pcall((ops :: any).ForceBigCall)
		if not fine then
			warn(`[StormService] Great Storm big call failed: {err}`)
		end
	end
end

local function refreshCallerTitles()
	local hour = math.floor(os.time() / 3600)
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		local shop = data and data.flags.shop
		local untilHour = if type(shop) == "table" and type(shop.callerHour) == "number"
			then shop.callerHour
			else 0
		player:SetAttribute("StormCaller", if untilHour > hour then true else nil)
	end
end

local function grantTicket(tier: string)
	return function(_player: Player, data: any): boolean?
		local shop = data.flags.shop
		if type(shop) ~= "table" then
			shop = {}
			data.flags.shop = shop
		end
		return Effects.addTicket(shop, tier)
	end
end

local function afterTicket(tier: string)
	return function(player: Player, _receipt: any, _fresh: boolean)
		StormService.QueueSummon(player, tier) -- queue full: the ticket stays saved
	end
end

local function setupSummons()
	MonetizationService.OnProduct("CallTheStorm", grantTicket("Storm"), afterTicket("Storm"))
	MonetizationService.OnProduct(
		"CallTheGreatStorm",
		grantTicket("GreatStorm"),
		afterTicket("GreatStorm")
	)
	Players.PlayerRemoving:Connect(function(player: Player)
		-- a queued storm whose buyer left does not run; their ticket stays saved
		for i = #queue, 1, -1 do
			if queue[i].player == player then
				table.remove(queue, i)
			end
		end
		publishQueue()
	end)
	DataService.OnLoaded(function()
		refreshCallerTitles()
	end)
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
	naturalWarningAt = stateStart + stateDuration
	publish()
	folder:SetAttribute("Intensity", 0)
	folder:SetAttribute("SummonQueue", 0)
	folder:SetAttribute("SummonedBy", "")
	folder:SetAttribute("GreatStormCallers", "")
	folder.Parent = ReplicatedStorage -- parent after the attributes so clients see a full set
	setupDevCommands()
	setupSummons()
end

function StormService.Start()
	task.spawn(function()
		while true do
			local offset = tonumber(Workspace:GetAttribute("DayClockOffset")) or 0
			Lighting.ClockTime = DayClock.clockTime(Workspace:GetServerTimeNow() + offset)
			task.wait(10)
		end
	end)
	local sinceIntensity = 0
	local lastIntensity = -1
	local sinceTitles = 0
	while true do
		local dt = task.wait(TICK_SECONDS)
		local now = Workspace:GetServerTimeNow()
		if
			now >= stateStart + stateDuration
			and state == "Calm"
			and (sunny() or coldOpenHold() or liveOpsCalm())
		then
			stateDuration += dt -- stay calm while a cold open or a LiveOps CalmSeas hour runs
		elseif now >= stateStart + stateDuration then
			-- Chain from the scheduled end, so a slow tick never drifts the cycle.
			enter(WeatherMath.nextState(state), math.min(now, stateStart + stateDuration))
			if state == "Storm" and current and current.tier == "GreatStorm" then
				task.spawn(bigCallForGreatSummon)
			elseif state == "Calm" then
				folder:SetAttribute("SummonedBy", "")
			end
		end
		stepSummons(now)
		sinceTitles += dt
		if sinceTitles >= 30 then
			sinceTitles = 0
			refreshCallerTitles()
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
