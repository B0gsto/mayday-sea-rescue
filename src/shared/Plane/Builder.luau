--!strict
-- Plane/Builder (WP-7): the placeholder seaplane from code-built Parts, in Boat/Builder's layout so
-- VehicleService can treat it like a boat when it is parked (WP-10 wires it in).
--   HullRoot      invisible collision box over the floats (spec.hullSize), the only part with mass
--     Float1..4 + FloatForce1..4, DriveAttachment + DriveForce / DriveTorque   the boat rig: a parked,
--                 empty plane floats on Boat/Simulator like any hull
--     FlyAttachment + FlyVelocity (LinearVelocity) + FlyAttitude (AlignOrientation)   off when built;
--                 PlaneController switches them on locally while the pilot flies (Plane/Flight)
--     SurvivorSlot1..4, BowPoint   attachments (CONTRACT)
--     VisualJoint   Motor6D HullRoot -> Body (the fuselage)
--   Body          fuselage; every other part welds to it (Massless, no collision)
--   Prop          the propeller, on Motor6D PropJoint (Body -> Prop); PlaneController spins its Transform
--   DriverSeat    VehicleSeat (+ EyePoint), PassengerSeat1..3
-- Local frame: -Z is the nose, Y up; HullRoot centre at the origin, float bottoms at y -1.5.
local Flight = require(script.Parent.Flight)

local ORANGE = Color3.fromRGB(255, 102, 0)
local WHITE = Color3.fromRGB(240, 240, 236)
local DARK = Color3.fromRGB(45, 48, 54)
local GLASS = Color3.fromRGB(120, 170, 200)
local NAVY = Color3.fromRGB(22, 48, 78)

local Builder = {}

local function part(
	model: Model,
	body: BasePart?,
	className: string,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3
): BasePart
	local p = Instance.new(className) :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	if color == ORANGE then
		p:SetAttribute("Paint", "Body") -- livery roles (LiveryPaint)
	elseif color == NAVY then
		p:SetAttribute("Paint", "Secondary")
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

local function attach(parent: Instance, name: string, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = pos
	a.Parent = parent
	return a
end

-- Cylinder along the hull (Z).
local function rod(
	model: Model,
	body: BasePart,
	name: string,
	length: number,
	d: number,
	pos: Vector3,
	color: Color3
)
	local p = part(
		model,
		body,
		"Part",
		name,
		Vector3.new(length, d, d),
		CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0),
		color
	) :: Part
	p.Shape = Enum.PartType.Cylinder
end

function Builder.build(spec: Flight.Spec): Model
	local model = Instance.new("Model")
	model.Name = spec.id

	local root = part(model, nil, "Part", "HullRoot", spec.hullSize, CFrame.identity, WHITE)
	root.Transparency = 1
	root.CastShadow = false
	root.Massless = false
	root.CanCollide = true
	root.CanQuery = true
	local s = spec.hullSize
	root.CustomPhysicalProperties =
		PhysicalProperties.new(spec.massHint / (s.X * s.Y * s.Z), 0.3, 0, 1, 1)
	model.PrimaryPart = root

	-- fuselage (Body) high over the floats
	local bodyAt = Vector3.new(0, 6.5, -1)
	local body =
		part(model, nil, "Part", "Body", Vector3.new(4.2, 4.4, 16), CFrame.new(bodyAt), ORANGE)
	local joint = Instance.new("Motor6D")
	joint.Name = "VisualJoint"
	joint.Part0 = root
	joint.Part1 = body
	joint.C0 = CFrame.new(bodyAt)
	joint.Parent = root

	local function deco(name: string, size: Vector3, pos: Vector3, color: Color3, rot: CFrame?)
		return part(
			model,
			body,
			"Part",
			name,
			size,
			CFrame.new(pos) * (rot or CFrame.identity),
			color
		)
	end
	deco("BellyStripe", Vector3.new(4.3, 1, 16.1), Vector3.new(0, 4.9, -1), NAVY)
	deco(
		"Windscreen",
		Vector3.new(3.8, 1.8, 0.3),
		Vector3.new(0, 8, -8.6),
		GLASS,
		CFrame.Angles(math.rad(-35), 0, 0)
	)
	deco("WindowL", Vector3.new(0.2, 1.4, 8), Vector3.new(-2.1, 7.4, -3), GLASS)
	deco("WindowR", Vector3.new(0.2, 1.4, 8), Vector3.new(2.1, 7.4, -3), GLASS)
	deco(
		"TailCone",
		Vector3.new(2.6, 2.8, 8),
		Vector3.new(0, 7.2, 10.5),
		ORANGE,
		CFrame.Angles(math.rad(-6), 0, 0)
	)
	deco(
		"Fin",
		Vector3.new(0.4, 5, 4),
		Vector3.new(0, 10.6, 13),
		ORANGE,
		CFrame.Angles(math.rad(-15), 0, 0)
	)
	deco("Tailplane", Vector3.new(13, 0.35, 3.2), Vector3.new(0, 8.3, 13.5), WHITE)
	deco("Wing", Vector3.new(44, 0.6, 5.5), Vector3.new(0, 9, -3.5), WHITE)
	deco("WingTipL", Vector3.new(1.5, 0.65, 5.5), Vector3.new(-22.7, 9, -3.5), ORANGE)
	deco("WingTipR", Vector3.new(1.5, 0.65, 5.5), Vector3.new(22.7, 9, -3.5), ORANGE)
	for _, x in { -1, 1 } do
		-- wing strut from the fuselage foot out under the wing
		local from, to = Vector3.new(x * 2, 5, -3.5), Vector3.new(x * 9, 8.7, -3.5)
		local strut = CFrame.lookAt((from + to) / 2, to)
		part(
			model,
			body,
			"Part",
			"WingStrut",
			Vector3.new(0.3, 0.6, (to - from).Magnitude),
			strut,
			DARK
		)
		-- float, with its struts up to the fuselage
		rod(model, body, "Float", 20, 1.9, Vector3.new(x * 4.5, -0.5, 0), WHITE)
		rod(model, body, "FloatNose", 2, 1.3, Vector3.new(x * 4.5, -0.2, -10.8), NAVY)
		for _, z in { -5, 4 } do
			local a, b = Vector3.new(x * 4.5, 0.4, z), Vector3.new(x * 1.6, 4.4, z)
			part(
				model,
				body,
				"Part",
				"FloatStrut",
				Vector3.new(0.35, 0.35, (b - a).Magnitude),
				CFrame.lookAt((a + b) / 2, b),
				DARK
			)
		end
	end
	rod(model, body, "Cowl", 2.4, 3.6, Vector3.new(0, 6.6, -10.1), WHITE)
	rod(model, body, "Spinner", 1, 1.2, Vector3.new(0, 6.6, -11.6), ORANGE)

	-- propeller: two blades on a hub that spins about the nose axis
	local hubAt = CFrame.new(0, 6.6, -11.9)
	local prop = part(model, nil, "Part", "Prop", Vector3.new(0.8, 0.8, 0.4), hubAt, DARK)
	local propJoint = Instance.new("Motor6D")
	propJoint.Name = "PropJoint"
	propJoint.Part0 = body
	propJoint.Part1 = prop
	propJoint.C0 = body.CFrame:ToObjectSpace(hubAt)
	propJoint.Parent = body
	for _, y in { -1, 1 } do
		part(
			model,
			prop,
			"Part",
			"Blade",
			Vector3.new(0.5, 3.4, 0.15),
			hubAt * CFrame.new(0, y * 1.9, 0),
			DARK
		)
	end

	-- seats: pilot and three behind / beside (spec.seats = 4)
	local function seat(className: string, name: string, pos: Vector3): BasePart
		local p =
			part(model, body, className, name, Vector3.new(1.8, 0.4, 1.8), CFrame.new(pos), DARK)
		p.CanTouch = true -- seats sit on touch
		return p
	end
	local driver = seat("VehicleSeat", "DriverSeat", Vector3.new(-0.95, 5, -5.5)) :: VehicleSeat
	driver.MaxSpeed = 0 -- PlaneController flies it; the legacy seat motor must not
	driver.Torque = 0
	driver.TurnSpeed = 0
	driver.HeadsUpDisplay = false
	attach(driver, "EyePoint", spec.eyePoint)
	seat("Seat", "PassengerSeat1", Vector3.new(0.95, 5, -5.5))
	seat("Seat", "PassengerSeat2", Vector3.new(-0.95, 5, -1.5))
	seat("Seat", "PassengerSeat3", Vector3.new(0.95, 5, -1.5))

	-- boat rig (parked) and flight movers (flying)
	for i, p in spec.floatPoints do
		local a = attach(root, `Float{i}`, p)
		local f = Instance.new("VectorForce")
		f.Name = `FloatForce{i}`
		f.Attachment0 = a
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = false
		f.Force = Vector3.zero
		f.Parent = root
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

	local fly = attach(root, "FlyAttachment", Vector3.zero)
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "FlyVelocity"
	velocity.Attachment0 = fly
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.MaxForce = 0
	velocity.Enabled = false
	velocity.Parent = root
	local attitude = Instance.new("AlignOrientation")
	attitude.Name = "FlyAttitude"
	attitude.Mode = Enum.OrientationAlignmentMode.OneAttachment
	attitude.Attachment0 = fly
	attitude.RigidityEnabled = false
	attitude.MaxTorque = 0
	attitude.Responsiveness = 20
	attitude.Enabled = false
	attitude.Parent = root

	for i, z in { 1.5, 1.5, 4.5, 4.5 } do -- the cabin behind the seats
		attach(root, `SurvivorSlot{i}`, Vector3.new(if i % 2 == 1 then -0.95 else 0.95, 6, z))
	end
	attach(root, "BowPoint", Vector3.new(0, 0, -s.Z / 2))

	model:SetAttribute("VehicleId", spec.id)
	model:SetAttribute("CameraMode", spec.cameraMode)
	model:SetAttribute("Capacity", spec.survivorCapacity)
	model:SetAttribute("SurvivorCount", 0)
	model:SetAttribute("Draft", spec.draft)
	model:SetAttribute("SpeedMultiplier", 1)
	model:SetAttribute("Visual", "Greybox")
	return model
end

return Builder
