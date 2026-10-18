--!strict
-- TelemetryService (RP-A1): the thin Telemetry module in front of Roblox AnalyticsService. Other
-- services call it with one-line hooks; what each event carries is decided in Telemetry/Events
-- (pure, tested). Every AnalyticsService call is pcall-wrapped: analytics never breaks a game path.
--
-- Onboarding funnel (Creator Dashboard > Analytics > Funnels > Onboarding), Telemetry/Events.Funnel:
--   1 Joined                 PlayerAdded (here)
--   2 ColdOpenStarted        OperationService.StartColdOpen (the radio tasking is auto-done there)
--   3-4 ColdOpenApproach / ColdOpenRecovery   OperationService record() on the cold open
--   5 ColdOpenEnded          OperationService endColdOpen (the reason is the ColdOpenEnded custom event)
--   6 FirstOpComplete        OperationService finish (first station call rescued)
--   7 FirstRank              ProgressionService.RankChanged (here)
--   8 FirstChandleryVisit    the Chandlery gear counter prompt, Panel "ShopCounter" (here)
-- Economy (currency "Cash"): sources from ProgressionService push() award extras (Award, Cash packs,
--   Starter Kit), sinks from ProgressionService buy() (gear and vehicles).
-- Custom: OpGrade, OpFailed (OperationService finish), ColdOpenEnded, StormJoined (Weather State, here).
--
--   TelemetryService.Funnel(player, stepName)
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

local Events = require(script.Parent:WaitForChild("Telemetry"):WaitForChild("Events"))

local TelemetryService = {}
TelemetryService.Priority = 5 -- before the services whose signals it watches
TelemetryService.Verbose = false -- Studio: print every event (Studio already logs "event fired")
TelemetryService.Recent = {} :: { string }

local RECENT_MAX = 60
local trackers: { [Player]: Events.Tracker } = {}

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
	note(`{player.UserId} custom {event.name} {event.value}`)
	send(event.name, function()
		AnalyticsService:LogCustomEvent(player, event.name, event.value, event.fields)
	end)
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
	kind: "Gear" | "Vehicle",
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
	}
	for _, event in Events.opEvents(facts) do
		custom(player, event)
	end
	if Events.countsAsFirstOp(facts) then
		TelemetryService.Funnel(player, "FirstOpComplete")
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

function TelemetryService.Init()
	Players.PlayerAdded:Connect(function(player)
		TelemetryService.Funnel(player, "Joined")
		task.defer(stormCheck, player, true)
	end)
	for _, player in Players:GetPlayers() do
		TelemetryService.Funnel(player, "Joined")
	end
	Players.PlayerRemoving:Connect(function(player)
		trackers[player] = nil
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
			local service: any = module and (require :: any)(module)
			service.SetPassOwnedForTesting(player, key)
			return service.OwnsPass(player, key)
		end
		return nil
	end
	dev.Parent = game:GetService("ServerStorage")
end

function TelemetryService.Start()
	devHook()
	local progression = script.Parent:FindFirstChild("ProgressionService")
	if progression and progression:IsA("ModuleScript") then
		local ok, service = pcall(require, progression)
		local signal = ok and type(service) == "table" and (service :: any).RankChanged
		if typeof(signal) == "RBXScriptSignal" then
			signal:Connect(function(player: Player, newRank: number, oldRank: number)
				if newRank > oldRank then
					TelemetryService.Funnel(player, "FirstRank")
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
end

return TelemetryService
