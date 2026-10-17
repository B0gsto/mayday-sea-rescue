--!strict
-- CallService: the radio. Offers calls to free players, tracks accepted calls, times them out
-- (the harbour patrol picks the victim up: nobody dies), pays crews, and runs the storm's big call
-- (Capsized Ferry). The physical side (victims, prompts, deliveries) is RescueService.
--
-- Remotes (shared Net): CallOffered, CallUpdated, CallCompleted, CallFailed (S->C), CallAccepted (C->S).
-- Every S->C payload carries the call's id; CallOffered/CallUpdated carry the full card (see payload()).
-- Contract API: GetActiveCalls, GetVictimPositions, CallCompleted (signal: callInfo, helpers).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))
local Net = require(Shared:WaitForChild("Net"))

local RescueService = require(script.Parent:WaitForChild("RescueService") :: ModuleScript) :: any

export type CallInfo = {
	id: string,
	kind: string,
	position: Vector3,
	zoneId: string,
	expiresAt: number,
	assignedTo: { Player },
	isBig: boolean,
}

type PlayerState = {
	activeCallId: string?,
	offerCallId: string?,
	nextOfferAt: number,
	completed: number,
}

local CallService = {}
CallService.Priority = 70

---------------------------------------------------------------- signal

type Handler = (CallInfo, { Player }) -> ()
local handlers: { Handler } = {}
CallService.CallCompleted = {
	Connect = function(_self: any, fn: Handler)
		table.insert(handlers, fn)
		return {
			Disconnect = function()
				local i = table.find(handlers, fn)
				if i then
					table.remove(handlers, i)
				end
			end,
		}
	end,
}

---------------------------------------------------------------- state

local calls: { [string]: any } = {}
local playerState: { [Player]: PlayerState } = {}
local nextId = 0
local bigCall: any = nil
local lastWeatherState = "Calm"

local function now(): number
	return Workspace:GetServerTimeNow()
end

local serviceCache: { [string]: any } = {}
local function service(name: string): any?
	local cached = serviceCache[name]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local mod = script.Parent:FindFirstChild(name)
	if not (mod and mod:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(require, mod)
	serviceCache[name] = if ok then result else false
	return if ok then result else nil
end

local function try(serviceName: string, fnName: string, ...: any): (boolean, any)
	local svc = service(serviceName)
	local fn = svc and svc[fnName]
	if type(fn) ~= "function" then
		return false, "missing"
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(`[CallService] {serviceName}.{fnName} failed: {result}`)
	end
	return ok, result
end

local function weatherState(): string
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	local s = folder and folder:GetAttribute("State")
	return if type(s) == "string" then s else "Calm"
end

local function stateOf(player: Player): PlayerState
	local st = playerState[player]
	if not st then
		st = {
			activeCallId = nil,
			offerCallId = nil,
			nextOfferAt = now() + CallLogic.offerDelay(nil, true),
			completed = 0,
		}
		playerState[player] = st
	end
	return st
end

local function award(player: Player, cash: number, rep: number, reason: string)
	if cash <= 0 and rep <= 0 then
		return
	end
	local ok = try("ProgressionService", "Award", player, cash, rep, reason)
	if not ok then
		warn(`[CallService] could not award {player.Name} {cash} Cash / {rep} Rep ({reason})`)
	end
end

local function stormCashMultiplier(): number
	if weatherState() ~= "Storm" then
		return 1
	end
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	return if folder and folder:GetAttribute("IsGreatStorm") == true then 2 else 1.5
end

---------------------------------------------------------------- payloads

local function info(call: any): CallInfo
	return {
		id = call.id,
		kind = call.kind,
		position = call.position,
		zoneId = call.zoneId,
		expiresAt = call.expiresAt,
		assignedTo = table.clone(call.assignedTo),
		isBig = call.isBig,
	}
end

local function payload(call: any, message: string?): { [string]: any }
	local aboard = RescueService.CountAboard(call)
	local towing = RescueService.IsTowing(call)
	local preview = CallLogic.previewReward(call.kind, call.tutorialIndex)
	local dropOffs = {}
	for _, d in RescueService.GetDropOffs(call.spec.dropOffs) do
		table.insert(dropOffs, d.position)
	end
	return {
		id = call.id,
		kind = call.kind,
		title = call.spec.displayName,
		radioLine = call.spec.radioLine,
		zoneName = call.zoneName,
		position = call.position,
		isBig = call.isBig,
		state = call.state,
		phase = if call.state == "Offered"
			then "Offered"
			elseif aboard > 0 or towing then "Return"
			else "Search",
		offerExpiresAt = call.offerExpiresAt,
		expiresAt = call.expiresAt,
		timer = call.timer,
		total = call.total,
		delivered = call.delivered,
		aboard = aboard,
		towing = towing,
		targets = if call.state == "Active"
			then RescueService.GetTargets(call)
			else { call.position },
		towPosition = if towing then RescueService.TowPosition(call) else nil,
		dropOffs = dropOffs,
		cash = preview.cash,
		rep = preview.rep,
		message = message,
	}
end

local function sendUpdate(call: any, message: string?, only: Player?)
	local data = payload(call, message)
	local remote = Net.event("CallUpdated")
	if only then
		remote:FireClient(only, data)
		return
	end
	for _, p in call.assignedTo do
		if p.Parent then
			remote:FireClient(p, data)
		end
	end
end

---------------------------------------------------------------- offers

local function newCall(kind: string, zone: string, position: Vector3): any
	nextId += 1
	local spec = assert(CallTypes.get(kind), kind)
	local zoneId = CallLogic.zoneIdAt(position)
	local call = {
		id = `C{nextId}`,
		kind = kind,
		spec = spec,
		zone = zone,
		zoneId = zoneId,
		zoneName = CallTypes.SpawnZones[zone].displayName,
		position = position,
		isBig = spec.isBig,
		state = "Offered",
		offeredTo = {} :: { Player },
		assignedTo = {} :: { Player },
		actors = {} :: { [Player]: boolean },
		owner = nil :: Player?,
		timer = CallLogic.timerFor(kind, zone),
		expiresAt = 0,
		offerExpiresAt = now() + CallTypes.Scheduler.OfferSeconds,
		acceptedAt = 0,
		graceUntil = nil :: number?,
		total = spec.victims,
		delivered = 0,
		victims = {},
		tutorialIndex = nil :: number?,
	}
	if kind == "Tow" then
		call.total = 1 -- one boat to bring in
	end
	calls[call.id] = call
	return call
end

local function canTow(player: Player): boolean
	local ok, result = try("ProgressionService", "CanUseVehicle", player, "RIB")
	return if ok then result == true else true
end

local function offerTo(player: Player)
	local st = stateOf(player)
	local choice = CallLogic.chooseCall(st.completed, weatherState(), canTow(player))
	local call = newCall(choice.kind, choice.zone, CallLogic.pickSpawnPoint(choice.zone))
	if st.completed < #CallTypes.Payout.Tutorial then
		call.tutorialIndex = st.completed
	end
	table.insert(call.offeredTo, player)
	st.offerCallId = call.id
	Net.event("CallOffered"):FireClient(player, payload(call))
end

local function scheduleNext(player: Player)
	local st = playerState[player]
	if st then
		st.activeCallId = nil
		st.offerCallId = nil
		st.nextOfferAt = now() + CallLogic.offerDelay(weatherState())
	end
end

---------------------------------------------------------------- lifecycle

local function closeCall(call: any)
	call.state = "Done"
	calls[call.id] = nil
	RescueService.Cleanup(call)
	if call == bigCall then
		bigCall = nil
	end
	if not call.isBig then
		for _, p in call.assignedTo do
			local st = playerState[p]
			if st and st.activeCallId == call.id then
				scheduleNext(p)
			end
		end
	end
end

local function helped(call: any, player: Player): boolean
	if call.actors[player] then
		return true
	end
	local ok, result = try("CrewService", "HasRoleAction", player, call.id)
	return ok and result == true
end

local function fireSignal(call: any, helpers: { Player })
	local snapshot = info(call)
	for _, fn in table.clone(handlers) do
		task.spawn(fn, snapshot, helpers)
	end
end

local function completeNormal(call: any)
	local elapsed = now() - call.acceptedAt
	local crewSize = #call.assignedTo
	local helpers: { Player } = {}
	local mult = stormCashMultiplier()
	for _, p in call.assignedTo do
		if p.Parent then
			local st = stateOf(p)
			if helped(call, p) then
				local tutorialIndex = if st.completed < #CallTypes.Payout.Tutorial
					then st.completed
					else nil
				local r = CallLogic.reward(call.kind, elapsed, call.timer, crewSize, tutorialIndex)
				award(p, r.cash, r.rep, `Call:{call.kind}`)
				st.completed += 1
				p:SetAttribute("CallsCompleted", st.completed)
				table.insert(helpers, p)
				Net.event("CallCompleted"):FireClient(p, {
					id = call.id,
					kind = call.kind,
					title = call.spec.displayName,
					grade = r.grade,
					cash = math.floor(r.cash * mult + 0.5),
					rep = r.rep,
					message = if call.kind == "Tow"
						then "Boat moored. Nice towing!"
						else "Survivors safe ashore!",
				})
			else
				local share = CallLogic.failSafeCash(call.kind)
				award(p, share, 0, "CallShare")
				Net.event("CallCompleted"):FireClient(p, {
					id = call.id,
					kind = call.kind,
					title = call.spec.displayName,
					grade = "Share",
					cash = math.floor(share * mult + 0.5),
					rep = 0,
					message = "Your crew finished the call. Lend a hand next time for full pay!",
				})
			end
		end
	end
	closeCall(call)
	fireSignal(call, helpers)
end

local function finishBig(call: any)
	local saved, total = call.delivered, call.total
	local cash, rep = CallLogic.bigCompletionBonus(saved, total)
	local mult = stormCashMultiplier()
	local helpers: { Player } = {}
	local seen: { [Player]: boolean } = {}
	local everyone = table.clone(call.assignedTo)
	for p in call.actors do
		if not table.find(everyone, p) then
			table.insert(everyone, p)
		end
	end
	for _, p in everyone do
		if p.Parent and not seen[p] then
			seen[p] = true
			if saved > 0 and helped(call, p) then
				award(p, cash, rep, "BigCall:CapsizedFerry")
				table.insert(helpers, p)
				Net.event("CallCompleted"):FireClient(p, {
					id = call.id,
					kind = call.kind,
					title = call.spec.displayName,
					grade = `{saved}/{total} saved`,
					cash = math.floor(cash * mult + 0.5),
					rep = rep,
					message = "The Gale Queen's passengers are safe. All hands, well done!",
				})
			else
				Net.event("CallFailed"):FireClient(p, {
					id = call.id,
					reason = "BigCallOver",
					message = "The harbour patrol and the lifeboats took the rest of the Gale Queen's passengers.",
					cash = 0,
				})
			end
		end
	end
	closeCall(call)
	if #helpers > 0 then
		fireSignal(call, helpers)
	end
end

local function failCall(call: any)
	if call.isBig then
		finishBig(call)
		return
	end
	local share = CallLogic.failSafeCash(call.kind)
	local mult = stormCashMultiplier()
	for _, p in call.assignedTo do
		if p.Parent then
			award(p, share, 0, "CallFailSafe")
			Net.event("CallFailed"):FireClient(p, {
				id = call.id,
				reason = "Expired",
				message = if call.kind == "Tow"
					then "The harbour patrol towed them in. Everyone's safe."
					else "The harbour patrol picked them up. Safe and sound!",
				cash = math.floor(share * mult + 0.5),
			})
		end
	end
	closeCall(call)
end

local function withdrawOffer(call: any)
	for _, p in call.offeredTo do
		if p.Parent then
			Net.event("CallFailed")
				:FireClient(p, { id = call.id, reason = "Withdrawn", silent = true })
		end
		scheduleNext(p)
	end
	calls[call.id] = nil
end

local function activate(call: any, player: Player)
	call.state = "Active"
	call.owner = player
	call.acceptedAt = now()
	call.expiresAt = call.acceptedAt + call.timer
	call.assignedTo = { player }
	local st = stateOf(player)
	st.offerCallId = nil
	st.activeCallId = call.id
	-- free crewmates join the call
	local ok, crew = try("CrewService", "GetCrew", player)
	if ok and type(crew) == "table" then
		for _, mate in crew do
			if typeof(mate) == "Instance" and mate:IsA("Player") and mate ~= player then
				local ms = stateOf(mate)
				if not ms.activeCallId then
					if ms.offerCallId and calls[ms.offerCallId] then
						withdrawOffer(calls[ms.offerCallId])
					end
					ms.offerCallId = nil
					ms.activeCallId = call.id
					table.insert(call.assignedTo, mate)
				end
			end
		end
	end
	RescueService.SpawnCall(call)
	sendUpdate(call, call.spec.radioLine)
end

local function startBigCall()
	if bigCall then
		return
	end
	local count = CallLogic.bigCallVictimCount(#Players:GetPlayers())
	local call = newCall("CapsizedFerry", "FerrySite", CallTypes.SpawnZones.FerrySite.center)
	call.state = "Active"
	call.total = count
	call.acceptedAt = now()
	call.expiresAt = call.acceptedAt + call.timer
	call.offerExpiresAt = call.expiresAt
	bigCall = call
	local positions = CallLogic.scatterPoints(
		call.position,
		count,
		CallTypes.BigCall.FerryVictimMinRadius,
		CallTypes.BigCall.FerryVictimMaxRadius,
		"Outside"
	)
	RescueService.SpawnCall(call, positions)
	Net.event("CallOffered"):FireAllClients(payload(call))
	print(`[CallService] big call {call.id}: Capsized Ferry with {count} victims`)
end

---------------------------------------------------------------- hooks from RescueService

function CallService.CanAct(call: any, player: Player): boolean
	if call.isBig or table.find(call.assignedTo, player) then
		return true
	end
	-- a crewmate of someone on the call can help (and joins it)
	local ok, crew = try("CrewService", "GetCrew", player)
	if ok and type(crew) == "table" then
		for _, mate in crew do
			if table.find(call.assignedTo, mate) then
				table.insert(call.assignedTo, player)
				return true
			end
		end
	end
	return false
end

function CallService.RecordAction(call: any, player: Player)
	call.actors[player] = true
	if call.isBig and not table.find(call.assignedTo, player) then
		table.insert(call.assignedTo, player)
	end
	try("CrewService", "RecordRoleAction", player, call.id)
end

function CallService.Notify(call: any, player: Player, message: string)
	if calls[call.id] then
		sendUpdate(call, message, player)
	end
end

function CallService.OnVictimBoarded(call: any, _player: Player)
	sendUpdate(
		call,
		if call.isBig
			then "Survivor aboard! Take them to the dock or hospital."
			else "Survivor aboard! Bring them home."
	)
end

function CallService.OnVictimLost(call: any)
	sendUpdate(call, "A survivor went back in the water!")
end

function CallService.OnTowAttached(call: any, _player: Player)
	sendUpdate(call, "Tow line on! Bring her in to the dock, nice and steady.")
end

function CallService.OnTowLost(call: any)
	sendUpdate(call, "The tow line came off! Hook it up again.")
end

function CallService.OnTowDelivered(call: any, _driver: Player?)
	if calls[call.id] then
		call.delivered = call.total
		completeNormal(call)
	end
end

function CallService.OnVictimsDelivered(call: any, count: number, driver: Player?)
	if not calls[call.id] then
		return
	end
	call.delivered += count
	if call.isBig then
		if driver then
			local cash, rep = CallLogic.bigVictimPay()
			award(driver, cash * count, rep * count, "BigCall:Victim")
		end
		if call.delivered >= call.total then
			finishBig(call)
		else
			sendUpdate(call, `{call.delivered}/{call.total} passengers safe!`)
			if driver and not table.find(call.assignedTo, driver) then
				sendUpdate(call, nil, driver)
			end
		end
		return
	end
	if call.delivered >= call.total then
		completeNormal(call)
	else
		sendUpdate(call, `{call.delivered}/{call.total} delivered. Go back for the rest!`)
	end
end

---------------------------------------------------------------- contract API

function CallService.GetActiveCalls(): { CallInfo }
	local out = {}
	for _, call in calls do
		if call.state == "Active" then
			table.insert(out, info(call))
		end
	end
	return out
end

function CallService.GetVictimPositions(player: Player): { Vector3 }
	local out = {}
	for _, call in calls do
		if call.state == "Active" and (call.isBig or table.find(call.assignedTo, player)) then
			for _, p in RescueService.GetTargets(call) do
				table.insert(out, p)
			end
		end
	end
	return out
end

-- Dev helper (Studio): start the big call without waiting for a storm.
function CallService.ForceBigCall()
	startBigCall()
end

---------------------------------------------------------------- scheduler

local function onAccepted(player: Player, callId: any)
	if type(callId) ~= "string" then
		return
	end
	local call = calls[callId]
	if not call then
		return
	end
	if call.isBig then
		if call.state == "Active" and not table.find(call.assignedTo, player) then
			table.insert(call.assignedTo, player)
		end
		sendUpdate(call, call.spec.radioLine, player)
		return
	end
	if call.state ~= "Offered" or not table.find(call.offeredTo, player) then
		return
	end
	local st = stateOf(player)
	if st.activeCallId then
		return
	end
	activate(call, player)
end

local function tick()
	local t = now()
	local state = weatherState()
	if state == "Storm" and lastWeatherState ~= "Storm" then
		startBigCall()
	end
	lastWeatherState = state

	for _, call in table.clone(calls) do
		if call.state == "Offered" and t > call.offerExpiresAt then
			withdrawOffer(call)
		elseif call.state == "Active" and t > call.expiresAt then
			local inProgress = RescueService.CountAboard(call) > 0 or RescueService.IsTowing(call)
			if inProgress and not call.graceUntil then
				call.graceUntil = call.expiresAt + CallTypes.Scheduler.LateGrace
				sendUpdate(call, "Running late! Deliver now before the patrol boat takes over.")
			elseif not inProgress or t > (call.graceUntil :: number) then
				failCall(call)
			end
		end
	end

	for _, player in Players:GetPlayers() do
		local st = stateOf(player)
		if
			not st.activeCallId
			and not st.offerCallId
			and t >= st.nextOfferAt
			and player.Character
		then
			offerTo(player)
		end
	end
end

local function onPlayerAdded(player: Player)
	stateOf(player)
	if bigCall then
		task.delay(5, function()
			if bigCall and player.Parent then
				Net.event("CallOffered"):FireClient(player, payload(bigCall))
			end
		end)
	end
	if RunService:IsStudio() then
		player.Chatted:Connect(function(msg)
			if msg == "/ferry" then
				startBigCall()
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	playerState[player] = nil
	for _, call in table.clone(calls) do
		local i = table.find(call.assignedTo, player)
		if i then
			table.remove(call.assignedTo, i)
		end
		call.actors[player] = nil
		local j = table.find(call.offeredTo, player)
		if j then
			table.remove(call.offeredTo, j)
		end
		if not call.isBig then
			if call.state == "Offered" and #call.offeredTo == 0 then
				calls[call.id] = nil
			elseif call.state == "Active" and #call.assignedTo == 0 then
				closeCall(call)
			end
		end
	end
end

function CallService.Init()
	Net.event("CallAccepted").OnServerEvent:Connect(onAccepted)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
end

function CallService.Start()
	lastWeatherState = weatherState()
	while true do
		local ok, err = pcall(tick :: any)
		if not ok then
			warn(`[CallService] tick failed: {err}`)
		end
		task.wait(0.5)
	end
end

return CallService
