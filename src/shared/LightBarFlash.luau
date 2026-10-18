--!strict
-- LightBarFlash (RP-M5 stream B): pure LED light bar logic for the "LightBar" cosmetic
-- (Config/Cosmetics/LightBar). Which lamps a bar has, which are lit at time t, and which pattern runs.
-- No Roblox instances; tests/LightBars.spec.luau.
--
-- Lamps are numbered left to right across the bar; side 1 = left half, 2 = right half. A single-lamp
-- beacon flashes in the left half's timing. Patterns (real LED controller patterns, ECE R65 style
-- 2 to 4 flashes per second per side):
--   Alternate      UK double flash, halves swap 1.5 times a second (the no-siren default)
--   SlowAlternate  triple flash, halves swap about once a second ("Wail")
--   FastAlternate  single flash, halves swap 3.3 times a second ("Yelp")
--   WigWag         solid halves alternate, 0.7 s cycle ("HiLo", alternate halves)
--   QuadFlash      four short flashes per side ("Phaser")
--   Steady         all on
local LightBarFlash = {}

export type Lamp = { color: string, side: number, invert: boolean, steady: boolean }
type Spec = { period: number, flashes: number, on: number, gap: number }

LightBarFlash.Patterns =
	{ "Alternate", "SlowAlternate", "FastAlternate", "WigWag", "QuadFlash", "Steady" }

-- Siren tone (vehicle attribute SirenPattern / SirenTone, RP-M5 stream A) -> light pattern.
LightBarFlash.SirenPatterns = {
	Wail = "SlowAlternate",
	Yelp = "FastAlternate",
	HiLo = "WigWag",
	Phaser = "QuadFlash",
} :: { [string]: string }

local SPECS: { [string]: Spec } = {
	Alternate = { period = 2 / 3, flashes = 2, on = 0.06, gap = 0.06 },
	SlowAlternate = { period = 1.2, flashes = 3, on = 0.1, gap = 0.08 },
	FastAlternate = { period = 0.3, flashes = 1, on = 0.11, gap = 0 },
	WigWag = { period = 0.7, flashes = 1, on = 0.33, gap = 0 },
	QuadFlash = { period = 0.8, flashes = 4, on = 0.045, gap = 0.045 },
}

-- Reserved signal colours (docs/05 section 3.2) that a light colour must stay clear of in hue.
LightBarFlash.Reserved = {
	HullOrange = Color3.fromRGB(0xFF, 0x66, 0x00),
	HiVisYellow = Color3.fromRGB(0xDF, 0xFF, 0x00),
	SolasOrange = Color3.fromRGB(0xFF, 0x5A, 0x1F),
	DistressRed = Color3.fromRGB(0xFF, 0x2A, 0x1A),
	WaypointGreen = Color3.fromRGB(0x3E, 0xE0, 0x7A),
} :: { [string]: Color3 }

local function isPattern(name: any): boolean
	return type(name) == "string" and (SPECS[name] ~= nil or name == "Steady")
end
LightBarFlash.isPattern = isPattern

-- Is a half (side 1 or 2) lit at time t?
function LightBarFlash.sideOn(pattern: string, t: number, side: number): boolean
	if pattern == "Steady" then
		return true
	end
	local spec = SPECS[pattern] or SPECS.Alternate
	local half = spec.period / 2
	local phase = (t + (if side == 2 then half else 0)) % spec.period
	if phase >= half then
		return false
	end
	local step = spec.on + spec.gap
	local i = math.floor(phase / step)
	return i < spec.flashes and phase - i * step < spec.on
end

function LightBarFlash.lampOn(pattern: string, t: number, lamp: Lamp): boolean
	if lamp.steady or pattern == "Steady" then
		return true
	end
	local side = if lamp.invert then 3 - lamp.side else lamp.side
	return LightBarFlash.sideOn(pattern, t, side)
end

-- The pattern a bar runs: the siren's when it is on and known, else the option's base pattern.
function LightBarFlash.patternFor(base: string?, sirenOn: boolean, siren: any): string
	if sirenOn and type(siren) == "string" and LightBarFlash.SirenPatterns[siren] then
		return LightBarFlash.SirenPatterns[siren]
	end
	return if isPattern(base) then base :: string else "Alternate"
end

-- Lamp modules for a bar `width` studs wide: about one per 0.2 m (0.6 studs) per half, even, 2..8.
function LightBarFlash.lampCount(width: number): number
	return math.clamp(2 * math.floor(width / 1.2 + 0.5), 2, 8)
end

local function set(list: any): { [string]: boolean }
	local s = {}
	if type(list) == "table" then
		for _, v in list do
			s[v] = true
		end
	end
	return s
end

-- Per-lamp layout for an option (`half`, `invert`, `steady`) on an n-lamp bar, left to right. The
-- half pattern runs from each outer end inwards, so the bar is mirror-symmetric.
function LightBarFlash.layout(option: { [string]: any }, n: number): { Lamp }
	local half: { string } = if type(option.half) == "table" and #option.half > 0
		then option.half
		else { "Blue" }
	local invert, steady = set(option.invert), set(option.steady)
	local lamps: { Lamp } = {}
	if n <= 1 then
		local c = half[1]
		return { { color = c, side = 1, invert = false, steady = steady[c] == true } }
	end
	local per = n // 2
	for i = 1, n do
		local side = if i <= per then 1 else 2
		local fromOuter = if side == 1 then i else n + 1 - i -- 1 = outermost
		local c = half[(fromOuter - 1) % #half + 1]
		table.insert(
			lamps,
			{ color = c, side = side, invert = invert[c] == true, steady = steady[c] == true }
		)
	end
	return lamps
end

local function hue(c: Color3): (number, number)
	local h, s = c:ToHSV()
	return h * 360, s
end

-- The reserved colour a light colour is too close to (within `minHue` degrees and saturated), or
-- nil. White and other low-saturation lights never clash.
function LightBarFlash.reservedClash(c: Color3, minHue: number?): string?
	local h, s = hue(c)
	if s < 0.35 then
		return nil
	end
	if h < 12 or h > 340 then
		return "DistressRed"
	end
	for name, r in LightBarFlash.Reserved do
		local rh = hue(r)
		local d = math.abs(h - rh)
		d = math.min(d, 360 - d)
		if d < (minHue or 10) then
			return name
		end
	end
	return nil
end

return LightBarFlash
