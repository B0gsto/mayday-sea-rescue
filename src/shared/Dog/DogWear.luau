--!strict
-- DogWear (RP-M5, Bosun's Wardrobe + Water Dog Friends): pure data and geometry for what the dog wears.
-- DogService builds it; the option lists live in src/shared/Config/Cosmetics/DogWear.luau and Dog.luau
-- (each option carries the key of its look here: `look`).
--
-- * Harness colours: a multiply tint on the Hull Orange harness parts (Shared.Dog.BosunRig), so a tint can only
--   darken channels: the variants are deep, real webbing colours (navy, forest, burgundy, teal). The free
--   default is the duty harness (no tint).
-- * Bandanas, the dog life jacket and the captain's hat are plain Parts (no new uploads), laid out here in
--   Bosun's authored frame (studs, origin on the ground between the feet, front -Z, up +Y; the same frame
--   as BosunMotion.PIVOTS). Each part says which body part it is welded to (`on` = "Fore" | "Head").
-- * Colours are sRGB hex. None of them may be a docs/05 3.2 reserved signal colour (tests check the
--   distance to every one of them).
local DogWear = {}

export type PartSpec = {
	name: string,
	shape: string, -- "Block" | "Wedge" | "Cylinder" (Cylinder axis = the CFrame's X axis)
	size: Vector3,
	cframe: CFrame, -- in the authored frame
	color: string, -- hex
	material: string, -- Enum.Material name
	on: string, -- "Fore" | "Head"
}

-- docs/05 section 3.2 (sRGB approximations).
DogWear.RESERVED = {
	HullOrange = "FF6600",
	HiVisYellow = "DFFF00",
	SolasOrange = "FF5A1F",
	DistressRed = "FF2A1A",
	Retroreflective = "D6D9DC",
	WaypointGreen = "3EE07A",
}
DogWear.MIN_RESERVED_DISTANCE = 60 -- RGB distance (0..441) every cosmetic colour keeps from them

-- Harness tints (multiplied into the harness orange, BosunRig HARNESS).
DogWear.HARNESS_ORANGE = "FF6600"
DogWear.HARNESS = {
	Duty = nil :: { number }?, -- the uploaded colour
	Navy = { 0.22, 0.75, 1.0 },
	Forest = { 0.3, 1.0, 1.0 },
	Burgundy = { 0.78, 0.45, 0.95 },
	Teal = { 0.15, 0.85, 1.0 },
}

-- Six plain cotton bandanas (real bandana dye colours, none of them a signal colour).
DogWear.BANDANA = {
	Red = "9E2A2B", -- classic turkey red, darker than Distress Red
	Navy = "1F2B47",
	Forest = "2E4A34",
	Burgundy = "5E1E2B",
	Chambray = "6F8BA8",
	Mustard = "B98F2E",
}

local JACKET_SHELL = "2C4E86" -- a blue dog float coat (the reserved oranges are for casualties and the hull)
local JACKET_TRIM = "9AA0A6" -- grey piping, kept well off the reserved retroreflective silver
local WEBBING = "1C1D20"
local HAT_CROWN = "222B3F" -- a navy skipper's cap (a white crown sits too close to the reserved tape silver)
local HAT_BAND = "15161A"
local HAT_PEAK = "15161A"
local BRASS = "A8874A"

-- The neck: the bandana's top edge at the throat, the ring round the neck base to the nape (BosunRig's
-- neck block meeting the chest ball and the torso top).
local THROAT = Vector3.new(0, 1.95, -1.47)
local NAPE = Vector3.new(0, 2.3, -0.98)
local NECK_HALF_WIDTH = 0.33

local function v3(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

-- A frame from a position and two axes (right, up), re-orthonormalised.
local function frame(pos: Vector3, right: Vector3, up: Vector3): CFrame
	local r = right.Unit
	local b = r:Cross(up).Unit -- back (+Z)
	local u = b:Cross(r).Unit
	return CFrame.fromMatrix(pos, r, u)
end
DogWear.frame = frame

local function spec(name, shape, size, cf, color, material, on): PartSpec
	return {
		name = name,
		shape = shape,
		size = size,
		cframe = cf,
		color = color,
		material = material,
		on = on,
	}
end

-- A folded triangle hanging from `top` (centre of its top edge) along `down`, `width` across X.
-- Two right-angled WedgeParts meet on the centre line (the wedge's right angle is at local -Y / +Z).
local function triangle(
	prefix: string,
	top: Vector3,
	down: Vector3,
	width: number,
	height: number,
	color
)
	local d = down.Unit
	local x = Vector3.new(1, 0, 0)
	local out = {}
	for _, side in { 1, -1 } do
		local localY = d
		local localZ = -x * side
		local localX = localY:Cross(localZ)
		local centre = top + d * (height / 2) + x * side * (width / 4)
		local cf = CFrame.fromMatrix(centre, localX, localY, localZ)
		table.insert(
			out,
			spec(
				prefix .. (if side > 0 then "R" else "L"),
				"Wedge",
				Vector3.new(0.035, height, width / 2),
				cf,
				color,
				"Fabric",
				"Fore"
			)
		)
	end
	return out
end

-- A rolled band round the neck: short cylinders on the ellipse through THROAT and NAPE.
local function neckRing(
	prefix: string,
	color: string,
	segments: number,
	radius: number
): { PartSpec }
	local centre = (THROAT + NAPE) / 2
	local long = (THROAT - centre) -- toward the throat
	local half = long.Magnitude
	local a = long.Unit
	local side = Vector3.new(1, 0, 0)
	local out = {}
	local points = {}
	for i = 0, segments - 1 do
		local t = (i / segments) * 2 * math.pi
		table.insert(points, centre + a * math.cos(t) * half + side * math.sin(t) * NECK_HALF_WIDTH)
	end
	for i = 1, segments do
		local p0 = points[i]
		local p1 = points[i % segments + 1]
		local mid = (p0 + p1) / 2
		local along = p1 - p0
		local outward = (mid - centre).Unit
		local cf = frame(mid, along, outward)
		table.insert(
			out,
			spec(
				`{prefix}{i}`,
				"Cylinder",
				Vector3.new(along.Magnitude + 0.04, radius * 2, radius * 2),
				cf,
				color,
				"Fabric",
				"Fore"
			)
		)
	end
	return out
end

-- A bandana: folded triangle on the chest, the roll round the neck, a small knot at the nape.
function DogWear.bandana(color: string): { PartSpec }
	local parts = triangle(
		"Bandana",
		THROAT + Vector3.new(0, -0.02, -0.1), -- over the harness chest strap
		Vector3.new(0, -1, 0),
		0.6,
		0.42,
		color
	)
	for _, p in neckRing("BandanaRoll", color, 12, 0.045) do
		table.insert(parts, p)
	end
	table.insert(
		parts,
		spec(
			"BandanaKnot",
			"Block",
			Vector3.new(0.12, 0.08, 0.09),
			frame(NAPE + Vector3.new(0, 0.03, 0.02), Vector3.new(1, 0, 0), (NAPE - THROAT).Unit),
			color,
			"Fabric",
			"Fore"
		)
	)
	return parts
end

-- The dog life jacket: foam back and side panels with rolled shoulders, a chest float under the neck,
-- two belly straps, grey piping along the sides and a webbing grab handle on top.
function DogWear.lifeJacket(): { PartSpec }
	local parts: { PartSpec } = {}
	local z, len = 0.12, 1.62
	local SIDE, BACK = 0.55, 2.2 -- BosunRig torso: half width 0.475, top 2.13
	local function add(p: PartSpec)
		table.insert(parts, p)
	end
	add(
		spec(
			"JacketBack",
			"Block",
			Vector3.new(1.04, 0.15, len),
			CFrame.new(0, BACK, z),
			JACKET_SHELL,
			"Fabric",
			"Fore"
		)
	)
	for _, s in { 1, -1 } do
		local tag = if s > 0 then "R" else "L"
		local roll = math.rad(9) * s
		local sideCf = CFrame.new(SIDE * s, 1.8, z) * CFrame.Angles(0, 0, roll)
		add(
			spec(
				"JacketSide" .. tag,
				"Block",
				Vector3.new(0.15, 0.7, len - 0.06),
				sideCf,
				JACKET_SHELL,
				"Fabric",
				"Fore"
			)
		)
		add(
			spec(
				"JacketShoulder" .. tag,
				"Cylinder",
				Vector3.new(len, 0.3, 0.3),
				CFrame.new(0.47 * s, BACK - 0.06, z) * CFrame.Angles(0, math.rad(90), 0),
				JACKET_SHELL,
				"Fabric",
				"Fore"
			)
		)
		add(
			spec(
				"JacketHem" .. tag,
				"Cylinder",
				Vector3.new(len - 0.06, 0.17, 0.17),
				sideCf * CFrame.new(0, -0.35, 0) * CFrame.Angles(0, math.rad(90), 0),
				JACKET_SHELL,
				"Fabric",
				"Fore"
			)
		)
		add(
			spec(
				"JacketPiping" .. tag,
				"Block",
				Vector3.new(0.02, 0.07, len - 0.2),
				sideCf * CFrame.new(0.08 * s, 0.12, 0),
				JACKET_TRIM,
				"Fabric",
				"Fore"
			)
		)
		for i, sz in { -0.42, 0.62 } do
			add(
				spec(
					`JacketStrap{tag}{i}`,
					"Block",
					Vector3.new(0.035, 0.28, 0.15),
					CFrame.new(0.5 * s, 1.32, sz) * CFrame.Angles(0, 0, math.rad(-8) * s),
					WEBBING,
					"Fabric",
					"Fore"
				)
			)
		end
	end
	for i, sz in { -0.42, 0.62 } do
		add(
			spec(
				`JacketBelly{i}`,
				"Block",
				Vector3.new(1.0, 0.035, 0.15),
				CFrame.new(0, 1.2, sz),
				WEBBING,
				"Fabric",
				"Fore"
			)
		)
	end
	-- chest float: a foam pad on the chest below the throat, its lower edge rolled
	local chestTop = THROAT + Vector3.new(0, -0.08, -0.11)
	local down = Vector3.new(0, -1, 0)
	local chestCf = frame(chestTop + down * 0.22, Vector3.new(1, 0, 0), -down)
	add(
		spec(
			"JacketChest",
			"Block",
			Vector3.new(0.7, 0.45, 0.16),
			chestCf,
			JACKET_SHELL,
			"Fabric",
			"Fore"
		)
	)
	add(
		spec(
			"JacketChestRoll",
			"Cylinder",
			Vector3.new(0.7, 0.16, 0.16),
			chestCf * CFrame.new(0, -0.22, 0),
			JACKET_SHELL,
			"Fabric",
			"Fore"
		)
	)
	-- grab handle: two stitched feet and a webbing loop with a rubber grip
	for i, hz in { -0.16, 0.4 } do
		add(
			spec(
				`JacketHandleFoot{i}`,
				"Block",
				Vector3.new(0.13, 0.17, 0.035),
				CFrame.new(0, BACK + 0.15, z + hz - 0.12),
				WEBBING,
				"Fabric",
				"Fore"
			)
		)
	end
	add(
		spec(
			"JacketHandle",
			"Block",
			Vector3.new(0.13, 0.035, 0.6),
			CFrame.new(0, BACK + 0.24, z),
			WEBBING,
			"Fabric",
			"Fore"
		)
	)
	add(
		spec(
			"JacketGrip",
			"Cylinder",
			Vector3.new(0.34, 0.09, 0.09),
			CFrame.new(0, BACK + 0.25, z) * CFrame.Angles(0, math.rad(90), 0),
			"2A2B2E",
			"Rubber",
			"Fore"
		)
	)
	return parts
end

-- A tiny captain's hat between the ears: black band, navy crown, black peak, brass badge and cord.
function DogWear.captainsHat(): { PartSpec }
	local base = CFrame.new(0, 2.98, -1.55) * CFrame.Angles(math.rad(-10), 0, 0) -- tipped forward a little
	local up = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> up
	return {
		spec(
			"HatBand",
			"Cylinder",
			Vector3.new(0.13, 0.58, 0.58),
			base * CFrame.new(0, 0.07, 0) * up,
			HAT_BAND,
			"Fabric",
			"Head"
		),
		spec(
			"HatCrown",
			"Cylinder",
			Vector3.new(0.12, 0.75, 0.75),
			base * CFrame.new(0, 0.18, 0.02) * up,
			HAT_CROWN,
			"Fabric",
			"Head"
		),
		spec(
			"HatPeak",
			"Cylinder",
			Vector3.new(0.03, 0.46, 0.46),
			base * CFrame.new(0, 0.03, -0.25) * CFrame.Angles(math.rad(-14), 0, 0) * up,
			HAT_PEAK,
			"SmoothPlastic",
			"Head"
		),
		spec(
			"HatCord",
			"Block",
			Vector3.new(0.48, 0.026, 0.024),
			base * CFrame.new(0, 0.08, -0.29),
			BRASS,
			"Metal",
			"Head"
		),
		spec(
			"HatBadge",
			"Cylinder",
			Vector3.new(0.024, 0.13, 0.13),
			base * CFrame.new(0, 0.18, -0.38) * CFrame.Angles(0, math.rad(90), 0),
			BRASS,
			"Metal",
			"Head"
		),
	}
end

-- Look key -> parts (nil / "None": nothing).
function DogWear.parts(kind: string, look: string?): { PartSpec }
	if not look or look == "None" then
		return {}
	elseif kind == "Bandana" then
		local hex = DogWear.BANDANA[look]
		return if hex then DogWear.bandana(hex) else {}
	elseif kind == "Jacket" and look == "LifeJacket" then
		return DogWear.lifeJacket()
	elseif kind == "Hat" and look == "CaptainsHat" then
		return DogWear.captainsHat()
	end
	return {}
end

function DogWear.harnessTint(look: string?): { number }?
	return if look then (DogWear.HARNESS :: any)[look] else nil
end

-- `hex` multiplied by `tint` (r, g, b factors), as hex.
function DogWear.tinted(hex: string, tint: { number }): string
	local out = ""
	for i = 1, 3 do
		local v = tonumber(string.sub(hex, 2 * i - 1, 2 * i), 16) or 0
		out ..= string.format("%02X", math.floor(v * tint[i] + 0.5))
	end
	return out
end

-- RGB distance between two hex colours (0..441).
function DogWear.distance(a: string, b: string): number
	local function rgb(h: string): (number, number, number)
		return tonumber(string.sub(h, 1, 2), 16) or 0,
			tonumber(string.sub(h, 3, 4), 16) or 0,
			tonumber(string.sub(h, 5, 6), 16) or 0
	end
	local r1, g1, b1 = rgb(a)
	local r2, g2, b2 = rgb(b)
	return math.sqrt((r1 - r2) ^ 2 + (g1 - g2) ^ 2 + (b1 - b2) ^ 2)
end

-- Every colour any wear can use (for the reserved-colour check), including the tinted harness.
function DogWear.allColors(): { string }
	local out = {}
	local kinds: { { any } } = {
		{ "Bandana", DogWear.BANDANA },
		{ "Jacket", { LifeJacket = true } },
		{ "Hat", { CaptainsHat = true } },
	}
	for _, kind in kinds do
		for look in kind[2] :: any do
			for _, p in DogWear.parts(kind[1] :: string, look) do
				table.insert(out, p.color)
			end
		end
	end
	for _, tint in DogWear.HARNESS :: any do
		table.insert(out, DogWear.tinted(DogWear.HARNESS_ORANGE, tint))
	end
	return out
end

DogWear.v3 = v3
return DogWear
