--!strict
-- TouchDriveController (owner 2026-10-31, on a phone: "make buttons for left, right, cause when you want to turn,
-- it is awkward"). On a touch device (Layout.device), while the local player sits in a craft's DriverSeat, the
-- stock thumbstick and jump button hide (GuiService.TouchControlsEnabled) and a drive pad takes their corners
-- (HudLayout regions "steer" and "drive", sizes mt.pad):
--   steer (left thumb)   LEFT, RIGHT: held = full lock; step off above LEFT (VehicleExitController.StepOff)
--   drive (right thumb)  GO (throttle) in the corner, BRAKE (brake, then reverse) left of it, and a small column:
--                        approach on boats (the slow helm, Z on desktop: ApproachMode) or rise over dive (heli, sub)
-- BoatController, HeliController and SubController add throttle() / steer() / lift() to their keyboard and
-- gamepad input; all three are 0 off touch, so those stay as they were. A press squashes the button and clicks.
-- Studio: Workspace attribute HudDevice = "Touch" shows the pad on a desktop (mouse presses, one at a time).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AudioController = require(script.Parent.AudioController)
local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HudLayout"))
local Layout = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Layout"))
local Style =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"):WaitForChild("Style"))
local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
)
local VehicleExitController = require(script.Parent.VehicleExitController)

local ART = UiImages.Pad
-- the sprites' box is 244 x 256 with the disc's centre at (122, 122): the disc fills the hit square, its rim overhangs
local ART_SCALE = 1.25
local ART_ANCHOR = Vector2.new(0.5, 122 / 256)

local TouchDriveController = {}

local player = Players.LocalPlayer
local rng = Random.new()
local presses: { [string]: { [InputObject]: boolean } } = {}
local buttons: { [string]: Frame } = {}
local wasHeld: { [string]: boolean } = {}
local regions: { Frame } = {}
local craft: Model? = nil -- the craft whose DriverSeat we drive with the pad
local hidStock = false

local function held(key: string): boolean
	local set = presses[key]
	if not set then
		return false
	end
	for input in set do
		local st = input.UserInputState
		if st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
			set[input] = nil
		end
	end
	return next(set) ~= nil
end

local function axis(plus: string, minus: string): number
	return (if held(plus) then 1 else 0) - (if held(minus) then 1 else 0)
end

-- -1..1 throttle from GO / BRAKE, 0 off touch.
function TouchDriveController.throttle(): number
	return if craft then axis("go", "brake") else 0
end

-- -1..1 steer (+ = right, like VehicleSeat.SteerFloat), 0 off touch.
function TouchDriveController.steer(): number
	return if craft then axis("right", "left") else 0
end

-- -1..1 climb / rise (+) or descend / dive (-), 0 off touch.
function TouchDriveController.lift(): number
	return if craft then axis("up", "down") else 0
end

-- True when the pad replaces the stock touch controls on this device: no CAS touch buttons then.
function TouchDriveController.on(): boolean
	return Layout.device() == "Touch"
end

local function tap(key: string)
	local model = craft
	if key == "exit" then
		VehicleExitController.StepOff()
	elseif key == "slow" and model then
		-- local attribute: this client simulates the hull, so the governor runs here (BoatController's Z)
		model:SetAttribute("ApproachMode", not (model:GetAttribute("ApproachMode") == true))
	end
end

local function feel(key: string, down: boolean)
	local b = buttons[key]
	local art = b and b:FindFirstChild("Art") :: ImageLabel?
	local sc = art and art:FindFirstChildOfClass("UIScale")
	if not (art and sc) then
		return
	end
	if down then
		TweenService:Create(sc, TweenInfo.new(0.06), { Scale = 0.88 }):Play()
		art.ImageColor3 = Color3.fromRGB(215, 215, 215)
		AudioController.play("UI_Click", nil, 0.7, rng:NextNumber(0.97, 1.03))
	else
		TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		art.ImageColor3 = Color3.new(1, 1, 1)
	end
end

local function button(key: string, parent: Frame): Frame
	local hit = Instance.new("Frame")
	hit.Name = key
	hit.BackgroundTransparency = 1
	hit.Active = true -- sinks the touch: no camera drag from the pad
	hit.Parent = parent
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Image = ART[key]
	art.ScaleType = Enum.ScaleType.Fit
	art.AnchorPoint = ART_ANCHOR
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(ART_SCALE, ART_SCALE * 256 / 244)
	Instance.new("UIScale").Parent = art
	art.Parent = hit
	presses[key] = {}
	hit.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if
			craft
			and input.UserInputState == Enum.UserInputState.Begin
			and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1)
		then
			presses[key][input] = true
			tap(key)
		end
	end)
	buttons[key] = hit
	return hit
end

-- Sizes and places the buttons in their regions (du) from the metrics.
local function place(mt: Layout.Metrics)
	local p, g = mt.pad, HudLayout.PAD_GAP
	local function put(key: string, size: number, anchor: Vector2, pos: UDim2)
		local b = buttons[key]
		b.Size = UDim2.fromOffset(size, size)
		b.AnchorPoint = anchor
		b.Position = pos
	end
	put("left", p.steer, Vector2.new(0, 1), UDim2.fromScale(0, 1))
	put("right", p.steer, Vector2.new(1, 1), UDim2.fromScale(1, 1))
	put("exit", p.small, Vector2.new(0.5, 0), UDim2.fromOffset(p.steer / 2, 0))
	put("go", p.go, Vector2.new(1, 1), UDim2.fromScale(1, 1))
	-- brake and approach centred on GO's height, the rise / dive column on the bottom
	local function mid(size: number): number
		return -(p.go - size) / 2
	end
	put("brake", p.brake, Vector2.new(1, 1), UDim2.new(1, -(p.go + g), 1, mid(p.brake)))
	put("slow", p.small, Vector2.new(0, 1), UDim2.new(0, 0, 1, mid(p.small)))
	put("down", p.small, Vector2.new(0, 1), UDim2.fromScale(0, 1))
	put("up", p.small, Vector2.new(0, 1), UDim2.new(0, 0, 1, -(p.small + g)))
end

local function setCraft(model: Model?, kind: string?)
	if model == craft then
		return
	end
	craft = model
	for _, set in presses do
		table.clear(set)
	end
	-- the stock thumbstick and jump button: off while the pad drives, back when you step off (only if we hid them)
	if model and GuiService.TouchControlsEnabled then
		GuiService.TouchControlsEnabled = false
		hidStock = true
	elseif not model and hidStock then
		GuiService.TouchControlsEnabled = true
		hidStock = false
	end
	if model then
		buttons.slow.Visible = kind == "boat"
		buttons.up.Visible = kind ~= "boat"
		buttons.down.Visible = kind ~= "boat"
	end
	for _, r in regions do
		local root = r:FindFirstChild("Pad") :: Frame
		Style.pop(root, model ~= nil)
	end
end

-- The craft the local player drives (DriverSeat of a VehicleId model) and its kind, else nil.
local function driven(): (Model?, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local model = seat and seat.Name == "DriverSeat" and seat.Parent
	if not (model and model:IsA("Model") and model:GetAttribute("VehicleId") ~= nil) then
		return nil, nil
	end
	local kind = if model:HasTag("Heli")
		then "heli"
		elseif model:GetAttribute("Sub") == true then "sub"
		else "boat"
	return model, kind
end

local function step()
	local model, kind = driven()
	setCraft(if TouchDriveController.on() then model else nil, kind)
	for key in buttons do
		local h = held(key)
		if h ~= (wasHeld[key] == true) then
			wasHeld[key] = h
			feel(key, h)
		end
	end
	if craft then
		-- step off: never in the cold open (VehicleExitController ignores it), dimmed while a heli is airborne
		buttons.exit.Visible = player:GetAttribute("ColdOpenDone") == true
		local art = buttons.exit:FindFirstChild("Art") :: ImageLabel
		art.ImageTransparency = if craft:GetAttribute("Airborne") == true then 0.5 else 0
		-- approach on: a steady yellow ring round the turtle (never a flash)
		local ring = buttons.slow:FindFirstChild("On") :: Frame
		ring.Visible = craft:GetAttribute("ApproachMode") == true
	end
end

function TouchDriveController.Init() end

function TouchDriveController.Start()
	-- REV2: a notification or home swipe mid-press may never end the touch: drop every hold
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(presses)
	end)
	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchDrive"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	local KEYS: { [string]: { string } } = {
		steer = { "left", "right", "exit" },
		drive = { "go", "brake", "slow", "up", "down" },
	}
	for name, keys in KEYS do
		local region = Layout.region(gui, name :: Layout.RegionName)
		local root = Instance.new("Frame")
		root.Name = "Pad"
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromScale(1, 1)
		root.Visible = false
		root.Parent = region
		table.insert(regions, region)
		for _, key in keys do
			button(key, root)
		end
	end
	local ring = Instance.new("Frame")
	ring.Name = "On"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1.24, 1.24) -- just outside the sticker's white rim
	ring.Visible = false
	ring.Parent = buttons.slow
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 228, 92)
	stroke.Thickness = 4
	stroke.Parent = ring
	place(Layout.current())
	Layout.onMetrics(place)
	gui.Parent = player:WaitForChild("PlayerGui")
	RunService.Heartbeat:Connect(step)
end

return TouchDriveController
