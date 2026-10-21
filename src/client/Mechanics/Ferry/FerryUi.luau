--!strict
-- Shared client helpers for the ferry mechanics (scene_command, triage, hull_knock, air_pocket):
-- a cleanup bin, small UI builders in the HudTheme palette, subtitles, positional sound with a
-- visual ripple (docs 09 section 2.7: every sound cue has a ripple for players with sound off),
-- key bindings, and the Viewmodel hands hook (pcall: the camera stream's API may not exist yet).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AudioConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AudioConfig")
)
local HudTheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local InputGlyph =
	require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("InputGlyph"))
local RadioFormat =
	require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("RadioFormat"))
local VoiceCast = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("VoiceCast"))
local VoiceTTS =
	require(script.Parent.Parent.Parent:WaitForChild("Controllers"):WaitForChild("VoiceTTS"))

local FerryUi = {}
FerryUi.Theme = HudTheme

-- Ferry sound cues. Ids are public Pro Sound Effects library clips (verified with
-- tools/audio-search.py verify); the rest come from AudioConfig. No placeholders are left.
FerryUi.Sounds = {
	knock = "rbxassetid://9116658943", -- Metal Hit Steel Plate Hit Slapped 15: a gloved fist on plate
	replyTap = "rbxassetid://9125691302", -- Metal Taps Very Light Clinking Hits On Sheet: taps in the hull
	hullCreak = "rbxassetid://9126147889", -- Underwater Sheet Metal Bending Whining Creak
	radioClick = AudioConfig.id("Radio_Key"), -- squelch and PTT click
	breathIn = "rbxassetid://9113585946", -- Breath Exhale 15, a calm breath (regulator stand-in)
	bubbles = "rbxassetid://9125409816", -- Bubbles Small Underwater Above Water Quality
	lineTug = "rbxassetid://9118714215", -- Rope Grab 1: a rope snapping taut, soft
	underwaterBed = AudioConfig.id("Under_Ambience"), -- calm, warm underwater ambience
	tagSnap = AudioConfig.id("UI_Click"), -- the triage band clicking shut
	tabletTap = AudioConfig.id("UI_Prompt"),
}

---------------------------------------------------------------- cleanup bin

export type Bin = { add: (any) -> any, clean: () -> () }

function FerryUi.bin(): Bin
	local items: { any } = {}
	local self = {} :: Bin
	function self.add(x: any): any
		table.insert(items, x)
		return x
	end
	function self.clean()
		for i = #items, 1, -1 do
			local x = items[i]
			local t = typeof(x)
			if t == "Instance" then
				pcall(function()
					x:Destroy()
				end)
			elseif t == "RBXScriptConnection" then
				x:Disconnect()
			elseif t == "function" then
				pcall(x)
			elseif t == "thread" then
				pcall(task.cancel, x)
			end
		end
		table.clear(items)
	end
	return self
end

---------------------------------------------------------------- UI builders

function FerryUi.screen(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets -- keep panels and touch buttons out of notches
	gui.DisplayOrder = order or 22
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function FerryUi.frame(
	parent: Instance,
	size: UDim2,
	pos: UDim2,
	colour: Color3?,
	transparency: number?
): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = colour or HudTheme.Colors.panel
	f.BackgroundTransparency = transparency or HudTheme.PanelTransparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function FerryUi.corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or HudTheme.Corner)
	c.Parent = parent
end

function FerryUi.stroke(parent: Instance, colour: Color3, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function FerryUi.text(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	textSize: number?,
	colour: Color3?,
	font: Enum.Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Text = text
	l.TextWrapped = true
	l.TextSize = textSize or 18
	l.TextColor3 = colour or HudTheme.Colors.text
	l.Font = font or HudTheme.BodyFont
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Parent = parent
	return l
end

function FerryUi.button(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	colour: Color3?,
	onClick: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.AutoButtonColor = true
	b.BackgroundColor3 = colour or HudTheme.Colors.panelLight
	b.Font = HudTheme.BoldFont
	b.TextColor3 = HudTheme.Colors.text
	b.TextSize = 18
	b.TextWrapped = true
	b.Text = text
	b.Parent = parent
	FerryUi.corner(b, 10)
	b.Activated:Connect(onClick)
	return b
end

-- Bottom-centre caption, the subtitle for every voice and sound cue.
-- "Quoted" speech is voiced: by `cast`, else the name before it ('Mara: "..."'), else a passenger.
function FerryUi.subtitle(gui: Instance, text: string, seconds: number?, cast: string?)
	if string.find(text, '"') then
		local who = string.match(text, '^([^"%[]*)"') or ""
		VoiceTTS.speak(text, cast or VoiceCast.castFor(who, "CASUALTY_F"), { channel = "ferry" })
	end
	local old = gui:FindFirstChild("FerrySubtitle")
	if old then
		old:Destroy()
	end
	local l = Instance.new("TextLabel")
	l.Name = "FerrySubtitle"
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.new(0.5, 0, 1, -40)
	l.Size = UDim2.fromOffset(720, 34)
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.45
	l.TextColor3 = HudTheme.Colors.text
	l.Font = HudTheme.BodyFont
	l.TextSize = 20
	l.TextWrapped = true
	l.Text = RadioFormat.capLine(text, 6) -- six words, like the radio
	l.ZIndex = 50
	l.Parent = gui
	FerryUi.corner(l, 8)
	task.delay(seconds or 3.5, function()
		if l.Parent then
			TweenService
				:Create(l, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
				:Play()
			task.wait(0.45)
			l:Destroy()
		end
	end)
end

---------------------------------------------------------------- sound and ripple

-- Plays a sound at a world position (3D, rolls off with distance) or flat when `at` is nil.
function FerryUi.sound(id: string, at: Vector3?, volume: number?, speed: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.8
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 120
	s.RollOffMinDistance = 6
	if at then
		local p = Instance.new("Part")
		p.Name = "FerrySoundEmitter"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(at)
		p.Parent = workspace
		s.Parent = p
		task.delay(6, function()
			p:Destroy()
		end)
	else
		s.Parent = workspace.CurrentCamera
		task.delay(6, function()
			s:Destroy()
		end)
	end
	s:Play()
	return s
end

-- A ring that grows and fades at a world position: the visual twin of a sound cue.
function FerryUi.ripple(at: Vector3, strength: number, colour: Color3?)
	if strength <= 0 then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "FerryRipple"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromScale(2, 2)
	bb.Parent = anchor
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.2, 0.2)
	ring.BackgroundTransparency = 1
	ring.Parent = bb
	FerryUi.corner(ring, 999)
	local s = Instance.new("UIStroke")
	s.Color = colour or Color3.fromRGB(190, 235, 255)
	s.Thickness = 2 + 3 * strength
	s.Transparency = 1 - math.clamp(strength, 0.2, 1)
	s.Parent = ring
	local grow = 4 + 8 * strength
	bb.Size = UDim2.fromScale(grow, grow)
	TweenService
		:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 1) })
		:Play()
	TweenService:Create(s, TweenInfo.new(1.1), { Transparency = 1 }):Play()
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

---------------------------------------------------------------- hands (Viewmodel)

local viewmodel: any = nil
local searched = false

-- Ferry action names mapped onto the Viewmodel's clips (src/client/Camera/ViewmodelActions.luau:
-- throw, haul, grab, radio, cpr, knock, point, steer, phone). `false` = no hands clip (camera moment).
-- When the camera stream adds dedicated clips, point these at them.
FerryUi.ActionAlias = {
	hull_knock = "knock",
	hull_mark_chalk = "point",
	line_pull = "haul",
	radio_ptt = "radio",
	tablet_raise = "phone",
	tablet_tap = "phone",
	tablet_drag = "phone",
	triage_walk_ask = "point",
	triage_airway = "grab",
	triage_shoulder_tap = "grab",
	triage_count_breaths = "point",
	triage_cap_refill = "grab",
	triage_attach_band = "grab",
	calm_hand_on_shoulder = "grab",
	mask_fit_1 = "grab",
	mask_fit_2 = "grab",
	mask_fit_3 = "grab",
	dive_descend = false,
	surface_in_pocket = false,
	surface_handover = "haul",
} :: { [string]: string | boolean }

-- Plays a first-person hands action through the camera stream's Viewmodel API when it exists.
function FerryUi.playAction(ferryName: string)
	local alias = FerryUi.ActionAlias[ferryName]
	if alias == false then
		return
	end
	local name = if type(alias) == "string" then alias else ferryName
	if not searched then
		searched = true
		local client = script.Parent.Parent.Parent
		local mod = client:FindFirstChild("Viewmodel", true)
		if mod and mod:IsA("ModuleScript") then
			local ok, m = pcall(require, mod)
			if ok then
				viewmodel = m
			end
		end
	end
	if viewmodel and type(viewmodel.playAction) == "function" then
		pcall(viewmodel.playAction, name)
	end
end

---------------------------------------------------------------- input

-- A key label for the device in use: kb on keyboard and mouse, pad on gamepad, "" on touch (the
-- on-screen button is the prompt). Strings, so mouse buttons and digits read right ("Click", "1").
function FerryUi.keyLabel(kb: string, pad: string): string
	local d = InputGlyph.device()
	return if d == "Gamepad" then pad elseif d == "Keyboard" then kb else ""
end

-- Gamepad players drive a panel with Roblox UI navigation (D-pad / stick moves, A presses),
-- starting on `first`. Mouse players keep their pointer free while `first` (a Modal button) shows.
function FerryUi.focus(first: GuiButton)
	first.Modal = true
	if InputGlyph.device() == "Gamepad" then
		GuiService.SelectedObject = first
	end
end

-- True when on-screen buttons are the way in (touch is the preferred input).
function FerryUi.isTouch(): boolean
	return InputGlyph.device() == "Touch"
		or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
end

-- Binds keys (and gamepad buttons) to handlers; returns the connection. Ignores typing in chat.
function FerryUi.keys(map: { [Enum.KeyCode]: () -> () }): RBXScriptConnection
	return UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local fn = map[input.KeyCode]
		if fn then
			fn()
		end
	end)
end

export type Hold = {
	button: TextButton, -- the touch / mouse target and the glyph
	held: () -> boolean,
	setFill: (progress: number, colour: Color3?) -> (),
	idle: (seconds: number) -> (), -- after ~10 s without a hold the glyph pulses (the world helps)
}

-- A hold action: E on keyboard, X on gamepad, or press and hold the button (touch / mouse).
-- The button fills with `setFill` as the held work progresses.
function FerryUi.hold(bin: Bin, parent: Instance, pos: UDim2): Hold
	local down: { [any]: boolean } = {}
	local b = FerryUi.button(parent, "", UDim2.fromOffset(150, 64), pos, nil, function() end)
	b.ClipsDescendants = true
	local fill = FerryUi.frame(b, UDim2.fromScale(0, 1), UDim2.new(), HudTheme.Colors.ready, 0.35)
	local label = FerryUi.text(
		b,
		`{FerryUi.keyLabel("E", "X")}  Hold`,
		UDim2.fromScale(1, 1),
		UDim2.new(),
		20,
		nil,
		HudTheme.BoldFont
	)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 2
	local function isPointer(i: InputObject): boolean
		return i.UserInputType == Enum.UserInputType.Touch
			or i.UserInputType == Enum.UserInputType.MouseButton1
	end
	bin.add(b.InputBegan:Connect(function(i: InputObject)
		if isPointer(i) then
			down[i.UserInputType] = true
		end
	end))
	bin.add(UserInputService.InputBegan:Connect(function(i: InputObject, processed: boolean)
		if not processed and (i.KeyCode == Enum.KeyCode.E or i.KeyCode == Enum.KeyCode.ButtonX) then
			down[i.KeyCode] = true
		end
	end))
	bin.add(UserInputService.InputEnded:Connect(function(i: InputObject)
		down[i.KeyCode] = nil
		if isPointer(i) then
			down[i.UserInputType] = nil
		end
	end))
	return {
		button = b,
		held = function()
			return next(down) ~= nil
		end,
		setFill = function(progress: number, colour: Color3?)
			fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
			fill.BackgroundColor3 = colour or HudTheme.Colors.ready
		end,
		idle = function(seconds: number)
			local on = seconds > 10 and seconds % 1 < 0.5
			b.BackgroundColor3 = if on then HudTheme.Colors.accent else HudTheme.Colors.panelLight
		end,
	}
end

---------------------------------------------------------------- world

-- The Gale Queen RescueService built for this operation (Model with CallId = opId; C2 art or the greybox).
function FerryUi.findFerry(opId: string): Model?
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "GaleQueen" and d:GetAttribute("CallId") == opId then
			return d
		end
	end
	return nil
end

-- World position of a named mark on this operation's ferry (an Attachment such as "AirPocket", "HullAxis" or
-- "ATT_Knock_03"), nil on the greybox or before her art has loaded.
function FerryUi.ferryPoint(opId: string, name: string): Vector3?
	local ferry = FerryUi.findFerry(opId)
	local mark = ferry and ferry:FindFirstChild(name, true)
	return if mark and mark:IsA("Attachment") then mark.WorldPosition else nil
end

function FerryUi.character(): (Model?, BasePart?)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return char, if root and root:IsA("BasePart") then root else nil
end

-- The shared scene board (Ops_Board) starts with the first ferry mechanic that loads.
task.defer(function()
	local ok, err = pcall(function()
		local BoardView = script.Parent:WaitForChild("BoardView") :: ModuleScript
		((require :: any)(BoardView) :: any).start()
	end)
	if not ok then
		warn("[FerryUi] BoardView:", err)
	end
end)

return FerryUi
