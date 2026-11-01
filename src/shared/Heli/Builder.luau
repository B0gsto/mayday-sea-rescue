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
--
-- Real model: Builder.build(id, visuals) with M_Veh_RescueHeli (cloned by the server's AssetLoader,
-- authored in HullRoot space) keeps the same HullRoot and an invisible Body, skips the greybox
-- dressing, welds the body mesh to Body and the rotor meshes to RotorHub / TailHub (placed at
-- ATT_MainRotor / ATT_TailRotor, so the spin code is unchanged), and puts the seats, EyePoint,
-- WinchPoint, SurvivorSlots and PetSeat at the ATT_* points (AssetIds.Attachments). Without visuals
-- (asset failed to load) the greybox is built as before. Attribute Visual = asset name or "Greybox".
local AssetIds = require(script.Parent.Parent.Config.AssetIds)
local Winch = require(script.Parent.Winch)

local ORANGE = Color3.fromRGB(255, 102, 0)
local WHITE = Color3.fromRGB(240, 240, 236)
local DARK = Color3.fromRGB(45, 48, 54)
local GLASS = Color3.fromRGB(120, 170, 200)
local YELLOW = Color3.fromRGB(245, 205, 48) -- Lego bright yellow

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

-- The greybox cabin, boom, winch arm and skids (not built over the real model).
local function dressing(model: Model, body: BasePart)
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
	part(model, body, "WinchHook", Vector3.new(0.6, 0.6, 0.6), CFrame.new(5, 1.9, 2.4), YELLOW) -- the cable's end
	for _, x in { -2.6, 2.6 } do -- skids: bottom at -4.5 = Flight spec.skid
		part(model, body, "Skid", Vector3.new(0.4, 0.4, 11), CFrame.new(x, -4.3, 0), DARK)
		part(model, body, "Strut", Vector3.new(0.3, 1.6, 0.3), CFrame.new(x, -3.4, -2.5), DARK)
		part(model, body, "Strut", Vector3.new(0.3, 1.6, 0.3), CFrame.new(x, -3.4, 2.5), DARK)
	end
end

-- visuals: the real model (see the header); nil or empty builds the greybox.
function Builder.build(id: string, visuals: { Model }?): Model
	local real = if visuals and #visuals > 0 then visuals else nil
	local atts: { [string]: Vector3 } = if real
		then AssetIds.Attachments.M_Veh_RescueHeli or {}
		else {}
	local function at(name: string, fallback: Vector3): Vector3
		return atts[name] or fallback
	end
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
	if real then
		body.Transparency = 1
		body.CastShadow = false
	else
		dressing(model, body)
	end

	local mainAt = CFrame.new(at("ATT_MainRotor", Vector3.new(0, ROTOR_Y, 0)))
	local main = rotor(model, body, "RotorHub", "RotorJoint", mainAt, 41, if real then 0 else 4)
	local tailAt = CFrame.new(at("ATT_TailRotor", Vector3.new(0.5, 3.4, 19.6)))
		* CFrame.Angles(0, 0, math.pi / 2)
	local tail = rotor(model, body, "TailHub", "TailRotorJoint", tailAt, 7, if real then 0 else 2)

	local driverAt = at("ATT_DriverSeat", Vector3.new(1.4, -1.4, -2.6))
	local driver = seat(model, body, true, "DriverSeat", driverAt)
	attach(driver, "EyePoint", at("ATT_EyePoint", driverAt + Vector3.new(0, 2.6, 0)) - driverAt)
	local passenger = seat(
		model,
		body,
		false,
		"PassengerSeat1",
		at("ATT_PassengerSeat1", Vector3.new(-1.4, -1.4, -2.6))
	)

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
	-- under the hook: VehicleService.Climb hangs the cable here
	attach(root, "WinchPoint", at("ATT_WinchPoint", Vector3.new(5, 1.6, 2.4)))
	for i = 1, Winch.SEATS do
		local fallback = Vector3.new(-1.4 + (i - 1) * 2.8, -1.4, 2.4)
		attach(root, `SurvivorSlot{i}`, at(`ATT_SurvivorSlot{i}`, fallback))
	end
	local petSeat = atts.ATT_PetSeat
	if petSeat then
		attach(root, "PetSeat", petSeat) -- PetSeat.choose prefers it
	end

	if real then
		for _, p: BasePart in { main :: BasePart, tail, driver, passenger } do
			p.Transparency = 1
			p.CastShadow = false
		end
		for _, visual in real do
			visual:PivotTo(CFrame.identity) -- authored in HullRoot space
			for _, d in visual:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.Massless = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = if string.find(d.Name, "MainRotor", 1, true)
						then main
						elseif string.find(d.Name, "TailRotor", 1, true) then tail
						else body
					weld.Part1 = d
					weld.Parent = d
				end
			end
			visual.Parent = model
		end
	end

	model:AddTag("Heli")
	model:SetAttribute("VehicleId", id)
	model:SetAttribute("CameraMode", "Chase")
	model:SetAttribute("Capacity", Winch.SEATS)
	model:SetAttribute("SurvivorCount", 0)
	model:SetAttribute("Visual", if real then real[1].Name else "Greybox")
	return model
end

return Builder
