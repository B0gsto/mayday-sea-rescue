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
-- Height: lots with `floors` are code-built terraces (TownBuildings), stepping down from 4 storeys on central Fore
-- Street to 3 on the inner avenues and Church Street's centre; the rest (outer avenues, Church Street's north side)
-- stay M_Bld_Cottage_0n. `corner`: the end lots of a street row (they turn the corner: side windows).

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
	},
} :: { [string]: { Landmark } }

-- extra rects no lot takes (not buildings): Port Haven's TownLane climbs north-east from Bodmin Road's x 20 end
TownLayout.CLEAR = { PortHaven = { { 0, -550, 80, -500 } } } :: { [string]: { Rect } }

-- landmark rects and the CLEAR rects (both keep lots and gardens out)
local function landmarkRects(town: Town): { Rect }
	local out: { Rect } = table.clone(TownLayout.CLEAR[town.id] or {})
	local lms: { Landmark } = TownLayout.LANDMARKS[town.id] or {}
	for _, l in lms do
		table.insert(out, l.rect)
	end
	return out
end

TownLayout.DEPTH = 16 -- cottage depth (studs), all six
TownLayout.GAP = 0.6 -- terraced: party walls nearly touching
-- frontage widths (studs) of M_Bld_Cottage_01..06 (Swaps.cottage widths x 3); fill() relies on 18 / 22 / 26
TownLayout.COTTAGES = { 22, 26, 18, 22, 26, 18 }
TownLayout.RENDERS = { "White", "Pink", "Ochre", "Sage", "Blue" } -- M_Bld_Cottage_Kit render sets

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
	local D = TownLayout.DEPTH
	local back = town.width / 2 + town.footway + 1 -- street centre to the house front
	local setback = back + D / 2
	local corner = back + D + TownLayout.GAP -- avenue rows start behind the street rows' corner houses
	local out: { Lot } = {}
	local seq = 0
	-- one row: houses filling `a`..`b` along `axis` ("x" or "z") at `across`, fronts facing `face` (unit XZ)
	local function row(
		axis: string,
		a: number,
		b: number,
		across: number,
		face: Vector3,
		shop: boolean,
		floors: (along: number) -> number?
	)
		local ws = fill(b - a, math.floor(math.abs(across + a)))
		local used = -TownLayout.GAP
		for _, w in ws do
			used += w + TownLayout.GAP
		end
		local s = a + (b - a - used) / 2 -- the < 4 stud remainder split at the two ends
		for idx, w in ws do
			seq += 1
			local pair = VARIANTS[w]
			local v = pair[seq % 2 + 1]
			local along = s + w / 2
			s += w + TownLayout.GAP
			local pos = if axis == "x"
				then Vector3.new(along, town.origin.Y, across)
				else Vector3.new(across, town.origin.Y, along)
			local hx, hz =
				if axis == "x" then w / 2 else D / 2, if axis == "x" then D / 2 else w / 2
			local rect = { pos.X - hx, pos.Z - hz, pos.X + hx, pos.Z + hz }
			local free = true
			for _, k in keep do
				if overlaps(rect, k) then
					free = false
				end
			end
			if free then
				table.insert(out, {
					asset = string.format("M_Bld_Cottage_%02d", v),
					render = TownLayout.RENDERS[(seq * 3 + v) % #TownLayout.RENDERS + 1],
					-- yaw turns the front (asset local -Z) toward `face`
					cf = CFrame.new(pos) * CFrame.Angles(0, math.atan2(-face.X, -face.Z), 0),
					w = w,
					rect = rect,
					shop = shop,
					face = face,
					floors = floors(along),
					corner = axis == "x" and (idx == 1 or idx == #ws),
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
	for i = 1, #xs - 1 do
		for j = 1, #zs - 1 do
			local x0, x1, zS, zN = xs[i], xs[i + 1], zs[j], zs[j + 1]
			-- street rows run corner to corner; avenue rows fill between them
			local nf = if j + 1 == 2 then fore else midStreet
			row("x", x0 + back, x1 - back, zN + setback, Vector3.new(0, 0, -1), j + 1 == 2, nf) -- faces the street north
			if j > 1 then
				local sf = if j == 2 then fore else midStreet
				row("x", x0 + back, x1 - back, zS - setback, Vector3.new(0, 0, 1), j == 2, sf) -- faces the street south
			end
			if j + 1 == #zs then -- the last street's far side (village edge): cottages facing it, no gardens
				row("x", x0 + back, x1 - back, zN - setback, Vector3.new(0, 0, 1), false, cottage)
			end
			-- by the south road (no street row there) the avenue rows run to its pavement, 3 studs spare for
			-- the bend between avenues (Harbour Road east of x 180); without south data keep a corner clear
			local zW = if j == 1 and south and south[i] then south[i] - back - 3 else zS - corner
			local zE = if j == 1
					and south
					and south[i + 1]
				then south[i + 1] - back - 3
				else zS - corner
			-- inner avenues get 3-storey terraces, the outer two stay cottages (height steps down to the edges)
			local wf = if i > 1 then three else cottage
			local ef = if i + 1 < #xs then three else cottage
			row("z", zN + corner, zW, x0 + setback, Vector3.new(-1, 0, 0), false, wf) -- faces the avenue west
			row("z", zN + corner, zE, x1 - setback, Vector3.new(1, 0, 0), false, ef) -- faces the avenue east
		end
	end
	return out
end

-- back gardens: up to GARDEN studs behind each lot, inside its block, clear of every lot, keep rect and garden
-- already given (corners and the narrow middles lose theirs). -> { { rect, lot } }
TownLayout.GARDEN = 15 -- back-to-back gardens leave an 8-stud back lane between them
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
	local out = {}
	for _, l in lots do
		local f, r = l.face, l.rect
		local G = TownLayout.GARDEN
		local g: Rect = if f.Z < 0
			then { r[1], r[4], r[3], r[4] + G }
			elseif f.Z > 0 then { r[1], r[2] - G, r[3], r[2] }
			elseif f.X < 0 then { r[3], r[2], r[3] + G, r[4] }
			else { r[1] - G, r[2], r[1], r[4] }
		local inside = false
		for _, b in blocks do
			inside = inside or (g[1] >= b[1] and g[3] <= b[3] and g[2] >= b[2] and g[4] <= b[4])
		end
		local free = inside
		for _, t in taken do
			if free and overlaps(g, t) then
				free = false
			end
		end
		if free then
			table.insert(taken, g)
			table.insert(out, { rect = g, lot = l })
		end
	end
	return out
end

return TownLayout
