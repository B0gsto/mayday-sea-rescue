--!strict
-- OperationService: rescue operations v2 (docs/09-rescue-operations.md, CONTRACT.md "Operations v2").
-- The one source of truth for the radio and rescues. It offers operations (the first-call chain,
-- the storm rate, the Capsized Ferry at storm start), runs each operation's step state machine
-- (every op: radio_ack -> launch -> auto_board -> transport, docs/16 K1; the track owner does every
-- step, an NPC crewmate only fills in when they leave), validates the step results clients submit
-- (the server recomputes the grade from metrics), ticks every casualty's condition meter, runs the
-- takeover at Critical, and pays through ProgressionService.Award.
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
local OfferPacing = require(Shared:WaitForChild("Calls"):WaitForChild("OfferPacing"))
local RescueVariants = require(Shared:WaitForChild("Config"):WaitForChild("RescueVariants"))
local Weather = require(Shared:WaitForChild("Weather"))
local OpsFolder = Shared:WaitForChild("Ops")
local Board = require(OpsFolder:WaitForChild("Board"))
local Condition = require(OpsFolder:WaitForChild("Condition"))
local Grading = require(OpsFolder:WaitForChild("Grading"))
local Operations = require(OpsFolder:WaitForChild("Operations"))
local Remotes = require(OpsFolder:WaitForChild("Remotes"))
local Types = require(OpsFolder:WaitForChild("Types"))

local BoatColdOpen = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpen"))
local RescueService = require(script.Parent:WaitForChild("RescueService") :: ModuleScript) :: any
-- the cold open's per-player lifecycle: runs at most once, never restarts by itself
local ColdOpenFlow = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpenFlow"))
-- the first session's fail-safe calls (docs/15 section 3)
local Onboarding = require(Shared:WaitForChild("Onboarding"))
-- The scenes around the survivors (spectacle only, docs/16 K1): the rip's variant and current,
local RipFlow = require(script.Parent.Parent:WaitForChild("Ops"):WaitForChild("RipFlow"))
-- the listing fishing boat, the burning cruiser.
local FireScene = require(script.Parent.Parent:WaitForChild("Ops"):WaitForChild("FireScene"))
local NpcPickup = require(script.Parent.Parent:WaitForChild("Ops"):WaitForChild("NpcPickup"))
local SinkingScene = require(script.Parent.Parent:WaitForChild("Ops"):WaitForChild("SinkingScene"))

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
	variant: string?,
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
	failed: boolean?, -- timed out or failed (failStep): a ride home then never takes them off the boat
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

-- Fire and sinking: the survivors tire this much faster (docs/16 K1, urgency). -- tune
OperationService.FAST_TIRING = 1.6

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
local lastActiveAt: { [Player]: number } = {} -- last tick on an operation: the idle nudge's clock
local COLD_OPEN_START_GRACE = 10 -- s before a cold open that never got its op counts as lost
local nextId = 0
local bigOp: any = nil
local bigLastEnd = 0 -- the last big call's end (Start: the server start), for OfferPacing.nextBigCallAt
local bigReadySince: number? = nil -- since when a player past the tutorial chain has been on
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

-- A Great Storm or a live event quickens the offer rhythm (G69).
local function offerRushed(): boolean
	if Weather.isGreatStorm() then
		return true
	end
	local live = ReplicatedStorage:FindFirstChild("LiveOpsState")
	return live ~= nil and live:GetAttribute("Phase") == "Active"
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

-- One of a new player's first three station calls (the saved total, so a returning player's first
-- calls of a session are not): no time cap and a calm swimmer in a lifejacket (docs/15 section 3).
local function onboardingCall(player: Player?): boolean
	local total = player and player:GetAttribute("OpsCompletedTotal")
	return type(total) == "number" and Onboarding.failsafeCall(total)
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
	player:SetAttribute("ColdOpenActive", nil)
	markColdOpenDone(player)
	try("TelemetryService", "ColdOpenEnded", player, reason) -- RP-A1 onboarding funnel
	local ok, v = try("VehicleService", "GetVehicle", player)
	if ok and typeof(v) == "Instance" and v:IsA("Model") then
		v:SetAttribute("ColdOpenApproach", false)
		v:SetAttribute("ColdOpenAutoThrottle", false)
	end
	local msg = ColdOpenFlow.radioFor(reason)
	fire("Ops_Radio", player, { opId = opId or "", from = msg.from, text = msg.text })
	local alive, onCraft = coldOpenRiderStatus(player)
	local how = ColdOpenFlow.handover(alive, onCraft)
	-- Handover first: OnboardingController reads it when ColdOpenEnded fires
	player:SetAttribute("ColdOpenHandover", how)
	player:SetAttribute("ColdOpenEnded", reason) -- Studio tests
	if how ~= "Ride" then
		try("VehicleService", "Stow", player) -- the abandoned jet ski waits at the bay, not at sea
	end
	if how == "Station" then
		sendToStation(player)
	elseif how == "Respawn" then
		stationOnSpawn[player] = true
	end -- "Ride": they keep the jet ski and stay seated; call 2 is offered there (docs/16 B2, K18)
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

---------------------------------------------------------------- crew

local function vehicleOf(player: Player): Model?
	local ok, v = try("VehicleService", "GetVehicle", player)
	return if ok and typeof(v) == "Instance" and v:IsA("Model") then v else nil
end

-- Every step is the track owner's (a crewmate rides along); nobody left: an NPC crewmate takes it.
local function stepAssignee(track: Track): Player?
	if track.owner.Parent then
		return track.owner
	end
	for _, p in track.members do
		if p.Parent then
			return p
		end
	end
	return nil
end

---------------------------------------------------------------- snapshots

local function casualtyPosition(op: any, index: number): Vector3
	local v = op.scene.victims and op.scene.victims[index]
	if v and v.floater and v.state == "Water" then
		return v.floater.cf.Position
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
		plan = plan,
		results = done,
		current = current,
		casualties = casualties,
		saved = op.saved,
		total = #op.casualties,
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
		variant = op.variant,
	}
end

---------------------------------------------------------------- creation

local function newOp(
	kind: string,
	sceneKind: string,
	zone: string,
	position: Vector3,
	victims: number? -- survivors in the water (default: the scene kind's count)
): any
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
		history = {} :: { { t: number, c: { number } } },
		lastSample = 0,
		saved = 0,
		takeover = nil :: { reason: string, at: number }?,
		grade = nil :: string?,
		scene = {
			id = id,
			kind = sceneKind,
			spec = spec,
			position = position,
			total = victims or spec.victims,
			victims = {},
			isBig = def.isBig,
			opsDriven = true,
			opId = id,
		},
	}
	op.scene.casualties = op.casualties
	-- 2026-10-21: a personal call's casualty is its crew's only until aboard (no stealing); big calls stay public
	op.scene.privateTo = if def.isBig then nil else op.members
	-- the rare-call variant (docs/15 H2), at its base weight in any weather; Studio can force one
	local forcedVariant = RunService:IsStudio() and Workspace:GetAttribute("RescueVariantForce")
	local variant = RescueVariants.choose(
		kind,
		rng:NextNumber(),
		if type(forcedVariant) == "string" then forcedVariant else nil
	)
	if variant then
		op.variant = variant.id
		op.scene.variant = variant.id
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
		plan = op.def.steps,
		index = 0,
		current = nil,
		casualtyIndex = nil, -- claimed by the per-casualty run (advance)
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
local startTakeover: (op: any, reason: string, raced: number?) -> ()

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
	local assignee = stepAssignee(track)
	local t = now()
	local inst: StepInst = {
		key = `{track.id}:{track.seq}`,
		def = def,
		mechanicId = def.mechanicId,
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
	})
	if op.coldOpen and op.owner then -- RP-A1 onboarding funnel
		try("TelemetryService", "ColdOpenStep", op.owner, inst.def.id)
	end
	if by then
		op.helpers[by] = true
		try("CrewService", "RecordRoleAction", by, op.id)
	end
end

-- A casualty is home: counted once; on a big call they leave the boat and the rescuer is paid for them.
local function deliverCasualty(op: any, ci: number, actor: Player?)
	local c: CasualtyState? = op.casualties[ci]
	if not c or c.delivered then
		return
	end
	c.delivered = true
	op.saved += 1
	if op.isBig then
		pcall(RescueService.RemoveVictim, op.scene, ci)
		local pay = Grading.bigCasualtyPay()
		if actor and actor.Parent then
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

local function applyEffect(op: any, track: Track, inst: StepInst, by: Player?)
	local effect = inst.def.effect
	local ci = inst.casualtyIndex
	local c: CasualtyState? = if ci then op.casualties[ci] else nil
	local actor = by or track.owner
	if effect == "board" and c and ci then
		c.inWater = false
		c.aboard = true
		c.panicking = false
		pcall(RescueService.BoardVictim, op.scene, ci, actor)
	elseif effect == "deliver" and ci and not (inst.failed and op.isBig) then
		-- a big call's delivery takes them off the boat: a failed ride home leaves them aboard, and
		-- the pad lands them whenever the boat gets in (OnVictimsDelivered)
		deliverCasualty(op, ci, actor)
	end
end

local function complete(op: any, track: Track, inst: StepInst, grade: Grade, by: Player?)
	if track.current ~= inst then
		return
	end
	track.current = nil
	record(op, track, inst, grade, by)
	applyEffect(op, track, inst, by)
	advance(op, track)
end

local function npcFinish(op: any, track: Track, inst: StepInst)
	complete(op, track, inst, "Silver", nil)
end

-- onFail handling (timeout or a client failed = true).
local function failStep(op: any, track: Track, inst: StepInst, why: string)
	local def = inst.def
	local action = def.onFail
	inst.failed = true
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
		if Operations.canFail(op.coldOpen == true, onboardingCall(op.owner)) then
			startTakeover(op, "StepFailed")
		else
			beginStep(op, track, def, inst.attempt) -- the first missions cannot fail: try again
		end
		return
	elseif action == "continue" then
		complete(op, track, inst, "Bronze", inst.assignee)
		return
	end
	complete(op, track, inst, "Fail", nil)
end

-- Claims the next casualty for a track: its own still to bring home, else an unclaimed one.
local function claimCasualty(op: any, track: Track): number?
	for i, c in op.casualties do
		if Board.mayTake(c, track.id) then
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
		-- a finished per-casualty run loops back while casualties remain
		local prev = track.plan[track.index]
		local after = track.plan[track.index + 1]
		if track.loopStart and prev and prev.perCasualty and not (after and after.perCasualty) then
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
		if def.perCasualty then
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
			if def.effect == "board" and op.casualties[ci].aboard then
				continue -- they already climbed aboard (stepBoarding): straight to the ride home
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

-- `raced`: the casualty the K15 racer already has alongside; it picks them up itself (op.raceDone).
startTakeover = function(op: any, reason: string, raced: number?)
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
		`Haven Rescue, Gale Isles Coastguard. {op.def.takeoverAsset} will take over.`
	)
	-- 2026-10-21: casualties still in the water are picked up by an NPC boat in front of the player
	-- (the same climb aboard); the op ends, unpaid, once they are all aboard it
	local waiting = 0
	local function one()
		waiting -= 1
		if waiting == 0 then
			finish(op, "Takeover")
		end
	end
	if raced then
		waiting += 1
		op.raceDone = one
	end
	local vehicles = service("VehicleService")
	for i, c in op.casualties do
		if
			vehicles
			and i ~= raced
			and not c.delivered
			and not c.aboard
			and RescueService.VictimPosition(op.scene, i)
		then
			waiting += 1
			NpcPickup.run(vehicles, function()
				return RescueService.VictimPosition(op.scene, i)
			end, function()
				return (RescueService.ReleaseVictim(op.scene, i))
			end, one)
		end
	end
	if waiting == 0 then
		finish(op, "Takeover")
		return
	end
	for _, t in op.tracks do
		t.current = nil
		t.done = true
	end
	broadcast(op)
end

---------------------------------------------------------------- finishing and pay

local function closeOp(op: any)
	op.state = "Done"
	ops[op.id] = nil
	pcall(SinkingScene.Cleanup, op.scene)
	pcall(FireScene.Cleanup, op.scene)
	pcall(RescueService.Cleanup, op.scene)
	if op == bigOp then
		bigOp = nil
		bigLastEnd = now()
	end
	for _, p in everyone(op) do
		local st = playerState[p]
		if st and st.activeOpId == op.id then
			st.activeOpId = nil
			st.offerOpId = nil
			-- the cold open leaves room for Chief Aggie's walk-up and welcome before the next call
			st.nextOfferAt = now()
				+ (
					if op.coldOpen
						then BoatColdOpen.NEXT_CALL_DELAY
						else OfferPacing.afterOp(op.isBig, weatherState(), offerRushed())
				)
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
		table.insert(scored, { grade = r.grade, weight = r.weight })
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
				reward = Grading.bigCompletionBonus(op.saved, #op.casualties)
				paidAs = "Op:CapsizedFerry"
			elseif op.takeover then
				-- 2026-10-21: no pay for failing; only casualties brought home pay
				reward = Grading.takeoverPayout(op.def.weight, op.saved, #op.casualties, humans)
				paidAs = `Op:{op.kind}:Takeover`
			else
				local tut = if st.completed < #Grading.Payout.Tutorial then st.completed else nil
				reward = Grading.payout(op.def.weight, grade, humans, tut)
				paidAs = `Op:{op.kind}`
			end
			st.completed += 1
			p:SetAttribute("OpsCompleted", st.completed)
		else
			reward = if op.takeover
				then { cash = 0, rep = 0 }
				else Grading.shareWithoutStep(op.def.weight)
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
		-- the saved count of finished operations (ProgressionService); takeovers never count
		if op.helpers[p] and not op.takeover then
			try("ProgressionService", "RecordTraining", p, grade)
		end
		p:SetAttribute("OpsLastGrade", op.grade)
		p:SetAttribute("OpsLastKind", op.kind)
		try("TelemetryService", "OpFinished", p, op, reason) -- RP-A1: grade, fail reason, first op
		fire("Ops_Debrief", p, {
			opId = op.id,
			kind = op.kind,
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
		})
	end
	closeOp(op)
	if op.coldOpen and op.owner then
		endColdOpen(op.owner, reason)
	end
	local snap: any = info(op) -- plus the debrief facts BadgeService / LeaderboardService read
	snap.reason, snap.storm, snap.saved = reason, op.storm == true, op.saved
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

-- The deliver or board step the server completed itself (a pad reached, a survivor aboard), per track.
-- The client's own result for that step arrives late: it is acknowledged with the server's grade and
-- otherwise ignored (no second completion, step advance or pay).
local padDone: { [Track]: { key: string, grade: Grade } } = setmetatable({}, { __mode = "k" }) :: any

-- Cold open (docs 09 9.1): tell the jet ski when the recovery step is current (BoatController's
-- ease only acts then, so a full-throttle run brakes near the casualty) and end the auto-throttle.
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
		local onApproach = inst ~= nil and not inst.npc and inst.def.id == "recovery"
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
	end
end

-- Server-owned and server-derived metrics (CONTRACT.md "Operations v2": never taken from the client).
local function serverMetrics(op: any, inst: StepInst, metrics: Types.Metrics)
	metrics.elapsed = now() - inst.startedAt
	local c: CasualtyState? = if inst.casualtyIndex then op.casualties[inst.casualtyIndex] else nil
	if c then
		metrics.conditionAtEnd = c.condition
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
			-- the server already completed this step: acknowledge it, change nothing
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
	serverMetrics(op, inst, metrics)
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
	fire("Ops_StepAck", player, { opId = opId, stepKey = key, accepted = true, grade = grade })
	complete(op, track, inst, grade, player)
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

-- A boat with casualties reached a pad: the real transport path. The current "deliver" step of
-- the driver's track completes with the server-measured condition (no stub cap).
-- The pad and the client's transport result race: whichever reaches the step first completes it
-- (complete() checks track.current), and the other is acknowledged and ignored.
function OperationService.OnVictimsDelivered(
	scene: any,
	_count: number,
	driver: Player?,
	_pad: string?
)
	local op = opOfScene(scene)
	if not op or not driver or op.state ~= "Active" then
		return
	end
	-- everyone this boat landed counts, not only the current step's casualty
	for i, v in scene.victims do
		local c = op.casualties[i]
		if v.state == "Delivered" and c and not c.delivered then
			deliverCasualty(op, i, driver)
		end
	end
	local track = trackOf(op, driver)
	local inst = track and track.current
	if track and inst and inst.def.effect == "deliver" then
		local metrics: Types.Metrics = { elapsed = now() - inst.startedAt }
		local ci = inst.casualtyIndex
		if ci then
			metrics.conditionAtEnd = op.casualties[ci].condition
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
		complete(op, track, inst, grade, driver)
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

-- G69 idle nudge: standing on foot (not seated in a boat or car) and how far from the station.
local function stationIdle(player: Player): (boolean, number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character.PrimaryPart
	if not (humanoid and root and humanoid.Health > 0 and not humanoid.Sit) then
		return false, math.huge
	end
	return true, CallLogic.flatDistance(root.Position, CallTypes.STATION)
end

-- In the sea on foot (swimming or wading chest-deep): a call waits until they are out or aboard.
-- The sea is at Y 0 (no Terrain water). SwimController holds a swimmer in Swimming (the owner's state
-- replicates), so wave bob can't let a call through; the depth test still catches chest-deep wading.
local function inWater(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character.PrimaryPart
	return humanoid ~= nil
		and root ~= nil
		and not humanoid.Sit
		and (humanoid:GetState() == Enum.HumanoidStateType.Swimming or root.Position.Y < -0.5)
end

local SkyFlare = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("SkyFlare"))

-- forcedKind: an operation id, or "EasyCall" (the idle nudge: a swimmer close in, in calm water).
local function offerTo(player: Player, forcedKind: string?, opts: any?)
	local st = stateOf(player)
	local choice = CallLogic.chooseCall(st.completed, weatherState())
	local kind = Operations.FromCallKind[choice.kind]
	local sceneKind, zone, victims = choice.kind, choice.zone, choice.victims
	if forcedKind == "EasyCall" then
		kind, sceneKind, zone, victims = "PersonInWater", "Swimmer", "CalmBay", nil
	elseif forcedKind then
		local forced = Operations.get(forcedKind)
		-- an unknown kind (or the ferry): a swimmer
		local def = if forced and not forced.isBig then forced else Operations.Defs.PersonInWater
		kind, sceneKind = def.id, def.sceneKinds[1]
		zone, victims = CallTypes.Kinds[sceneKind].zones[1], nil
	end
	if sceneKind == "WildlifeRescue" then
		sceneKind, zone = "Swimmer", "Near" -- the animal rides the swimmer scene (SanctuaryService)
	end
	local op = newOp(kind, sceneKind, zone, CallLogic.pickSpawnPoint(zone), victims)
	if kind == "WildlifeRescue" then
		try("SanctuaryService", "DressOffer", op, player)
	end
	if opts and type(opts.variant) == "string" then
		local forced = RescueVariants.get(kind, opts.variant)
		if forced then
			op.variant = forced.id
			op.scene.variant = forced.id
		end
	end
	pcall(SkyFlare.announce, op) -- a Legendary / Epic call's sky flare; never blocks the call
	if kind == "RipCurrent" then
		RipFlow.Task(op) -- the variant (swimmer / body-boarder): the radio line
	end
	table.insert(op.offeredTo, player)
	st.offerOpId = op.id
	local tut = if st.completed < #Grading.Payout.Tutorial then st.completed else nil
	fire("Ops_Offered", player, offerPayload(op, tut))
	return op
end

local function withdrawOffer(op: any)
	local t = now()
	for _, p in op.offeredTo do
		fire("Ops_Closed", p, { opId = op.id, reason = "Withdrawn", silent = true })
		local st = playerState[p]
		if st and st.offerOpId == op.id then
			st.offerOpId = nil
			st.nextOfferAt = t + OfferPacing.afterDecline(weatherState(), offerRushed())
		end
	end
	if not op.isBig then
		ops[op.id] = nil -- a big call is server-wide: one player's card never drops it
	end
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
	rollCasualties(op, op.scene.total)
	for i, c in op.casualties do
		if onboardingCall(player) and op.def.states.Alert then
			c = Condition.new(`{op.id}-{i}`, "Alert", true)
			op.casualties[i] = c
		end
		if op.kind == "SinkingVessel" or op.kind == "VesselFire" then
			c.driftScale = OperationService.FAST_TIRING
		end
	end
	RescueService.SpawnCall(op.scene)
	if op.scene.kind == "RipCurrent" then
		pcall(RipFlow.Spawn, op.scene) -- the rip is the current; tag the body-boarder's board
	elseif op.scene.kind == "Sinking" then
		pcall(SinkingScene.Spawn, op.scene)
	elseif op.scene.kind == "VesselFire" then
		pcall(FireScene.Spawn, op.scene)
	end
	newTrack(op, player, members)
	radio(op, "Gale Isles Coastguard", op.radioLine or op.def.radioLine)
	advance(op, op.tracks[1])
	-- K15 (docs/16): from the player's 4th call an NPC RIB races them to the first casualty; there
	-- first, it takes them and the call ends unpaid (a takeover). Never on the first three calls.
	local vehicles = service("VehicleService")
	local total = player:GetAttribute("OpsCompletedTotal") -- nil until a call counts: no race
	if
		vehicles
		and not op.isBig
		and type(total) == "number"
		and not Onboarding.failsafeCall(total)
	then
		task.spawn(NpcPickup.run, vehicles, function()
			return RescueService.VictimPosition(op.scene, 1)
		end, function()
			return (RescueService.ReleaseVictim(op.scene, 1))
		end, function()
			if op.raceDone then
				op.raceDone()
			end
		end, {
			delay = NpcPickup.RACE_DELAY,
			claim = function(): boolean
				local c = op.casualties[1]
				if op.state ~= "Active" or op.takeover or not c or c.aboard or c.delivered then
					return false
				end
				startTakeover(op, "Race", 1)
				return true
			end,
		})
	end
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

-- past the cold open and the tutorial chain: the big call's pager reaches this player
local function bigCallReady(player: Player): boolean
	local total = player:GetAttribute("OpsCompletedTotal")
	return OfferPacing.bigCallReady(if type(total) == "number" then total else nil)
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
	op.storm = weatherState() == "Storm" -- the scheduled ferry comes in calm weather: no storm pay
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
	pcall(SkyFlare.distress, op.position) -- the world cue: a red flare and the ferry's horn out at sea
	-- the server-wide pager, never to a player still in the tutorial chain
	for _, p in Players:GetPlayers() do
		if bigCallReady(p) then
			Remotes.event("Ops_Offered"):FireClient(p, offerPayload(op))
		end
	end
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

-- Cold open, the way in (docs/14 section 3): while the casualty holds on, the recovery step waits
-- for land (no timeout); at a shore point (BoatColdOpen.landed) the shore party takes them over and
-- the step completes with the client's kept result. No headway for 10 s: Aggie calls them in.
local coldOpenNudge: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local function coldOpenShore(op: any)
	if not op.coldOpen then
		return
	end
	for _, track in op.tracks do
		local inst: any = track.current
		local player = track.owner
		local ci = inst and inst.casualtyIndex or 1
		local v = op.scene.victims and op.scene.victims[ci]
		local mode = v and v.state == "Water" and v.model and v.model:GetAttribute("PiwMode")
		if
			not (inst and player and inst.def.id == "recovery" and not inst.npc and mode == "held")
		then
			continue
		end
		local cas = v.floater.cf.Position
		inst.timeoutAt = math.max(inst.timeoutAt, now() + 30)
		if BoatColdOpen.landed(mode, cas) then
			local shore = BoatColdOpen.nearestShore(cas)
			pcall(RescueService.RemoveVictim, op.scene, ci)
			try("NpcService", "ShoreHandover", shore.dry, shore.water)
			onStepResult(player, op.id, inst.key, { metrics = {} })
			continue
		end
		local n = coldOpenNudge[inst]
		if not n then
			n = BoatColdOpen.newNudge(now())
			coldOpenNudge[inst] = n
		end
		local _, d = BoatColdOpen.nearestShore(cas)
		if BoatColdOpen.nudge(n, now(), d) then
			radio(op, BoatColdOpen.SHORE_RADIO.from, BoatColdOpen.SHORE_RADIO.text)
		end
	end
end

-- Server-side auto_board for every op: AmbientRescueService.StepBoarding, the free-roam rule (close, slow,
-- level, room aboard). A crew's boat boards any survivor its track may take while picking up or carrying
-- (a RIB or lifeboat fits several, all landed together). The client auto_board mechanic stays as the
-- visuals and a second path; whichever comes first wins.
local function boardingStep(track: Track): StepInst?
	local inst = track.current
	if not inst or inst.npc then
		return nil
	end
	if inst.def.effect == "board" and inst.mechanicId == "auto_board" then
		return inst
	end
	return if inst.def.effect == "deliver" then inst else nil
end

local function stepBoarding(op: any, dt: number)
	local ambient = service("AmbientRescueService")
	if op.coldOpen or not op.scene or not ambient then
		return
	end
	local function may(player: Player, i: number): boolean
		local track = trackOf(op, player)
		local inst = track and boardingStep(track)
		return track ~= nil
			and inst ~= nil
			and op.casualties[i] ~= nil
			and Board.mayTake(op.casualties[i], track.id)
	end
	ambient.StepBoarding(
		op.scene,
		dt,
		ambient.SeatedBoats(),
		may,
		function(i: number, player: Player)
			local track = trackOf(op, player)
			local inst = track and boardingStep(track)
			if not (track and inst) or op.state ~= "Active" then
				return
			end
			local c: CasualtyState = op.casualties[i]
			local old = inst.casualtyIndex
			if inst.def.effect == "board" and old ~= i then
				-- they reached another survivor than the one claimed: that one is free again
				if old then
					op.casualties[old].claimedBy = nil
				end
				inst.casualtyIndex = i
				track.casualtyIndex = i
			end
			c.claimedBy = track.id
			if inst.def.effect == "board" then
				local metrics: Types.Metrics = { elapsed = now() - inst.startedAt }
				local grade: Grade =
					Grading.stepGrade(inst.def, metrics, inst.def.serverMetrics) :: any
				padDone[track] = { key = inst.key, grade = grade }
				if inst.assignee then
					fire(
						"Ops_StepAck",
						inst.assignee,
						{ opId = op.id, stepKey = inst.key, accepted = true, grade = grade }
					)
				end
				complete(op, track, inst, grade, player) -- the board effect plays the climb
			else
				-- one more while carrying: aboard now, landed with the rest
				c.inWater = false
				c.aboard = true
				c.panicking = false
				pcall(RescueService.BoardVictim, op.scene, i, player)
				broadcast(op)
			end
		end
	)
end

local function tickOp(op: any, dt: number, t: number)
	if op.state ~= "Active" then
		return
	end
	sampleColdOpen(op)
	coldOpenShore(op)
	local env = {
		storm = not op.coldOpen and (op.storm or weatherState() == "Storm"),
		coldWater = false,
	}
	for _, c in op.casualties do
		Condition.step(c, dt, env)
	end
	-- first session: no fail state on the cold open and the next three calls (docs/15 section 3)
	Onboarding.protect(
		op.casualties,
		if op.owner and playerState[op.owner] then playerState[op.owner].completed else 0
	)
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
		-- the cold open and the first three station calls cannot fail (docs/15 section 3, 2026-10-21):
		-- no cap, no Critical takeover, the survivor waits. Picked-up casualties are safe.
		local yes, why = false, nil
		if Operations.canFail(op.coldOpen == true, onboardingCall(op.owner)) then
			yes, why = Condition.shouldTakeover(
				Operations.atRisk(op.casualties),
				elapsed,
				op.def.capSeconds
			)
		end
		if yes then
			startTakeover(op, why or "Critical")
		end
	end
	stepBoarding(op, dt)
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
	-- the Capsized Ferry's own clock (OfferPacing.nextBigCallAt), held while a cold open runs
	local anyReady = false
	for _, p in Players:GetPlayers() do
		anyReady = anyReady or bigCallReady(p)
	end
	bigReadySince = if anyReady then bigReadySince or t else nil
	local due = OfferPacing.nextBigCallAt(bigLastEnd, bigReadySince)
	if due and t >= due and not bigOp and not OperationService.ColdOpenHoldsWeather() then
		startBigOp()
	end
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
				-- survivors visibly tire: CasualtyController sinks them and slows the wave
				for i, c in op.casualties do
					pcall(RescueService.SetStamina, op.scene, i, c.condition / 100)
				end
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local st = stateOf(player)
		if st.activeOpId or not lastActiveAt[player] then
			lastActiveAt[player] = t -- first sight: the two idle minutes count from here
		end
		if st.offerOpId and not ops[st.offerOpId] then
			-- the server-wide call ended before this player joined it: free the pager
			st.offerOpId = nil
			st.nextOfferAt = t + OfferPacing.afterDecline(weatherState(), offerRushed())
		end
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
			elseif decision == "Offer" and not inWater(player) then
				-- two idle minutes on the quay: the board nudges an easy call, not a random one
				local onFoot, stationDistance = stationIdle(player)
				local nudge = st.completed >= #Grading.Payout.Tutorial
					and OfferPacing.nudgesIdle(t - lastActiveAt[player], onFoot, stationDistance)
				offerTo(player, if nudge then "EasyCall" else nil)
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

-- True while someone's cold open runs (at most Onboarding.WEATHER_HOLD s each): StormService
-- holds a new storm until it ends, so the first rescue stays in calm daylight.
function OperationService.ColdOpenHoldsWeather(): boolean
	local t = now()
	for player, e in coldOpenFlow do
		if
			ColdOpenFlow.isRunning(e)
			and t - (coldOpenBegunAt[player] or -math.huge) < Onboarding.WEATHER_HOLD
		then
			return true
		end
	end
	return false
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
-- in Calm Bay (ColdOpen.SPAWN) with a Person in the Water operation already tasked (the radio ack is
-- auto-done) and rescues the casualty within about 90 s; the station and onboarding come after.
-- Plan (shared/Boat/ColdOpen.PLAN): tasking (auto, Gold) -> recovery -> transport; Assist on; condition drift x0.5.
OperationService.ColdOpenPlan = BoatColdOpen.PLAN
OperationService.ColdOpenDriftScale = 0.5
-- studs ahead of the spawn CFrame (shared/Boat/ColdOpen.DISTANCE): on screen at spawn.
OperationService.ColdOpenDistance = BoatColdOpen.DISTANCE

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
	player:SetAttribute("ColdOpenActive", true) -- client weather stays calm for this player
	if st.offerOpId and ops[st.offerOpId] then
		withdrawOffer(ops[st.offerOpId])
	end
	local at, home = BoatColdOpen.SPAWN, BoatColdOpen.SHORE[1].water
	-- facing the slipway: the casualty is on the way home, so straight ahead always closes the drop-off
	local cf = spawnCFrame or CFrame.lookAt(at, Vector3.new(home.X, at.Y, home.Z))
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
	local op = newOp("PersonInWater", "Swimmer", "CalmBay", pos)
	-- the first rescue is always the plain swimmer: the rare variants arrive with the call chain
	op.variant = "Swimmer"
	op.scene.variant = "Swimmer"
	op.coldOpen = true
	op.storm = false -- a storm already running when the cold open starts is not this op's weather
	flow.opId = op.id
	try("TelemetryService", "ColdOpenStarted", player) -- RP-A1 onboarding funnel
	-- the plan jumps straight to recovery; the approach is the auto-throttle run in
	try("TelemetryService", "ColdOpenStep", player, "approach")
	op.planIds = OperationService.ColdOpenPlan
	op.offeredTo = { player }
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
	-- the radio ack is auto-done: record it as the player's (Gold) and go straight to the next step
	radio(op, "Gale Isles Coastguard", BoatColdOpen.RADIO)
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

-- Offer a call to `player` without accepting it: the radio card appears and the player accepts as
-- usual. opts.variant forces one RescueVariants id (Studio).
function OperationService.OfferCall(player: Player, kind: string?, opts: any?): string?
	local st = stateOf(player)
	if st.activeOpId and ops[st.activeOpId] then
		return nil
	end
	local pending = st.offerOpId and ops[st.offerOpId]
	if pending and pending.isBig then
		return nil -- the server-wide call is the more special one
	end
	if now() < st.nextOfferAt then
		return nil -- the breather after the last op
	end
	if pending then
		withdrawOffer(pending)
	end
	local op = offerTo(player, kind or "PersonInWater", opts)
	return op.id
end

-- Offers the running big call to one free player (late joiners, docs/15 H7). It never interrupts an op or the after-op breather, and replaces a pending
-- personal offer: the more special call wins (G69).
function OperationService.OfferBigCall(player: Player): boolean
	if not bigOp or bigOp.state ~= "Active" or not bigCallReady(player) then
		return false
	end
	local st = stateOf(player)
	if st.activeOpId and ops[st.activeOpId] then
		return false
	end
	if now() < st.nextOfferAt then
		return false
	end
	if st.offerOpId and ops[st.offerOpId] then
		if st.offerOpId == bigOp.id then
			Remotes.event("Ops_Offered"):FireClient(player, offerPayload(bigOp))
			return true
		end
		withdrawOffer(ops[st.offerOpId]) -- the more special call wins
	end
	if not table.find(bigOp.offeredTo, player) then
		table.insert(bigOp.offeredTo, player)
	end
	st.offerOpId = bigOp.id
	Remotes.event("Ops_Offered"):FireClient(player, offerPayload(bigOp))
	return true
end

-- Dev helper (Studio).
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

-- Dev board (DevService): end the player's current op, graded ("Complete") or dropped unpaid.
function OperationService.DevEnd(player: Player, graded: boolean): boolean
	local st = stateOf(player)
	local op = st.activeOpId and ops[st.activeOpId]
	if not op then
		return false
	end
	if graded then
		finish(op, "Complete")
	else
		closeOp(op)
	end
	return true
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
				OperationService.OfferBigCall(player)
			end
		end)
	end
	if RunService:IsStudio() then
		player.Chatted:Connect(function(msg)
			if msg == "/ferry" then
				startBigOp()
			elseif msg == "/op" then
				OperationService.DevStart(player, "PersonInWater")
			end
		end)
	end
end

local function onPlayerRemoving(player: Player)
	playerState[player] = nil
	coldOpenFlow[player] = nil
	stationOnSpawn[player] = nil
	coldOpenBegunAt[player] = nil
	lastActiveAt[player] = nil
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
			elseif cmd == "takeover" then
				-- force the fail path on the running call (Studio test of the NPC pickup)
				for _, op in ops do
					if op.state == "Active" and not op.isBig then
						startTakeover(op, "Dev")
						return op.id
					end
				end
				return nil
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
					lastKind = p and p:GetAttribute("OpsLastKind"),
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
	bigLastEnd = now()
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
