--!strict
-- PartGrid: fallback ocean when EditableMesh is unavailable (the experience's "Allow Mesh / Image
-- APIs" security setting off, memory budget, old client). A lattice of shared vertices on the wave
-- surface, each cell drawn as two triangles of two WedgeParts each, so neighbours share their edges
-- exactly (no gaps or steps). Wedges wear the OceanWater MaterialVariant (the ocean normal map and
-- glossy roughness; template WaterVariant.model.json, cloned into MaterialService on first use). Its
-- MaterialPattern is Organic: each wedge maps the texture in its own frame, and the Regular tiling showed
-- as repeating chevrons that changed direction at every triangle edge.
-- Allocates CFrames per update (fallback only; at most 12 x 12 cells = 576 wedges).

local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")

local OceanPalette = require(script.Parent.OceanPalette)

local THICKNESS = 0.1 -- wedge slab; its top face lies on the surface
local VARIANT = "OceanWater"

export type PartGrid = {
	parts: { WedgePart }, -- 4 per cell: triangle 1 (w1, w2), triangle 2 (w1, w2)
	cframes: { CFrame },
	cells: number,
	cellSize: number,
	half: number,
	ys: { number }, -- world Y per lattice vertex (i * (cells + 1) + j + 1)
	bucket: { number }, -- palette bucket per triangle
	tint: Color3, -- water tint the buckets were coloured with
	foam: number, -- whitecap strength the buckets were coloured with
}

local PartGrid = {}

local function ensureVariant(): boolean
	if MaterialService:FindFirstChild(VARIANT) then
		return true
	end
	local template = script.Parent:FindFirstChild("WaterVariant")
	if not (template and template:IsA("MaterialVariant")) then
		return false
	end
	local variant = template:Clone()
	variant.Name = VARIANT
	variant.Parent = MaterialService
	return true
end

function PartGrid.new(parent: Instance, cells: number, cellSize: number): PartGrid
	local hasVariant = ensureVariant()
	local count = cells * cells * 4
	local parts: { WedgePart } = table.create(count)
	for _ = 1, count do
		local part = Instance.new("WedgePart")
		part.Name = "OceanTri"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		if hasVariant then
			part.MaterialVariant = VARIANT
		else
			part.Reflectance = 0.08 -- tune
		end
		part.Color = OceanPalette.colours[OceanPalette.SEA_BUCKET]
		part.Parent = parent
		table.insert(parts, part)
	end
	return {
		parts = parts,
		cframes = table.create(count, CFrame.identity),
		cells = cells,
		cellSize = cellSize,
		half = cells * cellSize / 2,
		ys = table.create((cells + 1) * (cells + 1), 0),
		bucket = table.create(cells * cells * 2, 0),
		tint = Color3.new(),
		foam = 0,
	}
end

-- Places wedges n and n + 1 to fill triangle abc (the classic two-right-angle-wedge split along
-- the altitude from the longest edge), slab top face on the triangle.
local function triangle(grid: PartGrid, n: number, a: Vector3, b: Vector3, c: Vector3)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local sink = (if right.Y > 0 then right else -right) * (THICKNESS / 2)
	local parts, cframes = grid.parts, grid.cframes
	parts[n].Size = Vector3.new(THICKNESS, height, math.abs(ab:Dot(back)))
	cframes[n] = CFrame.fromMatrix((a + b) / 2 - sink, right, up, back)
	parts[n + 1].Size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back)))
	cframes[n + 1] = CFrame.fromMatrix((a + c) / 2 - sink, -right, up, -back)
end

-- heightAt(x, z) -> world Y of the surface. tint: the flat-sea colour (matches the far plane);
-- troughs and crests blend toward the palette's navy / foam. foam 0..1 (storm intensity, quantised by the
-- caller): whitecaps, the highest crests whiten (the mesh ocean's foam overlay is off while the Part grid stands in).
function PartGrid.update(
	grid: PartGrid,
	cx: number,
	cz: number,
	seaLevel: number,
	heightAt: (number, number) -> number,
	tint: Color3,
	foam: number
)
	if tint ~= grid.tint or foam ~= grid.foam then
		grid.tint, grid.foam = tint, foam
		table.clear(grid.bucket)
	end
	local cells, size, half, ys = grid.cells, grid.cellSize, grid.half, grid.ys
	local side = cells + 1
	for i = 0, cells do
		for j = 0, cells do
			ys[i * side + j + 1] = heightAt(cx + i * size - half, cz + j * size - half)
		end
	end
	local colours, bucket, parts = OceanPalette.colours, grid.bucket, grid.parts
	local n, t = 1, 1
	for i = 0, cells - 1 do
		local x0, x1 = cx + i * size - half, cx + (i + 1) * size - half
		for j = 0, cells - 1 do
			local z0, z1 = cz + j * size - half, cz + (j + 1) * size - half
			local y00, y10 = ys[i * side + j + 1], ys[(i + 1) * side + j + 1]
			local y01, y11 = ys[i * side + j + 2], ys[(i + 1) * side + j + 2]
			local p00, p10 = Vector3.new(x0, y00, z0), Vector3.new(x1, y10, z0)
			local p01, p11 = Vector3.new(x0, y01, z1), Vector3.new(x1, y11, z1)
			triangle(grid, n, p00, p01, p10)
			triangle(grid, n + 2, p10, p01, p11)
			for k = 0, 1 do
				local mean = (y10 + y01 + (if k == 0 then y00 else y11)) / 3
				local b = OceanPalette.bucketFor(mean - seaLevel)
				if b ~= bucket[t] then
					bucket[t] = b
					-- Gentle: each triangle is one flat colour, so strong shading read as diamond facets and
					-- diagonal bands across the sea (playtest r16-r51). The waves read from facet lighting. -- tune
					local colour = tint:Lerp(
						colours[b],
						math.min(math.abs(b - OceanPalette.SEA_BUCKET) / OceanPalette.HALF, 1)
							* (if b > OceanPalette.SEA_BUCKET then 0.35 + 0.55 * foam else 0.35)
					)
					parts[n + k * 2].Color = colour
					parts[n + k * 2 + 1].Color = colour
				end
				t += 1
			end
			n += 4
		end
	end
	Workspace:BulkMoveTo(parts, grid.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function PartGrid.destroy(grid: PartGrid)
	for _, part in grid.parts do
		part:Destroy()
	end
	table.clear(grid.parts)
end

return PartGrid
