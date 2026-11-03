--!strict
-- AmbientMix (sea1, owner 2026-10-29: "not too many survivors on water ... it looks too empty"): how many
-- free-roam survivors AmbientRescueService keeps in the water and what each spawn is. Pure data, Lune-safe
-- (tests/AmbientMix.spec.luau). CASH is here so tests/Pacing.spec.luau prices free-roam with the live number.
local CallLogic = require(script.Parent.CallLogic)
local CallTypes = require(script.Parent.CallTypes)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local RingLayout = require(script.Parent.Parent.Config.RingLayout)
local SeaZones = require(script.Parent.SeaZones)

local AmbientMix = {}

AmbientMix.BASE = 6 -- scenes server-wide with one player -- tune
AmbientMix.PER_PLAYER = 3 -- more per player in the server -- tune
AmbientMix.MAX = 24 -- six players -- tune
AmbientMix.IN_SIGHT = 3 -- scenes kept within SIGHT of every player out at sea -- tune
AmbientMix.SIGHT = 500 -- studs: in view from a boat at the game camera -- tune
AmbientMix.SIGHT_MIN = 220 -- studs: sight spawns appear this far out (never beside you) -- tune
AmbientMix.HOME_CLEAR = 320 -- studs from every berth: the coves stay the missions' (Near / CalmBay) -- tune
AmbientMix.CASH = 120 -- per survivor delivered home (a Silver call pays 550); sight spawns pay x Bronze -- tune
AmbientMix.FAR = 0.3 -- share of timed spawns off an outer island (the rest by ZONE_SHARE) -- tune
AmbientMix.ZONE_SHARE = { 0.3, 0.25, 0.2, 0.15, 0.1 } -- timed spawns per sea zone: every zone has some -- tune

export type Spawn = { kind: "Swimmer" | "DriftingCraft", total: number }

-- Scenes in the water server-wide for this many players.
function AmbientMix.cap(players: number): number
	return math.clamp(
		AmbientMix.BASE + AmbientMix.PER_PLAYER * players,
		AmbientMix.BASE,
		AmbientMix.MAX
	)
end

-- What one spawn is, from a roll in [0, 1): mostly a lone swimmer, some small clusters, the odd capsized dinghy.
function AmbientMix.pick(roll: number): Spawn
	if roll < 0.6 then
		return { kind = "Swimmer", total = 1 }
	elseif roll < 0.75 then
		return { kind = "Swimmer", total = 2 }
	elseif roll < 0.85 then
		return { kind = "Swimmer", total = 3 }
	end
	return { kind = "DriftingCraft", total = 2 }
end

-- A timed spawn point from `rng`: a sea zone by ZONE_SHARE, uniform by area inside it, in open water or nil.
function AmbientMix.zonePoint(rng: () -> number): Vector3?
	local roll, index = rng(), #SeaZones.Zones
	for i, share in AmbientMix.ZONE_SHARE do
		roll -= share
		if roll < 0 then
			index = i
			break
		end
	end
	local A = CallTypes.Areas
	local inner = if index > 1 then SeaZones.Zones[index - 1].outer else A.OuterMin
	local outer = math.min(SeaZones.Zones[index].outer, GameConfig.MapRadius - A.MapMargin)
	local p = CallLogic.ringPoint(RingLayout.Center, inner, outer, rng)
	return if CallLogic.isWater(p, "Outer") then p else nil
end

-- What one free-roam survivor pays at `pos` (extra: a sight spawn, sea1's added density, at the Bronze share).
function AmbientMix.payAt(pos: Vector3, extra: boolean?): number
	local _, zone = SeaZones.zoneAt(pos)
	return math.floor(
		AmbientMix.CASH * zone.pay * (if extra then CallTypes.Payout.Grade.Bronze else 1)
	)
end

return AmbientMix
