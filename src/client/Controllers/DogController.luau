--!strict
-- DogController: Bosun's body language and his point-and-bark, on the client.
--
-- Motion: every dog in Workspace.Bosun (DogService) is the rigid M_Chr_Bosun model rigged with Motor6Ds
-- (Root, Neck, Hips, Ruff, Tail) on an invisible root the server moves. Each frame (PreSimulation) this
-- writes their Transforms from Shared.Dog.BosunMotion: breathing, the walk's bob and pitch while he
-- follows, sitting when he stops (and while he waits ashore for a jet ski), his head turning to his
-- owner, a casualty or a passing glance, a tail wag (carried high when excited or swimming, low when he
-- sits or is tired, tucked when wet; a rear wiggle on the old model without a Tail joint), a float and
-- paddle when he swims, a shake when he climbs out, and a lean into the boat's motion aboard. Inputs
-- come from the replicated Mode and Wetness attributes and the root's velocity. Transforms are local; the server owns position.
-- LOD: LOD1 / LOD2 copies start hidden; the client shows one by camera distance (local Transparency).
-- The harness stays hidden while the model attribute HideHarness is set (DogService: a life jacket on).
--
-- DogPoint (DogService): his head turns toward the victim and the tail goes, a "Woof!" bubble pops
-- over his head and a small Waypoint Green arrow hovers beside him pointing the way. The arrow is
-- skipped while ReplicatedStorage attribute UseMapWaypoints is true (the map shows the casualty).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BosunMotion = require(Shared:WaitForChild("Dog"):WaitForChild("BosunMotion"))
local Net = require(Shared:WaitForChild("Net"))

local DogController = {}

local SHOW_SECONDS = 2.2
local OWNER_LOOK_RANGE = 28 -- studs: he watches his owner inside this
local ARROW_COLOR = Color3.fromHex("3EE07A") -- Waypoint Green: where to go (docs 05 section 3.2)
local BUBBLE_TEXT = Color3.fromHex("0A2A3B")
local JOINTS = { "Root", "Neck", "Hips", "Ruff", "Tail" }

type DogState = {
	model: Model,
	motion: BosunMotion.State,
	motors: { [string]: { Motor6D } },
	lods: { [number]: { BasePart } },
	lod: number?,
	dirty: boolean,
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
local rng = Random.new()

local function makeBubble(body: BasePart): BillboardGui
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "WoofBubble"
	bubble.Size = UDim2.fromOffset(110, 52)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 1.4, 0)
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
	label.TextSize = 28
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
	for _, name in JOINTS do
		motors[name] = {}
	end
	local lods: { [number]: { BasePart } } = {}
	for _, d in state.model:GetDescendants() do
		if d:IsA("Motor6D") and motors[d.Name] then
			table.insert(motors[d.Name], d)
		elseif d:IsA("Model") then
			local lod = d:GetAttribute("BosunLod")
			if type(lod) == "number" then
				local parts = {}
				local hideHarness = state.model:GetAttribute("HideHarness") == true -- a life jacket on
				for _, p in d:GetDescendants() do
					if p:IsA("BasePart") then
						if hideHarness and string.find(p.Name, "_Harness", 1, true) then
							p.Transparency = 1
						else
							table.insert(parts, p)
						end
					end
				end
				lods[lod] = parts
			end
		end
	end
	state.motors = motors
	state.lods = lods
	state.lod = nil -- re-apply visibility
end

local function track(model: Instance)
	if not model:IsA("Model") or dogs[model] then
		return
	end
	local state: DogState = {
		model = model,
		motion = BosunMotion.new(),
		motors = {},
		lods = {},
		lod = nil,
		dirty = true,
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
	table.insert(
		state.connections,
		model:GetAttributeChangedSignal("HideHarness"):Connect(markDirty)
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
end

-- LOD --------------------------------------------------------------------------------------------

local function applyLod(state: DogState, distance: number)
	local want = BosunMotion.lodFor(distance, state.lod)
	if not state.lods[want] then
		-- an LOD that didn't load: the nearest one that did
		for _, alt in { want - 1, want + 1, want - 2, want + 2 } do
			if state.lods[alt] then
				want = alt
				break
			end
		end
	end
	if want == state.lod or not state.lods[want] then
		return
	end
	state.lod = want
	for lod, parts in state.lods do
		local t = if lod == want then 0 else 1
		for _, p in parts do
			p.Transparency = t -- local only: the server never writes it after rigging
		end
	end
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

local function stepDog(state: DogState, dt: number, now: number, camera: Camera?)
	local model = state.model
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	if state.dirty then
		rebuild(state)
	end
	if camera then
		applyLod(state, (camera.CFrame.Position - body.Position).Magnitude)
	end
	local cf = body.CFrame
	local vel = body.AssemblyLinearVelocity
	local attr = model:GetAttribute("Mode")
	local mode: string = if type(attr) == "string" then attr else "Follow"
	-- the deck's acceleration (Ride: he is welded to the boat), smoothed against physics jitter
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
		tailJoint = state.motors.Tail ~= nil and #state.motors.Tail > 0,
	})
	for name, list in state.motors do
		local transform = (pose :: any)[name] :: CFrame?
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

	local old = body:FindFirstChild("WoofBubble")
	if old then
		old:Destroy()
	end
	local bubble = makeBubble(body)
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
			bubble:Destroy()
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
		local camera = Workspace.CurrentCamera
		for model, state in dogs do
			if model.Parent then
				stepDog(state, dt, now, camera)
			else
				untrack(model)
			end
		end
	end)
end

return DogController
