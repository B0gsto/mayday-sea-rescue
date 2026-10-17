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
--   PassengerSeat1..n  Seats
-- Colour scheme: rescue orange with white.

local VehicleConfig = require(script.Parent.Parent.Config.VehicleConfig)

type VehicleSpec = VehicleConfig.VehicleSpec

local ORANGE = Color3.fromRGB(255, 102, 0)
local WHITE = Color3.fromRGB(240, 240, 236)
local DARK = Color3.fromRGB(45, 48, 54)
local GLASS = Color3.fromRGB(120, 170, 200)

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
	alongZ: boolean
)
	local turn = if alongZ then CFrame.Angles(0, math.pi / 2, 0) else CFrame.identity
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

	local model = ctx.model
	model:SetAttribute("VehicleId", spec.id)
	model:SetAttribute("Capacity", spec.survivorCapacity)
	model:SetAttribute("SurvivorCount", 0)
	model:SetAttribute("Draft", spec.draft)
	model:SetAttribute("SpeedMultiplier", 1)
	return model
end

local function buildJetSki(spec: VehicleSpec): Model
	local ctx = newCtx(spec, Vector3.new(2.8, 0.9, 7.4), Vector3.new(0, -0.35, 0.5), ORANGE)
	deco(ctx, "Nose", Vector3.new(2.4, 0.8, 1.4), Vector3.new(0, -0.3, -3.6), WHITE)
	deco(ctx, "Stripe", Vector3.new(2.9, 0.2, 7.4), Vector3.new(0, -0.15, 0.5), WHITE)
	deco(ctx, "Console", Vector3.new(1.8, 0.6, 1.4), Vector3.new(0, 0.35, -1.9), ORANGE)
	deco(ctx, "Handlebar", Vector3.new(2.4, 0.2, 0.25), Vector3.new(0, 0.95, -1.4), DARK)
	deco(ctx, "HandlebarPost", Vector3.new(0.3, 0.5, 0.3), Vector3.new(0, 0.7, -1.5), DARK)
	seat(ctx, true, "DriverSeat", Vector3.new(1.2, 0.5, 2.6), Vector3.new(0, 0.35, 1.0))
	-- rescue sled towed flush behind the stern (docs 02: 1 survivor on the sled)
	deco(ctx, "Sled", Vector3.new(2.6, 0.3, 2.4), Vector3.new(0, -0.5, 5.9), WHITE)
	deco(ctx, "SledRailL", Vector3.new(0.2, 0.4, 2.4), Vector3.new(-1.25, -0.25, 5.9), ORANGE)
	deco(ctx, "SledRailR", Vector3.new(0.2, 0.4, 2.4), Vector3.new(1.25, -0.25, 5.9), ORANGE)
	return finish(
		ctx,
		spec,
		{ Vector3.new(0, -0.35, 5.9) },
		Vector3.new(0, -0.2, 4.5),
		Vector3.new(0, -0.2, -4.5)
	)
end

local function buildRIB(spec: VehicleSpec): Model
	local ctx = newCtx(spec, Vector3.new(4.6, 0.5, 14), Vector3.new(0, -0.85, 0), WHITE)
	tube(ctx, "TubeL", 13.4, 1.4, Vector3.new(-2.3, -0.4, 0.3), true)
	tube(ctx, "TubeR", 13.4, 1.4, Vector3.new(2.3, -0.4, 0.3), true)
	tube(ctx, "BowTube", 4.6, 1.4, Vector3.new(0, -0.4, -6.7), false)
	deco(ctx, "TubeStripeL", Vector3.new(0.1, 0.3, 11), Vector3.new(-3.01, -0.4, 0.5), WHITE)
	deco(ctx, "TubeStripeR", Vector3.new(0.1, 0.3, 11), Vector3.new(3.01, -0.4, 0.5), WHITE)
	deco(ctx, "Console", Vector3.new(1.6, 1.4, 1.2), Vector3.new(0, 0.1, -0.9), WHITE)
	local screen =
		deco(ctx, "Windscreen", Vector3.new(1.6, 0.6, 0.1), Vector3.new(0, 1.1, -1.45), GLASS)
	screen.Transparency = 0.4
	deco(ctx, "Engine", Vector3.new(1.1, 1.8, 1.0), Vector3.new(0, -0.1, 7.3), DARK)
	deco(ctx, "LightMast", Vector3.new(0.2, 2.4, 0.2), Vector3.new(0, 1.3, 6.4), DARK)
	deco(ctx, "Beacon", Vector3.new(0.5, 0.3, 0.5), Vector3.new(0, 2.6, 6.4), ORANGE)
	seat(ctx, true, "DriverSeat", Vector3.new(1.4, 0.6, 1.4), Vector3.new(0, -0.3, 0.9))
	for i = 1, spec.seats - 1 do
		local side = if i % 2 == 1 then -1 else 1
		local row = math.ceil(i / 2)
		seat(
			ctx,
			false,
			`PassengerSeat{i}`,
			Vector3.new(1.4, 0.6, 1.4),
			Vector3.new(side * 1.1, -0.3, 2.5 + row * 1.6)
		)
	end
	local slots = {}
	for i = 1, spec.survivorCapacity do
		local side = if i % 2 == 1 then -1 else 1
		table.insert(slots, Vector3.new(side * 1.0, -0.6, -3.5 - math.floor((i - 1) / 2) * 1.8))
	end
	return finish(ctx, spec, slots, Vector3.new(0, -0.2, 7.6), Vector3.new(0, -0.2, -7.6))
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
