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
-- K14: a guide point while he rides hidden on the craft (payload.from = the craft) barks, pops the
-- bubble and shows the arrow from the craft instead of his hidden body.
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
local TREAT_SECONDS = 1.6 -- one happy spin after the daily challenge set (DogService.Treat)
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
	treatSerial: number,
	treatUntil: number,
	glanceDir: Vector3?,
	glanceUntil: number,
	nextGlance: number,
	connections: { RBXScriptConnection },
}

local active: { [Model]: number } = {}
local dogs: { [Model]: DogState } = {}
local lastBark: { [Model]: number } = {}
local rng = Random.new()

local function makeBubble(body: BasePart): BillboardGui
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "WoofBubble"
	bubble.Size = UDim2.fromOffset(84, 40)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
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
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Woof!"
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.TextColor3 = BUBBLE_TEXT
	label.Parent = frame
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
		treatSerial = tonumber(model:GetAttribute("Treat")) or 0,
		treatUntil = 0,
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
	table.insert(
		state.connections,
		model:GetAttributeChangedSignal("Treat"):Connect(function()
			local serial = tonumber(model:GetAttribute("Treat")) or 0
			if serial <= state.treatSerial then
				return
			end
			state.treatSerial = serial
			state.treatUntil = os.clock() + TREAT_SECONDS
			local body = model:FindFirstChild("Body") :: BasePart?
			if body then
				local old = body:FindFirstChild("WoofBubble")
				if old then
					old:Destroy()
				end
				local bubble = makeBubble(body)
				task.delay(TREAT_SECONDS + 0.6, function()
					if bubble.Parent then
						bubble:Destroy()
					end
				end)
			end
		end)
	)
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
	local treating = now < state.treatUntil
	local excited = if pointing or treating then 1 else 0
	if not pointing and not treating and mode ~= "Swim" then
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
	if treating then
		-- a hop and one full turn about the root pivot, easing in and out
		local p = math.clamp(1 - (state.treatUntil - now) / TREAT_SECONDS, 0, 1)
		local hop = 0.35 * math.sin(math.pi * p)
		pose.Root = CFrame.new(0, hop, 0) * CFrame.Angles(0, 2 * math.pi * p, 0) * pose.Root
	end
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
	if
		dog:GetAttribute("Hidden") == true
		and typeof(from) == "Instance"
		and from:IsA("Model")
		and from.PrimaryPart
	then
		body = from.PrimaryPart
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
			bubble = makeBubble(body)
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
