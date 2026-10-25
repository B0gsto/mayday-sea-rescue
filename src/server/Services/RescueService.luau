--!strict
-- RescueService: the physical side of calls. Builds victims (the rigged swimmer casualty from
-- Assets/CasualtyAsset, falling back to greybox people in Survivor Yellow life vests), drifting dinghies
-- and the capsized ferry; bobs them on Weather.heightAt every Heartbeat (anchored, no physics); runs the
-- hold-to-pull prompt; and detects deliveries at the DropOff pads. Operation bookkeeping, steps and pay
-- live in OperationService (the scene table passed in here is OperationService's `op.scene`).
--
-- Ops v2: a scene with `opsDriven = true` keeps its prompts disabled; the recovery step calls
-- RescueService.BoardVictim when the survivor climbs aboard.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))
local CasualtyRig = require(Shared:WaitForChild("Casualty"):WaitForChild("CasualtyRig"))
local ColdOpen = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpen"))
local PiwRescue = require(script.Parent.Parent.Ops.PiwRescue)
local RipCurrent = require(Shared:WaitForChild("RipCurrent"))
local CasualtyAsset: any = (function()
	local ok, m = pcall(require, script.Parent.Parent.Assets.CasualtyAsset)
	if not ok then
		warn(`[RescueService] CasualtyAsset unavailable ({m}): greybox victims`)
	end
	return if ok then m else nil
end)()
local NpcFactory: any = (function()
	local ok, m = pcall(require, script.Parent.Parent.Npc.NpcFactory)
	if not ok then
		warn(`[RescueService] NpcFactory unavailable ({m}): greybox people stay`)
	end
	return if ok then m else nil
end)()
local AssetLoader: any = (function()
	local ok, m = pcall(require, script.Parent.Parent.Assets.AssetLoader)
	if not ok then
		warn(`[RescueService] AssetLoader unavailable ({m}): greybox ferry`)
	end
	return if ok then m else nil
end)()
local AssetIds = require(Shared:WaitForChild("Config"):WaitForChild("AssetIds"))
local DataService = require(script.Parent.DataService)
local FerryRig = require(Shared:WaitForChild("Ferry"):WaitForChild("FerryRig"))
local HullKnock = require(Shared:WaitForChild("Ferry"):WaitForChild("HullKnock"))
local Wake = require(Shared:WaitForChild("Boat"):WaitForChild("Wake"))
local Waves = require(Shared:WaitForChild("Waves"))

local RescueService = {}
RescueService.Priority = 60

local SURVIVOR_YELLOW = Color3.fromHex("#FFD23F")
local SKIN =
	{ Color3.fromRGB(255, 214, 170), Color3.fromRGB(198, 140, 100), Color3.fromRGB(120, 80, 55) }
local SHIRTS =
	{ Color3.fromRGB(70, 120, 190), Color3.fromRGB(200, 80, 90), Color3.fromRGB(90, 160, 110) }
local DELIVER_MARGIN = 12
-- Survivors of a vessel scene (sinking, fire) or the cliff foot: this far out from the scene's centre.
local SCATTER_RADIUS = 32 -- clear of the 52-stud trawler

type Floater = {
	parts: { BasePart },
	offsets: { CFrame },
	arms: { [number]: { shoulder: CFrame, side: number, len: number } },
	x: number,
	z: number,
	yaw: number,
	depth: number,
	tilt: CFrame, -- static lean (the ferry lies on its side)
	sway: number, -- roll amplitude, radians
	phase: number,
	parent: Floater?,
	parentOffset: CFrame?,
	cf: CFrame,
	active: boolean,
	model: Model?, -- owning model, resolved lazily from parts[1]
	fixedY: number?, -- a diver on the seabed (call.dive): held at this height, not on the waves
}

local floaters: { Floater } = {}
local victimsByModel: { [Model]: any } = {}
local liveCalls: { [any]: boolean } = {}
local mapFolder: Folder
local CASUALTY_GROUP = "Casualty" -- never collides with Default (boats, quays)

-- Lazy access to other streams' services (they may not exist yet).
local serviceCache: { [string]: any } = {}
local function service(name: string): any?
	local cached = serviceCache[name]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local mod = script.Parent:FindFirstChild(name)
	if not (mod and mod:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(require, mod)
	serviceCache[name] = if ok then result else false
	return if ok then result else nil
end

local function try(serviceName: string, fnName: string, ...: any): (boolean, any)
	local svc = service(serviceName)
	local fn = svc and svc[fnName]
	if type(fn) ~= "function" then
		return false, "missing"
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(`[RescueService] {serviceName}.{fnName} failed: {result}`)
	end
	return ok, result
end

local function operations(): any
	return require(script.Parent:WaitForChild("OperationService") :: ModuleScript) :: any
end

-- Water height: Weather (stream D) if present, else calm waves.
local weather: any = nil
local fallbackParams = Waves.paramsFor(0, 0, 0)
local function heightAt(pos: Vector3, now: number): number
	if weather == nil then
		weather = false
		local mod = Shared:FindFirstChild("Weather")
		if mod and mod:IsA("ModuleScript") then
			local ok, result = pcall(require, mod)
			if ok then
				weather = result
			end
		end
	end
	if weather and weather.heightAt then
		local ok, h = pcall(weather.heightAt, pos, now)
		if ok and type(h) == "number" then
			return h
		end
	end
	return Waves.heightAt(pos.X, pos.Z, now, fallbackParams)
end

---------------------------------------------------------------- building

local function newPart(
	model: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function newFloater(x: number, z: number, depth: number): Floater
	return {
		parts = {},
		offsets = {},
		arms = {},
		x = x,
		z = z,
		yaw = math.random() * math.pi * 2,
		depth = depth,
		tilt = CFrame.identity,
		sway = 0.06,
		phase = math.random() * 10,
		cf = CFrame.new(x, depth, z),
		active = true,
	}
end

local function addPart(f: Floater, part: BasePart, offset: CFrame)
	table.insert(f.parts, part)
	table.insert(f.offsets, offset)
end

-- R15-ish greybox person. `base` is the torso centre relative to the floater root; waving arms.
-- Returns the parts it added (upgradePerson swaps them for a Roblox R15 character).
local function addPerson(f: Floater, model: Instance, base: CFrame, vest: boolean): { BasePart }
	local first = #f.parts + 1
	local skin = SKIN[math.random(#SKIN)]
	local shirt = SHIRTS[math.random(#SHIRTS)]
	addPart(f, newPart(model, "Torso", Vector3.new(2, 2, 1), shirt), base)
	addPart(
		f,
		newPart(model, "Head", Vector3.new(1.3, 1.3, 1.3), skin, Enum.PartType.Ball),
		base * CFrame.new(0, 1.7, 0)
	)
	for side = -1, 1, 2 do
		addPart(
			f,
			newPart(
				model,
				if side < 0 then "LeftLeg" else "RightLeg",
				Vector3.new(0.8, 1.8, 0.8),
				Color3.fromRGB(40, 50, 70)
			),
			base * CFrame.new(side * 0.5, -1.9, 0)
		)
		local arm = newPart(
			model,
			if side < 0 then "LeftArm" else "RightArm",
			Vector3.new(0.6, 1.8, 0.6),
			skin
		)
		addPart(f, arm, base * CFrame.new(side * 1.3, 0, 0))
		f.arms[#f.parts] =
			{ shoulder = base * CFrame.new(side * 1.3, 0.8, 0), side = side, len = 1.8 }
	end
	if vest then
		local v = newPart(model, "LifeVest", Vector3.new(2.3, 1.6, 1.4), SURVIVOR_YELLOW)
		addPart(f, v, base * CFrame.new(0, 0.2, 0))
		addPart(
			f,
			newPart(model, "VestCollar", Vector3.new(2.5, 0.45, 1.55), SURVIVOR_YELLOW),
			base * CFrame.new(0, 1, 0)
		)
	end
	return table.move(f.parts, first, #f.parts, 1, {})
end

-- Swaps a greybox person (addPerson's parts) for a Roblox R15 character dressed for `role`
-- (NpcFactory / Config/NpcOutfits, docs/12 section 2.9) once its catalog assets have loaded. The
-- greybox stays when the build fails or the floater was carried off meanwhile. The greybox "Torso"
-- stays as an invisible marker.
local GREYBOX_FEET = 2.8 -- studs from addPerson's torso centre down to its feet
local function upgradePerson(
	f: Floater,
	model: Instance,
	base: CFrame,
	parts: { BasePart },
	role: string,
	pose: string,
	onRig: ((Model) -> ())?
)
	if not NpcFactory then
		return
	end
	-- in the water: no stock animation (Roblox's swim idle lies the body flat, a plank with a head);
	-- CasualtyController poses it like the CasualtyAsset swimmer instead
	local swimmer = pose == "Tread"
	task.spawn(function()
		local rig: Model?, rootHeight: number =
			NpcFactory.build(role, { pose = if swimmer then nil else pose })
		local root = rig and rig.PrimaryPart
		if not (rig and root) then
			return
		end
		if not (f.active and model.Parent and table.find(floaters, f)) then
			rig:Destroy() -- carried, delivered or despawned while loading: keep what is there
			return
		end
		local parts2, offsets2, arms2 = {}, {}, {}
		for i, part in f.parts do
			if table.find(parts, part) then
				if part.Name == "Torso" then
					part.Transparency = 1
					part.CanQuery = false
				else
					part:Destroy()
					continue
				end
			end
			table.insert(parts2, part)
			table.insert(offsets2, f.offsets[i])
			if f.arms[i] and not table.find(parts, part) then
				arms2[#parts2] = f.arms[i]
			end
		end
		-- sitting: the hips (root) sit just under the torso; standing: the feet where the greybox's were
		local lift = if pose == "Sit" then -0.9 else rootHeight - GREYBOX_FEET
		local offset = base * CFrame.new(0, lift, 0)
		root.CFrame = f.cf * offset
		table.insert(parts2, root)
		table.insert(offsets2, offset)
		f.parts, f.offsets, f.arms = parts2, offsets2, arms2
		if swimmer then
			CasualtyRig.motorize(rig)
			rig:SetAttribute("CasualtyPose", "TreadWater")
			CollectionService:AddTag(rig, "CasualtyRig")
		end
		rig.Parent = model
		if model:IsA("Model") then
			model:SetAttribute("R15", true)
		end
		if onRig then
			onRig(rig)
		end
	end)
end

-- The rigged swimmer (CasualtyAsset): the skinned mesh rides the floater with the sea surface at its
-- Waterline (f.cf sits on the surface, so the bob and roll pivot there). `pose` is the client pose.
-- `seat`: torso centre on a parent floater (dinghy passengers), seated. Returns false when not loaded.
RescueService.RIG_TORSO = 3.2 -- studs above the feet: the invisible root (prompt, welds) sits here
local SIT_TORSO = 1.15 -- studs above the pivot of the Sit pose (hips lowered to the seat)
local function addRiggedPerson(f: Floater, model: Model, seat: CFrame?): Model?
	local rig = CasualtyAsset and CasualtyAsset.clone()
	local mesh = rig and rig.PrimaryPart
	if not (rig and mesh) then
		return nil
	end
	local water = rig:GetAttribute("Waterline")
	local w = if type(water) == "number" then water else 4.55
	local feet = if seat then seat * CFrame.new(0, -SIT_TORSO, 0) else CFrame.new(0, -w, 0)
	addPart(f, mesh, feet * mesh.PivotOffset:Inverse())
	rig:SetAttribute("CasualtyPose", if seat then "Sit" else "TreadWater")
	rig:SetAttribute("Strobe", true)
	CollectionService:AddTag(rig, CasualtyAsset.TAG)
	rig.Parent = model
	return rig
end

local function register(f: Floater)
	table.insert(floaters, f)
end

local function unregister(f: Floater)
	f.active = false
	local i = table.find(floaters, f)
	if i then
		table.remove(floaters, i)
	end
end

local function makePrompt(
	parent: BasePart,
	action: string,
	object: string,
	interaction: CallTypes.Interaction
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = interaction.holdSeconds
	prompt.MaxActivationDistance = interaction.range
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local onPull: (victim: any, player: Player, forced: boolean?) -> ()

-- One victim in the water (or seated on a parent floater such as a dinghy).
local function spawnVictim(call: any, pos: Vector3, parent: Floater?, parentOffset: CFrame?): any
	local model = Instance.new("Model")
	model.Name = "Victim"
	model:SetAttribute("CallId", call.id)
	model:SetAttribute("Survivor", true)
	local f = newFloater(pos.X, pos.Z, -0.3)
	f.parent = parent
	f.parentOffset = parentOffset
	local root = newPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), SURVIVOR_YELLOW)
	root.Transparency = 1
	addPart(f, root, CFrame.identity)
	model.PrimaryPart = root
	local creature = call.wildlifeSpecies ~= nil -- the sanctuary's animal replaces the person (SanctuaryService)
	local rig: Model? = nil
	if not creature then
		if parent then
			rig = addRiggedPerson(f, model, CFrame.identity)
		else
			-- f.cf on the sea surface; the root (prompt, welds, the PIW mechanics' target) at chest height
			f.depth = 0
			f.sway = 0.09
			f.offsets[1] = CFrame.new(0, RescueService.RIG_TORSO - 4.55, 0)
			rig = addRiggedPerson(f, model)
			if not rig then
				f.depth = -0.3
				f.sway = 0.06
				f.offsets[1] = CFrame.identity
			end
		end
		if not rig then
			local greybox = addPerson(f, model, CFrame.identity, true)
			local role = if call.kind == "CapsizedFerry"
				then "Passenger"
				elseif parent then "Boater"
				else "Swimmer"
			upgradePerson(
				f,
				model,
				CFrame.identity,
				greybox,
				role,
				if parent then "Sit" else "Tread",
				function(r: Model)
					-- stepPoses then waves, panics and turns this one too
					local v = victimsByModel[model]
					if v and not parent then
						v.rig = r
					end
				end
			)
		end
	end
	model:SetAttribute("Rigged", rig ~= nil)
	if call.dive and not parent then
		f.fixedY = pos.Y + 5.5 -- feet just off the seabed (the rig hangs 4.55 under f.cf)
	end
	if type(call.privateTo) == "table" then
		-- a mission casualty: only its crew sees it until aboard (PrivateCasualtyController hides it)
		local ids = {}
		for _, p in call.privateTo do
			table.insert(ids, p.UserId)
		end
		model:SetAttribute("PrivateTo", Board.privateList(ids))
	end
	model.Parent = mapFolder
	-- a casualty in the water never blocks the boat that comes for them (the R15 torso collides
	-- by default and the floater is anchored: a held swimmer at the hull pinned the jet ski).
	-- The Humanoid turns torso CanCollide back on and the R15 rig loads later, so the collision
	-- group (set on every part, now and when added) does the real work.
	local function noCollide(part: Instance)
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CollisionGroup = CASUALTY_GROUP
		end
	end
	for _, part in model:GetDescendants() do
		noCollide(part)
	end
	model.DescendantAdded:Connect(noCollide)
	local victim = {
		call = call,
		model = model,
		root = root,
		floater = f,
		state = "Water",
		carrier = nil :: Model?,
		lastPos = pos,
		rig = rig,
		index = #(call.victims or {}) + 1,
	}
	local prompt = makePrompt(
		root,
		"Pull aboard",
		if parent then "Passenger" else "Swimmer",
		call.spec.interaction
	)
	prompt.Enabled = not call.opsDriven
	prompt.Triggered:Connect(function(player)
		onPull(victim, player)
	end)
	victim.prompt = prompt
	victimsByModel[model] = victim
	register(f)
	return victim
end

local function buildDinghy(call: any, pos: Vector3): Floater
	local model = Instance.new("Model")
	model.Name = "DriftingDinghy"
	model:SetAttribute("CallId", call.id)
	local f = newFloater(pos.X, pos.Z, 0)
	local blue = Color3.fromRGB(58, 123, 213)
	local root = newPart(model, "Floor", Vector3.new(4, 0.4, 8), Color3.fromRGB(60, 60, 70))
	addPart(f, root, CFrame.new(0, -0.2, 0))
	model.PrimaryPart = root
	for side = -1, 1, 2 do
		addPart(
			f,
			newPart(model, "Tube", Vector3.new(9, 1.4, 1.4), blue, Enum.PartType.Cylinder),
			CFrame.new(side * 2.2, 0.3, 0) * CFrame.Angles(0, math.pi / 2, 0)
		)
	end
	addPart(
		f,
		newPart(model, "Bow", Vector3.new(5.6, 1.4, 1.4), blue, Enum.PartType.Cylinder),
		CFrame.new(0, 0.3, -4.3)
	)
	addPart(
		f,
		newPart(model, "Paddle", Vector3.new(0.3, 0.2, 5), Color3.fromRGB(230, 230, 220)),
		CFrame.new(1.2, 0.6, 1) * CFrame.Angles(0, 0.4, 0)
	)
	model.Parent = mapFolder
	register(f)
	call.props = call.props or {}
	table.insert(call.props, { model = model, floater = f })
	return f
end

-- The Gale Queen greybox (fallback when the C2 art can't load): Hull 16x7x60 + Keel, Deckhouse, Bridge, Funnel,
-- five LifeRaft cylinders. Its floater frame sits 1.5 studs under the sea (the old buildFerry).
local GREYBOX_FERRY_DEPTH = -1.5
local function greyboxFerry(model: Model, f: Floater)
	f.depth = GREYBOX_FERRY_DEPTH
	local white, red = Color3.fromRGB(236, 236, 230), Color3.fromRGB(196, 48, 40)
	local hull = newPart(model, "Hull", Vector3.new(16, 7, 60), white)
	addPart(f, hull, CFrame.new(0, 2.5, 0))
	model.PrimaryPart = hull
	addPart(f, newPart(model, "Keel", Vector3.new(16, 5, 60), red), CFrame.new(0, -3.5, 0))
	addPart(f, newPart(model, "Deckhouse", Vector3.new(12, 6, 34), white), CFrame.new(0, 9, -4))
	addPart(
		f,
		newPart(model, "Bridge", Vector3.new(12.2, 2, 6), Color3.fromRGB(80, 110, 140)),
		CFrame.new(0, 10.5, -18)
	)
	addPart(
		f,
		newPart(model, "Funnel", Vector3.new(4, 6, 4), Color3.fromRGB(20, 40, 60)),
		CFrame.new(0, 15, 6)
	)
	for i = -2, 2 do
		addPart(
			f,
			newPart(
				model,
				"LifeRaft",
				Vector3.new(1.6, 1.6, 3),
				Color3.fromRGB(230, 120, 40),
				Enum.PartType.Cylinder
			),
			CFrame.new(6.5, 8, i * 6)
		)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "GALE QUEEN"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(20, 40, 60)
	label.Parent = gui
	gui.Parent = hull
	model:SetAttribute("Art", false)
end

local function ferryAtts(): FerryRig.Atts
	return ((AssetIds :: any).Attachments or {})[FerryRig.FERRY] or {}
end

local function raftAtts(): FerryRig.Atts
	return ((AssetIds :: any).Attachments or {})[FerryRig.RAFT] or {}
end

-- An attachment on `part` at a pivot-space point of an asset whose pivot is `pivot` (asset orientation).
local function pivotAttachment(part: BasePart, pivot: CFrame, name: string, at: CFrame)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = part.CFrame:ToObjectSpace(pivot * at)
	a.Parent = part
end

-- Moves an asset clone's parts onto floater `f` (anchored, riding `offset` * their place from the asset pivot).
-- Returns the parts by C2 token.
local function rideAsset(f: Floater, art: Model, offset: CFrame): { [string]: BasePart }
	local pivot = art:GetPivot()
	local byToken: { [string]: BasePart } = {}
	for _, d in art:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			addPart(f, d, offset * pivot:ToObjectSpace(d.CFrame))
			byToken[FerryRig.token(d.Name)] = d
		end
	end
	return byToken
end

-- Shows the parts of one ship state: "Capsized" (Damage + GrabLines) or "Upright" (Undamaged). Hidden parts
-- leave the model and the floater; ferry.stash keeps them with their offsets.
local function setFerryState(ferry: any, state: string)
	local f: Floater = ferry.floater
	ferry.state = state
	local keepParts, keepOffsets = {}, {}
	for i, part in f.parts do
		if FerryRig.visibleIn(part.Name, state) then
			table.insert(keepParts, part)
			table.insert(keepOffsets, f.offsets[i])
		else
			table.insert(ferry.stash, { part = part, offset = f.offsets[i], parent = part.Parent })
			part.Parent = nil
		end
	end
	local still = {}
	for _, s in ferry.stash do
		if FerryRig.visibleIn(s.part.Name, state) then
			s.part.Parent = s.parent
			s.part.CFrame = f.cf * s.offset
			table.insert(keepParts, s.part)
			table.insert(keepOffsets, s.offset)
		else
			table.insert(still, s)
		end
	end
	ferry.stash = still
	-- arms are keyed by part index; the ferry has none
	f.parts, f.offsets = keepParts, keepOffsets
end

-- The C2 Gale Queen on the floater; false when the asset can't load (the caller builds the greybox).
local function dressFerry(ferry: any): boolean
	local template = AssetLoader and AssetLoader.getTemplate(FerryRig.FERRY, FerryRig.LOD)
	local model: Model, f: Floater = ferry.model, ferry.floater
	if not (template and model.Parent and f.active) then
		return false
	end
	local atts = ferryAtts()
	local art = template:Clone()
	art.Name = "Art"
	local pivot = art:GetPivot()
	local parts = rideAsset(f, art, FerryRig.ferryOffset(atts))
	local hull = parts.Hull
	if hull then
		-- hull_knock.luau: FindFirstChild("Hull", true); HullAxis is its knock frame, AirPocket this op's pocket
		hull.Name = "Hull"
		hull.CanCollide = true -- the hull team stands on her upturned side
		hull.CanQuery = true
		model.PrimaryPart = hull
		pivotAttachment(hull, pivot, "HullAxis", FerryRig.hullAxis(atts))
		local pocket =
			FerryRig.pocketPoint(atts, HullKnock.pocketCompartment(tostring(ferry.callId)))
		if pocket then
			pivotAttachment(hull, pivot, "AirPocket", CFrame.new(pocket))
		end
		model:SetAttribute("HullLength", FerryRig.HULL_LENGTH)
	end
	f.depth = FerryRig.AXIS_ABOVE_SEA
	-- where the parts go on the next Heartbeat (the floater was already placed with the greybox depth)
	for i, part in f.parts do
		part.CFrame = f.cf * f.offsets[i]
	end
	if AssetLoader.setWet then
		pcall(AssetLoader.setWet, art, true)
	end
	art.Parent = model
	model:SetAttribute("Art", true)
	setFerryState(ferry, ferry.state)
	return true
end

-- A deployed liferaft, greybox until (or unless) the C2 raft loads: black tube ring, orange canopy.
local function greyboxRaft(model: Model, f: Floater)
	local tube = newPart(
		model,
		"Tubes",
		Vector3.new(1.4, 8.9, 8.9),
		Color3.fromRGB(30, 30, 32),
		Enum.PartType.Cylinder
	)
	addPart(f, tube, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2))
	model.PrimaryPart = tube
	local canopy = newPart(
		model,
		"Canopy",
		Vector3.new(7.6, 5, 7.6),
		Color3.fromRGB(240, 96, 30),
		Enum.PartType.Ball
	)
	canopy.Transparency = 0.35
	addPart(f, canopy, CFrame.new(0, 2.6, 0))
	model:SetAttribute("Art", false)
end

local function dressRaft(raft: any): boolean
	local template = AssetLoader and AssetLoader.getTemplate(FerryRig.RAFT, FerryRig.LOD)
	if not (template and raft.model.Parent and raft.floater.active) then
		return false
	end
	local art = template:Clone()
	art.Name = "Art"
	local parts = rideAsset(raft.floater, art, FerryRig.raftOffset(raftAtts()))
	if AssetLoader.setWet then
		pcall(AssetLoader.setWet, art, true)
	end
	art.Parent = raft.model
	raft.model.PrimaryPart = parts.Tubes or art.PrimaryPart
	raft.model:SetAttribute("Art", true)
	return true
end

-- The raft's painter back to the canister cradle it floated off from (a sagging Beam; both ends ride floaters).
local function rigPainter(ferry: any, raft: any)
	local a0 = ferry.model:FindFirstChild(FerryRig.liferaftName(raft.canister), true)
	local a1 = raft.model:FindFirstChild("ATT_Painter", true)
	if not (a0 and a0:IsA("Attachment") and a1 and a1:IsA("Attachment")) then
		return
	end
	local beam = Instance.new("Beam")
	beam.Name = "Painter"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0, beam.Width1 = 0.14, 0.14
	beam.Segments = 16
	beam.CurveSize0, beam.CurveSize1 = -3, 3
	beam.FaceCamera = true
	beam.LightInfluence = 1
	beam.Color = ColorSequence.new(Color3.fromRGB(206, 196, 168))
	beam.Parent = raft.model
end

-- Horizontal frame of the ferry floater (no tilt): x across (+ keel side), z along.
local function ferryPlan(f: Floater): CFrame
	return CFrame.new(f.x, 0, f.z) * CFrame.Angles(0, f.yaw, 0)
end

local function buildRaft(call: any, ferryF: Floater, spec: any, index: number): any
	local model = Instance.new("Model")
	model.Name = "Liferaft"
	model:SetAttribute("CallId", call.id)
	model:SetAttribute("Raft", index)
	local at = (ferryPlan(ferryF) * CFrame.new(spec.x, 0, spec.z)).Position
	local f = newFloater(at.X, at.Z, 0)
	f.yaw = ferryF.yaw + spec.yaw
	f.sway = 0.07
	model.Parent = mapFolder
	register(f)
	call.props = call.props or {}
	table.insert(call.props, { model = model, floater = f })
	return { model = model, floater = f, canister = spec.canister, index = index }
end

-- The capsized Gale Queen and her deployed liferafts. The floaters exist at once (casualties sit in the rafts
-- from the start); the C2 art loads in the background and the greybox stands in when it can't.
-- Waterline check (I1c, Studio): the roll axis rides AXIS_ABOVE_SEA over the midships sea, so the Damage part's
-- loose lines end FerryRig.lineEndDepth() under the calm surface.
local function buildFerry(call: any, pos: Vector3): (Floater, { any })
	local model = Instance.new("Model")
	model.Name = "GaleQueen"
	model:SetAttribute("CallId", call.id)
	local f = newFloater(pos.X, pos.Z, FerryRig.AXIS_ABOVE_SEA)
	f.yaw = math.rad(20)
	f.sway = 0.02
	f.tilt = CFrame.Angles(0, 0, FerryRig.TILT) -- lying on her side (keel side up)
	model.Parent = mapFolder
	register(f)
	call.props = call.props or {}
	table.insert(call.props, { model = model, floater = f })
	local ferry = {
		model = model,
		floater = f,
		callId = call.id,
		state = "Capsized",
		stash = {},
		rafts = {},
	}
	call.ferry = ferry
	for i, spec in FerryRig.RAFTS do
		table.insert(ferry.rafts, buildRaft(call, f, spec, i))
	end
	task.spawn(function()
		local ok, art = pcall(dressFerry, ferry)
		if not (ok and art) then
			if not ok then
				warn(`[RescueService] Gale Queen art failed: {art}`)
			end
			if model.Parent and f.active then
				greyboxFerry(model, f)
			end
		end
		for _, raft in ferry.rafts do
			local rok, rart = pcall(dressRaft, raft)
			if not (rok and rart) then
				if not rok then
					warn(`[RescueService] liferaft art failed: {rart}`)
				end
				if raft.model.Parent and raft.floater.active then
					greyboxRaft(raft.model, raft.floater)
				end
			elseif ok and art then
				rigPainter(ferry, raft)
			end
		end
	end)
	return f, ferry.rafts
end

-- Upright (Undamaged shows) or Capsized (Damage + GrabLines show). The op spawns her capsized.
function RescueService.SetFerryState(call: any, state: string)
	local ferry = call.ferry
	if ferry and (state == "Capsized" or state == "Upright") then
		setFerryState(ferry, state)
	end
end

-- Builds everything a call needs at call.position. Called by OperationService on accept / big-call start.
function RescueService.SpawnCall(call: any, victimPositions: { Vector3 }?)
	liveCalls[call] = true
	call.victims = {}
	local pos: Vector3 = call.position
	if call.kind == "DriftingCraft" then
		local dinghy = buildDinghy(call, pos)
		for i = 1, call.total do
			local seat = CFrame.new(0, 1.3, if i % 2 == 1 then -1.8 else 1.8)
				* CFrame.Angles(0, if i % 2 == 1 then 0 else math.pi, 0)
			table.insert(call.victims, spawnVictim(call, pos, dinghy, seat))
		end
	elseif call.kind ~= "CapsizedFerry" then
		-- swimmers: one on the spot, or spread round a vessel scene in the water beside her
		local n = call.total or 1
		for i = 1, n do
			local a = i / n * math.pi * 2
			local r = if n > 1 then SCATTER_RADIUS else 0
			table.insert(
				call.victims,
				spawnVictim(call, pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			)
		end
	else
		local ferryF, rafts = buildFerry(call, pos)
		local positions: { Vector3 } = victimPositions or {}
		local seats = FerryRig.assignSeats(#positions, #rafts)
		local plan = ferryPlan(ferryF)
		local rAtts = raftAtts()
		for i, p in positions do
			local seat = seats[i]
			local raft = seat and rafts[seat.raft]
			local offset = seat and FerryRig.seatOffset(rAtts, seat.seat)
			if raft and offset then
				table.insert(call.victims, spawnVictim(call, p, raft.floater, offset))
			else
				-- never inside the hull or under the superstructure
				local rel = plan:PointToObjectSpace(Vector3.new(p.X, 0, p.Z))
				local x, z = FerryRig.pushClear(rel.X, rel.Z)
				local clear = plan:PointToWorldSpace(Vector3.new(x, 0, z))
				table.insert(call.victims, spawnVictim(call, Vector3.new(clear.X, p.Y, clear.Z)))
			end
		end
	end
end

---------------------------------------------------------------- vehicles and pulling

local function vehicleOf(player: Player): Model?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local node: Instance? = hum and hum.SeatPart
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	local ok, v = try("VehicleService", "GetVehicle", player)
	if ok and typeof(v) == "Instance" and v:IsA("Model") and v.Parent then
		return v
	end
	return nil
end

local function driverOf(vehicle: Model): Player?
	local ok, d = try("VehicleService", "GetDriver", vehicle)
	if ok and typeof(d) == "Instance" and d:IsA("Player") then
		return d
	end
	local owner = vehicle:GetAttribute("Owner")
	return if type(owner) == "number" then Players:GetPlayerByUserId(owner) else nil
end

local function vehicleRoot(vehicle: Model): BasePart?
	return vehicle.PrimaryPart or vehicle:FindFirstChildWhichIsA("BasePart", true)
end

local function notify(call: any, player: Player, message: string)
	operations().Notify(call, player, message)
end

-- Unanchors and welds a victim into one assembly so it can ride a boat.
local function prepareCarry(victim: any)
	unregister(victim.floater)
	if victim.rig then
		victim.rig:SetAttribute("CasualtyPose", "Sit")
	end
	local f: Floater = victim.floater
	-- rest pose: arms down, sitting upright
	for i, part in f.parts do
		part.CFrame = f.cf * f.offsets[i]
	end
	for _, part in f.parts do
		part.Anchored = false
		part.Massless = true
		part.CanCollide = false
		if part ~= victim.root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = victim.root
			weld.Part1 = part
			weld.Parent = victim.root
		end
	end
end

local function restoreFloat(victim: any)
	for _, part in victim.floater.parts do
		part.Anchored = true
	end
	for _, w in victim.root:GetChildren() do
		if w:IsA("WeldConstraint") then
			w:Destroy()
		end
	end
	victim.floater.active = true
	if victim.rig then
		victim.rig:SetAttribute(
			"CasualtyPose",
			if victim.floater.parent then "Sit" else "TreadWater"
		)
	end
	register(victim.floater)
end

-- Fallback when VehicleService is missing: weld behind the boat's root.
local function fallbackWeld(vehicle: Model, victim: any): boolean
	local root = vehicleRoot(vehicle)
	if not root then
		return false
	end
	victim.model:PivotTo(root.CFrame * CFrame.new(0, 1.5, 2.5))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = victim.root
	weld.Parent = victim.root
	victim.model.Parent = vehicle
	return true
end

onPull = function(victim: any, player: Player, forced: boolean?)
	local call = victim.call
	if victim.state ~= "Water" or not liveCalls[call] then
		return
	end
	local Ops = operations()
	if not forced and not Ops.CanAct(call, player) then
		notify(call, player, "That's another crew's call.")
		return
	end
	local vehicle = vehicleOf(player)
	if not vehicle then
		notify(call, player, "Bring a boat alongside to pull them aboard.")
		return
	end
	if
		not forced
		and CallLogic.flatDistance(vehicle:GetPivot().Position, victim.root.Position)
			> call.spec.interaction.vehicleRange
	then
		notify(call, player, "Bring your boat closer.")
		return
	end
	prepareCarry(victim)
	local added: boolean
	local svc = service("VehicleService")
	if svc and type(svc.AddSurvivor) == "function" then
		local ok, result = pcall(svc.AddSurvivor, vehicle, victim.model)
		if ok then
			added = result == true
			if not added then
				restoreFloat(victim)
				notify(call, player, "Your boat is full. Deliver your survivors first.")
				return
			end
		else
			warn(`[RescueService] AddSurvivor failed: {result}`)
			added = fallbackWeld(vehicle, victim)
		end
	else
		added = fallbackWeld(vehicle, victim)
	end
	if not added then
		restoreFloat(victim)
		return
	end
	victim.state = "Aboard"
	victim.carrier = vehicle
	victim.model:SetAttribute("PrivateTo", nil) -- aboard: everyone sees them
	if victim.prompt then
		victim.prompt:Destroy()
		victim.prompt = nil
	end
	Ops.RecordAction(call, player)
	local driver = driverOf(vehicle)
	if driver then
		Ops.RecordAction(call, driver)
	end
	Ops.OnVictimBoarded(call, player)
end

---------------------------------------------------------------- per-frame motion

local function turnToward(f: Floater, target: number, k: number)
	local delta = (target - f.yaw + math.pi) % (2 * math.pi) - math.pi
	f.yaw += delta * k
end

local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

local function stepFloaters(now: number)
	table.clear(bulkParts)
	table.clear(bulkCFrames)
	for _, f in floaters do
		-- VehicleService owns anything welded aboard (OnVehicle)
		local owner = f.model
		if not owner and f.parts[1] then
			owner = f.parts[1]:FindFirstAncestorWhichIsA("Model")
			f.model = owner
		end
		if owner and owner:GetAttribute("OnVehicle") ~= nil then
			continue
		end
		if f.parent then
			f.cf = f.parent.cf * (f.parentOffset or CFrame.identity)
		else
			local h = heightAt(Vector3.new(f.x, 0, f.z), now)
			local roll = math.sin(now * 1.3 + f.phase) * f.sway
			local pitch = math.sin(now * 0.9 + f.phase * 1.7) * f.sway
			f.cf = CFrame.new(f.x, f.fixedY or h + f.depth, f.z)
				* CFrame.Angles(0, f.yaw, 0)
				* f.tilt
				* CFrame.Angles(pitch, 0, roll)
		end
		for i, part in f.parts do
			local arm = f.arms[i]
			local cf
			if arm then
				local wave = 2.4 + math.sin(now * 6 + f.phase + arm.side) * 0.45
				cf = f.cf
					* arm.shoulder
					* CFrame.Angles(0, 0, arm.side * wave)
					* CFrame.new(0, -arm.len / 2, 0)
			else
				cf = f.cf * f.offsets[i]
			end
			table.insert(bulkParts, part)
			table.insert(bulkCFrames, cf)
		end
	end
	if #bulkParts > 0 then
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

---------------------------------------------------------------- casualty poses (rigged swimmer)

-- Chooses each swimmer's client pose (CasualtyController): Panic while the casualty is panicking
-- (op casualties[i].panicking), Wave with a boat in sight, else TreadWater; a
-- swimmer who sees a boat turns slowly to face it. 4 Hz, server side (attributes replicate).
RescueService.WAVE_RANGE = 160 -- studs: a boat this close gets waved at
RescueService.WAVE_MIN = 9 -- studs: alongside, they stop waving and reach for the boat

local function stepPoses()
	local boats: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local v = vehicleOf(player)
		if v then
			table.insert(boats, v:GetPivot().Position)
		end
	end
	for call in liveCalls do
		if type(call.victims) ~= "table" then
			continue
		end
		for i, v in call.victims do
			local rig = v.rig
			if not rig or v.state ~= "Water" or not rig.Parent or v.floater.parent then
				continue
			end
			local c = type(call.casualties) == "table" and call.casualties[i]
			local f: Floater = v.floater
			local best, bestD = nil :: Vector3?, math.huge
			for _, b in boats do
				local d = Vector2.new(b.X - f.x, b.Z - f.z).Magnitude
				if d < bestD then
					best, bestD = b, d
				end
			end
			local pose = "TreadWater"
			local piw = v.model:GetAttribute("PiwMode") -- docs/14 section 3 ways (PiwRescue)
			if c and c.panicking then
				pose = "Panic"
			elseif piw == "held" or piw == "line" then
				pose = "Hold"
			elseif
				piw ~= nil -- armed, not yet holding on: waving the rescuer in
				or (best and bestD < RescueService.WAVE_RANGE and bestD > RescueService.WAVE_MIN)
			then
				pose = "Wave"
			end
			if best and bestD < RescueService.WAVE_RANGE then
				-- the face is -Z: yaw so the look vector points at the boat
				turnToward(f, math.atan2(-(best.X - f.x), -(best.Z - f.z)), 0.12)
			end
			if rig:GetAttribute("CasualtyPose") ~= pose then
				rig:SetAttribute("CasualtyPose", pose)
			end
		end
	end
end

---------------------------------------------------------------- drift and wake (persons in water)

-- A person in the water drifts mostly with the current and a little with the wind (docs 09
-- section 5.2), and a boat passing near pushes them away on its wake (Boat/Wake: Kelvin wedge,
-- side and prop wash). Scripted (the floaters are anchored); studs/s.
RescueService.DRIFT_CURRENT = 0.45 -- studs/s (about 0.3 kn), one direction per call -- tune
RescueService.DRIFT_LEEWAY = 0.15 -- studs/s downwind, doubled in a storm -- tune
RescueService.DRIFT_RANGE = 240 -- studs from where they went in: the base drift fades out here
RescueService.WAKE_PUSH_MAX = 12 -- studs/s cap on the summed wake push -- tune

-- Open water round a point: no quay, breakwater or moored boat (Workspace.Map / Dressing) within
-- `radius` at the waterline, nor overhead, so a craft can come alongside. Call spawns check it, and the
-- drift stops short of one (playtest 2026-10-24: call 2's dinghy lay against a moored crabber and the
-- jet ski could never get within reach). dir: check that way only (the drift's heading).
RescueService.CLEAR_SPAWN = 25 -- studs -- tune
RescueService.CLEAR_DRIFT = 8 -- studs -- tune
local seaParams = RaycastParams.new()
seaParams.FilterType = Enum.RaycastFilterType.Include
seaParams.RespectCanCollide = true
seaParams.IgnoreWater = true
local COMPASS = {}
for i = 0, 7 do
	table.insert(COMPASS, Vector3.new(math.cos(i * math.pi / 4), 0, math.sin(i * math.pi / 4)))
end
function RescueService.ClearWater(p: Vector3, radius: number, dir: Vector3?): boolean
	seaParams.FilterDescendantsInstances =
		{ Workspace:FindFirstChild("Map") :: any, Workspace:FindFirstChild("Dressing") }
	local at = Vector3.new(p.X, 1, p.Z)
	if Workspace:Raycast(at + Vector3.new(0, 30, 0), Vector3.new(0, -30, 0), seaParams) then
		return false -- under a hull or a deck
	end
	local dirs: { Vector3 } = if dir and dir.Magnitude > 1e-3 then { dir.Unit } else COMPASS
	for _, d in dirs do
		if Workspace:Raycast(at, d * radius, seaParams) then
			return false
		end
	end
	return true
end

local function currentOf(call: any): Vector3
	local c = call.driftCurrent
	if typeof(c) ~= "Vector3" then
		local id = tostring(call.id or "")
		local h = 7
		for i = 1, #id do
			h = (h * 31 + string.byte(id, i)) % 100003
		end
		local a = h / 100003 * math.pi * 2
		c = Vector3.new(math.cos(a), 0, math.sin(a))
		call.driftCurrent = c
	end
	return c
end

local function stepDrift(dt: number)
	if dt <= 0 then
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("Weather")
	local w = folder and folder:GetAttribute("WindDirection")
	local a = if type(w) == "number" then w else 0
	local storm = folder ~= nil and folder:GetAttribute("State") == "Storm"
	local leeway = Vector3.new(math.cos(a), 0, math.sin(a))
		* (RescueService.DRIFT_LEEWAY * (if storm then 2 else 1))
	for call in liveCalls do
		if type(call.victims) ~= "table" then
			continue
		end
		local base = currentOf(call) * RescueService.DRIFT_CURRENT + leeway
		for _, v in call.victims do
			local f: Floater? = v.floater
			if v.state ~= "Water" or not f or f.parent or not f.active then
				continue
			end
			local answer = PiwRescue.velocity(v, dt) -- swimming to / held by a rescuer (docs/14 3)
			if answer then
				f.x += answer.X * dt
				f.z += answer.Z * dt
				continue
			end
			local origin: Vector3 = v.driftOrigin or Vector3.new(f.x, 0, f.z)
			v.driftOrigin = origin
			local gone = (Vector3.new(f.x, 0, f.z) - origin).Magnitude
			local fade = 1 - math.clamp(gone / RescueService.DRIFT_RANGE, 0, 1)
			local push = Wake.pushAt(f.cf.Position)
			if push.Magnitude > RescueService.WAKE_PUSH_MAX then
				push = push.Unit * RescueService.WAKE_PUSH_MAX
			end
			local vel = base * fade + push
			-- the rip off the hub beach carries anything drifting in its channel out to sea (docs 09
			-- section 8.4). Engaged casualties (swimming to / held by a rescuer) are the rescuer's.
			vel += RipCurrent.velocityAt(RipCurrent.HubBeach, Vector3.new(f.x, 0, f.z))
			if not RescueService.ClearWater(f.cf.Position, RescueService.CLEAR_DRIFT, vel) then
				continue -- held off the quay / moored boat
			end
			f.x += vel.X * dt
			f.z += vel.Z * dt
		end
	end
end

---------------------------------------------------------------- deliveries

local function dropOffPads(): { BasePart }
	local pads = {}
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("DropOffs")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and child:GetAttribute("DropOff") ~= nil then
				table.insert(pads, child)
			end
		end
	end
	return pads
end

local function padAt(pos: Vector3, allowed: { string }, margin: number): string?
	for _, pad in dropOffPads() do
		local name = pad:GetAttribute("DropOff")
		if
			type(name) == "string"
			and table.find(allowed, name)
			and CallLogic.insidePad(pad.CFrame, pad.Size, pos, margin)
		then
			return name
		end
	end
	return nil
end

-- Removes the given victims from a vehicle, putting back any survivors that aren't in the list.
-- The drop-off (docs/20 change 4, a visible beat): a delivered survivor climbs off onto the nearest dry
-- footing beside the boat (quay, pontoon, slipway); with none in reach (a shore point lands them up to
-- 40 studs out) they swim to the first footing toward the nearest pad or slipway, then climb out, stand
-- and wave, and go up the quay (removed). No footing anywhere: handed straight in.
local CLIMB_OFF_SECONDS = 1.0
local SWIM_OFF_SPEED = 16 -- studs/s: a quick swim the camera can follow -- tune
local SWIM_OFF_MAX = 4 -- s cap on that swim
local FOOT_SEARCH = 150 -- studs toward the drop-off
local footParams = RaycastParams.new()
footParams.FilterType = Enum.RaycastFilterType.Exclude
footParams.IgnoreWater = true

local function footAt(p: Vector3, fromY: number): Vector3?
	local hit =
		Workspace:Raycast(Vector3.new(p.X, fromY + 20, p.Z), Vector3.new(0, -40, 0), footParams)
	return if hit and hit.Position.Y > 1 then hit.Position else nil
end

-- The nearest drop-off pad or cold-open slipway (its dry end) to `from`.
local function nearestHome(from: Vector3): Vector3?
	local best, bestD = nil :: Vector3?, math.huge
	local points = {}
	for _, pad in dropOffPads() do
		table.insert(points, pad.Position)
	end
	for _, sp in ColdOpen.SHORE do
		table.insert(points, sp.dry)
	end
	for _, p in points do
		local d = CallLogic.flatDistance(p, from)
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best
end

local function findFooting(from: Vector3): Vector3?
	for r = 5, 13, 4 do
		for k = 0, 7 do
			local a = k * math.pi / 4
			local foot = footAt(from + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), from.Y)
			if foot then
				return foot
			end
		end
	end
	local home = nearestHome(from)
	local dir = home and (home - from) * Vector3.new(1, 0, 1)
	if not (dir and dir.Magnitude > 1) then
		return nil
	end
	dir = dir.Unit
	for d = 14, FOOT_SEARCH, 3 do
		local foot = footAt(from + dir * d, from.Y)
		if foot then
			return foot + dir * 3 -- a step in from the edge
		end
	end
	return nil
end

local function climbOff(v: any, from: Vector3)
	local model: Model = v.model
	local vehicles = Workspace:FindFirstChild("Vehicles")
	footParams.FilterDescendantsInstances = if vehicles then { model, vehicles } else { model }
	local foot = findFooting(from)
	if not foot then
		model:Destroy()
		return
	end
	local _, size = model:GetBoundingBox()
	local start = model:GetPivot()
	local flat = Vector3.new(foot.X - start.X, 0, foot.Z - start.Z)
	local look = if flat.Magnitude > 0.1 then flat.Unit else start.LookVector
	-- far from the footing: off the side and a swim to just short of it, at the waterline
	local swimTo = foot - look * 2
	local swim = CallLogic.flatDistance(swimTo, start.Position)
	if swim > 6 then
		if v.rig then
			v.rig:SetAttribute("CasualtyPose", "TreadWater")
		end
		local seconds = math.min(swim / SWIM_OFF_SPEED, SWIM_OFF_MAX)
		local t0 = os.clock()
		while model.Parent do
			local u = math.min((os.clock() - t0) / seconds, 1)
			local p = start.Position:Lerp(swimTo, u)
			local y = heightAt(p, Workspace:GetServerTimeNow())
			model:PivotTo(CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + look))
			if u >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		start = model:GetPivot()
	end
	local stand = foot + Vector3.new(0, size.Y / 2, 0)
	local finish = CFrame.lookAt(stand, stand + look)
	if v.rig then
		v.rig:SetAttribute("CasualtyPose", "Wave")
	end
	local t0 = os.clock()
	while model.Parent do
		local u = math.min((os.clock() - t0) / CLIMB_OFF_SECONDS, 1)
		model:PivotTo(start:Lerp(finish, u) + Vector3.new(0, math.sin(u * math.pi) * 1.5, 0))
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	task.wait(2.5) -- a wave from the quay, then up to the ambulance
	model:Destroy()
end

-- patrol: Cleanup's harbour-patrol pick-up, not a delivery (no rescue counted)
local function unloadVictims(vehicle: Model, victims: { any }, patrol: boolean?)
	-- every delivery off a craft (pads, home / shore via RemoveVictim, free roam) lands here: the dock board's count
	local driver = if patrol then nil else driverOf(vehicle)
	local data: any = driver and DataService.Get(driver)
	if data then
		data.totalRescues += #victims
		DataService.MarkDirty(driver :: Player)
	end
	local svc = service("VehicleService")
	if svc and type(svc.RemoveSurvivors) == "function" then
		local ok, removed = pcall(svc.RemoveSurvivors, vehicle)
		if ok and type(removed) == "table" then
			for _, m in removed do
				local v = victimsByModel[m]
				if not (v and table.find(victims, v)) then
					pcall(svc.AddSurvivor, vehicle, m)
				end
			end
		end
	end
	local from = vehicle:GetPivot().Position
	for _, v in victims do
		v.state = "Delivered"
		victimsByModel[v.model] = nil
		task.spawn(climbOff, v, from)
	end
end

local function checkDeliveries()
	-- victims aboard, grouped per carrier
	local byCarrier: { [Model]: { any } } = {}
	for call in liveCalls do
		for i, v in call.victims do
			if v.state == "Aboard" then
				local carrier: Model? = v.carrier
				if not carrier or not carrier.Parent or not v.model.Parent then
					-- boat gone: the victim goes back in the water where it was last seen
					victimsByModel[v.model] = nil
					v.model:Destroy()
					local fresh = spawnVictim(call, v.lastPos)
					call.victims[i] = fresh
					operations().OnVictimLost(call)
				else
					v.lastPos =
						Vector3.new(carrier:GetPivot().Position.X, 0, carrier:GetPivot().Position.Z)
					local list = byCarrier[carrier] or {}
					byCarrier[carrier] = list
					table.insert(list, v)
				end
			end
		end
	end
	for carrier, list in byCarrier do
		local pos = carrier:GetPivot().Position
		local deliverable = {}
		local padOf: { [any]: string } = {}
		for _, v in list do
			local pad = padAt(pos, v.call.spec.dropOffs, DELIVER_MARGIN)
			if pad then
				table.insert(deliverable, v)
				padOf[v.call] = pad
			end
		end
		if #deliverable > 0 then
			local driver = driverOf(carrier)
			unloadVictims(carrier, deliverable)
			local perCall: { [any]: number } = {}
			for _, v in deliverable do
				perCall[v.call] = (perCall[v.call] or 0) + 1
			end
			for call, count in perCall do
				if driver then
					operations().RecordAction(call, driver)
				end
				if call.onDelivered then
					call.onDelivered(count, driver, padOf[call]) -- free-roam (AmbientRescueService)
				else
					operations().OnVictimsDelivered(call, count, driver, padOf[call])
				end
			end
		end
	end
end

---------------------------------------------------------------- ops v2 step effects

-- Recovery step succeeded: the victim goes aboard the player's boat (no range check: the client
-- mechanic already played the approach). Without a boat (or a full one) the victim is taken out
-- of the water and hidden ("Recovered"). Returns true when the victim rides the boat.
function RescueService.BoardVictim(call: any, index: number, player: Player): boolean
	local victim = call.victims and call.victims[index]
	if not victim or victim.state ~= "Water" then
		return victim ~= nil and victim.state == "Aboard"
	end
	if vehicleOf(player) then
		onPull(victim, player, true)
		if (victim.state :: any) == "Aboard" then
			return true
		end
	end
	victim.state = "Recovered"
	if victim.prompt then
		victim.prompt:Destroy()
		victim.prompt = nil
	end
	unregister(victim.floater)
	victimsByModel[victim.model] = nil
	victim.model:Destroy()
	return false
end

-- Stamina (0..1, the condition meter) on the casualty model, for CasualtyController's tiring visual.
function RescueService.SetStamina(call: any, index: number, stamina: number)
	local victim = call.victims and call.victims[index]
	if victim and victim.state == "Water" and victim.model.Parent then
		local v = math.floor(math.clamp(stamina, 0, 1) * 20 + 0.5) / 20
		if victim.model:GetAttribute("Stamina") ~= v then
			victim.model:SetAttribute("Stamina", v)
		end
	end
end

-- Where a casualty is now (the floater), or nil when they are not in the water.
function RescueService.VictimPosition(call: any, index: number): Vector3?
	local victim = call.victims and call.victims[index]
	if not victim or victim.state ~= "Water" then
		return nil
	end
	return victim.root.Position
end

-- A casualty was handed over without reaching a pad (stub transport, big-call movement):
-- take it off the boat or out of the water.
function RescueService.RemoveVictim(call: any, index: number)
	local victim = call.victims and call.victims[index]
	if not victim or victim.state == "Delivered" then
		return
	end
	if victim.state == "Aboard" and victim.carrier and victim.carrier.Parent then
		unloadVictims(victim.carrier, { victim })
		return
	end
	victim.state = "Delivered"
	unregister(victim.floater)
	victimsByModel[victim.model] = nil
	victim.model:Destroy()
end

---------------------------------------------------------------- queries and cleanup

-- Positions still to reach: victims in the water.
function RescueService.GetTargets(call: any): { Vector3 }
	local out = {}
	for _, v in call.victims or {} do
		if v.state == "Water" then
			table.insert(out, v.floater.cf.Position)
		end
	end
	return out
end

function RescueService.CountAboard(call: any): number
	local n = 0
	for _, v in call.victims or {} do
		if v.state == "Aboard" then
			n += 1
		end
	end
	return n
end

-- Removes everything a call spawned. Victims still aboard are taken off the boat too
-- (the harbour patrol picks them up).
function RescueService.Cleanup(call: any)
	liveCalls[call] = nil
	local aboard: { [Model]: { any } } = {}
	for _, v in call.victims or {} do
		if v.state == "Aboard" and v.carrier and v.carrier.Parent then
			local list = aboard[v.carrier] or {}
			aboard[v.carrier] = list
			table.insert(list, v)
		elseif v.state ~= "Delivered" then
			unregister(v.floater)
			victimsByModel[v.model] = nil
			v.model:Destroy()
		end
	end
	for carrier, list in aboard do
		unloadVictims(carrier, list, true)
	end
	for _, prop in call.props or {} do
		unregister(prop.floater)
		prop.model:Destroy()
	end
	call.props = nil
end

-- Studio dev hook (RP-I1c ferry check): ServerStorage.FerryDev:Invoke(cmd). "start" the big call, "info" the ferry and rafts as built,
-- "lines" how deep the Damage part's loose lines end under the sea over ~4 s, "toggle" Upright and back,
-- "board" a raft casualty into a RIB spawned for the first player.
local function liveFerry(): any?
	for call in liveCalls do
		if call.kind == "CapsizedFerry" and call.ferry then
			return call
		end
	end
	return nil
end

local function present(model: Instance, token: string): boolean
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and FerryRig.token(d.Name) == token then
			return true
		end
	end
	return false
end

local function ferryDev(cmd: string): any
	if cmd == "start" then
		operations().ForceBigCall()
		return liveFerry() ~= nil
	end
	local call = liveFerry()
	if not call then
		return "no ferry"
	end
	local ferry = call.ferry
	local f: Floater = ferry.floater
	if cmd == "info" then
		local hull = ferry.model:FindFirstChild("Hull", true)
		local marks = {}
		for _, d in ferry.model:GetDescendants() do
			if d:IsA("Attachment") then
				table.insert(marks, d.Name)
			end
		end
		table.sort(marks)
		local rafts = {}
		for _, r in ferry.rafts do
			local seated = 0
			for _, v in call.victims do
				if v.floater and v.floater.parent == r.floater then
					seated += 1
				end
			end
			table.insert(rafts, {
				art = r.model:GetAttribute("Art"),
				seated = seated,
				painter = r.model:FindFirstChild("Painter", true) ~= nil,
				pos = r.floater.cf.Position,
			})
		end
		return {
			art = ferry.model:GetAttribute("Art"),
			hull = hull and hull:IsA("BasePart") and { hull.Name, hull.Size, hull.CanCollide }
				or false,
			hullLength = ferry.model:GetAttribute("HullLength"),
			marks = table.concat(marks, ","),
			damage = present(ferry.model, "Damage"),
			grab = present(ferry.model, "GrabLines"),
			undamaged = present(ferry.model, "Undamaged"),
			parts = #f.parts,
			depth = f.depth,
			pocket = HullKnock.pocketCompartment(tostring(call.id)),
			rafts = rafts,
			victims = #call.victims,
			opId = call.id,
		}
	elseif cmd == "lines" then
		local depths = {}
		for _ = 1, 20 do
			local now = Workspace:GetServerTimeNow()
			local plan = ferryPlan(f)
			for z = -25, 25, 10 do
				local at = plan:PointToWorldSpace(
					Vector3.new(FerryRig.rolledAcross(Vector3.new(9, 10, 0)), 0, z)
				)
				local water = heightAt(at, now)
				local axisY = (f.cf * CFrame.new(0, 0, z)).Position.Y
				table.insert(depths, water - (axisY - FerryRig.LINE_END_BELOW_AXIS))
			end
			task.wait(0.2)
		end
		table.sort(depths)
		local sum = 0
		for _, d in depths do
			sum += d
		end
		return { min = depths[1], max = depths[#depths], mean = sum / #depths, n = #depths }
	elseif cmd == "toggle" then
		setFerryState(ferry, "Upright")
		local up = { present(ferry.model, "Undamaged"), present(ferry.model, "Damage") }
		setFerryState(ferry, "Capsized")
		local cap = { present(ferry.model, "Undamaged"), present(ferry.model, "Damage") }
		return { upright = up, capsized = cap }
	elseif cmd == "board" then
		local player = Players:GetPlayers()[1]
		local index, victim = nil, nil
		for i, v in call.victims do
			if v.state == "Water" and v.floater and v.floater.parent then
				index, victim = i, v
				break
			end
		end
		if not (player and index and victim) then
			return "no raft casualty"
		end
		local at = victim.floater.cf.Position
		local ok, boat = try(
			"VehicleService",
			"SpawnSeated",
			player,
			"RIB",
			CFrame.new(at.X + 10, at.Y + 2, at.Z),
			0,
			"Scripted"
		)
		task.wait(2)
		local boarded = RescueService.BoardVictim(call, index, player)
		return {
			spawned = ok and boat ~= nil,
			boarded = boarded,
			state = victim.state,
			index = index,
		}
	end
	return "unknown"
end

function RescueService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(CASUALTY_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(CASUALTY_GROUP, "Default", false)
	local existing = Workspace:FindFirstChild("CallProps")
	if existing and existing:IsA("Folder") then
		mapFolder = existing
	else
		mapFolder = Instance.new("Folder")
		mapFolder.Name = "CallProps"
		mapFolder.Parent = Workspace
	end
end

function RescueService.Start()
	if CasualtyAsset then
		CasualtyAsset.preload()
	end
	if AssetLoader then
		AssetLoader.preload({ FerryRig.FERRY, FerryRig.RAFT })
	end
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "FerryDev"
		dev.OnInvoke = ferryDev
		dev.Parent = game:GetService("ServerStorage")
	end
	PiwRescue.start(liveCalls, function(call, player)
		return operations().CanAct(call, player)
	end)
	local accum, poseAccum = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		stepDrift(dt)
		stepFloaters(now)
		poseAccum += dt
		if poseAccum >= 0.25 then
			poseAccum = 0
			stepPoses()
		end
		accum += dt
		if accum >= 0.2 then
			accum = 0
			checkDeliveries()
		end
	end)
end

-- Exposed for tests.
RescueService.SpawnZones = CallTypes.SpawnZones

return RescueService
