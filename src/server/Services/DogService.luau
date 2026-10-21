--!strict
-- DogService: Bosun, every player's Newfoundland (docs 01: MVP follower who barks and points).
--
-- Bosun is the uploaded LP mesh M_Chr_Bosun_LP: one textured MeshPart per Shared.Dog.BosunRig part
-- (G82), assembled on the rig's Motor6Ds; the greybox BosunRig Parts are the fallback when the upload
-- fails (and still stand in for the unfinished Water Dog Friends coat options). An invisible root part
-- "Body" carries the physics: he follows his player on land (AlignPosition / AlignOrientation, no
-- collisions: docs 02 section 10.8), floats in his harness on water, and rides the RIB and bigger boats
-- aft (welded to a DogSlot / the aft deck, out of the helm camera) while they sit in them. He never
-- rides a craft without a seat for him (the jet ski: driver seat only): he sits and waits ashore. The
-- parts hang on Motor6Ds named after the BosunMotion pose keys (Root, Neck, Jaw, Tail1, Tail2, eight leg
-- joints) whose Transforms DogController writes locally. Everyone sees this low-poly dog (docs/14 section 4:
-- no fur-card hero close-up).
--
-- Attributes on the dog model for the client: Mode ("Follow" | "Wait" | "Ride" | "Swim"), Wetness
-- (0..1, BosunWetness) and Wet (coat and wear darkened); Waiting (bool), Treat (a counter, bumped by
-- DogService.Treat for the daily challenge set: DogController spins him once and pops a "Woof!").
--
-- Every few seconds he sniffs for the nearest victim from CallService.GetVictimPositions and, inside his
-- nose range, faces it and fires DogPoint to his player:
--   DogPoint:FireClient(player, { dog = Model, direction = Vector3 (unit, flat),
--                                 position = Vector3, distance = number })
-- The client (DogController) turns his head, shows a "Woof!" bubble and a small arrow.
--
-- Cosmetics (RP-M5): the player's Cos_Dog attribute picks the companion (Config/Cosmetics/Dog: Bosun, or
-- a Water Dog Friends dog on Bosun's rig in its own coat colour; same abilities) and Cos_DogHarness /
-- Cos_DogBandana / Cos_DogJacket / Cos_DogHat what he wears (Config/Cosmetics/DogWear, geometry in
-- Shared.Dog.DogWear): a tint on the harness parts, and plain Parts in a "Wear" model welded to the Torso
-- / Head (darkened while he is wet). A life jacket hides the harness. Model attributes DogId, DogName, Breed.
--
-- API (server): DogService.GetDog(player): Model?, DogService.Treat(player): ()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local BosunRig = require(Shared:WaitForChild("Dog"):WaitForChild("BosunRig"))
local BosunWetness = require(Shared:WaitForChild("Dog"):WaitForChild("BosunWetness"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local DogVisual = require(Shared:WaitForChild("Dog"):WaitForChild("DogVisual"))
local DogWear = require(Shared:WaitForChild("Dog"):WaitForChild("DogWear"))
local Net = require(Shared:WaitForChild("Net"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local DogService = {}
DogService.Priority = 50

local NOSE_RANGE = 80 -- docs 02 section 5 (Kennel upgrades are [L]) -- tune
local POINT_INTERVAL = 4 -- seconds between sniffs -- tune
local POINT_HOLD = 2.5 -- seconds he keeps facing the victim
local LEG_HEIGHT = DogVisual.LEG_HEIGHT -- body centre above the ground
local FLOAT_HEIGHT = 0.5 -- body centre above the water surface
local TELEPORT_DISTANCE = 70
local WET_TICK = 0.5 -- seconds between wetness updates
local SWIM_DEPTH = LEG_HEIGHT - 0.4 -- water this deep under him: he swims
local WADE_DEPTH = 0.4 -- water this deep: his coat gets wet

type Anchors = { [string]: { part: BasePart, rest: CFrame } }

local SPECS: { [string]: any } = {}
for _, spec in BosunRig.PARTS do
	SPECS[spec.name] = spec
end

type Dog = {
	player: Player,
	model: Model,
	body: BasePart,
	alignPos: AlignPosition,
	alignRot: AlignOrientation,
	rideWeld: WeldConstraint?,
	rideModel: Model?,
	waitAt: Vector3?, -- set while the player rides the jet ski: he has no seat, so Bosun waits ashore
	waitFace: Vector3?,
	pointUntil: number,
	pointDir: Vector3?,
	mode: string,
	depth: number, -- water depth under him (studs, 0 on dry land / aboard)
	wetness: number,
	wet: boolean,
	lastSwim: boolean,
	variant: string, -- Cos_Dog option id this model was built for
	anchors: Anchors, -- Fore (Torso) / Head, rest pose in the authored frame
}

local WEAR_SLOTS = { "DogHarness", "DogBandana", "DogJacket", "DogHat" }
local WEAR_KIND = { DogBandana = "Bandana", DogJacket = "Jacket", DogHat = "Hat" }
local WET_DARKEN = 0.72 -- wet fabric drops about a quarter of its value (docs/05 3.3)

local dogs: { [Player]: Dog } = {}
local applyWear: (dog: Dog) -> ()
local dogOption: (dog: Dog) -> { [string]: any }
local folder: Folder

local weather: any = nil
local function getWeather(): any
	if weather == nil then
		local module = Shared:FindFirstChild("Weather")
		local ok, result = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
		end
		weather = if ok then result else false
	end
	return weather
end

local function seaHeight(position: Vector3): number
	if getWeather() then
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

-- The greybox rig: one plain Part per BosunRig entry, in `coat` (hex). The fallback when the uploads
-- fail, and the stand-in for the Water Dog Friends breeds that have no real model yet.
local function buildPlaceholder(model: Model, body: BasePart, base: CFrame, coat: string): Anchors
	local built: { [string]: BasePart } = { Body = body }
	local anchors: Anchors = {}
	for _, spec in BosunRig.PARTS do
		local p = Instance.new("Part")
		p.Name = spec.name
		p.Shape = (Enum.PartType :: any)[spec.shape]
		p.Size = spec.size
		local hex = if spec.color == BosunRig.COAT then coat else spec.color
		p.Color = Color3.fromHex(hex)
		p:SetAttribute("DryColor", hex)
		p.Material = (Enum.Material :: any)[spec.material]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = spec.size.Magnitude > 0.5
		if spec.harness then
			p:AddTag("BosunHarness")
			p:SetAttribute("BaseColor", hex)
		end
		p.CFrame = base * spec.cframe
		local parent = built[spec.parent]
		if spec.joint and spec.pivot then
			local world = base * CFrame.new(spec.pivot)
			local m = Instance.new("Motor6D")
			m.Name = spec.joint
			m.Part0 = parent
			m.Part1 = p
			m.C0 = parent.CFrame:ToObjectSpace(world)
			m.C1 = p.CFrame:ToObjectSpace(world)
			m.Parent = p
		else
			local w = Instance.new("Weld")
			w.Name = "BosunWeld"
			w.Part0 = parent
			w.Part1 = p
			w.C0 = parent.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
		p.Parent = model
		built[spec.name] = p
	end
	for on, name in BosunRig.ANCHORS do
		anchors[on] = { part = built[name], rest = base:ToObjectSpace(built[name].CFrame) }
	end
	return anchors
end

-- The LP upload (M_Chr_Bosun_LP): one textured MeshPart per BosunRig part, joined on the same Motor6Ds
-- (or Welds) the placeholder uses, so Shared.Dog.BosunMotion animates it unchanged. Returns nil when
-- the upload is missing a part: the greybox rig then takes over.
local function buildMesh(model: Model, body: BasePart, base: CFrame): Anchors?
	local clone = AssetLoader.clone(DogVisual.LP_ASSET, "LOD0")
	if not clone then
		return nil
	end
	local source: { [string]: BasePart } = {}
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			source[DogVisual.shortName(d.Name, DogVisual.LP_ASSET)] = d
		end
	end
	clone:PivotTo(base) -- the uploaded parts keep their own mesh-centre rest frames

	local built: { [string]: BasePart } = { Body = body }
	local anchors: Anchors = {}
	for _, spec in BosunRig.PARTS do
		local p = source[spec.name]
		if not p then
			for name, part in built do
				if name ~= "Body" then
					part:Destroy()
				end
			end
			clone:Destroy()
			return nil
		end
		p.Name = spec.name
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p:SetAttribute("Mesh", true)
		if spec.harness then
			p:AddTag("BosunHarness")
			p:SetAttribute("BaseColor", DogWear.HARNESS_ORANGE)
		end
		local parent = built[spec.parent]
		if spec.joint and spec.pivot then
			local world = base * CFrame.new(spec.pivot)
			local m = Instance.new("Motor6D")
			m.Name = spec.joint
			m.Part0 = parent
			m.Part1 = p
			m.C0 = parent.CFrame:ToObjectSpace(world)
			m.C1 = p.CFrame:ToObjectSpace(world)
			m.Parent = p
		else
			local w = Instance.new("Weld")
			w.Name = "BosunWeld"
			w.Part0 = parent
			w.Part1 = p
			w.C0 = parent.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
		p.Parent = model
		built[spec.name] = p
	end
	clone:Destroy() -- any part the rig has no use for

	for on, name in BosunRig.ANCHORS do
		local part = built[name]
		local spec = SPECS[name]
		if part and spec then
			anchors[on] = { part = part, rest = spec.cframe }
		end
	end
	return anchors
end

-- Builds the dog at `cf` (facing cf.LookVector): the uploaded LP mesh when `useMesh` and it loads,
-- else the greybox BosunRig in `coat` (hex). Body is the invisible physics root; the visual parts
-- hang on Motor6Ds (pivots in the authored frame) or Welds.
local function buildDog(
	player: Player,
	cf: CFrame,
	coat: string,
	useMesh: boolean
): (Model, BasePart, Anchors)
	local model = Instance.new("Model")
	model.Name = `Bosun_{player.UserId}`
	model:SetAttribute("Owner", player.UserId)

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 1.6, 3.4) -- the old greybox body: same mass for the aligners
	body.Transparency = 1
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.CFrame = cf
	body.Parent = model
	model.PrimaryPart = body

	local base = cf * CFrame.new(0, -LEG_HEIGHT, 0) -- the authored origin: the ground under him
	local anchors: Anchors? = if useMesh then buildMesh(model, body, base) else nil
	if anchors then
		model:SetAttribute("Art", "Mesh")
	else
		anchors = buildPlaceholder(model, body, base, coat)
		model:SetAttribute("Art", "Greybox")
	end

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "RootAttachment"
	rootAttachment.Parent = body
	local headTop = Instance.new("Attachment")
	headTop.Name = "BarkAttachment" -- the Woof! bubble (DogController)
	headTop.Position = Vector3.new(0, 1.35, -1.6)
	headTop.Parent = body

	model.Parent = folder
	return model, body, anchors :: Anchors
end

-- Cosmetics ---------------------------------------------------------------------------------------

local function equipped(player: Player, slot: string): string
	local v = player:GetAttribute(Cosmetics.attribute(slot))
	return if type(v) == "string" then v else (Cosmetics.default(slot) or "")
end

function dogOption(dog: Dog): { [string]: any }
	return (Cosmetics.option("Dog", dog.variant) or Cosmetics.option("Dog", "Bosun") or {}) :: any
end

local function lookOf(player: Player, slot: string): string?
	local option = Cosmetics.option(slot, equipped(player, slot)) :: any
	return option and option.look
end

local function wetColor(hex: string, wet: boolean): Color3
	local c = Color3.fromHex(hex)
	return if wet then Color3.new(c.R * WET_DARKEN, c.G * WET_DARKEN, c.B * WET_DARKEN) else c
end

-- Re-dresses the dog from the player's Cos_Dog* attributes.
function applyWear(dog: Dog)
	local old = dog.model:FindFirstChild("Wear")
	if old then
		old:Destroy()
	end
	local player = dog.player
	-- harness: tinted by the harness look, hidden under a life jacket
	local tint = DogWear.harnessTint(lookOf(player, "DogHarness"))
	local jacket = lookOf(player, "DogJacket")
	local hide = jacket ~= nil and jacket ~= "None"
	dog.model:SetAttribute("HarnessHidden", hide)
	dog.model:SetAttribute(
		"HarnessTint",
		if tint then Color3.new(tint[1], tint[2], tint[3]) else Color3.new(1, 1, 1)
	)
	for _, p in dog.model:GetDescendants() do
		if p:IsA("BasePart") and p:HasTag("BosunHarness") then
			if p:GetAttribute("Mesh") == true then
				-- the uploaded harness is textured: multiply the webbing (the tape parts stay silver)
				local mul = if tint and not string.find(p.Name, "Tape", 1, true)
					then Color3.new(tint[1], tint[2], tint[3])
					else Color3.new(1, 1, 1)
				p:SetAttribute("Tint", mul)
				local dim = if dog.wet then WET_DARKEN else 1
				p.Color = Color3.new(mul.R * dim, mul.G * dim, mul.B * dim)
			else
				local base = p:GetAttribute("BaseColor")
				if type(base) == "string" then
					-- the tape stays retroreflective silver
					local hex = if tint and not string.find(p.Name, "Tape", 1, true)
						then DogWear.tinted(base, tint)
						else base
					p:SetAttribute("DryColor", hex)
					p.Color = wetColor(hex, dog.wet)
				end
			end
			p.Transparency = if hide then 1 else 0
		end
	end
	local wear = Instance.new("Model")
	wear.Name = "Wear"
	for _, slot in WEAR_SLOTS do
		local kind = WEAR_KIND[slot]
		if not kind then
			continue
		end
		for _, spec in DogWear.parts(kind, lookOf(player, slot)) do
			local anchor = dog.anchors[spec.on]
			if not anchor then
				continue
			end
			local p: BasePart
			if spec.shape == "Wedge" then
				p = Instance.new("WedgePart")
			else
				local plain = Instance.new("Part")
				plain.Shape = if spec.shape == "Cylinder"
					then Enum.PartType.Cylinder
					else Enum.PartType.Block
				p = plain
			end
			p.Name = spec.name
			p.Size = spec.size
			p.Material = (Enum.Material :: any)[spec.material] or Enum.Material.Fabric
			p.Color = wetColor(spec.color, dog.wet)
			p:SetAttribute("DryColor", spec.color)
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			p.Anchored = false
			p.CastShadow = spec.size.Magnitude > 0.5
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.CFrame = anchor.part.CFrame * anchor.rest:Inverse() * spec.cframe
			local w = Instance.new("Weld")
			w.Name = "WearWeld"
			w.Part0 = anchor.part
			w.Part1 = p
			w.C0 = anchor.rest:Inverse() * spec.cframe
			w.Parent = p
			p.Parent = wear
		end
	end
	wear.Parent = dog.model
end

-- Wet: the coat, harness and wear darken (every part carries its DryColor).
local function wetWear(dog: Dog)
	local dim = if dog.wet then WET_DARKEN else 1
	for _, p in dog.model:GetDescendants() do
		if not p:IsA("BasePart") then
			continue
		end
		local hex = p:GetAttribute("DryColor")
		local tint = p:GetAttribute("Tint")
		if type(hex) == "string" then
			p.Color = wetColor(hex, dog.wet)
		elseif p:GetAttribute("Mesh") == true then
			-- the LP upload ships no _Wet maps: dim its textures when soaked
			if typeof(tint) == "Color3" then
				p.Color = Color3.new(tint.R * dim, tint.G * dim, tint.B * dim)
			else
				p.Color = Color3.new(dim, dim, dim)
			end
		end
	end
end

local function makeDog(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then root.CFrame * CFrame.new(3, -1, 2) else CFrame.new(0, 10, 0)
	local variant = equipped(player, "Dog")
	local option = (Cosmetics.option("Dog", variant) or {}) :: any
	local model, body, anchors = buildDog(
		player,
		CFrame.new(start.Position) * start.Rotation,
		if type(option.coat) == "string" then option.coat else BosunRig.COAT,
		type(option.coat) ~= "string" -- the uploaded Bosun mesh carries its own black coat
	)
	model:SetAttribute("Mode", "Follow")
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

	local dog: Dog = {
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
		mode = "Follow",
		depth = 0,
		wetness = 0,
		wet = false,
		lastSwim = false,
		variant = variant,
		anchors = anchors,
	}
	option = dogOption(dog)
	model:SetAttribute("DogId", dog.variant)
	model:SetAttribute("DogName", option.name or "Bosun")
	model:SetAttribute("Breed", option.breed or "Newfoundland")
	dogs[player] = dog
	applyWear(dog)
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
-- craft with no seat for him (canRide).
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
rayParams.IgnoreWater = true -- terrain water is not ground: over it he swims, never stands on it

-- His body centre's height at `position`, and the water depth there (math.huge: no ground found).
local function groundY(position: Vector3, character: Model): (number, number)
	rayParams.FilterDescendantsInstances = { folder, character }
	local hit =
		Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -60, 0), rayParams)
	local surface = seaHeight(position)
	local sea = surface + FLOAT_HEIGHT
	if hit then
		return math.max(hit.Position.Y + LEG_HEIGHT, sea), math.max(0, surface - hit.Position.Y)
	end
	return sea, math.huge
end

local function setMode(dog: Dog, mode: string)
	if dog.mode ~= mode then
		dog.mode = mode
		dog.model:SetAttribute("Mode", mode)
	end
end

-- A Newfoundland can't ride a jet ski: she carries only the driver seat (the sled is a survivor
-- slot, not a seat), so there is nowhere for him to sit even now the camera is third person. He
-- rides the RIB and the bigger boats; a first-person-only craft has no room either.
local function canRide(model: Model): boolean
	local id = model:GetAttribute("VehicleId")
	if VehicleConfig.isJetSki(id) then
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
		return Vector3.new(top.X, (groundY(top, character)), top.Z), look :: Vector3
	end
	return Vector3.new(pos.X, (groundY(pos, character)), pos.Z), face
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
		dog.depth = 0
		setMode(dog, "Wait")
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
		dog.depth = 0
		setMode(dog, "Ride")
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
	local y, depth = groundY(desired, character)
	desired = Vector3.new(desired.X, y, desired.Z)
	dog.depth = depth
	setMode(dog, if depth > SWIM_DEPTH then "Swim" else "Follow")

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

-- Rain on him now (0..1): the storm's intensity, unless something is over his head.
local function rainOn(dog: Dog): number
	local w = getWeather()
	if not w then
		return 0
	end
	local okState, state = pcall(w.getState)
	if not okState or state == "Calm" then
		return 0
	end
	local ok, intensity = pcall(w.getIntensity)
	if not ok or type(intensity) ~= "number" or intensity <= 0 then
		return 0
	end
	local ignore: { Instance } = { folder }
	if dog.player.Character then
		table.insert(ignore, dog.player.Character)
	end
	rayParams.FilterDescendantsInstances = ignore
	if Workspace:Raycast(dog.body.Position, Vector3.new(0, 60, 0), rayParams) then
		return 0 -- sheltered
	end
	return math.clamp(intensity, 0, 1)
end

local function updateWetness(dog: Dog, dt: number)
	local swam = dog.mode == "Swim"
	local wetness = BosunWetness.step(dog.wetness, dt, {
		submerged = dog.depth > WADE_DEPTH,
		rain = rainOn(dog),
	})
	if dog.lastSwim and not swam then
		wetness = BosunWetness.shake(wetness)
	end
	dog.lastSwim = swam
	dog.wetness = wetness
	local rounded = math.floor(wetness * 20 + 0.5) / 20
	if dog.model:GetAttribute("Wetness") ~= rounded then
		dog.model:SetAttribute("Wetness", rounded)
	end
	local wet = BosunWetness.isWet(dog.wet, wetness)
	if wet ~= dog.wet then
		dog.wet = wet
		dog.model:SetAttribute("Wet", wet)
		wetWear(dog)
	end
end

function DogService.GetDog(player: Player): Model?
	local dog = dogs[player]
	return if dog then dog.model else nil
end

-- A short happy moment: the client spins Bosun once, tail high, with a "Woof!" (no new remote:
-- the model attribute replicates the counter).
function DogService.Treat(player: Player)
	local dog = dogs[player]
	if not (dog and dog.model.Parent) then
		return
	end
	local count = tonumber(dog.model:GetAttribute("Treat")) or 0
	dog.model:SetAttribute("Treat", count + 1)
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
	for _, slot in WEAR_SLOTS do
		player:GetAttributeChangedSignal(Cosmetics.attribute(slot)):Connect(function()
			local dog = dogs[player]
			if dog and dog.model.Parent then
				applyWear(dog)
			end
		end)
	end
	-- a different companion: rebuild the dog where he stands (same follow / swim / ride / point)
	player:GetAttributeChangedSignal(Cosmetics.attribute("Dog")):Connect(function()
		local dog = dogs[player]
		local character = player.Character
		if not (dog and character) or dog.variant == equipped(player, "Dog") then
			return
		end
		local at = dog.body.CFrame
		removeDog(player)
		makeDog(player, character)
		local fresh = dogs[player]
		if fresh then
			fresh.body.CFrame = at
		end
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
	AssetLoader.preload({ DogVisual.LP_ASSET })
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
	task.spawn(function()
		while true do
			local dt = task.wait(WET_TICK)
			for _, dog in dogs do
				updateWetness(dog, dt)
			end
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
