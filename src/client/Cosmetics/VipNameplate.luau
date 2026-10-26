--!strict
-- VipNameplate (RP-M5 E2, a CosmeticsController feature): the VIP Crew Card's gold nameplate.
-- Other players whose "Cos_Badge" is "Gold" get a restrained overhead name plate instead of the
-- default Roblox name: their display name in HudTheme pale brass on a dark slate strip with a
-- hairline brass edge and a small "VIP CREW" caption (no glow, no animation). Local only: the
-- default name display is hidden on this client while the plate shows, restored when it goes.
-- The local player sees no plate of their own.
--
--   VipNameplate.Start(ctx)
--   VipNameplate.attach(model, name) -> () -> ()   plate on any rig (smoke tests / review shots)
local Players = game:GetService("Players")

local AvatarCosmetics = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AvatarCosmetics")
)
local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))

local VipNameplate = {}

local MAX_DISTANCE = 70 -- studs; the default name shows to about 100
local PLATE = "VipNameplate"

local function build(head: BasePart, name: string): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = PLATE
	gui.Adornee = head
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = MAX_DISTANCE
	gui.Size = UDim2.fromScale(3.4, 1.0) -- studs: shrinks with distance like a real tag
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.ResetOnSpawn = false

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.fromScale(0.5, 1)
	strip.Size = UDim2.fromScale(1, 0.58)
	strip.BackgroundColor3 = HudTheme.Colors.panel
	strip.BackgroundTransparency = 0.35
	strip.BorderSizePixel = 0
	strip.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = strip
	local edge = Instance.new("UIStroke")
	edge.Color = HudTheme.Colors.gold
	edge.Thickness = 1.5
	edge.Transparency = 0.15
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = strip

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Font = HudTheme.HeaderFont
	label.TextScaled = true
	label.Text = name
	label.TextColor3 = HudTheme.Colors.gold
	label.TextStrokeTransparency = 0.75
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = strip

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.fromScale(0.5, 0)
	caption.Size = UDim2.fromScale(0.62, 0.38)
	caption.Font = HudTheme.BoldFont
	caption.TextScaled = true
	caption.Text = "VIP CREW"
	caption.TextColor3 = HudTheme.Colors.gold
	caption.TextTransparency = 0.1
	caption.TextStrokeTransparency = 0.8
	caption.Parent = gui
	return gui
end

function VipNameplate.attach(model: Model, name: string): () -> ()
	local head = model:FindFirstChild("Head")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not head or not head:IsA("BasePart") then
		return function() end
	end
	local old = head:FindFirstChild(PLATE)
	if old then
		old:Destroy()
	end
	local before = if hum then hum.DisplayDistanceType else nil
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local gui = build(head, name)
	gui.Parent = head
	return function()
		gui:Destroy()
		if hum and hum.Parent and before then
			hum.DisplayDistanceType = before
		end
	end
end

function VipNameplate.Start(ctx: any)
	local detach: { [Player]: () -> () } = {}

	local function refresh(p: Player)
		local d = detach[p]
		if d then
			detach[p] = nil
			d()
		end
		local character = p.Character
		if p == ctx.player or not character then
			return
		end
		if AvatarCosmetics.gold(ctx.equipped(p, "Badge")) then
			character:WaitForChild("Head", 10)
			if p.Character == character then
				detach[p] = VipNameplate.attach(character, p.DisplayName)
			end
		end
	end

	local function track(p: Player)
		if p == ctx.player then
			return
		end
		ctx.onEquipped(p, "Badge", function()
			refresh(p)
		end)
		p.CharacterAdded:Connect(function()
			task.defer(refresh, p)
		end)
		task.spawn(refresh, p)
	end

	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(p)
		detach[p] = nil
	end)
	for _, p in Players:GetPlayers() do
		track(p)
	end
end

return VipNameplate
