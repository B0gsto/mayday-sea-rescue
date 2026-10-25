--!strict
-- Sub/Builder: the placeholder submarine from Parts (docs/23 (h), WP-8) until the Blender model lands.
-- Same layout as Boat/Builder where it matters: Model, PrimaryPart = HullRoot (invisible collidable box,
-- the only part with mass), DriverSeat (VehicleSeat), PassengerSeat1, SurvivorSlot1..2 and BowPoint
-- attachments on HullRoot; every visual part Massless, CanCollide = false, welded to HullRoot. Built at
-- the origin, bow to -Z; the caller pivots and parents it. Sub/Rig adds its movers on first step.
-- Attributes: Sub = true (SubController, CameraController and BoatController key off it), VehicleId,
-- CameraMode, Capacity, SurvivorCount, Draft.
local Dive = require(script.Parent.Dive)

local YELLOW = Color3.fromRGB(255, 196, 0)
local DARK = Color3.fromRGB(45, 48, 52)
local GLASS = Color3.fromRGB(170, 215, 235)

local Builder = {}

local function part(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Massless = true
	p.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	return p
end

local function attach(root: BasePart, name: string, at: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = at
	a.Parent = root
end

function Builder.build(vehicleId: string?): Model
	local model = Instance.new("Model")
	model.Name = "Submarine"
	local root = Instance.new("Part")
	root.Name = "HullRoot"
	root.Size = Vector3.new(5, 5, 14)
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	local alongZ = CFrame.Angles(0, math.pi / 2, 0) -- a Cylinder's axis is X
	local cyl, ball = Enum.PartType.Cylinder, Enum.PartType.Ball
	part(model, root, "Hull", Vector3.new(11, 5, 5), alongZ, YELLOW, cyl)
	part(model, root, "Bow", Vector3.new(5, 5, 5), CFrame.new(0, 0, -5.5), YELLOW, ball)
	part(model, root, "Stern", Vector3.new(4.2, 4.2, 4.2), CFrame.new(0, 0, 5.8), YELLOW, ball)
	local dome =
		part(model, root, "Dome", Vector3.new(3.8, 3.8, 3.8), CFrame.new(0, 2.2, -2.4), GLASS, ball)
	dome.Material = Enum.Material.Glass
	dome.Transparency = 0.45
	part(
		model,
		root,
		"Hatch",
		Vector3.new(0.6, 2, 2),
		CFrame.new(0, 2.6, 1.6) * CFrame.Angles(0, 0, math.pi / 2),
		DARK,
		cyl
	)
	part(model, root, "FinTop", Vector3.new(0.3, 2.4, 2), CFrame.new(0, 2.6, 6.4), YELLOW)
	part(model, root, "FinBottom", Vector3.new(0.3, 1.8, 1.6), CFrame.new(0, -2.3, 6.4), YELLOW)
	part(model, root, "FinSide", Vector3.new(6.4, 0.3, 1.8), CFrame.new(0, 0, 6.4), YELLOW)
	part(model, root, "BowPlanes", Vector3.new(6.6, 0.25, 1.2), CFrame.new(0, -0.6, -3.6), DARK)
	part(
		model,
		root,
		"PropHub",
		Vector3.new(0.8, 0.9, 0.9),
		CFrame.new(0, 0, 8.2) * alongZ,
		DARK,
		cyl
	)
	for i = 0, 2 do
		local spin = CFrame.new(0, 0, 8.2) * CFrame.Angles(0, 0, i * 2 * math.pi / 3)
		part(
			model,
			root,
			`PropBlade{i + 1}`,
			Vector3.new(0.5, 1.6, 0.15),
			spin * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0.5, 0),
			DARK
		)
	end
	for _, x in { -1.4, 1.4 } do
		local lamp = part(
			model,
			root,
			"Headlight",
			Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(x, -0.8, -7.6),
			Color3.fromRGB(255, 244, 214),
			ball
		)
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 45
		light.Angle = 55
		light.Brightness = 4
		light.Color = Color3.fromRGB(255, 244, 214)
		light.Parent = lamp
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.6, 0.4, 1.6)
	seat.CFrame = CFrame.new(0, 0.9, -2.4)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.HeadsUpDisplay = false
	seat.Parent = model
	local passenger = Instance.new("Seat")
	passenger.Name = "PassengerSeat1"
	passenger.Size = Vector3.new(1.6, 0.4, 1.6)
	passenger.CFrame = CFrame.new(0, 0.9, 0.6)
	passenger.Transparency = 1
	passenger.CanCollide = false
	passenger.Massless = true
	passenger.Parent = model
	for _, s in { seat :: BasePart, passenger } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = s
		w.Parent = s
	end

	attach(root, "SurvivorSlot1", Vector3.new(-1, 0.4, 2.6))
	attach(root, "SurvivorSlot2", Vector3.new(1, 0.4, 2.6))
	attach(root, "BowPoint", Vector3.new(0, 0, -8))
	model:SetAttribute("Sub", true)
	model:SetAttribute("VehicleId", vehicleId or "Submarine")
	model:SetAttribute("CameraMode", "Chase")
	model:SetAttribute("Capacity", Dive.SEATS)
	model:SetAttribute("SurvivorCount", 0)
	model:SetAttribute("Draft", Dive.DRAFT)
	return model
end

return Builder
