--!strict
-- DogService: Bosun, every player's Newfoundland (docs 01: MVP follower who barks and points).
--
-- Bosun is the uploaded LP mesh M_Chr_Bosun_LP: one textured MeshPart per Shared.Dog.BosunRig part
-- (G82), assembled on the rig's Motor6Ds; the greybox BosunRig Parts are the fallback when the upload
-- fails (and still stand in for the unfinished Water Dog Friends coat options). An invisible root part
-- "Body" carries the physics: he follows his player on land (AlignPosition / AlignOrientation, no
-- collisions: docs 02 section 10.8) and floats in his harness on water. While his player sits in any
-- vehicle (car, boat, jet ski) he is hidden (model attribute Hidden, DogController) and reappears
-- beside them when they get out. The
-- parts hang on Motor6Ds named after the BosunMotion pose keys (Root, Neck, Jaw, Tail1, Tail2, eight leg
-- joints) whose Transforms DogController writes locally. Everyone sees this low-poly dog (docs/14 section 4:
-- no fur-card hero close-up).
--
-- Attributes on the dog model for the client: Mode ("Follow" | "Wait" | "Swim"), Wetness
-- (0..1, BosunWetness) and Wet (coat and wear darkened); Hidden (bool), Treat (a counter, bumped by
-- DogService.Treat for the daily challenge set: DogController spins him once and pops a "Woof!").
--
-- Every few seconds he sniffs for the nearest victim from OperationService.GetVictimPositions and, inside his
-- nose range, faces it and fires DogPoint to his player:
--   DogPoint:FireClient(player, { dog = Model, direction = Vector3 (unit, flat),
--                                 position = Vector3, distance = number })
-- The client (DogController) turns his head, shows a "Woof!" bubble and a small arrow.
-- K14 (docs/16): he is the guide. On a craft (hidden) with his player idle for BosunGuide.IDLE s, the
-- same DogPoint goes out for the nearest survivor (their call's victims or a free-roam swimmer), with
-- `from` = the craft: the bark, bubble and arrow come from it.
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
local BosunGuide = require(Shared:WaitForChild("Dog"):WaitForChild("BosunGuide"))
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
local GUIDE_TICK = 1 -- seconds between guide checks (BosunGuide)
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
	hidden: boolean, -- the player is in a vehicle: Bosun is hidden (model attribute Hidden)
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
local guides: { [Player]: BosunGuide.State } = {}
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

local operationService: any = nil
local function victimPositions(player: Player): { Vector3 }
	if operationService == nil then
		local module = script.Parent:FindFirstChild("OperationService")
		local ok, result = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
		end
		operationService = if ok and type(result) == "table" then result else false
		if not operationService then
			task.delay(10, function()
				operationService = nil -- retry later; OperationService may not exist yet
			end)
		end
	end
	if not operationService or type(operationService.GetVictimPositions) ~= "function" then
		return {}
	end
	local ok, positions = pcall(operationService.GetVictimPositions, player)
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
		hidden = false,
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

local function step(dog: Dog, now: number)
	local character = dog.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root then
		return
	end
	-- In any vehicle he is hidden (DogController) and stays where he was; he reappears beside the
	-- player when they get out (user, 2026-10-22: a dog standing on the car looked broken).
	if vehicleOf(humanoid.SeatPart) then
		if not dog.hidden then
			dog.hidden = true
			dog.model:SetAttribute("Hidden", true)
		end
		dog.depth = 0
		setMode(dog, "Wait")
		return
	end
	local justOut = dog.hidden
	if justOut then
		dog.hidden = false
		dog.model:SetAttribute("Hidden", nil)
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
	if justOut or (desired - pos).Magnitude > TELEPORT_DISTANCE then
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
	if dog.hidden then
		return
	end
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

local ambient: any = nil
local function swimmerPositions(): { Vector3 }
	if ambient == nil then
		local module = script.Parent:FindFirstChild("AmbientRescueService")
		local ok, result = false, nil
		if module and module:IsA("ModuleScript") then
			ok, result = pcall(require, module)
		end
		ambient = if ok and type(result) == "table" then result else false
	end
	if not ambient or type(ambient.SwimmerPositions) ~= "function" then
		return {}
	end
	local ok, list = pcall(ambient.SwimmerPositions)
	return if ok and type(list) == "table" then list else {}
end

-- K14: on a boat, idle long enough, he points the way to the nearest survivor.
local function guide(dog: Dog, dt: number)
	local character = dog.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local craft = humanoid and vehicleOf(humanoid.SeatPart)
	local id = craft and craft:GetAttribute("VehicleId")
	local root = craft and craft.PrimaryPart
	local vel = if root then root.AssemblyLinearVelocity else Vector3.zero
	local state = guides[dog.player] or BosunGuide.new()
	guides[dog.player] = state
	local onCraft = root ~= nil and type(id) == "string" and VehicleConfig.get(id) ~= nil
	if not BosunGuide.step(state, dt, onCraft, Vector3.new(vel.X, 0, vel.Z).Magnitude) then
		return
	end
	local at = (root :: BasePart).Position
	local targets = table.clone(victimPositions(dog.player))
	for _, p in swimmerPositions() do
		table.insert(targets, p)
	end
	local best = BosunGuide.nearest(at, targets)
	local flat = if best then Vector3.new(best.X - at.X, 0, best.Z - at.Z) else Vector3.zero
	if flat.Magnitude < 1 then
		return
	end
	Net.event("DogPoint"):FireClient(dog.player, {
		dog = dog.model,
		direction = flat.Unit,
		position = best,
		distance = flat.Magnitude,
		from = craft,
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
	if not (dog and dog.model.Parent) or dog.hidden then
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
	guides[player] = nil
end

local function onCharacter(player: Player, character: Model)
	local dog = dogs[player]
	if dog and dog.model.Parent then
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
			local dt = task.wait(GUIDE_TICK)
			for _, dog in dogs do
				guide(dog, dt)
			end
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
