--!strict
-- PIW/Ui: the small shared HUD and input kit for the Person in the Water mechanics.
-- Every mechanic binds the same three schemes (docs 09 section 2.7):
--   PC: mouse aim, left click (hold to charge), left/right click two-hand rhythm, number keys.
--   Mobile: big Action button (hold to charge), two rhythm pads, tap cards, drag on the right half.
--   Gamepad: right stick aim (camera), A / RT action, LB / RB rhythm, A B X Y cards.
-- Panels are compact and sit low on the screen so the first-person view stays clear; Assist mode
-- may add one subtle hint line and glow the right card after 5 s of hesitation (docs 09 9.3).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local HudTheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Layout = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("Layout"))

local Ui = {}
Ui.Theme = HudTheme
Ui.PRIORITY = Enum.ContextActionPriority.High.Value + 50

export type Bag = { items: { any } }

function Ui.bag(): Bag
	return { items = {} }
end

function Ui.add<T>(bag: Bag, item: T): T
	table.insert(bag.items, item)
	return item
end

function Ui.clean(bag: Bag)
	local items = bag.items
	bag.items = {}
	for i = #items, 1, -1 do
		local it = items[i]
		local kind = typeof(it)
		if kind == "RBXScriptConnection" then
			it:Disconnect()
		elseif kind == "Instance" then
			it:Destroy()
		elseif kind == "function" then
			pcall(it)
		elseif kind == "thread" then
			pcall(task.cancel, it)
		end
	end
end

local serial = 0
local function uniqueName(name: string): string
	serial += 1
	return `PIW_{name}_{serial}`
end

-- Binds keys / buttons; fn(stateName "Begin"|"End"|"Change", input). Returns an unbind function.
function Ui.bind(bag: Bag, name: string, fn: (string, InputObject) -> (), ...: any): () -> ()
	local action = uniqueName(name)
	ContextActionService:BindActionAtPriority(action, function(_, state, input)
		if state == Enum.UserInputState.Begin then
			fn("Begin", input)
		elseif state == Enum.UserInputState.End then
			fn("End", input)
		elseif state == Enum.UserInputState.Change then
			fn("Change", input)
		end
		return Enum.ContextActionResult.Sink
	end, false, Ui.PRIORITY, ...)
	local unbound = false
	local function unbind()
		if not unbound then
			unbound = true
			ContextActionService:UnbindAction(action)
		end
	end
	Ui.add(bag, unbind)
	return unbind
end

function Ui.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Ui.isGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last.Name:sub(1, 7) == "Gamepad"
end

function Ui.screen(bag: Bag, name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = `PIW_{name}`
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 22
	Layout.prepare(gui)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	Ui.add(bag, gui)
	return gui
end

-- The Layout "prompt" region (centre low, above the radio subtitles) of a mechanic screen, as a
-- bottom-up stack so a step panel and a recovery panel never sit on top of each other.
local function promptStack(gui: ScreenGui): Frame
	local region = Layout.region(gui, "prompt")
	if not region:FindFirstChildOfClass("UIListLayout") then
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, Layout.GAP)
		list.Parent = region
	end
	return region
end

-- A bottom-anchored panel on a ScreenGui goes into the prompt stack (its pos is then ignored);
-- anything else is placed as given.
function Ui.panel(parent: Instance, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor or Vector2.new(0.5, 1)
	f.Position = pos
	if parent:IsA("ScreenGui") and f.AnchorPoint.Y == 1 then
		local stack = promptStack(parent)
		f.LayoutOrder = -#stack:GetChildren() -- newest on top
		parent = stack
	end
	f.Size = size
	f.BackgroundColor3 = HudTheme.Colors.panel
	f.BackgroundTransparency = HudTheme.PromptTransparency
	f.BorderSizePixel = 0
	f.Parent = parent
	HudTheme.corner(f)
	HudTheme.stroke(f)
	return f
end

function Ui.text(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	textSize: number?,
	bold: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = if bold then HudTheme.BoldFont else HudTheme.BodyFont
	l.TextColor3 = HudTheme.Colors.text
	l.TextSize = textSize or HudTheme.TextSize.body
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

function Ui.button(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	onClick: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = HudTheme.Colors.panelLight
	b.AutoButtonColor = true
	b.Font = HudTheme.BoldFont
	b.TextColor3 = HudTheme.Colors.text
	b.TextSize = 18
	b.TextWrapped = true
	b.Text = text
	b.Parent = parent
	HudTheme.corner(b, 10)
	b.Activated:Connect(onClick)
	return b
end

-- The step header: plain label and the real term underneath (docs 09 principle 1).
function Ui.header(parent: Instance, label: string, realTerm: string): (TextLabel, TextLabel)
	local a = Ui.text(
		parent,
		label,
		UDim2.new(1, -24, 0, 24),
		UDim2.fromOffset(12, 7),
		HudTheme.TextSize.title,
		true
	)
	local b = Ui.text(
		parent,
		realTerm,
		UDim2.new(1, -24, 0, 18),
		UDim2.fromOffset(12, 31),
		HudTheme.TextSize.small
	)
	b.TextColor3 = HudTheme.Colors.textDim
	b.Font = Enum.Font.BuilderSansMedium
	return a, b
end

-- Assist-only hint line: small, dim, never a glow over the world.
function Ui.hint(parent: Instance, text: string, assist: boolean): TextLabel
	local l = Ui.text(
		parent,
		text,
		UDim2.new(1, -24, 0, 20),
		UDim2.new(0, 12, 1, -25),
		HudTheme.TextSize.small
	)
	l.TextColor3 = HudTheme.Colors.textDim
	l.Visible = assist
	return l
end

-- A crew call-out line ("Five metres... three... neutral!") near the top of the screen.
function Ui.callout(bag: Bag, gui: ScreenGui): (string, number?) -> ()
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.fromScale(0.5, 0)
	l.Size = UDim2.new(1, 0, 0, 30)
	l.BackgroundTransparency = 1
	l.Font = HudTheme.BoldFont
	l.TextSize = 22
	l.TextColor3 = HudTheme.Colors.text
	l.TextStrokeTransparency = 0.6
	l.TextWrapped = true
	l.Text = ""
	l.Parent = Layout.region(gui, "notice")
	Ui.add(bag, l)
	local n = 0
	return function(text: string, seconds: number?)
		n += 1
		local mine = n
		l.Text = text
		task.delay(seconds or 2.5, function()
			if n == mine and l.Parent then
				l.Text = ""
			end
		end)
	end
end

-- Hands on screen: the camera stream's viewmodel (may not exist yet).
function Ui.hands(name: string)
	task.spawn(function()
		pcall(function()
			local client = script.Parent.Parent.Parent
			local cam = client:FindFirstChild("Camera")
			local vm = cam and cam:FindFirstChild("Viewmodel")
			if vm and vm:IsA("ModuleScript") then
				local Viewmodel = (require :: any)(vm)
				if type(Viewmodel.playAction) == "function" then
					Viewmodel.playAction(name)
				end
			end
		end)
	end)
end

local FACE =
	{ Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY }
local FACE_NAMES = { "A", "B", "X", "Y" }
local NUMBERS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

export type CardSpec = {
	title: string,
	cue: string,
	options: { string },
	answer: number?, -- only used for the Assist glow
	assist: boolean,
	disabled: { [number]: boolean }?,
}

-- 2 to 4 choice cards: number keys / tap / A B X Y. Calls onPick(i) once.
function Ui.cards(bag: Bag, parent: Instance, spec: CardSpec, onPick: (number) -> ()): Frame
	local n = math.min(#spec.options, 4)
	local frame = Ui.panel(parent, UDim2.fromOffset(640, 168), UDim2.new(0.5, 0, 1, -24))
	Ui.text(frame, spec.title, UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 8), 18, true)
	local cueLabel =
		Ui.text(frame, spec.cue, UDim2.new(1, -24, 0, 40), UDim2.fromOffset(12, 32), 16)
	cueLabel.TextColor3 = HudTheme.Colors.text
	local picked = false
	local unbind: () -> () = function() end
	local buttons: { TextButton } = {}
	local localBag = Ui.bag()
	local function pick(i: number)
		if picked or i > n or (spec.disabled and spec.disabled[i]) then
			return
		end
		picked = true
		unbind()
		Ui.clean(localBag)
		onPick(i)
	end
	local w = (616 - (n - 1) * 8) / n
	for i = 1, n do
		local key = if Ui.isGamepad() then FACE_NAMES[i] else tostring(i)
		local b = Ui.button(
			frame,
			`{key}  {spec.options[i]}`,
			UDim2.fromOffset(w, 74),
			UDim2.fromOffset(12 + (i - 1) * (w + 8), 82),
			function()
				pick(i)
			end
		)
		b.TextSize = 16
		if spec.disabled and spec.disabled[i] then
			b.BackgroundColor3 = HudTheme.Colors.locked
			b.TextColor3 = HudTheme.Colors.textDim
		end
		table.insert(buttons, b)
	end
	local keys = {}
	for i = 1, n do
		table.insert(keys, NUMBERS[i])
		table.insert(keys, FACE[i])
	end
	unbind = Ui.bind(bag, "Cards", function(state, input)
		if state ~= "Begin" then
			return
		end
		for i = 1, n do
			if input.KeyCode == NUMBERS[i] or input.KeyCode == FACE[i] then
				pick(i)
			end
		end
	end, table.unpack(keys))
	if spec.assist and spec.answer then
		local answer = spec.answer
		Ui.add(
			localBag,
			task.delay(5, function()
				if not picked and buttons[answer] and buttons[answer].Parent then
					HudTheme.stroke(buttons[answer], HudTheme.Colors.ready, 2)
				end
			end)
		)
	end
	return frame
end

-- Two-hand rhythm: left/right click, LB/RB, or two touch pads. onTap("L" | "R").
function Ui.pads(bag: Bag, parent: Instance, onTap: (string) -> ()): (TextButton, TextButton)
	local function pad(label: string, pos: UDim2, hand: string): TextButton
		local b = Ui.button(parent, label, UDim2.fromOffset(150, 110), pos, function() end)
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.BackgroundTransparency = 0.35
		b.Visible = Ui.isTouch()
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				onTap(hand)
			end
		end)
		return b
	end
	local l = pad("Left hand", UDim2.new(0, 110, 1, -40), "L")
	local r = pad("Right hand", UDim2.new(1, -110, 1, -40), "R")
	Ui.add(bag, l)
	Ui.add(bag, r)
	Ui.bind(bag, "RhythmL", function(state)
		if state == "Begin" then
			onTap("L")
		end
	end, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonL1, Enum.KeyCode.Q)
	Ui.bind(bag, "RhythmR", function(state)
		if state == "Begin" then
			onTap("R")
		end
	end, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonR1, Enum.KeyCode.E)
	return l, r
end

-- Hold-to-charge action: left click / A / RT, or a big touch Action button.
function Ui.action(
	bag: Bag,
	parent: Instance,
	label: string,
	onBegin: () -> (),
	onEnd: () -> ()
): TextButton
	local b = Ui.button(
		parent,
		label,
		UDim2.fromOffset(140, 140),
		UDim2.new(1, -40, 1, -180),
		function() end
	)
	b.AnchorPoint = Vector2.new(1, 1)
	b.BackgroundColor3 = HudTheme.Colors.accent
	b.BackgroundTransparency = 0.2
	b.Visible = Ui.isTouch()
	HudTheme.corner(b, 70)
	Ui.add(bag, b)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onBegin()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			onEnd()
		end
	end)
	Ui.bind(bag, "Action", function(state)
		if state == "Begin" then
			onBegin()
		elseif state == "End" then
			onEnd()
		end
	end, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2)
	return b
end

-- A horizontal bar with a moving needle and an optional good band (comfort, level, panic).
function Ui.meter(
	parent: Instance,
	title: string,
	pos: UDim2,
	width: number
): (number, number?, number?) -> ()
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = pos
	holder.Size = UDim2.fromOffset(width, 34)
	holder.Parent = parent
	local t = Ui.text(holder, title, UDim2.new(1, 0, 0, 17), UDim2.fromOffset(0, 0), 15)
	t.TextColor3 = HudTheme.Colors.textDim
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(0, 20)
	track.Size = UDim2.new(1, 0, 0, 10)
	track.BackgroundColor3 = HudTheme.Colors.locked
	track.BorderSizePixel = 0
	track.Parent = holder
	HudTheme.corner(track, 5)
	local band = Instance.new("Frame")
	band.BackgroundColor3 = HudTheme.Colors.panelLight
	band.BorderSizePixel = 0
	band.Size = UDim2.fromScale(0, 1)
	band.Parent = track
	local needle = Instance.new("Frame")
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Size = UDim2.fromOffset(4, 16)
	needle.Position = UDim2.fromScale(0, 0.5)
	needle.BackgroundColor3 = HudTheme.Colors.text
	needle.BorderSizePixel = 0
	needle.Parent = track
	return function(value: number, lo: number?, hi: number?)
		needle.Position = UDim2.fromScale(math.clamp(value, 0, 1), 0.5)
		if lo and hi then
			band.Position = UDim2.fromScale(lo, 0)
			band.Size = UDim2.fromScale(hi - lo, 1)
		end
	end
end

return Ui
