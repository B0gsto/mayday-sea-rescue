--!strict
-- Lighthouses: the harbour lights that open the world (docs/03-progression.md section 7, docs/10
-- section 1.2). Each light is dark until its mission relights it: reach it by boat, land the lamp
-- kit, then hold the crank until the optic turns. Relighting is a profile flag (`lighthouses`), so
-- the beam shows for that player on every server, and the zone beyond opens for calls.
--
-- Only lights whose ground exists on the current map are listed: the Harbor Light on the east
-- breakwater head (map/Build.luau, Street.swap) and Skerry Light on Skerry Isle (layout.py
-- SKERRY_ISLE). Gannet Rock, Tempest Point Light and Northlight are outside the current bake (LU-5).
--
-- Pure data and rules, safe to load in Lune (tests/Lighthouses.spec.luau).
local ProgressionConfig = require(script.Parent.Config.ProgressionConfig)
local Types = require(script.Parent.Ops.Types)

export type Light = {
	id: string,
	displayName: string,
	zone: string, -- the zone the light watches (docs/03 section 7)
	opens: string, -- the zone that becomes active for calls
	spawnZone: string, -- CallTypes.SpawnZones entry the mission scene sits in
	position: Vector3, -- tower base
	approach: Vector3, -- water where the mission boat waits
	crankOffset: Vector3, -- crank position from the tower base
	rankIndex: number,
	rankName: string,
	cert: string,
	certName: string,
	rep: number,
	radio: string, -- the "light relit" broadcast
	mission: Types.OperationDef,
}

local Lighthouses = {}

Lighthouses.FLAG = "lighthouses"
Lighthouses.DarkColour = Color3.fromRGB(200, 48, 40) -- unlit lamp seen at night

local function tasking(label: string, line: string): Types.StepDef
	return {
		id = "tasking",
		label = label,
		realTerm = "Tasking",
		role = "Navigator",
		mechanicId = "radio_ack",
		gradeBands = { { metric = "elapsed", gold = 15, silver = 25, bronze = 40 } },
		serverMetrics = { "elapsed" },
		weight = 0.5,
		timeoutSec = 45,
		onFail = "npc",
		npcSeconds = 8,
		tip = line,
	}
end

local function kit(label: string): Types.StepDef
	return {
		id = "kit_launch",
		label = label,
		realTerm = "Kit and launch",
		role = "Helm",
		mechanicId = "kit_launch",
		gradeBands = {
			{ metric = "kitFit", gold = 1, silver = 0.6, bronze = 0, higherIsBetter = true },
			{ metric = "elapsed", gold = 25, silver = 35, bronze = 60 },
		},
		serverMetrics = { "elapsed" },
		weight = 1,
		timeoutSec = 60,
		onFail = "npc",
		npcSeconds = 15,
		tip = "The lamp kit, the fuel can and the spare mantles go together.",
	}
end

local function passage(label: string, seconds: number): Types.StepDef
	return {
		id = "passage",
		label = label,
		realTerm = "Passage",
		role = "Helm",
		mechanicId = "passage",
		gradeBands = { { metric = "routeRatio", gold = 1.15, silver = 1.4, bronze = 1.8 } },
		weight = 0.5,
		timeoutSec = seconds,
		onFail = "continue",
		npcSeconds = 40,
		tip = "Quarter the waves and ease off on the crests.",
	}
end

local function crank(label: string): Types.StepDef
	return {
		id = "crank",
		label = label,
		realTerm = "Relight",
		role = "Crew",
		mechanicId = "lighthouse_crank",
		gradeBands = {
			{ metric = "cranks", gold = 1, silver = 1, bronze = 0, higherIsBetter = true },
		},
		weight = 2,
		timeoutSec = 120,
		onFail = "retry",
		npcAllowed = false,
		tip = "Hold the crank until the optic turns and the lamp catches.",
	}
end

local function mission(
	id: string,
	title: string,
	line: string,
	capSeconds: number,
	kitLabel: string,
	passageLabel: string,
	crankLabel: string
): Types.OperationDef
	return {
		id = id,
		displayName = title,
		radioLine = line,
		weight = 0, -- a story mission: no rescue pay, no tutorial count
		capSeconds = capSeconds,
		isBig = false,
		casualtyKind = "Vessel",
		states = { Vessel = 1 },
		lifejacketChance = 1,
		takeoverAsset = "Haven Patrol",
		sceneKinds = { "Tow" },
		steps = {
			tasking("Answer Tobias on the radio", "Answer the Coastguard promptly."),
			kit(kitLabel),
			passage(passageLabel, 300),
			crank(crankLabel),
		},
	}
end

local list: { Light } = {
	{
		id = "HarbourLight",
		displayName = "Harbor Light",
		zone = "Calm Bay",
		opens = "The Skerries",
		spawnZone = "Near",
		position = Vector3.new(44, 6, 360),
		approach = Vector3.new(44, 0, 392),
		crankOffset = Vector3.new(0, 6, -8),
		rankIndex = 2,
		rankName = "Lifeguard",
		cert = "Helm",
		certName = "Helm",
		rep = ProgressionConfig.Ranks[2].rep,
		radio = "Harbor Light is lit. Out.",
		mission = mission(
			"LighthouseHarbour",
			"Harbor Light",
			"Haven Rescue, Haven Station. Harbor Light is dark. Take Tobias and the lamp kit out to her.",
			360,
			"Load the lamp kit",
			"Take Tobias to the light",
			"Turn the lens"
		),
	},
	{
		id = "SkerryLight",
		displayName = "Skerry Light",
		zone = "The Skerries",
		opens = "Skerry wildlife and cliff calls",
		spawnZone = "Outer",
		position = Vector3.new(1520, 30, 1700),
		approach = Vector3.new(1420, 0, 1700),
		crankOffset = Vector3.new(-12, 4, 0),
		rankIndex = 3,
		rankName = "Rescue Swimmer",
		cert = "RescueSwimmer",
		certName = "Rescue Swimmer",
		rep = ProgressionConfig.Ranks[3].rep,
		radio = "Skerry Light is lit. Out.",
		mission = mission(
			"LighthouseSkerry",
			"Skerry Light",
			"Haven Rescue, Haven Station. Skerry Light is out. Tobias has the lens kit on the quay.",
			420,
			"Load the lens kit",
			"Run out to Skerry Isle",
			"Turn the lens"
		),
	},
}

Lighthouses.List = table.freeze(list)

local byId: { [string]: Light } = {}
local byMission: { [string]: Light } = {}
for _, light in Lighthouses.List do
	byId[light.id] = light
	byMission[light.mission.id] = light
end
Lighthouses.ById = table.freeze(byId)

-- The CallTypes spawn zone each relight opens (docs/03 section 7). Only Outer exists on the
-- current map: the Skerries spawn there. Skerry Light's wildlife/cliff work is listed on the light.
Lighthouses.OpenZones = table.freeze({ HarbourLight = "Outer" } :: { [string]: string })

function Lighthouses.get(id: string): Light?
	return byId[id]
end

function Lighthouses.missionLight(missionId: string): Light?
	return byMission[missionId]
end

-- The profile's `lighthouses` sub-table (never mutate it; use withLit). Accepts either the whole
-- profile flags table or the sub-table itself.
function Lighthouses.fromFlags(flags: any): { [string]: boolean }
	if type(flags) ~= "table" then
		return {}
	end
	local sub = flags[Lighthouses.FLAG]
	if type(sub) == "table" then
		return sub
	end
	-- also accept the sub-table itself, but never mistake the whole profile flags for one
	for id in flags do
		if byId[id] then
			return flags
		end
	end
	return {}
end

function Lighthouses.isLit(flags: any, id: string): boolean
	return Lighthouses.fromFlags(flags)[id] == true
end

-- A copy of the `lighthouses` sub-table with `id` relit. Pass fromFlags(profile.flags), then the
-- result to ProgressionService.SetFlag.
function Lighthouses.withLit(flags: any, id: string): { [string]: boolean }
	local out = table.clone(Lighthouses.fromFlags(flags))
	out[id] = true
	return out
end

-- The first light still dark, in world order (Harbor Light, then Skerry Light).
function Lighthouses.next(flags: any): Light?
	for _, light in Lighthouses.List do
		if not Lighthouses.isLit(flags, light.id) then
			return light
		end
	end
	return nil
end

-- Is a call spawn zone open for this player? Outer (the Skerries) waits for the Harbor Light.
function Lighthouses.zoneOpen(flags: any, zoneId: string): boolean
	for lightId, id in Lighthouses.OpenZones do
		if id == zoneId then
			return Lighthouses.isLit(flags, lightId)
		end
	end
	return true
end

-- Is a certification held in a profile, or in a ProgressionRules.snapshot (table with `earned`)?
local function held(value: any): boolean
	if type(value) == "table" then
		return value.earned == true
	end
	return value == true
end

-- ok, why (1-3 words) for starting `id` from the station board. `snap` is a
-- ProgressionService.GetData snapshot (rep, rankIndex, certs, flags).
function Lighthouses.canStart(snap: any, id: string): (boolean, string)
	local light = Lighthouses.get(id)
	if not light then
		return false, "Unknown light"
	end
	local flags = if type(snap) == "table" then snap.flags else nil
	if Lighthouses.isLit(flags, id) then
		return false, "Already lit"
	end
	if type(snap) ~= "table" then
		return false, "Still loading"
	end
	local rank = tonumber(snap.rankIndex) or 1
	if rank < light.rankIndex then
		return false, `Needs {light.rankName}`
	end
	if (tonumber(snap.rep) or 0) < light.rep then
		return false, `Needs {light.rep} Rep`
	end
	local certs = snap.certs
	if type(certs) ~= "table" or not held(certs[light.cert]) then
		return false, `Needs {light.certName}`
	end
	for _, other in Lighthouses.List do
		if other.id == id then
			break
		end
		if not Lighthouses.isLit(flags, other.id) then
			return false, `Light {other.displayName} first`
		end
	end
	return true, "ok"
end

return Lighthouses
