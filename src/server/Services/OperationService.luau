--!strict
-- OperationService: rescue operations v2 (docs/09-rescue-operations.md, CONTRACT.md "Operations v2").
-- The one source of truth for the radio and rescues. It offers operations (the first-call chain,
-- the storm rate, the Capsized Ferry at storm start), runs each operation's step state machine,
-- assigns steps to crew roles (NPC crew fill empty seats: slower, Silver at most), validates the
-- step results clients submit (the server recomputes the grade from metrics), ticks every
-- casualty's condition meter, runs the takeover at Critical, and pays through
-- ProgressionService.Award with CrewService.RecordRoleAction for every step a player completes.
--
-- The physical scene (victims, NPC boats, bobbing, deliveries at the pads) is RescueService; this
-- service hands it an `op.scene` table and reacts to its hooks (OnVictimsDelivered, ...).
-- Remotes: src/shared/Ops/Remotes.luau (Ops_*). Data: src/shared/Ops/*.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local OpsFolder = Shared:WaitForChild("Ops")
local Condition = require(OpsFolder:WaitForChild("Condition"))
local Grading = require(OpsFolder:WaitForChild("Grading"))
local Operations = require(OpsFolder:WaitForChild("Operations"))
local Remotes = require(OpsFolder:WaitForChild("Remotes"))
local Types = require(OpsFolder:WaitForChild("Types"))
-- training exercises (RP-C1): exercise kinds record a pass, not certification progress
local Exercises = require(OpsFolder:WaitForChild("Definitions"):WaitForChild("Exercises"))

local RescueService = require(script.Parent:WaitForChild("RescueService") :: ModuleScript) :: any
-- Ferry (stream c): server-side metric checks and the scene board's task list.
local FerryValidate = require(
	script.Parent.Parent:WaitForChild("Ferry"):WaitForChild("FerryValidate") :: ModuleScript
) :: any
local SceneBoard = require(Shared:WaitForChild("Ferry"):WaitForChild("SceneBoard")) :: any
-- Person in the Water: onPattern and destinationRight, measured on the server.
local BoatColdOpen = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpen"))
-- the cold open's per-player lifecycle: runs at most once, never restarts by itself
local ColdOpenFlow = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpenFlow"))
local PiwMetrics = require(script.Parent.Parent:WaitForChild("Ops"):WaitForChild("PiwMetrics"))

type StepDef = Types.StepDef
type OperationDef = Types.OperationDef
type CasualtyState = Types.CasualtyState
type Grade = Types.Grade

export type OperationInfo = {
	id: string,
	kind: string,
	position: Vector3,
	zoneId: string,
	expiresAt: number,
	assignedTo: { Player },
	isBig: boolean,
	grade: string?,
}

type StepInst = {
	key: string,
	def: StepDef,
	mechanicId: string,
	casualtyIndex: number?,
	assignee: Player?,
	npc: boolean,
	npcDoneAt: number,
	startedAt: number,
	timeoutAt: number,
	attempt: number,
	tag: string?, -- triage: the tag the client chose
	board: { [string]: string }?, -- scene_command: unit -> task id (optional result.board)
}

type Track = {
	id: string,
	owner: Player,
	members: { Player },
	plan: { StepDef },
	index: number,
	current: StepInst?,
	casualtyIndex: number?,
	loopStart: number?,
	done: boolean,
	seq: number,
}

type StepRecord = {
	stepId: string,
	label: string,
	realTerm: string,
	grade: Grade,
	weight: number,
	by: string, -- player name or "NPC"
	userId: number?,
	trackId: string,
	at: number,
}

type PlayerState = {
	activeOpId: string?,
	offerOpId: string?,
	nextOfferAt: number,
	completed: number,
}

local OperationService = {}
OperationService.Priority = 70

-- New players get the cold open instead of their first offer. Turned on in Start() once
-- VehicleService.SpawnColdOpen exists (a cold open without the jet ski would strand them).
OperationService.ColdOpenAuto = false

-- Studio only: NPC durations x this (the smoke run sets it low).
OperationService.DevTimeScale = 1

---------------------------------------------------------------- signal

type Handler = (OperationInfo, { Player }) -> ()
local handlers: { Handler } = {}
OperationService.OperationCompleted = {
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

local ops: { [string]: any } = {}
local playerState: { [Player]: PlayerState } = {}
local coldOpenFlow: { [Player]: ColdOpenFlow.Entry } = {} -- this session's cold-open state
local stationOnSpawn: { [Player]: boolean } = {} -- died in the cold open: next spawn at station
local coldOpenBegunAt: { [Player]: number } = {} -- StartColdOpen may yield (SpawnColdOpen)
local COLD_OPEN_START_GRACE = 10 -- s before a cold open that never got its op counts as lost
local nextId = 0
local bigOp: any = nil
local lastWeatherState = "Calm"
local rng = Random.new()

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
		warn(`[OperationService] {serviceName}.{fnName} failed: {result}`)
	end
	return ok, result
end

local function weatherState(): string
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	local s = folder and folder:GetAttribute("State")
	return if type(s) == "string" then s else "Calm"
end

local function stormCashMultiplier(): number
	if weatherState() ~= "Storm" then
		return 1
	end
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	return if folder and folder:GetAttribute("IsGreatStorm") == true then 2 else 1.5
end

local function stateOf(player: Player): PlayerState
	local st = playerState[player]
	if not st then
		st = {
			activeOpId = nil,
			offerOpId = nil,
			nextOfferAt = now() + CallLogic.offerDelay(nil, true),
			completed = 0,
		}
		playerState[player] = st
	end
	return st
end

-- true / false, or nil while the player's profile is still loading (wait: a returning player
-- must not be dropped into the cold open again because their save was slow to load).
local function coldOpenDone(player: Player): boolean?
	if player:GetAttribute("ColdOpenDone") == true then
		return true
	end
	-- ProgressionService.GetData returns coldOpenDone from the profile (nil until it loads).
	local ok, data = try("ProgressionService", "GetData", player)
	if ok and data == nil then
		return nil
	end
	return ok and type(data) == "table" and data.coldOpenDone == true
end

local function markColdOpenDone(player: Player)
	player:SetAttribute("ColdOpenDone", true)
	-- CONTRACT: ProgressionService.SetFlag(player, "coldOpenDone", true) persists it (stream E).
	try("ProgressionService", "SetFlag", player, "coldOpenDone", true)
end

local function fire(name: Remotes.EventName, player: Player, data: any)
	if player.Parent then
		Remotes.event(name):FireClient(player, data)
	end
end

local function coldOpenEntry(player: Player): ColdOpenFlow.Entry
	local e = coldOpenFlow[player]
	if not e then
		e = ColdOpenFlow.new()
		coldOpenFlow[player] = e
	end
	return e
end

-- (alive, seated on the cold-open jet ski)
local function coldOpenRiderStatus(player: Player): (boolean, boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, false
	end
	local seat = humanoid.SeatPart
	local ok, v = try("VehicleService", "GetVehicle", player)
	local boat = if ok and typeof(v) == "Instance" and v:IsA("Model") then v else nil
	return true,
		seat ~= nil
			and boat ~= nil
			and boat:GetAttribute("ColdOpen") == true
			and seat:IsDescendantOf(boat)
end

-- On foot at the top of the station slipway (Map.Slipways.StationSlipway, its local -Z end is at
-- the quay), or by the station when the map has none. A player seated in anything is left alone.
local function sendToStation(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.SeatPart or humanoid.Health <= 0 then
		return
	end
	local map = Workspace:FindFirstChild("Map")
	local slips = map and map:FindFirstChild("Slipways")
	local ramp = slips and slips:FindFirstChild("StationSlipway")
	local pos = CallTypes.STATION + Vector3.new(0, 6, 0)
	if ramp and ramp:IsA("BasePart") then
		local half = ramp.Size / 2
		pos = (ramp.CFrame * CFrame.new(0, half.Y + 4, -half.Z + 10)).Position
	end
	local face = CallTypes.STATION
	if (face - pos).Magnitude < 1 then
		face = pos + Vector3.new(0, 0, -1)
	end
	local root = character.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	character:PivotTo(CFrame.lookAt(pos, Vector3.new(face.X, pos.Y, face.Z)))
end

-- The cold open ended for any reason: persist ColdOpenDone, radio the outcome (on anything but
-- a rescue the lifeboat has picked the casualty up) and hand the player over to the station.
-- Runs once per cold open; ColdOpenFlow never lets it start again.
local function endColdOpen(player: Player, reason: string)
	local e = coldOpenFlow[player]
	if not e then
		return
	end
	local opId = e.opId
	if not ColdOpenFlow.finish(e, reason) then
		return
	end
	markColdOpenDone(player)
	local ok, v = try("VehicleService", "GetVehicle", player)
	if ok and typeof(v) == "Instance" and v:IsA("Model") then
		v:SetAttribute("ColdOpenApproach", false)
		v:SetAttribute("ColdOpenAutoThrottle", false)
	end
	local msg = ColdOpenFlow.radioFor(reason)
	fire("Ops_Radio", player, { opId = opId or "", from = msg.from, text = msg.text })
	local alive, onCraft = coldOpenRiderStatus(player)
	local how = ColdOpenFlow.handover(alive, onCraft)
	player:SetAttribute("ColdOpenEnded", reason) -- Studio tests
	player:SetAttribute("ColdOpenHandover", how)
	if how == "Station" then
		sendToStation(player)
	elseif how == "Respawn" then
		stationOnSpawn[player] = true
	end -- "Ride": the client's arrival shot and Vehicle_ArrivalHandoff dock them at the station
end

local function everyone(op: any): { Player }
	local out = {}
	for _, t in op.tracks do
		for _, p in t.members do
			if p.Parent and not table.find(out, p) then
				table.insert(out, p)
			end
		end
	end
	for _, p in op.members do
		if p.Parent and not table.find(out, p) then
			table.insert(out, p)
		end
	end
	return out
end

local function radio(op: any, from: string, text: string, only: Player?)
	local data = { opId = op.id, from = from, text = text }
	if only then
		fire("Ops_Radio", only, data)
		return
	end
	for _, p in everyone(op) do
		fire("Ops_Radio", p, data)
	end
end

---------------------------------------------------------------- roles

local ROLE_ORDER = { "Helm", "Navigator", "Crew", "Medic" }

local function vehicleOf(player: Player): Model?
	local ok, v = try("VehicleService", "GetVehicle", player)
	return if ok and typeof(v) == "Instance" and v:IsA("Model") then v else nil
end

-- A one-person craft (the jet ski): its rider is Helm, Crew and Medic at once (docs 09 4.1).
local function soloCraft(player: Player): boolean
	local v = vehicleOf(player)
	return v ~= nil and v:GetAttribute("VehicleId") == "JetSki"
end

-- Owner is Helm; crewmates take Navigator, Crew, Medic in join order; extras are Crew.
local function roleOf(track: Track, player: Player): { string }
	local i = table.find(track.members, player)
	if not i then
		return {}
	end
	if #track.members == 1 then
		-- solo: the jet ski rider is everyone; in a bigger boat the helm also works the radio
		return if soloCraft(player) then table.clone(ROLE_ORDER) else { "Helm", "Navigator" }
	end
	return { ROLE_ORDER[i] or "Crew" }
end

local function assigneeFor(track: Track, step: StepDef): Player?
	for _, p in track.members do
		if p.Parent and table.find(roleOf(track, p), step.role) then
			return p
		end
	end
	if step.npcAllowed == false then
		return if track.owner.Parent then track.owner else track.members[1]
	end
	return nil -- an NPC crewmate takes it
end

-- Scene command (ferry) needs a Coxswain or Helm certification (player attribute, stream E);
-- otherwise the NPC Coastguard officer runs the scene. Studio skips the check for testing.
local function canCommand(player: Player): boolean
	return RunService:IsStudio()
		or player:GetAttribute("CertCoxswain") == true
		or player:GetAttribute("CertHelm") == true
end

local function stepAssignee(track: Track, step: StepDef): Player?
	local p = assigneeFor(track, step)
	if p and step.id == "scene_command" and not canCommand(p) then
		return nil
	end
	return p
end

---------------------------------------------------------------- snapshots

local function casualtyPosition(op: any, index: number): Vector3
	local v = op.scene.victims and op.scene.victims[index]
	if v and v.floater and v.state == "Water" then
		return v.floater.cf.Position
	end
	local boat = op.scene.boat
	if boat and boat.floater then
		return Vector3.new(boat.floater.x, 0, boat.floater.z)
	end
	return op.position
end

local function casualtyView(op: any, index: number): { [string]: any }
	local c: CasualtyState = op.casualties[index]
	return {
		index = index,
		id = c.id,
		state = c.state,
		condition = math.floor(c.condition + 0.5),
		band = Condition.band(c.condition),
		label = Condition.label(c.condition, c.state),
		lifejacket = c.lifejacket,
		inWater = c.inWater,
		surveyed = c.surveyed,
		treated = c.treated,
		delivered = c.delivered,
		takenOver = c.takenOver,
		tag = c.tag,
		position = casualtyPosition(op, index),
	}
end

local function trackOf(op: any, player: Player): Track?
	for _, t in op.tracks do
		if table.find(t.members, player) then
			return t
		end
	end
	return nil
end

local function stepView(inst: StepInst, track: Track): { [string]: any }
	return {
		key = inst.key,
		id = inst.def.id,
		label = inst.def.label,
		realTerm = inst.def.realTerm,
		role = inst.def.role,
		mechanicId = inst.mechanicId,
		npc = inst.npc,
		assignee = if inst.assignee then inst.assignee.Name else "NPC crew",
		timeoutAt = inst.timeoutAt,
		npcDoneAt = if inst.npc then inst.npcDoneAt else nil,
		trackId = track.id,
		casualtyIndex = inst.casualtyIndex,
	}
end

-- Ops_State payload: everything a tasking card / HUD needs.
local function snapshot(op: any, player: Player): { [string]: any }
	local track = trackOf(op, player)
	local casualties = {}
	for i in op.casualties do
		table.insert(casualties, casualtyView(op, i))
	end
	local plan = {}
	if track then
		for _, s in track.plan do
			table.insert(plan, { id = s.id, label = s.label, realTerm = s.realTerm, role = s.role })
		end
	end
	local done = {}
	for _, r in op.results do
		table.insert(done, { stepId = r.stepId, grade = r.grade, by = r.by, trackId = r.trackId })
	end
	local current = {}
	for _, t in op.tracks do
		if t.current then
			table.insert(current, stepView(t.current, t))
		end
	end
	return {
		opId = op.id,
		kind = op.kind,
		title = op.def.displayName,
		isBig = op.isBig,
		state = op.state,
		zoneName = op.zoneName,
		position = op.position,
		startedAt = op.acceptedAt,
		capAt = op.acceptedAt + op.def.capSeconds,
		storm = op.storm,
		takeover = op.takeover,
		myTrack = if track then track.id else nil,
		myRoles = if track then roleOf(track, player) else {},
		plan = plan,
		results = done,
		current = current,
		casualties = casualties,
		saved = op.saved,
		total = #op.casualties,
		board = op.board, -- ferry: the last Ops_Board payload, for late listeners
	}
end

local function broadcast(op: any)
	for _, p in everyone(op) do
		fire("Ops_State", p, snapshot(op, p))
	end
end

local function info(op: any): OperationInfo
	return {
		id = op.id,
		kind = op.kind,
		position = op.position,
		zoneId = op.zoneId,
		expiresAt = op.acceptedAt + op.def.capSeconds,
		assignedTo = everyone(op),
		isBig = op.isBig,
		grade = op.grade,
	}
end

---------------------------------------------------------------- creation

local POB_WORDS = { "one", "two", "three", "four" }

local function newOp(kind: string, sceneKind: string, zone: string, position: Vector3): any
	nextId += 1
	local def = assert(Operations.get(kind), kind)
	local spec = assert(CallTypes.Kinds[sceneKind], sceneKind)
	local id = `O{nextId}`
	local op = {
		id = id,
		kind = kind,
		def = def,
		isBig = def.isBig,
		zone = zone,
		zoneId = CallLogic.zoneIdAt(position),
		zoneName = CallTypes.SpawnZones[zone].displayName,
		position = position,
		state = "Offered",
		offeredTo = {} :: { Player },
		members = {} :: { Player },
		tracks = {} :: { Track },
		owner = nil :: Player?,
		offerExpiresAt = now() + CallTypes.Scheduler.OfferSeconds,
		acceptedAt = now(),
		storm = weatherState() == "Storm",
		casualties = {} :: { CasualtyState },
		results = {} :: { StepRecord },
		helpers = {} :: { [Player]: boolean },
		shared = {} :: { [string]: string },
		history = {} :: { { t: number, c: { number } } },
		lastSample = 0,
		saved = 0,
		takeover = nil :: { reason: string, at: number }?,
		osc = nil :: Player?,
		grade = nil :: string?,
		scene = {
			id = id,
			kind = sceneKind,
			spec = spec,
			position = position,
			total = if sceneKind == "Tow" then 1 else spec.victims,
			victims = {},
			isBig = def.isBig,
			opsDriven = true,
			opId = id,
		},
	}
	-- RescueService reads casualties[i].panicking live (the rigged swimmer thrashes until calmed)
	op.scene.casualties = op.casualties
	if sceneKind == "Tow" then
		-- people aboard the disabled vessel: the tasking says it and RescueService builds them
		local n = rng:NextInteger(1, #POB_WORDS)
		op.pob = n
		op.scene.pob = n
		op.radioLine = (string.gsub(def.radioLine, "%a+ aboard", `{POB_WORDS[n]} aboard`, 1))
	end
	ops[id] = op
	return op
end

local function rollCasualties(op: any, count: number)
	local def: OperationDef = op.def
	for i = 1, count do
		local state = Operations.roll(def.states, rng:NextNumber())
		local lifejacket = rng:NextNumber() < def.lifejacketChance
		table.insert(op.casualties, Condition.new(`{op.id}-{i}`, state, lifejacket))
	end
end

local function newTrack(op: any, owner: Player, members: { Player }): Track
	local track: Track = {
		id = `{op.id}T{#op.tracks + 1}`,
		owner = owner,
		members = members,
		plan = Operations.plan(op.def, if op.isBig then nil else op.casualties[1].state),
		index = 0,
		current = nil,
		casualtyIndex = if op.isBig then nil else 1,
		loopStart = nil,
		done = false,
		seq = 0,
	}
	if op.planIds then
		local filtered = {}
		for _, sdef in track.plan do
			if table.find(op.planIds, sdef.id) then
				table.insert(filtered, sdef)
			end
		end
		track.plan = filtered
	end
	table.insert(op.tracks, track)
	return track
end

---------------------------------------------------------------- the step machine

local advance: (op: any, track: Track) -> ()
local finish: (op: any, reason: string) -> ()
local startTakeover: (op: any, reason: string) -> ()

local function scaled(seconds: number): number
	return seconds * (if RunService:IsStudio() then OperationService.DevTimeScale else 1)
end

local function stepContext(op: any, track: Track, inst: StepInst, player: Player): { [string]: any }
	local ci = inst.casualtyIndex
	return {
		operation = {
			id = op.id,
			kind = op.kind,
			title = op.def.displayName,
			position = op.position,
			zoneName = op.zoneName,
			storm = op.storm,
			isBig = op.isBig,
		},
		step = stepView(inst, track),
		casualty = if ci then casualtyView(op, ci) else nil,
		vehicle = vehicleOf(player),
		role = inst.def.role,
		isAssist = player:GetAttribute("OpsPro") ~= true,
		attempt = inst.attempt,
		scene = {
			windDirection = (function()
				local f = ReplicatedStorage:FindFirstChild("Weather")
				local w = f and f:GetAttribute("WindDirection")
				return if type(w) == "number" then w else 0
			end)(),
			targets = RescueService.GetTargets(op.scene),
		},
	}
end

local function beginStep(op: any, track: Track, def: StepDef, attempt: number?)
	track.seq += 1
	local ci = track.casualtyIndex
	local cstate = if ci then op.casualties[ci].state else nil
	local assignee = stepAssignee(track, def)
	local t = now()
	local inst: StepInst = {
		key = `{track.id}:{track.seq}`,
		def = def,
		mechanicId = Operations.mechanicFor(def, cstate),
		casualtyIndex = ci,
		assignee = assignee,
		npc = assignee == nil,
		npcDoneAt = t + scaled((def.npcSeconds or 10) * Types.Rules.NpcSlowdown),
		startedAt = t,
		timeoutAt = t + def.timeoutSec,
		attempt = attempt or 1,
	}
	track.current = inst
	if assignee then
		fire("Ops_StepStart", assignee, stepContext(op, track, inst, assignee))
	end
	if def.id == "alongside" or def.id == "berth" then
		pcall(RescueService.SetTowMode, op.scene, "Alongside") -- lashed beside the tug
	end
	broadcast(op)
end

local function record(op: any, track: Track, inst: StepInst, grade: Grade, by: Player?)
	table.insert(op.results, {
		stepId = inst.def.id,
		label = inst.def.label,
		realTerm = inst.def.realTerm,
		grade = grade,
		weight = inst.def.weight,
		by = if by then by.Name else "NPC",
		userId = if by then by.UserId else nil,
		trackId = track.id,
		at = now() - op.acceptedAt,
		-- the cold open's Assist ease braked the hull on this step (grade capped at Silver)
		assistEase = if (inst :: any).assistEase then true else nil,
	})
	if by then
		op.helpers[by] = true
		try("CrewService", "RecordRoleAction", by, op.id)
	end
end

local function applyEffect(
	op: any,
	track: Track,
	inst: StepInst,
	by: Player?,
	_metrics: Types.Metrics
)
	local effect = inst.def.effect
	local ci = inst.casualtyIndex
	local c: CasualtyState? = if ci then op.casualties[ci] else nil
	local actor = by or track.owner
	if effect == "board" and c and ci then
		c.inWater = false
		c.panicking = false
		pcall(RescueService.BoardVictim, op.scene, ci, actor)
	elseif effect == "calm" and c then
		c.panicking = false
	elseif effect == "survey" and c then
		c.surveyed = true
	elseif effect == "treat" and c then
		c.treated = true
		c.sheltered = true
		c.wet = false
	elseif effect == "tow" and c then
		c.towed = true
		pcall(RescueService.AttachTowFor, op.scene, actor)
	elseif effect == "triage" and c then
		c.tag = inst.tag or Operations.triageTag(c.state)
	elseif effect == "deliver" and c and ci and not c.delivered then
		c.delivered = true
		op.saved += 1
		if op.isBig then
			pcall(RescueService.RemoveVictim, op.scene, ci)
			local pay = Grading.bigCasualtyPay()
			if actor.Parent then
				try(
					"ProgressionService",
					"Award",
					actor,
					pay.cash,
					pay.rep,
					"Op:CapsizedFerry:Casualty"
				)
			end
		end
	end
end

-- Ferry: the on-scene commander's assignments, to every crew on the operation (Ops_Board).
-- A human OSC's map comes from the optional `result.board` (unit -> task id, sanitised in
-- onStepResult); the NPC officer fills the board with every crew on scene plus NPC lifeboats.
local function sendBoard(op: any, inst: StepInst, by: Player?, metrics: Types.Metrics)
	local board = inst.board
	if not by then
		local units = {}
		for _, t in op.tracks do
			table.insert(units, `Haven {t.owner.DisplayName}`)
		end
		-- the NPC units scene_command.luau lists
		for _, n in
			{ "Lifeboat 17-01", "Haven Patrol", "ILB Two-Two", "ILB Two-Three", "Lifeboat 14-07" }
		do
			table.insert(units, `{n} (NPC)`)
		end
		board = SceneBoard.autoAssign(units)
	end
	local assigned: number? = if type(metrics.assigned) == "number" then metrics.assigned else nil
	if board and assigned == nil then
		local n = 0
		for _ in board do
			n += 1
		end
		assigned = n
	end
	op.board = {
		opId = op.id,
		osc = if by then by.DisplayName else "Coastguard (NPC)",
		npc = by == nil,
		assigned = assigned,
		tasksCovered = if board then SceneBoard.tasksCovered(board) else metrics.tasksCovered,
		reportCorrect = metrics.reportCorrect,
		board = board,
	}
	for _, p in everyone(op) do
		fire("Ops_Board", p, op.board)
	end
end

local function complete(
	op: any,
	track: Track,
	inst: StepInst,
	grade: Grade,
	by: Player?,
	metrics: Types.Metrics
)
	if track.current ~= inst then
		return
	end
	track.current = nil
	record(op, track, inst, grade, by)
	applyEffect(op, track, inst, by, metrics)
	if inst.def.id == "scene_command" then
		sendBoard(op, inst, by, metrics)
	end
	if op.takeover and inst.def.id == "standby" then
		finish(op, "Takeover")
		return
	end
	advance(op, track)
end

local function npcFinish(op: any, track: Track, inst: StepInst)
	complete(op, track, inst, "Silver", nil, {})
end

-- onFail handling (timeout or a client failed = true).
local function failStep(op: any, track: Track, inst: StepInst, why: string)
	local def = inst.def
	local action = def.onFail
	if action == "retry" then
		if inst.attempt < Types.Rules.MaxAttempts then
			if inst.assignee then
				fire(
					"Ops_StepAck",
					inst.assignee,
					{ opId = op.id, stepKey = inst.key, accepted = false, reason = why }
				)
			end
			beginStep(op, track, def, inst.attempt + 1)
			return
		end
		action = if def.npcAllowed == false then "skip" else "npc"
	end
	if action == "npc" and def.npcAllowed ~= false then
		inst.npc = true
		inst.assignee = nil
		inst.npcDoneAt = now() + scaled((def.npcSeconds or 10) * Types.Rules.NpcSlowdown * 0.5)
		radio(op, "Crew", `I'll take the {string.lower(def.realTerm)}.`)
		broadcast(op)
		return
	elseif action == "takeover" then
		startTakeover(op, "StepFailed")
		return
	elseif action == "continue" then
		complete(op, track, inst, "Bronze", inst.assignee, {})
		return
	end
	complete(op, track, inst, "Fail", nil, {})
end

-- Claims the next unclaimed casualty for a big-call track.
local function claimCasualty(op: any, track: Track): number?
	for i, c in op.casualties do
		if not c.claimedBy and not c.delivered and not c.takenOver then
			c.claimedBy = track.id
			return i
		end
	end
	return nil
end

advance = function(op: any, track: Track)
	if op.state ~= "Active" or track.done then
		return
	end
	while true do
		-- big calls: a finished per-casualty run loops back while casualties remain
		local prev = track.plan[track.index]
		local after = track.plan[track.index + 1]
		if
			op.isBig
			and track.loopStart
			and prev
			and prev.perCasualty
			and not (after and after.perCasualty)
		then
			track.casualtyIndex = claimCasualty(op, track)
			if track.casualtyIndex then
				track.index = track.loopStart - 1
			end
		end
		track.index += 1
		local def = track.plan[track.index]
		if not def then
			track.done = true
			break
		end
		if def.shared then
			if op.shared[def.id] and op.shared[def.id] ~= track.id then
				continue -- another unit has it
			end
			op.shared[def.id] = track.id
			if def.id == "scene_command" then
				op.osc = if canCommand(track.owner) then track.owner else nil
			end
		end
		if def.perCasualty and op.isBig then
			if track.loopStart == nil then
				track.loopStart = track.index
			end
			if track.casualtyIndex == nil then
				track.casualtyIndex = claimCasualty(op, track)
			end
			local ci = track.casualtyIndex
			if ci == nil or op.casualties[ci].takenOver then
				-- nothing (left) to pick up: skip the rest of this per-casualty run
				track.casualtyIndex = nil
				while track.plan[track.index + 1] and track.plan[track.index + 1].perCasualty do
					track.index += 1
				end
				continue
			end
		end
		beginStep(op, track, def)
		return
	end
	-- a track finished: the operation ends when every track has
	for _, t in op.tracks do
		if not t.done then
			broadcast(op)
			return
		end
	end
	finish(op, "Complete")
end

---------------------------------------------------------------- takeover

startTakeover = function(op: any, reason: string)
	if op.takeover or op.state ~= "Active" then
		return
	end
	op.takeover = { reason = reason, at = now() - op.acceptedAt }
	for _, c in op.casualties do
		if not c.delivered then
			c.takenOver = true
		end
	end
	radio(
		op,
		"Gale Isles Coastguard",
		`Haven Rescue, Gale Isles Coastguard. {op.def.takeoverAsset} is two minutes out and will take over. Good work holding on.`
	)
	-- stand by and assist: its own short step for the owner (docs 09 section 2.5)
	local track = op.tracks[1]
	if not track then
		finish(op, "Takeover")
		return
	end
	for _, t in op.tracks do
		t.current = nil
		t.done = true
	end
	track.done = false
	local standby: StepDef = {
		id = "standby",
		label = "Stand by and assist",
		realTerm = "Assisting the takeover",
		role = "Helm",
		mechanicId = "standby_assist",
		gradeBands = {
			{ metric = "steady", gold = 1, silver = 0.6, bronze = 0.2, higherIsBetter = true },
		},
		weight = 1,
		timeoutSec = 40,
		onFail = "skip",
		npcAllowed = false,
	}
	beginStep(op, track, standby)
end

---------------------------------------------------------------- finishing and pay

local function closeOp(op: any)
	op.state = "Done"
	ops[op.id] = nil
	pcall(RescueService.Cleanup, op.scene)
	if op == bigOp then
		bigOp = nil
	end
	for _, p in everyone(op) do
		local st = playerState[p]
		if st and st.activeOpId == op.id then
			st.activeOpId = nil
			st.offerOpId = nil
			st.nextOfferAt = now() + CallLogic.offerDelay(weatherState())
		end
	end
end

local function tipFor(op: any, scored: { Grading.ScoredStep }): string?
	local i = Grading.weakest(scored)
	if not i then
		return nil
	end
	local r = op.results[i]
	for _, s in op.def.steps do
		if s.id == r.stepId then
			return s.tip
		end
	end
	return nil
end

finish = function(op: any, reason: string)
	if op.state == "Done" then
		return
	end
	op.state = "Done"
	local scored: { Grading.ScoredStep } = {}
	for _, r in op.results do
		if r.stepId ~= "standby" then
			table.insert(scored, { grade = r.grade, weight = r.weight })
		end
	end
	local grade: Grade = Grading.operationGrade(scored) :: any
	op.grade = if op.takeover then "Takeover" else grade
	local people = everyone(op)
	local humans = 0
	for _, p in people do
		if op.helpers[p] then
			humans += 1
		end
	end
	local assisted = false
	for _, r in op.results do
		if r.stepId == "standby" and r.grade ~= "Fail" then
			assisted = true
		end
	end
	local mult = stormCashMultiplier()
	local helpers: { Player } = {}
	local timeline = {}
	for _, r in op.results do
		table.insert(timeline, {
			id = r.stepId,
			label = r.label,
			realTerm = r.realTerm,
			grade = r.grade,
			weight = r.weight,
			by = r.by,
			userId = r.userId,
			at = math.floor(r.at),
		})
	end
	local tip = tipFor(op, scored)
	for _, p in people do
		local st = stateOf(p)
		local reward: Grading.Reward
		local paidAs: string
		if op.helpers[p] then
			table.insert(helpers, p)
			if op.isBig then
				reward = Grading.bigCompletionBonus(op.saved, #op.casualties, op.osc == p)
				paidAs = "Op:CapsizedFerry"
			elseif op.takeover then
				local tr = trackOf(op, p)
				local total = Operations.totalWeight(if tr then tr.plan else op.def.steps)
				reward = Grading.takeoverPayout(op.def.weight, scored, total, humans, assisted)
				paidAs = `Op:{op.kind}:Takeover`
			else
				local tut = if st.completed < #Grading.Payout.Tutorial then st.completed else nil
				reward = Grading.payout(op.def.weight, grade, humans, tut)
				paidAs = `Op:{op.kind}`
			end
			st.completed += 1
			p:SetAttribute("OpsCompleted", st.completed)
		else
			reward = Grading.shareWithoutStep(op.def.weight)
			paidAs = "Op:Share"
		end
		if reward.cash > 0 or reward.rep > 0 then
			local ok = try("ProgressionService", "Award", p, reward.cash, reward.rep, paidAs)
			if not ok then
				warn(
					`[OperationService] could not award {p.Name} {reward.cash} Cash / {reward.rep} Rep`
				)
			end
		end
		if op.coldOpen then
			markColdOpenDone(p)
			local boat = vehicleOf(p)
			if boat then
				boat:SetAttribute("ColdOpenApproach", false)
				boat:SetAttribute("ColdOpenAutoThrottle", false)
			end
		end
		-- certification progress and exercise passes (RP-C1); takeovers never count
		local training: any = nil
		if op.helpers[p] and not op.takeover then
			local casualty = op.casualties[1]
			local steps = {}
			for _, r in op.results do
				local stepDef: StepDef? = nil
				for _, sd in op.def.steps do
					if sd.id == r.stepId then
						stepDef = sd
						break
					end
				end
				table.insert(steps, {
					id = r.stepId,
					grade = r.grade,
					userId = r.userId,
					assistEase = r.assistEase,
					mechanicId = if stepDef
						then Operations.mechanicFor(stepDef, casualty and casualty.state)
						else nil,
				})
			end
			local ex = Exercises.get(op.kind)
			local ok, res = try(
				"ProgressionService",
				"RecordTraining",
				p,
				op.kind,
				grade,
				steps,
				ex ~= nil,
				ex ~= nil and ex.cannotFail
			)
			if ok and type(res) == "table" then
				training = res
			end
		end
		p:SetAttribute("OpsLastGrade", op.grade)
		p:SetAttribute("OpsLastKind", op.kind)
		fire("Ops_Debrief", p, {
			opId = op.id,
			kind = op.kind,
			title = op.def.displayName,
			grade = op.grade,
			stepGrade = grade,
			reason = reason,
			takeover = op.takeover,
			steps = timeline,
			condition = op.history,
			saved = op.saved,
			total = #op.casualties,
			cash = math.floor(reward.cash * mult + 0.5),
			rep = reward.rep,
			tip = tip,
			me = p.UserId,
			-- certifications earned, progress, exercise pass, promotion (ProgressionRules)
			badges = if training then training.badges else nil,
		})
	end
	closeOp(op)
	if op.coldOpen and op.owner then
		endColdOpen(op.owner, reason)
	end
	local snap: any = info(op) -- plus the debrief facts BadgeService / LeaderboardService read
	snap.reason, snap.storm, snap.saved, snap.towParted =
		reason, op.storm == true, op.saved, op.towParted == true
	snap.steps = table.create(#op.results)
	for _, r in op.results do
		table.insert(snap.steps, { id = r.stepId, grade = r.grade, userId = r.userId })
	end
	for _, fn in table.clone(handlers) do
		task.spawn(fn, snap, helpers)
	end
	print(
		`[OperationService] {op.id} {op.kind} finished ({reason}): {op.grade}, {#op.results} steps`
	)
end

---------------------------------------------------------------- results from clients

local function sanitize(raw: any): Types.Metrics
	local out: Types.Metrics = {}
	if type(raw) ~= "table" then
		return out
	end
	local n = 0
	for k, v in raw do
		if type(k) == "string" and #k <= 32 then
			if type(v) == "number" and v == v and math.abs(v) < math.huge then
				out[k] = math.clamp(v, -Types.Rules.MetricMax, Types.Rules.MetricMax)
				n += 1
			elseif type(v) == "boolean" then
				out[k] = v
				n += 1
			end
		end
		if n >= Types.Rules.MaxMetrics then
			break
		end
	end
	return out
end

---------------------------------------------------------------- PIW server metrics

-- Per step instance (weak keys): the search pattern the server measures from the boat's track,
-- and whether the casualty needed the helicopter when the transport step started.
local piwState: { [StepInst]: { pattern: PiwMetrics.Pattern?, needsHeli: boolean? } } = setmetatable(
	{},
	{ __mode = "k" }
) :: any
-- The deliver step a pad completed, per track. The client's own transport result for that step
-- arrives late: it is acknowledged with the pad's grade and otherwise ignored (no second
-- completion, step advance or pay).
local padDone: { [Track]: { key: string, grade: Grade } } = setmetatable({}, { __mode = "k" }) :: any

local function windDirection(): number
	local f = ReplicatedStorage:FindFirstChild("Weather")
	local w = f and f:GetAttribute("WindDirection")
	return if type(w) == "number" then w else 0
end

-- Every tick: sample the boat on a search step, note a transport's heli need at its start.
local function samplePiw(op: any, dt: number)
	for _, track in op.tracks do
		local inst = track.current
		local ci = inst and inst.casualtyIndex
		if not inst or not ci or inst.npc then
			continue
		end
		local st = piwState[inst]
		if inst.mechanicId == "search" then
			if not st then
				local rank = inst.assignee and inst.assignee:GetAttribute("RankIndex")
				local due = type(rank) == "number" and rank >= PiwMetrics.PATTERN_RANK_INDEX
				st = {
					pattern = if due
						then PiwMetrics.newPattern(casualtyPosition(op, ci), windDirection())
						else nil,
				}
				piwState[inst] = st
			end
			local pattern = st and st.pattern
			local boat = inst.assignee and (vehicleOf(inst.assignee) or vehicleOf(track.owner))
			if pattern and boat then
				PiwMetrics.samplePattern(
					pattern,
					boat:GetPivot().Position,
					casualtyPosition(op, ci),
					dt
				)
			end
		elseif inst.mechanicId == "transport" and not st then
			local c: CasualtyState = op.casualties[ci]
			piwState[inst] = {
				needsHeli = PiwMetrics.needsHeli(
					c.state,
					c.lifejacket,
					Condition.band(c.condition)
				),
			}
		end
	end
end

-- Cold open (docs 09 9.1): tell the jet ski when the approach step is current (BoatController's
-- Assist ease only acts then) and watch the replicated motion for an ease the client must have
-- made, so the Silver cap holds even if a client leaves its assistEase flag out.
local coldOpenEase: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function sampleColdOpen(op: any)
	if not op.coldOpen then
		return
	end
	for _, track in op.tracks do
		local inst = track.current
		local player = track.owner
		local boat = player and vehicleOf(player)
		if not boat then
			continue
		end
		local onApproach = inst ~= nil and not inst.npc and inst.mechanicId == "approach"
		if boat:GetAttribute("ColdOpenApproach") ~= onApproach then
			boat:SetAttribute("ColdOpenApproach", onApproach)
		end
		local root = boat.PrimaryPart
		local started = boat:GetAttribute("ColdOpenStart")
		if
			root
			and boat:GetAttribute("ColdOpenAutoThrottle") == true
			and type(started) == "number"
		then
			-- mirror the client's time / distance hand-over (it also hands over on input)
			local d = ((op.position - root.Position) * Vector3.new(1, 0, 1)).Magnitude
			if not BoatColdOpen.autoActive(Workspace:GetServerTimeNow() - started, d, 0) then
				boat:SetAttribute("ColdOpenAutoThrottle", false)
			end
		end
		if onApproach and root and not coldOpenEase[inst] then
			local cas = casualtyPosition(op, inst.casualtyIndex or 1)
			local distance = ((cas - root.Position) * Vector3.new(1, 0, 1)).Magnitude
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			local speed = if look.Magnitude > 1e-3
				then root.AssemblyLinearVelocity:Dot(look.Unit)
				else 0
			local spec = VehicleConfig.get(tostring(boat:GetAttribute("VehicleId")))
			local assist = player:GetAttribute("OpsPro") ~= true
			if
				BoatColdOpen.serverSawEase(
					assist,
					distance,
					speed,
					if spec then spec.brakeDecel else nil
				)
			then
				coldOpenEase[inst] = true
			end
		end
	end
end

-- destinationRight for a transport step: the pad reached (or, for the client's result, the pad
-- nearest the boat) suits the casualty. nil when there is no casualty to judge.
local function destinationRight(op: any, inst: StepInst, pad: string?, player: Player?): boolean?
	local ci = inst.casualtyIndex
	local c: CasualtyState? = if ci then op.casualties[ci] else nil
	if not c then
		return nil
	end
	local allowed: { string } = op.scene.spec.dropOffs or {}
	if not pad then
		local boat = player and vehicleOf(player)
		if boat then
			pad =
				PiwMetrics.nearestPad(RescueService.GetDropOffs(allowed), boat:GetPivot().Position)
		end
	end
	local st = piwState[inst]
	local heli = if st and st.needsHeli ~= nil
		then st.needsHeli
		else PiwMetrics.needsHeli(c.state, c.lifejacket, Condition.band(c.condition))
	return PiwMetrics.destinationRight(pad, heli, allowed)
end

-- Server-owned and server-derived metrics (CONTRACT.md "Operations v2": never taken from the client).
local function serverMetrics(op: any, inst: StepInst, metrics: Types.Metrics, rawResult: any)
	metrics.elapsed = now() - inst.startedAt
	local ci = inst.casualtyIndex
	local c: CasualtyState? = if ci then op.casualties[ci] else nil
	if c then
		metrics.conditionAtEnd = c.condition
		local method = type(rawResult.metrics) == "table" and rawResult.metrics.method
		if type(method) == "string" then
			metrics.rightMethod = method == Operations.RecoveryMethod[c.state]
		else
			(metrics :: any).rightMethod = nil
		end
		local tag = type(rawResult.metrics) == "table" and rawResult.metrics.tag
		if type(tag) == "string" then
			metrics.tagRight = tag == Operations.triageTag(c.state)
		else
			(metrics :: any).tagRight = nil
		end
		if inst.def.id == "movement" then
			local redWaiting = false
			for j, other in op.casualties do
				if
					j ~= ci
					and other.tag == "Red"
					and not other.delivered
					and not other.takenOver
				then
					redWaiting = true
				end
			end
			metrics.priorityOrder = not (redWaiting and c.tag ~= "Red")
		end
	end
	if inst.mechanicId == "search" then
		local st = piwState[inst]
		metrics.onPattern = PiwMetrics.onPattern(st and st.pattern)
	elseif inst.mechanicId == "transport" then
		local right = destinationRight(op, inst, nil, inst.assignee)
		-- a stub away from any pad has no destination to judge: graded on the rest
		local m: any = metrics
		m.destinationRight = if rawResult.stub == true and not right then nil else right
	end
	local pob = type(rawResult.metrics) == "table" and rawResult.metrics.pob
	if type(pob) == "number" then
		local expected = if op.isBig then op.saved else op.pob or #op.casualties
		metrics.pobRight = pob == expected
	else
		(metrics :: any).pobRight = nil
	end
end

local function onStepResult(player: Player, opId: any, key: any, raw: any)
	if type(opId) ~= "string" or type(key) ~= "string" or type(raw) ~= "table" then
		return
	end
	local op = ops[opId]
	if not op or op.state ~= "Active" then
		return
	end
	local track = trackOf(op, player)
	local inst = track and track.current
	if not track or not inst or inst.key ~= key then
		local done = track and padDone[track]
		if done and done.key == key then
			-- the pad already completed this deliver step: acknowledge it, change nothing
			fire(
				"Ops_StepAck",
				player,
				{ opId = opId, stepKey = key, accepted = true, grade = done.grade }
			)
			return
		end
		fire(
			"Ops_StepAck",
			player,
			{ opId = opId, stepKey = key, accepted = false, reason = "NotCurrent" }
		)
		return
	end
	if inst.npc or inst.assignee ~= player then
		fire(
			"Ops_StepAck",
			player,
			{ opId = opId, stepKey = key, accepted = false, reason = "NotYours" }
		)
		return
	end
	local elapsed = now() - inst.startedAt
	if elapsed < (inst.def.minSeconds or Types.Rules.DefaultMinSeconds) then
		fire(
			"Ops_StepAck",
			player,
			{ opId = opId, stepKey = key, accepted = false, reason = "TooFast" }
		)
		beginStep(op, track, inst.def, inst.attempt)
		return
	end
	if raw.failed == true then
		failStep(op, track, inst, "Failed")
		return
	end
	local metrics = sanitize(raw.metrics)
	local rawTag = if type(raw.metrics) == "table" then raw.metrics.tag else nil
	serverMetrics(op, inst, metrics, raw)
	if op.kind == "CapsizedFerry" then
		-- recompute what a ferry client could fake (rightCompartment, rescued, fractions)
		pcall(FerryValidate.apply, op.id, inst.def.id, metrics)
		if inst.def.id == "scene_command" and type(raw.board) == "table" then
			local taskIds = {}
			for _, t in SceneBoard.Tasks do
				taskIds[t.id] = true
			end
			local board, n = {}, 0
			for u, tid in raw.board do
				if type(u) == "string" and #u <= 40 and type(tid) == "string" and taskIds[tid] then
					board[u] = tid
					n += 1
					if n >= 16 then
						break
					end
				end
			end
			inst.board = board
		end
	end
	-- condition events the step allows, capped
	local ci = inst.casualtyIndex
	if ci and type(raw.events) == "table" and inst.def.allowedEvents then
		for name, max in inst.def.allowedEvents do
			local n = raw.events[name]
			if type(n) == "number" and n == n then
				Condition.applyEvent(op.casualties[ci], name, math.clamp(math.floor(n), 0, max))
			end
		end
		metrics.conditionAtEnd = op.casualties[ci].condition
	end
	local isStub = raw.stub == true
	local grade: Grade = Grading.resolveStep(inst.def, metrics, { stub = isStub }) :: any
	if isStub then
		-- a stub is graded on the server metrics it actually has (Silver cap)
		local present = {}
		for _, m in (inst.def.serverMetrics or {}) :: { string } do
			if metrics[m] ~= nil then
				table.insert(present, m)
			end
		end
		grade = Grading.cap(
			Grading.stepGrade(inst.def, metrics, present),
			Types.Rules.StubGradeCap :: any
		) :: any
	end
	if
		op.coldOpen
		and inst.mechanicId == "approach"
		and (metrics.assistEase == true or coldOpenEase[inst])
	then
		-- an Assist ease did part of the approach: Silver at best (docs 09 9.1, honest grades)
		metrics.assistEase = true
		(inst :: any).assistEase = true
		grade = BoatColdOpen.capGrade(grade, true) :: any
	end
	if rawTag == "Red" or rawTag == "Yellow" or rawTag == "Green" then
		inst.tag = rawTag
	end
	fire("Ops_StepAck", player, { opId = opId, stepKey = key, accepted = true, grade = grade })
	complete(op, track, inst, grade, player, metrics)
end

-- Swap station (docs 09 section 4.2): a human on the track takes a step an NPC is doing.
-- Ops_TowLength: the Crew stepped the tow out or in; the server line follows (clamped 30..150).
local function onTowLength(player: Player, opId: any, studs: any)
	local op = if type(opId) == "string" then ops[opId] else nil
	if not op or op.state ~= "Active" or type(studs) ~= "number" or studs ~= studs then
		return
	end
	if table.find(op.members, player) then
		pcall(RescueService.SetTowLength, op.scene, studs)
	end
end

local function onTakeStep(player: Player, opId: any, key: any)
	local op = if type(opId) == "string" then ops[opId] else nil
	if not op or op.state ~= "Active" then
		return
	end
	local track = trackOf(op, player)
	local inst = track and track.current
	if not track or not inst or inst.key ~= key or not inst.npc then
		return
	end
	if inst.def.id == "scene_command" then
		if not canCommand(player) then
			radio(op, "Coastguard", "Scene command needs a Coxswain or Helm certification.", player)
			return
		end
		op.osc = player
	end
	inst.npc = false
	inst.assignee = player
	inst.startedAt = now()
	inst.timeoutAt = inst.startedAt + inst.def.timeoutSec
	fire("Ops_StepStart", player, stepContext(op, track, inst, player))
	broadcast(op)
end

---------------------------------------------------------------- RescueService hooks

local function opOfScene(scene: any): any?
	return if type(scene) == "table" and scene.opId then ops[scene.opId] else nil
end

-- The prompts are disabled on ops-driven scenes; these keep RescueService's interface whole.
function OperationService.CanAct(scene: any, player: Player): boolean
	local op = opOfScene(scene)
	return op ~= nil and (op.isBig or trackOf(op, player) ~= nil)
end

function OperationService.RecordAction(_scene: any, _player: Player) end

function OperationService.Notify(scene: any, player: Player, message: string)
	local op = opOfScene(scene)
	if op then
		radio(op, "Crew", message, player)
	end
end

function OperationService.OnVictimBoarded(_scene: any, _player: Player) end

function OperationService.OnVictimLost(scene: any)
	local op = opOfScene(scene)
	if op then
		for i, v in scene.victims do
			if v.state == "Water" and op.casualties[i] and not op.casualties[i].delivered then
				op.casualties[i].inWater = true
			end
		end
		radio(op, "Crew", "Casualty back in the water!")
	end
end

function OperationService.OnTowAttached(_scene: any, _player: Player) end

function OperationService.OnTowLost(scene: any)
	local op = opOfScene(scene)
	if op then
		radio(op, "Crew", "The tow line came off!")
	end
end

-- RescueService's server line (TowMotion) parted: the casualty is adrift again, so the crew
-- re-passes the tow from the heaving line; those steps' old records go so the re-run grades count.
function OperationService.OnTowParted(scene: any)
	local op = opOfScene(scene)
	if not op or op.state ~= "Active" or op.takeover then
		return
	end
	radio(op, "Crew", "Line's parted! Heads down! Stand by, we'll pass it again.")
	for _, c in op.casualties do
		c.towed = false
	end
	local track: Track? = op.tracks[1]
	local back: number? = nil
	if track then
		for i, sdef in track.plan do
			if sdef.id == "heaving_line" then
				back = i
				break
			end
		end
	end
	if not track or not back or track.index <= back then
		return
	end
	local redo: { [string]: boolean } = {}
	for i = back, math.min(track.index, #track.plan) do
		redo[track.plan[i].id] = true
	end
	for i = #op.results, 1, -1 do
		local r = op.results[i]
		if r.trackId == track.id and redo[r.stepId] then
			table.remove(op.results, i)
		end
	end
	track.current = nil
	track.done = false
	track.index = back - 1
	advance(op, track)
end

function OperationService.OnTowDelivered(scene: any, _driver: Player?)
	local op = opOfScene(scene)
	if op then
		radio(op, "Haven Harbour", "Tow's at the pontoon. Bring her alongside.")
	end
end

-- A boat with casualties reached a pad: the real transport path. The current "deliver" step of
-- the driver's track completes with the server-measured condition and destination (no stub cap).
-- The pad and the client's transport result race: whichever reaches the step first completes it
	op.towParted = true -- no Tow Truck badge for this op
-- (complete() checks track.current), and the other is acknowledged and ignored.
function OperationService.OnVictimsDelivered(
	scene: any,
	_count: number,
	driver: Player?,
	pad: string?
)
	local op = opOfScene(scene)
	if not op or not driver or op.state ~= "Active" then
		return
	end
	local track = trackOf(op, driver)
	local inst = track and track.current
	if track and inst and inst.def.effect == "deliver" then
		local metrics: Types.Metrics = { elapsed = now() - inst.startedAt }
		local ci = inst.casualtyIndex
		if ci then
			metrics.conditionAtEnd = op.casualties[ci].condition
		end
		if inst.mechanicId == "transport" then
			local right = destinationRight(op, inst, pad, driver)
			if right ~= nil then
				metrics.destinationRight = right
			end
		end
		local grade: Grade = Grading.stepGrade(inst.def, metrics, inst.def.serverMetrics) :: any
		padDone[track] = { key = inst.key, grade = grade }
		if inst.assignee then
			fire(
				"Ops_StepAck",
				inst.assignee,
				{ opId = op.id, stepKey = inst.key, accepted = true, grade = grade }
			)
		end
		complete(op, track, inst, grade, driver, metrics)
	end
end

---------------------------------------------------------------- offers and lifecycle

local function offerPayload(op: any, tutorialIndex: number?): { [string]: any }
	local preview = if op.isBig
		then Grading.bigCompletionBonus(1, 1)
		else Grading.payout(op.def.weight, "Silver", 1, tutorialIndex)
	return {
		opId = op.id,
		kind = op.kind,
		title = op.def.displayName,
		radioLine = op.radioLine or op.def.radioLine,
		zoneName = op.zoneName,
		position = op.position,
		isBig = op.isBig,
		offerExpiresAt = op.offerExpiresAt,
		cash = preview.cash,
		rep = preview.rep,
	}
end

local function canTow(player: Player): boolean
	local ok, result = try("ProgressionService", "CanUseVehicle", player, "RIB")
	return if ok then result == true else true
end

local function offerTo(player: Player, forcedKind: string?)
	local st = stateOf(player)
	local choice = CallLogic.chooseCall(st.completed, weatherState(), canTow(player))
	local sceneKind = choice.kind
	local zone = choice.zone
	if forcedKind then
		sceneKind = if forcedKind == "DisabledVessel" then "Tow" else "Swimmer"
		zone = if sceneKind == "Tow" then "CalmBay" else "Near"
	end
	if sceneKind == "DriftingCraft" then
		sceneKind = "Swimmer" -- the two-casualty variant is [L] (docs 09 section 5)
	end
	local kind = Operations.FromCallKind[sceneKind]
	local op = newOp(kind, sceneKind, zone, CallLogic.pickSpawnPoint(zone))
	table.insert(op.offeredTo, player)
	st.offerOpId = op.id
	local tut = if st.completed < #Grading.Payout.Tutorial then st.completed else nil
	fire("Ops_Offered", player, offerPayload(op, tut))
	return op
end

local function withdrawOffer(op: any)
	for _, p in op.offeredTo do
		fire("Ops_Closed", p, { opId = op.id, reason = "Withdrawn", silent = true })
		local st = playerState[p]
		if st and st.offerOpId == op.id then
			st.offerOpId = nil
			st.nextOfferAt = now() + CallLogic.offerDelay(weatherState())
		end
	end
	ops[op.id] = nil
end

local function freeCrewOf(player: Player): { Player }
	local members = { player }
	local ok, crew = try("CrewService", "GetCrew", player)
	if ok and type(crew) == "table" then
		for _, mate in crew do
			if typeof(mate) == "Instance" and mate:IsA("Player") and mate ~= player then
				local ms = stateOf(mate)
				if not ms.activeOpId then
					if ms.offerOpId and ops[ms.offerOpId] then
						withdrawOffer(ops[ms.offerOpId])
					end
					ms.offerOpId = nil
					table.insert(members, mate)
				end
			end
		end
	end
	return members
end

local function activate(op: any, player: Player)
	op.state = "Active"
	op.owner = player
	op.acceptedAt = now()
	op.storm = weatherState() == "Storm"
	local members = freeCrewOf(player)
	for _, p in members do
		stateOf(p).activeOpId = op.id
		stateOf(p).offerOpId = nil
		table.insert(op.members, p)
	end
	rollCasualties(op, 1)
	RescueService.SpawnCall(op.scene)
	newTrack(op, player, members)
	radio(op, "Gale Isles Coastguard", op.radioLine or op.def.radioLine)
	advance(op, op.tracks[1])
end

local function joinBig(op: any, player: Player)
	if trackOf(op, player) then
		broadcast(op)
		return
	end
	local members = freeCrewOf(player)
	local fresh = {}
	for _, p in members do
		if not trackOf(op, p) then
			table.insert(fresh, p)
			stateOf(p).activeOpId = op.id
		end
	end
	table.insert(op.members, player)
	local track = newTrack(op, player, fresh)
	advance(op, track)
end

local function startBigOp()
	if bigOp then
		return
	end
	local count = CallLogic.bigCallVictimCount(#Players:GetPlayers())
	local op =
		newOp("CapsizedFerry", "CapsizedFerry", "FerrySite", CallTypes.SpawnZones.FerrySite.center)
	op.state = "Active"
	op.acceptedAt = now()
	op.offerExpiresAt = op.acceptedAt + op.def.capSeconds
	op.storm = true
	op.scene.total = count
	bigOp = op
	rollCasualties(op, count)
	local positions = CallLogic.scatterPoints(
		op.position,
		count,
		CallTypes.BigCall.FerryVictimMinRadius,
		CallTypes.BigCall.FerryVictimMaxRadius,
		"Outside"
	)
	RescueService.SpawnCall(op.scene, positions)
	Remotes.event("Ops_Offered"):FireAllClients(offerPayload(op))
	print(`[OperationService] big op {op.id}: Capsized Ferry with {count} casualties`)
end

local function onAccept(player: Player, opId: any)
	if type(opId) ~= "string" then
		return
	end
	local op = ops[opId]
	if not op then
		return
	end
	if op.isBig then
		if op.state == "Active" then
			joinBig(op, player)
		end
		return
	end
	if op.state ~= "Offered" or not table.find(op.offeredTo, player) then
		return
	end
	if stateOf(player).activeOpId then
		return
	end
	activate(op, player)
end

---------------------------------------------------------------- tick

local function tickOp(op: any, dt: number, t: number)
	if op.state ~= "Active" then
		return
	end
	samplePiw(op, dt)
	sampleColdOpen(op)
	local env = { storm = op.storm or weatherState() == "Storm", coldWater = false }
	local ferry = op.kind == "CapsizedFerry"
	for _, c in op.casualties do
		local before = c.condition
		Condition.step(c, dt, env)
		if ferry and c.tag and not c.delivered and not c.takenOver and c.condition < before then
			-- an under-triaged casualty waiting on scene declines faster (docs 09 section 7)
			local f = FerryValidate.driftFactor(c.tag, c.state)
			if f > 1 then
				c.condition = math.clamp(c.condition - (before - c.condition) * (f - 1), 0, 100)
			end
		end
	end
	if t - op.lastSample >= 5 then
		op.lastSample = t
		local values = {}
		for _, c in op.casualties do
			table.insert(values, math.floor(c.condition + 0.5))
		end
		table.insert(op.history, { t = math.floor(t - op.acceptedAt), c = values })
	end
	-- takeover: a casualty at Critical, or the cap (big call: the cap ends it, Criticals are lifted)
	local elapsed = t - op.acceptedAt
	if op.isBig then
		for _, c in op.casualties do
			if Condition.isCritical(c) then
				c.takenOver = true
				radio(op, "Rescue Gale One", "Rescue Gale One has the casualty. Carry on.")
			end
		end
		if elapsed > op.def.capSeconds then
			finish(op, "Timer")
			return
		end
	elseif not op.takeover then
		local yes, why = Condition.shouldTakeover(op.casualties, elapsed, op.def.capSeconds)
		if yes then
			startTakeover(op, why or "Critical")
		end
	end
	for _, track in op.tracks do
		local inst = track.current
		if inst and op.state == "Active" then
			-- a big-call casualty lifted by the helicopter mid-run: drop it
			if op.isBig and inst.casualtyIndex and op.casualties[inst.casualtyIndex].takenOver then
				track.current = nil
				track.casualtyIndex = nil
				advance(op, track)
			elseif inst.npc then
				if t >= inst.npcDoneAt then
					npcFinish(op, track, inst)
				end
			elseif t > inst.timeoutAt then
				failStep(op, track, inst, "Timeout")
			elseif inst.assignee and not inst.assignee.Parent then
				inst.npc = true
				inst.assignee = nil
			end
		end
	end
	if op.state == "Active" and op.isBig then
		local open = false
		for _, c in op.casualties do
			open = open or not (c.delivered or c.takenOver)
		end
		local allDone = true
		for _, tr in op.tracks do
			allDone = allDone and tr.done
		end
		if not open and allDone and #op.tracks > 0 then
			finish(op, "Complete")
		end
	end
end

local lastTick = 0
local function tick()
	local t = now()
	local dt = if lastTick > 0 then math.min(t - lastTick, 2) else 0
	lastTick = t
	local state = weatherState()
	if state == "Storm" and lastWeatherState ~= "Storm" then
		startBigOp()
	end
	lastWeatherState = state
	for _, op in table.clone(ops) do
		if op.state == "Offered" and t > op.offerExpiresAt then
			withdrawOffer(op)
		else
			-- the cold open ends (never restarts) when its rider dies or leaves the jet ski
			local e = op.coldOpen and op.owner and coldOpenFlow[op.owner]
			local why = nil
			if e and op.state == "Active" then
				local alive, onCraft = coldOpenRiderStatus(op.owner)
				why = ColdOpenFlow.watch(e, t, alive, onCraft)
			end
			if why then
				finish(op, why)
			else
				tickOp(op, dt, t)
			end
		end
	end
	-- live HUD: condition values every ~1 s
	if math.floor(t) ~= math.floor(t - dt) then
		for _, op in ops do
			if op.state == "Active" then
				broadcast(op)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local st = stateOf(player)
		if not st.activeOpId and not st.offerOpId and t >= st.nextOfferAt and player.Character then
			local e = coldOpenEntry(player)
			local decision = if e.phase == "NotStarted"
					and OperationService.ColdOpenAuto
					and st.completed == 0
				then ColdOpenFlow.decide(e, true, 0, coldOpenDone(player))
				else ColdOpenFlow.decide(e, OperationService.ColdOpenAuto, st.completed, true)
			if decision == "Start" then
				OperationService.StartColdOpen(player)
			elseif decision == "Abandon" then
				-- its op is gone (a start error, closed without finish): hand over, never replay
				if t - (coldOpenBegunAt[player] or -math.huge) > COLD_OPEN_START_GRACE then
					endColdOpen(player, "Lost")
				end
			elseif
				decision == "Offer"
				-- Off duty (ExplorationService, docs 10 section 5.1): no standard taskings after the tutorials
				and not (
					player:GetAttribute("OffDuty") == true
					and st.completed >= #Grading.Payout.Tutorial
				)
			then
				offerTo(player)
			end -- "Wait": the profile is still loading, ask again next tick
		end
	end
end

---------------------------------------------------------------- contract API

function OperationService.GetActiveOperations(): { OperationInfo }
	local out = {}
	for _, op in ops do
		if op.state == "Active" then
			table.insert(out, info(op))
		end
	end
	return out
end

function OperationService.GetOperationOf(player: Player): OperationInfo?
	for _, op in ops do
		if op.state == "Active" and (trackOf(op, player) or table.find(op.members, player)) then
			return info(op)
		end
	end
	return nil
end

-- Positions still to reach for that player's operations (Bosun points at these).
function OperationService.GetVictimPositions(player: Player): { Vector3 }
	local out = {}
	for _, op in ops do
		if op.state == "Active" and (op.isBig or trackOf(op, player)) then
			for _, p in RescueService.GetTargets(op.scene) do
				table.insert(out, p)
			end
		end
	end
	return out
end

---------------------------------------------------------------- cold open (first session)

-- The cold open (design change, 2026-10): a new player spawns already seated on a moving jet ski
-- near the Harbour Mouth with a Person in the Water operation already tasked (the radio ack is
-- auto-done) and rescues the casualty within about 90 s; the station and onboarding come after.
-- Plan: tasking (auto, Gold) -> approach -> recovery; Assist on; condition drift x0.5.
OperationService.ColdOpenPlan = { "tasking", "approach", "recovery" }
OperationService.ColdOpenDriftScale = 0.5
-- studs ahead of the spawn CFrame (tune). The jet ski runs in at ColdOpen.AUTO_SPEED (20 kn)
-- and hands the throttle over ColdOpen.HANDOVER_DISTANCE (170) studs short, so it coasts in.
OperationService.ColdOpenDistance = { 220, 260 }

-- Starts the cold open for `player`, at most once per session (ColdOpenFlow): nil once it has
-- run, whatever the outcome. `spawnCFrame` is where the jet ski starts (default: the Harbour
-- Mouth zone centre, facing out to sea). `replay` (Studio dev only) runs it again. Returns the
-- operation id.
function OperationService.StartColdOpen(
	player: Player,
	spawnCFrame: CFrame?,
	replay: boolean?
): string?
	local st = stateOf(player)
	if st.activeOpId and ops[st.activeOpId] then
		return st.activeOpId
	end
	local flow = coldOpenEntry(player)
	if replay and flow.phase == "Finished" then
		ColdOpenFlow.reset(flow)
	end
	-- Running from here: if anything below throws, the tick abandons it instead of replaying
	if not ColdOpenFlow.begin(flow) then
		return nil
	end
	coldOpenBegunAt[player] = now()
	if st.offerOpId and ops[st.offerOpId] then
		withdrawOffer(ops[st.offerOpId])
	end
	local zone = CallTypes.SpawnZones.HarbourMouth
	local cf = spawnCFrame
		or CFrame.lookAt(
			zone.center,
			zone.center + (zone.center - CallTypes.STATION) * Vector3.new(1, 0, 1)
		)
	-- CONTRACT: VehicleService.SpawnColdOpen(player, cframe): Model? spawns a jet ski at `cframe`,
	-- seats the player and gives it some forward speed (stream B). Called through pcall.
	local okSpawn, spawnErr = try("VehicleService", "SpawnColdOpen", player, cf)
	if not okSpawn then
		warn(`[OperationService] cold open: VehicleService.SpawnColdOpen unavailable ({spawnErr})`)
	end
	local d = OperationService.ColdOpenDistance
	local ahead = cf.LookVector * Vector3.new(1, 0, 1)
	ahead = if ahead.Magnitude > 1e-3 then ahead.Unit else Vector3.new(0, 0, 1)
	local pos = cf.Position * Vector3.new(1, 0, 1) + ahead * rng:NextNumber(d[1], d[2])
	local op = newOp("PersonInWater", "Swimmer", "HarbourMouth", pos)
	op.coldOpen = true
	flow.opId = op.id
	op.planIds = OperationService.ColdOpenPlan
	op.offeredTo = { player }
	player:SetAttribute("OpsPro", false) -- Assist mode
	op.state = "Active"
	op.owner = player
	op.acceptedAt = now()
	st.activeOpId = op.id
	table.insert(op.members, player)
	table.insert(op.casualties, Condition.new(`{op.id}-1`, "Alert", true, 85))
	op.casualties[1].driftScale = OperationService.ColdOpenDriftScale
	-- BoatController's cold-open helm (shared/Boat/ColdOpen): auto-throttle, then hand-over
	local boat = vehicleOf(player)
	if boat then
		boat:SetAttribute("ColdOpenOpId", op.id)
		boat:SetAttribute("ColdOpenTarget", pos)
		boat:SetAttribute("ColdOpenStart", Workspace:GetServerTimeNow())
		boat:SetAttribute("ColdOpenApproach", false)
		boat:SetAttribute("ColdOpenAutoThrottle", true)
	end
	RescueService.SpawnCall(op.scene)
	local track = newTrack(op, player, { player })
	-- the radio ack is auto-done: record it as the player's (Gold) and go straight to the approach
	radio(
		op,
		"Gale Isles Coastguard",
		"Haven Rescue, person in the water dead ahead of you. Go get them!"
	)
	track.index = 1
	local tasking = track.plan[1]
	if tasking and tasking.id == "tasking" then
		table.insert(op.results, {
			stepId = tasking.id,
			label = tasking.label,
			realTerm = tasking.realTerm,
			grade = "Gold",
			weight = tasking.weight,
			by = player.Name,
			userId = player.UserId,
			trackId = track.id,
			at = 0,
		})
		op.helpers[player] = true
		try("CrewService", "RecordRoleAction", player, op.id)
	else
		track.index = 0
	end
	advance(op, track)
	return op.id
end

-- Dev helpers (Studio).
function OperationService.ForceBigCall()
	startBigOp()
end

function OperationService.DevStart(player: Player, kind: string?): string?
	local st = stateOf(player)
	if st.activeOpId and ops[st.activeOpId] then
		return st.activeOpId
	end
	if st.offerOpId and ops[st.offerOpId] then
		withdrawOffer(ops[st.offerOpId])
	end
	if kind == "CapsizedFerry" then
		startBigOp()
		if bigOp then
			joinBig(bigOp, player)
			return bigOp.id
		end
		return nil
	end
	local op = offerTo(player, kind or "PersonInWater")
	activate(op, player)
	return op.id
end

local function onPlayerAdded(player: Player)
	stateOf(player)
	coldOpenEntry(player)
	-- died during the cold open: the next character starts at the station
	player.CharacterAdded:Connect(function(character)
		if not stationOnSpawn[player] then
			return
		end
		stationOnSpawn[player] = nil
		task.defer(function()
			if
				character.Parent
				and (character.PrimaryPart or character:WaitForChild("HumanoidRootPart", 5))
			then
				sendToStation(player)
			end
		end)
	end)
	if bigOp then
		task.delay(5, function()
			if bigOp and player.Parent then
				fire("Ops_Offered", player, offerPayload(bigOp))
			end
		end)
	end
	if RunService:IsStudio() then
		player.Chatted:Connect(function(msg)
			if msg == "/ferry" then
				startBigOp()
			elseif msg == "/op" or msg == "/tow" then
				OperationService.DevStart(
					player,
					if msg == "/tow" then "DisabledVessel" else "PersonInWater"
				)
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	playerState[player] = nil
	coldOpenFlow[player] = nil
	stationOnSpawn[player] = nil
	coldOpenBegunAt[player] = nil
	for _, op in table.clone(ops) do
		local j = table.find(op.offeredTo, player)
		if j then
			table.remove(op.offeredTo, j)
		end
		local i = table.find(op.members, player)
		if i then
			table.remove(op.members, i)
		end
		for _, t in op.tracks do
			local k = table.find(t.members, player)
			if k then
				table.remove(t.members, k)
			end
			if t.owner == player and t.members[1] then
				t.owner = t.members[1]
			end
		end
		if not op.isBig then
			if op.state == "Offered" and #op.offeredTo == 0 then
				ops[op.id] = nil
			elseif op.state == "Active" and #everyone(op) == 0 then
				op.state = "Done"
				closeOp(op)
			end
		end
	end
end

function OperationService.Init()
	Remotes.init()
	Remotes.event("Ops_Accept").OnServerEvent:Connect(onAccept)
	Remotes.event("Ops_StepResult").OnServerEvent:Connect(onStepResult)
	Remotes.event("Ops_TakeStep").OnServerEvent:Connect(onTakeStep)
	Remotes.event("Ops_TowLength").OnServerEvent:Connect(onTowLength)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		onPlayerAdded(p)
	end
	if RunService:IsStudio() then
		-- Studio dev hook for tools/studio/smoke.py ("ops"): ServerStorage.OpsDev:Invoke(cmd, ...)
		local dev = Instance.new("BindableFunction")
		dev.Name = "OpsDev"
		dev.OnInvoke = function(cmd: string, a: any): any
			if cmd == "timescale" then
				OperationService.DevTimeScale = tonumber(a) or 1
				return OperationService.DevTimeScale
			elseif cmd == "start" then
				local p = Players:GetPlayers()[1]
				return if p then OperationService.DevStart(p, a) else nil
			elseif cmd == "coldopen" then
				local p = Players:GetPlayers()[1]
				return if p then OperationService.StartColdOpen(p, nil, true) else nil
			elseif cmd == "status" then
				local p = Players:GetPlayers()[1]
				local op = if p then OperationService.GetOperationOf(p) else nil
				local live = op and ops[op.id]
				return {
					op = op and op.id,
					results = if live then #live.results else 0,
					current = if live
							and live.tracks[1]
							and live.tracks[1].current
						then live.tracks[1].current.def.id
						else nil,
					lastGrade = p and p:GetAttribute("OpsLastGrade"),
					completed = p and p:GetAttribute("OpsCompleted"),
				}
			end
			return nil
		end
		dev.Parent = ServerStorage
	end
end

function OperationService.Start()
	lastWeatherState = weatherState()
	local vs = service("VehicleService")
	if vs and type(vs.SpawnColdOpen) == "function" then
		OperationService.ColdOpenAuto = true
	end
	while true do
		local ok, err = pcall(tick :: any)
		if not ok then
			warn(`[OperationService] tick failed: {err}`)
		end
		task.wait(0.25)
	end
end

return OperationService
