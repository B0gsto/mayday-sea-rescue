--!strict
-- ForestTrees (docs/23 (l), WP-21a): code-built placeholder trees for the hub forest until tree art lands. Each tree
-- is an AssetLoader template in three LODs (LOD0 trunk + 3 canopy balls, LOD1 trunk + 2, LOD2 trunk + 1) plus an
-- invisible trunk hull (AssetLoader.COLLISION_TAG): WorldDressingService publishes the visual parts to the client
-- scatter (ScatterController draws them with the rock LOD distances) and keeps only the hulls on the server, so
-- players bump into trunks but stream no tree meshes. Base of the trunk at Y 0. Rows: map/generated/props.json
-- `trees` (tools/world/scatter_props.py forest()).
--
--   ForestTrees.define(AssetLoader)   registers M_Tree_Oak_01, M_Tree_Oak_02, M_Tree_Pine_01 x LOD0..2

local ForestTrees = {}

type Ball = { number } -- x, y, z, diameter, colour index
type Spec = { trunk: { number }, balls: { Ball }, colours: { Color3 }, lods: { number } }

local BARK = Color3.fromRGB(86, 64, 46)

-- trunk = { height, diameter }; lods = canopy balls kept per LOD (the first n of `balls`)
local SPECS: { [string]: Spec } = {
	M_Tree_Oak_01 = {
		trunk = { 13, 1.8 },
		balls = { { 0, 15, 0, 14, 1 }, { 3.8, 18.5, 2.2, 9, 2 }, { -3.6, 12.5, -2.6, 9, 3 } },
		colours = {
			Color3.fromRGB(62, 92, 42),
			Color3.fromRGB(76, 104, 48),
			Color3.fromRGB(52, 80, 38),
		},
		lods = { 3, 2, 1 },
	},
	M_Tree_Oak_02 = {
		trunk = { 10, 1.4 },
		balls = { { 0, 11.5, 0, 10, 1 }, { -2.4, 14.5, 1.6, 7, 2 }, { 2.6, 9.5, -1.8, 6.5, 1 } },
		colours = { Color3.fromRGB(88, 112, 54), Color3.fromRGB(74, 100, 46) },
		lods = { 3, 2, 1 },
	},
	M_Tree_Pine_01 = {
		trunk = { 9, 1.5 },
		balls = { { 0, 9, 0, 10.5, 1 }, { 0, 15, 0, 7.5, 2 }, { 0, 20, 0, 4.5, 2 } },
		colours = { Color3.fromRGB(40, 66, 46), Color3.fromRGB(48, 76, 52) },
		lods = { 3, 2, 1 },
	},
}

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function build(spec: Spec, balls: number, collisionTag: string): Model
	local m = Instance.new("Model")
	local h, d = spec.trunk[1], spec.trunk[2]
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a Cylinder's axis is X
	local trunk = part(
		m,
		"Trunk",
		Vector3.new(h, d, d),
		CFrame.new(0, h / 2, 0) * upright,
		BARK,
		Enum.Material.Wood
	)
	trunk.Shape = Enum.PartType.Cylinder
	for i = 1, balls do
		local b = spec.balls[i]
		local ball = part(
			m,
			"Canopy",
			Vector3.new(b[4], b[4], b[4]),
			CFrame.new(b[1], b[2], b[3]),
			spec.colours[b[5]],
			Enum.Material.Grass
		)
		ball.Shape = Enum.PartType.Ball
		ball.CastShadow = i == 1 -- one shadow caster per tree
	end
	local hull = part(
		m,
		"Hull",
		Vector3.new(10, d + 0.6, d + 0.6),
		CFrame.new(0, 5, 0) * upright,
		BARK,
		Enum.Material.Wood
	)
	hull.Shape = Enum.PartType.Cylinder
	hull.Transparency = 1
	hull:AddTag(collisionTag)
	m.WorldPivot = CFrame.identity -- the trunk foot; no PrimaryPart (its CFrame is the turned cylinder)
	return m
end

function ForestTrees.define(AssetLoader: any)
	for asset, spec in SPECS do
		for lod, balls in spec.lods do
			AssetLoader.define(asset, `LOD{lod - 1}`, build(spec, balls, AssetLoader.COLLISION_TAG))
		end
	end
end

return ForestTrees
