--!strict
-- TabletCue: the build tablet's prompt in the UI kit look, in place of Roblox's grey "Tablet / Build" bubble (owner
-- 2026-10-31, first login on a phone: the grey bubble was the only cue). Over the tablet: a green kit pill with the
-- device's glyph (the tap hand on touch, an E keycap, the gamepad's X) and "Build"; tapping or clicking it opens the
-- tablet. While the tablet is the tutorial's goal (setGoal) the green build arrow (art/source/ui/build_arrow.svg)
-- bobs over the pill. It pops in once when the prompt shows and goes with it; the prompt keeps E / ButtonX.
--   TabletCue.mount(prompt, onOpen) -> { setGoal(on), shown() }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
) :: any

local UI = script.Parent
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Layout = require(UI:WaitForChild("Layout"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Theme = require(UI:WaitForChild("Kit"):WaitForChild("Theme"))

export type Cue = { setGoal: (on: boolean) -> (), shown: () -> boolean }

local TabletCue = {}

-- design units (x Layout scale: 0.7 on a phone): the pill 168 x 64, the arrow 64 wide
local PILL = Vector2.new(168, 64)
local ARROW_W = 64
local ARROW_H = math.round(ARROW_W * 516 / 392) -- the sprite's 392 x 516 px
local BOB = 6

function TabletCue.mount(prompt: ProximityPrompt, onOpen: () -> ()): Cue
	prompt.Style = Enum.ProximityPromptStyle.Custom
	local tablet = prompt.Parent :: BasePart

	local bb = Instance.new("BillboardGui")
	bb.Name = "TabletCue"
	bb.Adornee = tablet
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0) -- over the 4.2-stud screen's top edge
	bb.LightInfluence = 0
	bb.MaxDistance = 200
	bb.ResetOnSpawn = false
	bb.Enabled = false
	bb.Active = true -- the pill is a button (a BillboardGui only takes input under PlayerGui)

	-- a du canvas: sizes below are design units, the UIScale turns them into the device's px like the HUD
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Parent = box

	local arrow = Instance.new("ImageLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Image = UiImages.Markers.BuildArrow
	arrow.ScaleType = Enum.ScaleType.Fit
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.Visible = false
	arrow.Parent = box

	local button = Style.button(box, UDim2.fromOffset(PILL.X, PILL.Y))
	button.Name = "Pill"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.5, 1)
	local _, face =
		Style.block(button, Style.grad("buy"), { radius = 18, lip = 6, border = 4, shadow = true })
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = face
	local list = Style.list(row, true, 8)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.Size = UDim2.fromOffset(50, 50) -- 35 pt on a phone
	glyph.BackgroundColor3 = Color3.new(1, 1, 1)
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.LayoutOrder = 1
	glyph.Parent = row
	local capCorner = Style.corner(glyph, 10)
	local capStroke = Style.stroke(glyph, 3, true)
	local key = Style.label(glyph, "E", Theme.Text.heading, true) -- the keycap's letter, on the white cap
	key.Name = "Key"
	local label = Style.label(row, "Build", Theme.Text.button) -- 22 pt on a phone
	label.LayoutOrder = 2
	label.TextWrapped = false
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromScale(0, 1)
	Style.press(button, onOpen, 18)

	local goal = false
	local up = false

	local function device(): string
		return if Layout.current().touch then "Touch" else InputGlyph.device()
	end

	local function layout()
		local s = Layout.current().scale
		local h = PILL.Y + (if goal then ARROW_H + BOB * 2 else 0)
		scale.Scale = s
		box.Size = UDim2.fromOffset(PILL.X, h)
		bb.Size = UDim2.fromOffset(math.round(PILL.X * s), math.round(h * s))
		bb.SizeOffset = Vector2.new(0, 0.5) -- the gui's bottom (the pill) sits on the spot
		arrow.Size = UDim2.fromOffset(ARROW_W, ARROW_H)
		arrow.Visible = goal
		local d = device()
		key.Visible = d == "Keyboard"
		capCorner.Parent = if d == "Keyboard" then glyph else nil
		capStroke.Parent = if d == "Keyboard" then glyph else nil
		glyph.BackgroundTransparency = if d == "Keyboard" then 0 else 1
		key.Text = prompt.KeyboardKeyCode.Name
		glyph.Image = if d == "Touch"
			then UiImages.Markers.TapHand
			elseif d == "Gamepad" then UserInputService:GetImageForKeyCode(
				prompt.GamepadKeyCode
			)
			else ""
	end
	layout()
	Layout.onMetrics(layout)
	InputGlyph.onDevice(layout)

	local function show(on: boolean)
		if on == up then
			return
		end
		up = on
		bb.Enabled = on
		bb.Parent = if on then Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") else nil
		if on then
			Style.pop(button, true) -- one pop, never a loop
		end
	end
	prompt.PromptShown:Connect(function()
		show(true)
	end)
	prompt.PromptHidden:Connect(function()
		show(false)
	end)
	local bob = RunService.Heartbeat:Connect(function()
		if up and goal then -- a slow bob like the beacon's, never a flash
			arrow.Position = UDim2.new(0.5, 0, 0, BOB + math.sin(os.clock() * 1.8) * BOB)
		end
	end)
	tablet.Destroying:Connect(
		function() -- the station streams out: the stream-in makes a new prompt and cue
			bob:Disconnect()
			bb:Destroy()
		end
	)

	return {
		setGoal = function(on: boolean)
			if on ~= goal then
				goal = on
				layout()
			end
		end,
		shown = function(): boolean
			return up and goal
		end,
	}
end

return TabletCue
