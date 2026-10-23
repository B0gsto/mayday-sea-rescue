--!strict
-- BosunGuide (docs/16 K14): Bosun is the guide. With his player on a craft and idle (barely moving)
-- for IDLE seconds he points and barks at the nearest survivor, then again every REPEAT seconds while
-- they stay idle. Pure (tests/BosunGuide.spec.luau); DogService runs it.
local BosunGuide = {}

BosunGuide.IDLE = 8 -- s
BosunGuide.REPEAT = 12 -- s between points while still idle -- tune
BosunGuide.SLOW = 5 -- studs/s: slower than this counts as idle -- tune

export type State = { idle: number }

function BosunGuide.new(): State
	return { idle = 0 }
end

-- Advances the idle timer by dt; true when he should point now.
function BosunGuide.step(s: State, dt: number, onCraft: boolean, speed: number): boolean
	if not onCraft or speed >= BosunGuide.SLOW then
		s.idle = 0
		return false
	end
	s.idle += dt
	if s.idle >= BosunGuide.IDLE then
		s.idle = BosunGuide.IDLE - BosunGuide.REPEAT
		return true
	end
	return false
end

-- The nearest position (flat distance) to `from`, nil when there are none.
function BosunGuide.nearest(from: Vector3, positions: { Vector3 }): Vector3?
	local best, bestDist = nil, math.huge
	for _, p in positions do
		local d = Vector3.new(p.X - from.X, 0, p.Z - from.Z).Magnitude
		if d < bestDist then
			best, bestDist = p, d
		end
	end
	return best
end

return BosunGuide
