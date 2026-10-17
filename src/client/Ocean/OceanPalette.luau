--!strict
-- OceanPalette: height -> colour for the client ocean (docs/05-art-direction.md palette).
-- Abyss Navy troughs, Deep Teal mid-water, Foam crests. Colours are precomputed into buckets so
-- the per-frame path only does an integer compare and reuses existing Color3 values (no allocs).

local OceanPalette = {}

OceanPalette.DEEP_TEAL = Color3.fromHex("#2F4440") -- grey-green, not cyan (round 3)
OceanPalette.ABYSS_NAVY = Color3.fromHex("#18252A")
OceanPalette.FOAM = Color3.fromHex("#EAF7F5")

-- Height (studs above sea level) that maps to full Foam / full Navy. Storm crests (sum of
-- amplitudes about 3.4) reach it; calm swell (about 1.25) stays mostly teal. -- tune
OceanPalette.REFERENCE_AMPLITUDE = 3.0
-- Buckets on each side of sea level; total buckets = 2 * HALF + 1. -- tune
OceanPalette.HALF = 16
OceanPalette.COUNT = 2 * OceanPalette.HALF + 1

local function smoothstep(e0: number, e1: number, x: number): number
	local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)
end

-- Normalised height s in -1..1 -> colour.
local function colourFor(s: number): Color3
	if s <= 0 then
		-- Troughs darken quickly so swells read at a glance (art direction rule 1).
		return OceanPalette.DEEP_TEAL:Lerp(OceanPalette.ABYSS_NAVY, math.clamp(-s / 0.6, 0, 1))
	end
	return OceanPalette.DEEP_TEAL:Lerp(OceanPalette.FOAM, smoothstep(0.3, 0.95, s) * 0.9)
end

-- Bucket index 1..COUNT -> Color3, built once.
OceanPalette.colours = table.create(OceanPalette.COUNT) :: { Color3 }
for i = 1, OceanPalette.COUNT do
	OceanPalette.colours[i] = colourFor((i - 1 - OceanPalette.HALF) / OceanPalette.HALF)
end
table.freeze(OceanPalette.colours)

-- Height above sea level (studs) -> bucket index 1..COUNT. Allocation-free.
function OceanPalette.bucketFor(heightAboveSea: number): number
	local s = math.clamp(heightAboveSea / OceanPalette.REFERENCE_AMPLITUDE, -1, 1)
	return math.floor(s * OceanPalette.HALF + 0.5) + OceanPalette.HALF + 1
end

-- Bucket of the flat sea (used by the far plane and faded outer ring).
OceanPalette.SEA_BUCKET = OceanPalette.HALF + 1

return OceanPalette
