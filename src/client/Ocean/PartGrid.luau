--!strict
-- PartGrid: fallback ocean when EditableMesh is unavailable (permissions, memory budget, old
-- client). A low-res grid of thin tiles, each placed on the wave surface at its centre and
-- tilted to the surface normal, moved with one workspace:BulkMoveTo per update. Looks faceted
-- but keeps the game playable and readable. Allocates one CFrame per tile per update (fallback
-- only; at most 12 x 12 = 144 tiles).

local Workspace = game:GetService("Workspace")

local OceanPalette = require(script.Parent.OceanPalette)

local THICKNESS = 1
local OVERSIZE = 1.12 -- tiles overlap so tilted neighbours do not leave gaps -- tune

export type PartGrid = {
	parts: { BasePart },
	cframes: { CFrame },
	lx: { number },
	lz: { number },
	bucket: { number },
	count: number,
	half: number,
}

local PartGrid = {}

function PartGrid.new(parent: Instance, cells: number, cellSize: number): PartGrid
	local half = cells * cellSize / 2
	local count = cells * cells
	local parts: { BasePart } = table.create(count)
	local cframes: { CFrame } = table.create(count)
	local lx: { number } = table.create(count)
	local lz: { number } = table.create(count)
	local size = Vector3.new(cellSize * OVERSIZE, THICKNESS, cellSize * OVERSIZE)
	for i = 0, cells - 1 do
		for j = 0, cells - 1 do
			local part = Instance.new("Part")
			part.Name = "OceanTile"
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Color = OceanPalette.colours[OceanPalette.SEA_BUCKET]
			part.Size = size
			part.Parent = parent
			table.insert(parts, part)
			table.insert(cframes, CFrame.identity)
			table.insert(lx, (i + 0.5) * cellSize - half)
			table.insert(lz, (j + 0.5) * cellSize - half)
		end
	end
	return {
		parts = parts,
		cframes = cframes,
		lx = lx,
		lz = lz,
		bucket = table.create(count, OceanPalette.SEA_BUCKET),
		count = count,
		half = half,
	}
end

-- gradientAt(x, z) -> (worldY, dY/dX, dY/dZ)
function PartGrid.update(
	grid: PartGrid,
	cx: number,
	cz: number,
	seaLevel: number,
	gradientAt: (number, number) -> (number, number, number)
)
	local cframes, parts, bucket = grid.cframes, grid.parts, grid.bucket
	local colours = OceanPalette.colours
	for n = 1, grid.count do
		local x, z = cx + grid.lx[n], cz + grid.lz[n]
		local y, gx, gz = gradientAt(x, z)
		local tangent = Vector3.new(1, gx, 0).Unit
		local normal = Vector3.new(-gx, 1, -gz).Unit
		-- Top face on the surface: centre half a tile thickness below it, along the normal.
		cframes[n] =
			CFrame.fromMatrix(Vector3.new(x, y, z) - normal * (THICKNESS / 2), tangent, normal)
		local b = OceanPalette.bucketFor(y - seaLevel)
		if b ~= bucket[n] then
			bucket[n] = b
			parts[n].Color = colours[b]
		end
	end
	Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function PartGrid.destroy(grid: PartGrid)
	for _, part in grid.parts do
		part:Destroy()
	end
	table.clear(grid.parts)
end

return PartGrid
