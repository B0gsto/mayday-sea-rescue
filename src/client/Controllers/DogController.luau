--!strict
-- DogController: Bosun's body language and his point-and-bark, on the client.
--
-- Motion: every dog in Workspace.Bosun (DogService) is the uploaded LP mesh (or the greybox BosunRig)
-- on an invisible root the server moves, its parts on Motor6Ds named after the Shared.Dog.BosunMotion
-- pose keys (Root, Neck, Jaw, Tail1, Tail2, the eight leg joints). Each frame (PreSimulation) this
-- writes their Transforms: breathing
-- and panting, the trot while he follows, sitting when he stops (and while he waits ashore for a jet ski),
-- his head turning to his owner, a casualty or a passing glance, a tail wag (carried high when excited or
-- swimming, low when he sits or is tired, tucked when wet), a float and paddle when he swims, a shake when
-- he climbs out, and a lean into the boat's motion aboard. Inputs come from the replicated Mode and
-- Wetness attributes and the root's velocity. Transforms are local; the server owns position.
--
-- Every client draws the same low-poly faceted LP mesh (docs/14 section 4, 2026-10-18: no fur-card
-- hero close-up).
--
-- DogPoint (DogService): his head turns toward the victim and the tail goes, a "Woof!" bubble pops
-- over his head and a small Waypoint Green arrow hovers beside him pointing the way. The arrow is
-- skipped while ReplicatedStorage attribute UseMapWaypoints is true (the map shows the casualty).
-- K14: a guide point while he rides hidden on the craft (payload.from = the craft) barks and shows
-- the arrow from the craft instead of his hidden body; a "Woof!" with no dog in sight read wrong,
-- so the bubble there is a paw print on the craft's side toward the casualty.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local BosunMotion = require(Shared:WaitForChild("Dog"):WaitForChild("BosunMotion"))
local Net = require(Shared:WaitForChild("Net"))

local DogController = {}

local SHOW_SECONDS = 2.2
local BARK_GAP = 20 -- s between barks: DogService sniffs every 4 s, a bark each time nags
local BUBBLE_NEAR = 16 -- studs from the camera: closer, the bubble would sit mid-screen (bark only)
local OWNER_LOOK_RANGE = 28 -- studs: he watches his owner inside this
local ARROW_COLOR = Color3.fromHex("3EE07A") -- Waypoint Green: where to go (docs 05 section 3.2)
local BUBBLE_TEXT = Color3.fromHex("0A2A3B")

type DogState = {
	model: Model,
	motion: BosunMotion.State,
	motors: { [string]: { Motor6D } },
	dirty: boolean,
	hidden: boolean, -- model attribute Hidden: his player is in a vehicle
	lastVel: Vector3,
	accel: Vector3,
	pointAt: Vector3?,
	pointUntil: number,
	glanceDir: Vector3?,
	glanceUntil: number,
	nextGlance: number,
	connections: { RBXScriptConnection },
}

local active: { [Model]: number } = {}
local dogs: { [Model]: DogState } = {}
local lastBark: { [Model]: number } = {}
local rng = Random.new()

-- A paw print: one pad and four toes, in the bubble's stroke colour.
local function addPaw(frame: Frame)
	local function dot(size: number, x: number, y: number)
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromScale(size, size * (if size > 0.3 then 0.85 else 1.15))
		d.Position = UDim2.fromScale(x, y)
		d.BackgroundColor3 = Color3.fromHex("FF6B1A")
		d.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = d
		d.Parent = frame
	end
	dot(0.42, 0.5, 0.64)
	dot(0.15, 0.24, 0.42)
	dot(0.15, 0.4, 0.28)
	dot(0.15, 0.6, 0.28)
	dot(0.15, 0.76, 0.42)
end

local function makeBubble(body: BasePart, pawToward: Vector3?): BillboardGui
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "WoofBubble"
	bubble.Size = if pawToward then UDim2.fromOffset(46, 46) else UDim2.fromOffset(84, 40)
	bubble.StudsOffsetWorldSpace = if pawToward
		then pawToward * 4 + Vector3.new(0, 3, 0)
		else Vector3.new(0, 2.2, 0)
	bubble.AlwaysOnTop = true
	bubble.MaxDistance = 250
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromHex("F4F1EA")
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("FF6B1A")
	stroke.Thickness = 3
	stroke.Parent = frame
	if pawToward then
		corner.CornerRadius = UDim.new(0.5, 0)
		addPaw(frame)
	else
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "Woof!"
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 22
		label.TextColor3 = BUBBLE_TEXT
		label.Parent = frame
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = frame
	frame.Parent = bubble
	bubble.Adornee = body:FindFirstChild("BarkAttachment") or body
	bubble.Parent = body
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	return bubble
end

local function makeArrow(): Model
	local model = Instance.new("Model")
	model.Name = "BosunArrow"
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.35, 0.2, 1.4)
	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.2, 0.9, 0.8)
	for _, p in { shaft, tip } :: { BasePart } do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = ARROW_COLOR
		p.Parent = model
	end
	model.PrimaryPart = shaft
	model.Parent = Workspace
	return model
end

local function placeArrow(arrow: Model, origin: Vector3, direction: Vector3, t: number)
	local shaft = arrow:FindFirstChild("Shaft") :: BasePart
	local tip = arrow:FindFirstChild("Tip") :: BasePart
	local bob = math.sin(t * 8) * 0.25
	local base = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 2.2 + bob, -2.4 - bob)
	shaft.CFrame = base
	-- wedge lying flat, its slope facing forward: a flat arrowhead
	tip.CFrame = base
		* CFrame.new(0, 0, -1.1)
		* CFrame.Angles(0, 0, math.rad(90))
		* CFrame.Angles(0, math.rad(180), 0)
end

-- Rig cache ----------------------------------------------------------------------------------------

local function rebuild(state: DogState)
	state.dirty = false
	local motors: { [string]: { Motor6D } } = {}
	local fade = if state.hidden then 1 else 0
	for _, d in state.model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = motors[d.Name] or {}
			table.insert(motors[d.Name], d)
		elseif d:IsA("BasePart") then
			d.LocalTransparencyModifier = fade
		end
	end
	state.motors = motors
end

local function track(model: Instance)
	if not model:IsA("Model") or dogs[model] then
		return
	end
	local state: DogState = {
		model = model,
		motion = BosunMotion.new(),
		motors = {},
		dirty = true,
		hidden = false,
		lastVel = Vector3.zero,
		accel = Vector3.zero,
		pointAt = nil,
		pointUntil = 0,
		glanceDir = nil,
		glanceUntil = 0,
		nextGlance = os.clock() + rng:NextNumber(3, 7),
		connections = {},
	}
	local function markDirty()
		state.dirty = true
	end
	table.insert(state.connections, model.DescendantAdded:Connect(markDirty))
	table.insert(state.connections, model.DescendantRemoving:Connect(markDirty))
	dogs[model] = state
end

local function untrack(model: Instance)
	local state = dogs[model :: Model]
	if state then
		for _, c in state.connections do
			c:Disconnect()
		end
		dogs[model :: Model] = nil
	end
	lastBark[model :: Model] = nil
end

-- Motion ------------------------------------------------------------------------------------------

local function ownerHead(model: Model): Vector3?
	local owner = Players:GetPlayerByUserId(model:GetAttribute("Owner") :: number? or 0)
	local character = owner and owner.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	return if head then head.Position else nil
end

local function lookTarget(state: DogState, body: BasePart, now: number, moving: boolean): Vector3?
	local origin = body.Position + body.CFrame:VectorToWorldSpace(Vector3.new(0, 0.5, -2))
	if state.pointAt and now < state.pointUntil then
		return body.CFrame:VectorToObjectSpace(state.pointAt - origin)
	end
	if state.glanceDir and now < state.glanceUntil then
		return state.glanceDir
	end
	if now > state.nextGlance then
		-- a glance at something off to the side (gulls, a passing boat)
		state.glanceDir = CFrame.fromEulerAnglesYXZ(
			rng:NextNumber(-0.25, 0.2),
			rng:NextNumber(-0.5, 0.5),
			0
		).LookVector
		state.glanceUntil = now + rng:NextNumber(0.8, 1.8)
		state.nextGlance = now + rng:NextNumber(4, 9)
		return state.glanceDir
	end
	local head = ownerHead(state.model)
	if head and not moving and (head - origin).Magnitude < OWNER_LOOK_RANGE then
		return body.CFrame:VectorToObjectSpace(head - origin)
	end
	return nil
end

local function stepDog(state: DogState, dt: number, now: number)
	local model = state.model
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local hidden = model:GetAttribute("Hidden") == true
	if state.dirty or hidden ~= state.hidden then
		state.hidden = hidden
		rebuild(state)
	end
	if hidden then
		return
	end
	local cf = body.CFrame
	local vel = body.AssemblyLinearVelocity
	local attr = model:GetAttribute("Mode")
	local mode: string = if type(attr) == "string" then attr else "Follow"
	-- his body's acceleration, smoothed against physics jitter
	if dt > 0 then
		local raw = cf:VectorToObjectSpace(vel - state.lastVel) / dt
		state.accel = state.accel:Lerp(raw, math.min(1, dt * 6))
	end
	state.lastVel = vel
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local pointing = state.pointAt ~= nil and now < state.pointUntil
	local excited = if pointing then 1 else 0
	if not pointing and mode ~= "Swim" then
		local head = ownerHead(model)
		if head and (head - body.Position).Magnitude < 10 then
			excited = 0.45
		end
	end
	local wetness = model:GetAttribute("Wetness")
	local pose = BosunMotion.step(state.motion, {
		dt = dt,
		mode = mode,
		speed = speed,
		look = lookTarget(state, body, now, speed > 4),
		excited = excited,
		accel = state.accel,
		deckRoll = math.asin(math.clamp(cf.RightVector.Y, -1, 1)),
		deckPitch = math.asin(math.clamp(cf.LookVector.Y, -1, 1)),
		wetness = if type(wetness) == "number" then wetness else 0,
	})
	for name, list in state.motors do
		local transform = pose[name]
		if transform then
			for _, m in list do
				m.Transform = transform
			end
		end
	end
end

-- Point and bark -----------------------------------------------------------------------------------

local function onPoint(payload: any)
	if type(payload) ~= "table" or typeof(payload.dog) ~= "Instance" then
		return
	end
	local dog = payload.dog :: Instance
	if not dog:IsA("Model") then
		return
	end
	local body = dog:FindFirstChild("Body") :: BasePart?
	local direction = payload.direction
	if not body or typeof(direction) ~= "Vector3" then
		return
	end
	local from = payload.from
	local onCraft = false
	if
		dog:GetAttribute("Hidden") == true
		and typeof(from) == "Instance"
		and from:IsA("Model")
		and from.PrimaryPart
	then
		body = from.PrimaryPart
		onCraft = true
	end
	local serial = (active[dog] or 0) + 1
	active[dog] = serial

	track(dog)
	local state = dogs[dog]
	if state then
		state.pointAt = if typeof(payload.position) == "Vector3"
			then payload.position
			else body.Position + direction * 20
		state.pointUntil = os.clock() + SHOW_SECONDS
	end

	-- the head turn and arrow every sniff; the bark and bubble at most every BARK_GAP
	local now = os.clock()
	local bubble: BillboardGui? = nil
	if now - (lastBark[dog] or -math.huge) >= BARK_GAP then
		lastBark[dog] = now
		AudioController.play("Dog_Bark", body.Position, 1, rng:NextNumber(0.94, 1.06))
		local cam = Workspace.CurrentCamera
		if not cam or (cam.CFrame.Position - body.Position).Magnitude > BUBBLE_NEAR then
			local old = body:FindFirstChild("WoofBubble")
			if old then
				old:Destroy()
			end
			local flat = Vector3.new(direction.X, 0, direction.Z)
			bubble = makeBubble(
				body,
				if onCraft then (if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero) else nil
			)
		end
	end
	local arrow: Model? = if ReplicatedStorage:GetAttribute("UseMapWaypoints") == true
		then nil
		else makeArrow()
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > SHOW_SECONDS or not body.Parent or active[dog] ~= serial then
			connection:Disconnect()
			if arrow then
				arrow:Destroy()
			end
			if bubble then
				bubble:Destroy()
			end
			return
		end
		local target = payload.position
		local dir = direction
		if typeof(target) == "Vector3" then
			local flat = Vector3.new(target.X - body.Position.X, 0, target.Z - body.Position.Z)
			if flat.Magnitude > 1 then
				dir = flat.Unit
			end
		end
		if arrow then
			placeArrow(arrow, body.Position, dir, t)
		end
	end)
end

function DogController.Init()
	Net.event("DogPoint").OnClientEvent:Connect(onPoint)
end

function DogController.Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Bosun")
		folder.ChildAdded:Connect(track)
		folder.ChildRemoved:Connect(untrack)
		for _, child in folder:GetChildren() do
			track(child)
		end
	end)
	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		for model, state in dogs do
			if model.Parent then
				stepDog(state, dt, now)
			else
				untrack(model)
			end
		end
	end)
end

return DogController
