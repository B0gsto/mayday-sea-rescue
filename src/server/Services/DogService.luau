--!strict
-- DogService: Bosun, every player's Newfoundland (docs 01: MVP follower who barks and points).
--
-- A greybox dog (chunky black blocks, white chest patch, Rescue Orange vest) follows its player on
-- land (AlignPosition / AlignOrientation, no collisions: docs 02 section 10.8), floats in his vest
-- on water, and rides the player's boat (welded to a slot) while they sit in it. Every few
-- seconds he sniffs for the nearest victim from CallService.GetVictimPositions and, inside his
-- nose range, faces it and fires DogPoint to his player:
--   DogPoint:FireClient(player, { dog = Model, direction = Vector3 (unit, flat),
--                                 position = Vector3, distance = number })
-- The client (DogController) turns his head, shows a "Woof!" bubble and a small arrow.
--
-- API (server): DogService.GetDog(player): Model?
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local DogService = {}
DogService.Priority = 50

local NOSE_RANGE = 80 -- docs 02 section 5 (Kennel upgrades are [L]) -- tune
local POINT_INTERVAL = 4 -- seconds between sniffs -- tune
local POINT_HOLD = 2.5 -- seconds he keeps facing the victim
local LEG_HEIGHT = 1.85 -- body centre above the ground
local FLOAT_HEIGHT = 0.5 -- body centre above the water surface
local TELEPORT_DISTANCE = 70

local COLORS = {
	fur = Color3.fromRGB(24, 24, 28),
	nose = Color3.fromRGB(10, 10, 12),
	chest = Color3.fromHex("F4F1EA"), -- Hull White
	vest = Color3.fromHex("FF6B1A"), -- Rescue Orange: "us" (docs 05 section 3.2)
	eye = Color3.fromHex("EAF7F5"),
	tongue = Color3.fromRGB(230, 110, 130),
}

type Dog = {
	player: Player,
	model: Model,
	body: BasePart,
	alignPos: AlignPosition,
	alignRot: AlignOrientation,
	rideWeld: WeldConstraint?,
	rideModel: Model?,
	waitAt: Vector3?, -- set while the player rides a first-person craft (jet ski): Bosun waits ashore
	waitFace: Vector3?,
	pointUntil: number,
	pointDir: Vector3?,
}

local dogs: { [Player]: Dog } = {}
local folder: Folder

local weather: any = nil
local function seaHeight(position: Vector3): number
	if weather == nil then
		local module = Shared:FindFirstChild("Weather")
		local ok, result = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
		end
		weather = if ok then result else false
	end
	if weather then
		local ok, h = pcall(weather.heightAt, position)
		if ok and type(h) == "number" then
			return h
		end
	end
	return 0
end

local callService: any = nil
local function victimPositions(player: Player): { Vector3 }
	if callService == nil then
		local module = script.Parent:FindFirstChild("CallService")
		local ok, result = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
		end
		callService = if ok and type(result) == "table" then result else false
		if not callService then
			task.delay(10, function()
				callService = nil -- retry later; CallService may not exist yet
			end)
		end
	end
	if not callService or type(callService.GetVictimPositions) ~= "function" then
		return {}
	end
	local ok, positions = pcall(callService.GetVictimPositions, player)
	return if ok and type(positions) == "table" then positions else {}
end

local function part(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = model
	return p
end

local function attach(root: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
end

-- Builds Bosun at `cf` (facing cf.LookVector). Body is the root; Head hangs on a Weld (NeckWeld)
-- whose C0 the client may turn locally.
local function buildDog(player: Player, cf: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = `Bosun_{player.UserId}`
	model:SetAttribute("Owner", player.UserId)

	local body = part(model, "Body", Vector3.new(2, 1.6, 3.4), COLORS.fur, Enum.Material.Fabric)
	body.CFrame = cf
	model.PrimaryPart = body

	attach(
		body,
		part(model, "Vest", Vector3.new(2.2, 1.25, 1.9), COLORS.vest),
		CFrame.new(0, 0.22, -0.15)
	)
	attach(
		body,
		part(model, "VestBand", Vector3.new(2.25, 0.22, 0.35), COLORS.chest),
		CFrame.new(0, 0.3, -0.55)
	)
	attach(
		body,
		part(model, "VestHandle", Vector3.new(0.3, 0.3, 0.9), COLORS.vest),
		CFrame.new(0, 0.95, -0.15)
	)
	attach(
		body,
		part(model, "ChestPatch", Vector3.new(1.0, 0.85, 0.2), COLORS.chest),
		CFrame.new(0, -0.15, -1.72)
	)
	attach(
		body,
		part(model, "Rump", Vector3.new(2.05, 1.5, 0.8), COLORS.fur, Enum.Material.Fabric),
		CFrame.new(0, 0.05, 1.45)
	)
	for _, x in { -0.62, 0.62 } do
		for _, z in { -1.15, 1.15 } do
			local leg =
				part(model, "Leg", Vector3.new(0.6, 1.15, 0.6), COLORS.fur, Enum.Material.Fabric)
			attach(body, leg, CFrame.new(x, -1.3, z))
			attach(
				body,
				part(model, "Paw", Vector3.new(0.7, 0.3, 0.75), COLORS.fur),
				CFrame.new(x, -1.72, z - 0.08)
			)
		end
	end
	attach(
		body,
		part(model, "Tail", Vector3.new(0.45, 0.45, 1.3), COLORS.fur, Enum.Material.Fabric),
		CFrame.new(0, 0.55, 2.2) * CFrame.Angles(math.rad(35), 0, 0)
	)

	local head = part(model, "Head", Vector3.new(1.55, 1.35, 1.4), COLORS.fur, Enum.Material.Fabric)
	head.CFrame = body.CFrame * CFrame.new(0, 0.95, -2.05)
	local neck = Instance.new("Weld")
	neck.Name = "NeckWeld"
	neck.Part0 = body
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 0.95, -2.05)
	neck.Parent = body
	attach(
		head,
		part(model, "Snout", Vector3.new(0.95, 0.65, 0.65), COLORS.fur),
		CFrame.new(0, -0.28, -0.95)
	)
	attach(
		head,
		part(model, "Nose", Vector3.new(0.4, 0.28, 0.2), COLORS.nose),
		CFrame.new(0, -0.05, -1.32)
	)
	attach(
		head,
		part(model, "Tongue", Vector3.new(0.3, 0.1, 0.35), COLORS.tongue),
		CFrame.new(0, -0.64, -1.05)
	)
	for _, x in { -0.82, 0.82 } do
		attach(
			head,
			part(model, "Ear", Vector3.new(0.3, 0.8, 0.55), COLORS.fur, Enum.Material.Fabric),
			CFrame.new(x, -0.05, 0.05)
		)
		attach(
			head,
			part(model, "Eye", Vector3.new(0.2, 0.2, 0.08), COLORS.eye),
			CFrame.new(x * 0.42, 0.22, -0.71)
		)
	end

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "RootAttachment"
	rootAttachment.Parent = body
	local headTop = Instance.new("Attachment")
	headTop.Name = "BarkAttachment"
	headTop.Position = Vector3.new(0, 1.4, 0)
	headTop.Parent = head

	model.Parent = folder
	return model, body
end

local function makeDog(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then root.CFrame * CFrame.new(3, -1, 2) else CFrame.new(0, 10, 0)
	local model, body = buildDog(player, CFrame.new(start.Position) * start.Rotation)
	local rootAttachment = body:FindFirstChild("RootAttachment") :: Attachment

	local alignPos = Instance.new("AlignPosition")
	alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPos.Attachment0 = rootAttachment
	alignPos.MaxForce = 1e6
	alignPos.MaxVelocity = 45
	alignPos.Responsiveness = 22
	alignPos.Position = body.Position
	alignPos.Parent = body

	local alignRot = Instance.new("AlignOrientation")
	alignRot.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignRot.Attachment0 = rootAttachment
	alignRot.MaxTorque = 1e6
	alignRot.Responsiveness = 18
	alignRot.CFrame = body.CFrame.Rotation
	alignRot.Parent = body

	pcall(function()
		body:SetNetworkOwner(nil)
	end)

	dogs[player] = {
		player = player,
		model = model,
		body = body,
		alignPos = alignPos,
		alignRot = alignRot,
		rideWeld = nil,
		rideModel = nil,
		waitAt = nil,
		waitFace = nil,
		pointUntil = 0,
		pointDir = nil,
	}
end

local function vehicleOf(seat: BasePart?): Model?
	local node: Instance? = seat
	while node and node ~= Workspace do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

-- Where Bosun rides: a DogSlot attachment if the vehicle has one (CONTRACT: optional, stream B),
-- else the stern of bigger boats (behind the helm, out of the driver's view). He never rides a
-- first-person craft (canRide).
local function rideOffset(model: Model, root: BasePart): CFrame
	local slot = model:FindFirstChild("DogSlot", true)
	if slot and slot:IsA("Attachment") then
		return root.CFrame:ToObjectSpace(slot.WorldCFrame) * CFrame.new(0, LEG_HEIGHT, 0)
	end
	local id = model:GetAttribute("VehicleId")
	local spec = if type(id) == "string" then VehicleConfig.get(id) else nil
	local hull = if spec then spec.hullSize else root.Size
	local top = hull.Y / 2 + LEG_HEIGHT - 0.2
	return CFrame.new(0, top, hull.Z / 2 - 4) -- aft deck, behind the helm
end

local function stopRiding(dog: Dog)
	if dog.rideWeld then
		dog.rideWeld:Destroy()
		dog.rideWeld = nil
	end
	dog.rideModel = nil
	dog.alignPos.Enabled = true
	dog.alignRot.Enabled = true
	dog.alignPos.Position = dog.body.Position
	pcall(function()
		dog.body:SetNetworkOwner(nil)
	end)
end

local function startRiding(dog: Dog, model: Model)
	stopRiding(dog)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	dog.alignPos.Enabled = false
	dog.alignRot.Enabled = false
	dog.body.AssemblyLinearVelocity = Vector3.zero
	dog.body.CFrame = root.CFrame * rideOffset(model, root)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "BosunRide"
	weld.Part0 = root
	weld.Part1 = dog.body
	weld.Parent = dog.body
	dog.rideWeld = weld
	dog.rideModel = model
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundY(position: Vector3, character: Model): number
	rayParams.FilterDescendantsInstances = { folder, character }
	local hit =
		Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -60, 0), rayParams)
	local sea = seaHeight(position) + FLOAT_HEIGHT
	if hit then
		return math.max(hit.Position.Y + LEG_HEIGHT, sea)
	end
	return sea
end

-- A Newfoundland can't ride a jet ski: no dog on first-person craft (cameraMode "FirstPerson"),
-- whose rider's eye is right over the seat and sled. He rides the RIB and bigger boats.
local function canRide(model: Model): boolean
	local id = model:GetAttribute("VehicleId")
	if id == "JetSki" then
		return false
	end
	local spec = if type(id) == "string" then VehicleConfig.get(id) else nil
	return not (spec and spec.cameraMode == "FirstPerson")
end

local WAIT_SIDE = 4 -- studs beside the slipway's top, clear of the launching lane

-- The top of the station slipway (Map.Slipways.StationSlipway, its local -Z end at the quay).
local function slipwayTop(): (Vector3?, Vector3?)
	local map = Workspace:FindFirstChild("Map")
	local slips = map and map:FindFirstChild("Slipways")
	local ramp = slips and slips:FindFirstChild("StationSlipway")
	if ramp and ramp:IsA("BasePart") then
		local half = ramp.Size / 2
		local top = ramp.CFrame * CFrame.new(half.X + WAIT_SIDE, half.Y, -half.Z + 3)
		return top.Position, ramp.CFrame.LookVector * -1
	end
	return nil, nil
end

-- Where Bosun sits while the player is out on a jet ski: where he stands if that is dry land,
-- else beside the station slipway's top.
local function waitSpot(dog: Dog, character: Model): (Vector3, Vector3)
	local pos = dog.body.Position
	rayParams.FilterDescendantsInstances =
		{ folder, character, Workspace:FindFirstChild("Vehicles") }
	local hit = Workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), rayParams)
	local face = dog.body.CFrame.LookVector
	if hit and hit.Position.Y > seaHeight(hit.Position) + 0.5 then
		return Vector3.new(pos.X, hit.Position.Y + LEG_HEIGHT, pos.Z), face
	end
	local top, look = slipwayTop()
	if top then
		return Vector3.new(top.X, groundY(top, character), top.Z), look :: Vector3
	end
	return Vector3.new(pos.X, groundY(pos, character), pos.Z), face
end

local function hold(dog: Dog, at: Vector3, face: Vector3)
	if (dog.body.Position - at).Magnitude > TELEPORT_DISTANCE then
		dog.body.CFrame = CFrame.lookAt(at, at + face)
		dog.body.AssemblyLinearVelocity = Vector3.zero
	end
	dog.alignPos.Position = at
	local flat = Vector3.new(face.X, 0, face.Z)
	if flat.Magnitude > 1e-3 then
		dog.alignRot.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end

local function step(dog: Dog, now: number)
	local character = dog.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root then
		return
	end
	local vehicle = vehicleOf(humanoid.SeatPart)
	if vehicle and not canRide(vehicle) then
		if dog.rideModel then
			stopRiding(dog)
		end
		if not dog.waitAt then
			dog.waitAt, dog.waitFace = waitSpot(dog, character)
			dog.model:SetAttribute("Waiting", true)
		end
		hold(dog, dog.waitAt :: Vector3, dog.waitFace :: Vector3)
		return
	elseif dog.waitAt then
		-- back on foot (or aboard a boat he can ride): rejoin
		dog.waitAt, dog.waitFace = nil, nil
		dog.model:SetAttribute("Waiting", nil)
	end
	if vehicle then
		if dog.rideModel ~= vehicle or not (dog.rideWeld and dog.rideWeld.Parent) then
			startRiding(dog, vehicle)
		end
		return
	elseif dog.rideModel then
		stopRiding(dog)
		dog.body.CFrame = root.CFrame * CFrame.new(3, 0, 2)
	end

	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then
		flatLook = Vector3.new(0, 0, -1)
	end
	flatLook = flatLook.Unit
	local right = Vector3.new(-flatLook.Z, 0, flatLook.X)
	local desired = root.Position + right * 3.2 - flatLook * 1.5
	desired = Vector3.new(desired.X, groundY(desired, character), desired.Z)

	local pos = dog.body.Position
	if (desired - pos).Magnitude > TELEPORT_DISTANCE then
		dog.body.CFrame = CFrame.lookAt(desired, desired + flatLook)
		dog.body.AssemblyLinearVelocity = Vector3.zero
	end
	dog.alignPos.Position = desired

	local face = flatLook
	if now < dog.pointUntil and dog.pointDir then
		face = dog.pointDir
	else
		local toTarget = Vector3.new(desired.X - pos.X, 0, desired.Z - pos.Z)
		if toTarget.Magnitude > 2 then
			face = toTarget.Unit
		end
	end
	dog.alignRot.CFrame = CFrame.lookAt(Vector3.zero, face)
end

local function sniff(dog: Dog, now: number)
	local origin = dog.body.Position
	local best: Vector3? = nil
	local bestDist = NOSE_RANGE
	for _, position in victimPositions(dog.player) do
		if typeof(position) == "Vector3" then
			local d = (Vector3.new(position.X, origin.Y, position.Z) - origin).Magnitude
			if d < bestDist then
				best, bestDist = position, d
			end
		end
	end
	if not best then
		return
	end
	local flat = Vector3.new(best.X - origin.X, 0, best.Z - origin.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	dog.pointDir = flat.Unit
	dog.pointUntil = now + POINT_HOLD
	Net.event("DogPoint"):FireClient(dog.player, {
		dog = dog.model,
		direction = flat.Unit,
		position = best,
		distance = bestDist,
	})
end

function DogService.GetDog(player: Player): Model?
	local dog = dogs[player]
	return if dog then dog.model else nil
end

local function removeDog(player: Player)
	local dog = dogs[player]
	if dog then
		dog.model:Destroy()
		dogs[player] = nil
	end
end

local function onCharacter(player: Player, character: Model)
	local dog = dogs[player]
	if dog and dog.model.Parent then
		stopRiding(dog)
		local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if root then
			dog.body.CFrame = root.CFrame * CFrame.new(3, -1, 2)
		end
		return
	end
	character:WaitForChild("HumanoidRootPart", 5)
	if player.Parent and player.Character == character then
		makeDog(player, character)
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function DogService.Init()
	local existing = Workspace:FindFirstChild("Bosun")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Bosun"
		folder.Parent = Workspace
	end
	Players.PlayerRemoving:Connect(removeDog)
end

function DogService.Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, dog in dogs do
			step(dog, now)
		end
	end)
	while true do
		task.wait(POINT_INTERVAL)
		local now = os.clock()
		for _, dog in dogs do
			task.spawn(sniff, dog, now)
		end
	end
end

return DogService
