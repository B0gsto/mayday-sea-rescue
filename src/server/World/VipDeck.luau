--!strict
-- VipDeck (RP-M5 E2): the VIP Crew Card roof deck on the lifeboat station, built at runtime on the
-- M_Bld_Station shell (no edits to the station asset or map/Build.luau). A widow's-walk lookout
-- straddling the boat hall's slate ridge: Accoya-style decking on galvanised steel posts down to the
-- slates, a 1.1 m galvanised railing with toe boards, a teak bench facing the sea and a pair of
-- pedestal-mounted lookout binoculars; reached by a caged steel cat ladder up the hall's back gable,
-- with a padlocked anti-climb guard at its foot and a small enamel sign ("Roof deck: VIP Crew Card
-- holders"). Climbing is a prompt (src/client/Cosmetics/VipDeckAccess.luau, owners only), the
-- server moves the character (src/server/Cosmetics/VipStatus.luau).
--
-- Geometry is authored in the station's build.py metres (X across, +Y the back, Z up; hall ridge
-- at X -5.25, Z 10.78, roof pitch 3.78 / 4.5) and mapped to the asset frame in studs exactly as
-- LeaderboardService.toLocal does (3 studs per metre, X mirrored, upload recentred +0.175 m in Y).
--
--   VipDeck.build(asset: Model) -> Deck
--   Deck = { folder, foot: BasePart, head: BasePart, footStand: CFrame, headStand: CFrame,
--            volume: CFrame, volumeSize: Vector3 }
--   foot / head are the invisible prompt anchors (attribute VipDeck = "Foot" / "Head").
local CollectionService = game:GetService("CollectionService")

local VipDeck = {}

export type Deck = {
	folder: Folder,
	foot: BasePart,
	head: BasePart,
	footStand: CFrame,
	headStand: CFrame,
	volume: CFrame,
	volumeSize: Vector3,
}

local S = 3 -- studs per metre
local DY = 0.175 -- Swaps STATION_DY

local RIDGE_X, RIDGE_Z, PITCH = -5.25, 10.78, 3.78 / 4.5
local X0, X1 = -7.45, -3.05 -- deck across the ridge (4.4 m)
local Y0, Y1 = 3.0, 8.35 -- deck along the ridge (to just past the back verge)
local TOP = 11.30 -- deck surface
local RAIL = 1.1
local WALL_Y = 8.1 -- outer face of the hall's back gable
local LADDER_X, LADDER_Y = -5.25, 8.52 -- ladder centre line, 0.42 m off the stone

local GALV = Color3.fromRGB(146, 151, 153) -- weathered hot-dip galvanising
local DECKING = Color3.fromRGB(163, 136, 104) -- silvering hardwood decking
local TEAK = Color3.fromRGB(122, 86, 54)
local BLACK = Color3.fromRGB(28, 30, 32)
local ENAMEL = Color3.fromRGB(22, 40, 66) -- navy vitreous enamel sign
local CREAM = Color3.fromRGB(236, 230, 214)

local function toLocal(x: number, y: number, z: number): Vector3
	return Vector3.new(-x * S, z * S, (y + DY) * S)
end

type Ctx = { pivot: CFrame, folder: Folder }

local function box(
	c: Ctx,
	name: string,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	material: Enum.Material,
	color: Color3,
	collide: boolean?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = collide == true
	p.CastShadow = true
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(
		math.max(math.abs(x1 - x0) * S, 0.05),
		math.max(math.abs(z1 - z0) * S, 0.05),
		math.max(math.abs(y1 - y0) * S, 0.05)
	)
	p.CFrame = c.pivot * CFrame.new(toLocal((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
	p.Parent = c.folder
	return p
end

local function roofZ(x: number): number
	return RIDGE_Z - math.abs(x - RIDGE_X) * PITCH
end

-- a steel post (square hollow section) from the slates up to z1
local function post(c: Ctx, x: number, y: number, z1: number)
	local h = 0.04
	box(c, "Post", x - h, y - h, roofZ(x) - 0.05, x + h, y + h, z1, Enum.Material.Metal, GALV)
	-- base plate on the slates
	box(
		c,
		"PostFoot",
		x - 0.09,
		y - 0.09,
		roofZ(x) - 0.06,
		x + 0.09,
		y + 0.09,
		roofZ(x) + 0.01,
		Enum.Material.Metal,
		GALV
	)
end

local function platform(c: Ctx)
	-- bearers along the ridge, joists across
	for _, x in { X0 + 0.1, RIDGE_X, X1 - 0.1 } do
		box(
			c,
			"Bearer",
			x - 0.05,
			Y0,
			TOP - 0.24,
			x + 0.05,
			Y1,
			TOP - 0.03,
			Enum.Material.Metal,
			GALV
		)
	end
	local y = Y0
	while y <= Y1 + 0.001 do
		box(
			c,
			"Joist",
			X0,
			y - 0.025,
			TOP - 0.13,
			X1,
			y + 0.025,
			TOP - 0.03,
			Enum.Material.Wood,
			DECKING
		)
		y += 0.6
	end
	for _, x in { X0 + 0.1, RIDGE_X, X1 - 0.1 } do
		for _, py in { Y0 + 0.1, (Y0 + Y1) / 2, Y1 - 0.35 } do
			post(c, x, py, TOP - 0.24)
		end
	end
	-- decking boards across the ridge (120 mm boards, 8 mm gaps), one walkable slab under them
	local walk =
		box(c, "DeckWalk", X0, Y0, TOP - 0.04, X1, Y1, TOP, Enum.Material.Wood, DECKING, true)
	walk.Transparency = 1
	local yb = Y0
	local i = 0
	while yb + 0.12 <= Y1 + 0.001 do
		i += 1
		local shade = if i % 3 == 0 then 0.94 elseif i % 3 == 1 then 1.0 else 0.97
		box(
			c,
			"Board",
			X0,
			yb,
			TOP - 0.03,
			X1,
			yb + 0.12,
			TOP,
			Enum.Material.WoodPlanks,
			Color3.new(DECKING.R * shade, DECKING.G * shade, DECKING.B * shade)
		)
		yb += 0.128
	end
	-- edge fascia
	box(c, "Fascia", X0 - 0.03, Y0, TOP - 0.2, X0, Y1, TOP, Enum.Material.Wood, DECKING)
	box(c, "Fascia", X1, Y0, TOP - 0.2, X1 + 0.03, Y1, TOP, Enum.Material.Wood, DECKING)
	box(c, "Fascia", X0, Y0 - 0.03, TOP - 0.2, X1, Y0, TOP, Enum.Material.Wood, DECKING)
	box(c, "Fascia", X0, Y1, TOP - 0.2, X1, Y1 + 0.03, TOP, Enum.Material.Wood, DECKING)
end

-- railing along one edge: posts, top rail, knee rail, toe board; `gap` = { from, to } left open
local function railRun(
	c: Ctx,
	alongX: boolean,
	fixed: number,
	a: number,
	b: number,
	gap: { number }?
)
	local function seg(s0: number, s1: number)
		if s1 - s0 < 0.05 then
			return
		end
		local function bar(
			z0: number,
			z1: number,
			w: number,
			name: string,
			mat: Enum.Material,
			col: Color3
		)
			if alongX then
				box(c, name, s0, fixed - w, z0, s1, fixed + w, z1, mat, col)
			else
				box(c, name, fixed - w, s0, z0, fixed + w, s1, z1, mat, col)
			end
		end
		bar(TOP + RAIL - 0.06, TOP + RAIL, 0.035, "TopRail", Enum.Material.Metal, GALV)
		bar(TOP + 0.53, TOP + 0.57, 0.02, "KneeRail", Enum.Material.Metal, GALV)
		bar(TOP, TOP + 0.1, 0.012, "ToeBoard", Enum.Material.Metal, GALV)
	end
	if gap then
		seg(a, gap[1])
		seg(gap[2], b)
	else
		seg(a, b)
	end
	local n = math.max(1, math.ceil((b - a) / 1.3))
	for k = 0, n do
		local s = a + (b - a) * k / n
		if not gap or s <= gap[1] + 0.01 or s >= gap[2] - 0.01 then
			if alongX then
				box(
					c,
					"RailPost",
					s - 0.025,
					fixed - 0.025,
					TOP,
					s + 0.025,
					fixed + 0.025,
					TOP + RAIL,
					Enum.Material.Metal,
					GALV
				)
			else
				box(
					c,
					"RailPost",
					fixed - 0.025,
					s - 0.025,
					TOP,
					fixed + 0.025,
					s + 0.025,
					TOP + RAIL,
					Enum.Material.Metal,
					GALV
				)
			end
		end
	end
end

local function railings(c: Ctx)
	local e = 0.04
	railRun(c, false, X0 + e, Y0 + e, Y1 - e)
	railRun(c, false, X1 - e, Y0 + e, Y1 - e)
	railRun(c, true, Y0 + e, X0 + e, X1 - e)
	-- back edge: the ladder comes up through a self-closing gate
	local g0, g1 = LADDER_X - 0.3, LADDER_X + 0.3
	railRun(c, true, Y1 - e, X0 + e, X1 - e, { g0, g1 })
	box(
		c,
		"GateBar",
		g0 + 0.02,
		Y1 - 0.2,
		TOP + RAIL - 0.05,
		g1 - 0.02,
		Y1 - 0.16,
		TOP + RAIL - 0.01,
		Enum.Material.Metal,
		GALV
	)
	box(
		c,
		"GateBar",
		g0 + 0.02,
		Y1 - 0.2,
		TOP + 0.53,
		g1 - 0.02,
		Y1 - 0.16,
		TOP + 0.57,
		Enum.Material.Metal,
		GALV
	)
	box(
		c,
		"GateStile",
		g1 - 0.05,
		Y1 - 0.2,
		TOP + 0.05,
		g1 - 0.01,
		Y1 - 0.16,
		TOP + RAIL,
		Enum.Material.Metal,
		GALV
	)
	-- invisible fall guard above the railing (players jump higher than a real handrail)
	local h = TOP + 3.2
	for _, w in
		{
			{ X0 - 0.02, Y0, X0, Y1 },
			{ X1, Y0, X1 + 0.02, Y1 },
			{ X0, Y0 - 0.02, X1, Y0 },
			{ X0, Y1, X1, Y1 + 0.02 },
		}
	do
		local p = box(
			c,
			"FallGuard",
			w[1],
			w[2],
			TOP,
			w[3],
			w[4],
			h,
			Enum.Material.SmoothPlastic,
			GALV,
			true
		)
		p.Transparency = 1
		p.CastShadow = false
	end
end

local function bench(c: Ctx)
	-- teak slatted bench against the back rail, facing the sea (-Y)
	local bx0, bx1 = X0 + 0.45, LADDER_X - 0.55
	local by = Y1 - 0.75
	for k = 0, 3 do
		local y0 = by - 0.21 + k * 0.105
		box(c, "Slat", bx0, y0, TOP + 0.42, bx1, y0 + 0.085, TOP + 0.45, Enum.Material.Wood, TEAK)
	end
	for k = 0, 2 do
		local z0 = TOP + 0.55 + k * 0.12
		box(c, "BackSlat", bx0, by + 0.24, z0, bx1, by + 0.27, z0 + 0.085, Enum.Material.Wood, TEAK)
	end
	for _, x in { bx0 + 0.05, bx1 - 0.09 } do
		box(c, "Leg", x, by - 0.2, TOP, x + 0.045, by - 0.155, TOP + 0.42, Enum.Material.Wood, TEAK)
		box(c, "Leg", x, by + 0.2, TOP, x + 0.045, by + 0.27, TOP + 0.9, Enum.Material.Wood, TEAK)
		box(
			c,
			"Arm",
			x - 0.01,
			by - 0.24,
			TOP + 0.62,
			x + 0.055,
			by + 0.25,
			TOP + 0.65,
			Enum.Material.Wood,
			TEAK
		)
	end
	-- a seat the player can sit on
	local seat = Instance.new("Seat")
	seat.Name = "BenchSeat"
	seat.Anchored = true
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Size = Vector3.new((bx1 - bx0) * S * 0.8, 0.2, 1.2)
	seat.CFrame = c.pivot
		* CFrame.new(toLocal((bx0 + bx1) / 2, by, TOP + 0.45))
		* CFrame.Angles(0, 0, 0)
	seat.Parent = c.folder
end

local function binoculars(c: Ctx)
	-- pedestal lookout binoculars (big-eye style) at the front rail, looking out to sea
	local x, y = LADDER_X + 0.9, Y0 + 0.45
	box(
		c,
		"PedestalBase",
		x - 0.16,
		y - 0.16,
		TOP,
		x + 0.16,
		y + 0.16,
		TOP + 0.03,
		Enum.Material.Metal,
		GALV
	)
	box(
		c,
		"Pedestal",
		x - 0.045,
		y - 0.045,
		TOP + 0.03,
		x + 0.045,
		y + 0.045,
		TOP + 1.12,
		Enum.Material.Metal,
		GALV
	)
	box(
		c,
		"Yoke",
		x - 0.12,
		y - 0.04,
		TOP + 1.12,
		x + 0.12,
		y + 0.04,
		TOP + 1.16,
		Enum.Material.Metal,
		BLACK
	)
	for _, dx in { -0.07, 0.07 } do
		local barrel = Instance.new("Part")
		barrel.Name = "Barrel"
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Anchored = true
		barrel.CanCollide = false
		barrel.CanQuery = false
		barrel.Material = Enum.Material.SmoothPlastic
		barrel.Color = BLACK
		barrel.Size = Vector3.new(0.34 * S, 0.11 * S, 0.11 * S)
		-- cylinder axis is local X: turn it to point along the sea direction (-Y metres = -Z studs)
		barrel.CFrame = c.pivot
			* CFrame.new(toLocal(x + dx, y - 0.05, TOP + 1.24))
			* CFrame.Angles(0, math.rad(90), 0)
			* CFrame.Angles(0, 0, math.rad(4))
		barrel.Parent = c.folder
		local eye = barrel:Clone()
		eye.Name = "Eyecup"
		eye.Size = Vector3.new(0.05 * S, 0.08 * S, 0.08 * S)
		eye.CFrame = c.pivot
			* CFrame.new(toLocal(x + dx, y + 0.14, TOP + 1.25))
			* CFrame.Angles(0, math.rad(90), 0)
		eye.Parent = c.folder
	end
end

local function ladder(c: Ctx): (number, number)
	local x0, x1 = LADDER_X - 0.225, LADDER_X + 0.225
	local y = LADDER_Y
	local top = TOP + RAIL
	-- stiles (flat bar) and round rungs every 300 mm
	for _, x in { x0, x1 } do
		box(c, "Stile", x - 0.03, y - 0.008, 0, x + 0.03, y + 0.008, top, Enum.Material.Metal, GALV)
	end
	local z = 0.3
	while z < TOP - 0.05 do
		box(
			c,
			"Rung",
			x0,
			y - 0.013,
			z - 0.013,
			x1,
			y + 0.013,
			z + 0.013,
			Enum.Material.Metal,
			GALV
		)
		z += 0.3
	end
	-- wall brackets back to the granite
	local zb = 0.6
	while zb < roofZ(LADDER_X) + 0.5 and zb < 9.6 do
		for _, x in { x0, x1 } do
			box(
				c,
				"Bracket",
				x - 0.025,
				WALL_Y,
				zb - 0.025,
				x + 0.025,
				y,
				zb + 0.025,
				Enum.Material.Metal,
				GALV
			)
		end
		zb += 1.8
	end
	-- safety cage: hoops (three flat-bar sides) every 0.9 m from 2.5 m, five vertical straps
	local cy = y + 0.7
	local zh = 2.5
	while zh <= top - 0.1 do
		box(
			c,
			"Hoop",
			x0 - 0.12,
			cy - 0.01,
			zh,
			x1 + 0.12,
			cy + 0.01,
			zh + 0.05,
			Enum.Material.Metal,
			GALV
		)
		box(c, "Hoop", x0 - 0.13, y, zh, x0 - 0.11, cy, zh + 0.05, Enum.Material.Metal, GALV)
		box(c, "Hoop", x1 + 0.11, y, zh, x1 + 0.13, cy, zh + 0.05, Enum.Material.Metal, GALV)
		zh += 0.9
	end
	for _, s in
		{
			{ x0 - 0.12, y + 0.35 },
			{ x1 + 0.12, y + 0.35 },
			{ x0, cy },
			{ LADDER_X, cy },
			{ x1, cy },
		}
	do
		local sx, sy = s[1], s[2]
		box(
			c,
			"CageStrap",
			sx - 0.012,
			sy - 0.012,
			2.5,
			sx + 0.012,
			sy + 0.012,
			top,
			Enum.Material.Metal,
			GALV
		)
	end
	-- padlocked anti-climb guard over the bottom rungs
	box(
		c,
		"Guard",
		x0 - 0.04,
		y + 0.03,
		0.25,
		x1 + 0.04,
		y + 0.045,
		2.4,
		Enum.Material.DiamondPlate,
		GALV
	)
	box(
		c,
		"Padlock",
		x1 + 0.02,
		y + 0.045,
		1.3,
		x1 + 0.07,
		y + 0.07,
		1.37,
		Enum.Material.Metal,
		Color3.fromRGB(150, 118, 58)
	)
	return cy, top
end

local function sign(c: Ctx)
	-- enamel plate on the gable stone beside the ladder foot
	local x0, x1 = LADDER_X - 1.35, LADDER_X - 0.55
	local plate = box(
		c,
		"VipSign",
		x0,
		WALL_Y,
		1.35,
		x1,
		WALL_Y + 0.012,
		1.9,
		Enum.Material.SmoothPlastic,
		ENAMEL
	)
	plate.Reflectance = 0.04
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignText"
	gui.Face = Enum.NormalId.Back -- +Z studs = +Y metres = out of the back wall
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = 1
	gui.Parent = plate
	local border = Instance.new("Frame")
	border.BackgroundTransparency = 1
	border.Size = UDim2.new(1, -16, 1, -16)
	border.Position = UDim2.fromOffset(8, 8)
	border.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = CREAM
	stroke.Thickness = 3
	stroke.Parent = border
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = border
	local function line(text: string, y: number, h: number, size: number, bold: boolean)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, -24, 0, h)
		l.Position = UDim2.fromOffset(12, y)
		l.Text = text
		l.TextColor3 = CREAM
		l.TextSize = size
		l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
		l.Parent = border
	end
	line("ROOF DECK", 20, 50, 44, true)
	line("VIP Crew Card holders", 76, 40, 30, false)
	line("Thank you for keeping the ladder clear", 118, 30, 20, false)
end

local function anchor(c: Ctx, name: string, which: string, at: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = c.pivot * CFrame.new(at)
	p:SetAttribute("VipDeck", which)
	p.Parent = c.folder
	CollectionService:AddTag(p, "VipDeckLadder")
	return p
end

function VipDeck.build(asset: Model): Deck
	local folder = Instance.new("Folder")
	folder.Name = "VipDeck"
	local pivot = asset:GetPivot()
	local c: Ctx = { pivot = pivot, folder = folder }
	platform(c)
	railings(c)
	bench(c)
	binoculars(c)
	local cy = ladder(c)
	sign(c)
	local foot = anchor(c, "LadderFoot", "Foot", toLocal(LADDER_X, cy + 0.2, 1.2))
	local head = anchor(c, "LadderHead", "Head", toLocal(LADDER_X, Y1 - 0.5, TOP + 1.0))
	local seaward = pivot * CFrame.new(toLocal(RIDGE_X, Y0 - 50, TOP))
	local headPos = (pivot * CFrame.new(toLocal(RIDGE_X, (Y0 + Y1) / 2, TOP + 1.05))).Position
	local footPos = (pivot * CFrame.new(toLocal(LADDER_X, cy + 1.3, 1.05))).Position
	local wallPos = (pivot * CFrame.new(toLocal(LADDER_X, WALL_Y, 1.05))).Position
	folder.Parent = asset.Parent or asset
	return {
		folder = folder,
		foot = foot,
		head = head,
		footStand = CFrame.lookAt(footPos, Vector3.new(wallPos.X, footPos.Y, wallPos.Z)),
		headStand = CFrame.lookAt(
			headPos,
			Vector3.new(seaward.Position.X, headPos.Y, seaward.Position.Z)
		),
		volume = pivot * CFrame.new(toLocal(RIDGE_X, (Y0 + Y1) / 2, TOP + 1.6)),
		volumeSize = Vector3.new((X1 - X0) * S + 1, 3.6 * S, (Y1 - Y0) * S + 1),
	}
end

return VipDeck
