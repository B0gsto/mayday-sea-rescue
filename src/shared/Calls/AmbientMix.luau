--!strict
-- AmbientMix (sea1, owner 2026-10-29: "not too many survivors on water ... it looks too empty"): how many
-- free-roam survivors AmbientRescueService keeps in the water and what each spawn is. Pure data, Lune-safe
-- (tests/AmbientMix.spec.luau). Pay is not here: every free-roam survivor pays AmbientRescueService.CASH.
local AmbientMix = {}

AmbientMix.BASE = 6 -- scenes server-wide with one player -- tune
AmbientMix.PER_PLAYER = 3 -- more per player in the server -- tune
AmbientMix.MAX = 24 -- six players -- tune
AmbientMix.IN_SIGHT = 3 -- scenes kept within SIGHT of every player out at sea -- tune
AmbientMix.SIGHT = 500 -- studs: in view from a boat at the game camera -- tune
AmbientMix.SIGHT_MIN = 220 -- studs: sight spawns appear this far out (never beside you) -- tune
AmbientMix.HOME_CLEAR = 320 -- studs from every berth: the coves stay the missions' (Near / CalmBay) -- tune
AmbientMix.FAR = 0.3 -- share of timed spawns off an outer island (the rest in the Outer ring) -- tune

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

return AmbientMix
