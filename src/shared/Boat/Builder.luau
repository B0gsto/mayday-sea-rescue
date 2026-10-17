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
-- Colour scheme: rescue orange with white; the RIB has an RNLI navy hull and orange tubes.

local VehicleConfig = require(script.Parent.Parent.Config.VehicleConfig)

type VehicleSpec = VehicleConfig.VehicleSpec

local ORANGE = Color3.fromRGB(255, 102, 0)
local WHITE = Color3.fromRGB(240, 240, 236)
local DARK = Color3.fromRGB(45, 48, 54)
local GLASS = Color3.fromRGB(120, 170, 200)
local NAVY = Color3.fromRGB(28, 42, 82)
local GREY = Color3.fromRGB(110, 114, 120)
local RED_LIGHT = Color3.fromRGB(255, 40, 30)
local GREEN_LIGHT = Color3.fromRGB(40, 255, 90)
local WHITE_LIGHT = Color3.fromRGB(255, 244, 225)
local BLUE_LIGHT = Color3.fromRGB(40, 110, 255)
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
)
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
	root.CanCollide = true
	root.CanTouch = false
	root.CanQuery = true
	local volume = spec.hullSize.X * spec.hullSize.Y * spec.hullSize.Z
	root.CustomPhysicalProperties = PhysicalProperties.new(spec.massHint / volume, 0.3, 0, 1, 1)
	root.Parent = model
	model.PrimaryPart = root

	local body = newPart(nil, "Part", "Body", bodySize, CFrame.new(bodyOffset), bodyColor) :: Part
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
-- at y -1.65, tube tops at +1.65, deck at 0. Navy deep-V hull inside 0.55 m orange tubes,
-- centre console with screen, jockey seats behind it, twin outboards, A-frame with radar and lights.
local function buildRIB(spec: VehicleSpec): Model
	local ctx = newCtx(spec, Vector3.new(6.2, 1.7, 22.6), Vector3.new(0, -0.85, 0.9), NAVY)
	deco(ctx, "Keel", Vector3.new(2.2, 0.6, 21.0), Vector3.new(0, -1.5, 0.6), NAVY)
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
function Builder.build(spec: VehicleSpec): Model
	local model = if spec.id == "JetSki"
		then buildJetSki(spec)
		elseif spec.id == "RIB" then buildRIB(spec)
		else buildGeneric(spec)
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	return model
end

return Builder
