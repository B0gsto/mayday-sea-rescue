--!strict
-- Crowding (docs/20 WP-C addendum): how a busy server makes room. Pure, Lune-tested in
-- tests/Crowding.spec.luau.
--   Crowding.scale(players)    1 up to SOLO players, easing down to MIN at FULL or more. Idle-despawn
--                              timers, NPC traffic and moored-boat counts multiply by it.
--   Crowding.apart(d, gap)     soft collision between player craft (they ghost through each other's
--                              hulls): the speed (studs/s) a hull should at least have away from another
--                              whose centre is d studs off, once closer than gap. 0 when clear.
local Crowding = {}

Crowding.SOLO = 2 -- players -- tune
Crowding.FULL = 8 -- players -- tune
Crowding.MIN = 0.25 -- tune
Crowding.PUSH = 8 -- studs/s apart at full overlap -- tune

function Crowding.scale(players: number): number
	local t = math.clamp((players - Crowding.SOLO) / (Crowding.FULL - Crowding.SOLO), 0, 1)
	return 1 - (1 - Crowding.MIN) * t
end

function Crowding.apart(distance: number, gap: number): number
	if gap <= 0 or distance >= gap then
		return 0
	end
	return Crowding.PUSH * (1 - math.max(distance, 0) / gap)
end

return Crowding
