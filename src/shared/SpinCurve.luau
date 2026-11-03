--!strict
-- SpinCurve: the Deep Spin's timing, copied verbatim from the owner-approved reference
-- (docs/prototypes/spin-wheel.html: SPIN_KEYS, CLAW_KEYS, T_*, reveal tables). Pure; tests/SpinCurve.spec.luau.
-- Angles follow WheelMath: a positive rotor rotation carries segment i toward the pointer, and reads clockwise
-- from the wheel's front. The speed curve is scaled by under a few percent so it lands inside the server's wedge.
local WheelMath = require(script.Parent:WaitForChild("WheelMath"))

local SpinCurve = {}

SpinCurve.COUNT = 12

type Keys = { { number } }

SpinCurve.SPIN_KEYS = {
	{ 0, 0 },
	{ 0.3, -210 },
	{ 0.6, -60 },
	{ 0.74, -6 },
	{ 0.75, 0 },
	{ 0.81, 0 }, -- wind-up + a held breath
	{ 0.87, 1500 },
	{ 1.5, 2600 },
	{ 3.40, 3200 }, -- spin hard
	{ 3.49, 1150 },
	{ 4.10, 1500 }, -- slam 1, wheel rips loose
	{ 4.19, 540 },
	{ 4.75, 760 }, -- slam 2, fights again
	{ 4.83, 210 },
	{ 5.6, 75 },
	{ 6.25, 22 },
	{ 6.7, 0 },
	{ 6.78, -38 },
	{ 6.92, 0 }, -- slam 3, crawl, rock back
} :: Keys

SpinCurve.T_BREAK = 0.55
SpinCurve.T_DIVE = 1.5
SpinCurve.T_PLUNGE = 1.9
SpinCurve.FALL_H = 2.4 -- the fall, in screen heights
SpinCurve.GROUND_Y = 0.84 -- from the top of the frame, in screen heights
SpinCurve.SOIL_H = 1
SpinCurve.T_RELEASE = 0.81
SpinCurve.T_SLAM = { 3.41, 4.11, 4.76 }
SpinCurve.T_END = 6.92
SpinCurve.T_STOP = 0.28 -- dead silence with the winning wedge up
SpinCurve.T_SURFACE = 1.1
SpinCurve.STEP = 30
SpinCurve.MAX_SPEED = 3200

SpinCurve.CLAW_KEYS = {
	{ 0, 0 },
	{ 3.31, 0 },
	{ 3.41, 1.1 },
	{ 3.47, 0.98 },
	{ 3.9, 0.96 },
	{ 4.03, 0.55 },
	{ 4.10, 0.6 },
	{ 4.11, 1.12 },
	{ 4.17, 0.98 },
	{ 4.62, 0.95 },
	{ 4.72, 0.6 },
	{ 4.76, 1.14 },
	{ 4.82, 1 },
	{ 7, 1 },
} :: Keys

-- the wheel's speed during the dive: grinds up on land, drills through
SpinCurve.DIVE_KEYS = {
	{ 0, 0 },
	{ 0.55, 900 },
	{ 0.70, 1500 },
	{ 1.5, 700 },
	{ 1.9, 0 },
} :: Keys

-- reveal scaling, by tier (Common 1 .. Mythic 6)
SpinCurve.TIERS = table.freeze({
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
})
SpinCurve.BUILD_DUR = { 0.5, 0.7, 0.85, 1.05, 1.3, 1.6 }
SpinCurve.HOLD = { 0.9, 1, 1.2, 1.6, 2, 2.6 }
SpinCurve.GLOW = { 0.1, 0.18, 0.3, 0.45, 0.6, 0.8 }
SpinCurve.BURST = { 0.45, 0.55, 0.7, 0.85, 1, 1 } -- the win burst's scale (the count table's share of its cap)

function SpinCurve.tier(rarity: string): number
	return (SpinCurve.TIERS :: any)[rarity] or 1
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

function SpinCurve.smooth(a: number, b: number, x: number): number
	local k = math.clamp((x - a) / (b - a), 0, 1)
	return k * k * (3 - 2 * k)
end

function SpinCurve.easeOutBack(k: number): number
	local c = 1.9
	return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2
end

function SpinCurve.table(keys: Keys, t: number): number
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 2, #keys do
		if t <= keys[i][1] then
			local a, b = keys[i - 1], keys[i]
			local span = b[1] - a[1]
			return lerp(a[2], b[2], (t - a[1]) / (if span > 0 then span else 1))
		end
	end
	return keys[#keys][2]
end

local DT = 1 / 240

export type Curve = { at: (t: number) -> number, scale: number, final: number }

-- A curve from `start` (degrees, any value) that ends on `segment` (1-based), `off` degrees from its centre
function SpinCurve.build(start: number, segment: number, off: number): Curve
	local n = math.ceil(SpinCurve.T_END / DT) + 1
	local raw = table.create(n, 0)
	local total = 0
	for i = 2, n do
		total += SpinCurve.table(SpinCurve.SPIN_KEYS, (i - 1) * DT) * DT
		raw[i] = total
	end
	local spot = WheelMath.spinAngle(segment, SpinCurve.COUNT, 0) + off
	local want = WheelMath.normalize(spot - start)
	local scale = (want + 360 * math.round((total - want) / 360)) / total
	local final = start + total * scale
	return {
		scale = scale,
		final = final,
		at = function(t: number): number
			if t >= SpinCurve.T_END then
				return final
			end
			local f = math.clamp(t / DT, 0, n - 1)
			local i = math.floor(f)
			return start + lerp(raw[i + 1], raw[math.min(i + 2, n)], f - i) * scale
		end,
	}
end

-- A random spot inside a wedge, clear of the dividers (the reference's rnd(-11, 11))
function SpinCurve.offset(unit: number): number
	return -11 + 22 * unit
end

-- The dive at time k (s): fall in screen heights, crack and broken 0..1, depth 0..1, zoom, the wheel's own bob
-- in screen heights
function SpinCurve.dive(k: number)
	local x = math.clamp((k - SpinCurve.T_BREAK) / (SpinCurve.T_DIVE - SpinCurve.T_BREAK), 0, 1)
	local crack = SpinCurve.smooth(0.08, SpinCurve.T_BREAK, k)
	return {
		fall = SpinCurve.FALL_H * x ^ 1.6,
		crack = crack,
		broken = SpinCurve.smooth(SpinCurve.T_BREAK - 0.03, SpinCurve.T_BREAK + 0.16, k),
		depth = SpinCurve.smooth(1.1, 1.85, k),
		zoom = lerp(0.78, 1, SpinCurve.smooth(0.95, 1.7, k)),
		bob = (math.sin(k * 41) * 0.9 * crack * (1 - x) + 13 * math.sin(math.pi * x)) / 100,
		speed = SpinCurve.table(SpinCurve.DIVE_KEYS, k),
	}
end

return SpinCurve
