--!strict
-- TelemetryService (RP-A1, G64): the thin Telemetry module in front of Roblox AnalyticsService.
-- Other services call it with one-line hooks; what each event carries is decided in Telemetry/Events
-- (pure, tested). Every AnalyticsService call is pcall-wrapped: analytics never breaks a game path.
-- The spec (every funnel step, where it fires, and the Phase 2 hook list): docs/research/analytics.md.
--
-- Funnels: Onboarding (one-time, Events.Funnel) and the recurring TelemetryNames.Funnels Call, Shop,
-- Vehicle, Explore and Companion. Economy: currency "Cash" (sources from ProgressionService push()
-- extra.award, sinks from vehicle and upgrade buys). Progression: Explorer (stamps).
-- Custom: the fixed TelemetryNames.Custom list.
--
--   TelemetryService.Funnel(player, stepName)                         onboarding step (once per player)
--   TelemetryService.Build(player, key, level, finished, tutorialDone)  onboarding build steps (DockService)
--   TelemetryService.Step(player, funnel, sessionId, stepName, a?, b?, c?)   any recurring funnel step
--   TelemetryService.Call(player, opId, step, kind?)                   Call funnel (session = the call)
--   TelemetryService.Shop(player, step, app?, item?, currency?)        Shop funnel (session = the visit)
--   TelemetryService.Vehicle(player, step, vehicleId, where?)          Vehicle funnel (Spawned = new)
--   TelemetryService.Explore(player, islandId, step, stamps?)          Explore funnel (session = island)
--   TelemetryService.VehicleRecovered(player, rawReason, vehicleId)   VehicleRecovered (reason mapped)
--   TelemetryService.Companion(player, species, step)                  Companion funnel (session = species)
--   TelemetryService.RobuxPrompt(player, kind, key, purchased)         a Robux prompt closed
--   TelemetryService.Custom(player, name, value?, field1?, field2?, field3?)   one line at a site
--   TelemetryService.CashFlow(player, extra?, balance)                 push() hook: logs extra.award Cash
--   TelemetryService.CashSpent(player, price, balance, kind, itemId)
--   TelemetryService.ColdOpenStarted(player) / ColdOpenStep(player, stepId) / ColdOpenEnded(player, reason)
--   TelemetryService.OpFinished(player, op, reason)                    op: OperationService's live op table
--   TelemetryService.Recent -> { string }                              last events (Studio: ServerStorage.TelemetryDev)
-- Client (Telemetry_Client, rate limited, every value checked against a fixed set): TabletOpened,
-- Device(type), Shop(step, app, item?, currency?), InputDead(context),
-- StuckReset(context).
local AnalyticsService = game:GetService("AnalyticsService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local TelemetryNames = require(Shared:WaitForChild("TelemetryNames"))
local VehicleConfig = require(Config:WaitForChild("VehicleConfig"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local Events = require(script.Parent:WaitForChild("Telemetry"):WaitForChild("Events"))

local TelemetryService = {}
TelemetryService.Priority = 5 -- before the services whose signals it watches
TelemetryService.Verbose = false -- Studio: print every event (Studio already logs "event fired")
TelemetryService.Recent = {} :: { string }

type Shop = { id: string, at: number, app: string }
type Session = { joinedAt: number, device: string?, day: string? }

local RECENT_MAX = 60
local JOB = if game.JobId ~= "" then string.sub(game.JobId, 1, 8) else "studio" -- call session ids per server
local trackers: { [Player]: Events.Tracker } = {}
local buckets: { [Player]: Events.Bucket } = {}
local shops: { [Player]: Shop } = {}
local vehicles: { [Player]: string } = {}
local sessions: { [Player]: Session } = {}
local clientRemote: RemoteEvent? = nil
local dayChecked: { [Player]: boolean } = {}
local knownItems: { [string]: boolean } = {}
-- Session trail (live-ops monitoring): each player's event lines, saved on leave to the
-- SessionTrail_v1 DataStore (key "<userId>_<joinUnix>") and read by tools/trail.py via Open Cloud.
local TRAIL_STORE = "SessionTrail_v1"
local TRAIL_MAX = 600
local trails: { [number]: { joined: number, lines: { string } } } = {}

local function trailAdd(userId: number, text: string)
	local trail = trails[userId]
	if trail and #trail.lines < TRAIL_MAX then
		table.insert(trail.lines, `{os.time() - trail.joined} {text}`)
	end
end

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
	local id, rest = string.match(text, "^(%d+) (.*)$")
	if id and rest then
		trailAdd(tonumber(id) :: number, rest)
	end
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

-- A construction started (or finished): the onboarding steps it completes (Events.buildSteps).
function TelemetryService.Build(
	player: Player,
	key: string,
	level: number,
	finished: boolean,
	tutorialDone: boolean
)
	for _, step in Events.buildSteps(key, level, finished, tutorialDone) do
		TelemetryService.Funnel(player, step)
	end
end

-- Any recurring funnel step (LogFunnelStepEvent). Each step is sent once per session id: Roblox
-- only counts the first anyway, and repeats eat the global rate limit.
function TelemetryService.Step(
	player: Player,
	funnel: string,
	sessionId: string,
	stepName: string,
	a: string?,
	b: string?,
	c: string?
)
	local n = Events.stepOf(TelemetryNames.Funnels[funnel], stepName)
	if not n then
		warn(`[TelemetryService] {funnel}/{stepName} is not a TelemetryNames.Funnels step; dropped`)
		return
	end
	if not (player.Parent and Events.first(trackerOf(player), `{funnel}:{sessionId}:{n}`)) then
		return
	end
	note(`{player.UserId} {funnel} {sessionId} {n} {stepName}`)
	send(funnel, function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			funnel,
			sessionId,
			n,
			stepName,
			Events.fields(a, b, c)
		)
	end)
end

local function progression(player: Player, path: string, level: number, levelName: string)
	note(`{player.UserId} progression {path} {level} {levelName}`)
	send("Progression", function()
		AnalyticsService:LogProgressionEvent(
			player,
			path,
			Enum.AnalyticsProgressionType.Complete,
			level,
			levelName
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

local function callContext(player: Player, big: boolean?): string
	local weather = ReplicatedStorage:FindFirstChild("Weather")
	return Events.callContext(
		player:GetAttribute("ColdOpenActive") == true,
		big == true,
		weather ~= nil and weather:GetAttribute("State") == "Storm"
	)
end

-- Call funnel: Offered -> Accepted -> Seated -> Boarded -> Delivered, one session per call. Accepted
-- comes from the active-operation poll and Delivered from OpFinished; the others are one-line hooks.
function TelemetryService.Call(player: Player, opId: any, step: string, kind: string?)
	if step == "Boarded" then
		TelemetryService.Funnel(player, "FirstBoard")
	end
	TelemetryService.Step(player, "Call", `{JOB}:{tostring(opId)}`, step, kind, callContext(player))
end

-- Shop funnel: MenuOpened -> PanelOpened -> ItemViewed -> BuyTapped -> Bought, one session per visit
-- (Events.shopFresh). Fields: app, item, currency. The client sends the first four, the server Bought.
function TelemetryService.Shop(
	player: Player,
	step: string,
	app: string?,
	item: string?,
	currency: string?
)
	local n = Events.stepOf(TelemetryNames.Funnels.Shop, step)
	if not n then
		return
	end
	local now = os.clock()
	local last = shops[player]
	local s: Shop = if last and not Events.shopFresh(last.at, n, now)
		then last
		else { id = HttpService:GenerateGUID(false), at = now, app = "None" }
	shops[player] = s
	s.at = now
	s.app = app or s.app
	TelemetryService.Step(player, "Shop", s.id, step, s.app, item or "None", currency or "None")
end

-- Vehicle funnel: Spawned (a new session) -> Boarded -> Underway. Fields: vehicle, where it spawned.
-- How a vehicle goes away is the VehicleDespawned / VehicleRecovered custom events.
function TelemetryService.Vehicle(player: Player, step: string, vehicleId: string, where: string?)
	if step == "Spawned" or not vehicles[player] then
		vehicles[player] = HttpService:GenerateGUID(false)
	end
	TelemetryService.Step(player, "Vehicle", vehicles[player], step, vehicleId, where)
end

-- Auto-recovery ran (VehicleService reset). The raw reason never goes out: the
-- speed check's carries numbers.
function TelemetryService.VehicleRecovered(player: Player, reason: string, vehicleId: string)
	local why = if reason == "Flipped"
			or reason == "Stuck"
			or reason == "Sunk"
		then reason
		elseif reason == "out of bounds" then "OutOfBounds"
		elseif string.find(reason, "flooded", 1, true) then "Flooded"
		else "Runaway"
	TelemetryService.Custom(player, "VehicleRecovered", 1, why, vehicleId)
end

-- Explore funnel: Sighted -> Reached -> Stamped, one session per island. A stamp with the player's
-- stamp count also goes to Progression (path Explorer, level = stamps).
function TelemetryService.Explore(player: Player, islandId: string, step: string, stamps: number?)
	TelemetryService.Step(player, "Explore", islandId, step, islandId)
	if step == "Stamped" and type(stamps) == "number" then
		progression(player, "Explorer", stamps, islandId)
	end
end

-- Companion funnel: Rescued -> Adopted -> Chosen, one session per species. A switch away from the
-- current companion is the CompanionSwitch custom event.
function TelemetryService.Companion(player: Player, species: string, step: string)
	TelemetryService.Step(player, "Companion", species, step, species)
end

-- A Robux prompt closed (MonetizationService, from MarketplaceService's Prompt*PurchaseFinished).
function TelemetryService.RobuxPrompt(player: Player, kind: string, key: string, purchased: boolean)
	if not (player and player.Parent) then
		return
	end
	custom(
		player,
		Events.custom("RobuxPrompt", 1, kind, key, if purchased then "Purchased" else "Cancelled")
	)
	if purchased then
		TelemetryService.Shop(player, "Bought", nil, key, "Robux")
	end
end

function TelemetryService.ColdOpenStarted(player: Player)
	TelemetryService.Funnel(player, "AtSea")
end

function TelemetryService.ColdOpenStep(player: Player, stepId: string)
	local name = Events.ColdOpenSteps[stepId]
	if name then
		TelemetryService.Funnel(player, name)
	end
end

function TelemetryService.ColdOpenEnded(player: Player, reason: string)
	if Events.first(trackerOf(player), "ColdOpenEnded") then
		custom(player, { name = "ColdOpenEnded", value = 1, fields = Events.fields(reason) })
	end
end

function TelemetryService.OpFinished(player: Player, op: any, reason: string)
	local facts: Events.OpFacts = {
		kind = tostring(op.kind),
		grade = if type(op.grade) == "string" then op.grade else nil,
		reason = reason,
		helped = op.helpers ~= nil and op.helpers[player] == true,
		coldOpen = op.coldOpen == true,
		storm = op.storm == true,
		big = op.isBig == true,
		rarity = if op.wildlifeRare == true then "Rare" else "None", -- the sanctuary's rare palette
		saved = if type(op.saved) == "number" then op.saved else 0,
	}
	for _, event in Events.opEvents(facts) do
		custom(player, event)
	end
	if Events.delivered(facts) then
		TelemetryService.Call(player, op.id, "Delivered", facts.kind)
		TelemetryService.Funnel(player, "FirstDelivery")
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

-- Profile loaded: SessionStart (value = days since the first session, the day and
-- gap buckets, New / Returning). flags.firstSessionDay / lastSessionDay are written once per day,
-- after the events, so a same-day rejoin is not a return.
local function sessionDay(player: Player, data: any)
	if dayChecked[player] or not player.Parent then
		return
	end
	dayChecked[player] = true
	local today = Events.utcDay(os.time())
	local flags = if type(data) == "table" then data.flags else nil
	local previous = if type(flags) == "table" then flags.lastSessionDay else nil
	local first = if type(flags) == "table" then flags.firstSessionDay else nil
	previous = if type(previous) == "number" and previous > 0 then previous else nil
	first = if type(first) == "number" and first > 0 then first else (previous or today)
	local days = math.max(0, today - first)
	local day = Events.dayBucket(days)
	local session = sessions[player]
	if session then
		session.day = day
	end
	custom(
		player,
		Events.custom(
			"SessionStart",
			days,
			day,
			Events.gapBucket(if previous then today - previous else nil),
			if previous then "Returning" else "New"
		)
	)
	local progressionService = service("ProgressionService")
	if progressionService and type(progressionService.SetFlag) == "function" then
		if previous ~= today then
			pcall(progressionService.SetFlag, player, "lastSessionDay", today)
		end
		if not (type(flags) == "table" and flags.firstSessionDay == first) then
			pcall(progressionService.SetFlag, player, "firstSessionDay", first)
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

-- Call accepted: OperationService has no start signal, so read its live list once a second. One
-- Call/Accepted per participant per call.
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
			for _, player in info.assignedTo or {} do
				if
					typeof(player) == "Instance"
					and player:IsA("Player")
					and player.Parent
					and Events.first(trackerOf(player), `OpStart:{tostring(info.id)}`)
				then
					TelemetryService.Step(
						player,
						"Call",
						`{JOB}:{tostring(info.id)}`,
						"Accepted",
						tostring(info.kind),
						callContext(player, info.isBig)
					)
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

local function str(v: any): string?
	return if type(v) == "string" then v else nil
end

-- What only the client knows. Every value is checked against a fixed set (a client cannot grow the
-- dashboard's field cardinality) and the remote is rate limited (Events.allow).
local function clientStep(player: Player, name: string, a: any, b: any, c: any, d: any)
	if name == "TabletOpened" then
		TelemetryService.Funnel(player, "TabletOpened")
	elseif name == "Device" then
		local session = sessions[player]
		if session and Events.Devices[a] then
			session.device = a
		end
	elseif name == "InputDead" or name == "StuckReset" then
		local session = sessions[player]
		if Events.InputContexts[a] then
			custom(player, Events.custom(name, 1, session and session.device or "Unknown", a))
		end
	elseif name == "Shop" then
		local step, app, item, currency = str(a), str(b), str(c), str(d)
		local n = step and Events.stepOf(TelemetryNames.Funnels.Shop, step)
		if
			not step
			or not n
			or n > 4 -- Bought is the server's
			or (app ~= nil and not Events.ShopApps[app])
			or (item ~= nil and not Events.knownItem(item, knownItems))
			or (currency ~= nil and currency ~= "Cash" and currency ~= "Robux")
		then
			return
		end
		TelemetryService.Shop(player, step, app, item, currency)
		if step == "BuyTapped" and currency == "Robux" and item then
			local kind = if MonetizationConfig.GamePasses[item] then "GamePasses" else "Products"
			custom(player, Events.custom("RobuxPrompt", 1, kind, item, "Shown"))
		end
	end
end

local function addKnown(list: { string })
	for _, key in list do
		knownItems[key] = true
	end
end

local function saveTrail(userId: number)
	local trail = trails[userId]
	trails[userId] = nil
	if not trail or RunService:IsStudio() then
		return
	end
	send("SessionTrail", function()
		DataStoreService:GetDataStore(TRAIL_STORE):SetAsync(`{userId}_{trail.joined}`, {
			job = JOB,
			place = game.PlaceVersion,
			lines = trail.lines,
		})
	end)
end

local function onJoin(player: Player)
	trails[player.UserId] = trails[player.UserId] or { joined = os.time(), lines = {} }
	sessions[player] = sessions[player] or { joinedAt = os.clock() }
	TelemetryService.Funnel(player, "Joined")
	watchFriends(player)
end

function TelemetryService.Init()
	addKnown(VehicleConfig.Order)
	addKnown(VehicleUpgrades.UpgradeOrder)
	for _, group in { MonetizationConfig.Products, MonetizationConfig.GamePasses } do
		for key in group :: { [string]: any } do
			knownItems[key] = true
		end
	end
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
		clientRemote.OnServerEvent:Connect(
			function(player: Player, name: any, a: any, b: any, c: any, d: any)
				if type(name) ~= "string" then
					return
				end
				local now = os.clock()
				local bucket = buckets[player]
				if not bucket then
					bucket = Events.newBucket(now)
					buckets[player] = bucket
				end
				if Events.allow(bucket, now) then
					clientStep(player, name, a, b, c, d)
				end
			end
		)
	end
	Players.PlayerAdded:Connect(function(player)
		onJoin(player)
		task.defer(stormCheck, player, true)
	end)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			local seconds = math.floor(os.clock() - session.joinedAt)
			custom(
				player,
				Events.custom(
					"SessionEnd",
					seconds,
					Events.lengthBucket(seconds),
					session.device or "Unknown",
					session.day or "Unknown"
				)
			)
		end
		saveTrail(player.UserId)
		trackers[player] = nil
		buckets[player] = nil
		shops[player] = nil
		vehicles[player] = nil
		sessions[player] = nil
		dayChecked[player] = nil
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
	ScriptContext.Error:Connect(function(message: string, stack: string)
		local line = `ERR {string.sub(message, 1, 200)} @ {string.sub(
			string.gsub(stack, "\n", " | "),
			1,
			200
		)}`
		for userId in trails do
			trailAdd(userId, line)
		end
	end)
	game:BindToClose(function()
		for userId in table.clone(trails) do
			saveTrail(userId)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local root = player.Character
					and player.Character:FindFirstChild("HumanoidRootPart")
				local humanoid = player.Character
					and player.Character:FindFirstChildOfClass("Humanoid")
				local seat = humanoid and humanoid.SeatPart
				local where = if root and root:IsA("BasePart")
					then `{math.floor(root.Position.X)},{math.floor(root.Position.Y)},{math.floor(
						root.Position.Z
					)}`
					else "nochar"
				trailAdd(
					player.UserId,
					`pos {where}{if seat then " seat " .. seat:GetFullName() else ""}`
				)
			end
		end
	end)
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
