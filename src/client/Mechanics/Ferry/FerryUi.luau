--!strict
-- Shared client helpers for the ferry mechanics (scene_command, triage, hull_knock, air_pocket):
-- a cleanup bin, small UI builders in the HudTheme palette, subtitles, positional sound with a
-- visual ripple (docs 09 section 2.7: every sound cue has a ripple for players with sound off),
-- key bindings, and the Viewmodel hands hook (pcall: the camera stream's API may not exist yet).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudTheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))

local FerryUi = {}
FerryUi.Theme = HudTheme

-- Placeholder sound ids (swap for the real uploads; a 0 id plays nothing but the ripple shows).
FerryUi.Sounds = {
	knock = "rbxassetid://0", -- a gloved fist on steel plate, dull and short
	replyTap = "rbxassetid://0", -- muffled metal taps from inside the hull
	hullCreak = "rbxassetid://0",
	radioClick = "rbxassetid://0", -- squelch and PTT click
	breathIn = "rbxassetid://0", -- regulator inhale, slow and calm
	bubbles = "rbxassetid://0", -- exhale bubbles
	lineTug = "rbxassetid://0", -- a rope snapping taut, soft
	underwaterBed = "rbxassetid://0", -- calm, warm underwater ambience (never scary)
	tagSnap = "rbxassetid://0", -- the triage band clicking shut
	tabletTap = "rbxassetid://0",
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
function FerryUi.subtitle(gui: Instance, text: string, seconds: number?)
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
	l.Text = text
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
-- throw, haul, grab, radio, cpr, knock, point, steer). `false` = no hands clip (camera moment).
-- When the camera stream adds dedicated clips, point these at them.
FerryUi.ActionAlias = {
	hull_knock = "knock",
	hull_mark_chalk = "point",
	line_pull = "haul",
	radio_ptt = "radio",
	tablet_raise = "point",
	tablet_tap = "point",
	tablet_drag = "point",
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

FerryUi.NumberKeys = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
}

---------------------------------------------------------------- world

-- The Gale Queen greybox RescueService built for this operation (Model with CallId = opId).
function FerryUi.findFerry(opId: string): Model?
	for _, d in workspace:GetDescendants() do
		if d:IsA("Model") and d.Name == "GaleQueen" and d:GetAttribute("CallId") == opId then
			return d
		end
	end
	return nil
end

function FerryUi.character(): (Model?, BasePart?)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return char, if root and root:IsA("BasePart") then root else nil
end

return FerryUi
