--!strict
-- FarPlane: flat sea from the edge of the wave rings out towards the horizon.
-- Ocean spike: each strip is a 4-vertex EditableMesh MeshPart with the same SurfaceAppearance as
-- the wave mesh (OceanSurface) and world-locked UVs, so the ripple normal map and its specular
-- glitter carry on to the horizon. Falls back to plain Parts if EditableMesh fails (memory budget,
-- permissions): after the first failed strip the rest skip EditableMesh, and it is warned once.
-- Four thin Parts in a pinwheel around a square hole, so the plane never shows through wave
-- troughs inside the rings. Parts are capped at 2048 studs per axis, so each strip is at most
-- 2048 long and the plane reaches (2048 - innerHalf) studs from the camera; Atmosphere haze
-- (stream D lighting) should hide the edge. Moving it is 4 CFrame writes per snap (not per frame).

local AssetService = game:GetService("AssetService")
local MaterialService = game:GetService("MaterialService")

local MeshGrid = require(script.Parent.MeshGrid)
local OceanPalette = require(script.Parent.OceanPalette)
local OceanSurface = require(script.Parent.OceanSurface)

local MAX_PART = 2048
local OVERLAP = 4 -- studs the plane tucks under the flat outer edge of the ring -- tune
local DROP = 0.15 -- top surface sits this far below sea level to avoid z-fighting -- tune
local THICKNESS = 1
local CORNER_DROP = 1.35 -- corner tiles sit at the horizon skirt depth, under the bands

local warned = false

export type FarPlane = {
	parts: { BasePart },
	offsets: { Vector3 },
	caps: { BasePart }, -- Parts mode: the four corner tiles shown instead of the strips for a high camera
	meshes: { EditableMesh },
	uvs: { { number } }, -- per strip: uv id, local x, local z (x3) per vertex, flattened
	uvU: number,
	uvV: number,
	seaLevel: number,
}

local FarPlane = {}

function FarPlane.new(
	parent: Instance,
	innerHalf: number,
	seaLevel: number,
	surface: string,
	reach: number?, -- half-size of the square the plane fills (default: as far as parts allow)
	withMesh: boolean? -- false: plain Parts in the Part grid's material, so the Parts-mode sea is one material
): FarPlane
	local r = math.max(innerHalf - OVERLAP, 1)
	local width = math.min(MAX_PART - 2 * r, (reach or math.huge) - r)
	local length = 2 * r + width -- <= MAX_PART
	local y = -DROP
	-- Pinwheel: each strip covers one side plus one corner.
	local layout = {
		{
			size = Vector3.new(length, THICKNESS, width),
			offset = Vector3.new(width / 2, y, -r - width / 2),
		},
		{
			size = Vector3.new(width, THICKNESS, length),
			offset = Vector3.new(r + width / 2, y, width / 2),
		},
		{
			size = Vector3.new(length, THICKNESS, width),
			offset = Vector3.new(-width / 2, y, r + width / 2),
		},
		{
			size = Vector3.new(width, THICKNESS, length),
			offset = Vector3.new(-r - width / 2, y, -width / 2),
		},
	}
	local parts: { BasePart } = {}
	local offsets: { Vector3 } = {}
	local meshes: { EditableMesh } = {}
	local uvs: { { number } } = {}
	local useMesh = withMesh ~= false
	local function add(name: string, size: Vector3, offset: Vector3): BasePart
		local part, em, uv = FarPlane._strip(size, offset, surface, useMesh)
		useMesh = em ~= nil
		part.Name = name
		part.CFrame = CFrame.new(offset + Vector3.new(0, seaLevel, 0))
		part.Parent = parent
		table.insert(parts, part)
		table.insert(offsets, offset)
		if em then
			table.insert(meshes, em)
			table.insert(uvs, uv)
		end
		return part
	end
	for n, entry in layout do
		add(`OceanFar{n}`, entry.size, entry.offset)
	end
	-- Parts mode, high camera (setCap): four MAX_PART tiles meeting under the camera replace the strips and the
	-- Part grid. At reduced graphics quality (phones, Automatic) the engine culls every part whose nearest point is
	-- past its draw distance, so from the air the horizon bands (nearest 700+ studs away) vanished into a square
	-- edge with sky behind; these tiles' nearest point is straight down, so they draw out to +-MAX_PART whenever
	-- anything below draws. That quality level also lights a big glossy quad at its corners only: a strip corner
	-- next to the sun glint washed the whole strip white. These tiles' corners stay far from the glint (it lies
	-- ~0.7 x camera height sunward, the shared corner is under the camera).
	local caps: { BasePart } = {}
	if withMesh == false then
		for i = -1, 1, 2 do
			for j = -1, 1, 2 do
				local offset = Vector3.new(i * MAX_PART / 2, -CORNER_DROP, j * MAX_PART / 2)
				local part =
					add("OceanFarCorner", Vector3.new(MAX_PART, THICKNESS, MAX_PART), offset)
				part.LocalTransparencyModifier = 1
				table.insert(caps, part)
			end
		end
	end
	return {
		parts = parts,
		offsets = offsets,
		caps = caps,
		seaLevel = seaLevel,
		meshes = meshes,
		uvs = uvs,
		uvU = 0 / 0,
		uvV = 0 / 0,
	}
end

-- One flat strip: a quad MeshPart (vertices at local y 0, bounds pinned to +-1 so the part centre is
-- the water plane) with the ocean SurfaceAppearance, or a plain Part if EditableMesh fails.
function FarPlane._strip(
	size: Vector3,
	offset: Vector3,
	surface: string,
	useMesh: boolean?
): (BasePart, EditableMesh?, { number })
	local hx, hz = size.X / 2, size.Z / 2
	local uv: { number } = {}
	local made: EditableMesh? = nil
	local ok, result = pcall(function()
		if useMesh == false then
			error("skipped after an earlier failure")
		end
		local em = AssetService:CreateEditableMesh()
		if em == nil then
			error("CreateEditableMesh returned nil (memory budget?)")
		end
		made = em
		local corners = {
			Vector3.new(-hx, 0, -hz),
			Vector3.new(hx, 0, -hz),
			Vector3.new(-hx, 0, hz),
			Vector3.new(hx, 0, hz),
		}
		local v, u = {}, {}
		local up = em:AddNormal(Vector3.yAxis)
		for i, c in corners do
			v[i] = em:AddVertex(c)
			u[i] = em:AddUV(Vector2.zero)
			table.insert(uv, u[i])
			table.insert(uv, offset.X + c.X)
			table.insert(uv, offset.Z + c.Z)
		end
		for _, tri in { { 1, 3, 2 }, { 2, 3, 4 } } do
			local f = em:AddTriangle(v[tri[1]], v[tri[2]], v[tri[3]])
			em:SetFaceUVs(f, { u[tri[1]], u[tri[2]], u[tri[3]] })
			em:SetFaceNormals(f, { up, up, up })
		end
		for _, p in { Vector3.new(-hx, -1, -hz), Vector3.new(hx - 0.01, 1, hz - 0.01) } do
			em:AddTriangle(
				em:AddVertex(p),
				em:AddVertex(p + Vector3.xAxis * 0.01),
				em:AddVertex(p + Vector3.zAxis * 0.01)
			)
		end
		local fixed, _, _, umap = MeshGrid.toFixed(em) -- see MeshGrid.toFixed: the client's memory budget
		if fixed then
			em:Destroy()
			em = fixed
			made = fixed
			for i = 1, #uv, 3 do
				uv[i] = umap[uv[i]]
			end
		end
		-- Precise, as MeshGrid: no LOD decimation of the flat sheet
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
		if part == nil then
			error("CreateMeshPartAsync returned nil")
		end
		return { part = part, em = em }
	end)
	local part: BasePart
	local em: EditableMesh? = nil
	if ok then
		part = result.part
		em = result.em
		OceanSurface.attach(part, surface)
	else
		if made then
			made:Destroy()
		end
		if not warned and useMesh ~= false then
			warned = true
			warn(`[Ocean] far plane mesh unavailable ({result}); flat Parts`)
		end
		local p = Instance.new("Part")
		p.Size = Vector3.new(size.X, 0.2, size.Z)
		p.Material = Enum.Material.SmoothPlastic
		p.MaterialVariant = "OceanWater" -- PartGrid's water normal map (plain plastic if absent)
		p.Color = OceanPalette.colours[OceanPalette.SEA_BUCKET]
		-- As PartGrid: no Reflectance on top of the variant, or the far sea mirrors the sky brighter than the near
		p.Reflectance = if MaterialService:FindFirstChild(p.MaterialVariant) then 0 else 0.05 -- tune
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		part = p
		table.clear(uv)
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part, em, uv
end

-- World-locked UVs: ou/ov are the grid centre's offset in studs (same as MeshGrid.apply).
function FarPlane.setUV(plane: FarPlane, ou: number, ov: number)
	if ou == plane.uvU and ov == plane.uvV then
		return
	end
	plane.uvU, plane.uvV = ou, ov
	local inv = 1 / OceanSurface.TILE_STUDS
	for m, em in plane.meshes do
		local uv = plane.uvs[m]
		for i = 1, #uv, 3 do
			em:SetUV(uv[i], Vector2.new((uv[i + 1] + ou) * inv, (uv[i + 2] + ov) * inv))
		end
	end
end

function FarPlane.setSurface(plane: FarPlane, kind: string)
	for _, part in plane.parts do
		if part:IsA("MeshPart") then
			OceanSurface.attach(part, kind)
		end
	end
end

-- Parts mode, high camera: the corner tiles instead of the strips (the caller hides the Part grid)
function FarPlane.setCap(plane: FarPlane, on: boolean)
	if #plane.caps == 0 then
		return
	end
	for _, part in plane.parts do
		local cap = table.find(plane.caps, part) ~= nil
		part.LocalTransparencyModifier = if cap == on then 0 else 1
	end
end

function FarPlane.moveTo(plane: FarPlane, cx: number, cz: number)
	local base = Vector3.new(cx, plane.seaLevel, cz)
	for n, part in plane.parts do
		part.CFrame = CFrame.new(base + plane.offsets[n])
	end
end

function FarPlane.destroy(plane: FarPlane)
	for _, part in plane.parts do
		part:Destroy()
	end
	for _, em in plane.meshes do
		em:Destroy()
	end
	table.clear(plane.parts)
	table.clear(plane.meshes)
end

return FarPlane
