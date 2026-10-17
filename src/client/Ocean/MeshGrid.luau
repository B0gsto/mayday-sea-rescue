--!strict
-- MeshGrid: one square EditableMesh lattice (optionally with a square hole in the middle) shown
-- through a MeshPart. The controller writes world heights into grid.heights, then calls apply().
--
-- API used (current Roblox EditableMesh API, 2024+ "new" API):
--   AssetService:CreateEditableMesh()                     -> EditableMesh (may be nil / error)
--   em:AddVertex / AddTriangle / AddColor / AddNormal / SetFaceColors / SetFaceNormals
--   AssetService:CreateMeshPartAsync(Content.fromObject(em), options) -> MeshPart (yields)
--   em:SetPosition / SetColor each update; the linked MeshPart re-renders automatically.
-- Everything that can fail is pcall'd; new() returns nil plus a reason so the caller can fall back.
--
-- Bounds: a MeshPart scales its mesh to fit Part.Size, so if the vertex bounds changed as waves
-- moved, the whole mesh would visibly rescale. Two sub-millimetre "anchor" triangles pin the
-- bounding box at (+-half, +-BOUNDS_Y, +-half) for the mesh's lifetime, and heights are clamped
-- inside it. The box is symmetric, so mesh-local origin == part position.

local AssetService = game:GetService("AssetService")

local OceanPalette = require(script.Parent.OceanPalette)

local BOUNDS_Y = 10 -- studs above and below sea level; storm crests are about 3.4 -- tune
local CLAMP_Y = BOUNDS_Y - 0.1
local ANCHOR_SIZE = 0.01

export type Grid = {
	em: EditableMesh,
	part: MeshPart,
	count: number,
	cells: number,
	cellSize: number,
	half: number, -- half width in studs
	lx: { number }, -- local X per vertex
	lz: { number }, -- local Z per vertex
	vid: { number }, -- EditableMesh vertex id per vertex
	cid: { number }, -- EditableMesh colour id per vertex (empty when colours are unsupported)
	bucket: { number }, -- current palette bucket per vertex
	heights: { number }, -- world Y per vertex, written by the caller before apply()
	index: { number }, -- lattice key i * (cells + 1) + j + 1 -> vertex index (0 when in the hole)
	hasColours: boolean,
}

local MeshGrid = {}

function MeshGrid.latticeKey(grid: Grid, i: number, j: number): number
	return i * (grid.cells + 1) + j + 1
end

-- cells: lattice width in cells; holeCells: hole width in cells (0 = none, same parity as cells).
function MeshGrid.new(
	name: string,
	parent: Instance,
	cells: number,
	cellSize: number,
	holeCells: number
): (Grid?, string?)
	local okCreate, emOrErr = pcall(function()
		return AssetService:CreateEditableMesh()
	end)
	if not okCreate or emOrErr == nil then
		return nil, `CreateEditableMesh failed: {emOrErr}`
	end
	local em = emOrErr :: EditableMesh

	local half = cells * cellSize / 2
	local h0 = (cells - holeCells) / 2
	local h1 = h0 + holeCells
	local function inHoleVertex(i: number, j: number): boolean
		return holeCells > 0 and i > h0 and i < h1 and j > h0 and j < h1
	end
	local function inHoleCell(i: number, j: number): boolean
		return holeCells > 0 and i >= h0 and i < h1 and j >= h0 and j < h1
	end

	local side = cells + 1
	local lx: { number } = {}
	local lz: { number } = {}
	local vid: { number } = {}
	local cid: { number } = {}
	local nid: { number } = {}
	local index: { number } = table.create(side * side, 0)
	local hasColours = true
	local hasNormals = true
	local teal = OceanPalette.colours[OceanPalette.SEA_BUCKET]

	local okBuild, buildErr = pcall(function()
		for i = 0, cells do
			for j = 0, cells do
				if not inHoleVertex(i, j) then
					local x, z = i * cellSize - half, j * cellSize - half
					table.insert(lx, x)
					table.insert(lz, z)
					table.insert(vid, em:AddVertex(Vector3.new(x, 0, z)))
					index[i * side + j + 1] = #vid
				end
			end
		end
		-- Optional attributes: per-vertex colour and auto-computed normals.
		local okColours = pcall(function()
			for n = 1, #vid do
				cid[n] = em:AddColor(teal, 1)
			end
		end)
		hasColours = okColours and #cid == #vid
		local okNormals = pcall(function()
			for n = 1, #vid do
				nid[n] = em:AddNormal() -- no argument: computed by the engine as vertices move
			end
		end)
		hasNormals = okNormals and #nid == #vid

		local function triangle(a: number, b: number, c: number)
			local face = em:AddTriangle(vid[a], vid[b], vid[c])
			if hasColours then
				hasColours = pcall(em.SetFaceColors, em, face, { cid[a], cid[b], cid[c] })
			end
			if hasNormals then
				hasNormals = pcall(em.SetFaceNormals, em, face, { nid[a], nid[b], nid[c] })
			end
		end
		for i = 0, cells - 1 do
			for j = 0, cells - 1 do
				if not inHoleCell(i, j) then
					local v00 = index[i * side + j + 1]
					local v10 = index[(i + 1) * side + j + 1]
					local v01 = index[i * side + j + 2]
					local v11 = index[(i + 1) * side + j + 2]
					-- Winding gives a +Y face normal (right-hand rule). If the sea is invisible
					-- from above in Studio, swap the last two vertices of both triangles.
					triangle(v00, v01, v10)
					triangle(v10, v01, v11)
				end
			end
		end

		-- Bounds anchors (see header): tiny triangles at the two opposite corners of the box.
		local function anchor(p: Vector3)
			local a = em:AddVertex(p)
			local b = em:AddVertex(p + Vector3.new(ANCHOR_SIZE, 0, 0))
			local c = em:AddVertex(p + Vector3.new(0, 0, ANCHOR_SIZE))
			em:AddTriangle(a, b, c)
		end
		anchor(Vector3.new(-half, -BOUNDS_Y, -half))
		anchor(Vector3.new(half - ANCHOR_SIZE, BOUNDS_Y, half - ANCHOR_SIZE))
	end)
	if not okBuild then
		em:Destroy()
		return nil, `building the grid failed: {buildErr}`
	end
	if not hasColours then
		warn("[Ocean] EditableMesh vertex colours unavailable; using flat Deep Teal")
	end

	local okPart, partOrErr = pcall(function()
		local content = Content.fromObject(em)
		local okOpts, withOpts = pcall(function()
			return AssetService:CreateMeshPartAsync(content, {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Precise,
			})
		end)
		if okOpts and withOpts then
			return withOpts
		end
		return AssetService:CreateMeshPartAsync(content)
	end)
	if not okPart or partOrErr == nil then
		em:Destroy()
		return nil, `CreateMeshPartAsync failed: {partOrErr}`
	end
	local part = partOrErr :: MeshPart
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	-- Vertex colours multiply the part colour, so keep it white when they work.
	part.Color = if hasColours then Color3.new(1, 1, 1) else OceanPalette.DEEP_TEAL
	part.Reflectance = 0.05 -- tune
	part.CFrame = CFrame.identity
	part.Parent = parent

	local count = #vid
	return {
		em = em,
		part = part,
		count = count,
		cells = cells,
		cellSize = cellSize,
		half = half,
		lx = lx,
		lz = lz,
		vid = vid,
		cid = if hasColours then cid else {},
		bucket = table.create(count, OceanPalette.SEA_BUCKET),
		heights = table.create(count, 0),
		index = index,
		hasColours = hasColours,
	},
		nil
end

-- Pushes grid.heights (world Y, sea level is part Y) into the mesh. Allocation-free:
-- one SetPosition per vertex, one SetColor only when a vertex changes palette bucket.
-- Cost at High: about 1665 SetPosition calls per frame across both rings (budget ~0.5 ms).
function MeshGrid.apply(grid: Grid, seaLevel: number)
	local em, vid, lx, lz, heights = grid.em, grid.vid, grid.lx, grid.lz, grid.heights
	local colours = OceanPalette.colours
	local bucketFor = OceanPalette.bucketFor
	local hasColours, cid, bucket = grid.hasColours, grid.cid, grid.bucket
	for n = 1, grid.count do
		local y = math.clamp(heights[n] - seaLevel, -CLAMP_Y, CLAMP_Y)
		em:SetPosition(vid[n], Vector3.new(lx[n], y, lz[n]))
		if hasColours then
			local b = bucketFor(y)
			if b ~= bucket[n] then
				bucket[n] = b
				em:SetColor(cid[n], colours[b])
			end
		end
	end
end

function MeshGrid.destroy(grid: Grid)
	grid.part:Destroy()
	grid.em:Destroy()
end

return MeshGrid
