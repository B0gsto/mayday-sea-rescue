--!strict
-- Heli/Builder (WP-6): greybox rescue helicopter from parts, built at the origin. Server-side
-- (VehicleService calls it from WP-10). Same conventions as Boat/Builder:
--   HullRoot   invisible collidable cabin box, the ONLY part with mass (MASS). PrimaryPart and the
--              network-owned part. Holds FlyAttachment with LinearVelocity "Lift" and
--              AlignOrientation "Attitude" (both off until HeliController flies it), WinchPoint
--              (under the door), SurvivorSlot1..n.
--   Body       visible cabin; every other part welds to it, Massless, CanCollide false.
--   DriverSeat VehicleSeat (EyePoint attachment), PassengerSeat1.
--   RotorHub   the main rotor (blades weld to it) on Motor6D "RotorJoint"; TailHub on
--              "TailRotorJoint". HeliController spins both by Transform.
-- Model tag "Heli"; attributes VehicleId, CameraMode, Capacity, SurvivorCount.
-- Size: AW139-ish, cabin ~4.4 m long (1 m = 3 studs), rotor 13.8 m.
local Winch = require(script.Parent.Winch)

local ORANGE = Color3.fromRGB(255, 102, 0)
local WHITE = Color3.fromRGB(240, 240, 236)
local DARK = Color3.fromRGB(45, 48, 54)
local GLASS = Color3.fromRGB(120, 170, 200)

local ROOT_SIZE = Vector3.new(7, 6, 13)
local MASS = 6400 / 37 -- RMU (1 RMU = 37 kg)
local ROTOR_Y = 4.6

local Builder = {}

local function part(
	model: Model,
	body: BasePart?,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if color == GLASS then Enum.Material.Glass else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	if color == ORANGE then
		p:SetAttribute("Paint", "Body") -- livery role (LiveryPaint)
	end
	if body then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = model
	return p
end

local function attach(parent: BasePart, name: string, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
	return a
end

-- A hub on a Motor6D from Body, with `blades` blades of `length` welded to it, spinning about the
-- hub's local Y (the main rotor) or, turned by `tilt`, about X (the tail rotor).
local function rotor(
	model: Model,
	body: BasePart,
	name: string,
	joint: string,
	at: CFrame,
	length: number,
	blades: number
): Part
	local hub = part(model, nil, name, Vector3.new(0.8, 0.5, 0.8), at, DARK)
	for i = 1, blades do
		local yaw = (i - 1) * math.pi * 2 / blades
		part(
			model,
			hub,
			`{name}Blade{i}`,
			Vector3.new(0.9, 0.15, length / 2),
			at * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.1, -length / 4),
			DARK
		)
	end
	local m = Instance.new("Motor6D")
	m.Name = joint
	m.Part0 = body
	m.Part1 = hub
	m.C0 = body.CFrame:ToObjectSpace(at)
	m.Parent = body
	return hub
end

local function seat(
	model: Model,
	body: BasePart,
	isDriver: boolean,
	name: string,
	pos: Vector3
): BasePart
	local s = Instance.new(if isDriver then "VehicleSeat" else "Seat") :: BasePart
	s.Name = name
	s.Size = Vector3.new(1.6, 0.5, 1.8)
	s.CFrame = CFrame.new(pos)
	s.Color = DARK
	s.Massless = true
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = true -- seats sit on touch
	if s:IsA("VehicleSeat") then
		-- HeliController flies it; the legacy seat motor must not drive
		s.MaxSpeed = 0
		s.Torque = 0
		s.TurnSpeed = 0
		s.HeadsUpDisplay = false
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = s
	weld.Parent = s
	s.Parent = model
	return s
end

function Builder.build(id: string): Model
	local model = Instance.new("Model")
	model.Name = id

	local root = part(model, nil, "HullRoot", ROOT_SIZE, CFrame.identity, DARK)
	root.Massless = false
	root.Transparency = 1
	root.CastShadow = false
	root.CanCollide = true
	root.CanQuery = true
	root.CustomPhysicalProperties =
		PhysicalProperties.new(MASS / (ROOT_SIZE.X * ROOT_SIZE.Y * ROOT_SIZE.Z), 0.3, 0, 1, 1)
	model.PrimaryPart = root

	local body = part(model, root, "Body", Vector3.new(6.6, 5.2, 10), CFrame.new(0, 0, 0.5), ORANGE)
	part(model, body, "Nose", Vector3.new(5.6, 3.6, 3), CFrame.new(0, -0.6, -5.9), ORANGE)
	part(
		model,
		body,
		"Windscreen",
		Vector3.new(5.4, 2.2, 0.3),
		CFrame.new(0, 1.3, -4.4) * CFrame.Angles(math.rad(-30), 0, 0),
		GLASS
	)
	part(model, body, "WindowL", Vector3.new(0.2, 1.8, 3.2), CFrame.new(-3.35, 1, -1.5), GLASS)
	part(model, body, "WindowR", Vector3.new(0.2, 1.8, 3.2), CFrame.new(3.35, 1, -1.5), GLASS)
	part(model, body, "Door", Vector3.new(0.2, 3.6, 3.6), CFrame.new(3.35, -0.4, 2.4), WHITE)
	part(model, body, "Stripe", Vector3.new(6.7, 0.6, 10.1), CFrame.new(0, -1.4, 0.5), WHITE)
	part(model, body, "Engine", Vector3.new(4, 1.6, 6), CFrame.new(0, 3.2, 1.5), WHITE)
	part(model, body, "Mast", Vector3.new(0.7, 1.2, 0.7), CFrame.new(0, 4, 0), DARK)
	part(model, body, "Boom", Vector3.new(1.6, 1.6, 14), CFrame.new(0, 1.2, 12.5), ORANGE)
	part(model, body, "Fin", Vector3.new(0.4, 4, 2.4), CFrame.new(0, 3.4, 19), ORANGE)
	part(model, body, "Stabiliser", Vector3.new(4.4, 0.3, 1.4), CFrame.new(0, 1.4, 18), WHITE)
	part(model, body, "WinchArm", Vector3.new(2, 0.4, 0.4), CFrame.new(4.3, 2.4, 2.4), DARK)
	for _, x in { -2.6, 2.6 } do -- skids: bottom at -4.5 = Flight spec.skid
		part(model, body, "Skid", Vector3.new(0.4, 0.4, 11), CFrame.new(x, -4.3, 0), DARK)
		part(model, body, "Strut", Vector3.new(0.3, 1.6, 0.3), CFrame.new(x, -3.4, -2.5), DARK)
		part(model, body, "Strut", Vector3.new(0.3, 1.6, 0.3), CFrame.new(x, -3.4, 2.5), DARK)
	end

	rotor(model, body, "RotorHub", "RotorJoint", CFrame.new(0, ROTOR_Y, 0), 41, 4)
	rotor(
		model,
		body,
		"TailHub",
		"TailRotorJoint",
		CFrame.new(0.5, 3.4, 19.6) * CFrame.Angles(0, 0, math.pi / 2),
		7,
		2
	)

	local driver = seat(model, body, true, "DriverSeat", Vector3.new(1.4, -1.4, -2.6))
	attach(driver, "EyePoint", Vector3.new(0, 2.6, 0))
	seat(model, body, false, "PassengerSeat1", Vector3.new(-1.4, -1.4, -2.6))

	local fly = attach(root, "FlyAttachment", Vector3.zero)
	local lift = Instance.new("LinearVelocity")
	lift.Name = "Lift"
	lift.Attachment0 = fly
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lift.MaxForce = 0 -- HeliController sets it from the assembly mass
	lift.Enabled = false
	lift.Parent = root
	local attitude = Instance.new("AlignOrientation")
	attitude.Name = "Attitude"
	attitude.Attachment0 = fly
	attitude.Mode = Enum.OrientationAlignmentMode.OneAttachment
	attitude.Responsiveness = 12
	attitude.MaxTorque = math.huge
	attitude.Enabled = false
	attitude.Parent = root
	attach(root, "WinchPoint", Vector3.new(4.8, 2.2, 2.4))
	for i = 1, Winch.SEATS do
		attach(root, `SurvivorSlot{i}`, Vector3.new(-1.4 + (i - 1) * 2.8, -1.4, 2.4))
	end

	model:AddTag("Heli")
	model:SetAttribute("VehicleId", id)
	model:SetAttribute("CameraMode", "Chase")
	model:SetAttribute("Capacity", Winch.SEATS)
	model:SetAttribute("SurvivorCount", 0)
	return model
end

return Builder
