--!strict
-- TelemetryService (RP-A1, G64): the thin Telemetry module in front of Roblox AnalyticsService.
-- Other services call it with one-line hooks; what each event carries is decided in Telemetry/Events
-- (pure, tested). Every AnalyticsService call is pcall-wrapped: analytics never breaks a game path.
--
-- Onboarding funnel (Creator Dashboard > Analytics > Funnels > Onboarding), Telemetry/Events.Funnel:
--   1 Joined                 PlayerAdded (here)
--   2 ColdOpenStarted        OperationService.StartColdOpen (the radio tasking is auto-done there)
--   3-4 ColdOpenApproach / ColdOpenRecovery   OperationService record() on the cold open
--   5 ColdOpenEnded          OperationService endColdOpen (the reason is the ColdOpenEnded custom event)
--   6 RewardSeen             the client's first reward burst (Telemetry_Client)
--   7 ReachedStation         the client reaches the station beacon (Telemetry_Client)
--   8 Call2Accepted          the active-operation poll sees the first station call
--   9 FirstOpComplete        OperationService finish (call 2 complete)
--   10 Call3Complete         OperationService finish (call 3 complete)
--   11 FirstChandleryVisit   the Chandlery gear counter prompt, Panel "ShopCounter" (here)
--   12 FirstUnlock           the first gear or vehicle purchase (ProgressionService buy / BuyStock)
--   13 FirstRank             ProgressionService.RankChanged (here)
--   14 FirstDailyCrate       StreakService open
--   15 Day2Return            DataService.OnLoaded, a later UTC day than flags.lastSessionDay
-- Economy (currency "Cash"): sources from ProgressionService push() award extras (Award, Cash packs,
--   Starter Kit), sinks from ProgressionService buy()/BuyStock(), PetService treats.
-- Custom (LogCustomEvent): the fixed TelemetryNames.Custom list. OpStarted/OpComplete/OpGrade come
--   from the active-operation poll and OperationService finish (variant rarity in the fields).
--
--   TelemetryService.Funnel(player, stepName)
--   TelemetryService.Custom(player, name, value?, field1?, field2?, field3?)   one line at a site
--   TelemetryService.CashFlow(player, extra?, balance)          push() hook: logs extra.award Cash
--   TelemetryService.CashSpent(player, price, balance, kind, itemId)
--   TelemetryService.ColdOpenStarted(player) / ColdOpenStep(player, stepId) / ColdOpenEnded(player, reason)
--   TelemetryService.OpFinished(player, op, reason)            op: OperationService's live op table
--   TelemetryService.Recent -> { string }                       last events (Studio: ServerStorage.TelemetryDev)
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local RescueVariants = require(Shared:WaitForChild("Config"):WaitForChild("RescueVariants"))
local TelemetryNames = require(Shared:WaitForChild("TelemetryNames"))

local Events = require(script.Parent:WaitForChild("Telemetry"):WaitForChild("Events"))

local TelemetryService = {}
TelemetryService.Priority = 5 -- before the services whose signals it watches
TelemetryService.Verbose = false -- Studio: print every event (Studio already logs "event fired")
TelemetryService.Recent = {} :: { string }

local RECENT_MAX = 60
local trackers: { [Player]: Events.Tracker } = {}
local lastClient: { [Player]: number } = {}
local clientRemote: RemoteEvent? = nil
local dayChecked: { [Player]: boolean } = {}

local function trackerOf(player: Player): Events.Tracker
	local t = trackers[player]
	if not t then
		t = Events.newTracker()
		trackers[player] = t
	end
	return t
end

local function note(text: string)
	local recent = TelemetryService.Recent
	table.insert(recent, text)
	if #recent > RECENT_MAX then
		table.remove(recent, 1)
	end
	if TelemetryService.Verbose and RunService:IsStudio() then
		print("[Telemetry]", text)
	end
end

local function send(label: string, fn: () -> ())
	xpcall(fn, function(err)
		warn(`[TelemetryService] {label} failed: {err}`)
	end)
end

local function custom(player: Player, event: Events.Custom)
	if not TelemetryNames.isCustom(event.name) then
		warn(`[TelemetryService] {event.name} is not on the fixed TelemetryNames list; dropped`)
		return
	end
	note(`{player.UserId} custom {event.name} {event.value}`)
	send(event.name, function()
		AnalyticsService:LogCustomEvent(player, event.name, event.value, event.fields)
	end)
end

-- One line at a trigger site. The name must be on src/shared/TelemetryNames.luau; the three field
-- values are clipped by Events.custom. `value` defaults to 1 (a counter).
function TelemetryService.Custom(
	player: Player,
	name: string,
	value: number?,
	a: string?,
	b: string?,
	c: string?
)
	if not (player and player.Parent) then
		return
	end
	custom(player, Events.custom(name, value, a, b, c))
end

function TelemetryService.Funnel(player: Player, stepName: string)
	local s = Events.funnelStep(stepName)
	if not (s and player.Parent and Events.first(trackerOf(player), `Funnel:{stepName}`)) then
		return
	end
	note(`{player.UserId} onboarding {s.step} {s.name}`)
	send("Onboarding", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, s.step, s.name)
	end)
end

-- Rank progression (LogProgressionEvent, Creator Dashboard > Analytics > Progression): one
-- Complete per promotion, with the rank index and display name (never the player's name).
local function rankProgression(player: Player, rankIndex: number)
	local def = ProgressionConfig.Ranks[rankIndex]
	local name = if def and type(def.displayName) == "string"
		then def.displayName
		else `Rank{rankIndex}`
	note(`{player.UserId} progression Rank {rankIndex} {name}`)
	send("Progression", function()
		AnalyticsService:LogProgressionEvent(
			player,
			"Rank",
			Enum.AnalyticsProgressionType.Complete,
			rankIndex,
			name
		)
	end)
end

local function economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	amount: number,
	balance: number,
	transaction: string,
	sku: string
)
	note(`{player.UserId} economy {flow.Name} {amount} {transaction} {sku} -> {balance}`)
	send("Economy", function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			Events.CURRENCY,
			amount,
			math.max(0, math.floor(balance)),
			transaction,
			sku
		)
	end)
end

-- ProgressionService push(): every Cash grant travels as extra.award { cash, reason }.
function TelemetryService.CashFlow(player: Player, extra: { [string]: any }?, balance: number)
	local award = extra and extra.award
	local amount = if type(award) == "table" then Events.amount(award.cash) else nil
	if not (award and amount) then
		return
	end
	local transaction, sku = Events.cashSource(award.reason)
	economy(player, Enum.AnalyticsEconomyFlowType.Source, amount, balance, transaction, sku)
end

function TelemetryService.CashSpent(
	player: Player,
	price: number,
	balance: number,
	kind: string,
	itemId: string
)
	local amount = Events.amount(price)
	if amount then
		local transaction, sku = Events.cashSink(kind, itemId)
		economy(player, Enum.AnalyticsEconomyFlowType.Sink, amount, balance, transaction, sku)
	end
end

function TelemetryService.ColdOpenStarted(player: Player)
	TelemetryService.Funnel(player, "ColdOpenStarted")
end

function TelemetryService.ColdOpenStep(player: Player, stepId: string)
	local name = Events.ColdOpenSteps[stepId]
	if name then
		TelemetryService.Funnel(player, name)
	end
end

function TelemetryService.ColdOpenEnded(player: Player, reason: string)
	TelemetryService.Funnel(player, "ColdOpenEnded")
	if Events.first(trackerOf(player), "ColdOpenEnded") then
		custom(player, { name = "ColdOpenEnded", value = 1, fields = Events.fields(reason) })
	end
end

local function rarityOf(variant: any): string
	if type(variant) ~= "string" or variant == "" then
		return "None"
	end
	local def = RescueVariants.ById(variant)
	return if def then def.rarity else "None"
end

function TelemetryService.OpFinished(player: Player, op: any, reason: string)
	local facts: Events.OpFacts = {
		kind = tostring(op.kind),
		grade = if type(op.grade) == "string" then op.grade else nil,
		reason = reason,
		helped = op.helpers ~= nil and op.helpers[player] == true,
		coldOpen = op.coldOpen == true,
		exercise = op.exercise ~= nil and op.exercise ~= false,
		storm = op.storm == true,
		big = op.isBig == true,
		rarity = rarityOf(op.variant),
	}
	for _, event in Events.opEvents(facts) do
		custom(player, event)
	end
	if Events.countsAsFirstOp(facts) then
		TelemetryService.Funnel(player, "FirstOpComplete")
		local done = player:GetAttribute("OpsCompleted")
		if type(done) == "number" and done >= 3 then
			TelemetryService.Funnel(player, "Call3Complete")
		end
	end
end

local function stormCheck(player: Player, midStorm: boolean)
	local weather = ReplicatedStorage:FindFirstChild("Weather")
	if not (weather and weather:GetAttribute("State") == "Storm") then
		return
	end
	if Events.first(trackerOf(player), Events.stormKey(weather:GetAttribute("StormId"))) then
		custom(player, Events.stormJoined(weather:GetAttribute("IsGreatStorm") == true, midStorm))
	end
end

local function service(name: string): any?
	local module = script.Parent:FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

-- Day2Return: the first session on a later UTC day than the profile's last recorded one. The flag
-- is written once per day, after the funnel step, so a same-day rejoin is not a return.
local function sessionDay(player: Player, data: any)
	if dayChecked[player] or not player.Parent then
		return
	end
	dayChecked[player] = true
	local today = Events.utcDay(os.time())
	local flags = if type(data) == "table" then data.flags else nil
	local previous = if type(flags) == "table" then flags.lastSessionDay else nil
	if Events.day2Return(previous, today) then
		TelemetryService.Funnel(player, "Day2Return")
	end
	if previous ~= today then
		local progression = service("ProgressionService")
		if progression and type(progression.SetFlag) == "function" then
			pcall(progression.SetFlag, player, "lastSessionDay", today)
		end
	end
end

-- FriendBonus is published by FriendService (attributes); log it once per session when active.
local function watchFriends(player: Player)
	local function check()
		if not player.Parent then
			return
		end
		local count = player:GetAttribute("FriendCount")
		local percent = player:GetAttribute("FriendBonus")
		if
			type(count) == "number"
			and count > 0
			and Events.first(trackerOf(player), "FriendBonus")
		then
			custom(
				player,
				Events.custom(
					"FriendBonus",
					if type(percent) == "number" then percent else 0,
					tostring(count)
				)
			)
		end
	end
	player:GetAttributeChangedSignal("FriendCount"):Connect(check)
	player:GetAttributeChangedSignal("FriendBonus"):Connect(check)
	task.defer(check)
end

local function opContext(player: Player, info: any): string
	if player:GetAttribute("ColdOpenActive") == true then
		return "ColdOpen"
	elseif player:GetAttribute("OpsExercise") ~= nil then
		return "Exercise"
	elseif info.isBig == true then
		return "Big"
	end
	local weather = ReplicatedStorage:FindFirstChild("Weather")
	return if weather and weather:GetAttribute("State") == "Storm" then "Storm" else "Calm"
end

-- Operation started: OperationService has no start signal, so read its live list once a second.
-- One OpStarted per participant per operation; the first non-cold-open, non-exercise op accepted
-- is funnel step 12 (call 2 accepted).
local function pollOps()
	local operations = service("OperationService")
	if not operations or type(operations.GetActiveOperations) ~= "function" then
		return
	end
	local ok, list = pcall(operations.GetActiveOperations)
	if not ok or type(list) ~= "table" then
		return
	end
	for _, info in list do
		if type(info) == "table" then
			local kind = tostring(info.kind)
			local rarity = rarityOf(info.variant)
			for _, player in info.assignedTo or {} do
				if
					typeof(player) == "Instance"
					and player:IsA("Player")
					and player.Parent
					and Events.first(trackerOf(player), `OpStart:{tostring(info.id)}`)
				then
					local coldOpen = player:GetAttribute("ColdOpenActive") == true
					local exercise = player:GetAttribute("OpsExercise") ~= nil
					custom(player, Events.opStarted(kind, rarity, opContext(player, info)))
					if not coldOpen and not exercise then
						TelemetryService.Funnel(player, "Call2Accepted")
					end
				end
			end
		end
	end
end

-- LiveOps participation: LiveOpsService publishes replicated state; this watches it. One
-- LiveEvent per event window per player; StormJoined stays the Great Storm hook.
local function pollWorldEvents()
	local players = Players:GetPlayers()
	if #players == 0 then
		return
	end
	local liveOps = ReplicatedStorage:FindFirstChild("LiveOpsState")
	if liveOps and liveOps:GetAttribute("Phase") == "Active" then
		local id = liveOps:GetAttribute("Event")
		if type(id) == "string" and id ~= "" then
			local key = `Live:{id}:{tostring(liveOps:GetAttribute("StartsAt"))}`
			for _, player in players do
				if Events.first(trackerOf(player), key) then
					custom(player, Events.custom("LiveEvent", 1, id))
				end
			end
		end
	end
end

-- The few first-session facts only the client knows: the reward burst played, the station beacon
-- reached, photo mode opened. One fixed-name RemoteEvent, rate limited, server-side logged.
local function clientStep(player: Player, name: string)
	if name == "RewardSeen" then
		TelemetryService.Funnel(player, "RewardSeen")
	elseif name == "StationReached" then
		TelemetryService.Funnel(player, "ReachedStation")
	elseif name == "PhotoModeOpen" then
		if Events.first(trackerOf(player), "PhotoMode") then
			custom(player, Events.custom("PhotoMode"))
		end
	elseif name == "PetPetted" then
		if Events.first(trackerOf(player), "PetPetted") then
			custom(player, Events.custom("PetPetted"))
		end
	end
end

function TelemetryService.Init()
	local folder = Net.init()
	local existing = folder:FindFirstChild("Telemetry_Client")
	if existing and existing:IsA("RemoteEvent") then
		clientRemote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "Telemetry_Client"
		created.Parent = folder
		clientRemote = created
	end
	if clientRemote then
		clientRemote.OnServerEvent:Connect(function(player: Player, name: any)
			if type(name) ~= "string" then
				return
			end
			local now = os.clock()
			if now - (lastClient[player] or -math.huge) < 0.5 then
				return
			end
			lastClient[player] = now
			clientStep(player, name)
		end)
	end
	Players.PlayerAdded:Connect(function(player)
		TelemetryService.Funnel(player, "Joined")
		watchFriends(player)
		task.defer(stormCheck, player, true)
	end)
	for _, player in Players:GetPlayers() do
		TelemetryService.Funnel(player, "Joined")
		watchFriends(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		trackers[player] = nil
		lastClient[player] = nil
		dayChecked[player] = nil
	end)
	-- the Chandlery gear counter's prompt is a server prompt (WorldService, Panel = "ShopCounter")
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Panel") == "ShopCounter" then
			TelemetryService.Funnel(player, "FirstChandleryVisit")
		end
	end)
end

-- Studio only: ServerStorage.TelemetryDev (BindableFunction) for smoke runs. The command bar's
-- require() gets its own module copies, so tests reach the live ones through this.
--   Invoke("recent") -> { string }               the last events sent
--   Invoke("pass", player, key) -> boolean       MonetizationService.SetPassOwnedForTesting
local function devHook()
	if not RunService:IsStudio() then
		return
	end
	local dev = Instance.new("BindableFunction")
	dev.Name = "TelemetryDev"
	dev.OnInvoke = function(cmd: string, player: Player?, key: string?): any
		if cmd == "recent" then
			return table.clone(TelemetryService.Recent)
		elseif cmd == "pass" and player and key then
			local module = script.Parent:FindFirstChild("MonetizationService")
			local monetization: any = module and (require :: any)(module)
			monetization.SetPassOwnedForTesting(player, key)
			return monetization.OwnsPass(player, key)
		end
		return nil
	end
	dev.Parent = game:GetService("ServerStorage")
end

function TelemetryService.Start()
	devHook()
	local progression = script.Parent:FindFirstChild("ProgressionService")
	if progression and progression:IsA("ModuleScript") then
		local ok, progressionService = pcall(require, progression)
		local signal = ok
			and type(progressionService) == "table"
			and (progressionService :: any).RankChanged
		if typeof(signal) == "RBXScriptSignal" then
			signal:Connect(function(player: Player, newRank: number, oldRank: number)
				if newRank > oldRank then
					TelemetryService.Funnel(player, "FirstRank")
					rankProgression(player, newRank)
				end
			end)
		end
	end
	task.spawn(function()
		local weather = ReplicatedStorage:WaitForChild("Weather", 60)
		if weather then
			weather:GetAttributeChangedSignal("State"):Connect(function()
				for _, player in Players:GetPlayers() do
					stormCheck(player, false)
				end
			end)
		end
	end)
	task.spawn(function()
		local module = script.Parent:WaitForChild("DataService", 30)
		if module and module:IsA("ModuleScript") then
			local ok, dataService = pcall(require, module)
			if ok and type(dataService) == "table" and type(dataService.OnLoaded) == "function" then
				dataService.OnLoaded(sessionDay)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(pollOps)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(5)
			pcall(pollWorldEvents)
		end
	end)
end

return TelemetryService
