--!strict
-- RescueService: the physical side of calls. Builds victims (greybox people in Survivor Yellow
-- life vests), drifting dinghies, disabled boats and the capsized ferry; bobs them on
-- Weather.heightAt every Heartbeat (anchored, no physics); runs the hold-to-pull and tow prompts;
-- and detects deliveries at the DropOff pads. Call bookkeeping and pay live in CallService.
--
-- CONTRACT: the towed NPC boat stays anchored and is moved by this script along the tow line.
-- VehicleService.AttachTow is still called (rope visual and hitch) inside pcall; if it errors or is
-- missing, a Beam stands in for the rope.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CallLogic = require(Shared:WaitForChild("Calls"):WaitForChild("CallLogic"))
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local Waves = require(Shared:WaitForChild("Waves"))

local RescueService = {}
RescueService.Priority = 60

local SURVIVOR_YELLOW = Color3.fromHex("#FFD23F")
local SKIN =
	{ Color3.fromRGB(255, 214, 170), Color3.fromRGB(198, 140, 100), Color3.fromRGB(120, 80, 55) }
local SHIRTS =
	{ Color3.fromRGB(70, 120, 190), Color3.fromRGB(200, 80, 90), Color3.fromRGB(90, 160, 110) }
local DELIVER_MARGIN = 12
local TOW_DOCK_MARGIN = 16
local TOW_LENGTH = 18

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
}

local floaters: { Floater } = {}
local victimsByModel: { [Model]: any } = {}
local liveCalls: { [any]: boolean } = {}
local mapFolder: Folder

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

local function callService(): any
	return require(script.Parent:WaitForChild("CallService") :: ModuleScript) :: any
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
local function addPerson(f: Floater, model: Instance, base: CFrame, vest: boolean)
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

local onPull: (victim: any, player: Player) -> ()
local onTow: (call: any, player: Player) -> ()

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
	addPerson(f, model, CFrame.identity, true)
	model.Parent = mapFolder
	local victim = {
		call = call,
		model = model,
		root = root,
		floater = f,
		state = "Water",
		carrier = nil :: Model?,
		lastPos = pos,
	}
	local prompt = makePrompt(
		root,
		"Pull aboard",
		if parent then "Passenger" else "Swimmer",
		call.spec.interaction
	)
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

local function buildDisabledBoat(call: any, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "DisabledBoat"
	model:SetAttribute("CallId", call.id)
	local f = newFloater(pos.X, pos.Z, 0.3)
	f.sway = 0.04
	local hull = newPart(model, "Hull", Vector3.new(6, 2.4, 14), Color3.fromRGB(236, 236, 230))
	addPart(f, hull, CFrame.identity)
	model.PrimaryPart = hull
	addPart(
		f,
		newPart(model, "Stripe", Vector3.new(6.1, 0.5, 14.1), Color3.fromRGB(40, 90, 160)),
		CFrame.new(0, -0.4, 0)
	)
	addPart(
		f,
		newPart(model, "Cabin", Vector3.new(4.4, 3, 5), Color3.fromRGB(236, 236, 230)),
		CFrame.new(0, 2.7, 2)
	)
	addPart(
		f,
		newPart(model, "Windshield", Vector3.new(4.2, 1.2, 0.3), Color3.fromRGB(120, 170, 200)),
		CFrame.new(0, 3.4, -0.55)
	)
	addPart(
		f,
		newPart(
			model,
			"Smoke",
			Vector3.new(1.2, 1.2, 1.2),
			Color3.fromRGB(70, 70, 70),
			Enum.PartType.Ball
		),
		CFrame.new(0, 1.6, 6)
	)
	addPerson(f, model, CFrame.new(1.5, 2.6, -3.5), true) -- the skipper, waving from the bow
	local bow = Instance.new("Attachment")
	bow.Name = "BowPoint"
	bow.Position = Vector3.new(0, 0.6, -7)
	bow.Parent = hull
	model.Parent = mapFolder
	register(f)
	local prompt = makePrompt(hull, "Attach tow line", "Disabled boat", call.spec.interaction)
	prompt.Triggered:Connect(function(player)
		onTow(call, player)
	end)
	call.boat = {
		model = model,
		floater = f,
		hull = hull,
		bow = bow,
		prompt = prompt,
		state = "Waiting",
		tower = nil :: Model?,
	}
end

local function buildFerry(call: any, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "GaleQueen"
	model:SetAttribute("CallId", call.id)
	local f = newFloater(pos.X, pos.Z, -1.5)
	f.yaw = math.rad(20)
	f.sway = 0.02
	f.tilt = CFrame.Angles(0, 0, math.rad(72)) -- lying on her side
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
	model.Parent = mapFolder
	register(f)
	call.props = call.props or {}
	table.insert(call.props, { model = model, floater = f })
end

-- Builds everything a call needs at call.position. Called by CallService on accept / big-call start.
function RescueService.SpawnCall(call: any, victimPositions: { Vector3 }?)
	liveCalls[call] = true
	call.victims = {}
	local pos: Vector3 = call.position
	if call.kind == "Swimmer" then
		table.insert(call.victims, spawnVictim(call, pos))
	elseif call.kind == "DriftingCraft" then
		local dinghy = buildDinghy(call, pos)
		for i = 1, call.total do
			local seat = CFrame.new(0, 1.3, if i % 2 == 1 then -1.8 else 1.8)
				* CFrame.Angles(0, if i % 2 == 1 then 0 else math.pi, 0)
			table.insert(call.victims, spawnVictim(call, pos, dinghy, seat))
		end
	elseif call.kind == "Tow" then
		buildDisabledBoat(call, pos)
	elseif call.kind == "CapsizedFerry" then
		buildFerry(call, pos)
		local positions: { Vector3 } = victimPositions or {}
		for _, p in positions do
			table.insert(call.victims, spawnVictim(call, p))
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
	callService().Notify(call, player, message)
end

-- Unanchors and welds a victim into one assembly so it can ride a boat.
local function prepareCarry(victim: any)
	unregister(victim.floater)
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

onPull = function(victim: any, player: Player)
	local call = victim.call
	if victim.state ~= "Water" or not liveCalls[call] then
		return
	end
	local CallService = callService()
	if not CallService.CanAct(call, player) then
		notify(call, player, "That's another crew's call.")
		return
	end
	local vehicle = vehicleOf(player)
	if not vehicle then
		notify(call, player, "Bring a boat alongside to pull them aboard.")
		return
	end
	if
		CallLogic.flatDistance(vehicle:GetPivot().Position, victim.root.Position)
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
	if victim.prompt then
		victim.prompt:Destroy()
		victim.prompt = nil
	end
	CallService.RecordAction(call, player)
	local driver = driverOf(vehicle)
	if driver then
		CallService.RecordAction(call, driver)
	end
	CallService.OnVictimBoarded(call, player)
end

onTow = function(call: any, player: Player)
	local boat = call.boat
	if not boat or boat.state ~= "Waiting" or not liveCalls[call] then
		return
	end
	local CallService = callService()
	if not CallService.CanAct(call, player) then
		notify(call, player, "That's another crew's call.")
		return
	end
	local vehicle = vehicleOf(player)
	if not vehicle then
		notify(call, player, "Bring a boat alongside to attach the tow line.")
		return
	end
	if
		CallLogic.flatDistance(vehicle:GetPivot().Position, boat.hull.Position)
		> call.spec.interaction.vehicleRange
	then
		notify(call, player, "Bring your boat closer.")
		return
	end
	local vehicleId = vehicle:GetAttribute("VehicleId")
	local spec = if type(vehicleId) == "string" then VehicleConfig.get(vehicleId) else nil
	if spec and not spec.canTow then
		notify(call, player, `The {spec.displayName} can't tow. Take the RIB.`)
		return
	end
	local svc = service("VehicleService")
	local attached = false
	if svc and type(svc.AttachTow) == "function" then
		local ok, result = pcall(svc.AttachTow, vehicle, boat.model)
		if ok and result == false then
			notify(call, player, "Can't attach the tow line to this boat.")
			return
		end
		attached = ok
		if not ok then
			warn(`[RescueService] AttachTow failed: {result}`)
		end
	end
	if not attached then
		-- visual stand-in for the rope
		local root = vehicleRoot(vehicle)
		if root then
			local a0 = Instance.new("Attachment")
			a0.Name = "CallTowA0"
			a0.Position = Vector3.new(0, 0.5, root.Size.Z / 2)
			a0.Parent = root
			local beam = Instance.new("Beam")
			beam.Name = "CallTowRope"
			beam.Attachment0 = a0
			beam.Attachment1 = boat.bow
			beam.Width0, beam.Width1 = 0.3, 0.3
			beam.Color = ColorSequence.new(Color3.fromRGB(240, 230, 200))
			beam.FaceCamera = true
			beam.Parent = boat.hull
			boat.fallbackRope = { a0, beam } :: { Instance }
		end
	end
	boat.state = "Towed"
	boat.tower = vehicle
	boat.usesVehicleService = attached
	boat.prompt.Enabled = false
	CallService.RecordAction(call, player)
	local driver = driverOf(vehicle)
	if driver then
		CallService.RecordAction(call, driver)
	end
	CallService.OnTowAttached(call, player)
end

local function releaseTow(boat: any)
	if boat.tower and boat.usesVehicleService then
		try("VehicleService", "DetachTow", boat.tower)
	end
	if boat.fallbackRope then
		for _, inst in boat.fallbackRope do
			inst:Destroy()
		end
		boat.fallbackRope = nil
	end
	boat.tower = nil
end

---------------------------------------------------------------- per-frame motion

local function hitchPosition(vehicle: Model): Vector3
	local hitch = vehicle:FindFirstChild("TowHitch", true)
	if hitch and hitch:IsA("Attachment") then
		return hitch.WorldPosition
	end
	local cf = vehicle:GetPivot()
	return (cf * CFrame.new(0, 0, 6)).Position
end

local function towLength(vehicle: Model): number
	local rope = vehicle:FindFirstChildWhichIsA("RopeConstraint", true)
	return if rope then rope.Length else TOW_LENGTH
end

local function stepTow(call: any, dt: number)
	local boat = call.boat
	if not boat or boat.state ~= "Towed" then
		return
	end
	local tower: Model? = boat.tower
	if not tower or not tower.Parent then
		releaseTow(boat)
		boat.state = "Waiting"
		boat.prompt.Enabled = true
		callService().OnTowLost(call)
		return
	end
	local f: Floater = boat.floater
	local hitch = hitchPosition(tower)
	local dx, dz = hitch.X - f.x, hitch.Z - f.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local keep = towLength(tower) * 0.92 + 7 -- rope plus half a hull, slack so the rope never yanks
	if dist > keep * 3 then
		releaseTow(boat)
		boat.state = "Waiting"
		boat.prompt.Enabled = true
		callService().OnTowLost(call)
		return
	end
	if dist > keep then
		local pull = (dist - keep) / dist
		f.x += dx * pull
		f.z += dz * pull
	end
	if dist > 1 then
		local target = math.atan2(-dx, -dz)
		local delta = (target - f.yaw + math.pi) % (2 * math.pi) - math.pi
		f.yaw += delta * math.min(dt * 2, 1)
	end
end

local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

local function stepFloaters(now: number)
	table.clear(bulkParts)
	table.clear(bulkCFrames)
	for _, f in floaters do
		if f.parent then
			f.cf = f.parent.cf * (f.parentOffset or CFrame.identity)
		else
			local h = heightAt(Vector3.new(f.x, 0, f.z), now)
			local roll = math.sin(now * 1.3 + f.phase) * f.sway
			local pitch = math.sin(now * 0.9 + f.phase * 1.7) * f.sway
			f.cf = CFrame.new(f.x, h + f.depth, f.z)
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

function RescueService.GetDropOffs(dropOffs: { string }): { { name: string, position: Vector3 } }
	local out = {}
	for _, pad in dropOffPads() do
		local name = pad:GetAttribute("DropOff")
		if type(name) == "string" and table.find(dropOffs, name) then
			table.insert(out, { name = name, position = pad.Position })
		end
	end
	return out
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
local function unloadVictims(vehicle: Model, victims: { any })
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
	for _, v in victims do
		v.state = "Delivered"
		victimsByModel[v.model] = nil
		v.model:Destroy()
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
					callService().OnVictimLost(call)
				else
					v.lastPos =
						Vector3.new(carrier:GetPivot().Position.X, 0, carrier:GetPivot().Position.Z)
					local list = byCarrier[carrier] or {}
					byCarrier[carrier] = list
					table.insert(list, v)
				end
			end
		end
		local boat = call.boat
		if boat and boat.state == "Towed" then
			local pos = Vector3.new(boat.floater.x, 0.2, boat.floater.z)
			if padAt(pos, call.spec.dropOffs, TOW_DOCK_MARGIN) then
				local tower = boat.tower
				releaseTow(boat)
				boat.state = "Moored"
				callService().OnTowDelivered(call, tower and driverOf(tower))
			end
		end
	end
	for carrier, list in byCarrier do
		local pos = carrier:GetPivot().Position
		local deliverable = {}
		for _, v in list do
			if padAt(pos, v.call.spec.dropOffs, DELIVER_MARGIN) then
				table.insert(deliverable, v)
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
					callService().RecordAction(call, driver)
				end
				callService().OnVictimsDelivered(call, count, driver)
			end
		end
	end
end

---------------------------------------------------------------- queries and cleanup

-- Positions still to reach: victims in the water, or the disabled boat waiting for a tow.
function RescueService.GetTargets(call: any): { Vector3 }
	local out = {}
	for _, v in call.victims or {} do
		if v.state == "Water" then
			table.insert(out, v.floater.cf.Position)
		end
	end
	if call.boat and call.boat.state == "Waiting" then
		table.insert(out, Vector3.new(call.boat.floater.x, 0, call.boat.floater.z))
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

function RescueService.IsTowing(call: any): boolean
	return call.boat ~= nil and call.boat.state == "Towed"
end

function RescueService.TowPosition(call: any): Vector3?
	local boat = call.boat
	return if boat then Vector3.new(boat.floater.x, 0, boat.floater.z) else nil
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
		unloadVictims(carrier, list)
	end
	local boat = call.boat
	if boat then
		releaseTow(boat)
		local delay = if boat.state == "Moored" then 8 else 0
		boat.state = "Gone"
		task.delay(delay, function()
			unregister(boat.floater)
			boat.model:Destroy()
		end)
	end
	for _, prop in call.props or {} do
		unregister(prop.floater)
		prop.model:Destroy()
	end
	call.props = nil
end

function RescueService.Init()
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
	local accum = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = Workspace:GetServerTimeNow()
		for call in liveCalls do
			stepTow(call, dt)
		end
		stepFloaters(now)
		accum += dt
		if accum >= 0.2 then
			accum = 0
			checkDeliveries()
		end
	end)
end

-- Exposed for CallService fallbacks and tests.
RescueService.SpawnZones = CallTypes.SpawnZones

return RescueService
