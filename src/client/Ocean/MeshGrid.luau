--!strict
-- MeshGrid: one square EditableMesh lattice (optionally with a square hole in the middle) shown
-- through a MeshPart. The controller writes world heights and slopes into grid.heights / gx / gz,
-- then calls apply().
--
-- Look (ocean spike, round 1): the MeshPart carries a SurfaceAppearance (OceanSurface) with a
-- tiling FFT chop normal map, low roughness and a tinted albedo; the probe showed that
-- SurfaceAppearance renders on EditableMesh MeshParts but ignores EditableMesh vertex colours, so
-- colour is a per-preset tint (SurfaceAppearance.Color), not per vertex. Per-vertex normals are
-- written explicitly from the analytic wave gradient so the swell shades smoothly under Future
-- lighting (no faceting from engine-computed normals). UVs are world-locked: u = (x + ou) / TILE.
--
-- API used (current Roblox EditableMesh API):
--   AssetService:CreateEditableMesh(), em:AddVertex / AddTriangle / AddNormal / AddUV /
--   SetFaceNormals / SetFaceUVs, AssetService:CreateMeshPartAsync(Content.fromObject(em)),
--   em:SetPosition / SetNormal / SetUV each update.
-- Everything that can fail is pcall'd; new() returns nil plus a reason so the caller can fall back.
--
-- Bounds: a MeshPart scales its mesh to fit Part.Size, so two sub-millimetre "anchor" triangles pin
-- the bounding box at (+-half, +-BOUNDS_Y, +-half) and heights are clamped inside it.

local AssetService = game:GetService("AssetService")

local OceanSurface = require(script.Parent.OceanSurface)

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
	nid: { number }, -- EditableMesh normal id per vertex (empty when normals are unsupported)
	uid: { number }, -- EditableMesh UV id per vertex (empty when UVs are unsupported)
	heights: { number }, -- world Y per vertex, written by the caller before apply()
	gx: { number }, -- dY/dX per vertex, written by the caller before apply()
	gz: { number }, -- dY/dZ per vertex
	index: { number }, -- lattice key i * (cells + 1) + j + 1 -> vertex index (0 when in the hole)
	uvU: number, -- current UV offset (studs), NaN until first apply
	uvV: number,
}

local MeshGrid = {}

local fixedWarned = false
local function warnFixed(why: string)
	if not fixedWarned then
		fixedWarned = true
		warn(`[Ocean] fixed-size EditableMesh unavailable ({why}); growable meshes`)
	end
end

-- The client gives EditableMesh a small memory budget (Studio's is unlimited) and an empty, growable
-- mesh reserves it as if it were full: the v64 real client ran out after ~6 ocean meshes. A fixed-size
-- copy costs only what it holds and still takes SetPosition / SetNormal / SetUV. Returns the copy plus
-- old -> new id maps for vertices, normals and UVs, or nil (the caller keeps the growable mesh).
function MeshGrid.toFixed(em: EditableMesh): (EditableMesh?, { [number]: number }, { [number]: number }, {
	[number]: number,
})
	local vmap, nmap, umap = {}, {}, {}
	local okCopy, copy = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
	end)
	if not okCopy or copy == nil then
		warnFixed(`copy failed: {copy}`)
		return nil, vmap, nmap, umap
	end
	local fixed = copy :: EditableMesh
	-- ids are not guaranteed to survive the copy: map them by order, checking every value matches
	local okMap, mapErr = pcall(function()
		local function map(
			into: { [number]: number },
			src: { number },
			dst: { number },
			get: (number, number) -> any
		)
			assert(#src == #dst, "count changed")
			for k, id in src do
				local a, b = get(1, id), get(2, dst[k])
				local d = a - b
				assert(
					(if typeof(d) == "Vector3" then d.Magnitude else d.Magnitude) < 1e-3,
					"value changed"
				)
				into[id] = dst[k]
			end
		end
		local both = { em, fixed }
		map(vmap, em:GetVertices(), fixed:GetVertices(), function(m, id)
			return both[m]:GetPosition(id)
		end)
		map(nmap, em:GetNormals(), fixed:GetNormals(), function(m, id)
			return both[m]:GetNormal(id)
		end)
		map(umap, em:GetUVs(), fixed:GetUVs(), function(m, id)
			return both[m]:GetUV(id)
		end)
	end)
	if not okMap or not fixed.FixedSize then
		warnFixed(if okMap then "copy not fixed-size" else `ids: {mapErr}`)
		fixed:Destroy()
		return nil, vmap, nmap, umap
	end
	return fixed, vmap, nmap, umap
end

function MeshGrid.latticeKey(grid: Grid, i: number, j: number): number
	return i * (grid.cells + 1) + j + 1
end

-- cells: lattice width in cells; holeCells: hole width in cells (0 = none, same parity as cells).
-- surface: OceanSurface kind for the SurfaceAppearance ("Calm" | "Storm" | "Foam").
function MeshGrid.new(
	name: string,
	parent: Instance,
	cells: number,
	cellSize: number,
	holeCells: number,
	surface: string,
	backFaces: boolean?
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
	local nid: { number } = {}
	local uid: { number } = {}
	local index: { number } = table.create(side * side, 0)
	local hasNormals = true
	local hasUVs = true
	local tile = OceanSurface.TILE_STUDS

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
		hasNormals = pcall(function()
			for n = 1, #vid do
				nid[n] = em:AddNormal(Vector3.yAxis)
			end
		end) and #nid == #vid
		-- The underside faces get their own static downward normal. Sharing the top surface's
		-- (upward) normals made every visible back face lit from behind, i.e. pure black: a large
		-- black patch of sea wherever the near patch's underside was in view (shore shot).
		local downNid: number? = nil
		if backFaces and hasNormals then
			local okDown, idOrErr = pcall(em.AddNormal, em, -Vector3.yAxis)
			downNid = if okDown then idOrErr else nil
		end
		hasUVs = pcall(function()
			for n = 1, #vid do
				uid[n] = em:AddUV(Vector2.new(lx[n] / tile, lz[n] / tile))
			end
		end) and #uid == #vid

		local function triangle(a: number, b: number, c: number, under: boolean?)
			local face = em:AddTriangle(vid[a], vid[b], vid[c])
			if under and downNid then
				pcall(em.SetFaceNormals, em, face, { downNid, downNid, downNid })
			elseif hasNormals and not under then
				hasNormals = pcall(em.SetFaceNormals, em, face, { nid[a], nid[b], nid[c] })
			end
			if hasUVs then
				hasUVs = pcall(em.SetFaceUVs, em, face, { uid[a], uid[b], uid[c] })
			end
		end
		for i = 0, cells - 1 do
			for j = 0, cells - 1 do
				if not inHoleCell(i, j) then
					local v00 = index[i * side + j + 1]
					local v10 = index[(i + 1) * side + j + 1]
					local v01 = index[i * side + j + 2]
					local v11 = index[(i + 1) * side + j + 2]
					triangle(v00, v01, v10)
					triangle(v10, v01, v11)
					if backFaces then
						-- Underside, so the surface is visible from below (underwater view).
						triangle(v00, v10, v01, true)
						triangle(v10, v11, v01, true)
					end
				end
			end
		end

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
	if not hasNormals then
		warn("[Ocean] EditableMesh normals unavailable; engine normals")
	end
	if not hasUVs then
		warn("[Ocean] EditableMesh UVs unavailable; the ripple normal map will not tile")
	end

	local fixed, vmap, nmap, umap = MeshGrid.toFixed(em)
	if fixed then
		em:Destroy()
		em = fixed
		for n = 1, #vid do
			vid[n] = vmap[vid[n]]
			if hasNormals then
				nid[n] = nmap[nid[n]]
			end
			if hasUVs then
				uid[n] = umap[uid[n]]
			end
		end
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
	part.CFrame = CFrame.identity
	OceanSurface.attach(part, surface)
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
		nid = if hasNormals then nid else {},
		uid = if hasUVs then uid else {},
		heights = table.create(count, 0),
		gx = table.create(count, 0),
		gz = table.create(count, 0),
		index = index,
		uvU = 0 / 0,
		uvV = 0 / 0,
	},
		nil
end

-- Pushes grid.heights (world Y; sea level is part Y) and slopes into the mesh, and moves the UVs
-- when the world-locked offset (ou, ov) changes (grid snap or ripple drift). Allocation-free.
-- lift: optional per-vertex lift table (foam overlay), nil for the water surface.
function MeshGrid.apply(grid: Grid, seaLevel: number, ou: number, ov: number, lift: { number }?)
	local em, vid, lx, lz, heights = grid.em, grid.vid, grid.lx, grid.lz, grid.heights
	local nid, gx, gz = grid.nid, grid.gx, grid.gz
	local hasNormals = #nid > 0
	for n = 1, grid.count do
		local y = heights[n] - seaLevel
		if lift then
			y += lift[n]
		end
		em:SetPosition(vid[n], Vector3.new(lx[n], math.clamp(y, -CLAMP_Y, CLAMP_Y), lz[n]))
		if hasNormals then
			local sx, sz = gx[n], gz[n]
			local inv = 1 / math.sqrt(sx * sx + 1 + sz * sz)
			em:SetNormal(nid[n], Vector3.new(-sx * inv, inv, -sz * inv))
		end
	end
	local uid = grid.uid
	if #uid > 0 and (ou ~= grid.uvU or ov ~= grid.uvV) then
		grid.uvU, grid.uvV = ou, ov
		local inv = 1 / OceanSurface.TILE_STUDS
		for n = 1, grid.count do
			em:SetUV(uid[n], Vector2.new((lx[n] + ou) * inv, (lz[n] + ov) * inv))
		end
	end
end

function MeshGrid.destroy(grid: Grid)
	grid.part:Destroy()
	grid.em:Destroy()
end

return MeshGrid
