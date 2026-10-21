--!strict
-- TownBuildings: the code-built town buildings (no art yet; swap for assets when a terrace kit lands).
--   TownBuildings.terrace(parent, lot, n, lo, hi) -> Model   a TownLayout lot with `floors`: rendered terrace
--     house, recessed 2-over-2 sash windows on both faces (through-parts: one glass column per bay, one sill /
--     lintel per window and one head / meeting rail per storey serve front and back; the white core behind is the
--     sash frame), string course, cornice, slate roof with ridge, granite stack with pots, dormers on some tall
--     houses; doorcase with fanlight, hood and step; Fore Street lots get a glazed shopfront; `corner` lots get
--     side windows. Styles per lot: rendered (9 colours, neighbours always differ), granite front, slate-hung
--     upper storeys, granite quoins; blinds and lit rooms seeded per lot.
--   TownBuildings.landmark(parent, lm, y) -> Model   TownLayout.LANDMARKS: Hotel, CustomsHouse, MarketHall.
-- Night: "_GlassLit_" parts (lit rooms, shop windows) + ATT_Lamp_Window / ATT_Smoke markers go through CottageRig
-- (Neon at night; RigLights / RigSmoke on a subset as for the cottages).
-- Materials avoid the MaterialService overrides (Slate -> KelpRock, WoodPlanks -> TurfOlive, Brick -> TurfWorn,
-- Concrete -> the pavement variant): render = Plaster, stone = Granite, roofs = RoofShingles, timber = Wood.
-- Perf: about 35 Parts a house (sill / lintel strips per storey, through-part doors and windows serve both faces),
-- only the core collides; trim casts no shadow; Atomic + StreamingMesh LOD (imposters past the streaming radius).

local CottageRig = require(script.Parent:WaitForChild("CottageRig"))
local TownLayout = require(script.Parent:WaitForChild("TownLayout"))

local TownBuildings = {}

local M = Enum.Material
local GRANITE = Color3.fromRGB(150, 146, 138)
local WHITE = Color3.fromRGB(238, 236, 228)
local SASH = Color3.fromRGB(246, 245, 240)
local GLASS = Color3.fromRGB(26, 31, 36) -- near-black panes: the sky reflection does the rest
local POT = Color3.fromRGB(172, 94, 62)
local HUNG = Color3.fromRGB(70, 76, 86) -- slate-hanging
local LIT = "Terrace_GlassLit_" -- CottageLights.kind -> "glow": CottageRig turns these Neon at night
local RENDERS =
	{ -- whites and creams lead, soft pastels between (9: n * 5 steps never repeat a neighbour)
		Color3.fromRGB(240, 238, 230), -- white
		Color3.fromRGB(234, 226, 204), -- cream
		Color3.fromRGB(196, 212, 222), -- pale blue
		Color3.fromRGB(244, 240, 226), -- warm white
		Color3.fromRGB(230, 204, 196), -- pink
		Color3.fromRGB(216, 200, 166), -- buff
		Color3.fromRGB(204, 214, 194), -- sage
		Color3.fromRGB(236, 214, 160), -- primrose
		Color3.fromRGB(214, 214, 208), -- pale grey
	}
local BLINDS = {
	Color3.fromRGB(236, 228, 206),
	Color3.fromRGB(244, 242, 236),
	Color3.fromRGB(214, 196, 170),
}
local RIDGES =
	{ Color3.fromRGB(150, 82, 60), Color3.fromRGB(56, 60, 66), Color3.fromRGB(128, 72, 54) }
TownBuildings.SLATES = { -- Delabole greys and blue-greys
	Color3.fromRGB(72, 78, 86),
	Color3.fromRGB(62, 68, 78),
	Color3.fromRGB(84, 88, 94),
	Color3.fromRGB(58, 64, 72),
	Color3.fromRGB(78, 82, 92),
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
	color: Color3
): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = M.RoofShingles
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
	-- recessed core: white, so it reads as the sash frames inside every window opening
	local core = box(
		"Core",
		Vector3.new(w, eave - gTop + 0.2, d - 0.7),
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
			box("Head", Vector3.new(w, 0.4, d - 0.45), 0, y1 - 0.2, 0, SASH, M.SmoothPlastic)
			box(
				"Rail",
				Vector3.new(w, 0.2, d - 0.45),
				0,
				y0 + (y1 - y0) * 0.55,
				0,
				SASH,
				M.SmoothPlastic
			)
			if f > 1 then -- storey 1 sits on the string course
				box("Sill", Vector3.new(w, 0.4, d + 0.7), 0, y0 + 0.05, 0, s.sill, M.Granite)
			end
			if s.lintels then
				box("Lintel", Vector3.new(w, 0.8, d + 0.2), 0, y1 + 0.3, 0, GRANITE, M.Granite)
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
							Vector3.new(gw - 0.7, h, d - 0.55),
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
					Vector3.new(w + 0.1, head - sill, math.min(3, d / 5)),
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
	box("Cornice", Vector3.new(w + 0.6, 1, d + 1.2), 0, eave - 0.3, 0, s.trim, M.Plaster)
	-- dual-pitch slate roof, ridge along the frontage (a wedge's slope faces its -Z)
	local run = d / 2 + 0.6
	local rise = run * 0.62
	wedge(
		m,
		"RoofF",
		Vector3.new(w + 0.4, rise, run),
		at * CFrame.new(0, eave + rise / 2, -run / 2),
		s.slate
	)
	wedge(
		m,
		"RoofB",
		Vector3.new(w + 0.4, rise, run),
		at * CFrame.new(0, eave + rise / 2, run / 2) * CFrame.Angles(0, math.pi, 0),
		s.slate
	)
	part(
		m,
		"Ridge",
		Vector3.new(w + 0.4, 0.75, 0.75),
		at * CFrame.new(0, eave + rise, 0) * CFrame.Angles(math.rad(45), 0, 0),
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
	if s.chimney ~= 0 then
		local x = s.chimney * (w / 2 - 1.1)
		local top = eave + rise + 3.2
		box("Stack", Vector3.new(2.2, top - eave, 3.4), x, (top + eave) / 2, 0, GRANITE, M.Granite)
		box(
			"StackCap",
			Vector3.new(2.6, 0.3, 3.8),
			x,
			top + 0.15,
			0,
			GRANITE:Lerp(Color3.new(), 0.2),
			M.Granite
		)
		for _, z in { -0.8, 0.8 } do
			local p = box("Pot", Vector3.new(1.4, 0.75, 0.75), x, top + 1, z, POT, M.Plaster)
			p.Shape = Enum.PartType.Cylinder -- a cylinder's axis is X: the roll stands it up
			p.CFrame = p.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
		marker("ATT_Smoke_01", x, top + 1.7, -0.8)
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
local function shopfront(m: Model, at: CFrame, w: number, n: number)
	local shop = SHOPS[n % #SHOPS + 1]
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
	if n % 2 == 0 then
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
	box("GroundRail", Vector3.new(gw, 0.2), 4.8, 0.5, SASH, M.SmoothPlastic)
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

-- the ground Y range a footprint stands on: the caller samples; lo = lowest, hi = highest
function TownBuildings.terrace(
	parent: Instance,
	lot: TownLayout.Lot,
	n: number,
	lo: number,
	hi: number
): Model
	local m = Instance.new("Model")
	m.Name = `Terrace{n}`
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local floors = lot.floors or 3
	if lot.corner then
		floors = math.min(floors + 1, 4)
	end
	local seed = math.floor(lot.cf.X * 31 + lot.cf.Z * 17)
	local rng = Random.new(seed)
	-- styles cycle with n so neighbours differ: granite front, slate-hung upper storeys, quoins, plain render
	local style = n % 6
	local granite = style == 0 and not lot.shop
	local hung = style == 3
	local wall = RENDERS[(n * 5) % #RENDERS + 1]
	local s = spec({
		w = lot.w,
		d = TownLayout.DEPTH,
		floors = floors,
		ground = if lot.shop then 10 else 9,
		upper = 8.1 + rng:NextNumber() * 0.9, -- a ragged eaves line down the street
		drop = hi - lo + 1,
		wall = if granite then GRANITE elseif hung then HUNG else wall,
		wallMat = if granite then M.Granite elseif hung then M.RoofShingles else M.Plaster,
		base = if hung then wall else nil,
		slate = TownBuildings.SLATES[n % #TownBuildings.SLATES + 1],
		bay = 6 + n % 3,
		corner = lot.corner,
		chimney = if n % 2 == 0 then 1 else -1,
		sill = if granite or rng:NextNumber() < 0.4 then GRANITE else WHITE,
		lintels = granite or style == 4,
		quoins = style == 4 and not lot.shop,
		dormers = if floors >= 4 and rng:NextNumber() < 0.6
			then rng:NextInteger(1, 2)
			elseif floors == 3 and rng:NextNumber() < 0.15 then 1
			else 0,
		ridge = RIDGES[rng:NextInteger(1, #RIDGES)],
		seed = seed,
	})
	local at = CFrame.new(lot.cf.X, hi, lot.cf.Z) * lot.cf.Rotation
	shell(m, at, s)
	if lot.shop then
		shopfront(m, at * CFrame.new(0, 0, -s.d / 2), lot.w, n)
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

-- a pyramid cap (4 corner wedges) of side `a`, height `h`, base centre `at`
local function pyramid(
	m: Model,
	at: CFrame,
	a: number,
	h: number,
	color: Color3,
	mat: Enum.Material
)
	for i = 0, 3 do
		local p = Instance.new("CornerWedgePart")
		p.Name = "Spire"
		p.Anchored = true
		p.Size = Vector3.new(a / 2, h, a / 2)
		-- a corner wedge's apex is above its (+X, -Z) corner: turn each quarter so the apexes meet at the centre
		p.CFrame = at * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(-a / 4, h / 2, a / 4)
		p.Color = color
		p.Material = mat
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = m
	end
end

local function clock(m: Model, at: CFrame, r: number)
	local face = part(
		m,
		"ClockFace",
		Vector3.new(0.3, r * 2, r * 2),
		at * CFrame.Angles(0, math.pi / 2, 0),
		WHITE,
		M.SmoothPlastic
	)
	face.Shape = Enum.PartType.Cylinder
	local black = Color3.fromRGB(24, 24, 26)
	part(
		m,
		"HourHand",
		Vector3.new(0.3, r * 0.55, 0.1),
		at
			* CFrame.new(0, 0, -0.2)
			* CFrame.Angles(0, 0, math.rad(-60))
			* CFrame.new(0, r * 0.27, 0),
		black,
		M.Metal
	)
	part(
		m,
		"MinuteHand",
		Vector3.new(0.2, r * 0.85, 0.1),
		at * CFrame.new(0, 0, -0.25) * CFrame.new(0, r * 0.42, 0),
		black,
		M.Metal
	)
end

local function flag(m: Model, base: CFrame, h: number, color: Color3)
	part(m, "Flagpole", Vector3.new(0.3, h, 0.3), base * CFrame.new(0, h / 2, 0), WHITE, M.Metal)
	part(m, "Flag", Vector3.new(5, 3, 0.1), base * CFrame.new(2.6, h - 1.8, 0), color, M.Fabric)
end

function TownBuildings.landmark(
	parent: Instance,
	lm: TownLayout.Landmark,
	lo: number,
	hi: number
): Model
	local r = lm.rect
	local m = Instance.new("Model")
	m.Name = lm.kind
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local f = lm.face
	local alongX = f.X == 0
	local w, d =
		if alongX then r[3] - r[1] else r[4] - r[2], if alongX then r[4] - r[2] else r[3] - r[1]
	local at = CFrame.new((r[1] + r[3]) / 2, hi, (r[2] + r[4]) / 2)
		* CFrame.Angles(0, math.atan2(-f.X, -f.Z), 0)
	local drop = hi - lo + 1
	if lm.kind == "Hotel" then
		local s = spec({
			w = w,
			d = d,
			floors = lm.floors,
			ground = 11,
			upper = 9,
			drop = drop,
			wall = Color3.fromRGB(236, 228, 210),
			base = GRANITE,
			baseMat = M.Granite,
			slate = TownBuildings.SLATES[2],
			corner = true,
			chimney = -1,
		})
		local eave = shell(m, at, s)
		-- portico on the entrance, name board on the roof, a domed corner turret over Eastgate Hill
		for _, x in { -5, 5 } do
			local c = part(
				m,
				"Column",
				Vector3.new(10, 1.6, 1.6),
				at * CFrame.new(x, 5, -d / 2 - 5) * CFrame.Angles(0, 0, math.rad(90)),
				WHITE,
				M.Plaster
			)
			c.Shape = Enum.PartType.Cylinder
		end
		part(
			m,
			"Portico",
			Vector3.new(14, 1.2, 7),
			at * CFrame.new(0, 10.6, -d / 2 - 3),
			WHITE,
			M.Plaster
		)
		part(
			m,
			"HotelDoor",
			Vector3.new(5, 8, 0.3),
			at * CFrame.new(0, 4, -d / 2 - 0.2),
			Color3.fromRGB(60, 34, 22),
			M.Wood
		)
		local board = part(
			m,
			"NameBoard",
			Vector3.new(26, 4, 0.6),
			at * CFrame.new(0, eave + 2.6, -d / 2 + 2),
			Color3.fromRGB(28, 40, 64),
			M.Wood
		)
		sign(board, "HARBOUR HOTEL", Color3.fromRGB(236, 206, 130), Enum.Font.Garamond)
		local tc = at * CFrame.new(w / 2 - 3, 0, -d / 2 + 3)
		local tower = part(
			m,
			"Turret",
			Vector3.new(eave + 6 + drop, 11, 11),
			tc * CFrame.new(0, (eave + 6 - drop) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			s.wall,
			M.Plaster
		)
		tower.Shape = Enum.PartType.Cylinder
		part(
			m,
			"TurretCornice",
			Vector3.new(1, 12.4, 12.4),
			tc * CFrame.new(0, eave + 6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			WHITE,
			M.Plaster
		).Shape =
			Enum.PartType.Cylinder
		part(
			m,
			"Dome",
			Vector3.new(11, 11, 11),
			tc * CFrame.new(0, eave + 6.5, 0),
			Color3.fromRGB(96, 138, 120),
			M.Metal
		).Shape =
			Enum.PartType.Ball
		flag(m, tc * CFrame.new(0, eave + 11.5, 0), 8, Color3.fromRGB(28, 40, 64))
	elseif lm.kind == "CustomsHouse" then
		local s = spec({
			w = w,
			d = d,
			floors = lm.floors,
			upper = 9,
			drop = drop,
			wall = GRANITE,
			wallMat = M.Granite,
			trim = Color3.fromRGB(226, 222, 212),
			slate = TownBuildings.SLATES[4],
			bay = 8,
			corner = true,
			chimney = 0,
			sill = GRANITE,
			lintels = true,
		})
		local eave = shell(m, at, s)
		-- central clock and flag tower, proud of the front
		local T, top = 12, eave + 16
		local tc = at * CFrame.new(0, 0, -d / 2 - 1)
		part(
			m,
			"Tower",
			Vector3.new(T, top + drop, T),
			tc * CFrame.new(0, (top - drop) / 2, 0),
			GRANITE,
			M.Granite
		).CanCollide =
			true
		part(
			m,
			"TowerCornice",
			Vector3.new(T + 1.2, 1.2, T + 1.2),
			tc * CFrame.new(0, top, 0),
			s.trim,
			M.Plaster
		)
		pyramid(m, tc * CFrame.new(0, top + 0.6, 0), T, 7, TownBuildings.SLATES[2], M.RoofShingles)
		clock(m, tc * CFrame.new(0, top - 5, -T / 2 - 0.2), 2.8)
		part(
			m,
			"Arch",
			Vector3.new(6, 9, 0.3),
			tc * CFrame.new(0, 4.5, -T / 2 - 0.1),
			Color3.fromRGB(40, 56, 80),
			M.Wood
		)
		local board = part(
			m,
			"NameBoard",
			Vector3.new(10, 1.8, 0.4),
			tc * CFrame.new(0, 11, -T / 2 - 0.2),
			s.trim,
			M.Plaster
		)
		sign(board, "CUSTOMS", Color3.fromRGB(40, 44, 52), Enum.Font.Garamond)
		flag(m, tc * CFrame.new(0, top + 7.6, 0), 9, Color3.fromRGB(26, 40, 96))
	else -- MarketHall: granite arcade, rendered upper hall, clock turret with a copper cupola
		local s = spec({
			w = w,
			d = d,
			floors = lm.floors,
			ground = 9,
			upper = 9,
			drop = drop,
			wall = Color3.fromRGB(230, 222, 200),
			base = GRANITE,
			baseMat = M.Granite,
			slate = TownBuildings.SLATES[3],
			corner = true,
			chimney = 0,
			arcade = true,
		})
		local eave = shell(m, at, s)
		local ridge = eave + (d / 2 + 0.6) * 0.62
		local tc = at * CFrame.new(0, ridge - 2, 0)
		part(m, "Turret", Vector3.new(6, 8, 6), tc * CFrame.new(0, 4, 0), WHITE, M.Plaster)
		clock(m, tc * CFrame.new(0, 5, -3.2), 2.2)
		clock(m, tc * CFrame.new(0, 5, 3.2) * CFrame.Angles(0, math.pi, 0), 2.2)
		part(
			m,
			"Cupola",
			Vector3.new(6, 6, 6),
			tc * CFrame.new(0, 8, 0),
			Color3.fromRGB(96, 138, 120),
			M.Metal
		).Shape =
			Enum.PartType.Ball
		part(
			m,
			"Vane",
			Vector3.new(0.25, 4, 0.25),
			tc * CFrame.new(0, 12.5, 0),
			Color3.fromRGB(200, 160, 60),
			M.Metal
		)
	end
	m.Parent = parent
	CottageRig.apply(m)
	return m
end

return TownBuildings
