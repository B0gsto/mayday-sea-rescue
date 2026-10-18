--!strict
-- DogService: Bosun, every player's Newfoundland (docs 01: MVP follower who barks and points).
--
-- Bosun is the uploaded rigid model M_Chr_Bosun (AssetLoader, by name; LOD0/1/2, nine MeshParts each:
-- BodyHead, BodyFore, BodyHind, Tail, Harness, FurHead, FurFront, FurRear, FurTail; the older six-part
-- upload without Tail / FurHead / FurTail still rigs). An invisible root part "Body" carries the
-- physics: he follows his player on land (AlignPosition / AlignOrientation, no collisions: docs 02
-- section 10.8), floats in his harness on water, and rides the RIB and bigger boats aft (welded to a
-- DogSlot / the aft deck, out of the helm camera) while they sit in them. He never rides a first-person
-- craft (the jet ski): he sits and waits ashore. Each LOD is rigged with Motor6Ds at BosunMotion.PIVOTS
-- (Root, Neck, Hips, Ruff, Tail; Harness, FurHead, FurRear, FurTail welded on) whose Transforms
-- DogController writes locally; LOD1 and LOD2 start hidden and the client picks the LOD by distance. Until the model loads (or if it
-- can't), a greybox placeholder stands in ("Placeholder" model) and the load is retried.
--
-- Attributes on the dog model for the client: Mode ("Follow" | "Wait" | "Ride" | "Swim"), Wetness
-- (0..1, BosunWetness) and Wet (the wet SurfaceAppearances are on, AssetLoader.setWet); Waiting (bool).
--
-- Every few seconds he sniffs for the nearest victim from CallService.GetVictimPositions and, inside his
-- nose range, faces it and fires DogPoint to his player:
--   DogPoint:FireClient(player, { dog = Model, direction = Vector3 (unit, flat),
--                                 position = Vector3, distance = number })
-- The client (DogController) turns his head, shows a "Woof!" bubble and a small arrow.
--
-- Cosmetics (RP-M5): the player's Cos_Dog attribute picks the companion (Config/Cosmetics/Dog: Bosun, or
-- a Water Dog Friends stand-in on Bosun's rig; same abilities) and Cos_DogHarness / Cos_DogBandana /
-- Cos_DogJacket / Cos_DogHat what he wears (Config/Cosmetics/DogWear, geometry in Shared.Dog.DogWear): a
-- tint on the harness SurfaceAppearances (dry and wet), and plain Parts in a "Wear" model welded to the
-- LOD0 BodyFore / BodyHead (darkened while he is wet). A life jacket sets the model attribute HideHarness
-- (DogController hides the harness locally). Model attributes DogId, DogName, Breed.
--
-- API (server): DogService.GetDog(player): Model?
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local BosunMotion = require(Shared:WaitForChild("Dog"):WaitForChild("BosunMotion"))
local BosunWetness = require(Shared:WaitForChild("Dog"):WaitForChild("BosunWetness"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local DogWear = require(Shared:WaitForChild("Dog"):WaitForChild("DogWear"))
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
local ASSET = "M_Chr_Bosun"
local LODS = { "LOD0", "LOD1", "LOD2" }
local LOAD_RETRY = AssetLoader.RETRY_AFTER + 1
local WET_TICK = 0.5 -- seconds between wetness updates
local SWIM_DEPTH = LEG_HEIGHT - 0.4 -- water this deep under him: he swims
local WADE_DEPTH = 0.4 -- water this deep: his coat gets wet

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
	real: boolean, -- the uploaded model is on (else the greybox placeholder)
	mode: string,
	depth: number, -- water depth under him (studs, 0 on dry land / aboard)
	wetness: number,
	wet: boolean,
	lastSwim: boolean,
	variant: string, -- Cos_Dog option id this model was built for
	anchors: { [string]: { part: BasePart, rest: CFrame } }, -- LOD0 Fore / Head, rest pose in the authored frame
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

-- Builds Bosun at `cf` (facing cf.LookVector) as the greybox placeholder. Body is the physics root
-- (it stays, invisible, when the real model replaces the "Placeholder" model); Head hangs on a Motor6D
-- "Neck" whose Transform the client turns.
local function buildDog(player: Player, cf: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = `Bosun_{player.UserId}`
	model:SetAttribute("Owner", player.UserId)

	local body = part(model, "Body", Vector3.new(2, 1.6, 3.4), COLORS.fur, Enum.Material.Fabric)
	body.CFrame = cf
	model.PrimaryPart = body
	local placeholder = Instance.new("Model")
	placeholder.Name = "Placeholder"
	placeholder.Parent = model

	attach(
		body,
		part(placeholder, "Vest", Vector3.new(2.2, 1.25, 1.9), COLORS.vest),
		CFrame.new(0, 0.22, -0.15)
	)
	attach(
		body,
		part(placeholder, "VestBand", Vector3.new(2.25, 0.22, 0.35), COLORS.chest),
		CFrame.new(0, 0.3, -0.55)
	)
	attach(
		body,
		part(placeholder, "VestHandle", Vector3.new(0.3, 0.3, 0.9), COLORS.vest),
		CFrame.new(0, 0.95, -0.15)
	)
	attach(
		body,
		part(placeholder, "ChestPatch", Vector3.new(1.0, 0.85, 0.2), COLORS.chest),
		CFrame.new(0, -0.15, -1.72)
	)
	attach(
		body,
		part(placeholder, "Rump", Vector3.new(2.05, 1.5, 0.8), COLORS.fur, Enum.Material.Fabric),
		CFrame.new(0, 0.05, 1.45)
	)
	for _, x in { -0.62, 0.62 } do
		for _, z in { -1.15, 1.15 } do
			local leg = part(
				placeholder,
				"Leg",
				Vector3.new(0.6, 1.15, 0.6),
				COLORS.fur,
				Enum.Material.Fabric
			)
			attach(body, leg, CFrame.new(x, -1.3, z))
			attach(
				body,
				part(placeholder, "Paw", Vector3.new(0.7, 0.3, 0.75), COLORS.fur),
				CFrame.new(x, -1.72, z - 0.08)
			)
		end
	end
	attach(
		body,
		part(placeholder, "Tail", Vector3.new(0.45, 0.45, 1.3), COLORS.fur, Enum.Material.Fabric),
		CFrame.new(0, 0.55, 2.2) * CFrame.Angles(math.rad(35), 0, 0)
	)

	local head =
		part(placeholder, "Head", Vector3.new(1.55, 1.35, 1.4), COLORS.fur, Enum.Material.Fabric)
	head.CFrame = body.CFrame * CFrame.new(0, 0.95, -2.05)
	local neck = Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = body
	neck.Part1 = head
	neck.C0 = CFrame.new(0, 0.95, -1.5)
	neck.C1 = CFrame.new(0, 0, 0.55)
	neck.Parent = head
	attach(
		head,
		part(placeholder, "Snout", Vector3.new(0.95, 0.65, 0.65), COLORS.fur),
		CFrame.new(0, -0.28, -0.95)
	)
	attach(
		head,
		part(placeholder, "Nose", Vector3.new(0.4, 0.28, 0.2), COLORS.nose),
		CFrame.new(0, -0.05, -1.32)
	)
	attach(
		head,
		part(placeholder, "Tongue", Vector3.new(0.3, 0.1, 0.35), COLORS.tongue),
		CFrame.new(0, -0.64, -1.05)
	)
	for _, x in { -0.82, 0.82 } do
		attach(
			head,
			part(placeholder, "Ear", Vector3.new(0.3, 0.8, 0.55), COLORS.fur, Enum.Material.Fabric),
			CFrame.new(x, -0.05, 0.05)
		)
		attach(
			head,
			part(placeholder, "Eye", Vector3.new(0.2, 0.2, 0.08), COLORS.eye),
			CFrame.new(x * 0.42, 0.22, -0.71)
		)
	end

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "RootAttachment"
	rootAttachment.Parent = body
	local headTop = Instance.new("Attachment")
	headTop.Name = "BarkAttachment" -- the Woof! bubble (DogController)
	headTop.Position = Vector3.new(0, 2.35, -2.05)
	headTop.Parent = body

	model.Parent = folder
	return model, body
end

-- The real model -----------------------------------------------------------------------------------

-- Round 5 has 9 parts per LOD; the 6-part model (no Tail, FurHead, FurTail) still rigs.
local PART_KEYS = {
	"BodyHead",
	"BodyFore",
	"BodyHind",
	"Tail",
	"Harness",
	"FurHead",
	"FurFront",
	"FurRear",
	"FurTail",
}
local FUR_KEYS = { FurFront = true, FurRear = true, FurHead = true, FurTail = true }
local ATTACH_ON = {
	ATT_Mouth = "BodyHead",
	ATT_HarnessHandle = "Harness",
	ATT_TowRing = "Harness",
	ATT_TailRoot = "Tail",
}

local function keyOf(name: string): string?
	for _, key in PART_KEYS do
		if
			string.find(name, "_" .. key .. "_", 1, true)
			or string.sub(name, -#key - 1) == "_" .. key
		then
			return key
		end
	end
	return nil
end

-- Fur cards are alpha cutouts seen from both sides. AlphaMode comes from Appearances.model.json
-- (tools/gen_asset_ids.py); DoubleSided can't be set from game scripts, so it is baked into the uploaded
-- Model (art/source/characters/M_Chr_Bosun/set_double_sided.luau). These writes are best effort.
local function prepareFur(p: BasePart)
	for _, sa in p:GetDescendants() do
		if sa:IsA("SurfaceAppearance") then
			pcall(function()
				(sa :: any).AlphaMode = Enum.AlphaMode.Transparency
			end)
		end
	end
	if p:IsA("MeshPart") then
		pcall(function()
			(p :: any).DoubleSided = true
		end)
	end
end

-- Welds one LOD copy onto `body` with the BosunMotion joints. `visible` false hides it (the client
-- shows the LOD it wants locally). Returns false if a body part is missing.
local function rigLod(body: BasePart, copy: Model, lod: number, fur: boolean): boolean
	local base = body.CFrame * CFrame.new(0, -LEG_HEIGHT, 0) -- the authored origin: the ground under him
	copy:PivotTo(base)
	local parts: { [string]: BasePart } = {}
	local extra: { BasePart } = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			local key = keyOf(d.Name)
			if key and FUR_KEYS[key] and not fur then
				d:Destroy() -- a short-coated stand-in (Config/Cosmetics/Dog `fur = false`)
			elseif key and not parts[key] then
				parts[key] = d
			else
				table.insert(extra, d)
			end
		end
	end
	local fore, head, hind = parts.BodyFore, parts.BodyHead, parts.BodyHind
	if not (fore and head and hind) then
		warn(
			`[DogService] {copy.Name}: BodyFore / BodyHead / BodyHind missing; keeping the placeholder`
		)
		return false
	end
	local function motor(name: string, part0: BasePart, part1: BasePart, pivot: Vector3 | CFrame)
		local world = if typeof(pivot) == "CFrame" then pivot else base * CFrame.new(pivot)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = part0
		m.Part1 = part1
		m.C0 = part0.CFrame:ToObjectSpace(world)
		m.C1 = part1.CFrame:ToObjectSpace(world)
		m.Parent = part1
	end
	local function weld(part0: BasePart, part1: BasePart)
		local w = Instance.new("Weld")
		w.Name = "BosunWeld"
		w.Part0 = part0
		w.Part1 = part1
		w.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
		w.Parent = part1
	end
	local pivots = BosunMotion.PIVOTS
	motor("Root", body, fore, pivots.Root)
	motor("Neck", fore, head, pivots.Neck)
	motor("Hips", fore, hind, pivots.Hips)
	if parts.FurFront then
		motor("Ruff", fore, parts.FurFront, pivots.Ruff)
	end
	if parts.Harness then
		weld(fore, parts.Harness)
	end
	if parts.FurRear then
		weld(hind, parts.FurRear)
	end
	if parts.FurHead then
		weld(head, parts.FurHead) -- turns with the head, not at RUFF_FOLLOW
	end
	-- the tail joint at ATT_TailRoot (on the PrimaryPart until moved below; every part's origin is the
	-- authored origin, so the joint frame is the marker's position in the body's orientation)
	local tail = parts.Tail
	if tail then
		local marker = copy:FindFirstChild("ATT_TailRoot", true)
		local pivot: CFrame = if marker and marker:IsA("Attachment")
			then CFrame.new(marker.WorldPosition) * base.Rotation
			else base * CFrame.new(pivots.Tail)
		motor("Tail", hind, tail, pivot)
	end
	if parts.FurTail then
		weld(tail or hind, parts.FurTail) -- the cards move with the skin about the tail root
	end
	for _, p in extra do
		weld(fore, p)
	end
	-- the markers ride on the part they belong to (AssetLoader puts them all on the PrimaryPart)
	for _, d in copy:GetDescendants() do
		local on = d:IsA("Attachment") and ATTACH_ON[d.Name]
		local target = on and parts[on]
		if target and d.Parent ~= target then
			local a = d :: Attachment
			local world = a.WorldCFrame
			a.Parent = target
			a.WorldCFrame = world
		end
	end
	for key, p in parts do
		if FUR_KEYS[key] then
			prepareFur(p)
		end
		p.Transparency = if lod == 0 then 0 else 1
	end
	for _, p in extra do
		p.Transparency = if lod == 0 then 0 else 1
	end
	copy.Name = LODS[lod + 1]
	copy:SetAttribute("BosunLod", lod)
	return true
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

-- Re-dresses the dog from the player's Cos_Dog* attributes (needs the uploaded model; the greybox
-- placeholder wears nothing).
function applyWear(dog: Dog)
	local old = dog.model:FindFirstChild("Wear")
	if old then
		old:Destroy()
	end
	if not dog.real then
		return
	end
	local player = dog.player
	-- harness colour: a multiply tint on every harness SurfaceAppearance (dry, wet, every LOD)
	local tint = DogWear.harnessTint(lookOf(player, "DogHarness"))
	local color = if tint then Color3.new(tint[1], tint[2], tint[3]) else Color3.new(1, 1, 1)
	for _, d in dog.model:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			local owner = d:FindFirstAncestorWhichIsA("BasePart")
			if owner and keyOf(owner.Name) == "Harness" then
				pcall(function()
					(d :: any).Color = color
				end)
			end
		end
	end
	local jacket = lookOf(player, "DogJacket")
	dog.model:SetAttribute("HideHarness", if jacket and jacket ~= "None" then true else nil)
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

local function wetWear(dog: Dog)
	local wear = dog.model:FindFirstChild("Wear")
	if not wear then
		return
	end
	for _, p in wear:GetChildren() do
		local hex = p:GetAttribute("DryColor")
		if p:IsA("BasePart") and type(hex) == "string" then
			p.Color = wetColor(hex, dog.wet)
		end
	end
end

-- Swaps the placeholder for the uploaded model (yields while it loads). False if LOD0 can't load.
local function attachReal(dog: Dog): boolean
	local body = dog.body
	local copies: { [number]: Model } = {}
	for i, lod in LODS do
		local copy = AssetLoader.clone(ASSET, lod)
		if copy then
			if rigLod(body, copy, i - 1, dogOption(dog).fur ~= false) then
				copies[i - 1] = copy
			else
				copy:Destroy()
			end
		end
	end
	if not copies[0] or not dog.model.Parent then
		for _, copy in copies do
			copy:Destroy()
		end
		return false
	end
	for _, copy in copies do
		AssetLoader.setWet(copy, dog.wet)
		copy.Parent = dog.model
	end
	local placeholder = dog.model:FindFirstChild("Placeholder")
	if placeholder then
		placeholder:Destroy()
	end
	body.Transparency = 1
	body.CastShadow = false
	local bark = body:FindFirstChild("BarkAttachment") :: Attachment?
	if bark then
		bark.Position = Vector3.new(0, 1.25, -2.0)
	end
	dog.real = true
	dog.model:SetAttribute("Placeholder", nil)
	local base = body.CFrame * CFrame.new(0, -LEG_HEIGHT, 0)
	for _, d in copies[0]:GetDescendants() do
		local key = d:IsA("BasePart") and keyOf(d.Name)
		local on = if key == "BodyFore" then "Fore" elseif key == "BodyHead" then "Head" else nil
		if on then
			dog.anchors[on] =
				{ part = d :: BasePart, rest = base:ToObjectSpace((d :: BasePart).CFrame) }
		end
	end
	applyWear(dog)
	return true
end

-- Keeps trying to load the model while the dog exists; the placeholder stands in meanwhile.
local function upgrade(dog: Dog)
	while dog.model.Parent and not dog.real do
		local ok, result = pcall(attachReal, dog)
		if ok and result then
			return
		elseif not ok then
			warn(`[DogService] attaching {ASSET} failed: {result}`)
		end
		task.wait(LOAD_RETRY)
	end
end

local function makeDog(player: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if root then root.CFrame * CFrame.new(3, -1, 2) else CFrame.new(0, 10, 0)
	local model, body = buildDog(player, CFrame.new(start.Position) * start.Rotation)
	model:SetAttribute("Placeholder", true)
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
		real = false,
		mode = "Follow",
		depth = 0,
		wetness = 0,
		wet = false,
		lastSwim = false,
		variant = equipped(player, "Dog"),
		anchors = {},
	}
	local option = dogOption(dog)
	model:SetAttribute("DogId", dog.variant)
	model:SetAttribute("DogName", option.name or "Bosun")
	model:SetAttribute("Breed", option.breed or "Newfoundland")
	dogs[player] = dog
	task.spawn(upgrade, dog)
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
		AssetLoader.setWet(dog.model, wet)
		wetWear(dog)
	end
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
	for _, lod in LODS do
		task.spawn(AssetLoader.getTemplate, ASSET, lod)
	end
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
