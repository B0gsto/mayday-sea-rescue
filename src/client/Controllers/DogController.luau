--!strict
-- DogController: Bosun's point-and-bark on the client (DogService fires DogPoint).
-- On each DogPoint: his head turns toward the victim (local NeckWeld.C0), a "Woof!" bubble pops
-- over his head and a small Waypoint Green arrow hovers beside him pointing the way.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local DogController = {}

local SHOW_SECONDS = 2.2
local MAX_HEAD_YAW = math.rad(75)
local ARROW_COLOR = Color3.fromHex("3EE07A") -- Waypoint Green: where to go (docs 05 section 3.2)
local BUBBLE_TEXT = Color3.fromHex("0A2A3B")

local active: { [Model]: number } = {}
local baseNeck: { [Weld]: CFrame } = {}

local function makeBubble(head: BasePart): BillboardGui
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "WoofBubble"
	bubble.Size = UDim2.fromOffset(110, 52)
	bubble.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
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
	bubble.Adornee = head
	bubble.Parent = head
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

local function onPoint(payload: any)
	if type(payload) ~= "table" or typeof(payload.dog) ~= "Instance" then
		return
	end
	local dog = payload.dog :: Instance
	if not dog:IsA("Model") then
		return
	end
	local body = dog:FindFirstChild("Body") :: BasePart?
	local head = dog:FindFirstChild("Head") :: BasePart?
	local neck = body and body:FindFirstChild("NeckWeld") :: Weld?
	local direction = payload.direction
	if not body or not head or typeof(direction) ~= "Vector3" then
		return
	end
	local serial = (active[dog] or 0) + 1
	active[dog] = serial

	-- head turn, in the body's frame
	if neck then
		local base = baseNeck[neck] or neck.C0
		baseNeck[neck] = base
		local localDir = body.CFrame:VectorToObjectSpace(direction)
		local yaw = math.clamp(math.atan2(-localDir.X, -localDir.Z), -MAX_HEAD_YAW, MAX_HEAD_YAW)
		local turned = base * CFrame.Angles(math.rad(12), yaw, 0)
		TweenService:Create(neck, TweenInfo.new(0.2, Enum.EasingStyle.Back), { C0 = turned }):Play()
		task.delay(SHOW_SECONDS, function()
			if active[dog] == serial and neck.Parent then
				TweenService:Create(neck, TweenInfo.new(0.4), { C0 = base }):Play()
			end
		end)
	end

	local old = head:FindFirstChild("WoofBubble")
	if old then
		old:Destroy()
	end
	local bubble = makeBubble(head)
	local arrow = makeArrow()
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > SHOW_SECONDS or not body.Parent or active[dog] ~= serial then
			connection:Disconnect()
			arrow:Destroy()
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
		placeArrow(arrow, body.Position, dir, t)
	end)
end

function DogController.Init()
	Net.event("DogPoint").OnClientEvent:Connect(onPoint)
end

function DogController.Start() end

return DogController
