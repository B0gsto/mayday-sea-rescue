--!strict
-- DeepSpin/Set: the spinner's private stage, client only, built on press and destroyed on the way out: the hero wheel
-- (flat sprites on Parts, as the reference draws it), claws, the fake plaza + rock shaft + water, and the Deep below.
-- All of it sits ALTITUDE studs over the island so the real ocean and island can never cut into the shot; the camera
-- looks along +Z of the set, so one backdrop wall closes the Deep. Nothing here is visible to other players.
-- Local axes: y up, -z toward the camera, screen right = -x. Screen layouts come from the reference, in H (the frame's
-- height at the wheel) and U (H / 100).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
)
local SpinCurve = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpinCurve"))

local Art = (AssetIds :: any).DeepSpin :: { [string]: string }
local M = Enum.Material
local rgb = Color3.fromRGB

local Set = {}

Set.R = 7 -- the wheel's radius in studs
Set.H = Set.R / 0.36 -- reference: R = 0.36 H at zoom 1
Set.U = Set.H / 100
Set.DIST = 26 -- camera to wheel
local H, U, R = Set.H, Set.U, Set.R
local ALTITUDE = 1800
local GROUND = -10 -- the plaza under the hub, as on the real wheel (PrizeWheel WHEEL_Y)
Set.WATER = GROUND - SpinCurve.SOIL_H * H
Set.DEEP = -SpinCurve.FALL_H * H -- where the fall ends, in the set's y
local WATER, DEEP = Set.WATER, Set.DEEP
local HW = 11 -- the shaft's half width
local STUDS = "rbxassetid://18878365966"
local SOIL = {
	rgb(122, 79, 43),
	rgb(107, 68, 38),
	rgb(92, 58, 32),
	rgb(77, 58, 44),
	rgb(70, 70, 79),
	rgb(57, 58, 69),
	rgb(45, 46, 58),
}

export type Stage = {
	folder: Folder,
	origin: CFrame, -- the set's frame: hub height, the real wheel's rotation, up in the sky
	rotor: Decal,
	blur: Decal,
	wedge: Decal,
	place: (self: Stage, frame: CFrame, angle: number, flap: number) -> (),
	setBlur: (self: Stage, k: number) -> (),
	setWedge: (self: Stage, segment: number?, lift: number, alpha: number) -> (),
	setDim: (self: Stage, rotorDim: number, fade: number) -> (),
	setClaws: (self: Stage, frame: CFrame, p: number, jitter: number) -> (),
	setBulbs: (self: Stage, t: number, sw: number) -> (),
	setVortex: (self: Stage, frame: CFrame, sw: number, a: number) -> (),
	setGlow: (
		self: Stage,
		frame: CFrame,
		color: Color3,
		amount: number,
		rays: number,
		t: number
	) -> (),
	setStand: (self: Stage, ground: CFrame, broken: number, visible: boolean) -> (),
	setCracks: (self: Stage, k: number) -> (),
	showCracks: (self: Stage, ground: CFrame?) -> (),
	throwPlates: (self: Stage, color: Color3) -> (),
	stepPlates: (self: Stage, dt: number) -> (),
	showDeep: (self: Stage) -> (),
	dropShaft: (self: Stage) -> (),
	stepDeep: (self: Stage, t: number, boost: number) -> (),
}

local function rnd(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
		true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a flat sprite: a clear Part carrying one decal on its camera-side face
local function sprite(
	parent: Instance,
	name: string,
	id: string,
	size: number,
	h: number?
): (Part, Decal)
	local p =
		part(parent, name, Vector3.new(size, h or size, 0.02), CFrame.new(), Color3.new(1, 1, 1))
	p.Transparency = 1
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Front
	d.Texture = id
	d.Parent = p
	return p, d
end

local function studTop(p: BasePart, tint: Color3)
	local t = Instance.new("Texture")
	t.Face = Enum.NormalId.Top
	t.Texture = STUDS
	t.StudsPerTileU, t.StudsPerTileV = 8, 8
	t.Color3 = tint
	t.Parent = p
end

local function darken(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

-- the claw: a yellow Lego block with two jaws hugging the rim, on a navy rail running off screen, on the `side` of x
local function buildClaw(parent: Instance, side: number): Model
	local model = Instance.new("Model")
	model.Name = "Claw"
	local yellow, dark = rgb(244, 194, 13), rgb(35, 40, 47)
	local function block(
		name: string,
		x0: number,
		x1: number,
		y0: number,
		y1: number,
		color: Color3,
		depth: number?
	): Part
		local w, h = (x1 - x0) * U, (y1 - y0) * U
		local at = CFrame.new(side * (x0 + x1) / 2 * U, (y0 + y1) / 2 * U, -0.5)
		return part(model, name, Vector3.new(w, h, depth or 1.2), at, color)
	end
	local rail = block("Rail", 9, 90, -2.5, 2.5, rgb(31, 58, 110), 0.9)
	studTop(rail, rgb(107, 142, 199))
	local body = block("Body", 1, 12, -10, 10, yellow)
	studTop(body, darken(yellow, 0.85))
	block("JawTop", -6, 6, 8, 14, yellow)
	block("JawLow", -6, 6, -14, -8, yellow)
	block("Rubber", -7, -3.8, -9, 9, dark, 1.04)
	block("Pad", -4, 1, -8, 8, rgb(214, 48, 45), 1.08)
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new() -- PivotTo places the rim contact point
	model.Parent = parent
	return model
end

local function buildWheel(self: any, folder: Instance)
	self.back = part(
		folder,
		"Back",
		Vector3.new(1.2, R * 2.2, R * 2.2),
		CFrame.new(),
		rgb(20, 43, 86),
		nil,
		Enum.PartType.Cylinder
	)
	self.rotorPart, self.rotor = sprite(folder, "Rotor", Art.rotor, R * 0.975 * 2)
	self.blurPart, self.blur = sprite(folder, "Blur", Art.blur, R * 0.975 * 2)
	self.blur.Transparency = 1
	self.wedgePart, self.wedge = sprite(folder, "Wedge", Art.wedge1, R * 0.975 * 2)
	self.wedge.Transparency = 1
	self.housingPart, self.housing = sprite(folder, "Housing", Art.housing, R * 2.2)
	self.flapperPart, self.flapper = sprite(folder, "Flapper", Art.flapper, 18 * U)
	self.bulbs = {}
	for i = 1, 24 do
		local a = (i - 0.5) / 24 * math.pi * 2
		local at = CFrame.new(math.cos(a) * R * 1.035, math.sin(a) * R * 1.035, -0.3)
		table.insert(self.bulbs, {
			part = part(
				folder,
				"Bulb",
				Vector3.one * 0.36,
				at,
				rgb(255, 225, 120),
				M.SmoothPlastic,
				Enum.PartType.Ball
			),
			at = at,
		})
	end
	self.claws = { buildClaw(folder, 1), buildClaw(folder, -1) }
	-- the Deep's and the shaft's own light: Set parts lit the same at noon and midnight
	local lamp = part(folder, "Lamp", Vector3.one, CFrame.new(), Color3.new(1, 1, 1))
	lamp.Transparency = 1
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Shadows = 44, 1.6, false
	light.Parent = lamp
	self.lamp = lamp
	self.vortexPart, self.vortex = sprite(folder, "Vortex", Art.vortex, 150)
	self.vortex2Part, self.vortex2 = sprite(folder, "Vortex2", Art.vortex, 100)
	self.vortex.Transparency, self.vortex2.Transparency = 1, 1
	self.raysPart, self.rays = sprite(folder, "Rays", Art.rays, 60)
	self.glowPart, self.glow = sprite(folder, "Glow", "rbxassetid://136452411239756", 44)
	self.rays.Transparency, self.glow.Transparency = 1, 1
end

-- columns and the base: the real stand is hidden locally while this one breaks
local function buildStand(self: any, folder: Instance)
	self.columns = {}
	for _, side in { 1, -1 } do
		local model = Instance.new("Model")
		model.Name = "Column"
		local h = -GROUND
		local post = part(
			model,
			"Post",
			Vector3.new(1.1, h, 1.1),
			CFrame.new(side * R * 0.78, h / 2, 0.9),
			rgb(246, 244, 238)
		)
		for k = 1, 3 do
			part(
				model,
				"Band",
				Vector3.new(1.2, 0.5, 1.2),
				CFrame.new(side * R * 0.78, h * (k / 4), 0.9),
				rgb(214, 48, 45)
			)
		end
		model.PrimaryPart = post
		model.WorldPivot = CFrame.new(side * R * 0.78, 0, 0.9)
		model.Parent = folder
		table.insert(
			self.columns,
			{ model = model, side = side, at = CFrame.new(side * R * 0.78, 0, 0.9) }
		)
	end
	self.base = part(folder, "Base", Vector3.new(R * 2.3, 0.8, 4), CFrame.new(), rgb(31, 58, 110))
	studTop(self.base, rgb(53, 89, 143))
end

-- the plaza the fall starts from (its real colour), the jagged shaft of Lego strata and the water at the bottom
local function buildShaft(self: any, parent: Instance, grass: Color3)
	local O = self.origin
	local folder = Instance.new("Folder")
	folder.Name = "Shaft"
	folder.Parent = parent
	self.shaft = folder
	local plazas = Instance.new("Folder")
	plazas.Name = "Plaza"
	plazas.Parent = parent
	self.plazas = plazas
	local tint = darken(grass, 0.82)
	local function plaza(size: Vector3, at: CFrame)
		studTop(part(plazas, "Plaza", size, O * at, grass), tint)
	end
	plaza(Vector3.new(300, 1.6, 400), CFrame.new(HW + 150, GROUND - 0.8, 150))
	plaza(Vector3.new(300, 1.6, 400), CFrame.new(-HW - 150, GROUND - 0.8, 150))
	plaza(Vector3.new(HW * 2, 1.6, 300), CFrame.new(0, GROUND - 0.8, 158))
	local rowH = 6 * U
	local rows = math.ceil((GROUND - WATER) / rowH)
	local function seams(p: BasePart, face: Enum.NormalId, shift: number)
		local t = Instance.new("Texture")
		t.Face = face
		t.Texture = Art.strata
		t.StudsPerTileU, t.StudsPerTileV = 28 * U, rowH
		t.OffsetStudsU = shift
		t.Parent = p
	end
	for r = 0, rows - 1 do
		local y = GROUND - 1.6 - (r + 0.5) * rowH
		local c = SOIL[math.min(#SOIL, math.floor(r * #SOIL / 13) + 1)]
		local shift = (r % 2) * 14 * U
		for _, side in { 1, -1 } do
			local jag = rnd(0, 1.3) -- the walls step in and out, row by row
			local wall = part(
				folder,
				"Strata",
				Vector3.new(6, rowH, 48),
				O * CFrame.new(side * (HW + 3 - jag), y, -16),
				c
			)
			seams(wall, if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left, shift)
		end
		local back = part(
			folder,
			"ShaftBack",
			Vector3.new(HW * 2 + 2, rowH, 2),
			O * CFrame.new(0, y, 9),
			darken(c, 0.45)
		)
		seams(back, Enum.NormalId.Front, shift)
	end
	local water = part(
		folder,
		"Water",
		Vector3.new(HW * 2 + 4, 0.2, 56),
		O * CFrame.new(0, WATER, -16),
		rgb(43, 185, 204)
	)
	water.Transparency = 0.1
	-- a foam crown along the broken underside, bricks hanging off it
	for i = 1, 26 do
		local x = -HW + (i - 0.5) / 26 * HW * 2
		part(
			folder,
			"Foam",
			Vector3.one * rnd(0.9, 1.7),
			O * CFrame.new(x, WATER + rnd(0, 0.3), 7.4),
			rgb(255, 255, 255),
			M.SmoothPlastic,
			Enum.PartType.Ball
		)
	end
	for _ = 1, 10 do
		part(
			folder,
			"Drip",
			Vector3.new(1.4, rnd(0.5, 2), 1),
			O * CFrame.new(rnd(-HW, HW), WATER - rnd(0.2, 1), 8.5),
			SOIL[#SOIL]
		)
	end
end

-- stepped cracks: right-angle walks along the brick grid, one SurfaceGui so they cost one Part (the real plaza's top)
local function buildCracks(self: any, folder: Instance)
	local size = 70
	local p = part(folder, "Cracks", Vector3.new(size, 0.02, size), CFrame.new(), Color3.new())
	p.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.LightInfluence = 0.3
	gui.Parent = p
	self.crackPart, self.crackGui = p, gui
	self.crackSteps = {}
	local mid = size * 10 / 2
	local function seg(x0: number, y0: number, x1: number, y1: number, width: number, k: number)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = rgb(30, 20, 8)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(mid + (x0 + x1) / 2, mid + (y0 + y1) / 2)
		f.Size = UDim2.fromOffset(math.abs(x1 - x0) + width, math.abs(y1 - y0) + width)
		f.Visible = false
		f.Parent = gui
		local lit = Instance.new("Frame")
		lit.BorderSizePixel = 0
		lit.BackgroundColor3 = rgb(169, 236, 147)
		lit.AnchorPoint = Vector2.new(0, 1)
		lit.Position = UDim2.new(0, 0, 1, math.ceil(width * 0.35))
		lit.Size = UDim2.new(1, 0, 0, math.ceil(width * 0.3))
		lit.ZIndex = 0
		lit.Parent = f
		table.insert(self.crackSteps, { frame = f, at = k })
	end
	for i = 1, 10 do
		local dir = if i % 2 == 0 then 1 else -1
		local x, y = 0, 0
		local steps = math.random(4, 6)
		local dy = rnd(-1.2, 1.6)
		for k = 1, steps do
			local nx = x + dir * rnd(32, 62)
			local width = 10 * (1 - k / (steps + 1)) + 2
			seg(x, y, nx, y, width, (k - 1) / steps)
			x = nx
			local ny = y + ((if k % 2 == 0 then 1 else -1) * rnd(12, 24) + dy * 10)
			seg(x, y, x, ny, width, (k - 0.5) / steps)
			y = ny
		end
	end
end

-- the pooled plates and dirt that erupt from the hole: anchored, thrown by hand, reused on nothing else
local function buildPlates(self: any, folder: Instance)
	self.plates = {}
	for i = 1, 46 do
		local big = i <= 22
		local p = part(
			folder,
			"Plate",
			if big
				then Vector3.new(rnd(3, 5.5), 0.7, rnd(3, 5.5))
				else Vector3.new(rnd(0.5, 1), 0.5, rnd(0.5, 1)),
			CFrame.new(),
			if big then rgb(79, 191, 70) elseif i % 3 == 0 then rgb(92, 58, 32) else rgb(122, 79, 43)
		)
		if big then
			studTop(p, rgb(111, 215, 99))
		end
		p.Transparency = 1
		self.plates[i] = { part = p, big = big, life = 0 }
	end
end

-- the Deep: backdrop, reef layers, kelp, rays, a whale, jellies, lost bricks; `low` skips what costs and adds least
local function buildDeep(self: any, folder: Instance, low: boolean)
	local O = self.origin * CFrame.new(0, DEEP, 0)
	self.deepO = O
	local wall = part(
		folder,
		"Backdrop",
		Vector3.new(800, 420, 1),
		O * CFrame.new(0, 0, 165),
		rgb(2, 20, 42)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 1
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Parent = wall
	wall.Transparency = 1
	self.backdrop = gui
	local sky = Instance.new("Frame")
	sky.BorderSizePixel = 0
	sky.Size = UDim2.fromScale(1, 1)
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(16, 110, 134)),
		ColorSequenceKeypoint.new(0.34, rgb(8, 74, 104)),
		ColorSequenceKeypoint.new(0.62, rgb(3, 38, 70)),
		ColorSequenceKeypoint.new(1, rgb(1, 12, 34)),
	})
	grad.Parent = sky

	local depth = Instance.new("Folder")
	depth.Name = "Deep"
	depth.Parent = folder
	self.deepFolder = depth

	local function k(z: number): number
		return (Set.DIST + z) / Set.DIST
	end
	-- reefs: jagged brick silhouettes, tallest at the frame's edges so the wheel stays clear
	local tones = { rgb(7, 48, 79), rgb(5, 37, 66), rgb(3, 26, 51) }
	for l = 0, 2 do
		local z = 70 - l * 26
		local base = -(0.19 + l * 0.09) * H * k(z)
		local x = -1.15 * H * k(z)
		while x < 1.15 * H * k(z) do
			local w = rnd(0.07, 0.16) * H * k(z)
			local edge = math.min(math.abs(x) / (0.9 * H * k(z)), 1) ^ 1.6
			local top = base + (0.03 + edge * (0.2 - l * 0.05)) * H * k(z) * rnd(0.8, 1.1)
			local bottom = base - 60
			part(
				depth,
				"Reef",
				Vector3.new(w, top - bottom, 6),
				O * CFrame.new(x + w / 2, (top + bottom) / 2, z),
				tones[l + 1]
			)
			x += w
		end
	end
	-- rays and kelp are Beams: cheap, unlit, and they sway by curve alone
	local host = part(depth, "Beams", Vector3.one, O, Color3.new())
	host.Transparency = 1
	local function beam(
		a: Vector3,
		b: Vector3,
		width: number,
		color: Color3,
		seq: NumberSequence?,
		glow: number?
	): Beam
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = a, b
		a0.Parent, a1.Parent = host, host
		local bm = Instance.new("Beam")
		bm.Attachment0, bm.Attachment1 = a0, a1
		bm.Width0, bm.Width1 = width, width * (if glow then 2.2 else 0.5)
		bm.Color = ColorSequence.new(color)
		bm.Transparency = seq or NumberSequence.new(0)
		bm.LightEmission = glow or 0
		bm.LightInfluence = 0
		bm.FaceCamera = true
		bm.Segments = 10
		bm.Parent = host
		return bm
	end
	local rayFade = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.6, 0.86),
		NumberSequenceKeypoint.new(1, 1),
	})
	for i = 1, if low then 3 else 6 do
		local x = -60 + (i - 0.5) * (if low then 40 else 20)
		beam(
			Vector3.new(x + 16, 60, 110),
			Vector3.new(x - 16, -36, 110),
			rnd(6, 13),
			rgb(64, 190, 216),
			rayFade,
			0.35
		)
	end
	self.kelp = {}
	if not low then
		for i = 1, 20 do
			local side = if i % 2 == 0 then 1 else -1
			local layer = i % 4 == 0
			local z = if layer then 44 else 24
			local x = side * rnd(0.5, 1) * 0.9 * H * k(z)
			local baseY = -(0.3 + (if layer then 0.09 else 0)) * H * k(z)
			local height = rnd(0.2, 0.55) * H * k(z)
			local bm = beam(
				Vector3.new(x, baseY, z),
				Vector3.new(x, baseY + height, z),
				rnd(1, 1.9) * U * k(z) * 1.6,
				if layer then rgb(10, 74, 76) else rgb(12, 94, 88)
			)
			table.insert(self.kelp, { beam = bm, phase = rnd(0, 6.28), sway = height * 0.09 })
		end
	end
	-- the whale: a slow, huge silhouette; a smooth body (blocks read as a glitch at this size), head screen right
	local whale = Instance.new("Model")
	whale.Name = "Whale"
	local s = 2.6 * U * k(70)
	local function blob(c: CFrame, size: Vector3, color: Color3): Part
		local b = part(whale, "Blob", Vector3.one, c, color)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = size
		mesh.Parent = b
		return b
	end
	local blue = rgb(16, 82, 127)
	local body = blob(CFrame.new(), Vector3.new(44, 13, 13) * s, blue)
	blob(CFrame.new(-4 * s, -3.2 * s, -0.5 * s), Vector3.new(30, 5.2, 12) * s, rgb(42, 124, 174))
	blob(CFrame.new(-15 * s, 1 * s, -5 * s), Vector3.new(1.6, 1.6, 1.6) * s, rgb(212, 246, 255))
	blob(CFrame.new(26 * s, 0, 0), Vector3.new(20, 6, 6) * s, blue) -- the tail stock
	for _, dy in { 4.5, -4.5 } do
		local fluke = blob(
			CFrame.new(35 * s, dy * s, 0)
				* CFrame.Angles(0, 0, math.rad(if dy > 0 then -48 else 48)),
			Vector3.new(11, 3.2, 3) * s,
			blue
		)
		fluke.Name = "Fluke"
	end
	blob(
		CFrame.new(-4 * s, -8 * s, 0) * CFrame.Angles(0, 0, math.rad(-58)),
		Vector3.new(11, 3, 3) * s,
		blue
	)
	whale.PrimaryPart = body
	whale.Parent = depth
	self.whale = whale
	-- jellies and drifting bricks, the Deep's tiny living lights and its lost toys
	self.jellies = {}
	for i = 1, if low then 2 else 5 do
		local z = rnd(24, 60)
		local c = if i % 2 == 0 then rgb(255, 123, 213) else rgb(92, 242, 255)
		local d = rnd(1.6, 3.2) * U * 0.55 * k(z) * 2.6
		local jelly = Instance.new("Model")
		local dome =
			part(jelly, "Dome", Vector3.one * d, CFrame.new(), c, M.Neon, Enum.PartType.Ball)
		dome.Transparency = 0.42
		for j = -1, 1 do
			local leg = part(
				jelly,
				"Leg",
				Vector3.new(d * 0.1, d * (0.9 + (1 - math.abs(j)) * 0.3), d * 0.1),
				CFrame.new(j * d * 0.28, -d * 0.75, 0),
				c,
				M.Neon
			)
			leg.Transparency = 0.5
		end
		jelly.PrimaryPart = dome
		jelly.Parent = depth
		table.insert(self.jellies, {
			model = jelly,
			at = Vector3.new(rnd(-0.9, 0.9) * H * k(z), rnd(-0.3, 0.35) * H * k(z), z),
			phase = rnd(0, 6.28),
		})
	end
	self.floats = {}
	local colors = {
		rgb(214, 48, 45),
		rgb(244, 194, 13),
		rgb(47, 168, 74),
		rgb(24, 120, 216),
		rgb(244, 244, 238),
	}
	for i = 1, if low then 6 else 14 do
		local z = rnd(10, 52)
		local c = darken(colors[(i - 1) % 5 + 1], 0.6)
		local brick = part(
			depth,
			"LostBrick",
			Vector3.new(rnd(1.2, 2.6), 1, rnd(0.8, 1.3)) * rnd(0.8, 1.5),
			O,
			c
		)
		studTop(brick, darken(c, 1.3))
		table.insert(self.floats, {
			part = brick,
			at = Vector3.new(rnd(-1, 1) * H * k(z), rnd(-0.34, 0.42) * H * k(z), z),
			phase = rnd(0, 6.28),
			spin = rnd(-0.25, 0.25),
			tilt = rnd(0, 6.28),
		})
	end
end

local Stage = {}
Stage.__index = Stage

function Stage.place(self: any, frame: CFrame, angle: number, flap: number)
	local turn = frame * CFrame.Angles(0, 0, math.rad(angle) - math.pi / 2)
	self.back.CFrame = frame * CFrame.new(0, 0, 0.62) * CFrame.Angles(0, math.pi / 2, 0)
	self.rotorPart.CFrame = turn
	self.blurPart.CFrame = turn * CFrame.new(0, 0, -0.06)
	self.wedgePart.CFrame = turn * CFrame.new(0, 0, -0.12)
	self.housingPart.CFrame = frame * CFrame.new(0, 0, -0.18)
	for _, b in self.bulbs do
		b.part.CFrame = frame * b.at
	end
	-- the flapper swings on its pin; screen clockwise = +z rotation
	self.flapperPart.CFrame = frame
		* CFrame.new(0, R * 1.02, -0.36)
		* CFrame.Angles(0, 0, flap)
		* CFrame.new(0, -1.8 * U, 0)
	self.lamp.CFrame = frame * CFrame.new(0, 3, -16)
end

function Stage.setBlur(self: any, k: number)
	self.blur.Transparency = 1 - k
end

function Stage.setWedge(self: any, segment: number?, lift: number, alpha: number)
	if segment then
		self.wedge.Texture = Art[`wedge{segment}`]
	end
	self.wedge.Transparency = 1 - alpha
	self.wedgePart.Size = Vector3.new(R * 0.975 * 2 * lift, R * 0.975 * 2 * lift, 0.02)
end

function Stage.setDim(self: any, rotorDim: number, fade: number)
	local v = 1 - rotorDim
	self.rotor.Color3 = Color3.new(v, v, v)
	for _, d in { self.rotor, self.housing, self.flapper } do
		d.Transparency = fade
	end
	self.back.Transparency = fade
	if self.wedge.Transparency < 1 then
		self.wedge.Transparency = fade
	end
	for _, b in self.bulbs do
		b.part.Transparency = fade
	end
end

function Stage.setClaws(self: any, frame: CFrame, p: number, jitter: number)
	for i, claw in self.claws do
		local side = if i == 1 then 1 else -1
		local x = (R * 1.035 + (1 - p) * 36 * U) * side
		claw:PivotTo(frame * CFrame.new(x, jitter, -0.5))
	end
end

function Stage.setBulbs(self: any, t: number, sw: number)
	for i, b in self.bulbs do
		local br = 0.5 + 0.5 * math.sin(t * (1.8 + sw * 2) - i * 0.9) -- a slow wave, never a strobe
		b.part.Color = Color3.fromRGB(200 + 55 * br, 150 + 90 * br, 35 + 90 * br)
	end
end

function Stage.setVortex(self: any, frame: CFrame, sw: number, a: number)
	self.vortexPart.CFrame = frame * CFrame.new(0, 0, 26) * CFrame.Angles(0, 0, -a)
	self.vortex2Part.CFrame = frame * CFrame.new(0, 0, 18) * CFrame.Angles(0, 0, -a * 0.6 + 1)
	self.vortex.Transparency = 1 - sw * 0.82
	self.vortex2.Transparency = 1 - sw * 0.5
end

function Stage.setGlow(
	self: any,
	frame: CFrame,
	color: Color3,
	amount: number,
	rays: number,
	t: number
)
	self.glowPart.CFrame = frame * CFrame.new(0, 0, 3)
	self.raysPart.CFrame = frame * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, 0, t * 0.2)
	self.glow.Color3, self.rays.Color3 = color, color
	self.glow.Transparency = 1 - amount
	self.rays.Transparency = 1 - rays
end

function Stage.setStand(self: any, ground: CFrame, broken: number, visible: boolean)
	for _, c in self.columns do
		c.model:PivotTo(
			ground
				* c.at
				* CFrame.new(c.side * broken * 16 * U, -broken * 3 * U, 0)
				* CFrame.Angles(0, 0, -c.side * broken * 1.05)
		)
	end
	self.base.CFrame = ground * CFrame.new(0, 0.4, 0.9)
	self.base.Transparency = if visible and broken < 0.05 then 0 else 1
end

function Stage.showCracks(self: any, ground: CFrame?)
	self.crackGui.Enabled = ground ~= nil
	if ground then
		self.crackPart.CFrame = ground * CFrame.new(0, 0.06, 0)
	end
end

function Stage.setCracks(self: any, k: number)
	for _, s in self.crackSteps do
		local on = s.at <= k
		if s.frame.Visible ~= on then
			s.frame.Visible = on
		end
	end
end

-- big plates of ground first, dirt and soil after; in the set's frame, where the camera outruns them
function Stage.throwPlates(self: any, color: Color3)
	for i, pl in self.plates do
		local side = if i % 2 == 0 then 1 else -1
		local x = side * rnd(0, 11)
		pl.at = Vector3.new(x, GROUND + 0.4, rnd(-8, 7))
		local a = side * rnd(0.1, 1.05)
		local sp = rnd(45, if pl.big then 120 else 170) * U * 0.6
		pl.v = Vector3.new(math.sin(a) * sp, math.cos(a) * sp, rnd(-5, 2))
		pl.rot = Vector3.new(rnd(0, 6), rnd(0, 6), rnd(0, 6))
		pl.vr = Vector3.new(rnd(-6, 6), rnd(-6, 6), rnd(-6, 6))
		pl.life = rnd(1, 1.7)
		if pl.big then
			pl.part.Color = if i % 3 == 0 then color:Lerp(Color3.new(1, 1, 1), 0.14) else color
		end
		pl.part.Transparency = 0
	end
end

function Stage.stepPlates(self: any, dt: number)
	local O = self.origin
	for _, pl in self.plates do
		if pl.life > 0 then
			pl.life -= dt
			if pl.life <= 0 then
				pl.part.Transparency = 1
			else
				pl.v += Vector3.new(0, -62 * U * 0.55 * dt, 0)
				pl.at += pl.v * dt
				pl.rot += pl.vr * dt
				pl.part.CFrame = O * CFrame.new(pl.at) * CFrame.Angles(pl.rot.X, pl.rot.Y, pl.rot.Z)
			end
		end
	end
end

-- the plaza stretches past the backdrop: from below its underside would be a tan band across the Deep's sky
function Stage.showDeep(self: any)
	self.backdrop.Enabled = true
	self.plazas:Destroy()
end

function Stage.dropShaft(self: any)
	self.shaft:Destroy()
end

function Stage.stepDeep(self: any, t: number, boost: number)
	local O = self.deepO
	local cycle = ((t % 26) + 26) % 26 / 26
	local z = 70 - boost * 26 -- Mythic pulls it close
	local kz = (Set.DIST + z) / Set.DIST
	local xw = (-0.95 + 1.9 * cycle) * 1.77 * 1.05
	self.whale:PivotTo(O * CFrame.new(-xw * H * kz, (0.26 + 0.02 * math.sin(t * 0.35)) * H * kz, z))
	for _, kelp in self.kelp do
		local sway = math.sin(t * 0.8 + kelp.phase) * kelp.sway
		kelp.beam.CurveSize0, kelp.beam.CurveSize1 = sway, -sway
	end
	for _, j in self.jellies do
		local p = j.at
			+ Vector3.new(math.sin(t * 0.22 + j.phase) * 0.8, math.sin(t * 0.35 + j.phase) * 1.2, 0)
		j.model:PivotTo(O * CFrame.new(p))
	end
	for _, f in self.floats do
		local p = f.at
			+ Vector3.new(math.cos(t * 0.18 + f.phase), math.sin(t * 0.3 + f.phase) * 0.7, 0)
		f.part.CFrame = O * CFrame.new(p) * CFrame.Angles(f.tilt, t * f.spin, f.tilt + t * f.spin)
	end
end

function Set.new(hub: CFrame, grass: Color3, low: boolean): Stage
	local self: any = setmetatable({}, Stage)
	local folder = Instance.new("Folder")
	folder.Name = "DeepSpinSet"
	self.folder = folder
	self.origin = CFrame.new(hub.X, ALTITUDE, hub.Z) * hub.Rotation
	buildWheel(self, folder)
	buildStand(self, folder)
	buildShaft(self, folder, grass)
	buildCracks(self, folder)
	buildPlates(self, folder)
	buildDeep(self, folder, low)
	self:stepDeep(0, 0) -- everything in its place before the wheel falls past it (they are built stacked on the origin)
	folder.Parent = Workspace
	return self
end

return Set
