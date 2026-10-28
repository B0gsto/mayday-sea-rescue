--!strict
-- StreetFurniture: code-built bench and litter bin standing in for M_Road_Bench / M_Road_Bin, whose
-- uploads render as flat navy blocks in the live client (round-2 art review), plus the Fore Street clutter:
-- Planter (granite trough of bedding flowers), ABoard (chalkboard A-frame), HangingBasket (pivot = the hook, hangs
-- below it). Same conventions as the assets: pivot at the base centre, front (the sitting side) = local -Z.
--   StreetFurniture.build(asset) -> Model?   nil for any other asset (the caller clones the real one)

local StreetFurniture = {}

local IRON = Color3.fromRGB(34, 42, 38) -- cast-iron ends, painted dark green-black
local OAK = Color3.fromRGB(150, 108, 68)
local BIN_GREEN = Color3.fromRGB(38, 62, 48)
local GOLD = Color3.fromRGB(196, 160, 70)

local function part(
	m: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = m
end

local function bench(m: Model)
	for _, x in { -2.7, 2.7 } do
		part(
			m,
			"LegFront",
			Vector3.new(0.25, 1.45, 0.25),
			CFrame.new(x, 0.72, -0.8),
			IRON,
			Enum.Material.Metal
		)
		part(
			m,
			"LegBack",
			Vector3.new(0.25, 2.9, 0.25),
			CFrame.new(x, 1.45, 0.7) * CFrame.Angles(0.12, 0, 0),
			IRON,
			Enum.Material.Metal
		)
		part(
			m,
			"Arm",
			Vector3.new(0.25, 0.2, 1.8),
			CFrame.new(x, 2.1, -0.15),
			IRON,
			Enum.Material.Metal
		)
	end
	for i, z in { -0.75, -0.25, 0.25 } do
		part(
			m,
			`Seat{i}`,
			Vector3.new(5.9, 0.16, 0.42),
			CFrame.new(0, 1.5, z),
			OAK,
			Enum.Material.Wood
		)
	end
	for i, y in { 2.15, 2.7 } do
		part(
			m,
			`Back{i}`,
			Vector3.new(5.9, 0.42, 0.12),
			-- 0.05 in front of the back legs' faces (0.72 left them 0.001 apart)
			CFrame.new(0, y, 0.67 + (y - 2.15) * 0.12) * CFrame.Angles(0.12, 0, 0),
			OAK,
			Enum.Material.Wood
		)
	end
end

local function bin(m: Model)
	local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinders run along X
	part(
		m,
		"Body",
		Vector3.new(2.5, 1.8, 1.8),
		CFrame.new(0, 1.25, 0) * upright,
		BIN_GREEN,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Band",
		Vector3.new(0.18, 1.86, 1.86),
		CFrame.new(0, 2.05, 0) * upright,
		GOLD,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Lid",
		Vector3.new(0.3, 2.0, 2.0),
		CFrame.new(0, 2.65, 0) * upright,
		BIN_GREEN,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Mouth",
		Vector3.new(0.05, 0.5, 1.0),
		CFrame.new(0, 1.9, -0.9),
		Color3.fromRGB(16, 18, 16),
		Enum.Material.SmoothPlastic
	)
end

-- bedding colours: geranium red, petunia pink and purple, white alyssum, marigold
local BLOOMS = {
	Color3.fromRGB(200, 36, 44),
	Color3.fromRGB(226, 108, 160),
	Color3.fromRGB(122, 64, 150),
	Color3.fromRGB(236, 232, 222),
	Color3.fromRGB(232, 150, 40),
}
local LEAF = Color3.fromRGB(62, 92, 48)

-- a mound of flowers: leafy cushion (Fabric: Grass is a terrain slot) dotted with blooms
local function blooms(m: Model, at: CFrame, w: number, d: number, seed: number)
	part(m, "Leaves", Vector3.new(w, 0.7, d), at, LEAF, Enum.Material.Fabric)
	local rng = Random.new(seed)
	for i = 1, math.floor(w * d * 1.2) do
		local s = rng:NextNumber(0.35, 0.6)
		part(
			m,
			`Bloom{i}`,
			Vector3.new(s, s, s),
			at
				* CFrame.new(
					rng:NextNumber(-w / 2, w / 2) * 0.9,
					0.35,
					rng:NextNumber(-d / 2, d / 2) * 0.9
				),
			BLOOMS[rng:NextInteger(1, #BLOOMS)],
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
	end
end

local function planter(m: Model)
	local stone = Color3.fromRGB(150, 146, 138)
	part(m, "Trough", Vector3.new(5, 1.8, 2), CFrame.new(0, 0.9, 0), stone, Enum.Material.Granite)
	part(
		m,
		"Lip",
		Vector3.new(5.3, 0.25, 2.3),
		CFrame.new(0, 1.85, 0),
		stone,
		Enum.Material.Granite
	)
	part(
		m,
		"Soil",
		Vector3.new(4.6, 0.1, 1.6),
		CFrame.new(0, 1.95, 0),
		Color3.fromRGB(58, 44, 32),
		Enum.Material.Fabric
	)
	blooms(m, CFrame.new(0, 2.2, 0), 4.4, 1.5, 7)
end

-- chalkboard A-frame: two boards leaning together, the -Z face toward the passers-by; pale chalk strokes, no words
local function aBoard(m: Model)
	local frame = Color3.fromRGB(40, 58, 46)
	local chalk = Color3.fromRGB(220, 218, 206)
	for _, side in { -1, 1 } do
		local lean = CFrame.new(0, 1.35, side * 0.42) * CFrame.Angles(side * 0.17, 0, 0)
		part(m, "Board", Vector3.new(1.7, 2.7, 0.12), lean, frame, Enum.Material.Wood)
		-- the slate sunk into the board, its face 0.05 proud of the board's; the chalk 0.05 proud of the slate's
		local face = lean * CFrame.new(0, 0.05, side * 0.06)
		part(
			m,
			"Slate",
			Vector3.new(1.4, 2.1, 0.1),
			face,
			Color3.fromRGB(30, 33, 34),
			Enum.Material.SmoothPlastic
		)
		for i, w in { 0.9, 1.1, 0.7, 1.0 } do
			part(
				m,
				`Chalk{i}`,
				Vector3.new(w, 0.07, 0.1),
				face * CFrame.new((i % 2) * 0.1 - 0.05, 0.75 - i * 0.38, side * 0.05),
				if i == 1 then Color3.fromRGB(236, 190, 90) else chalk,
				Enum.Material.SmoothPlastic
			)
		end
	end
end

-- hanging basket: the hook at the pivot, a chain, a moss bowl trailing flowers
local function basket(m: Model)
	local iron = Color3.fromRGB(24, 26, 26)
	part(
		m,
		"Chain",
		Vector3.new(0.08, 1.2, 0.08),
		CFrame.new(0, -0.6, 0),
		iron,
		Enum.Material.Metal
	)
	part(
		m,
		"Bowl",
		Vector3.new(0.9, 2.2, 2.2),
		CFrame.new(0, -1.75, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(70, 74, 46),
		Enum.Material.Fabric,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Mound",
		Vector3.new(2.4, 1.3, 2.4),
		CFrame.new(0, -1.5, 0),
		LEAF,
		Enum.Material.Fabric,
		Enum.PartType.Ball
	)
	local rng = Random.new(11)
	for i = 1, 14 do
		local a = i * 2.4
		local r = rng:NextNumber(0.8, 1.25)
		local s = rng:NextNumber(0.35, 0.55)
		part(
			m,
			`Bloom{i}`,
			Vector3.new(s, s, s),
			CFrame.new(math.cos(a) * r, rng:NextNumber(-2.4, -1.0), math.sin(a) * r),
			BLOOMS[rng:NextInteger(1, #BLOOMS)],
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
	end
end

local BUILDERS: { [string]: (Model) -> () } = {
	M_Road_Bench = bench,
	M_Road_Bin = bin,
	Planter = planter,
	ABoard = aBoard,
	HangingBasket = basket,
}

function StreetFurniture.build(asset: string): Model?
	local fn = BUILDERS[asset]
	if not fn then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = asset
	fn(m)
	m.WorldPivot = CFrame.identity
	return m
end

return StreetFurniture
