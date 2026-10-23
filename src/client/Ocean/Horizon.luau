--!strict
-- Horizon: the far sea from the edge of the SurfaceAppearance far plane out to ~4200 studs
-- (ocean spike round 2). There is no hard horizon line: the sea colour fades from the water tint
-- to the Atmosphere haze colour with distance, and desaturates as it goes.
--
-- Shape: an inner ring (from the far plane's outer square, half INNER_HALF, to MID_RADIUS) and an
-- outer ring (MID_RADIUS - TUCK to OUTER_RADIUS, a little lower so the overlap never z-fights).
-- EditableMesh memory budget (round 5): the ring is built from only 3 shared template meshes,
-- each shown by several rotated MeshParts that all reference the same EditableMesh:
--   inner ring: two octant templates (0..45 and 45..90 degrees, mirror images, which a rotation
--               cannot produce), 4 copies each rotated by 90 degrees (the square edge repeats)
--   outer ring: one 22.5 degree sector template, 16 copies (the ring is round)
-- 3 EditableMeshes / 205 vertices instead of 64 / 1728. Every part stays under the 2048-stud cap.
-- Both rings wear the far plane's SurfaceAppearance and tint (part.Color), so neither the 700 square nor
-- MID_RADIUS is a seam: a matte vertex-coloured sea next to the glossy one read as a straight line out at
-- sea, as a dark wall under an Overcast sky, and from the air as a pale disc edge. Atmosphere haze does the
-- fade to the horizon. (The vertex colours below only matter if the SurfaceAppearance template is missing.)
-- Fallback: if CreateEditableMesh / CreateMeshPartAsync fails (memory budget, permissions), the
-- horizon is a set of thin flat Parts in four square bands, each a flat fade colour; warned once.
-- Moving it is one CFrame write per part per grid snap, never per frame.

local AssetService = game:GetService("AssetService")

local OceanPalette = require(script.Parent.OceanPalette)
local OceanSurface = require(script.Parent.OceanSurface)

local Horizon = {}

Horizon.INNER_HALF = 700 -- studs; the far plane reaches exactly this square -- tune
local MID_RADIUS = 2400
local OUTER_RADIUS = 4200
local FADE_END = 2600 -- fully haze-coloured from here -- tune
local TUCK = 30 -- studs the outer ring starts inside the inner ring
local DROP = 0.15 -- same level as the far plane
local OUTER_DROP = 0.6 -- the outer ring sits a little lower where the two overlap
local FLAT_THICKNESS = 0.2
local MAX_PART = 2048
-- Fallback square bands (Chebyshev distance from the centre), inner to outer. -- tune
local FLAT_BANDS = { 700, 1200, 1800, 2600, OUTER_RADIUS }

type Template = {
	ring: number,
	a0: number, -- start angle (radians)
	a1: number, -- end angle
	steps: number, -- angular steps
	rows: number, -- radial steps
	copies: number,
	period: number, -- rotation between copies (radians)
}

local QUARTER = math.pi / 2
local TEMPLATES: { Template } = {
	{ ring = 1, a0 = 0, a1 = QUARTER / 2, steps = 8, rows = 8, copies = 4, period = QUARTER },
	{ ring = 1, a0 = QUARTER / 2, a1 = QUARTER, steps = 8, rows = 8, copies = 4, period = QUARTER },
	{ ring = 2, a0 = 0, a1 = math.pi / 8, steps = 4, rows = 4, copies = 16, period = math.pi / 8 },
}

export type Horizon = {
	parts: { BasePart }, -- mesh copies, or flat fallback parts
	offsets: { CFrame }, -- per part, relative to the grid centre at sea level
	meshes: { EditableMesh }, -- shared templates (empty in the flat fallback)
	surfaced: { BasePart }, -- inner ring copies: SurfaceAppearance, part.Color = tint
	colourIds: { { number } }, -- per mesh: colour ids
	fades: { { number } }, -- per mesh: fade 0..1 per colour id
	flatFades: { number }, -- per part, flat fallback only: fade 0..1 of the part's band
	tint: Color3,
	haze: Color3,
	seaLevel: number,
}

local warned = false

local function warnOnce(message: string)
	if not warned then
		warned = true
		warn(message)
	end
end

local function smoothstep(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function innerRadius(angle: number): number
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	return Horizon.INNER_HALF / math.max(c, s)
end

local function fadeAt(r: number, rIn: number): number
	return smoothstep((r - rIn) / (FADE_END - rIn))
end

-- Desaturated, haze-weighted colour for a fade value.
local function colourAt(tint: Color3, haze: Color3, f: number): Color3
	local grey = (tint.R + tint.G + tint.B) / 3
	local flat = tint:Lerp(Color3.new(grey, grey, grey), 0.5 * f)
	return flat:Lerp(haze, f)
end

local function configure(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
end

local function meshPart(content: Content): MeshPart?
	local okOpts, withOpts = pcall(function()
		return AssetService:CreateMeshPartAsync(content, {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise, -- as MeshGrid: no LOD decimation of the flat sheet
		})
	end)
	if okOpts and withOpts then
		return withOpts
	end
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(content)
	end)
	return if ok then part else nil
end

-- One template sector mesh. Returns the mesh, its colour ids and fades, and the local centre
-- (bounds centre at the water plane) the mesh vertices are relative to; or nil plus a reason.
local function buildTemplate(t: Template): (EditableMesh?, { number }, { number }, Vector3, string?)
	local rows = t.rows
	local pts: { Vector3 } = {}
	local fade: { number } = {}
	for i = 0, t.steps do
		local a = t.a0 + (t.a1 - t.a0) * i / t.steps
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rIn = innerRadius(a)
		local r0 = if t.ring == 1 then rIn else MID_RADIUS - TUCK
		local r1 = if t.ring == 1 then MID_RADIUS else OUTER_RADIUS
		local fadeIn = if t.ring == 1 then rIn else Horizon.INNER_HALF
		for j = 0, rows do
			local s = j / rows
			-- Denser rows near the inner edge, where the colour changes fastest.
			local r = r0 + (r1 - r0) * s * s
			table.insert(pts, dir * r)
			table.insert(fade, fadeAt(r, fadeIn))
		end
	end
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, p in pts do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local y = if t.ring == 1 then -DROP else -OUTER_DROP
	local centre = Vector3.new((minX + maxX) / 2, y, (minZ + maxZ) / 2)
	local colourIds: { number } = {}

	local okCreate, emOrErr = pcall(function()
		return AssetService:CreateEditableMesh()
	end)
	if not okCreate or emOrErr == nil then
		return nil, {}, {}, centre, `CreateEditableMesh failed: {emOrErr}`
	end
	local em = emOrErr :: EditableMesh
	local okBuild, buildErr = pcall(function()
		local up = em:AddNormal(Vector3.yAxis)
		local v: { number } = {}
		-- Tiled UVs so the inner ring's normal map mips down the way the far plane's does.
		local uvs: { number } = {}
		for n, p in pts do
			v[n] = em:AddVertex(Vector3.new(p.X - centre.X, 0, p.Z - centre.Z))
			uvs[n] = em:AddUV(Vector2.new(p.X, p.Z) / OceanSurface.TILE_STUDS)
			colourIds[n] = em:AddColor(Color3.new(1, 1, 1), 1)
		end
		local stride = rows + 1
		for i = 0, t.steps - 1 do
			for j = 0, rows - 1 do
				local a = i * stride + j + 1
				local b = a + 1
				local c = a + stride
				local d = c + 1
				-- Wound to face up (as FarPlane): {a, b, c} faced down and was back-face culled from above.
				for _, tri in { { a, c, b }, { b, c, d } } do
					local f = em:AddTriangle(v[tri[1]], v[tri[2]], v[tri[3]])
					em:SetFaceNormals(f, { up, up, up })
					em:SetFaceUVs(f, { uvs[tri[1]], uvs[tri[2]], uvs[tri[3]] })
					em:SetFaceColors(f, { colourIds[tri[1]], colourIds[tri[2]], colourIds[tri[3]] })
				end
			end
		end
		-- Pin the bounds so the part centre is the water plane (as FarPlane does).
		local lo = Vector3.new(minX - centre.X, -1, minZ - centre.Z)
		local hi = Vector3.new(maxX - centre.X - 0.01, 1, maxZ - centre.Z - 0.01)
		for _, p in { lo, hi } do
			em:AddTriangle(
				em:AddVertex(p),
				em:AddVertex(p + Vector3.xAxis * 0.01),
				em:AddVertex(p + Vector3.zAxis * 0.01)
			)
		end
	end)
	if not okBuild then
		em:Destroy()
		return nil, {}, {}, centre, `building the horizon mesh failed: {buildErr}`
	end
	return em, colourIds, fade, centre, nil
end

-- Mesh horizon: 3 shared EditableMeshes, 32 MeshParts. Returns false (and leaves h empty) on any
-- failure so the caller can use the flat fallback.
local function buildMeshes(h: Horizon, parent: Instance, surface: string): (boolean, string?)
	local made: { BasePart } = {}
	local function fail(reason: string?): (boolean, string?)
		for _, part in made do
			part:Destroy()
		end
		for _, em in h.meshes do
			em:Destroy()
		end
		table.clear(h.parts)
		table.clear(h.offsets)
		table.clear(h.meshes)
		table.clear(h.surfaced)
		table.clear(h.colourIds)
		table.clear(h.fades)
		return false, reason
	end
	for n, t in TEMPLATES do
		local em, ids, fade, centre, err = buildTemplate(t)
		if not em then
			return fail(err)
		end
		table.insert(h.meshes, em)
		table.insert(h.colourIds, ids)
		table.insert(h.fades, fade)
		local content = Content.fromObject(em)
		for k = 0, t.copies - 1 do
			local part = meshPart(content)
			if not part then
				return fail("CreateMeshPartAsync failed")
			end
			table.insert(made, part)
			configure(part)
			part.Color = Color3.new(1, 1, 1)
			-- Both rings glossy and tinted: a matte haze-faded outer ring read as a pale disc edge from the air.
			OceanSurface.attach(part, surface)
			table.insert(h.surfaced, part)
			part.Name = `OceanHorizon{n}_{k}`
			-- Rotate the copy about the grid centre: CFrame.Angles(0, -phi, 0) turns the angle
			-- a of (cos a, 0, sin a) into a + phi.
			local offset = CFrame.Angles(0, -k * t.period, 0) * CFrame.new(centre)
			table.insert(h.parts, part)
			table.insert(h.offsets, offset)
		end
	end
	for n, part in h.parts do
		part.CFrame = CFrame.new(0, h.seaLevel, 0) * h.offsets[n]
		part.Parent = parent
	end
	return true, nil
end

-- Flat fallback: each band is a square annulus laid out as a pinwheel of four strips (as
-- FarPlane), each strip cut into tiles under the part size cap.
local function buildFlat(h: Horizon, parent: Instance)
	local y = -DROP - FLAT_THICKNESS / 2
	for b = 1, #FLAT_BANDS - 1 do
		local d0, d1 = FLAT_BANDS[b], FLAT_BANDS[b + 1]
		local width = d1 - d0
		local length = d0 + d1
		local tiles = math.ceil(length / MAX_PART)
		local tileLength = length / tiles
		local fade = fadeAt((d0 + d1) / 2, Horizon.INNER_HALF)
		for k = 0, 3 do
			local rot = CFrame.Angles(0, -k * QUARTER, 0)
			for i = 0, tiles - 1 do
				local p = Instance.new("Part")
				p.Name = `OceanHorizonFlat{b}_{k}_{i}`
				p.Size = Vector3.new(tileLength, FLAT_THICKNESS, width)
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				configure(p)
				p.Color = OceanPalette.colours[OceanPalette.SEA_BUCKET]
				local local0 = Vector3.new(-d0 + (i + 0.5) * tileLength, y, -(d0 + d1) / 2)
				local offset = rot * CFrame.new(local0)
				p.CFrame = CFrame.new(0, h.seaLevel, 0) * offset
				p.Parent = parent
				table.insert(h.parts, p)
				table.insert(h.offsets, offset)
				table.insert(h.flatFades, fade)
			end
		end
	end
end

function Horizon.new(
	parent: Instance,
	seaLevel: number,
	tint: Color3,
	haze: Color3,
	surface: string
): Horizon
	local h: Horizon = {
		parts = {},
		offsets = {},
		meshes = {},
		surfaced = {},
		colourIds = {},
		fades = {},
		flatFades = {},
		tint = tint,
		haze = haze,
		seaLevel = seaLevel,
	}
	local ok = buildMeshes(h, parent, surface)
	if not ok then
		-- EditableMesh can be unavailable in Studio: the flat Part horizon is the shipped fallback
		warnOnce("[Ocean] horizon mesh unavailable; using the flat Part horizon")
		buildFlat(h, parent)
	end
	Horizon.setColours(h, tint, haze, true)
	return h
end

function Horizon.setColours(h: Horizon, tint: Color3, haze: Color3, force: boolean?)
	if not force and tint == h.tint and haze == h.haze then
		return
	end
	h.tint, h.haze = tint, haze
	for m, em in h.meshes do
		local ids, fade = h.colourIds[m], h.fades[m]
		for n, id in ids do
			em:SetColor(id, colourAt(tint, haze, fade[n]))
		end
	end
	for n, fade in h.flatFades do
		h.parts[n].Color = colourAt(tint, haze, fade)
	end
	for _, part in h.surfaced do
		part.Color = tint
	end
end

-- No-op, kept for OceanController. The old high-camera skirt (2048-stud tiles out to +/-12288) blanked the whole
-- view from a camera a few hundred studs up, even hidden: tiles out at +/-4096 already did, +/-2048 did not.
function Horizon.setHigh(_h: Horizon, _high: boolean) end

function Horizon.setSurface(h: Horizon, kind: string)
	for _, part in h.surfaced do
		OceanSurface.attach(part, kind)
	end
end

function Horizon.moveTo(h: Horizon, cx: number, cz: number)
	local base = CFrame.new(cx, h.seaLevel, cz)
	for n, part in h.parts do
		part.CFrame = base * h.offsets[n]
	end
end

function Horizon.destroy(h: Horizon)
	for _, part in h.parts do
		part:Destroy()
	end
	for _, em in h.meshes do
		em:Destroy()
	end
	table.clear(h.parts)
	table.clear(h.offsets)
	table.clear(h.meshes)
	table.clear(h.surfaced)
	table.clear(h.colourIds)
	table.clear(h.fades)
	table.clear(h.flatFades)
end

return Horizon
