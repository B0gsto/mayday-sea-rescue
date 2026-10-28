-- Z-fight scan: finds visible coplanar overlapping faces (the flicker the owner keeps spotting).
-- One command, during a Studio play test (Server sees every island; Client also sees client-built art):
--   python3 tools/studio/smoke.py lua Server tools/studio/zfight_scan.luau
--   (echo 'ZF_ARGS = { top = 60, skip = 30, root = "Docks" }'; cat tools/studio/zfight_scan.luau) \
--     | python3 tools/studio/smoke.py lua Server -        -- page through / scope to one folder of workspace
-- The same file is the module behind tests/ZFight.spec.luau (Lune: no `game`, so it returns the scanner).
-- A pair is reported when two box faces are coplanar (0.02 studs, normals parallel), overlap > 0.05 sq studs,
-- look different (colour, material, transparency, reflectance, textures on that face) and the overlap is not
-- covered: the point just outside one of the faces must be in the open (inside no opaque box). Glued contacts
-- (opposite normals, both opaque) are therefore covered and dropped. Same-face Texture/Decal stacks are flagged.
-- Shapes: Block = 6 faces; Wedge = its bottom + back; MeshPart / Union = bounding box (low confidence);
-- cylinders, balls, corner wedges, trusses are skipped.
local Scan = {}

local EPS_PLANE = 0.02
local MIN_AREA = 0.05
local OPEN = 0.04 -- how far outside a face the visibility probe sits
local CELL = 16 -- occluder grid

local function cellKey(x: number, y: number, z: number): number
	return ((x + 5000) * 10000 + (y + 5000)) * 10000 + (z + 5000) -- cells within +-80k studs
end

local FACES = {
	{ "Right", 1, 1 },
	{ "Left", 1, -1 },
	{ "Top", 2, 1 },
	{ "Bottom", 2, -1 },
	{ "Back", 3, 1 },
	{ "Front", 3, -1 },
}

local function axes(cf: CFrame): { Vector3 }
	return { cf.RightVector, cf.UpVector, -cf.LookVector }
end

local function kind(p: BasePart): string?
	if p:IsA("WedgePart") then
		return "wedge"
	elseif p:IsA("Part") then
		local shape = (p :: Part).Shape
		if shape == Enum.PartType.Block then
			return "block"
		elseif shape == Enum.PartType.Wedge then
			return "wedge"
		end
		return nil
	elseif p:IsA("MeshPart") or p:IsA("UnionOperation") then
		return "mesh"
	end
	return nil
end

local function key3(c: Color3): string
	return string.format(
		"%d,%d,%d",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

-- what the face looks like: two faces with the same look cannot show a flicker
local function look(p: BasePart, face: string): string
	local s = key3(p.Color)
		.. "|"
		.. p.Material.Name
		.. "|"
		.. string.format("%.2f|%.2f", p.Transparency, p.Reflectance)
	for _, d in p:GetChildren() do
		if
			(d:IsA("Decal") or d:IsA("Texture"))
			and (d :: Decal).Face.Name == face
			and (d :: Decal).Transparency < 0.95
		then
			s ..= "|" .. (d :: Decal).Texture
		end
	end
	return s
end

local function full(i: Instance): string
	local names = {}
	local cur: Instance? = i
	while cur and cur ~= game do
		table.insert(names, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(names, ".")
end

export type Finding = {
	area: number,
	a: BasePart,
	b: BasePart?,
	faceA: string,
	faceB: string,
	at: Vector3,
	confidence: string,
	note: string,
}

-- the parts worth scanning: visible BaseParts below `roots`
function Scan.collect(roots: { Instance }): { BasePart }
	local out = {}
	for _, root in roots do
		local list = root:GetDescendants()
		if root:IsA("BasePart") then
			table.insert(list, root)
		end
		for _, d in list do
			if d:IsA("BasePart") and d.Transparency < 0.95 and kind(d) then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function inside(p: BasePart, at: Vector3): boolean
	local l = p.CFrame:PointToObjectSpace(at)
	local h = p.Size / 2
	return math.abs(l.X) <= h.X + 1e-3
		and math.abs(l.Y) <= h.Y + 1e-3
		and math.abs(l.Z) <= h.Z + 1e-3
end

-- clip polygon pts (2D {x, y}) to |x| <= hu, |y| <= hv; Sutherland-Hodgman against 4 half-planes
local function clip(pts: { { number } }, hu: number, hv: number): { { number } }
	local planes = { { 1, 0, hu }, { -1, 0, hu }, { 0, 1, hv }, { 0, -1, hv } }
	for _, pl in planes do
		local out = {}
		local n = #pts
		for i = 1, n do
			local a, b = pts[i], pts[i % n + 1]
			local da = pl[3] - (pl[1] * a[1] + pl[2] * a[2])
			local db = pl[3] - (pl[1] * b[1] + pl[2] * b[2])
			if da >= 0 then
				table.insert(out, a)
			end
			if (da >= 0) ~= (db >= 0) then
				local t = da / (da - db)
				table.insert(out, { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t })
			end
		end
		pts = out
		if #pts == 0 then
			break
		end
	end
	return pts
end

local function polyArea(pts: { { number } }): (number, number, number)
	local a, cx, cy = 0, 0, 0
	for i = 1, #pts do
		local p, q = pts[i], pts[i % #pts + 1]
		local cr = p[1] * q[2] - q[1] * p[2]
		a += cr
		cx += (p[1] + q[1]) * cr
		cy += (p[2] + q[2]) * cr
	end
	if math.abs(a) < 1e-9 then
		return 0, 0, 0
	end
	return math.abs(a) / 2, cx / (3 * a), cy / (3 * a)
end

type Face = {
	part: BasePart,
	name: string,
	c: Vector3,
	n: Vector3,
	u: Vector3,
	v: Vector3,
	hu: number,
	hv: number,
	r: number,
	look: string,
	mesh: boolean,
	scale: number,
}

-- a ScaleTo'd model (the boards' craft previews at 0.07) keeps its authored gaps in proportion: depth precision is
-- relative to view distance, so the plane tolerance scales with it
local function scaleOf(p: BasePart): number
	local m = p:FindFirstAncestorWhichIsA("Model")
	while m do
		local ok, s = pcall(function()
			return (m :: Model):GetScale()
		end)
		if ok and s ~= 1 then
			return math.min(s, 1)
		end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return 1
end

local function faces(p: BasePart, k: string): { Face }
	local scale = scaleOf(p)
	local cf, s = p.CFrame, p.Size
	local ax = axes(cf)
	local half = { s.X / 2, s.Y / 2, s.Z / 2 }
	local out = {}
	for _, f in FACES do
		local name, i, sign = f[1], f[2], f[3]
		if k ~= "wedge" or name == "Bottom" or name == "Back" then
			local j, l = i % 3 + 1, (i + 1) % 3 + 1
			table.insert(out, {
				part = p,
				name = name,
				c = cf.Position + ax[i] * (half[i] * sign),
				n = ax[i] * sign,
				u = ax[j],
				v = ax[l],
				hu = half[j],
				hv = half[l],
				r = math.sqrt(half[j] ^ 2 + half[l] ^ 2),
				look = look(p, name),
				mesh = k == "mesh",
				scale = scale,
			})
		end
	end
	return out
end

local function sameModel(a: BasePart, b: BasePart): boolean
	return a.Parent == b.Parent
		and a.Size == b.Size
		and a.CFrame == b.CFrame
		and a.Color == b.Color
		and a.Material == b.Material
end

-- every visible coplanar overlap among `parts`, biggest first
-- solid(pt): optional extra cover (Studio passes solid terrain: a face buried in the hillside never shows)
function Scan.find(parts: { BasePart }, solid: ((Vector3) -> boolean)?): { Finding }
	local buckets: { [string]: { Face } } = {}
	local opaque: { [number]: { BasePart } } = {} -- 16-stud grid cells (cellKey) -> the opaque boxes touching them
	for _, p in parts do
		local k = kind(p) :: string
		if p.Transparency < 0.05 and k ~= "mesh" then
			local cf, h = p.CFrame, p.Size / 2
			local ext = Vector3.new(
				math.abs(cf.XVector.X) * h.X
					+ math.abs(cf.YVector.X) * h.Y
					+ math.abs(cf.ZVector.X) * h.Z,
				math.abs(cf.XVector.Y) * h.X
					+ math.abs(cf.YVector.Y) * h.Y
					+ math.abs(cf.ZVector.Y) * h.Z,
				math.abs(cf.XVector.Z) * h.X
					+ math.abs(cf.YVector.Z) * h.Y
					+ math.abs(cf.ZVector.Z) * h.Z
			)
			local lo, hi = (cf.Position - ext) / CELL, (cf.Position + ext) / CELL
			for x = math.floor(lo.X), math.floor(hi.X) do
				for y = math.floor(lo.Y), math.floor(hi.Y) do
					for z = math.floor(lo.Z), math.floor(hi.Z) do
						local k = cellKey(x, y, z)
						local list = opaque[k]
						if not list then
							list = {}
							opaque[k] = list
						end
						table.insert(list, p)
					end
				end
			end
		end
		for _, f in faces(p, k) do
			-- canonical plane key: the normal flipped to a fixed hemisphere, rounded, plus its offset in 0.1 bins
			local n = f.n
			if
				n.X < -1e-4
				or (math.abs(n.X) <= 1e-4 and (n.Y < -1e-4 or (math.abs(n.Y) <= 1e-4 and n.Z < 0)))
			then
				n = -n
			end
			-- shortcut: normals rounded to 0.01 and offsets binned by 0.1 (+ the next bin); a plane that sits right
			-- on a normal rounding edge can be missed, fine for the axis-aligned and few-angle builds in this game
			local nk = string.format("%.2f,%.2f,%.2f", n.X, n.Y, n.Z)
			local d = n:Dot(f.c)
			local bin = math.floor(d / 0.1)
			for _, bb in { bin, bin + 1 } do
				local key = nk .. "#" .. bb
				local list = buckets[key]
				if not list then
					list = {}
					buckets[key] = list
				end
				table.insert(list, f)
			end
		end
	end

	local found: { Finding } = {}
	local seen: { [string]: boolean } = {}
	local ids: { [BasePart]: number } = {}
	for i, p in parts do
		ids[p] = i
	end
	for _, list in buckets do
		for i = 1, #list do
			local f1 = list[i]
			for j = i + 1, #list do
				local f2 = list[j]
				if
					f1.part ~= f2.part
					and f1.look ~= f2.look
					and (f1.c - f2.c).Magnitude < f1.r + f2.r
					and f1.n:Dot(f2.n) > 0.9999 -- opposite faces never both show (backface culling)
					and math.abs((f2.c - f1.c):Dot(f1.n)) < EPS_PLANE * math.min(f1.scale, f2.scale)
					and not sameModel(f1.part, f2.part)
				then
					local pair = ids[f1.part] < ids[f2.part]
							and (ids[f1.part] .. f1.name .. ":" .. ids[f2.part] .. f2.name)
						or (ids[f2.part] .. f2.name .. ":" .. ids[f1.part] .. f1.name)
					if not seen[pair] then
						seen[pair] = true
						local poly = {}
						for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
							local w = f2.c + f2.u * (f2.hu * s[1]) + f2.v * (f2.hv * s[2]) - f1.c
							table.insert(poly, { w:Dot(f1.u), w:Dot(f1.v) })
						end
						local shared = clip(poly, f1.hu, f1.hv)
						local area, cx, cy = polyArea(shared)
						if area > MIN_AREA then
							-- shortcut: under 0.01 studs wide is two abutting faces drifted by the client's replicated
							-- (compressed) rotations, sub-pixel; reported low, not failed
							local long = 0
							for k = 1, #shared do
								local a, b = shared[k], shared[k % #shared + 1]
								long =
									math.max(long, math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2))
							end
							local sliver = area / math.max(long, 1e-6) < 0.01
							local at = f1.c + f1.u * cx + f1.v * cy
							-- probes: the overlap's centre and its corners pulled 10% in; the face shows if any
							-- probe just outside it is in the open
							local samples = { at }
							for _, q in shared do
								local x, y = q[1] + (cx - q[1]) * 0.1, q[2] + (cy - q[2]) * 0.1
								table.insert(samples, f1.c + f1.u * x + f1.v * y)
							end
							local open = false
							for _, side in { f1.n, f2.n } do
								for _, pt in samples do
									local probe = pt + side * OPEN
									local covered = solid ~= nil and solid(probe)
									local c = probe / CELL
									for _, o in
										opaque[cellKey(
											math.floor(c.X),
											math.floor(c.Y),
											math.floor(c.Z)
										)] or {}
									do
										if inside(o, probe) then
											covered = true
											break
										end
									end
									open = open or not covered
								end
							end
							if open then
								table.insert(found, {
									area = area,
									a = f1.part,
									b = f2.part,
									faceA = f1.name,
									faceB = f2.name,
									at = at,
									confidence = if f1.mesh
											or f2.mesh
											or sliver
										then "low"
										else "high",
									note = if sliver
										then "sliver"
										elseif f1.n:Dot(f2.n) > 0 then "same"
										else "opposite",
								})
							end
						end
					end
				end
			end
		end
	end

	-- the same face carrying two or more visible Textures/Decals
	for _, p in parts do
		local count: { [string]: number } = {}
		for _, d in p:GetChildren() do
			if (d:IsA("Decal") or d:IsA("Texture")) and (d :: Decal).Transparency < 0.95 then
				local face = (d :: Decal).Face.Name
				count[face] = (count[face] or 0) + 1
				if count[face] == 2 then
					table.insert(found, {
						area = p.Size.Magnitude,
						a = p,
						b = nil,
						faceA = face,
						faceB = face,
						at = p.Position,
						confidence = "high",
						note = "decal stack",
					})
				end
			end
		end
	end

	table.sort(found, function(x, y)
		if x.confidence ~= y.confidence then
			return x.confidence == "high"
		end
		return x.area > y.area
	end)
	return found
end

local function v3(v: Vector3): string
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end

function Scan.line(f: Finding): string
	local b = f.b
	return string.format(
		"%7.2f %-4s %-8s %s.%s [%s %s] | %s [%s %s] @ %s",
		f.area,
		f.confidence,
		f.note,
		full(f.a),
		f.faceA,
		key3(f.a.Color),
		f.a.Material.Name,
		if b then full(b) .. "." .. f.faceB else "-",
		if b then key3(b.Color) else "",
		if b then b.Material.Name else "",
		v3(f.at)
	)
end

if typeof(game) ~= "Instance" then
	return Scan
end

-- Studio runner
local args = (getfenv() :: any).ZF_ARGS or {}
local root =
	assert(if args.root then workspace:FindFirstChild(args.root, true) else workspace, "no root")
local t0 = os.clock()
local parts = Scan.collect({ workspace }) -- everything covers; `root` only scopes the report
local terrain = workspace.Terrain
local found = Scan.find(parts, function(pt: Vector3): boolean
	local c = (pt / 4):Floor() * 4
	local mats, occ = terrain:ReadVoxels(Region3.new(c, c + Vector3.new(4, 4, 4)), 4)
	return occ[1][1][1] > 0.5 and mats[1][1][1] ~= Enum.Material.Water
end)
if root ~= workspace then
	local kept = {}
	for _, f in found do
		if f.a:IsDescendantOf(root) or (f.b and f.b:IsDescendantOf(root)) then
			table.insert(kept, f)
		end
	end
	found = kept
end
local high = 0
for _, f in found do
	if f.confidence == "high" then
		high += 1
	end
end
-- returned, not printed: execute_luau hands back the return value only (smoke.py parses the first line)
local lines = {
	string.format(
		"ZFIGHT %d findings (%d high, %d low) over %d parts in %.1fs",
		#found,
		high,
		#found - high,
		#parts,
		os.clock() - t0
	),
}
local skip, top = args.skip or 0, args.top or 25
for i = skip + 1, math.min(#found, skip + top) do
	table.insert(lines, Scan.line(found[i]))
end
return table.concat(lines, "\n")
