--!strict
-- PromptCueController: every ProximityPrompt in the house kit look, in place of Roblox's grey bubble (owner
-- 2026-11-01: the survivor's grey "Q Info" looked off-style). Each prompt turns Style = Custom here; when one shows,
-- a green kit pill with a white sticker rim floats on it: the device glyph (an E keycap, the gamepad's button, the
-- tap hand on touch), a yellow hold ring round the glyph for HoldDuration > 0, and the 1-3 word ActionText. The
-- pill is the touch / mouse target (InputHoldBegin / End); keys and gamepad buttons stay Roblox's own prompt input.
-- A prompt with the OwnCue attribute draws itself (TabletCue).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local UiImages = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
) :: any

local UI = script.Parent.Parent:WaitForChild("UI")
local HoldRing = require(UI:WaitForChild("HoldRing"))
local Layout = require(UI:WaitForChild("Layout"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Theme = require(UI:WaitForChild("Kit"):WaitForChild("Theme"))

-- design units (x Layout scale: 0.7 on a phone): pill 72 tall (56 pt tap target with the rim), glyph 48 (34 pt)
-- in a 60 ring (the face is 66: the pill less its 6 lip)
local H = 72
local RING = 60
local GLYPH = 48
local RIM = 4
local PAD_L, GAP, PAD_R = 6, 8, 18
local TEXT = Theme.Text.button -- 22 pt on a phone

local PromptCueController = {}

local widths: { [string]: number } = {}
local function textWidth(text: string): number
	if not widths[text] then
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = Font.new(Theme.FONT)
		params.Size = TEXT
		params.Width = 2000
		local ok, size = pcall(TextService.GetTextBoundsAsync, TextService, params)
		widths[text] = if ok then math.ceil(size.X) + 4 else #text * TEXT * 0.62
	end
	return widths[text]
end

local function adornee(prompt: ProximityPrompt): Instance?
	local p = prompt.Parent
	if p and p:IsA("Model") then
		return p.PrimaryPart
	end
	return p
end

-- builds the cue; returns its teardown
local function show(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType): () -> ()
	local text = if prompt.ActionText ~= "" then prompt.ActionText else prompt.ObjectText
	local w = PAD_L + RING + GAP + textWidth(text) + PAD_R
	local s = Layout.current().scale

	local bb = Instance.new("BillboardGui")
	bb.Name = "PromptCue"
	bb.Adornee = adornee(prompt) :: any
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Active = true -- the pill is a button (a BillboardGui only takes input under PlayerGui)
	bb.Size = UDim2.fromOffset(math.round((w + RIM * 2) * s), math.round((H + RIM * 2) * s))

	local box = Instance.new("Frame") -- du canvas
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(w + RIM * 2, H + RIM * 2)
	box.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Scale = s
	scale.Parent = box

	local button = Style.button(box, UDim2.fromScale(1, 1))
	button.Selectable = false -- gamepads press the prompt's own button
	local rim = Instance.new("Frame") -- the white sticker rim round the chunky block
	rim.BackgroundColor3 = Color3.new(1, 1, 1)
	rim.Size = UDim2.fromScale(1, 1)
	Style.corner(rim, 18 + RIM)
	Style.stroke(rim, 3, true)
	rim.Parent = button
	local pill = Instance.new("Frame")
	pill.BackgroundTransparency = 1
	pill.Position = UDim2.fromOffset(RIM, RIM)
	pill.Size = UDim2.new(1, -RIM * 2, 1, -RIM * 2)
	pill.Parent = button
	local block, face = Style.block(pill, Style.grad("buy"), { radius = 18, lip = 6, border = 4 })

	local ringBox = Instance.new("Frame")
	ringBox.BackgroundTransparency = 1
	ringBox.AnchorPoint = Vector2.new(0, 0.5)
	ringBox.Position = UDim2.new(0, PAD_L, 0.5, 0)
	ringBox.Size = UDim2.fromOffset(RING, RING)
	ringBox.Parent = face
	local setRing = HoldRing.new(ringBox, 5, Theme.Colors.ring)
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromOffset(GLYPH, GLYPH)
	glyph.BackgroundTransparency = 1
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.Parent = ringBox
	if input == Enum.ProximityPromptInputType.Keyboard then
		glyph.BackgroundTransparency = 0
		glyph.BackgroundColor3 = Color3.new(1, 1, 1)
		Style.corner(glyph, 10)
		Style.stroke(glyph, 3, true)
		local key = prompt.KeyboardKeyCode.Name
		Style.label(glyph, key, if #key > 1 then Theme.Text.small else Theme.Text.heading, true).Name =
			"Key"
	elseif input == Enum.ProximityPromptInputType.Gamepad then
		glyph.Image = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)
	else
		glyph.Image = UiImages.Markers.TapHand
	end

	local label = Style.label(face, text, TEXT)
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = UDim2.fromOffset(PAD_L + RING + GAP, 0)
	label.Size = UDim2.new(1, -(PAD_L + RING + GAP), 1, 0)

	local conns: { RBXScriptConnection } = {}
	local holding = false
	local function release()
		if holding then
			holding = false
			prompt:InputHoldEnd()
		end
	end
	if prompt.ClickablePrompt then
		table.insert(
			conns,
			button.InputBegan:Connect(function(io: InputObject)
				local t = io.UserInputType
				if
					not holding
					and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1)
				then
					holding = true
					prompt:InputHoldBegin()
				end
			end)
		)
		table.insert(
			conns,
			button.InputEnded:Connect(function(io: InputObject)
				local t = io.UserInputType
				if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
					release()
				end
			end)
		)
	end
	local tick: RBXScriptConnection? = nil
	table.insert(
		conns,
		prompt.PromptButtonHoldBegan:Connect(function()
			if prompt.HoldDuration <= 0 then
				return
			end
			local t0 = os.clock()
			if tick then
				tick:Disconnect()
			end
			tick = RunService.Heartbeat:Connect(function()
				setRing((os.clock() - t0) / prompt.HoldDuration)
			end)
		end)
	)
	table.insert(
		conns,
		prompt.PromptButtonHoldEnded:Connect(function()
			if tick then
				tick:Disconnect()
				tick = nil
			end
			setRing(0)
		end)
	)

	-- a prompt you can't afford yet (the Upgrade Station) wears grey, not the green price colour
	local function tint()
		local grad = Style.grad(if prompt:GetAttribute("Grey") == true then "disabled" else "buy")
		Style.gradient(face, grad)
		local lip = block:FindFirstChild("Lip") :: Frame
		lip.BackgroundColor3 = Theme.shade(grad.bottom)
	end
	tint()
	table.insert(conns, prompt:GetAttributeChangedSignal("Grey"):Connect(tint))

	bb.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	Style.pop(button, true) -- one pop, never a loop
	table.insert(
		conns,
		RunService.Heartbeat:Connect(function()
			Layout.keepClear(bb) -- off the top HUD (the Next chip)
			local player = Players.LocalPlayer -- hidden under an open panel or the map (MERGE3 ADs)
			bb.Enabled = player:GetAttribute("MenuOpen") ~= true
				and player:GetAttribute("MapOpen") ~= true
		end)
	)

	return function()
		release()
		for _, c in conns do
			c:Disconnect()
		end
		if tick then
			tick:Disconnect()
		end
		Style.pop(button, false)
		task.delay(0.2, bb.Destroy, bb)
	end
end

function PromptCueController.Start()
	local function adopt(inst: Instance)
		if inst:IsA("ProximityPrompt") and inst.Style == Enum.ProximityPromptStyle.Default then
			inst.Style = Enum.ProximityPromptStyle.Custom -- client-side only: the server never sets Style
		end
	end
	workspace.DescendantAdded:Connect(adopt)
	for _, inst in workspace:GetDescendants() do
		adopt(inst)
	end

	local cues: { [ProximityPrompt]: (() -> ()) | false } = {} -- false: still measuring its text
	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType)
			if prompt:GetAttribute("OwnCue") == true or cues[prompt] ~= nil then
				return
			end
			cues[prompt] = false
			local hide = show(prompt, input) -- may yield on the first measure of a label
			if cues[prompt] == false then
				cues[prompt] = hide
			else -- hidden (or shown again) while it measured
				hide()
			end
		end
	)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local hide = cues[prompt]
		cues[prompt] = nil
		if type(hide) == "function" then
			hide()
		end
	end)
end

return PromptCueController
