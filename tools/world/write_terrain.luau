-- Studio-side terrain writer (Edit datamodel, run through tools/studio.py execute_luau by
-- tools/world/studio_terrain.py, which prepends `local ARGS = {...}`). Not part of the game.
--
-- Reads the bake staged by make_work_place.luau (ServerStorage.__WorldTerrain: base64 int16 heights * scale and
-- uint8 material indices on a `cell`-stud grid) and writes Workspace.Terrain with WriteVoxels, 64 x 64 voxel
-- columns per call, as a shell (shellLand studs under land, shellSea under the seabed, extended down to the lowest
-- neighbour so cliffs have no holes). No Terrain water anywhere.
-- ARGS.mode: "write" (ARGS.row0..row1 tile rows of ARGS.window or the main grid; main row0 == 0 clears first),
-- "arch" (ARGS.arch), "export"
-- (ARGS.offset, ARGS.length: base64 slice of SerializationService:SerializeInstancesAsync({Terrain})), "probe".
local ARGS = (ARGS :: any) or { mode = "probe" }

local Terrain = workspace.Terrain
local data = game:GetService("ServerStorage"):FindFirstChild("__WorldTerrain")

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LUT = table.create(256, 0)
for i = 1, 64 do
	LUT[string.byte(ALPHABET, i)] = i - 1
end

local function decode(src: Instance, prefix: string): buffer
	local size = src:GetAttribute(prefix .. "Bytes")
	local out = buffer.create(size)
	local o = 0
	for k = 1, src:GetAttribute(prefix .. "Count") do
		local s = (src:FindFirstChild(prefix .. k) :: StringValue).Value
		for i = 1, #s, 4 do
			local a, b, c, d = string.byte(s, i, i + 3)
			local v = LUT[a] * 262144 + LUT[b] * 4096 + LUT[c] * 64 + LUT[d]
			if o < size then
				buffer.writeu8(out, o, bit32.rshift(v, 16))
			end
			if o + 1 < size then
				buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(v, 8), 255))
			end
			if o + 2 < size then
				buffer.writeu8(out, o + 2, bit32.band(v, 255))
			end
			o += 3
		end
	end
	return out
end

local function encode(raw: buffer, from: number, count: number): string
	local n = math.min(count, buffer.len(raw) - from)
	local parts = table.create(math.ceil(n / 3))
	for i = 0, n - 1, 3 do
		local a = buffer.readu8(raw, from + i)
		local b = if i + 1 < n then buffer.readu8(raw, from + i + 1) else nil
		local c = if i + 2 < n then buffer.readu8(raw, from + i + 2) else nil
		local v = a * 65536 + (b or 0) * 256 + (c or 0)
		parts[#parts + 1] = string.char(
			string.byte(ALPHABET, bit32.rshift(v, 18) + 1),
			string.byte(ALPHABET, bit32.band(bit32.rshift(v, 12), 63) + 1),
			if b then string.byte(ALPHABET, bit32.band(bit32.rshift(v, 6), 63) + 1) else 61,
			if c then string.byte(ALPHABET, bit32.band(v, 63) + 1) else 61
		)
	end
	return table.concat(parts)
end

if ARGS.mode == "write" then
	assert(data, "no ServerStorage.__WorldTerrain (open the work place from make_work_place.luau)")
	-- ARGS.window: an archipelago island window (docs/21), staged as a child Folder; nil = the main grid
	local src = if ARGS.window then data:FindFirstChild(ARGS.window) else data
	assert(src, `no staged window {ARGS.window}`)
	local hb, mb = decode(src, "H"), decode(src, "M")
	local nx, nz = src:GetAttribute("nx"), src:GetAttribute("nz")
	local ox, oz = src:GetAttribute("originX"), src:GetAttribute("originZ")
	local cell, scale = data:GetAttribute("cell"), data:GetAttribute("heightScale")
	local shellLand, shellSea = data:GetAttribute("shellLand"), data:GetAttribute("shellSea")
	local mats = {}
	for name in string.gmatch(data:GetAttribute("materials"), "[^,]+") do
		mats[#mats + 1] = (Enum.Material :: any)[name]
	end
	local M = Enum.Material
	local SUB = {
		[M.Sand] = M.Sand,
		[M.Sandstone] = M.Sandstone,
		[M.Salt] = M.Salt,
		[M.Limestone] = M.Limestone,
		[M.Slate] = M.Slate,
		[M.Mud] = M.Mud,
	}
	local NV, NVZ = nx - 1, nz - 1 -- voxel columns along x and z
	local TILE = 64
	local function colH(i: number, j: number): number
		i = math.clamp(i, 0, NV - 1)
		j = math.clamp(j, 0, NVZ - 1)
		local b = (j * nx + i) * 2
		local r = (j + 1) * nx * 2 + i * 2
		return (
			buffer.readi16(hb, b)
			+ buffer.readi16(hb, b + 2)
			+ buffer.readi16(hb, r)
			+ buffer.readi16(hb, r + 2)
		) / (4 * scale)
	end
	if ARGS.row0 == 0 and not ARGS.window then
		Terrain:Clear()
	end
	local voxels = 0
	for tj = ARGS.row0, ARGS.row1 - 1 do
		for ti = 0, NV // TILE - 1 do
			local i0, j0 = ti * TILE, tj * TILE
			local hs, bot = {}, {}
			local ymin, ymax = math.huge, -math.huge
			for a = 0, TILE - 1 do
				local hrow, brow = table.create(TILE), table.create(TILE)
				for c = 0, TILE - 1 do
					local i, j = i0 + a, j0 + c
					local h = colH(i, j)
					local low =
						math.min(colH(i - 1, j), colH(i + 1, j), colH(i, j - 1), colH(i, j + 1))
					local b = math.min(h - (if h > 0 then shellLand else shellSea), low - 4)
					hrow[c + 1], brow[c + 1] = h, b
					ymin, ymax = math.min(ymin, b), math.max(ymax, h)
				end
				hs[a + 1], bot[a + 1] = hrow, brow
			end
			local y0 = math.floor(ymin / cell) * cell
			local ny = math.ceil((ymax - y0) / cell) + 1
			local matArr, occArr = table.create(TILE), table.create(TILE)
			for a = 1, TILE do
				local mx, ox_ = table.create(ny), table.create(ny)
				for y = 1, ny do
					mx[y], ox_[y] = table.create(TILE, M.Air), table.create(TILE, 0)
				end
				for c = 1, TILE do
					local h, b = hs[a][c], bot[a][c]
					local top = mats[buffer.readu8(mb, (j0 + c - 1) * nx + i0 + a - 1) + 1]
					local sub = SUB[top] or M.Rock
					for y = 1, ny do
						local vy = y0 + (y - 1) * cell
						if vy + cell > b and vy < h then
							local occ = math.clamp((h - vy) / cell, 0, 1)
							if occ > 0.04 then
								ox_[y][c] = occ
								mx[y][c] = if h - (vy + cell / 2) > 6 then sub else top
								voxels += 1
							end
						end
					end
				end
				matArr[a], occArr[a] = mx, ox_
			end
			local x0, z0 = ox + i0 * cell, oz + j0 * cell
			local region = Region3.new(
				Vector3.new(x0, y0, z0),
				Vector3.new(x0 + TILE * cell, y0 + ny * cell, z0 + TILE * cell)
			)
			Terrain:WriteVoxels(region, cell, matArr, occArr)
		end
	end
	return `rows {ARGS.row0}..{ARGS.row1 - 1}: {voxels} voxels`
elseif ARGS.mode == "arch" then
	-- a natural rock arch: overlapping balls along a half ring spanning the gully, plus footing boulders
	local arch = ARGS.arch
	local c = Vector3.new(arch.x, arch.y, arch.z)
	local across = Vector3.new(arch.ax, 0, arch.az).Unit
	for k = 0, 24 do
		local t = math.pi * k / 24
		local p = c
			+ across * (arch.radius * math.cos(t))
			+ Vector3.new(0, arch.radius * 0.8 * math.sin(t), 0)
		local r = arch.thick * (1 + 0.25 * math.sin(k * 1.7))
		Terrain:FillBall(p, r, if k % 3 == 0 then Enum.Material.Rock else Enum.Material.Slate)
	end
	for side = -1, 1, 2 do
		Terrain:FillBall(
			c + across * (arch.radius * side) - Vector3.new(0, 6, 0),
			arch.thick * 1.6,
			Enum.Material.Slate
		)
	end
	return "arch ok"
elseif ARGS.mode == "colors" then
	-- Terrain.MaterialColors multiply the MaterialVariant colour maps too (look-dev round 2: the old docs/05 tints
	-- turned Turf / Moor near-black), so every slot with a B02 MaterialVariant is neutral white and the albedo maps
	-- carry the colour. (Decoration grass blades take the Grass colour: decoration stays off, see
	-- terrain_decoration.luau.)
	local tints = {}
	for _, name in
		{
			"Sand",
			"Sandstone",
			"Salt",
			"Limestone",
			"Rock",
			"Slate",
			"Basalt",
			"Grass",
			"LeafyGrass",
			"Mud",
			"Ground",
		}
	do
		tints[name] = { 255, 255, 255 }
	end
	for _, name in
		{ "Pavement", "Asphalt", "Cobblestone", "Concrete", "CrackedLava", "Snow", "WoodPlanks", "Brick", "Glacier", "Ice" }
	do
		tints[name] = { 255, 255, 255 }
	end
	-- (T2's olive LeafyGrass multiplier is gone: T3 re-graded the Moor albedo itself, process.py MACRO; Snow and
	-- WoodPlanks carry the TurfStraw / TurfOlive variants and their stock tints would recolour them)
	-- T4: Grass carries an olive tint again so the Decoration blades read as turf (they take the Grass colour); the
	-- Turf albedo is stored pre-divided by it (art/source/materials/library.py GRASS_COLOR, process.py)
	tints.Grass = { 148, 154, 112 }
	-- Ground pass (country.png): the variant albedos average khaki / brown, and from the air (and on low graphics
	-- quality) terrain draws close to those averages, so the island read ~45% brown. Multipliers push the swards
	-- green (pasture, dark lush olive, pale hay), heather / hedge banks a dark purple-brown, granite neutral grey.
	tints.Grass = { 121, 158, 87 }
	tints.WoodPlanks = { 186, 235, 167 }
	tints.Snow = { 232, 226, 160 } -- WP-3: hay / stubble fields read warm against the pasture from the air
	tints.Brick = { 210, 241, 205 }
	tints.LeafyGrass = { 202, 187, 245 }
	tints.Rock = { 235, 240, 250 }
	for name, c in tints do
		Terrain:SetMaterialColor((Enum.Material :: any)[name], Color3.fromRGB(c[1], c[2], c[3]))
	end
	-- Wind-animated grass decoration on Grass (terrain look-dev round 2): short coastal turf, not meadow
	-- (Decoration is not scriptable from execute_luau: "not a valid member"; tools/world/terrain_decoration.luau
	-- sets it in the exported Terrain.rbxm with Lune instead)
	local okD = pcall(function()
		(Terrain :: any).Decoration = ARGS.decoration ~= false
	end)
	local okG = pcall(function()
		(Terrain :: any).GrassLength = ARGS.grassLength or 0.3
	end)
	return `colors ok, decoration set {okD}, grass length set {okG}`
elseif ARGS.mode == "export" then
	local g = _G :: any
	if ARGS.offset == 0 or not g.__WorldTerrainExport then
		local ok, res = pcall(function()
			return game:GetService("SerializationService"):SerializeInstancesAsync({ Terrain })
		end)
		assert(ok, `SerializeInstancesAsync(Terrain) failed: {res}`)
		g.__WorldTerrainExport = res
	end
	local raw: buffer = g.__WorldTerrainExport
	return `{buffer.len(raw)}|{encode(raw, ARGS.offset, ARGS.length)}`
else
	local ok, mat = pcall(function()
		local m =
			Terrain:ReadVoxels(Region3.new(Vector3.new(0, -40, 600), Vector3.new(4, 8, 604)), 4)
		local out = {}
		for y = 1, m.Size.Y do
			out[#out + 1] = m[1][y][1].Name
		end
		return table.concat(out, ",")
	end)
	return `probe: data={data ~= nil} extents={Terrain.MaxExtents.Max} column(0,600)={ok and mat}`
end
