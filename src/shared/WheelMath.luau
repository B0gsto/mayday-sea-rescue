--!strict
-- WheelMath: the pure geometry of the in-world prize wheel (docs/24 D). No Roblox services; safe
-- in Lune (tests/WheelMath.spec.luau).
--
-- Segment `i` (1-based, SpinRules.SEGMENTS order) sits at `segmentAngle(i, count)` degrees, measured
-- counter-clockwise from +X in the wheel's own plane. The pointer is fixed at the top (+Y, 90°).
-- A wheel rotation of `spinAngle` degrees brings that segment under the pointer; `angleAt` is the
-- eased rotation over the spin, with a small overshoot that settles back.

local WheelMath = {}

WheelMath.POINTER = 90

function WheelMath.normalize(degrees: number): number
	return ((degrees % 360) + 360) % 360
end

function WheelMath.segmentAngle(segment: number, count: number): number
	assert(count > 0, "a wheel needs a segment")
	return WheelMath.normalize((math.floor(segment) - 1) * 360 / count)
end

-- Positive rotation (whole turns included) that lands `segment` under the pointer.
function WheelMath.spinAngle(segment: number, count: number, turns: number?): number
	local offset = WheelMath.normalize(WheelMath.POINTER - WheelMath.segmentAngle(segment, count))
	return math.max(0, math.floor(turns or 0)) * 360 + offset
end

-- Rotation at normalised time t [0, 1]: cubic ease-out, then a damped overshoot past the target.
function WheelMath.angleAt(t: number, target: number, overshoot: number?): number
	local u = math.clamp(t, 0, 1)
	local main = 0.8
	if u <= main then
		local k = u / main
		return target * (1 - (1 - k) ^ 3)
	end
	local settle = (u - main) / (1 - main)
	return target + (overshoot or 0) * math.sin(math.pi * settle)
end

-- Which segment (1-based) sits under the pointer at `rotation` degrees (the settle check).
function WheelMath.segmentUnder(rotation: number, count: number): number
	local step = 360 / count
	local raw = math.floor(WheelMath.normalize(WheelMath.POINTER - rotation) / step + 0.5) % count
	return raw + 1
end

-- Peg crossings during a spin: the flapper ticks once per segment boundary passed.
function WheelMath.ticksFor(rotation: number, count: number): number
	return math.floor(rotation / (360 / count))
end

return WheelMath
