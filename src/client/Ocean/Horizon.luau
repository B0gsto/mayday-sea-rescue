--!strict
-- Horizon: the far sea from the edge of the SurfaceAppearance far plane out to ~4200 studs
-- (ocean spike round 2). There is no hard horizon line: the sea colour fades from the water tint
-- to the Atmosphere haze colour with distance, and desaturates as it goes.
--
-- Shape: 2 rings x 32 sectors (one MeshPart each, every part under the 2048-stud cap). The inner
-- ring's inner edge follows the far plane's outer square exactly (half INNER_HALF), so nothing
-- overlaps and nothing z-fights; the outer edge is a circle. Sector edges share exact positions,
-- and the outer ring tucks a little under the inner one, so there are no cracks.
-- The parts carry no SurfaceAppearance (so per-vertex colours work): colour per vertex is
--   lerp(tint, haze, smoothstep(0, 1, (r - rInner) / (FADE_END - rInner)))
-- and is rewritten only when the tint or haze colour changes (WeatherController's 10 Hz blend).
-- Moving it is 64 CFrame writes per grid snap, never per frame.

local AssetService = game:GetService("AssetService")

local Horizon = {}

Horizon.INNER_HALF = 700 -- studs; the far plane reaches exactly this square -- tune
local MID_RADIUS = 2400
local OUTER_RADIUS = 4200
local FADE_END = 2600 -- fully haze-coloured from here -- tune
local SECTORS = 32 -- a multiple of 8 so the square's corners fall on sector edges
local ANGULAR_STEPS = 2
local RADIAL_STEPS = { 8, 4 }
local TUCK = 30 -- studs the outer ring starts inside the inner ring
local DROP = 0.15 -- same level as the far plane
local OUTER_DROP = 0.6 -- the outer ring sits a little lower where the two overlap

export type Horizon = {
	parts: { BasePart },
	offsets: { Vector3 },
	meshes: { EditableMesh },
	colourIds: { { number } }, -- per mesh: colour ids
	fades: { { number } }, -- per mesh: fade 0..1 per colour id
	tint: Color3,
	haze: Color3,
	seaLevel: number,
}

local function smoothstep(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function innerRadius(angle: number): number
	local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
	return Horizon.INNER_HALF / math.max(c, s)
end

-- Desaturated, haze-weighted colour for a fade value.
local function colourAt(tint: Color3, haze: Color3, f: number): Color3
	local grey = (tint.R + tint.G + tint.B) / 3
	local flat = tint:Lerp(Color3.new(grey, grey, grey), 0.5 * f)
	return flat:Lerp(haze, f)
end

local function buildSector(
	ring: number,
	a0: number,
	a1: number
): (BasePart?, EditableMesh?, { number }, { number }, Vector3)
	local rows = RADIAL_STEPS[ring]
	-- Vertex positions in world-offset space first, to find the bounds centre.
	local pts: { Vector3 } = {}
	local fade: { number } = {}
	for i = 0, ANGULAR_STEPS do
		local a = a0 + (a1 - a0) * i / ANGULAR_STEPS
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local rIn = innerRadius(a)
		local r0 = if ring == 1 then rIn else MID_RADIUS - TUCK
		local r1 = if ring == 1 then MID_RADIUS else OUTER_RADIUS
		for j = 0, rows do
			local s = j / rows
			-- Denser rows near the inner edge, where the colour changes fastest.
			local r = r0 + (r1 - r0) * s * s
			table.insert(pts, dir * r)
			table.insert(fade, smoothstep((r - rIn) / (FADE_END - rIn)))
		end
	end
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, p in pts do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local y = if ring == 1 then -DROP else -OUTER_DROP
	local centre = Vector3.new((minX + maxX) / 2, y, (minZ + maxZ) / 2)
	local colourIds: { number } = {}
	local ok, result = pcall(function()
		local em = AssetService:CreateEditableMesh()
		local up = em:AddNormal(Vector3.yAxis)
		local v: { number } = {}
		for n, p in pts do
			v[n] = em:AddVertex(Vector3.new(p.X - centre.X, 0, p.Z - centre.Z))
			colourIds[n] = em:AddColor(Color3.new(1, 1, 1), 1)
		end
		local stride = rows + 1
		for i = 0, ANGULAR_STEPS - 1 do
			for j = 0, rows - 1 do
				local a = i * stride + j + 1
				local b = a + 1
				local c = a + stride
				local d = c + 1
				for _, tri in { { a, b, c }, { b, d, c } } do
					local f = em:AddTriangle(v[tri[1]], v[tri[2]], v[tri[3]])
					em:SetFaceNormals(f, { up, up, up })
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
		local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		return { part = part, em = em }
	end)
	if not ok then
		warn(`[Ocean] horizon sector unavailable ({result})`)
		return nil, nil, {}, {}, centre
	end
	local part: BasePart = result.part
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.new(1, 1, 1)
	return part, result.em, colourIds, fade, centre
end

function Horizon.new(parent: Instance, seaLevel: number, tint: Color3, haze: Color3): Horizon
	local h: Horizon = {
		parts = {},
		offsets = {},
		meshes = {},
		colourIds = {},
		fades = {},
		tint = tint,
		haze = haze,
		seaLevel = seaLevel,
	}
	local step = 2 * math.pi / SECTORS
	for ring = 1, 2 do
		for s = 0, SECTORS - 1 do
			local part, em, ids, fade, centre = buildSector(ring, s * step, (s + 1) * step)
			if part and em then
				part.Name = `OceanHorizon{ring}_{s}`
				part.CFrame = CFrame.new(centre + Vector3.new(0, seaLevel, 0))
				part.Parent = parent
				table.insert(h.parts, part)
				table.insert(h.offsets, centre)
				table.insert(h.meshes, em)
				table.insert(h.colourIds, ids)
				table.insert(h.fades, fade)
			end
		end
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
end

function Horizon.moveTo(h: Horizon, cx: number, cz: number)
	local base = Vector3.new(cx, h.seaLevel, cz)
	for n, part in h.parts do
		part.CFrame = CFrame.new(base + h.offsets[n])
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
	table.clear(h.meshes)
end

return Horizon
