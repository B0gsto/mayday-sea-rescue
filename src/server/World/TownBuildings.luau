--!strict
-- TownBuildings: the code-built terrace houses of Penwyn's village (no art yet; swap for assets when a terrace kit lands).
--   TownBuildings.terrace(parent, lot, n, lo, hi) -> Model   a Lot with `floors`: rendered terrace
--     house, recessed 2-over-2 sash windows on both faces (through-parts: one glass column per bay, one sill /
--     lintel per window and one head / meeting rail per storey serve front and back; the white core behind is the
--     sash frame), string course, cornice, slate roof with ridge, granite stack with pots, dormers on some tall
--     houses; doorcase with fanlight, hood and step; Fore Street lots get a glazed shopfront; `corner` lots get
--     side windows. Styles per lot: rendered (9 colours, neighbours always differ), granite front, slate-hung
--     upper storeys, granite quoins; blinds and lit rooms seeded per lot. Roofs: dark Delabole slate, seeded pitch,
--     hipped on corners and now and then, stacks 1 or 2 at seeded heights. lot.kind: "endon" (gable-end-on
--     cottage), "chapel" (granite, tall round-headed windows), "garage" (single storey, roller door), "pub".
-- Night: "_GlassLit_" parts (lit rooms, shop windows) + ATT_Lamp_Window / ATT_Smoke markers go through CottageRig
-- (Neon at night; RigLights / RigSmoke on a subset as for the cottages).
-- Materials avoid the MaterialService overrides (Slate -> KelpRock, WoodPlanks -> TurfOlive, Brick -> TurfWorn,
-- Concrete -> the pavement variant): render = Plaster, stone = Granite, roofs = RoofShingles, timber = Wood.
-- Perf: about 35 Parts a house (sill / lintel strips per storey, through-part doors and windows serve both faces),
-- only the core collides; trim casts no shadow; Atomic + StreamingMesh LOD (imposters past the streaming radius).

local CottageRig = require(script.Parent:WaitForChild("CottageRig"))

local TownBuildings = {}

-- a house lot (Penwyn builds these); depth defaults to the cottage depth
export type Lot = {
	cf: CFrame,
	w: number,
	depth: number?,
	kind: string?,
	floors: number?,
	corner: boolean,
	shop: boolean,
}
local DEPTH = 16

local M = Enum.Material
local GRANITE = Color3.fromRGB(150, 146, 138)
local WHITE = Color3.fromRGB(238, 236, 228)
local SASH = Color3.fromRGB(246, 245, 240)
local GLASS = Color3.fromRGB(26, 31, 36) -- near-black panes: the sky reflection does the rest
local POT = Color3.fromRGB(172, 94, 62)
local HUNG = Color3.fromRGB(70, 76, 86) -- slate-hanging
local LIT = "Terrace_GlassLit_" -- CottageLights.kind -> "glow": CottageRig turns these Neon at night
local RENDERS =
	{ -- seaside pastels between whites and creams (9: n * 5 steps never repeat a neighbour)
		Color3.fromRGB(240, 238, 230), -- white
		Color3.fromRGB(236, 222, 190), -- cream
		Color3.fromRGB(176, 200, 218), -- pale blue
		Color3.fromRGB(244, 240, 226), -- warm white
		Color3.fromRGB(230, 190, 184), -- pink
		Color3.fromRGB(212, 192, 150), -- buff
		Color3.fromRGB(188, 206, 180), -- sage
		Color3.fromRGB(238, 210, 140), -- primrose
		Color3.fromRGB(200, 210, 212), -- pale grey-blue
	}
local BLINDS = {
	Color3.fromRGB(236, 228, 206),
	Color3.fromRGB(244, 242, 236),
	Color3.fromRGB(214, 196, 170),
}
local RIDGES =
	{ Color3.fromRGB(150, 82, 60), Color3.fromRGB(56, 60, 66), Color3.fromRGB(128, 72, 54) }
TownBuildings.SLATES =
	{ -- dark Delabole greys: the sky light lifts an up-facing roof about +25 grey from the air (#3A3F45 read pale)
		Color3.fromRGB(38, 41, 46),
		Color3.fromRGB(32, 35, 41),
		Color3.fromRGB(44, 46, 50),
		Color3.fromRGB(35, 38, 44),
		Color3.fromRGB(41, 42, 47),
	}
local DOORS = {
	Color3.fromRGB(30, 52, 86),
	Color3.fromRGB(110, 30, 34),
	Color3.fromRGB(34, 70, 52),
	Color3.fromRGB(36, 36, 40),
	Color3.fromRGB(196, 160, 60),
	Color3.fromRGB(70, 120, 140),
	Color3.fromRGB(240, 238, 230),
}
local SHOPS: { { any } } = {
	{ Color3.fromRGB(32, 72, 58), "BAKERY" },
	{ Color3.fromRGB(28, 44, 82), "FISH" },
	{ Color3.fromRGB(122, 32, 40), "PASTIES" },
	{ Color3.fromRGB(150, 112, 30), "CAFE" },
	{ Color3.fromRGB(30, 108, 112), "SURF" },
	{ Color3.fromRGB(70, 40, 80), "BOOKS" },
	{ Color3.fromRGB(150, 70, 30), "DELI" },
	{ Color3.fromRGB(40, 40, 44), "GIFTS" },
	{ Color3.fromRGB(26, 60, 96), "CHANDLER" },
	{ Color3.fromRGB(96, 26, 30), "BANK" },
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = size.X * size.Y * size.Z > 400 -- trim casts none
	p.Parent = parent
	return p
end

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.RoofShingles
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = parent
	return p
end

-- a word on a part's front face (shop fascias, hotel sign)
local function sign(p: Part, word: string, color: Color3, font: Enum.Font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 24
	gui.LightInfluence = 1
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.Text = word
	label.TextScaled = true
	label.Font = font
	label.TextColor3 = color
	label.Parent = gui
end

export type Spec = {
	w: number,
	d: number,
	floors: number,
	ground: number, -- ground storey height
	upper: number, -- upper storey height
	drop: number, -- plinth below the floor (sloping ground)
	wall: Color3,
	wallMat: Enum.Material,
	trim: Color3,
	base: Color3, -- ground storey colour
	baseMat: Enum.Material,
	slate: Color3,
	bay: number, -- target bay width (one window column each)
	corner: boolean,
	chimney: number, -- -1 / 1: stack on that party wall, 0: none
	arcade: boolean, -- open ground storey on granite piers (market hall)
	sill: Color3, -- window sills
	lintels: boolean, -- granite lintels over the upper windows
	quoins: boolean, -- granite quoins up both corners
	dormers: number, -- flat-topped dormers on the front slope
	ridge: Color3,
	seed: number, -- blinds and lit rooms
	roof: string, -- "gable" (ridge along the front), "hip", "endon" (gable to the street)
	pitch: number, -- rise / run
	stackUp: number, -- chimney top above the ridge
	stacks: number, -- 2: a stack on both party walls
}

-- the shell: local -Z = front, origin = front-to-back centre at floor level. Returns the eaves height.
local function shell(m: Model, at: CFrame, s: Spec): number
	local G, U, w, d = s.ground, s.upper, s.w, s.d
	local eave = G + (s.floors - 1) * U
	local gTop = if s.floors > 1 then G + 2.2 else eave -- the first upper sill
	local rng = Random.new(s.seed)
	local function box(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		c: Color3,
		mat: Enum.Material
	): Part
		return part(m, name, size, at * CFrame.new(x, y, z), c, mat)
	end
	-- recessed core: white, so it reads as the sash frames inside every window opening. Everything inside the walls is
	-- INSET studs narrower than w: flush with the end piers, its side faces z-fought through the gable walls.
	local INSET = 0.2
	local core = box(
		"Core",
		Vector3.new(w - INSET, eave - gTop + 0.2, d - 0.7),
		0,
		(eave + gTop) / 2,
		0,
		SASH,
		M.SmoothPlastic
	)
	core.CanCollide, core.CanQuery = true, true
	m.PrimaryPart = core -- CottageRig hangs its lights / smoke here
	local function marker(name: string, x: number, y: number, z: number)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = core
		a.WorldPosition = (at * CFrame.new(x, y, z)).Position
	end
	if s.arcade then
		local n = math.max(2, math.floor(w / 8))
		for i = 0, n do
			for _, z in { -d / 2 + 1.2, d / 2 - 1.2 } do
				box(
					"Pier",
					Vector3.new(2.4, gTop + s.drop, 2.4),
					-w / 2 + 1.2 + i * (w - 2.4) / n,
					(gTop - s.drop) / 2,
					z,
					s.base,
					s.baseMat
				)
			end
		end
		box("Soffit", Vector3.new(w, 1.2, d), 0, gTop - 0.6, 0, s.trim, M.Plaster)
	else
		local g = box(
			"Ground",
			Vector3.new(w, gTop + s.drop, d),
			0,
			(gTop - s.drop) / 2,
			0,
			s.base,
			s.baseMat
		)
		g.CanCollide, g.CanQuery = true, true
		box(
			"Plinth",
			Vector3.new(w + 0.1, s.drop + 1, d + 0.5),
			0,
			(1 - s.drop) / 2,
			0,
			GRANITE,
			M.Granite
		)
	end
	local c = math.max(1, math.floor(w / s.bay + 0.5))
	local bw = w / c
	local gw = math.min(3.4, bw - 2.2) -- window opening width
	if s.floors > 1 then
		-- bays: one glass column per bay from the first upper sill to the top head; piers and spandrel bands frame it
		local sill, head = gTop, eave - U + 7
		for k = 1, c do
			local x = -w / 2 + (k - 0.5) * bw
			box(
				"Glass",
				Vector3.new(gw - 0.7, head - sill, d - 0.6),
				x,
				(sill + head) / 2,
				0,
				GLASS,
				M.Glass
			).Reflectance =
				0.18
			box(
				"Bar",
				Vector3.new(0.18, head - sill, d - 0.45),
				x,
				(sill + head) / 2,
				0,
				SASH,
				M.SmoothPlastic
			)
		end
		for k = 0, c do
			local pw = if k == 0 or k == c then (bw - gw) / 2 else bw - gw
			local x = if k == 0
				then -w / 2 + pw / 2
				elseif k == c then w / 2 - pw / 2
				else -w / 2 + k * bw
			box("Pier", Vector3.new(pw, eave - gTop, d), x, (eave + gTop) / 2, 0, s.wall, s.wallMat)
		end
		local wide = w + (if s.corner then 0.3 else 0.02)
		for k = 1, s.floors - 2 do
			local h0, h1 = G + (k - 1) * U + 7, G + k * U + 2.2
			box("Band", Vector3.new(wide, h1 - h0, d), 0, (h0 + h1) / 2, 0, s.wall, s.wallMat)
		end
		box("Frieze", Vector3.new(wide, eave - head, d), 0, (eave + head) / 2, 0, s.wall, s.wallMat)
		box("Course", Vector3.new(w + 0.4, 0.5, d + 0.6), 0, gTop - 0.25, 0, s.trim, M.Plaster)
		-- per storey: head + meeting rails, sill and lintel strips across the row (perf: one part each, not one
		-- per window); per window now and then a half-drawn blind or a lit room
		local lit = 0
		for f = 1, s.floors - 1 do
			local y0, y1 = G + (f - 1) * U + 2.2, G + (f - 1) * U + 7
			box(
				"Head",
				Vector3.new(w - INSET, 0.4, d - 0.45),
				0,
				y1 - 0.2,
				0,
				SASH,
				M.SmoothPlastic
			)
			box(
				"Rail",
				Vector3.new(w - INSET, 0.2, d - 0.45),
				0,
				y0 + (y1 - y0) * 0.55,
				0,
				SASH,
				M.SmoothPlastic
			)
			if f > 1 then -- storey 1 sits on the string course
				box(
					"Sill",
					Vector3.new(w - INSET / 2, 0.4, d + 0.7),
					0,
					y0 + 0.05,
					0,
					s.sill,
					M.Granite
				)
			end
			if s.lintels then
				box(
					"Lintel",
					Vector3.new(w - INSET / 2, 0.8, d + 0.2),
					0,
					y1 + 0.3,
					0,
					GRANITE,
					M.Granite
				)
			end
			-- a lit storey: one strip behind every opening of the floor (the piers hide the rest; perf: one part)
			if rng:NextNumber() < 0.35 then
				lit += 1
				box(
					`{LIT}{lit}`,
					Vector3.new(w - (bw - gw) - 0.2, y1 - y0 - 0.6, d - 0.55),
					0,
					(y0 + y1) / 2,
					0,
					GLASS,
					M.SmoothPlastic
				).Transparency =
					1
				if lit == 1 then
					marker("ATT_Lamp_Window_01", 0, (y0 + y1) / 2, -d / 2 - 2)
				end
			else
				for k = 1, c do
					if rng:NextNumber() < 0.15 then
						local h = (y1 - y0) * (0.25 + rng:NextNumber() * 0.2)
						local x = -w / 2 + (k - 0.5) * bw
						box(
							"Blind",
							Vector3.new(gw - 0.76, h, d - 0.55), -- narrower than the glass: no shared side faces
							x,
							y1 - 0.4 - h / 2,
							0,
							BLINDS[rng:NextInteger(1, #BLINDS)],
							M.Fabric
						)
					end
				end
			end
		end
		if s.corner then -- side windows: two through-columns across the width (the party side hides in the gap)
			for _, z in { -d / 4, d / 4 } do
				box(
					"SideGlass",
					Vector3.new(w + 0.24, head - sill, math.min(3, d / 5)), -- between the quoins (+0.09) and corner bands (+0.15)
					0,
					(sill + head) / 2,
					z,
					GLASS,
					M.Glass
				)
			end
		end
	end
	if s.quoins then -- per corner: a short-width granite strip + the long blocks every other course (perf)
		local long = math.min(1.8, (bw - gw) / 2 - 0.15)
		local top = eave - 0.6
		if long >= 1 then
			for _, sx in { -1, 1 } do
				local qs = long * 0.6
				box(
					"Quoin",
					Vector3.new(qs, top - 1, d + 0.3),
					sx * (w / 2 - qs / 2 + 0.06),
					(top + 1) / 2,
					0,
					GRANITE,
					M.Granite
				)
				local y = 1
				while y + 1.2 < top do
					box(
						"Quoin",
						Vector3.new(long, 1.2, d + 0.36),
						sx * (w / 2 - long / 2 + 0.09),
						y + 0.6,
						0,
						GRANITE,
						M.Granite
					)
					y += 4.8
				end
			end
		end
	end
	-- top flush with the eaves: higher, its white top showed as a line round every roof from the air
	box("Cornice", Vector3.new(w + 0.6, 1, d + 1.2), 0, eave - 0.5, 0, s.trim, M.Plaster)
	-- slate roof (a wedge's slope faces its -Z)
	local run = d / 2 + 0.6
	local rise = run * s.pitch
	local ridgeY = eave + rise
	if s.roof == "endon" then -- ridge front to back: rendered gable triangles under two slate slabs
		local hw = w / 2
		local rr = hw * s.pitch
		ridgeY = eave + rr
		local a = math.atan2(rr, hw)
		for _, sx in { -1, 1 } do
			wedge(
				m,
				"Gable",
				Vector3.new(d, rr, hw),
				at
					* CFrame.new(sx * hw / 2, eave + rr / 2, 0)
					* CFrame.Angles(0, -sx * math.pi / 2, 0),
				s.wall,
				s.wallMat
			)
			part(
				m,
				"Slope",
				Vector3.new(math.sqrt(hw * hw + rr * rr) + 0.8, 0.4, d + 0.8),
				at
					* CFrame.new(sx * hw / 2, eave + rr / 2, 0)
					* CFrame.Angles(0, 0, -sx * a)
					* CFrame.new(sx * 0.4, 0.2, 0),
				s.slate,
				M.RoofShingles
			).CastShadow =
				true
		end
		part(
			m,
			"Ridge",
			Vector3.new(0.75, 0.75, d + 0.8),
			at * CFrame.new(0, ridgeY + 0.1, 0) * CFrame.Angles(0, 0, math.rad(45)),
			s.ridge,
			M.Plaster
		)
	else
		local hip = s.roof == "hip"
		local L = if hip then math.max(w + 0.4 - 2 * run, 0.4) else w + 0.4
		wedge(
			m,
			"RoofF",
			Vector3.new(L, rise, run),
			at * CFrame.new(0, eave + rise / 2, -run / 2),
			s.slate
		)
		wedge(
			m,
			"RoofB",
			Vector3.new(L, rise, run),
			at * CFrame.new(0, eave + rise / 2, run / 2) * CFrame.Angles(0, math.pi, 0),
			s.slate
		)
		if hip then -- half a pyramid each end: corner wedges whose apexes meet the ridge ends
			for _, e in { { -1, 0 }, { -1, 3 }, { 1, 1 }, { 1, 2 } } do
				local p = Instance.new("CornerWedgePart")
				p.Name = "Hip"
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
				p.Size = Vector3.new(run, rise, run)
				p.CFrame = at
					* CFrame.new(e[1] * L / 2, eave, 0)
					* CFrame.Angles(0, e[2] * math.pi / 2, 0)
					* CFrame.new(-run / 2, rise / 2, run / 2)
				p.Color, p.Material = s.slate, M.RoofShingles
				p.Parent = m
			end
		end
		part(
			m,
			"Ridge",
			Vector3.new(L, 0.75, 0.75),
			at * CFrame.new(0, ridgeY, 0) * CFrame.Angles(math.rad(45), 0, 0),
			s.ridge,
			M.Plaster
		)
		for i = 1, s.dormers do -- flat-topped dormers on the front slope, one per chosen bay
			local x = if s.dormers == 1 then 0 else -w / 2 + (i - 0.5) * w / s.dormers
			local zf = -d / 2 + 1.6
			box("Dormer", Vector3.new(4.2, 4, 3.6), x, eave + 2.4, zf + 1.8, SASH, M.Plaster)
			box("DormerGlass", Vector3.new(2.4, 2.4, 0.2), x, eave + 2.5, zf - 0.05, GLASS, M.Glass).Reflectance =
				0.18
			box(
				"DormerCap",
				Vector3.new(4.8, 0.4, 4.2),
				x,
				eave + 4.6,
				zf + 1.7,
				Color3.fromRGB(64, 68, 74),
				M.Metal
			)
		end
	end
	if s.chimney ~= 0 then
		local top = ridgeY + s.stackUp
		-- endon: one stack on the back gable; else on the party wall(s)
		local spots: { Vector3 } = if s.roof == "endon"
			then { Vector3.new(0, 0, d / 2 - 1.7) }
			elseif s.stacks == 2 then {
				Vector3.new(-(w / 2 - 1.1), 0, 0),
				Vector3.new(w / 2 - 1.1, 0, 0),
			}
			else { Vector3.new(s.chimney * (w / 2 - 1.1), 0, 0) }
		for k, sp in spots do
			local x, z = sp.X, sp.Z
			local up = top - (k - 1) * 1.3 -- a second stack sits a little lower
			box(
				"Stack",
				Vector3.new(2.2, up - eave, 3.4),
				x,
				(up + eave) / 2,
				z,
				GRANITE,
				M.Granite
			)
			box(
				"StackCap",
				Vector3.new(2.6, 0.3, 3.8),
				x,
				up + 0.15,
				z,
				GRANITE:Lerp(Color3.new(), 0.2),
				M.Granite
			)
			for _, dz in { -0.8, 0.8 } do
				local p =
					box("Pot", Vector3.new(1.4, 0.75, 0.75), x, up + 1, z + dz, POT, M.Plaster)
				p.Shape = Enum.PartType.Cylinder -- a cylinder's axis is X: the roll stands it up
				p.CFrame = p.CFrame * CFrame.Angles(0, 0, math.rad(90))
			end
			if k == 1 then
				marker("ATT_Smoke_01", x, up + 1.7, z - 0.8)
			end
		end
	end
	return eave
end

local function spec(over: { [string]: any }): Spec
	local s: { [string]: any } = {
		ground = 10,
		upper = 8.5,
		drop = 1,
		wallMat = M.Plaster,
		trim = WHITE,
		baseMat = M.Plaster,
		slate = TownBuildings.SLATES[1],
		bay = 7,
		corner = false,
		chimney = 1,
		arcade = false,
		sill = WHITE,
		lintels = false,
		quoins = false,
		dormers = 0,
		ridge = RIDGES[2],
		seed = 1,
		roof = "gable",
		pitch = 0.62,
		stackUp = 3.2,
		stacks = 1,
	}
	for k, v in over do
		s[k] = v
	end
	if s.base == nil then
		s.base = s.wall
	end
	return s :: any
end

-- glazed shopfront on the ground storey: stallriser, plate glass with a mullion, recessed door, pilasters, fascia
-- with the shop's name, cornice; every other shop a slim canvas awning
local PUBS: { { any } } = {
	{ Color3.fromRGB(26, 38, 30), "THE ANCHOR" },
	{ Color3.fromRGB(70, 24, 26), "SHIP INN" },
	{ Color3.fromRGB(24, 30, 52), "PILCHARD" },
}

local function shopfront(m: Model, at: CFrame, w: number, n: number, pub: boolean?)
	local shop = if pub then PUBS[n % #PUBS + 1] else SHOPS[n % #SHOPS + 1]
	local colour: Color3, word: string = shop[1], shop[2]
	local function box(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		z: number,
		c: Color3,
		mat: Enum.Material
	): Part
		return part(m, name, size, at * CFrame.new(x, y, z), c, mat)
	end
	local z = -0.3 -- proud of the wall face
	local inner = w - 2.4
	local dw = 3
	local gx = -dw / 2 -- glass centre (door at the right end)
	box("Pilaster", Vector3.new(1, 9.2, 0.8), -w / 2 + 0.7, 4.6, z, colour, M.Wood)
	box("Pilaster", Vector3.new(1, 9.2, 0.8), w / 2 - 0.7, 4.6, z, colour, M.Wood)
	box(
		"Stallriser",
		Vector3.new(inner - dw, 2.2, 0.6),
		gx,
		1.1,
		z,
		colour:Lerp(Color3.new(), 0.3),
		M.Wood
	)
	box("ShopGlass", Vector3.new(inner - dw, 5.2, 0.2), gx, 4.8, z + 0.1, GLASS, M.Glass).Reflectance =
		0.3
	local glow = box(
		`{LIT}Shop`,
		Vector3.new(inner - dw, 5.2, 0.05),
		gx,
		4.8,
		z - 0.03,
		GLASS,
		M.SmoothPlastic
	)
	glow.Transparency = 1
	glow:SetAttribute("Glow", Color3.fromRGB(112, 92, 70)) -- a lit shop interior, not a light box (CottageRig)
	box("Transom", Vector3.new(inner - dw, 0.3, 0.4), gx, 6.4, z, colour, M.Wood)
	box("Mullion", Vector3.new(0.3, 5.2, 0.4), gx, 4.8, z, colour, M.Wood)
	box(
		"ShopDoor",
		Vector3.new(dw - 0.4, 7.2, 0.2),
		inner / 2 - dw / 2,
		3.6,
		z + 0.5,
		colour:Lerp(Color3.new(), 0.25),
		M.Wood
	)
	local fascia = box("Fascia", Vector3.new(w - 0.6, 1.6, 0.6), 0, 8.3, z - 0.1, colour, M.Wood)
	sign(fascia, word, Color3.fromRGB(240, 214, 150), Enum.Font.Garamond)
	box("FasciaCornice", Vector3.new(w - 0.2, 0.35, 1), 0, 9.25, z - 0.1, WHITE, M.Plaster)
	if pub then -- hanging sign on an iron bracket over the pavement
		box(
			"SignBracket",
			Vector3.new(0.25, 0.25, 3.6),
			-w / 2 + 2,
			11.2,
			-1.8,
			Color3.fromRGB(28, 28, 30),
			M.Metal
		)
		local board =
			box("PubSign", Vector3.new(0.3, 3.2, 2.6), -w / 2 + 2, 9.3, -2.8, colour, M.Wood)
		board.CFrame = board.CFrame * CFrame.Angles(0, math.pi / 2, 0)
		sign(board, "INN", Color3.fromRGB(236, 206, 130), Enum.Font.Garamond)
	elseif n % 2 == 0 then
		box(
			"Awning",
			Vector3.new(w - 2.6, 0.12, 3.4),
			0,
			7,
			-1.9,
			colour:Lerp(WHITE, 0.15),
			M.Fabric
		).CFrame = at
			* CFrame.new(0, 6.9, -1.9)
			* CFrame.Angles(math.rad(22), 0, 0)
	end
end

-- the front door: white doorcase with fanlight and hood, panelled door. Through-parts (d = house depth): the same
-- parts make the back door (perf)
local function frontDoor(m: Model, at: CFrame, x: number, d: number, n: number)
	local function box(
		name: string,
		size: Vector3,
		y: number,
		proud: number,
		c: Color3,
		mat: Enum.Material
	): Part
		return part(
			m,
			name,
			Vector3.new(size.X, size.Y, d + 2 * proud),
			at * CFrame.new(x, y, 0),
			c,
			mat
		)
	end
	box("Doorcase", Vector3.new(4.6, 9.4), 5.7, 0.3, SASH, M.Plaster)
	box("Door", Vector3.new(3, 7), 4.5, 0.39, DOORS[n % #DOORS + 1], M.Wood)
	box("Fanlight", Vector3.new(3, 1.5), 8.95, 0.39, GLASS, M.Glass).Reflectance = 0.18
	box("DoorHood", Vector3.new(5.4, 0.5), 10.45, 1.2, WHITE, M.Plaster)
end

-- a ground-floor sash: white frame, glass, meeting rail, sill; through-parts, so the back gets the same window
local function groundWindow(
	m: Model,
	at: CFrame,
	x: number,
	d: number,
	gw: number,
	sill: Color3,
	glow: boolean
)
	local function box(
		name: string,
		size: Vector3,
		y: number,
		proud: number,
		c: Color3,
		mat: Enum.Material
	): Part
		return part(
			m,
			name,
			Vector3.new(size.X, size.Y, d + 2 * proud),
			at * CFrame.new(x, y, 0),
			c,
			mat
		)
	end
	box("GroundFrame", Vector3.new(gw + 0.8, 5.6), 4.6, 0.3, SASH, M.SmoothPlastic)
	box("GroundGlass", Vector3.new(gw, 4.8), 4.6, 0.38, GLASS, M.Glass).Reflectance = 0.18
	if glow then
		box(`{LIT}Ground`, Vector3.new(gw, 4.8), 4.6, 0.425, GLASS, M.SmoothPlastic).Transparency =
			1
	end
	box("GroundRail", Vector3.new(gw - 0.06, 0.2), 4.8, 0.5, SASH, M.SmoothPlastic)
	box("GroundSill", Vector3.new(gw + 1.2, 0.4), 1.9, 0.8, sill, M.Granite)
end

local function doorway(m: Model, at: CFrame, x: number, z: number, n: number)
	part(
		m,
		"Door",
		Vector3.new(3, 7, 0.3),
		at * CFrame.new(x, 3.5, z),
		DOORS[n % #DOORS + 1],
		M.Wood
	)
	part(m, "DoorHood", Vector3.new(4.2, 0.5, 1), at * CFrame.new(x, 7.6, z), WHITE, M.Plaster)
end

-- a chapel front (lot.kind "chapel"): two tall round-headed windows in granite surrounds, a doorcase with a
-- fanlight, a round window and a name stone in the gable; through-parts, so the back gable matches
local function chapelFront(m: Model, at: CFrame, w: number, d: number, eave: number)
	local function box(
		name: string,
		size: Vector3,
		x: number,
		y: number,
		proud: number,
		c: Color3,
		mat: Enum.Material
	): Part
		return part(
			m,
			name,
			Vector3.new(size.X, size.Y, d + 2 * proud),
			at * CFrame.new(x, y, 0),
			c,
			mat
		)
	end
	for _, sx in { -1, 1 } do
		local x = sx * w / 4
		box("Surround", Vector3.new(3.8, 10.6), x, 7.6, 0.25, WHITE, M.Plaster)
		box("ChapelGlass", Vector3.new(2.6, 9.4), x, 7.6, 0.35, GLASS, M.Glass).Reflectance = 0.18
		local arch = box("Arch", Vector3.new(3.8, 3.8), x, 12.9, 0.25, WHITE, M.Plaster)
		arch.Shape = Enum.PartType.Cylinder
		arch.Size = Vector3.new(d + 0.5, 3.8, 3.8)
		arch.CFrame = at * CFrame.new(x, 12.9, 0) * CFrame.Angles(0, math.pi / 2, 0)
		box("ChapelSill", Vector3.new(4.4, 0.5), x, 2.7, 0.6, GRANITE, M.Granite)
	end
	box("Doorcase", Vector3.new(4.8, 10.4), 0, 5.2, 0.3, WHITE, M.Plaster)
	box("Door", Vector3.new(3.2, 7.6), 0, 3.8, 0.39, Color3.fromRGB(40, 56, 80), M.Wood)
	box("Fanlight", Vector3.new(3.2, 1.6), 0, 8.6, 0.39, GLASS, M.Glass)
	local rose = part(
		m,
		"RoseWindow",
		Vector3.new(d + 0.7, 3.4, 3.4),
		at * CFrame.new(0, eave + 3.2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		GLASS,
		M.Glass
	)
	rose.Shape = Enum.PartType.Cylinder
	local stone = part(
		m,
		"NameStone",
		Vector3.new(6, 1.6, 0.4),
		at * CFrame.new(0, eave + 2, -d / 2 - 0.2),
		WHITE,
		M.Plaster
	)
	sign(stone, "BETHEL 1859", Color3.fromRGB(40, 44, 52), Enum.Font.Garamond)
end

-- the ground Y range a footprint stands on: the caller samples; lo = lowest, hi = highest
function TownBuildings.terrace(parent: Instance, lot: Lot, n: number, lo: number, hi: number): Model
	local m = Instance.new("Model")
	m.Name = `Terrace{n}`
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local kind = lot.kind
	local floors = if kind == "chapel" or kind == "garage"
		then 1
		elseif kind == "endon" then 2
		else lot.floors or 3
	if lot.corner then
		floors = math.min(floors + 1, 4)
	end
	local seed = math.floor(lot.cf.X * 31 + lot.cf.Z * 17)
	local rng = Random.new(seed)
	-- styles cycle with n so neighbours differ: granite front, slate-hung upper storeys, quoins, plain render
	local style = n % 6
	local granite = (style == 0 and not lot.shop) or kind == "chapel"
	local hung = style == 3 and floors > 1
	local wall = RENDERS[(n * 5) % #RENDERS + 1]
	local roof = if kind == "endon" or kind == "chapel"
		then "endon"
		elseif lot.corner or rng:NextNumber() < 0.15 then "hip"
		else "gable"
	local s = spec({
		w = lot.w,
		d = lot.depth or DEPTH,
		floors = floors,
		ground = if kind == "chapel"
			then 15
			elseif kind == "garage" then 10
			elseif lot.shop then 10
			else 9,
		upper = 8.1 + rng:NextNumber() * 0.9, -- a ragged eaves line down the street
		drop = hi - lo + 1,
		wall = if granite then GRANITE elseif hung then HUNG else wall,
		wallMat = if granite then M.Granite elseif hung then M.RoofShingles else M.Plaster,
		base = if hung then wall else nil,
		baseMat = if granite then M.Granite else nil, -- granite fronts: no flat Plaster ground storey
		slate = TownBuildings.SLATES[n % #TownBuildings.SLATES + 1],
		bay = 6 + n % 3,
		corner = lot.corner,
		chimney = if kind == "garage" or kind == "chapel" then 0 elseif n % 2 == 0 then 1 else -1,
		sill = if granite or rng:NextNumber() < 0.4 then GRANITE else WHITE,
		lintels = granite or style == 4,
		quoins = (style == 4 and not lot.shop) or kind == "chapel",
		dormers = if roof == "endon"
			then 0
			elseif floors >= 4 and rng:NextNumber() < 0.6 then rng:NextInteger(1, 2)
			elseif floors == 3 and rng:NextNumber() < 0.15 then 1
			else 0,
		ridge = RIDGES[rng:NextInteger(1, #RIDGES)],
		seed = seed,
		roof = roof,
		pitch = if kind == "garage"
			then 0.35
			elseif roof == "endon" then 0.95 + rng:NextNumber() * 0.25
			else ({ 0.5, 0.62, 0.75, 0.9 })[rng:NextInteger(1, 4)],
		stackUp = 1.8 + rng:NextNumber() * 3.6,
		stacks = if n % 3 == 0 then 2 else 1,
	})
	local at = CFrame.new(lot.cf.X, hi, lot.cf.Z) * lot.cf.Rotation
	local eave = shell(m, at, s)
	if kind == "chapel" then
		chapelFront(m, at, lot.w, s.d, eave)
	elseif kind == "garage" then
		local front = at * CFrame.new(0, 0, -s.d / 2)
		part(
			m,
			"RollerDoor",
			Vector3.new(lot.w - 5, 7.6, 0.3),
			front * CFrame.new(0, 3.8, -0.1),
			Color3.fromRGB(150, 156, 160),
			M.Metal
		)
		local fascia = part(
			m,
			"Fascia",
			Vector3.new(lot.w - 2, 1.4, 0.4),
			front * CFrame.new(0, 8.6, -0.2),
			Color3.fromRGB(176, 30, 34),
			M.SmoothPlastic
		)
		sign(fascia, "GARAGE", WHITE, Enum.Font.GothamBold)
	elseif lot.shop then
		shopfront(m, at * CFrame.new(0, 0, -s.d / 2), lot.w, n, kind == "pub")
		local rear = s.d / 2 + 0.1
		doorway(m, at, lot.w / 4, rear, n + 1)
		part(
			m,
			"BackGlass",
			Vector3.new(3, 4, 0.2),
			at * CFrame.new(-lot.w / 4, 4.6, rear),
			GLASS,
			M.Glass
		)
	else
		local q = lot.w / 4
		frontDoor(m, at, -q, s.d, n)
		groundWindow(m, at, q, s.d, math.min(4, lot.w / 2 - 3), s.sill, rng:NextNumber() < 0.35)
	end
	-- perf: real PointLights on every third house, smoke on every fourth (the Neon panes all glow), as the cottages
	m:SetAttribute("RigLights", n % 3 == 0)
	m:SetAttribute("RigSmoke", n % 4 == 0)
	m.Parent = parent
	CottageRig.apply(m)
	return m
end

return TownBuildings
