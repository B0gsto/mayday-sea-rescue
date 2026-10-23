--!strict
-- DevConfig: who may open the dev board (DevService / DevController) and what each dev action
-- accepts. Pure (Lune-tested in tests/DevBoard.spec.luau). The server checks every Dev_Action
-- against isAllowed and validate; the client only uses the lists to draw the panel.
local Config = script.Parent
local Exercises = require(Config.Parent.Ops.Definitions.Exercises)
local GameConfig = require(Config.GameConfig)
local LandVehicleConfig = require(Config.LandVehicleConfig)
local Lighthouses = require(Config.Parent.Lighthouses)
local LiveOps = require(Config.Parent.LiveOps)
local MapConfig = require(Config.MapConfig)
local MonetizationConfig = require(Config.MonetizationConfig)
local Operations = require(Config.Parent.Ops.Operations)
local ProgressionConfig = require(Config.ProgressionConfig)
local VehicleConfig = require(Config.VehicleConfig)
local Wildlife = require(Config.Wildlife)
local WorldConfig = require(Config.WorldConfig)

local DevConfig = {}

-- Access: Studio always, these user ids, or this rank and up in the studio group.
DevConfig.UserIds = table.freeze({ [11718681576] = true } :: { [number]: boolean })
DevConfig.GroupId = 548313786 -- Brightwake Games
DevConfig.MinGroupRank = 254

DevConfig.RateWindow = 2 -- seconds
DevConfig.RateMax = 10 -- actions per window per dev

function DevConfig.isAllowed(userId: any, groupRank: any, isStudio: boolean): boolean
	if isStudio then
		return true
	end
	if type(userId) == "number" and DevConfig.UserIds[userId] then
		return true
	end
	return type(groupRank) == "number" and groupRank >= DevConfig.MinGroupRank
end

---------------------------------------------------------------- lists (validated ids)

export type Spot = { id: string, label: string, position: Vector3 }

local spots: { Spot } = {}
for _, blip in MapConfig.Blips do
	table.insert(spots, { id = blip.id, label = blip.label, position = blip.position :: Vector3 })
end
for _, zone in GameConfig.Zones do
	table.insert(spots, { id = zone.id, label = zone.displayName, position = zone.center })
end
for _, light in Lighthouses.List do
	table.insert(spots, { id = light.id, label = light.displayName, position = light.position })
end
for _, poi in WorldConfig.POIs do
	table.insert(spots, { id = poi.id, label = poi.name, position = poi.position })
end
for _, point in WorldConfig.Points do
	table.insert(spots, { id = point.id, label = point.id, position = point.position })
end
for _, place in MapConfig.Places do
	if place.kind == "town" then
		table.insert(spots, {
			id = place.text,
			label = place.text,
			position = Vector3.new(place.x, 0, place.z),
		})
	end
end
local spotById: { [string]: Spot } = {}
local spotIds: { string } = {}
for _, spot in spots do
	if not spotById[spot.id] then -- the first source of an id wins (a Blip over a Point)
		spotById[spot.id] = spot
		table.insert(spotIds, spot.id)
	end
end
DevConfig.Spots = spotById
DevConfig.SpotOrder = table.freeze(spotIds)

local function keys(t: { [string]: any }): { string }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

local function concat(...: { string }): { string }
	local out = {}
	for _, list in { ... } do
		for _, v in list do
			table.insert(out, v)
		end
	end
	return out
end

DevConfig.Vehicles = table.freeze(concat(VehicleConfig.Order, LandVehicleConfig.Order))
DevConfig.Ops = table.freeze(concat(keys(Operations.Defs), Exercises.Order, { "ColdOpen" }))
DevConfig.Events = LiveOps.Order
DevConfig.Species = table.freeze(table.clone(Wildlife.SpeciesOrder))
DevConfig.Certs = table.freeze(concat(ProgressionConfig.CertOrder, { "All" }))
DevConfig.Passes = table.freeze(concat(keys(MonetizationConfig.GamePasses), { "All" }))
DevConfig.Lights = table.freeze(concat(keys(Lighthouses.ById), { "All" }))
DevConfig.RankCount = #ProgressionConfig.Ranks
DevConfig.MaxAmount = 10_000_000

---------------------------------------------------------------- actions

-- Arg kinds: player (a user id), bool, number {min, max}, enum {values}, position (a Vector3).
export type Arg = { kind: string, min: number?, max: number?, values: { string }? }

local function enum(values: { string }): Arg
	return { kind = "enum", values = values }
end
local function num(min: number, max: number): Arg
	return { kind = "number", min = min, max = max }
end
local PLAYER: Arg = { kind = "player" }
local BOOL: Arg = { kind = "bool" }
local POSITION: Arg = { kind = "position" }

DevConfig.Actions = table.freeze({
	god = { BOOL },
	invisible = { BOOL },
	tpSpot = { enum(DevConfig.SpotOrder) },
	tpPlayer = { PLAYER },
	bring = { PLAYER },
	tpPos = { POSITION },
	vehicle = { PLAYER, enum(DevConfig.Vehicles) },
	pet = { PLAYER, enum(DevConfig.Species) },
	bosun = { PLAYER },
	op = { PLAYER, enum(DevConfig.Ops) },
	opEnd = { PLAYER, BOOL }, -- true: complete (graded), false: cancel
	storm = { enum({ "Storm", "GreatStorm", "Calm" }) },
	clock = { num(7, 17) }, -- daylight only: the night look is buggy (2026-10-22)
	event = { enum(DevConfig.Events), BOOL },
	light = { PLAYER, enum(DevConfig.Lights), BOOL }, -- true: relit, false: dark again
	award = { PLAYER, num(0, DevConfig.MaxAmount), num(0, DevConfig.MaxAmount) },
	rank = { PLAYER, num(1, DevConfig.RankCount) },
	cert = { PLAYER, enum(DevConfig.Certs) },
	unlockAll = { PLAYER },
	pass = { PLAYER, enum(DevConfig.Passes) },
	reset = { PLAYER },
	kick = { PLAYER },
	stats = {},
} :: { [string]: { Arg } })

local MAX_COORD = 6000

local function check(arg: Arg, value: any): (boolean, any)
	if arg.kind == "player" then
		return type(value) == "number" and value > 0 and value % 1 == 0 and value < 2 ^ 53, value
	elseif arg.kind == "bool" then
		return type(value) == "boolean", value
	elseif arg.kind == "number" then
		local ok = type(value) == "number"
			and value == value
			and value >= (arg.min :: number)
			and value <= (arg.max :: number)
		return ok, value
	elseif arg.kind == "enum" then
		return type(value) == "string" and table.find(arg.values :: { string }, value) ~= nil, value
	elseif arg.kind == "position" then
		if typeof(value) ~= "Vector3" then
			return false, nil
		end
		local v = value :: Vector3
		for _, c in { v.X, v.Y, v.Z } do
			if c ~= c or math.abs(c) > MAX_COORD then
				return false, nil
			end
		end
		return true, v
	end
	return false, nil
end

-- ok and the clean argument list, or false and the reason (server log only, never shown).
function DevConfig.validate(action: any, args: any): (boolean, any)
	local spec = if type(action) == "string" then DevConfig.Actions[action] else nil
	if not spec then
		return false, "unknown action"
	end
	if type(args) ~= "table" then
		return false, "args not a table"
	end
	if #args ~= #spec then
		return false, "wrong arg count"
	end
	local clean = {}
	for i, arg in spec do
		local ok, value = check(arg, args[i])
		if not ok then
			return false, `bad arg {i} ({arg.kind})`
		end
		clean[i] = value
	end
	return true, clean
end

-- Sliding-window rate limit: true (and the stamp is kept) while under RateMax in RateWindow.
function DevConfig.rateOk(stamps: { number }, now: number): boolean
	while stamps[1] and now - stamps[1] > DevConfig.RateWindow do
		table.remove(stamps, 1)
	end
	if #stamps >= DevConfig.RateMax then
		return false
	end
	table.insert(stamps, now)
	return true
end

return DevConfig
