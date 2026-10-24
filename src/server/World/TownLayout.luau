--!strict
-- TownLayout: the pure city-block rules behind Town (tests/Town.spec.luau). A town is one WorldConfig.Towns entry
-- (generated from tools/world/layout.py TOWNS): a street grid from `origin`, avenues (x offsets, north-south) and
-- streets (z offsets, east-west, going north = more negative). The origin line (z = origin.z) is the town's south
-- road (Port Haven: Harbour Road), so no row faces it. Every other block side is lined with cottages, front to
-- the street, terraced (GAP apart), clear of the corners and of every `keep` rect {x0, z0, x1, z1}.
--
--   TownLayout.lines(town)        -> xs, zs      absolute grid lines (zs[1] = origin.z)
--   TownLayout.lots(town, extra?, south?) -> { Lot }  extra keep rects (e.g. the Swaps cottages); south: the
--     south road's z at each avenue (TownLayout.southZ) runs the first block's avenue rows down to its pavement
--   TownLayout.southZ(town, roads) -> { number }  from the WorldConfig <town>_Av<n> roads' south ends
--   TownLayout.blocks(town)       -> { Rect }    block interiors between the carriageways
--   TownLayout.gardens(town, lots, extra?) -> { {rect, lot} }  back gardens behind the lots
--   TownLayout.LANDMARKS[town.id] -> { {kind, rect, face, floors} }  code-built landmarks; their rects keep lots out
--   TownLayout.uses(town)         -> { {kind, rect} }  whole blocks of another use (USES: churchyard, green, ...)
-- Code-built terrace lots vary in `depth` (12 / 16 / 20, runs along a row): ragged back walls.
-- Height: lots with `floors` are code-built terraces (TownBuildings): central Fore Street 4 storeys, its edges 3,
-- the other terrace rows a seeded 2 / 3 / 4 each, and within a row runs of 2-4 houses step a storey up or down; the
-- rest (outer avenues, Church Street's north side) stay M_Bld_Cottage_0n. `corner`: the end lots of a street row
-- (they turn the corner: side windows). `kind` (about 1 lot in 5, never a corner or next to another): "gap" (a
-- walled garden with a tree), "endon" (a gable-end-on cottage), "chapel", "garage", on shop rows "pub". `front`:
-- the front garden depth between the pavement and the house (0 for shops: their fronts stand on the pavement).
-- Fore Street's south side is all shops; its north side mixes runs of shops and gardened houses.

local TownLayout = {}

export type Rect = { number }
export type Town = {
	id: string,
	origin: Vector3,
	width: number,
	footway: number,
	avenues: { number },
	streets: { number },
	keep: { Rect },
}
-- shop: the row faces Fore Street (the first street); face: unit XZ the front looks along
export type Lot = {
	asset: string,
	render: string,
	cf: CFrame,
	w: number,
	rect: Rect,
	shop: boolean,
	face: Vector3,
	floors: number?,
	corner: boolean,
	kind: string?,
	front: number,
	depth: number, -- front to back (TownLayout.DEPTH for cottages)
}
export type Landmark = { kind: string, rect: Rect, face: Vector3, floors: number }

-- face: unit XZ the front looks along. Hotel: the Fore Street / Eastgate Hill corner; Customs House: on Harbour
-- Road facing the harbour (Chapel Hill / hospital gap); MarketHall: Chapel Square's north-west corner, clock turret.
TownLayout.LANDMARKS = {
	PortHaven = {
		{
			kind = "Hotel",
			rect = { 292, -152, 360, -114 },
			face = Vector3.new(0, 0, -1),
			floors = 5,
		},
		{
			kind = "CustomsHouse",
			rect = { 31, -88, 85, -52 },
			face = Vector3.new(0, 0, 1),
			floors = 3,
		},
		{
			kind = "MarketHall",
			rect = { 35, -249, 71, -229 },
			face = Vector3.new(0, 0, 1),
			floors = 2,
		},
		{ -- the School block's (USES) north side, its front on the playground
			kind = "School",
			rect = { 52, -463, 140, -439 },
			face = Vector3.new(0, 0, 1),
			floors = 2,
		},
	},
} :: { [string]: { Landmark } }

-- extra rects no lot takes (not buildings): Port Haven's TownLane climbs north-east from Bodmin Road's x 20 end
TownLayout.CLEAR = { PortHaven = { { 0, -550, 80, -500 } } } :: { [string]: { Rect } }

-- whole blocks given over to another use (Town.luau blockUse builds them): i = the avenue gap (west avenue i), j =
-- the street gap (south line j), as TownLayout.blocks. They break the grid of terrace rings seen from above.
TownLayout.USES = {
	PortHaven = {
		{ kind = "Market", i = 6, j = 2 }, -- Tregenna car park and market stalls on Fore Street
		{ kind = "Churchyard", i = 3, j = 3 }, -- St Petroc's: tall west tower, yews, gravestones
		{ kind = "Green", i = 5, j = 3 }, -- the town green: diagonal paths, bandstand, war memorial
		{ kind = "Allotments", i = 2, j = 4 },
		{ kind = "School", i = 4, j = 4 }, -- board school and playground
	},
} :: { [string]: { { kind: string, i: number, j: number } } }

-- the USES blocks: rect = the block inside its pavements (lots and gardens stay out)
function TownLayout.uses(town: Town): { { kind: string, rect: Rect } }
	local xs, zs = TownLayout.lines(town)
	local b = town.width / 2 + town.footway
	local out = {}
	local list: { { kind: string, i: number, j: number } } = TownLayout.USES[town.id] or {}
	for _, u in list do
		table.insert(out, {
			kind = u.kind,
			rect = { xs[u.i] + b, zs[u.j + 1] + b, xs[u.i + 1] - b, zs[u.j] - b },
		})
	end
	return out
end

-- landmark, CLEAR and USES rects (all keep lots and gardens out)
local function landmarkRects(town: Town): { Rect }
	local out: { Rect } = table.clone(TownLayout.CLEAR[town.id] or {})
	local lms: { Landmark } = TownLayout.LANDMARKS[town.id] or {}
	for _, l in lms do
		table.insert(out, l.rect)
	end
	for _, u in TownLayout.uses(town) do
		table.insert(out, u.rect)
	end
	return out
end

TownLayout.DEPTH = 16 -- cottage depth (studs), all six
TownLayout.GAP = 0.6 -- terraced: party walls nearly touching
TownLayout.FRONT = 5 -- front garden depth (studs) of the non-shop rows
-- frontage widths (studs) of M_Bld_Cottage_01..06 (Swaps.cottage widths x 3); fill() relies on 18 / 22 / 26
TownLayout.COTTAGES = { 22, 26, 18, 22, 26, 18 }
TownLayout.RENDERS = { "White", "Pink", "Ochre", "Sage", "Blue" } -- M_Bld_Cottage_Kit render sets

-- a deterministic 0..1 hash of two numbers (seeded variety that tests can rely on)
local function hash(a: number, b: number): number
	local v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return v - math.floor(v)
end
TownLayout.hash = hash

function TownLayout.lines(town: Town): ({ number }, { number })
	local xs, zs = {}, { town.origin.Z }
	for _, a in town.avenues do
		table.insert(xs, town.origin.X + a)
	end
	for _, b in town.streets do
		table.insert(zs, town.origin.Z + b)
	end
	return xs, zs
end

local function overlaps(a: Rect, b: Rect): boolean
	return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
end

function TownLayout.blocks(town: Town): { Rect }
	local xs, zs = TownLayout.lines(town)
	local h = town.width / 2
	local out: { Rect } = {}
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			table.insert(out, { xs[i] + h, zs[j + 1] + h, xs[i + 1] - h, zs[j] - h })
		end
	end
	return out
end

-- frontage widths that fill `len` exactly (to under 4 studs): as many of the narrowest as fit, then widen them
-- one step (18 -> 22 -> 26) at a time, spread along the row by `seed`
local function fill(len: number, seed: number): { number }
	local G = TownLayout.GAP
	local n = math.floor((len + G) / (18 + G))
	local ws = table.create(n, 18)
	local spare = len - n * (18 + G) + G
	local k = 0
	while spare >= 4 and k < n * 2 do
		local i = (seed + k * 7) % n + 1
		if ws[i] < 26 then
			ws[i] += 4
			spare -= 4
		end
		k += 1
	end
	return ws
end
local VARIANTS = { [18] = { 3, 6 }, [22] = { 1, 4 }, [26] = { 2, 5 } }

function TownLayout.southZ(town: Town, roads: { { id: string, points: { Vector3 } } }): { number }
	local out = {}
	for _, r in roads do
		local n = string.match(r.id, `^{town.id}_Av(%d+)$`)
		if n then
			out[tonumber(n) :: number] = r.points[1].Z
		end
	end
	return out
end

function TownLayout.lots(town: Town, extra: { Rect }?, south: { number }?): { Lot }
	local xs, zs = TownLayout.lines(town)
	local keep: { Rect } = table.clone(town.keep)
	local more: { Rect } = extra or {}
	for _, r in more do
		table.insert(keep, r)
	end
	for _, r in landmarkRects(town) do
		table.insert(keep, r)
	end
	local D, F = TownLayout.DEPTH, TownLayout.FRONT
	local back = town.width / 2 + town.footway + 1 -- street centre to the pavement-side lot line
	-- avenue rows start behind the street rows' corner houses (gardened or not)
	local corner = back + F + D + TownLayout.GAP
	local out: { Lot } = {}
	local seq = 0
	-- one row: houses filling `a`..`b` along `axis` ("x" or "z"), fronts facing `face` (unit XZ) across the street
	-- centre line `line`; shops(along) says which lots are shopfronts; mix: a seeded row height 2 / 3 / 4
	local function row(
		axis: string,
		a: number,
		b: number,
		line: number,
		face: Vector3,
		shops: (along: number) -> boolean,
		floors: (along: number) -> number?,
		mix: boolean
	)
		local ws = fill(b - a, math.floor(math.abs(line + a)))
		local used = -TownLayout.GAP
		for _, w in ws do
			used += w + TownLayout.GAP
		end
		local s = a + (b - a - used) / 2 -- the < 4 stud remainder split at the two ends
		local toward = if axis == "x" then face.Z else face.X
		local key = line * 3 + toward * 41 -- the row's identity: the two sides of a street differ
		local rowStep = if mix then ({ -1, 0, 0, 1 })[math.floor(hash(key, a) * 4) + 1] else 0
		local step, runLeft, prevKind, deep = 0, 0, false, TownLayout.DEPTH
		for idx, w in ws do
			seq += 1
			local pair = VARIANTS[w]
			local v = pair[seq % 2 + 1]
			local along = s + w / 2
			s += w + TownLayout.GAP
			if runLeft <= 0 then -- runs of 2-4 houses a storey up or down: stepped eaves along the row
				local h = hash(along, key)
				runLeft = 2 + math.floor(h * 3)
				step = if h < 0.3 then -1 elseif h > 0.75 then 1 else 0
				deep = ({ 12, 16, 16, 20 })[math.floor(hash(key, along * 0.53) * 4) + 1] -- ragged back walls
			end
			runLeft -= 1
			local shop = shops(along)
			local isCorner = axis == "x" and (idx == 1 or idx == #ws)
			local kind: string? = nil
			if not isCorner and not prevKind and hash(along * 0.37, key) < 0.2 then
				local k = hash(along * 1.7 + 3.1, key * 0.29 + 5.7)
				kind = if shop
					then (if k < 0.6 then "pub" else "gap")
					elseif k < 0.1 then "chapel"
					elseif k < 0.4 then "gap"
					elseif k < 0.8 then "endon"
					else "garage"
				shop = shop and kind == "pub"
			end
			prevKind = kind ~= nil
			local fl = floors(along)
			-- code-built terraces vary in depth (cottage meshes are D); never the two end lots, which back onto the
			-- avenue rows
			local dl = if fl and kind ~= "gap" and idx > 2 and idx < #ws - 1 then deep else D
			local fr = if shop then 0 else F
			local across = line - toward * (back + fr + dl / 2)
			local pos = if axis == "x"
				then Vector3.new(along, town.origin.Y, across)
				else Vector3.new(across, town.origin.Y, along)
			local hx, hz =
				if axis == "x" then w / 2 else dl / 2, if axis == "x" then dl / 2 else w / 2
			local rect = { pos.X - hx, pos.Z - hz, pos.X + hx, pos.Z + hz }
			local free = true
			for _, k in keep do
				if overlaps(rect, k) then
					free = false
				end
			end
			if fl then
				fl = math.clamp(fl + rowStep + step, if shop then 3 else 2, 4)
			end
			if free then
				table.insert(out, {
					asset = string.format("M_Bld_Cottage_%02d", v),
					render = TownLayout.RENDERS[(seq * 2) % #TownLayout.RENDERS + 1], -- neighbours never match
					-- yaw turns the front (asset local -Z) toward `face`
					cf = CFrame.new(pos) * CFrame.Angles(0, math.atan2(-face.X, -face.Z), 0),
					w = w,
					rect = rect,
					shop = shop,
					face = face,
					floors = fl,
					corner = isCorner,
					kind = kind,
					front = fr,
					depth = dl,
				})
			end
		end
	end
	-- the centre: between the second and the second-to-last avenue (Port Haven: Station Hill .. Hospital Lane)
	local function central(x: number): boolean
		return x > xs[2] - 1 and x < xs[#xs - 1] + 1
	end
	local function fore(
		x: number
	): number? -- Fore Street: 4 storeys in the centre, 3 out to the edges
		return if central(x) then 4 else 3
	end
	local function midStreet(
		x: number
	): number? -- the other streets: 3 in the centre, cottages beyond
		return if central(x) then 3 else nil
	end
	local function cottage(_: number): number?
		return nil
	end
	local function three(_: number): number?
		return 3
	end
	local function always(_: number): boolean
		return true
	end
	local function never(_: number): boolean
		return false
	end
	-- Fore Street's north side: runs of about 60 studs, shops or gardened houses
	local function mixed(x: number): boolean
		return hash(math.floor(x / 60), 8) < 0.55
	end
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local x0, x1, zS, zN = xs[i], xs[i + 1], zs[j], zs[j + 1]
			-- street rows run corner to corner; avenue rows fill between them
			local fn = j + 1 == 2
			row(
				"x",
				x0 + back,
				x1 - back,
				zN,
				Vector3.new(0, 0, -1),
				if fn then always else never,
				if fn then fore else midStreet,
				not fn
			) -- faces the street north
			if j > 1 then
				local fs = j == 2
				row(
					"x",
					x0 + back,
					x1 - back,
					zS,
					Vector3.new(0, 0, 1),
					if fs then mixed else never,
					if fs then fore else midStreet,
					not fs
				) -- faces the street south
			end
			if j + 1 == #zs then -- the last street's far side (village edge): cottages facing it, no back gardens
				row("x", x0 + back, x1 - back, zN, Vector3.new(0, 0, 1), never, cottage, false)
			end
			-- by the south road (no street row there) the avenue rows run to its pavement, 3 studs spare for
			-- the bend between avenues (Harbour Road east of x 180); without south data keep a corner clear
			local zW = if j == 1 and south and south[i] then south[i] - back - 3 else zS - corner
			local zE = if j == 1
					and south
					and south[i + 1]
				then south[i + 1] - back - 3
				else zS - corner
			-- inner avenues get terraces, the outer two stay cottages (height steps down to the edges)
			local wf = if i > 1 then three else cottage
			local ef = if i + 1 < #xs then three else cottage
			row("z", zN + corner, zW, x0, Vector3.new(-1, 0, 0), never, wf, true) -- faces the avenue west
			row("z", zN + corner, zE, x1, Vector3.new(1, 0, 0), never, ef, true) -- faces the avenue east
		end
	end
	return out
end

-- back gardens: BACKYARD studs behind each lot (more behind a shallow house), then out to the longest of LONG that
-- stays clear; inside its block, clear of every lot, keep rect and garden already given (corners and the narrow
-- middles lose theirs).
-- -> { { rect, lot } }
TownLayout.GARDEN = 15
TownLayout.LONG = { 44, 34, 25, TownLayout.GARDEN } -- second-pass garden lengths, longest first
TownLayout.BACKYARD = 7 -- back-to-back street rows: 7 + 7 leaves the 6-stud gravel back lane (Town.paint)
function TownLayout.gardens(
	town: Town,
	lots: { Lot },
	extra: { Rect }?
): { { rect: Rect, lot: Lot } }
	local taken: { Rect } = table.clone(town.keep)
	local more: { Rect } = extra or {}
	for _, r in more do
		table.insert(taken, r)
	end
	for _, r in landmarkRects(town) do
		table.insert(taken, r)
	end
	for _, l in lots do
		table.insert(taken, l.rect)
	end
	local blocks = TownLayout.blocks(town)
	local function behind(l: Lot, G: number): Rect
		local f, r = l.face, l.rect
		return if f.Z < 0
			then { r[1], r[4], r[3], r[4] + G }
			elseif f.Z > 0 then { r[1], r[2] - G, r[3], r[2] }
			elseif f.X < 0 then { r[3], r[2], r[3] + G, r[4] }
			else { r[1] - G, r[2], r[1], r[4] }
	end
	local function fits(g: Rect, skip: Rect?): boolean
		local inside = false
		for _, b in blocks do
			inside = inside or (g[1] >= b[1] and g[3] <= b[3] and g[2] >= b[2] and g[4] <= b[4])
		end
		if not inside then
			return false
		end
		for _, t in taken do
			if t ~= skip and overlaps(g, t) then
				return false
			end
		end
		return true
	end
	local out = {}
	-- a shallower house gets that much more garden: every garden ends on the same back line
	local function slack(l: Lot): number
		return TownLayout.DEPTH - (l.depth or TownLayout.DEPTH)
	end
	for _, l in lots do
		local g = behind(l, TownLayout.BACKYARD + slack(l))
		if fits(g) then
			table.insert(taken, g)
			table.insert(out, { rect = g, lot = l })
		end
	end
	-- second pass: lengthen where a long garden stays clear (the open courts behind the avenue rows fill up)
	for _, o in out do
		for _, len in TownLayout.LONG do
			local g = behind(o.lot, len + slack(o.lot))
			if fits(g, o.rect) then
				table.remove(taken, table.find(taken, o.rect))
				table.insert(taken, g)
				o.rect = g
				break
			end
		end
	end
	return out
end

return TownLayout
