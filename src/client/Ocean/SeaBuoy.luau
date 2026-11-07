--!strict
-- SeaBuoy (docs/29 B): one zone-line buoy, code-built placeholder Parts until real art lands. A soft marker only:
-- the glow curtain between buoys is gone (owner 2026-11-07, "weird"); the crossing reads through fog and water.
-- No coplanar faces: every part overlaps the one below it (tests/ZFight.spec.luau).
local SeaBuoy = {}

export type Buoy = { model: Model, tinted: { BasePart } }

local WHITE = Color3.fromHex("F4F7FA")

local function part(
	model: Model,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	y: number,
	color: Color3?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = if shape == Enum.PartType.Cylinder
		then CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2)
		else CFrame.new(0, y, 0)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
		true, false, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color or WHITE
	p.Parent = model
	return p
end

function SeaBuoy.new(parent: Instance): Buoy
	local model = Instance.new("Model")
	model.Name = "SeaBuoy"
	local float = part(model, "Float", Enum.PartType.Cylinder, Vector3.new(5, 12, 12), 1.2)
	part(model, "Collar", Enum.PartType.Cylinder, Vector3.new(1.5, 8, 8), 4.15, WHITE)
	local mast = part(model, "Mast", Enum.PartType.Block, Vector3.new(4, 22, 4), 15.5)
	part(model, "Band", Enum.PartType.Block, Vector3.new(4.3, 3, 4.3), 16, WHITE)
	local lamp = part(model, "Lamp", Enum.PartType.Ball, Vector3.new(6, 6, 6), 28.5)
	lamp.Material = Enum.Material.Neon -- a steady light, never flashes
	model.PrimaryPart = float
	model.Parent = parent
	return { model = model, tinted = { float, mast, lamp } }
end

function SeaBuoy.tint(buoy: Buoy, color: Color3)
	for _, p in buoy.tinted do
		p.Color = color
	end
end

return SeaBuoy
