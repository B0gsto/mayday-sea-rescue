--!strict
-- Greybox land vehicle bodies from parts at real dimensions (LandVehicleConfig, 1 m = 3 studs).
-- Server only. The model's PrimaryPart "Chassis" is an invisible box at the centre of mass that
-- carries all the mass (its density is set to hit spec.mass); every body part is massless,
-- welded to it and collides (scrapes, never breaks). Wheels are massless, non-colliding parts on
-- Welds whose C0 Car/Physics sets each frame (Wheel_FL ... with WheelWeld).
--
-- Exposed for other streams: DriverSeat (VehicleSeat, right-hand drive) with EyePoint
-- (Attachment at the driver's eyes); Seat2..n; on Chassis: TowHitch, CarForce, CarTorque;
-- Headlamp parts (SpotLight), TailLamp / BrakeLamp / ReverseLamp parts, Beacon parts (LampIndex,
-- LampCount, LampColor attributes, a PointLight) for the light bar.
local Chassis = require(script.Parent.Chassis)
local LandVehicleConfig = require(script.Parent.Parent.Config.LandVehicleConfig)

type Spec = LandVehicleConfig.Spec

local Builder = {}

local M = 3
local GROUP = "LandVehicle"
local DARK = Color3.fromRGB(32, 32, 34)
local TYRE = Color3.fromRGB(26, 26, 28)
local RIM = Color3.fromRGB(175, 178, 182)
local GLASS = Color3.fromRGB(60, 80, 95)
local CHROME = Color3.fromRGB(200, 200, 205)

type Ctx = {
	model: Model,
	root: BasePart,
	spec: Spec,
	y0: number, -- ground level in the body frame (studs)
	zFront: number, -- front bumper z (studs)
	zRear: number,
	w: number, -- body width (studs)
}

local function part(
	ctx: Ctx,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = true
	p.CanTouch = false
	p.CollisionGroup = GROUP
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = ctx.model
	return p
end

-- A box from metres in the body frame: x across (right +), y above the ground, z from the front
-- bumper backwards (all metres; converted here).
local function box(
	ctx: Ctx,
	name: string,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(
		ctx,
		name,
		Vector3.new(sx * M, sy * M, sz * M),
		CFrame.new(x * M, ctx.y0 + y * M, ctx.zFront + z * M),
		color,
		material
	)
	if color == ctx.spec.bodyColor then
		p:SetAttribute("Paint", "Body") -- livery role (src/shared/LiveryPaint.luau)
	end
	return p
end

local function glass(p: Part): Part
	p.Transparency = 0.45
	p.Reflectance = 0.15
	p.CanCollide = false
	return p
end

local function lamp(
	ctx: Ctx,
	name: string,
	x: number,
	y: number,
	z: number,
	size: Vector3,
	color: Color3
): Part
	local p = box(ctx, name, size.X, size.Y, size.Z, x, y, z, color, Enum.Material.Glass)
	p.CanCollide = false
	return p
end

local function headlamps(ctx: Ctx, y: number, inset: number)
	local half = ctx.spec.width / 2 - inset
	for _, side in { -1, 1 } do
		local p = lamp(
			ctx,
			"Headlamp",
			side * half,
			y,
			0.02,
			Vector3.new(0.3, 0.14, 0.05),
			Color3.fromRGB(245, 245, 230)
		)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 75
		spot.Brightness = 2.5
		spot.Color = Color3.fromRGB(255, 248, 225)
		spot.Shadows = true
		spot.Enabled = false
		spot.Parent = p
	end
end

local function rearLamps(ctx: Ctx, y: number, length: number)
	local half = ctx.spec.width / 2 - 0.12
	for _, side in { -1, 1 } do
		lamp(
			ctx,
			"TailLamp",
			side * half,
			y,
			length,
			Vector3.new(0.18, 0.3, 0.05),
			Color3.fromRGB(150, 20, 20)
		)
		lamp(
			ctx,
			"BrakeLamp",
			side * half,
			y - 0.22,
			length,
			Vector3.new(0.18, 0.12, 0.05),
			Color3.fromRGB(120, 15, 15)
		)
		lamp(
			ctx,
			"ReverseLamp",
			side * (half - 0.25),
			y - 0.22,
			length,
			Vector3.new(0.12, 0.1, 0.05),
			Color3.fromRGB(190, 190, 190)
		)
	end
end

local function lightBar(ctx: Ctx, y: number, z: number, barWidth: number)
	local spec = ctx.spec
	local colors = spec.lightBarColors
	if not (spec.lightBar and colors) then
		return
	end
	box(ctx, "LightBarBase", barWidth, 0.06, 0.28, 0, y, z, DARK)
	local n = #colors
	local seg = barWidth / n
	for i, color in colors do
		local x = -barWidth / 2 + seg * (i - 0.5)
		local p = box(
			ctx,
			"Beacon",
			seg * 0.92,
			0.1,
			0.24,
			x,
			y + 0.08,
			z,
			color:Lerp(Color3.new(0, 0, 0), 0.5),
			Enum.Material.Glass
		)
		p.CanCollide = false
		p.Transparency = 0.15
		p:SetAttribute("LampIndex", i)
		p:SetAttribute("LampCount", n)
		p:SetAttribute("LampColor", color)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 16
		light.Brightness = 4
		light.Enabled = false
		light.Parent = p
	end
end

-- Battenburg-style side checks (rescue livery): alternating blocks along both flanks.
local function battenburg(ctx: Ctx, y: number, z0: number, z1: number, height: number)
	local spec = ctx.spec
	local n = math.max(2, math.floor((z1 - z0) / 0.6))
	local seg = (z1 - z0) / n
	for i = 0, n - 1 do
		for row = 0, 1 do
			local color = if (i + row) % 2 == 0 then spec.stripeColor else spec.stripeColor2
			for _, side in { -1, 1 } do
				local p = box(
					ctx,
					"Livery",
					0.02,
					height / 2,
					seg,
					side * (spec.width / 2 + 0.01),
					y + row * height / 2,
					z0 + seg * (i + 0.5),
					color
				)
				p.CanCollide = false
				p:SetAttribute("Paint", if (i + row) % 2 == 0 then "Stripe1" else "Stripe2")
			end
		end
	end
end

local function seat(
	ctx: Ctx,
	name: string,
	x: number,
	y: number,
	z: number,
	driver: boolean
): Seat | VehicleSeat
	local s: BasePart
	if driver then
		local vs = Instance.new("VehicleSeat")
		vs.MaxSpeed = 0
		vs.Torque = 0
		vs.TurnSpeed = 0
		vs.HeadsUpDisplay = false
		s = vs
	else
		s = Instance.new("Seat")
	end
	s.Name = name
	s.Size = Vector3.new(0.5 * M, 0.12 * M, 0.5 * M)
	s.CFrame = CFrame.new(x * M, ctx.y0 + y * M, ctx.zFront + z * M)
	s.Color = DARK
	s.Transparency = 0.2
	s.Massless = true
	s.CanCollide = false
	s.CollisionGroup = GROUP
	s.TopSurface = Enum.SurfaceType.Smooth
	s.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.root
	weld.Part1 = s
	weld.Parent = s
	s.Parent = ctx.model
	if driver then
		local eye = Instance.new("Attachment")
		eye.Name = "EyePoint"
		eye.Position = ctx.spec.eyePoint
		eye.Parent = s
	end
	return s :: any
end

local function wheels(ctx: Ctx, d: Chassis.Derived)
	local spec = ctx.spec
	for _, w in d.wheels do
		local p = Instance.new("Part")
		p.Name = "Wheel_" .. w.name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(spec.wheelWidth * M, w.radius * 2, w.radius * 2)
		p.Color = TYRE
		p.Material = Enum.Material.Rubber
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CollisionGroup = GROUP
		p.CFrame = ctx.root.CFrame * CFrame.new(w.centreRest)
		local rim = Instance.new("Part")
		rim.Name = "Rim"
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(spec.wheelWidth * M + 0.06, w.radius * 1.15, w.radius * 1.15)
		rim.Color = RIM
		rim.Material = Enum.Material.Metal
		rim.Massless = true
		rim.CanCollide = false
		rim.CanTouch = false
		rim.CanQuery = false
		rim.CFrame = p.CFrame
		local rimWeld = Instance.new("WeldConstraint")
		rimWeld.Part0 = p
		rimWeld.Part1 = rim
		rimWeld.Parent = rim
		rim.Parent = p
		local weld = Instance.new("Weld")
		weld.Name = "WheelWeld"
		weld.Part0 = ctx.root
		weld.Part1 = p
		weld.C0 = CFrame.new(w.centreRest)
		weld.Parent = p
		p.Parent = ctx.model
	end
end

-- Double-cab pickup (and the light-bar roll hoop, board rack and bed lockers of a beach truck).
local function pickupBody(ctx: Ctx)
	local s = ctx.spec
	local L, W, H = s.length, s.width, s.height
	local base, belt = s.groundClearance + 0.15, 1.05
	local c = s.bodyColor
	box(ctx, "Bumper", W, 0.28, 0.2, 0, base + 0.12, 0.1, DARK)
	box(ctx, "Grille", W * 0.6, 0.3, 0.05, 0, belt - 0.2, 0.22, DARK)
	box(ctx, "Bonnet", W, belt - base, 1.45, 0, (base + belt) / 2, 0.2 + 0.72, c)
	headlamps(ctx, belt - 0.15, 0.2)
	-- double cab: 1.65 m to 4.0 m
	local cabZ0, cabZ1 = 1.65, 3.85
	box(
		ctx,
		"CabLower",
		W,
		belt - base,
		cabZ1 - cabZ0,
		0,
		(base + belt) / 2,
		(cabZ0 + cabZ1) / 2,
		c
	)
	glass(
		box(
			ctx,
			"Windscreen",
			W * 0.9,
			H - belt - 0.08,
			0.3,
			0,
			(belt + H) / 2 - 0.04,
			cabZ0 + 0.25,
			GLASS,
			Enum.Material.Glass
		)
	)
	glass(
		box(
			ctx,
			"CabGlass",
			W * 0.94,
			H - belt - 0.1,
			cabZ1 - cabZ0 - 0.55,
			0,
			(belt + H) / 2 - 0.05,
			(cabZ0 + cabZ1) / 2 + 0.25,
			GLASS,
			Enum.Material.Glass
		)
	)
	box(ctx, "Roof", W * 0.92, 0.06, cabZ1 - cabZ0 - 0.4, 0, H - 0.03, (cabZ0 + cabZ1) / 2 + 0.2, c)
	for _, side in { -1, 1 } do
		box(ctx, "Mirror", 0.18, 0.15, 0.06, side * (W / 2 + 0.1), belt + 0.12, cabZ0 + 0.35, DARK)
		box(
			ctx,
			"Arch",
			0.06,
			0.25,
			1.0,
			side * (W / 2 + 0.02),
			s.wheelRadius * 2 + 0.05,
			s.frontOverhang,
			DARK
		)
		box(
			ctx,
			"Arch",
			0.06,
			0.25,
			1.0,
			side * (W / 2 + 0.02),
			s.wheelRadius * 2 + 0.05,
			s.frontOverhang + s.wheelbase,
			DARK
		)
		box(
			ctx,
			"Step",
			0.15,
			0.05,
			cabZ1 - cabZ0,
			side * (W / 2 + 0.05),
			base + 0.05,
			(cabZ0 + cabZ1) / 2,
			DARK
		)
		-- bed sides
		box(
			ctx,
			"BedSide",
			0.06,
			0.5,
			L - cabZ1 - 0.05,
			side * (W / 2 - 0.03),
			belt + 0.0,
			(cabZ1 + L) / 2,
			c
		)
	end
	box(ctx, "BedFloor", W, 0.06, L - cabZ1, 0, belt - 0.22, (cabZ1 + L) / 2, DARK)
	box(ctx, "Tailgate", W, 0.5, 0.05, 0, belt, L - 0.03, c)
	box(ctx, "RearBumper", W, 0.2, 0.15, 0, base + 0.15, L - 0.02, DARK)
	rearLamps(ctx, belt + 0.05, L - 0.03)
	-- beach truck kit: lockers in the bed, roll hoop with the light bar, board rack
	box(
		ctx,
		"KitLocker",
		W * 0.8,
		0.45,
		0.6,
		0,
		belt,
		cabZ1 + 0.4,
		Color3.fromRGB(70, 70, 75),
		Enum.Material.DiamondPlate
	)
	for _, side in { -1, 1 } do
		box(
			ctx,
			"RollHoop",
			0.06,
			0.6,
			0.06,
			side * (W / 2 - 0.1),
			belt + 0.5,
			cabZ1 + 0.1,
			CHROME,
			Enum.Material.Metal
		)
	end
	box(
		ctx,
		"RollHoopTop",
		W - 0.2,
		0.06,
		0.06,
		0,
		belt + 0.8,
		cabZ1 + 0.1,
		CHROME,
		Enum.Material.Metal
	)
	lightBar(ctx, H + 0.05, cabZ0 + 0.55, W * 0.75)
	box(ctx, "RescueBoard", 0.55, 0.08, 2.6, 0, H + 0.15, cabZ1 - 0.6, Color3.fromRGB(250, 205, 20))
	battenburg(ctx, base + 0.15, cabZ0, L - 0.1, 0.4)
end

-- Station-wagon coastguard 4x4: tall boxy body, roof rack with floodlights, spare on the door.
local function responseBody(ctx: Ctx)
	local s = ctx.spec
	local L, W, H = s.length, s.width, s.height
	local base, belt = s.groundClearance + 0.12, 1.15
	local c = s.bodyColor
	box(ctx, "Bumper", W + 0.1, 0.25, 0.25, 0, base + 0.1, 0.12, DARK)
	box(ctx, "Grille", W * 0.7, 0.35, 0.05, 0, belt - 0.25, 0.25, DARK)
	box(ctx, "Bonnet", W, belt - base, 1.2, 0, (base + belt) / 2, 0.25 + 0.6, c)
	headlamps(ctx, belt - 0.2, 0.25)
	local cabZ0 = 1.45
	box(ctx, "BodyLower", W, belt - base, L - cabZ0, 0, (base + belt) / 2, (cabZ0 + L) / 2, c)
	glass(
		box(
			ctx,
			"Windscreen",
			W * 0.92,
			0.55,
			0.12,
			0,
			belt + 0.3,
			cabZ0 + 0.06,
			GLASS,
			Enum.Material.Glass
		)
	)
	box(
		ctx,
		"Upper",
		W * 0.96,
		H - 0.12 - belt - 0.62,
		L - cabZ0 - 0.1,
		0,
		H - 0.12 - (H - 0.12 - belt - 0.62) / 2,
		(cabZ0 + L) / 2 + 0.05,
		c
	)
	glass(
		box(
			ctx,
			"SideGlass",
			W * 0.98,
			0.5,
			L - cabZ0 - 0.4,
			0,
			belt + 0.32,
			(cabZ0 + L) / 2 + 0.1,
			GLASS,
			Enum.Material.Glass
		)
	)
	box(
		ctx,
		"RoofRack",
		W * 0.95,
		0.08,
		L - cabZ0 - 0.3,
		0,
		H - 0.05,
		(cabZ0 + L) / 2 + 0.1,
		DARK,
		Enum.Material.Metal
	)
	box(
		ctx,
		"RopeBag",
		0.6,
		0.25,
		0.8,
		-0.4,
		H + 0.12,
		L - 1.2,
		Color3.fromRGB(230, 80, 20),
		Enum.Material.Fabric
	)
	box(
		ctx,
		"MudKit",
		0.5,
		0.2,
		1.2,
		0.4,
		H + 0.1,
		L - 1.4,
		Color3.fromRGB(60, 60, 64),
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		local fl =
			box(ctx, "Floodlight", 0.22, 0.18, 0.12, side * 0.55, H + 0.12, cabZ0 + 0.8, DARK)
		local spot = Instance.new("SpotLight")
		spot.Name = "Floodlight"
		spot.Face = Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 60
		spot.Brightness = 3
		spot.Enabled = false
		spot.Parent = fl
		box(ctx, "Mirror", 0.18, 0.16, 0.06, side * (W / 2 + 0.1), belt + 0.15, cabZ0 + 0.2, DARK)
		box(
			ctx,
			"Arch",
			0.08,
			0.25,
			0.95,
			side * (W / 2 + 0.03),
			s.wheelRadius * 2 + 0.05,
			s.frontOverhang,
			DARK
		)
		box(
			ctx,
			"Arch",
			0.08,
			0.25,
			0.95,
			side * (W / 2 + 0.03),
			s.wheelRadius * 2 + 0.05,
			s.frontOverhang + s.wheelbase,
			DARK
		)
	end
	local spare = box(
		ctx,
		"SpareWheel",
		0.75,
		0.75,
		0.22,
		0,
		belt + 0.05,
		L + 0.1,
		TYRE,
		Enum.Material.Rubber
	)
	spare.Shape = Enum.PartType.Cylinder
	spare.Size = Vector3.new(0.22 * M, 0.75 * M, 0.75 * M)
	spare.CFrame = spare.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	box(ctx, "RearBumper", W, 0.2, 0.15, 0, base + 0.12, L - 0.05, DARK)
	rearLamps(ctx, belt - 0.1, L)
	lightBar(ctx, H + 0.02, cabZ0 + 0.25, W * 0.8)
	battenburg(ctx, base + 0.15, 0.4, L - 0.1, 0.5)
end

-- Utility quad: tub, fuel tank and saddle, bars, racks with the rescue board, a beacon mast.
local function atvBody(ctx: Ctx)
	local s = ctx.spec
	local L, W = s.length, s.width
	local c = s.bodyColor
	box(ctx, "Frame", 0.5, 0.25, L * 0.8, 0, 0.45, L / 2, DARK, Enum.Material.Metal)
	box(ctx, "FrontFender", W * 0.95, 0.12, 0.7, 0, 0.78, 0.4, c)
	box(ctx, "RearFender", W * 0.95, 0.12, 0.7, 0, 0.8, L - 0.45, c)
	box(ctx, "Tank", 0.45, 0.25, 0.45, 0, 0.85, 0.85, c)
	box(ctx, "Saddle", 0.4, 0.14, 0.75, 0, 0.88, 1.35, DARK, Enum.Material.Fabric)
	box(ctx, "Bars", 0.8, 0.05, 0.05, 0, 1.05, 0.65, DARK, Enum.Material.Metal)
	box(ctx, "Headset", 0.2, 0.2, 0.15, 0, 0.95, 0.62, c)
	box(ctx, "FrontRack", W * 0.8, 0.04, 0.45, 0, 0.92, 0.3, DARK, Enum.Material.Metal)
	box(ctx, "RearRack", W * 0.85, 0.04, 0.55, 0, 0.95, L - 0.35, DARK, Enum.Material.Metal)
	box(ctx, "RescueTube", 0.9, 0.12, 0.15, 0, 1.02, L - 0.25, Color3.fromRGB(240, 40, 30))
	box(ctx, "RescueBoard", 0.5, 0.06, 2.4, 0.0, 1.06, L - 0.9, Color3.fromRGB(250, 205, 20))
	box(ctx, "Mast", 0.04, 0.6, 0.04, -0.4, 1.25, L - 0.1, DARK, Enum.Material.Metal)
	headlamps(ctx, 0.8, 0.3)
	rearLamps(ctx, 0.8, L - 0.05)
	lightBar(ctx, 1.57, L - 0.1, 0.3)
end

-- Box-body ambulance (parked handover point in the MVP).
local function ambulanceBody(ctx: Ctx)
	local s = ctx.spec
	local L, W, H = s.length, s.width, s.height
	local base = s.groundClearance + 0.15
	local c = s.bodyColor
	box(ctx, "Bumper", W, 0.25, 0.2, 0, base + 0.1, 0.1, DARK)
	box(ctx, "Bonnet", W * 0.95, 0.75, 0.9, 0, base + 0.4, 0.5, c)
	headlamps(ctx, base + 0.55, 0.25)
	box(ctx, "Cab", W * 0.95, 1.2, 1.2, 0, base + 0.8 + 0.2, 1.5, c)
	glass(box(ctx, "Windscreen", W * 0.9, 0.6, 0.1, 0, base + 1.3, 1.0, GLASS, Enum.Material.Glass))
	box(ctx, "Box", W, H - base, L - 2.2, 0, base + (H - base) / 2, 2.1 + (L - 2.2) / 2, c)
	box(
		ctx,
		"RearDoors",
		W * 0.9,
		H - base - 0.3,
		0.04,
		0,
		base + (H - base) / 2 + 0.1,
		L - 0.08,
		c:Lerp(Color3.new(1, 1, 1), 0.2)
	)
	rearLamps(ctx, base + 0.6, L - 0.05)
	lightBar(ctx, H + 0.02, 2.2, W * 0.8)
	battenburg(ctx, base + 0.3, 2.2, L - 0.1, 0.7)
end

-- Tandem boat trailer: A-frame drawbar to the coupler, side rails, rollers, winch post.
local function trailerBody(ctx: Ctx)
	local s = ctx.spec
	local L, W = s.length, s.width
	local steel = s.bodyColor
	local railY = s.wheelRadius * 2 + 0.05
	box(ctx, "Coupler", 0.15, 0.12, 0.35, 0, railY - 0.05, 0.15, DARK, Enum.Material.Metal)
	box(ctx, "Drawbar", 0.12, 0.12, 2.6, 0, railY, 1.5, steel, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		box(
			ctx,
			"Rail",
			0.1,
			0.14,
			L - 2.6,
			side * (W / 2 - 0.35),
			railY,
			2.6 + (L - 2.6) / 2,
			steel,
			Enum.Material.Metal
		)
		box(
			ctx,
			"Mudguard",
			0.35,
			0.05,
			1.6,
			side * (W / 2 - 0.05),
			s.wheelRadius * 2 + 0.1,
			s.frontOverhang,
			DARK
		)
		box(
			ctx,
			"Bunk",
			0.15,
			0.1,
			4.5,
			side * 0.45,
			railY + 0.18,
			L - 3,
			Color3.fromRGB(70, 50, 30),
			Enum.Material.Carpet
		)
	end
	for z = 3, L - 0.5, 1.4 do
		box(ctx, "CrossMember", W - 0.6, 0.1, 0.1, 0, railY, z, steel, Enum.Material.Metal)
		local roller = box(
			ctx,
			"Roller",
			0.3,
			0.16,
			0.16,
			0,
			railY + 0.12,
			z,
			Color3.fromRGB(30, 30, 32),
			Enum.Material.Rubber
		)
		roller.CanCollide = false
	end
	box(ctx, "WinchPost", 0.12, 0.9, 0.12, 0, railY + 0.45, 2.6, steel, Enum.Material.Metal)
	box(ctx, "Winch", 0.25, 0.2, 0.2, 0, railY + 0.7, 2.45, DARK, Enum.Material.Metal)
	box(
		ctx,
		"LightBoard",
		W * 0.8,
		0.15,
		0.05,
		0,
		railY + 0.25,
		L - 0.02,
		Color3.fromRGB(240, 240, 240)
	)
	rearLamps(ctx, railY + 0.3, L)
end

-- A greybox boat riding on the trailer (stands in for the real one until launch).
function Builder.boatOnTrailer(trailer: Model, boatId: string): Model?
	local root = trailer.PrimaryPart
	local spec = LandVehicleConfig.BoatTrailer
	if not root then
		return nil
	end
	local boat = Instance.new("Model")
	boat.Name = "TrailerBoat"
	boat:SetAttribute("BoatId", boatId)
	local ctx: Ctx = {
		model = boat,
		root = root,
		spec = spec,
		y0 = -spec.cgHeight * M,
		zFront = -(spec.frontOverhang - 0.07 * spec.frontOverhang) * M,
		zRear = (spec.length - 0.93 * spec.frontOverhang) * M,
		w = spec.width * M,
	}
	local bedY = spec.wheelRadius * 2 + 0.3
	if boatId == "RIB" then
		-- Atlantic 85 class: 8.44 m x 2.85 m; grey hull, orange tubes
		local hull =
			box(ctx, "Hull", 2.0, 0.6, 7.4, 0, bedY + 0.3, 2.3 + 3.7, Color3.fromRGB(70, 75, 85))
		hull.Massless = true
		for _, side in { -1, 1 } do
			box(
				ctx,
				"Tube",
				0.5,
				0.5,
				7.6,
				side * 1.15,
				bedY + 0.75,
				2.2 + 3.8,
				Color3.fromRGB(255, 110, 20),
				Enum.Material.Fabric
			)
		end
		box(ctx, "Console", 0.8, 0.9, 0.7, 0, bedY + 1.1, 5.2, Color3.fromRGB(230, 230, 230))
		box(ctx, "Engines", 1.2, 0.8, 0.5, 0, bedY + 0.9, 9.6, DARK)
	else
		-- three-seat rescue PWC: 3.3 m x 1.2 m
		box(ctx, "Hull", 1.2, 0.55, 3.3, 0, bedY + 0.3, 5.5 + 1.65, Color3.fromRGB(250, 205, 20))
		box(ctx, "Seat", 0.45, 0.25, 1.4, 0, bedY + 0.7, 7.3, DARK, Enum.Material.Fabric)
	end
	boat.Parent = trailer
	return boat
end

-- Builds a vehicle at the origin (Chassis centre at 0,0,0, facing -Z). extraMassKg: e.g. a
-- trailer's boat. Returns the model and its prepared chassis.
function Builder.build(spec: Spec, extraMassKg: number?): (Model, Chassis.Derived)
	local d = Chassis.prepare(spec, extraMassKg)
	local model = Instance.new("Model")
	model.Name = spec.id
	model:SetAttribute("VehicleId", spec.id)
	model:SetAttribute("LandVehicle", true)
	model:SetAttribute("CameraMode", spec.cameraMode)
	model:SetAttribute("CockpitView", spec.cockpitView)

	local wheelbase = spec.wheelbase * M
	local zFrontAxle = if spec.class == "Trailer"
		then -spec.frontOverhang * 0.93 * M
		else -wheelbase * (1 - spec.frontWeight)
	local zFront = if spec.class == "Trailer"
		then zFrontAxle
		else zFrontAxle - spec.frontOverhang * M
	local rootSize = Vector3.new(spec.track * M * 0.8, 0.5 * M, math.max(wheelbase, 1.5) * M)
	local root = Instance.new("Part")
	root.Name = "Chassis"
	root.Size = rootSize
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CollisionGroup = GROUP
	local volume = rootSize.X * rootSize.Y * rootSize.Z
	root.CustomPhysicalProperties =
		PhysicalProperties.new(math.clamp(d.mass / volume, 0.01, 100), 0.3, 0.2, 1, 1)
	root.Parent = model
	model.PrimaryPart = root

	local ctx: Ctx = {
		model = model,
		root = root,
		spec = spec,
		y0 = -spec.cgHeight * M,
		zFront = zFront,
		zRear = zFront + spec.length * M,
		w = spec.width * M,
	}

	local force = Instance.new("VectorForce")
	local torque = Instance.new("Torque")
	local centre = Instance.new("Attachment")
	centre.Name = "CentreOfMass"
	centre.Parent = root
	force.Name = "CarForce"
	force.Attachment0 = centre
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Parent = root
	torque.Name = "CarTorque"
	torque.Attachment0 = centre
	torque.RelativeTo = Enum.ActuatorRelativeTo.World
	torque.Torque = Vector3.zero
	torque.Parent = root

	if spec.class == "Pickup" then
		pickupBody(ctx)
	elseif spec.class == "Response" then
		responseBody(ctx)
	elseif spec.class == "ATV" then
		atvBody(ctx)
	elseif spec.class == "Ambulance" then
		ambulanceBody(ctx)
	else
		trailerBody(ctx)
	end
	wheels(ctx, d)

	-- seats: right-hand drive, so the driver sits on the right (+X)
	local function seatAt(name: string, x: number, z: number, driver: boolean)
		local cushion = if spec.class == "ATV" then 0.95 else spec.groundClearance + 0.5
		seat(ctx, name, x, cushion, z, driver)
	end
	local W = spec.width
	if spec.class == "ATV" then
		seatAt("DriverSeat", 0, 1.35, true)
	elseif spec.class == "Pickup" or spec.class == "Response" or spec.class == "Ambulance" then
		local frontZ = if spec.class == "Pickup"
			then 2.35
			elseif spec.class == "Response" then 2.0
			else 1.6
		seatAt("DriverSeat", W * 0.24, frontZ, true)
		seatAt("Seat2", -W * 0.24, frontZ, false)
		if spec.seats >= 5 then
			for i, x in { -W * 0.3, 0, W * 0.3 } do
				seatAt(`Seat{2 + i}`, x, frontZ + 0.95, false)
			end
		end
	end

	-- hitch at the rear bumper (tow ball, 0.45 m up), coupler at the trailer's nose
	if spec.canTow then
		local hitch = Instance.new("Attachment")
		hitch.Name = "TowHitch"
		hitch.CFrame = CFrame.fromMatrix(
			Vector3.new(0, ctx.y0 + 0.45 * M, ctx.zRear + 0.15 * M),
			Vector3.new(0, 0, 1),
			Vector3.new(0, 1, 0)
		)
		hitch.Parent = root
	end
	if spec.class == "Trailer" then
		local coupler = Instance.new("Attachment")
		coupler.Name = "Coupler"
		coupler.CFrame = CFrame.fromMatrix(
			Vector3.new(0, ctx.y0 + 0.45 * M, zFront),
			Vector3.new(0, 0, 1),
			Vector3.new(0, 1, 0)
		)
		coupler.Parent = root
		local cradle = Instance.new("Attachment")
		cradle.Name = "Cradle" -- the bed under the boat: launch depth is measured here
		cradle.Position =
			Vector3.new(0, ctx.y0 + (spec.wheelRadius * 2 + 0.3) * M, ctx.zRear - 3 * M)
		cradle.Parent = root
	end
	return model, d
end

-- Ground clearance check helper: how far the chassis centre sits above the ground at rest.
function Builder.rideHeight(spec: Spec): number
	return spec.cgHeight * M
end

return Builder
