--!strict
-- PirateBoat (docs/29 D): the placeholder Lego pirate boat from art/source/concepts/sea-zones (pirateBoat in src/models.js):
-- striped sail, black flag, shark-jaw ram, no guns. Code-built Parts until the Blender art lands; bow along -Z, the
-- pivot on the waterline, about 63 x 50 studs. All anchored and not solid: the server steers it, nothing collides.
local PirateBoat = {}

local S = 1.15 -- concept units -> studs
local DARK = Color3.fromHex("2E190E")
local WOOD = Color3.fromHex("6B3C22")
local WOOD_DARK = Color3.fromHex("4A2815")
local TAN = Color3.fromHex("D2A264")
local RED = Color3.fromHex("D8262C")
local CREAM = Color3.fromHex("FFF1D6")
local GOLD = Color3.fromHex("F2B72A")
local IRON = Color3.fromHex("454B59")
local BLACK = Color3.fromHex("14121C")

function PirateBoat.build(): Model
	local model = Instance.new("Model")
	model.Name = "PirateBoat"
	-- x: stern to bow, y: up, z: beam, as in the concept
	local function add(
		class: string,
		x0: number,
		x1: number,
		y0: number,
		y1: number,
		half: number,
		color: Color3,
		z: number?
	): BasePart
		local part = Instance.new(class) :: BasePart
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Size = Vector3.new(half * 2, y1 - y0, x1 - x0) * S
		part.CFrame = CFrame.new((z or 0) * S, (y0 + y1) / 2 * S, -(x0 + x1) / 2 * S)
		part.Parent = model
		return part
	end
	local function box(
		x0: number,
		x1: number,
		y0: number,
		y1: number,
		half: number,
		color: Color3,
		z: number?
	): BasePart
		return add("Part", x0, x1, y0, y1, half, color, z)
	end
	-- the hull, stepping wider as it rises: the galleon outline is the pirate read at distance
	local keel = box(-17, 20, -1, 2, 5.5, DARK)
	box(-18, 22, 2, 4.5, 6.4, WOOD)
	box(-19, 23.5, 4.5, 6, 6.9, GOLD)
	box(-20, 25, 6, 8.5, 7.3, WOOD)
	box(-20.6, 26, 8.5, 9.5, 7.7, RED)
	-- castles
	box(11, 24.6, 9.5, 12.5, 6.6, WOOD_DARK)
	box(-20.4, -7, 9.5, 14, 7.5, WOOD_DARK)
	box(-23, -13, 14, 18.2, 8, RED)
	box(-23.4, -12.6, 18.2, 19, 8.4, GOLD)
	for _, z in { -5, 0, 5 } do
		box(-21, -15, 19, 19.5, 1, TAN, z)
		box(13, 20, 12.5, 13, 1, TAN, z)
	end
	for x = -6, 10, 4 do
		box(x - 0.5, x + 0.5, 9.5, 11.6, 0.4, DARK, -7.2)
		box(x - 0.5, x + 0.5, 9.5, 11.6, 0.4, DARK, 7.2)
	end
	-- mast, yard, sail in red and cream stripes
	box(1.4, 3.4, 9.5, 41, 1, DARK)
	box(0.2, 1.3, 35, 36, 13, WOOD_DARK)
	for i = 0, 4 do
		box(
			-0.2,
			0.9,
			16 + i * 3.8,
			16 + (i + 1) * 3.8,
			12 - (4 - i) * 0.4,
			if i % 2 == 0 then RED else CREAM
		)
	end
	-- the black flag and its white skull
	box(1.9, 2.9, 41, 42, 0.5, GOLD)
	box(2.1, 2.7, 36.5, 40.5, 3.2, BLACK, 4.2)
	box(1.95, 2.85, 37.7, 39.5, 0.9, CREAM, 4.2)
	-- the shark-jaw ram: iron jaws, white teeth
	box(26, 33, 5.6, 7, 3.6, IRON)
	box(26, 31, 2.2, 3.6, 3.2, IRON)
	for z = -2.4, 2.4, 1.6 do
		box(31.3, 32.5, 4.4, 5.6, 0.45, CREAM, z)
		box(29.6, 30.8, 3.6, 4.8, 0.45, CREAM, z)
	end
	box(24.5, 26.6, 2.6, 6.6, 2.6, DARK) -- the throat, ends inside the jaws
	model.PrimaryPart = keel
	model.WorldPivot = CFrame.identity
	return model
end

return PirateBoat
