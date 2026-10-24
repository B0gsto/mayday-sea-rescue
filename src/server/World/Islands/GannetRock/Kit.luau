--!strict
-- Kit: the Part helpers Gannet Rock builds with (anchored, smooth, no touch events). Materials stay in the
-- unremapped set (Granite, Plaster, Wood, Metal, Glass, SmoothPlastic): MaterialService remaps Slate / Concrete /
-- WoodPlanks / Brick for the terrain.
local Kit = {}

local UP = CFrame.Angles(0, 0, math.pi / 2) -- a Part cylinder's axis is its X

function Kit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A vertical cylinder from y0 to y1 around (at.X, at.Z).
function Kit.cyl(
	parent: Instance,
	name: string,
	at: Vector3,
	radius: number,
	y0: number,
	y1: number,
	color: Color3,
	material: Enum.Material
): Part
	return Kit.part(
		parent,
		name,
		Vector3.new(y1 - y0, radius * 2, radius * 2),
		CFrame.new(at.X, (y0 + y1) / 2, at.Z) * UP,
		color,
		material,
		Enum.PartType.Cylinder
	)
end

-- The horizontal unit vector at angle a (radians; 0 = +X, pi/2 = +Z).
function Kit.dir(a: number): Vector3
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

-- A block whose local X points along `ahead` (horizontal), Y up.
function Kit.facing(pos: Vector3, ahead: Vector3): CFrame
	local x = Vector3.new(ahead.X, 0, ahead.Z).Unit
	return CFrame.fromMatrix(pos, x, Vector3.yAxis)
end

-- n blocks around a circle (an n-gon wall or deck): radial depth r0..r1, height y0..y1. skip(i) leaves gaps.
function Kit.ring(
	parent: Instance,
	name: string,
	at: Vector3,
	n: number,
	r0: number,
	r1: number,
	y0: number,
	y1: number,
	color: Color3,
	material: Enum.Material,
	phase: number?,
	skip: ((number) -> boolean)?
): { Part }
	local out = {}
	local half = math.pi / n
	for i = 0, n - 1 do
		if not (skip and skip(i)) then
			local a = (phase or 0) + i * 2 * half
			local width = 2 * r1 * math.tan(half) + 0.06 -- the outer edges meet
			local pos = Vector3.new(at.X, (y0 + y1) / 2, at.Z) + Kit.dir(a) * ((r0 + r1) / 2)
			table.insert(
				out,
				Kit.part(
					parent,
					`{name}{i}`,
					Vector3.new(r1 - r0, y1 - y0, width),
					Kit.facing(pos, Kit.dir(a)),
					color,
					material
				)
			)
		end
	end
	return out
end

-- A straight rail or beam between two points (square section).
function Kit.beam(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	thick: number,
	color: Color3,
	material: Enum.Material
): Part
	return Kit.part(
		parent,
		name,
		Vector3.new(thick, thick, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b),
		color,
		material
	)
end

return Kit
