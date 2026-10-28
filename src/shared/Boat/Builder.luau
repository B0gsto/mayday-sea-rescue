--!strict
-- Builder: greybox vehicle models from parts (server-side; VehicleService calls it).
--
-- Layout of every built vehicle (a Model, PrimaryPart = HullRoot, built at the origin):
--   HullRoot      invisible collidable box (spec.hullSize), the ONLY part with mass: its density is
--                 set so the assembly mass is spec.massHint. Physics root and network-owned part.
--     Float1..n         attachments at spec.floatPoints, each driving VectorForce FloatForce1..n
--     DriveAttachment   centre attachment for DriveForce (VectorForce) and DriveTorque (Torque)
--     SurvivorSlot1..n, TowHitch (stern), BowPoint (bow)   attachments (CONTRACT)
--     VisualJoint       Motor6D HullRoot -> Body. Remote clients offset its Transform to snap the
--                       visible hull onto their local wave (see BoatController); never replicated.
--   Body          the visible hull; every other visual part and the seats weld to Body. All
--                 non-root parts are Massless and CanCollide = false.
--   DriverSeat    VehicleSeat (ThrottleFloat / SteerFloat come from keyboard, gamepad, thumbstick)
--     EyePoint    Attachment at the driver's eye (spec.eyePoint) for the camera stream
--   PassengerSeat1..n  Seats
--   Nav*          navigation lights (COLREGs): NavPort red, NavStarboard green (112.5 deg sectors
--                 from dead ahead to 22.5 deg abaft the beam), NavMasthead white (forward 225 deg,
--                 all-round on the PWC), NavStern white (aft). Each holds a light named "NavLight",
--                 off when built; BoatController switches them on at night and in storms (NavLights).
-- Real dimensions at 1 m = 3 studs (docs 05 section 4.1): PWC 3.3 x 1.2 m, Atlantic 85 8.4 x 2.85 m.
-- Colour scheme: rescue orange with white; the RIB has a charcoal hull and orange tubes.
--
-- Real models: Builder.build(spec, visuals) with the uploaded models (RIB: M_Veh_RIB +
-- M_Veh_RIB_Helm; jet ski: M_Veh_JetSki, see
-- buildJetSkiAsset), cloned by the server's AssetLoader at their authored pivot, keeps the same
-- invisible physics (HullRoot, mass, float points, forces) and an invisible Body, welds every visual
-- part to Body and puts the seats, lights and attachments at the model's ATT_* points
-- (AssetIds.Attachments). Without visuals (asset failed to load) the greybox is built as before.
-- Attribute Visual = asset name or
-- "Greybox".

local AssetIds = require(script.Parent.Parent.Config.AssetIds)
local PetSeat = require(script.Parent.Parent.PetSeat)
local VehicleConfig = require(script.Parent.Parent.Config.VehicleConfig)

type VehicleSpec = VehicleConfig.VehicleSpec

local ORANGE = Color3.fromRGB(255, 102, 0)
local WHITE = Color3.fromRGB(240, 240, 236)
local DARK = Color3.fromRGB(45, 48, 54)
local GLASS = Color3.fromRGB(120, 170, 200)
local CHARCOAL = Color3.fromRGB(38, 40, 44)
local GREY = Color3.fromRGB(110, 114, 120)
local RED_LIGHT = Color3.fromRGB(255, 40, 30)
local GREEN_LIGHT = Color3.fromRGB(40, 255, 90)
local WHITE_LIGHT = Color3.fromRGB(255, 244, 225)
local BLUE_LIGHT = Color3.fromRGB(40, 110, 255)
local NAVY = Color3.fromRGB(22, 48, 78)
local SIDELIGHT_YAW = math.rad(56.25) -- centre of the dead-ahead .. 22.5 deg abaft the beam sector

local Builder = {}

type Ctx = {
	model: Model,
	root: Part,
	body: Part,
}

local function newPart(
	ctx: Ctx?,
	className: string,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	if ctx then
		-- livery roles for the greybox hull (src/shared/LiveryPaint.luau)
		if color == ORANGE then
			part:SetAttribute("Paint", "Body")
		elseif color == CHARCOAL or color == NAVY then
			part:SetAttribute("Paint", "Secondary")
		end
		part.Massless = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ctx.body
		weld.Part1 = part
		weld.Parent = part
		part.Parent = ctx.model
	end
	return part
end

local function deco(ctx: Ctx, name: string, size: Vector3, pos: Vector3, color: Color3): BasePart
	return newPart(ctx, "Part", name, size, CFrame.new(pos), color)
end

-- Cylinder parts run along their local X; alongZ turns them to lie along the hull.
local function tube(
	ctx: Ctx,
	name: string,
	length: number,
	diameter: number,
	pos: Vector3,
	alongZ: boolean,
	yaw: number?
)
	local turn = (if alongZ then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity)
	turn = CFrame.Angles(0, yaw or 0, 0) * turn
	local part = newPart(
		ctx,
		"Part",
		name,
		Vector3.new(length, diameter, diameter),
		CFrame.new(pos) * turn,
		ORANGE
	) :: Part
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A navigation light: a small lamp part plus a light named NavLight (off). sector nil = all-round
-- PointLight, else a SpotLight of that many degrees centred on the lamp's yaw (0 = dead ahead).
local function navLight(
	ctx: Ctx,
	name: string,
	pos: Vector3,
	color: Color3,
	yaw: number,
	sector: number?
): BasePart
	local lamp = newPart(
		ctx,
		"Part",
		name,
		Vector3.new(0.35, 0.35, 0.35),
		CFrame.new(pos) * CFrame.Angles(0, yaw, 0),
		color:Lerp(DARK, 0.6)
	)
	lamp:SetAttribute("NavColor", color)
	local light: Light
	if sector then
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = math.min(sector, 180)
		spot.Range = 12
		light = spot
	else
		local point = Instance.new("PointLight")
		point.Range = 10
		light = point
	end
	light.Name = "NavLight"
	light.Color = color
	light.Brightness = 2
	light.Shadows = false
	light.Enabled = false
	light.Parent = lamp
	return lamp
end

local function attach(root: BasePart, name: string, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = root
	return a
end

local function seat(
	ctx: Ctx,
	isDriver: boolean,
	name: string,
	size: Vector3,
	pos: Vector3
): Seat | VehicleSeat
	local s =
		newPart(ctx, if isDriver then "VehicleSeat" else "Seat", name, size, CFrame.new(pos), DARK)
	s.CanTouch = true -- seats sit on touch
	if s:IsA("VehicleSeat") then
		-- Thrust and steering come from BoatController; the legacy seat motor must not drive.
		s.MaxSpeed = 0
		s.Torque = 0
		s.TurnSpeed = 0
		s.HeadsUpDisplay = false
		return s
	end
	return s :: Seat
end

local function newCtx(
	spec: VehicleSpec,
	bodySize: Vector3,
	bodyOffset: Vector3,
	bodyColor: Color3
): Ctx
	local model = Instance.new("Model")
	model.Name = spec.id

	local root = newPart(nil, "Part", "HullRoot", spec.hullSize, CFrame.identity, ORANGE) :: Part
	root.Transparency = 1
	root.CastShadow = false
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = true
	local volume = spec.hullSize.X * spec.hullSize.Y * spec.hullSize.Z
	root.CustomPhysicalProperties = PhysicalProperties.new(spec.massHint / volume, 0.3, 0, 1, 1)
	root.Parent = model
	model.PrimaryPart = root

	local body = newPart(nil, "Part", "Body", bodySize, CFrame.new(bodyOffset), bodyColor) :: Part
	body:SetAttribute("Paint", if bodyColor == ORANGE then "Body" else "Secondary")
	body.Massless = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Parent = model
	local joint = Instance.new("Motor6D")
	joint.Name = "VisualJoint"
	joint.Part0 = root
	joint.Part1 = body
	joint.C0 = CFrame.new(bodyOffset)
	joint.C1 = CFrame.identity
	joint.Parent = root

	return { model = model, root = root, body = body }
end

local function finish(
	ctx: Ctx,
	spec: VehicleSpec,
	slots: { Vector3 },
	towHitch: Vector3,
	bow: Vector3
): Model
	local root = ctx.root
	for i, p in spec.floatPoints do
		local a = attach(root, `Float{i}`, p)
		local force = Instance.new("VectorForce")
		force.Name = `FloatForce{i}`
		force.Attachment0 = a
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = false
		force.Force = Vector3.zero
		force.Parent = root
	end
	local center = attach(root, "DriveAttachment", Vector3.zero)
	local drive = Instance.new("VectorForce")
	drive.Name = "DriveForce"
	drive.Attachment0 = center
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.ApplyAtCenterOfMass = true
	drive.Force = Vector3.zero
	drive.Parent = root
	local torque = Instance.new("Torque")
	torque.Name = "DriveTorque"
	torque.Attachment0 = center
	torque.RelativeTo = Enum.ActuatorRelativeTo.World
	torque.Torque = Vector3.zero
	torque.Parent = root

	for i, p in slots do
		attach(root, `SurvivorSlot{i}`, p)
	end
	attach(root, "TowHitch", towHitch)
	attach(root, "BowPoint", bow)
	local petSeat = PetSeat.builderPoint(spec.id, slots)
	if petSeat then
		attach(root, "PetSeat", petSeat)
	end

	local driverSeat = ctx.model:FindFirstChild("DriverSeat")
	if driverSeat then
		attach(driverSeat :: BasePart, "EyePoint", spec.eyePoint)
	end

	local model = ctx.model
	model:SetAttribute("VehicleId", spec.id)
	model:SetAttribute("CameraMode", spec.cameraMode)
	model:SetAttribute("Capacity", spec.survivorCapacity)
	model:SetAttribute("SurvivorCount", 0)
	model:SetAttribute("Draft", spec.draft)
	model:SetAttribute("SpeedMultiplier", 1)
	return model
end

-- PWC, 3.3 m x 1.2 m (9.9 x 3.6 studs). Collision box 2.1 studs deep: keel at y -1.05, gunwale +1.05.
-- Saddle top 0.8 m above the keel, handlebars about 1.05 m, a 1.5 m rescue sled off the stern.
local function buildJetSki(spec: VehicleSpec): Model
	local ctx = newCtx(spec, Vector3.new(3.4, 1.3, 8.4), Vector3.new(0, -0.4, 0.75), ORANGE)
	deco(ctx, "Nose", Vector3.new(2.4, 1.0, 1.5), Vector3.new(0, -0.15, -4.2), ORANGE)
	deco(ctx, "Keel", Vector3.new(1.2, 0.5, 8.6), Vector3.new(0, -0.85, 0.3), WHITE)
	deco(ctx, "Stripe", Vector3.new(3.5, 0.25, 8.4), Vector3.new(0, -0.3, 0.75), WHITE)
	deco(ctx, "Hood", Vector3.new(2.6, 0.9, 2.6), Vector3.new(0, 0.55, -2.4), WHITE)
	deco(ctx, "FootwellL", Vector3.new(0.7, 0.15, 4.2), Vector3.new(-1.3, 0.32, 1.8), DARK)
	deco(ctx, "FootwellR", Vector3.new(0.7, 0.15, 4.2), Vector3.new(1.3, 0.32, 1.8), DARK)
	deco(ctx, "Pedestal", Vector3.new(1.5, 0.6, 3.4), Vector3.new(0, 0.55, 1.5), ORANGE)
	deco(ctx, "HandlebarPost", Vector3.new(0.35, 0.9, 0.35), Vector3.new(0, 1.45, -1.3), DARK)
	deco(ctx, "Handlebar", Vector3.new(2.25, 0.18, 0.25), Vector3.new(0, 2.0, -1.2), DARK)
	deco(ctx, "Pump", Vector3.new(1.0, 0.6, 0.6), Vector3.new(0, -0.6, 5.0), DARK)
	seat(ctx, true, "DriverSeat", Vector3.new(1.35, 0.5, 3.0), Vector3.new(0, 1.1, 1.4))
	-- rescue sled (docs 05: board with handles), 1.5 m x 1.0 m, trailing flush off the stern
	deco(ctx, "Sled", Vector3.new(3.0, 0.3, 4.5), Vector3.new(0, -0.7, 7.3), WHITE)
	deco(ctx, "SledRailL", Vector3.new(0.2, 0.4, 4.2), Vector3.new(-1.45, -0.45, 7.3), ORANGE)
	deco(ctx, "SledRailR", Vector3.new(0.2, 0.4, 4.2), Vector3.new(1.45, -0.45, 7.3), ORANGE)
	-- PWC lights: bicolour sidelights on the nose, all-round white on a short stern pole
	navLight(ctx, "NavPort", Vector3.new(-0.9, 0.5, -3.9), RED_LIGHT, SIDELIGHT_YAW, 112.5)
	navLight(ctx, "NavStarboard", Vector3.new(0.9, 0.5, -3.9), GREEN_LIGHT, -SIDELIGHT_YAW, 112.5)
	deco(ctx, "LightPole", Vector3.new(0.15, 1.6, 0.15), Vector3.new(0, 1.8, 4.3), DARK)
	navLight(ctx, "NavMasthead", Vector3.new(0, 2.7, 4.3), WHITE_LIGHT, 0, nil)
	return finish(
		ctx,
		spec,
		{ Vector3.new(0, -0.45, 7.3) },
		Vector3.new(0, -0.3, 4.95),
		Vector3.new(0, -0.3, -4.95)
	)
end

-- Atlantic 85-class RIB, 8.4 m x 2.85 m (25.3 x 8.55 studs). Collision box 3.3 studs deep: keel
-- at y -1.65, tube tops at +1.65, deck at 0. Charcoal deep-V hull inside 0.55 m orange tubes,
-- centre console with screen, jockey seats behind it, twin outboards, A-frame with radar and lights.
local function buildRIB(spec: VehicleSpec): Model
	local ctx = newCtx(spec, Vector3.new(6.2, 1.7, 22.6), Vector3.new(0, -0.85, 0.9), CHARCOAL)
	deco(ctx, "Keel", Vector3.new(2.2, 0.6, 21.0), Vector3.new(0, -1.5, 0.6), CHARCOAL)
	deco(ctx, "Deck", Vector3.new(5.6, 0.1, 19.0), Vector3.new(0, 0.02, 1.4), GREY)
	local d = 1.65 -- tube diameter (0.55 m)
	tube(ctx, "TubeL", 20.6, d, Vector3.new(-3.45, 0.82, 2.3), true)
	tube(ctx, "TubeR", 20.6, d, Vector3.new(3.45, 0.82, 2.3), true)
	local bowYaw = math.atan2(2.6, 4.0)
	tube(ctx, "BowTubeL", 4.8, d, Vector3.new(-2.15, 0.82, -10.0), true, -bowYaw)
	tube(ctx, "BowTubeR", 4.8, d, Vector3.new(2.15, 0.82, -10.0), true, bowYaw)
	local cap = newPart(
		ctx,
		"Part",
		"BowCap",
		Vector3.new(d, d, d),
		CFrame.new(0, 0.82, -11.9),
		ORANGE
	) :: Part
	cap.Shape = Enum.PartType.Ball
	deco(ctx, "RubStrakeL", Vector3.new(0.12, 0.3, 18), Vector3.new(-4.29, 0.6, 2.3), DARK)
	deco(ctx, "RubStrakeR", Vector3.new(0.12, 0.3, 18), Vector3.new(4.29, 0.6, 2.3), DARK)
	-- centre console (0.9 m wide, 1.0 m tall) with windscreen and grab rail
	deco(ctx, "Console", Vector3.new(2.7, 3.0, 2.4), Vector3.new(0, 1.5, -1.2), WHITE)
	local screen =
		deco(ctx, "Windscreen", Vector3.new(2.7, 1.0, 0.1), Vector3.new(0, 3.5, -2.3), GLASS)
	screen.Transparency = 0.4
	deco(ctx, "GrabRail", Vector3.new(3.1, 0.15, 0.15), Vector3.new(0, 3.2, -0.1), GREY)
	-- jockey seats: helm behind the console, two crew behind the helm
	deco(ctx, "HelmPedestal", Vector3.new(1.0, 1.95, 1.6), Vector3.new(0, 0.98, 1.6), GREY)
	seat(ctx, true, "DriverSeat", Vector3.new(1.3, 0.6, 2.2), Vector3.new(0, 2.25, 1.6))
	for i = 1, spec.seats - 1 do
		local side = if i % 2 == 1 then -1 else 1
		local row = math.ceil(i / 2)
		local z = 1.6 + row * 3.2
		deco(
			ctx,
			`CrewPedestal{i}`,
			Vector3.new(1.0, 1.95, 1.6),
			Vector3.new(side * 1.3, 0.98, z),
			GREY
		)
		seat(
			ctx,
			false,
			`PassengerSeat{i}`,
			Vector3.new(1.3, 0.6, 2.2),
			Vector3.new(side * 1.3, 2.25, z)
		)
	end
	-- twin outboards on the transom
	for i, x in { -1.3, 1.3 } do
		deco(ctx, `EngineCowl{i}`, Vector3.new(1.3, 1.9, 1.7), Vector3.new(x, 1.2, 12.3), DARK)
		deco(ctx, `EngineLeg{i}`, Vector3.new(0.5, 2.8, 0.7), Vector3.new(x, -1.1, 12.6), DARK)
	end
	-- A-frame over the engines (about 2.3 m above the deck) with radar, blue beacon and lights
	for i, x in { -2.9, 2.9 } do
		deco(ctx, `AFrameLeg{i}`, Vector3.new(0.35, 7.0, 0.35), Vector3.new(x, 3.5, 10.0), GREY)
	end
	deco(ctx, "AFrameBeam", Vector3.new(6.15, 0.35, 0.35), Vector3.new(0, 7.0, 10.0), GREY)
	local radar = newPart(
		ctx,
		"Part",
		"Radar",
		Vector3.new(0.6, 1.8, 1.8),
		CFrame.new(0, 7.5, 10.0) * CFrame.Angles(0, 0, math.pi / 2),
		WHITE
	) :: Part
	radar.Shape = Enum.PartType.Cylinder
	local beacon =
		deco(ctx, "Beacon", Vector3.new(0.4, 0.5, 0.4), Vector3.new(-2.3, 7.45, 10.0), BLUE_LIGHT)
	beacon.Material = Enum.Material.Neon
	navLight(ctx, "NavMasthead", Vector3.new(1.6, 7.45, 9.8), WHITE_LIGHT, 0, 225)
	navLight(ctx, "NavStern", Vector3.new(0, 6.6, 10.25), WHITE_LIGHT, math.pi, 135)
	navLight(ctx, "NavPort", Vector3.new(-1.45, 2.6, -1.6), RED_LIGHT, SIDELIGHT_YAW, 112.5)
	navLight(ctx, "NavStarboard", Vector3.new(1.45, 2.6, -1.6), GREEN_LIGHT, -SIDELIGHT_YAW, 112.5)
	-- casualties ride in the forward well, ahead of the console
	local slots = {}
	for i = 1, spec.survivorCapacity do
		local side = if i % 2 == 1 then -1 else 1
		table.insert(slots, Vector3.new(side * 1.3, 0.1, -5.0 - math.floor((i - 1) / 2) * 2.4))
	end
	return finish(ctx, spec, slots, Vector3.new(0, 0.6, 11.4), Vector3.new(0, 0.6, -12.6))
end

-- Pivots the real models to `origin` (HullRoot space) and welds every part to the invisible Body.
local function weldVisuals(ctx: Ctx, visuals: { Model }, origin: Vector3)
	ctx.body.Transparency = 1
	ctx.body.CastShadow = false
	for _, visual in visuals do
		visual:PivotTo(CFrame.new(origin))
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = ctx.body
				weld.Part1 = d
				weld.Parent = d
			end
		end
		visual.Parent = ctx.model
	end
end

-- The RIB asset's authored pivot (Blender origin: skeg base, midships) in HullRoot space. Its ATT_*
-- layout matches the greybox: ATT_DriverSeat (0, 4.35, 1.6761) is the greybox seat (0, 2.25, 1.6),
-- ATT_Float1 (-2.2, 0.45, -8.9239) is floatPoints[1] (-2.2, -1.65, -9).
Builder.RIB_ORIGIN = Vector3.new(0, -2.1, -0.0761)

local function buildRIBAsset(spec: VehicleSpec, visuals: { Model }): Model
	local ctx = newCtx(spec, Vector3.new(1, 1, 1), Vector3.zero, CHARCOAL)
	local origin = Builder.RIB_ORIGIN
	local atts = AssetIds.Attachments.M_Veh_RIB or {}
	local function at(name: string, fallback: Vector3): Vector3
		local p = atts[name]
		return if p then p + origin else fallback
	end
	weldVisuals(ctx, visuals, origin)
	-- functional seats, invisible inside the modelled jockey seats
	local function hidden(part: BasePart)
		part.Transparency = 1
		part.CastShadow = false
	end
	local seatSize = Vector3.new(1.3, 0.6, 2.2)
	hidden(seat(ctx, true, "DriverSeat", seatSize, at("ATT_DriverSeat", Vector3.new(0, 2.25, 1.6))))
	for i = 1, spec.seats - 1 do
		local side = if i % 2 == 1 then -1 else 1
		local fallback = Vector3.new(side * 1.3, 2.25, 1.6 + math.ceil(i / 2) * 3.2)
		hidden(seat(ctx, false, `PassengerSeat{i}`, seatSize, at(`ATT_PassengerSeat{i}`, fallback)))
	end
	-- Bosun's spot (DogService): on the aft deck behind the jockey seats, out of the helm's view
	attach(ctx.root, "DogSlot", at("ATT_DogSlot", Vector3.new(0, 0.3, 7.4)))
	-- nav lights: small lamps in the modelled housings (they glow when NavLights switches them on)
	type Lamp = { name: string, pos: Vector3, color: Color3, yaw: number, sector: number }
	local lamps: { Lamp } = {
		{
			name = "NavMasthead",
			pos = Vector3.new(1.6, 7.45, 9.8),
			color = WHITE_LIGHT,
			yaw = 0,
			sector = 225,
		},
		{
			name = "NavStern",
			pos = Vector3.new(0, 6.6, 10.25),
			color = WHITE_LIGHT,
			yaw = math.pi,
			sector = 135,
		},
		{
			name = "NavPort",
			pos = Vector3.new(-1.45, 2.6, -1.6),
			color = RED_LIGHT,
			yaw = SIDELIGHT_YAW,
			sector = 112.5,
		},
		{
			name = "NavStarboard",
			pos = Vector3.new(1.45, 2.6, -1.6),
			color = GREEN_LIGHT,
			yaw = -SIDELIGHT_YAW,
			sector = 112.5,
		},
	}
	for _, l in lamps do
		local lamp = navLight(ctx, l.name, at(`ATT_{l.name}`, l.pos), l.color, l.yaw, l.sector)
		lamp.Size = Vector3.new(0.2, 0.2, 0.2)
		lamp.CastShadow = false
	end
	local slots = {}
	for i = 1, spec.survivorCapacity do
		local side = if i % 2 == 1 then -1 else 1
		local fallback = Vector3.new(side * 1.3, 0.1, -5.0 - math.floor((i - 1) / 2) * 2.4)
		table.insert(slots, at(`ATT_SurvivorSlot{i}`, fallback))
	end
	local model = finish(
		ctx,
		spec,
		slots,
		at("ATT_TowHitch", Vector3.new(0, 0.6, 11.4)),
		at("ATT_BowPoint", Vector3.new(0, 0.6, -12.6))
	)
	model:SetAttribute("Visual", visuals[1].Name)
	return model
end

-- The jet ski asset's authored pivot in HullRoot space: ATT_Float1..6 (y 0.05) sit on the
-- greybox floatPoints (y -1.05), e.g. ATT_Float3 (-1.4, 0.05, -2.3213) = floatPoints[3] (-1.4, -1.05, 0).
Builder.JETSKI_ORIGIN = Vector3.new(0, -1.1, 2.3213)
local NAV_RANGE = 3.5 -- studs: a small glow on the housing, not a pool of colour on deck and water
local NAV_BRIGHTNESS = 1

-- Real jet ski: M_Veh_JetSki.
local function buildJetSkiAsset(spec: VehicleSpec, visuals: { Model }): Model
	local ctx = newCtx(spec, Vector3.new(1, 1, 1), Vector3.zero, ORANGE)
	local origin = Builder.JETSKI_ORIGIN
	local atts = AssetIds.Attachments.M_Veh_JetSki or {}
	local function at(name: string, fallback: Vector3): Vector3
		local p = atts[name]
		return if p then p + origin else fallback
	end
	weldVisuals(ctx, visuals, origin)
	local function hidden(part: BasePart)
		part.Transparency = 1
		part.CastShadow = false
	end
	local seatPos = at("ATT_DriverSeat", Vector3.new(0, 1.1, 1.4))
	local driver = seat(ctx, true, "DriverSeat", Vector3.new(1.35, 0.5, 3.0), seatPos)
	hidden(driver)
	-- nav lights: tiny lamps in the modelled housings with short-range PointLights
	type Lamp = { name: string, pos: Vector3, color: Color3 }
	local lamps: { Lamp } = {
		{ name = "NavPort", pos = Vector3.new(-0.9, 0.5, -3.9), color = RED_LIGHT },
		{ name = "NavStarboard", pos = Vector3.new(0.9, 0.5, -3.9), color = GREEN_LIGHT },
		{ name = "NavMasthead", pos = Vector3.new(0, 2.7, 4.3), color = WHITE_LIGHT },
	}
	for _, l in lamps do
		local lamp = navLight(ctx, l.name, at(`ATT_{l.name}`, l.pos), l.color, 0, nil)
		lamp.Size = Vector3.new(0.12, 0.12, 0.12)
		lamp.CastShadow = false
		local light = lamp:FindFirstChild("NavLight") :: PointLight
		light.Range = NAV_RANGE
		light.Brightness = NAV_BRIGHTNESS
	end
	-- gameplay attachments on the hull: the kill cord clip and the display (TODO: live speed on
	-- the display, e.g. a SurfaceGui fed from the hull speed)
	attach(ctx.root, "KillCord", at("ATT_KillCord", Vector3.new(-0.2, 2.3, -1.2)))
	attach(ctx.root, "Display", at("ATT_Display", Vector3.new(0, 2.2, -1.66)))
	local model = finish(
		ctx,
		spec,
		{ at("ATT_SurvivorSlot1", Vector3.new(0, -0.45, 7.3)) },
		at("ATT_TowHitch", Vector3.new(0, -0.3, 4.95)),
		at("ATT_BowPoint", Vector3.new(0, -0.3, -4.95))
	)
	-- the casualty lies prone along the rear deck, head to the rider: sitting up they blocked half the chase
	-- view (r2 art review, playtest 3). The outline-only hi-vis keeps the prone body reading as a person.
	-- VehicleService stacks the body up the slot's Y axis, which now points forward.
	local slot = ctx.root:FindFirstChild("SurvivorSlot1") :: Attachment
	slot.CFrame = CFrame.new(slot.Position + Vector3.new(0, 0.6, 0))
		* CFrame.Angles(-math.pi / 2, 0, 0)
	-- the rider's seated eye (ATT_EyePoint), relative to the seat
	local eye = driver:FindFirstChild("EyePoint") :: Attachment
	eye.Position = at("ATT_EyePoint", seatPos + spec.eyePoint) - seatPos
	model:SetAttribute("Visual", visuals[1].Name)
	return model
end

local STEEL = Color3.fromRGB(178, 184, 190)
local DECK_GREY = Color3.fromRGB(146, 152, 156)
local GLASS_TINT = Color3.fromRGB(26, 42, 56)

-- A flat plate through four corners (bottomA/bottomB, topA/topB): the hull chine and flare.
local function plate(
	ctx: Ctx,
	name: string,
	bottomA: Vector3,
	bottomB: Vector3,
	topA: Vector3,
	topB: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local up = ((topA + topB) - (bottomA + bottomB)) * 0.5
	local along = ((bottomB + topB) - (bottomA + topA)) * 0.5
	local yAxis = up.Unit
	local zAxis = (along - yAxis * along:Dot(yAxis)).Unit
	local xAxis = yAxis:Cross(zAxis).Unit
	local centre = (bottomA + bottomB + topA + topB) * 0.25
	local cf = CFrame.fromMatrix(centre, xAxis, yAxis, zAxis)
	return newPart(
		ctx,
		"Part",
		name,
		Vector3.new(thickness, up.Magnitude + 0.08, along.Magnitude + 0.18),
		cf,
		color,
		material
	)
end

-- A square-section bar between two points (rails, lifelines, stays, fender ropes).
local function strut(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local d = b - a
	return newPart(
		ctx,
		"Part",
		name,
		Vector3.new(thickness, thickness, d.Magnitude),
		CFrame.lookAt((a + b) * 0.5, b),
		color,
		material
	)
end

local function disc(
	ctx: Ctx,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = newPart(ctx, "Part", name, size, cf, color, material) :: Part
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A half-bow volume: a WedgePart on its side so its triangular plan tapers to the centre line
-- at `zBack - depth` and its full half beam sits at `zBack` (the raked, flared bow).
local function bowHalf(
	ctx: Ctx,
	name: string,
	halfBeam: number,
	height: number,
	depth: number,
	y: number,
	zBack: number,
	sx: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local cf = CFrame.new(sx * halfBeam * 0.5, y, zBack - depth * 0.5)
		* CFrame.Angles(0, 0, if sx > 0 then -math.pi / 2 else math.pi / 2)
	return newPart(
		ctx,
		"WedgePart",
		name,
		Vector3.new(height, halfBeam, depth),
		cf,
		color,
		material
	)
end

-- A life ring in the XY plane, facing +Z.
local function lifeRing(
	ctx: Ctx,
	name: string,
	centre: Vector3,
	radius: number,
	girth: number,
	depth: number
)
	local segments = 12
	for i = 1, segments do
		local a1 = (i - 1) / segments * math.pi * 2
		local a2 = i / segments * math.pi * 2
		local x1, y1 = math.cos(a1) * radius, math.sin(a1) * radius
		local x2, y2 = math.cos(a2) * radius, math.sin(a2) * radius
		local mid = centre + Vector3.new((x1 + x2) * 0.5, (y1 + y2) * 0.5, 0)
		local radial = Vector3.new(x1 + x2, y1 + y2, 0).Unit
		local tangent = Vector3.new(x2 - x1, y2 - y1, 0).Unit
		local cf = CFrame.fromMatrix(mid, Vector3.new(0, 0, 1), radial, tangent)
		newPart(
			ctx,
			"Part",
			`{name}{i}`,
			Vector3.new(depth, girth, (Vector3.new(x2 - x1, y2 - y1, 0)).Magnitude + 0.04),
			cf,
			if i >= 10 or i <= 2 then ORANGE else WHITE
		)
	end
end

-- All-weather lifeboat, 17.3 m x 5.9 m (51.9 x 17.7 studs). Collision box unchanged: 7.5 studs
-- deep, keel at -3.75, deck at +2.95. The Severn-style shell is a navy displacement hull (flared
-- lower panels, hard chine, a raked and plan-tapered bow in WedgeParts), an orange wheelhouse with
-- dark windows and a white roof, mast/radar, fender rail and grab lines, and a towing post aft.
-- The blue beacon starts off; the client flashes it only while this boat's owner is on a call.
local function buildLifeboat(spec: VehicleSpec): Model
	-- the visible Body sits inside the shell: a greybox slab must not show through the bow taper
	local ctx = newCtx(spec, Vector3.new(6.0, 4.0, 36), Vector3.new(0, -0.6, 2.0), NAVY)
	local KEEL_Y, CHINE_Y, SHEER_Y = -2.8, 0.9, 3.15
	local stations = {
		{ z = 25.1, keel = 3.3, chine = 8.0, sheer = 8.55 },
		{ z = 19.0, keel = 3.4, chine = 8.1, sheer = 8.6 },
		{ z = 8.0, keel = 3.5, chine = 8.1, sheer = 8.6 },
		{ z = -4.0, keel = 3.5, chine = 8.05, sheer = 8.55 },
		{ z = -13.0, keel = 3.0, chine = 7.5, sheer = 8.1 },
		{ z = -18.5, keel = 2.0, chine = 6.0, sheer = 6.7 },
		{ z = -22.5, keel = 1.0, chine = 3.4, sheer = 4.2 },
		{ z = -25.0, keel = 0.35, chine = 0.85, sheer = 1.15 },
	}
	for _, sx in { -1, 1 } do
		local side = if sx > 0 then "S" else "P"
		-- the parallel-body hull: two flat panels meeting at the hard chine
		for i = 1, 5 do
			local a, b = stations[i], stations[i + 1]
			plate(
				ctx,
				`HullLower{i}{side}`,
				Vector3.new(sx * a.keel, KEEL_Y, a.z),
				Vector3.new(sx * b.keel, KEEL_Y, b.z),
				Vector3.new(sx * a.chine, CHINE_Y, a.z),
				Vector3.new(sx * b.chine, CHINE_Y, b.z),
				0.36,
				NAVY
			)
			plate(
				ctx,
				`HullUpper{i}{side}`,
				Vector3.new(sx * a.chine, CHINE_Y, a.z),
				Vector3.new(sx * b.chine, CHINE_Y, b.z),
				Vector3.new(sx * a.sheer, SHEER_Y, a.z),
				Vector3.new(sx * b.sheer, SHEER_Y, b.z),
				0.36,
				NAVY
			)
			strut(
				ctx,
				`Chine{i}{side}`,
				Vector3.new(sx * (a.chine + 0.12), CHINE_Y, a.z),
				Vector3.new(sx * (b.chine + 0.12), CHINE_Y, b.z),
				0.32,
				STEEL
			)
			strut(
				ctx,
				`SheerBand{i}{side}`,
				Vector3.new(sx * (a.sheer - 0.02), 2.76, a.z),
				Vector3.new(sx * (b.sheer - 0.02), 2.76, b.z),
				0.42,
				ORANGE
			)
			strut(
				ctx,
				`SheerCap{i}{side}`,
				Vector3.new(sx * a.sheer, SHEER_Y + 0.08, a.z),
				Vector3.new(sx * b.sheer, SHEER_Y + 0.08, b.z),
				0.5,
				WHITE
			)
		end
		-- the lower bow is lofted like the body, so the flare and chine run right to the stem
		for i = 5, 7 do
			local a, b = stations[i], stations[i + 1]
			plate(
				ctx,
				`BowLower{i}{side}`,
				Vector3.new(sx * a.keel, KEEL_Y, a.z),
				Vector3.new(sx * b.keel, KEEL_Y, b.z),
				Vector3.new(sx * a.chine, CHINE_Y, a.z),
				Vector3.new(sx * b.chine, CHINE_Y, b.z),
				0.36,
				NAVY
			)
		end
		-- the upper bow is one solid WedgePart per side: a raked, flared entry
		bowHalf(ctx, `BowUpper{side}`, 8.05, 3.85, 12.2, (SHEER_Y + CHINE_Y) * 0.5, -13.0, sx, NAVY)
		strut(
			ctx,
			`BowChine{side}`,
			Vector3.new(sx * 7.5, CHINE_Y, -13.0),
			Vector3.new(sx * 0.15, CHINE_Y, -25.2),
			0.4,
			STEEL
		)
		strut(
			ctx,
			`BowBand{side}`,
			Vector3.new(sx * 8.05, 2.76, -13.0),
			Vector3.new(sx * 0.1, 4.15, -25.2),
			0.42,
			ORANGE
		)
		strut(
			ctx,
			`BowCap{side}`,
			Vector3.new(sx * 8.1, SHEER_Y + 0.08, -13.0),
			Vector3.new(0, 4.53, -25.2),
			0.5,
			WHITE
		)
		-- the raised bow bulwark: the classic lifeboat sheer, one plate per bow station
		for i = 5, 7 do
			local a, b = stations[i], stations[i + 1]
			local capA = 3.15 + (-13.0 - a.z) / 12.2 * 1.3
			local capB = 3.15 + (-13.0 - b.z) / 12.2 * 1.3
			plate(
				ctx,
				`BowBulwark{i}{side}`,
				Vector3.new(sx * a.sheer, SHEER_Y, a.z),
				Vector3.new(sx * b.sheer, SHEER_Y, b.z),
				Vector3.new(sx * a.sheer, capA, a.z),
				Vector3.new(sx * b.sheer, capB, b.z),
				0.45,
				WHITE
			)
		end
		-- grey foredeck on the wedge top
		-- its aft end 0.05 past the bow hull's (no shared plane)
		bowHalf(ctx, `Foredeck{side}`, 7.95, 0.12, 12.25, 3.2, -12.95, sx, DECK_GREY)
	end
	-- keel, raked stem, transom
	deco(ctx, "Keel", Vector3.new(6.4, 1.7, 38.5), Vector3.new(0, -2.55, 4.0), NAVY)
	deco(ctx, "KeelStrip", Vector3.new(1.4, 0.45, 37.0), Vector3.new(0, -3.45, 4.5), DARK)
	newPart(
		ctx,
		"Part",
		"Stem",
		Vector3.new(1.0, 6.9, 1.5),
		CFrame.new(0, 0.0, -25.2) * CFrame.Angles(math.rad(-6), 0, 0),
		NAVY
	)
	deco(ctx, "StemBand", Vector3.new(1.2, 6.5, 0.3), Vector3.new(0, 0.0, -25.9), STEEL)
	deco(ctx, "Transom", Vector3.new(16.3, 6.2, 0.6), Vector3.new(0, -0.1, 25.25), NAVY)
	deco(ctx, "TransomBand", Vector3.new(16.5, 0.45, 0.75), Vector3.new(0, 2.76, 25.25), ORANGE)
	deco(ctx, "TransomCap", Vector3.new(16.6, 0.5, 0.8), Vector3.new(0, 3.23, 25.25), WHITE)
	deco(ctx, "Nameplate", Vector3.new(6.4, 1.0, 0.2), Vector3.new(0, 1.4, 25.6), WHITE)
	deco(ctx, "Deck", Vector3.new(15.0, 0.2, 37.5), Vector3.new(0, 2.85, 5.75), DECK_GREY)
	-- wheelhouse: orange, faceted rounded front, dark glass, white roof
	deco(ctx, "CabinSkirt", Vector3.new(13.2, 0.6, 17.8), Vector3.new(0, 3.15, -6.0), WHITE)
	deco(ctx, "Cabin", Vector3.new(12.8, 5.2, 17.6), Vector3.new(0, 5.6, -6.0), ORANGE)
	deco(ctx, "CabinFront", Vector3.new(9.0, 5.2, 0.5), Vector3.new(0, 5.6, -15.6), ORANGE)
	for _, sx in { -1, 1 } do
		plate(
			ctx,
			`CabinChamfer{sx}`,
			Vector3.new(sx * 6.35, 3.0, -14.4),
			Vector3.new(sx * 4.55, 3.0, -15.55),
			Vector3.new(sx * 6.35, 8.2, -14.4),
			Vector3.new(sx * 4.55, 8.2, -15.55),
			0.5,
			ORANGE
		)
		strut(
			ctx,
			`ChamferTrimTop{sx}`,
			Vector3.new(sx * 6.35, 8.12, -14.5),
			Vector3.new(sx * 4.55, 8.12, -15.62),
			0.18,
			WHITE
		)
	end
	deco(ctx, "Roof", Vector3.new(14.2, 0.45, 19.2), Vector3.new(0, 8.45, -6.0), WHITE)
	deco(ctx, "RoofVisor", Vector3.new(13.0, 0.3, 0.9), Vector3.new(0, 8.25, -15.75), WHITE)
	for _, sx in { -1, 1 } do
		deco(
			ctx,
			`RoofRail{sx}`,
			Vector3.new(0.22, 0.3, 15.0),
			Vector3.new(sx * 6.9, 8.75, -6.0),
			STEEL
		)
	end
	local screen = deco(
		ctx,
		"Windscreen",
		Vector3.new(7.7, 2.0, 0.16),
		Vector3.new(0, 7.35, -15.9),
		GLASS_TINT
	)
	screen.Transparency = 0.18
	screen.Material = Enum.Material.Glass
	for _, x in { -2.0, 2.0 } do
		deco(
			ctx,
			`WindscreenPost{x}`,
			Vector3.new(0.18, 2.15, 0.2),
			Vector3.new(x, 7.35, -15.95),
			WHITE
		)
	end
	deco(ctx, "WindscreenSill", Vector3.new(8.2, 0.2, 0.35), Vector3.new(0, 6.28, -15.95), WHITE)
	deco(ctx, "WindscreenHead", Vector3.new(8.2, 0.22, 0.35), Vector3.new(0, 8.38, -15.95), WHITE)
	for _, sx in { -1, 1 } do
		local chamferWindow = plate(
			ctx,
			`ChamferWindow{sx}`,
			Vector3.new(sx * 6.0, 6.35, -14.5),
			Vector3.new(sx * 4.55, 6.35, -15.42),
			Vector3.new(sx * 6.0, 8.15, -14.5),
			Vector3.new(sx * 4.55, 8.15, -15.42),
			0.14,
			GLASS_TINT
		)
		chamferWindow.Transparency = 0.2
		chamferWindow.Material = Enum.Material.Glass
		-- four side windows with white frames and mullions
		for i = 1, 4 do
			local z = -12.4 + (i - 1) * 3.6
			local win = deco(
				ctx,
				`SideWindow{i}{sx}`,
				Vector3.new(0.16, 1.85, 3.0),
				Vector3.new(sx * 6.48, 7.15, z),
				GLASS_TINT
			)
			win.Transparency = 0.22
			win.Material = Enum.Material.Glass
			deco(
				ctx,
				`WindowSill{i}{sx}`,
				Vector3.new(0.24, 0.16, 3.2),
				Vector3.new(sx * 6.55, 6.2, z),
				WHITE
			)
			deco(
				ctx,
				`WindowHead{i}{sx}`,
				Vector3.new(0.24, 0.16, 3.2),
				Vector3.new(sx * 6.55, 8.1, z),
				WHITE
			)
		end
		for i = 1, 3 do
			deco(
				ctx,
				`WindowPost{i}{sx}`,
				Vector3.new(0.24, 2.0, 0.22),
				Vector3.new(sx * 6.55, 7.15, -10.6 + (i - 1) * 3.6),
				WHITE
			)
		end
		deco(
			ctx,
			`CabinGrab{sx}`,
			Vector3.new(0.14, 0.14, 6.4),
			Vector3.new(sx * 6.55, 5.3, -6.2),
			WHITE
		)
	end
	local rearWindow = deco(
		ctx,
		"RearWindow",
		Vector3.new(10.4, 1.75, 0.16),
		Vector3.new(0, 7.1, 2.86),
		GLASS_TINT
	)
	rearWindow.Transparency = 0.22
	rearWindow.Material = Enum.Material.Glass
	for _, x in { -1.7, 1.7 } do
		deco(ctx, `RearWindowPost{x}`, Vector3.new(0.2, 1.9, 0.2), Vector3.new(x, 7.1, 2.88), WHITE)
	end
	deco(ctx, "RearDoor", Vector3.new(2.4, 3.4, 0.2), Vector3.new(0, 4.85, 2.9), WHITE)
	disc(
		ctx,
		"DoorPorthole",
		Vector3.new(0.16, 0.8, 0.8),
		CFrame.new(0, 6.25, 3.02) * CFrame.Angles(math.pi / 2, 0, 0),
		GLASS_TINT,
		Enum.Material.Glass
	)
	lifeRing(ctx, "LifeRing", Vector3.new(4.3, 4.55, 2.96), 0.8, 0.22, 0.2)
	-- crew seats, pedestals and the helm console (seat parts keep the controller's layout)
	deco(ctx, "HelmConsole", Vector3.new(5.4, 1.7, 1.1), Vector3.new(0, 4.9, -9.6), DARK)
	deco(ctx, "HelmDash", Vector3.new(5.6, 0.2, 1.35), Vector3.new(0, 5.8, -9.6), GREY)
	disc(
		ctx,
		"HelmWheel",
		Vector3.new(0.16, 1.5, 1.5),
		CFrame.new(0, 6.2, -9.05) * CFrame.Angles(math.pi / 2, 0, 0),
		DARK
	)
	deco(ctx, "HelmScreen", Vector3.new(1.8, 0.62, 0.12), Vector3.new(0, 5.55, -9.95), GLASS_TINT)
	for _, x in { 0.9, 1.25 } do
		deco(ctx, `Throttle{x}`, Vector3.new(0.14, 0.7, 0.14), Vector3.new(x, 6.1, -9.3), DARK)
	end
	local seatSpots = {
		{ name = "Driver", x = 0, z = -7.4, driver = true },
		{ name = "Passenger1", x = 2.9, z = -2.4, driver = false },
		{ name = "Passenger2", x = -2.9, z = -2.4, driver = false },
		{ name = "Passenger3", x = 0, z = 1.2, driver = false },
	}
	for _, spot in seatSpots do
		if spot.driver then
			seat(ctx, true, "DriverSeat", Vector3.new(1.6, 0.6, 2.2), Vector3.new(0, 4.5, -7.4))
		end
		deco(
			ctx,
			`{spot.name}Pedestal`,
			Vector3.new(2.0, 1.35, 2.4),
			Vector3.new(spot.x, 3.62, spot.z),
			GREY
		)
		deco(
			ctx,
			`{spot.name}Cushion`,
			Vector3.new(1.65, 0.14, 2.25),
			Vector3.new(spot.x, 4.82, spot.z),
			WHITE
		)
		deco(
			ctx,
			`{spot.name}Back`,
			Vector3.new(1.65, 1.0, 0.28),
			Vector3.new(spot.x, 5.25, spot.z + 1.16),
			WHITE
		)
	end
	for i = 1, spec.seats - 1 do
		local x = if i == 1 then 2.9 elseif i == 2 then -2.9 else 0
		local z = if i == 3 then 1.2 else -2.4
		seat(ctx, false, `PassengerSeat{i}`, Vector3.new(1.5, 0.6, 2.0), Vector3.new(x, 4.5, z))
	end
	-- aft survivor well: eight places, side benches, engine hatch
	local slots = {}
	for i = 1, spec.survivorCapacity do
		local side = if i % 2 == 1 then -1 else 1
		local row = math.floor((i - 1) / 2)
		table.insert(slots, Vector3.new(side * 3.4, 3.0, 7.5 + row * 3.4))
	end
	for _, sx in { -1, 1 } do
		deco(
			ctx,
			`Bench{sx}`,
			Vector3.new(1.1, 0.55, 9.0),
			Vector3.new(sx * 6.3, 3.35, 11.0),
			WHITE
		)
		deco(
			ctx,
			`BenchRail{sx}`,
			Vector3.new(0.16, 0.3, 9.0),
			Vector3.new(sx * 6.72, 3.75, 11.0), -- 0.05 inside the bench's end (6.75 left 0.02)
			ORANGE
		)
	end
	deco(ctx, "EngineHatch", Vector3.new(7.4, 0.8, 2.8), Vector3.new(0, 3.35, 19.5), ORANGE)
	deco(ctx, "EngineHatchTop", Vector3.new(7.5, 0.14, 2.9), Vector3.new(0, 3.8, 19.5), WHITE)
	-- towing post, winch and stern gear
	deco(ctx, "TowBase", Vector3.new(2.0, 1.2, 2.0), Vector3.new(0, 3.55, 22.8), DARK)
	deco(ctx, "TowPost", Vector3.new(0.9, 3.4, 0.9), Vector3.new(0, 5.45, 22.8), GREY)
	deco(ctx, "TowCrossbar", Vector3.new(4.4, 0.45, 0.7), Vector3.new(0, 6.7, 22.8), GREY)
	deco(ctx, "TowFairlead", Vector3.new(0.9, 0.5, 0.5), Vector3.new(0, 2.65, 25.25), DARK) -- centred in the transom
	disc(
		ctx,
		"WinchDrum",
		Vector3.new(2.4, 0.7, 0.7),
		CFrame.new(0, 4.1, 20.8) * CFrame.Angles(0, 0, math.pi / 2),
		DARK
	)
	for _, sx in { -1, 1 } do
		deco(
			ctx,
			`WinchPlate{sx}`,
			Vector3.new(0.24, 1.4, 1.4),
			Vector3.new(sx * 1.3, 4.1, 20.8),
			STEEL
		)
	end
	deco(ctx, "SternPlatform", Vector3.new(9.0, 0.2, 1.6), Vector3.new(0, 1.2, 25.7), GREY)
	for i = 1, 3 do
		deco(
			ctx,
			`SternStep{i}`,
			Vector3.new(1.4, 0.14, 0.5),
			Vector3.new(-6.3, 2.55 - (i - 1) * 0.5, 25.8),
			STEEL
		)
	end
	-- mast, yard, radar, antennas, lights
	deco(ctx, "MastBase", Vector3.new(1.8, 0.5, 2.0), Vector3.new(0, 8.85, -6.2), WHITE)
	deco(ctx, "Mast", Vector3.new(0.55, 6.4, 0.55), Vector3.new(0, 12.2, -6.2), WHITE)
	deco(ctx, "MastTop", Vector3.new(0.35, 2.0, 0.35), Vector3.new(0, 16.2, -6.2), WHITE)
	deco(ctx, "Yard", Vector3.new(9.2, 0.25, 0.25), Vector3.new(0, 14.8, -6.2), WHITE)
	deco(ctx, "RadarPedestal", Vector3.new(0.6, 0.7, 0.6), Vector3.new(0, 15.0, -6.2), DARK)
	disc(
		ctx,
		"Radar",
		Vector3.new(4.6, 0.35, 0.35),
		CFrame.new(0, 15.55, -6.2),
		WHITE,
		Enum.Material.Metal
	)
	for _, sx in { -1, 1 } do
		strut(
			ctx,
			`Stay{sx}`,
			Vector3.new(0, 16.2, -6.2),
			Vector3.new(sx * 6.7, 8.6, -13.6),
			0.1,
			STEEL
		)
		strut(
			ctx,
			`Antenna{sx}`,
			Vector3.new(sx * 1.0, 8.85, -2.0),
			Vector3.new(sx * 2.2, 14.0, -1.0),
			0.1,
			WHITE
		)
		deco(
			ctx,
			`GpsBase{sx}`,
			Vector3.new(1.1, 0.16, 1.1),
			Vector3.new(sx * 3.2, 8.75, 0.8),
			DARK
		)
		disc(
			ctx,
			`Gps{sx}`,
			Vector3.new(0.5, 0.9, 0.9),
			CFrame.new(sx * 3.2, 8.95, 0.8) * CFrame.Angles(0, 0, math.pi / 2),
			WHITE
		)
	end
	-- the beacon: dark blue glass when off, Neon and a PointLight only while on a call
	disc(
		ctx,
		"BeaconBase",
		Vector3.new(1.0, 0.3, 1.0),
		CFrame.new(0, 17.25, -6.2) * CFrame.Angles(0, 0, math.pi / 2),
		DARK
	)
	local beacon = disc(
		ctx,
		"Beacon",
		Vector3.new(0.8, 0.75, 0.75),
		CFrame.new(0, 17.68, -6.2) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(24, 42, 72)
	)
	beacon.Transparency = 0.08
	beacon:SetAttribute("LifeboatBeacon", true)
	beacon:SetAttribute("BeaconColor", BLUE_LIGHT)
	local glow = Instance.new("PointLight")
	glow.Name = "BeaconLight"
	glow.Color = BLUE_LIGHT
	glow.Range = 22
	glow.Brightness = 2.5
	glow.Shadows = false
	glow.Enabled = false
	glow.Parent = beacon
	navLight(ctx, "NavMasthead", Vector3.new(0, 15.15, -7.0), WHITE_LIGHT, 0, 225)
	navLight(ctx, "NavStern", Vector3.new(0, 5.8, 24.4), WHITE_LIGHT, math.pi, 135)
	for _, sx in { -1, 1 } do
		deco(
			ctx,
			`NavHousing{sx}`,
			Vector3.new(0.3, 0.5, 0.55),
			Vector3.new(sx * 6.55, 6.85, -12.4),
			WHITE
		)
	end
	navLight(ctx, "NavPort", Vector3.new(-6.55, 6.9, -12.75), RED_LIGHT, SIDELIGHT_YAW, 112.5)
	navLight(
		ctx,
		"NavStarboard",
		Vector3.new(6.55, 6.9, -12.75),
		GREEN_LIGHT,
		-SIDELIGHT_YAW,
		112.5
	)
	for _, sx in { -1, 1 } do
		disc(
			ctx,
			`Horn{sx}`,
			Vector3.new(0.6, 0.35, 0.35),
			CFrame.new(sx * 0.8, 8.3, -15.5) * CFrame.Angles(math.pi / 2, 0, 0),
			DARK
		)
	end
	disc(
		ctx,
		"Searchlight",
		Vector3.new(0.6, 0.7, 0.7),
		CFrame.new(0.9, 8.85, -14.5) * CFrame.Angles(math.pi / 2, 0, 0),
		WHITE
	)
	-- bow gear and jackstaff
	deco(ctx, "BowRoller", Vector3.new(0.7, 0.3, 1.4), Vector3.new(0, 3.3, -24.4), STEEL)
	deco(ctx, "Anchor", Vector3.new(1.4, 1.6, 0.5), Vector3.new(0, 1.5, -24.8), DARK)
	deco(ctx, "AnchorStock", Vector3.new(2.4, 0.28, 0.35), Vector3.new(0, 2.2, -24.8), DARK)
	deco(ctx, "Jackstaff", Vector3.new(0.12, 2.0, 0.12), Vector3.new(0, 4.2, -24.9), WHITE)
	deco(ctx, "JackFlag", Vector3.new(0.9, 0.55, 0.08), Vector3.new(0.5, 4.9, -24.9), ORANGE)
	-- fender rail, stanchions, lifelines and fenders
	for _, sx in { -1, 1 } do
		deco(
			ctx,
			`SideRail{sx}`,
			Vector3.new(0.2, 0.2, 25.0),
			Vector3.new(sx * 8.55, 4.05, 11.5),
			WHITE
		)
		deco(
			ctx,
			`GrabLine{sx}`,
			Vector3.new(0.1, 0.1, 25.0),
			Vector3.new(sx * 8.45, 3.5, 11.5),
			DARK
		)
		for _, z in { -1.0, 3.2, 7.4, 11.6, 15.8, 20.0, 23.6 } do
			deco(
				ctx,
				`Stanchion{sx}{z}`,
				Vector3.new(0.16, 1.0, 0.16),
				Vector3.new(sx * 8.55, 3.6, z),
				WHITE
			)
		end
		local railPoints = {
			Vector3.new(sx * 8.55, 4.05, -1.0),
			Vector3.new(sx * 8.05, 4.45, -13.0),
			Vector3.new(sx * 6.65, 4.95, -18.5),
			Vector3.new(sx * 4.15, 5.35, -22.5),
			Vector3.new(0, 5.55, -25.2),
		}
		for i = 1, #railPoints - 1 do
			strut(ctx, `BowRail{sx}{i}`, railPoints[i], railPoints[i + 1], 0.2, WHITE)
		end
		local capAt = { 3.23, 3.23, 3.82, 4.22, 4.45 }
		for i = 2, #railPoints - 1 do
			local h = railPoints[i].Y - capAt[i]
			deco(
				ctx,
				`BowStanchion{sx}{i}`,
				Vector3.new(0.16, h, 0.16),
				Vector3.new(railPoints[i].X, capAt[i] + h * 0.5, railPoints[i].Z),
				WHITE
			)
		end
		for _, z in { -6.0, 5.0, 16.0 } do
			disc(
				ctx,
				`Fender{sx}{z}`,
				Vector3.new(1.9, 0.9, 0.9),
				CFrame.new(sx * 8.85, 1.7, z) * CFrame.Angles(0, 0, math.pi / 2),
				WHITE
			)
			for _, y in { 1.0, 2.4 } do
				disc(
					ctx,
					`FenderBand{sx}{z}{y}`,
					Vector3.new(0.3, 0.94, 0.94),
					CFrame.new(sx * 8.85, y, z) * CFrame.Angles(0, 0, math.pi / 2),
					ORANGE
				)
			end
			strut(
				ctx,
				`FenderLine{sx}{z}`,
				Vector3.new(sx * 8.55, 4.05, z),
				Vector3.new(sx * 8.85, 2.6, z),
				0.08,
				DARK
			)
		end
	end
	strut(ctx, "SternRail", Vector3.new(-8.4, 4.05, 24.2), Vector3.new(8.4, 4.05, 24.2), 0.2, WHITE)
	for _, x in { -8.4, -4.0, 4.0, 8.4 } do
		deco(
			ctx,
			`SternStanchion{x}`,
			Vector3.new(0.16, 1.0, 0.16),
			Vector3.new(x, 3.6, 24.2),
			WHITE
		)
	end
	deco(ctx, "Flagstaff", Vector3.new(0.12, 3.2, 0.12), Vector3.new(5.4, 4.9, 23.9), WHITE)
	deco(ctx, "Ensign", Vector3.new(1.4, 0.8, 0.08), Vector3.new(6.1, 5.9, 23.9), ORANGE)
	-- twin propellers and rudders, unchanged
	for _, sx in { -1, 1 } do
		deco(ctx, `Shaft{sx}`, Vector3.new(0.4, 0.4, 5.0), Vector3.new(sx * 2.6, -2.0, 22.0), DARK)
		deco(
			ctx,
			`Propeller{sx}`,
			Vector3.new(0.25, 2.2, 2.2),
			Vector3.new(sx * 2.6, -2.0, 24.6),
			GREY
		)
	end
	return finish(ctx, spec, slots, Vector3.new(0, 0.6, 25.4), Vector3.new(0, 0.6, -25.4))
end

-- The Tidewalker catamaran (M_Veh_Tidewalker, lifeboat frame) authored pivot in HullRoot space
-- (frame_offset.json hullroot_origin): ATT_Float1 (-5.5, -0.2, -19.99) is floatPoints[1] (-5.5, -3, -20).
Builder.TIDEWALKER_ORIGIN = Vector3.new(0, -2.8, -0.01)

local function buildTidewalkerAsset(spec: VehicleSpec, visuals: { Model }): Model
	local ctx = newCtx(spec, Vector3.new(1, 1, 1), Vector3.zero, NAVY)
	local origin = Builder.TIDEWALKER_ORIGIN
	local atts = AssetIds.Attachments[visuals[1].Name] or {}
	local function at(name: string, fallback: Vector3): Vector3
		local p = atts[name]
		return if p then p + origin else fallback
	end
	weldVisuals(ctx, visuals, origin)
	local function hidden(part: BasePart)
		part.Transparency = 1
		part.CastShadow = false
	end
	-- functional seats on the flybridge, invisible inside the modelled helm seats
	local seatSize = Vector3.new(1.5, 0.6, 2.0)
	hidden(seat(ctx, true, "DriverSeat", seatSize, at("ATT_DriverSeat", Vector3.new(0, 10.88, -3))))
	for i = 1, spec.seats - 1 do
		local fallback = Vector3.new((i - 2) * 2.3, 10.88, -3)
		hidden(seat(ctx, false, `PassengerSeat{i}`, seatSize, at(`ATT_PassengerSeat{i}`, fallback)))
	end
	type Lamp = { name: string, pos: Vector3, color: Color3, yaw: number, sector: number }
	local lamps: { Lamp } = {
		{
			name = "NavMasthead",
			pos = Vector3.new(0.75, 19, 3.9),
			color = WHITE_LIGHT,
			yaw = 0,
			sector = 225,
		},
		{
			name = "NavStern",
			pos = Vector3.new(0, 16, 9.7),
			color = WHITE_LIGHT,
			yaw = math.pi,
			sector = 135,
		},
		{
			name = "NavPort",
			pos = Vector3.new(-6.55, 16, -3.2),
			color = RED_LIGHT,
			yaw = SIDELIGHT_YAW,
			sector = 112.5,
		},
		{
			name = "NavStarboard",
			pos = Vector3.new(6.55, 16, -3.2),
			color = GREEN_LIGHT,
			yaw = -SIDELIGHT_YAW,
			sector = 112.5,
		},
	}
	for _, l in lamps do
		local lamp = navLight(ctx, l.name, at(`ATT_{l.name}`, l.pos), l.color, l.yaw, l.sector)
		lamp.Size = Vector3.new(0.2, 0.2, 0.2)
		lamp.CastShadow = false
	end
	-- survivor places on the aft deck
	local slots = {}
	for i = 1, spec.survivorCapacity do
		local side = if i % 2 == 1 then -1 else 1
		local fallback = Vector3.new(side * 3.4, 3.0, 7.5 + math.floor((i - 1) / 2) * 3.4)
		table.insert(slots, at(`ATT_SurvivorSlot{i}`, fallback))
	end
	local model = finish(
		ctx,
		spec,
		slots,
		at("ATT_TowHitch", Vector3.new(0, 0.6, 25.4)),
		at("ATT_BowPoint", Vector3.new(0, 0.6, -25.4))
	)
	model:SetAttribute("Visual", visuals[1].Name)
	return model
end

-- Fallback for a vehicle id without a hand-built greybox: a plain box with seats in a column.
local function buildGeneric(spec: VehicleSpec): Model
	local size = spec.hullSize
	local ctx =
		newCtx(spec, size * Vector3.new(0.95, 0.6, 0.95), Vector3.new(0, -size.Y * 0.2, 0), ORANGE)
	seat(ctx, true, "DriverSeat", Vector3.new(1.4, 0.5, 1.4), Vector3.new(0, size.Y * 0.2, 0))
	for i = 1, spec.seats - 1 do
		seat(
			ctx,
			false,
			`PassengerSeat{i}`,
			Vector3.new(1.4, 0.5, 1.4),
			Vector3.new(0, size.Y * 0.2, i * 1.8)
		)
	end
	local slots = {}
	for i = 1, spec.survivorCapacity do
		table.insert(slots, Vector3.new(0, size.Y * 0.2, -i * 1.8))
	end
	return finish(ctx, spec, slots, Vector3.new(0, 0, size.Z / 2), Vector3.new(0, 0, -size.Z / 2))
end

-- Builds a vehicle at the origin with its HullRoot anchored. The caller pivots and parents it.
-- visuals: the real models (RIB, jet ski, Tidewalker; see the header); nil or empty builds the greybox.
function Builder.build(spec: VehicleSpec, visuals: { Model }?): Model
	local kind = spec.base or spec.id -- premium boats use their base hull's layout
	local model = if kind == "JetSki"
			and visuals
			and #visuals > 0
		then buildJetSkiAsset(spec, visuals)
		elseif kind == "JetSki" then buildJetSki(spec)
		elseif kind == "RIB" and visuals and #visuals > 0 then buildRIBAsset(spec, visuals)
		elseif kind == "RIB" then buildRIB(spec)
		elseif kind == "Lifeboat" and visuals and #visuals > 0 then buildTidewalkerAsset(
			spec,
			visuals
		)
		elseif kind == "Lifeboat" then buildLifeboat(spec)
		else buildGeneric(spec)
	if model:GetAttribute("Visual") == nil then
		model:SetAttribute("Visual", "Greybox")
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	return model
end

return Builder
