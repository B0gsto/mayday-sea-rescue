--!strict
-- DevBoard: the dev board panel shell and its widgets (DevController fills the tabs). Dev-only
-- tool, outside gameplay rules: a tabbed, scrollable panel with icon + 1-3 word buttons, a
-- target-player dropdown, sliders and a hold-to-confirm button. Phone-sized via UISizeConstraint.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local HudTheme = require(script.Parent:WaitForChild("HudTheme"))

local C = HudTheme.Colors
local ROW = 44
local HOLD_SECONDS = 1.5

local DevBoard = {}

export type Board = {
	gui: ScreenGui,
	panel: Frame,
	tab: (name: string) -> Frame, -- a tab's content list (create on first call)
	setStatus: (text: string) -> (),
	setTarget: (text: string) -> (),
	onTarget: (fn: () -> ()) -> (),
	setVisible: (on: boolean) -> (),
	visible: () -> boolean,
}

local function list(parent: Instance, padding: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

function DevBoard.build(parent: Instance, tabs: { string }): Board
	local gui = Instance.new("ScreenGui")
	gui.Name = "DevBoard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Enabled = false
	gui.Parent = parent

	local panel = HudTheme.panel("Panel", UDim2.fromScale(0.94, 0.86), gui)
	panel.BackgroundTransparency = 0.08
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -12, 0.5, 0)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 620)
	limit.Parent = panel
	HudTheme.padding(panel, 8)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, ROW)
	header.Parent = panel
	HudTheme.label(
		"Title",
		"🛠 Dev board",
		UDim2.fromScale(0.4, 1),
		HudTheme.HeaderFont,
		HudTheme.TextSize.title,
		header
	)
	local target = HudTheme.button("Target", "🎯 Me", UDim2.new(0.42, 0, 1, -6), header)
	target.Position = UDim2.new(0.4, 0, 0, 3)
	target.BackgroundColor3 = C.panelLight
	-- a full-row tap target (PTA 2026-10-31: the 38 px X missed taps at 844 x 390)
	local close = HudTheme.button("Close", "X", UDim2.new(0, ROW + 8, 1, 0), header)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.BackgroundColor3 = C.panelLight

	-- tabs wrap in rows of 4, all visible at once
	local tabRows = math.ceil(#tabs / 4)
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Position = UDim2.fromOffset(0, ROW + 4)
	bar.Size = UDim2.new(1, 0, 0, tabRows * ROW)
	bar.Parent = panel
	local barGrid = Instance.new("UIGridLayout")
	barGrid.CellSize = UDim2.new(0.25, -4, 0, ROW - 4)
	barGrid.CellPadding = UDim2.fromOffset(4, 4)
	barGrid.SortOrder = Enum.SortOrder.LayoutOrder
	barGrid.Parent = bar
	local top = (tabRows + 1) * ROW + 12

	local status =
		HudTheme.label("Status", "", UDim2.new(1, 0, 0, 24), nil, HudTheme.TextSize.small, panel)
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.fromScale(0, 1)
	status.TextColor3 = C.textDim

	local pages: { [string]: ScrollingFrame } = {}
	local buttons: { [string]: TextButton } = {}
	local function show(name: string)
		for n, page in pages do
			page.Visible = n == name
			buttons[n].BackgroundColor3 = if n == name then C.accent else C.panelLight
		end
	end
	for i, name in tabs do
		local b = HudTheme.button(name, name, UDim2.new(), bar)
		b.LayoutOrder = i
		local page = Instance.new("ScrollingFrame")
		page.Name = name
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Position = UDim2.fromOffset(0, top)
		page.Size = UDim2.new(1, 0, 1, -(top + 28))
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize = UDim2.new()
		page.ScrollBarThickness = 6
		page.Visible = false
		page.Parent = panel
		list(page, 6)
		pages[name] = page
		buttons[name] = b
		b.Activated:Connect(function()
			show(name)
		end)
	end
	show(tabs[1])

	local board: Board
	board = {
		gui = gui,
		panel = panel,
		tab = function(name: string): Frame
			return pages[name] :: any
		end,
		setStatus = function(text: string)
			status.Text = text
		end,
		setTarget = function(text: string)
			target.Text = `🎯 {text}`
		end,
		onTarget = function(fn: () -> ())
			target.Activated:Connect(fn)
		end,
		setVisible = function(on: boolean)
			gui.Enabled = on
			-- a gamepad needs a selected button to navigate the panel
			if on and UserInputService.GamepadEnabled then
				GuiService.SelectedObject = buttons[tabs[1]]
			elseif
				not on
				and GuiService.SelectedObject
				and GuiService.SelectedObject:IsDescendantOf(gui)
			then
				GuiService.SelectedObject = nil
			end
		end,
		visible = function(): boolean
			return gui.Enabled
		end,
	}
	close.Activated:Connect(function()
		board.setVisible(false)
	end)
	-- close on the press too: a tap that drifts off the small corner button never fires Activated
	close.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			board.setVisible(false)
		end
	end)
	return board
end

-- A titled block of buttons (a wrapping grid) inside a tab.
function DevBoard.section(page: Instance, title: string): Frame
	HudTheme.label(
		"H",
		title,
		UDim2.new(1, -8, 0, 22),
		HudTheme.HeaderFont,
		HudTheme.TextSize.small,
		page
	).LayoutOrder =
		nextOrder()
	local grid = Instance.new("Frame")
	grid.Name = title
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.LayoutOrder = nextOrder()
	grid.Parent = page
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -4, 0, ROW)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	return grid
end

function DevBoard.button(grid: Instance, text: string, fn: () -> ()): TextButton
	local b = HudTheme.button(text, text, UDim2.new(), grid)
	b.BackgroundColor3 = C.panelLight
	b.LayoutOrder = nextOrder()
	b.Activated:Connect(fn)
	return b
end

-- A toggle: lit (accent) while on. fn gets the new state.
function DevBoard.toggle(grid: Instance, text: string, fn: (on: boolean) -> ()): TextButton
	local on = false
	local b: TextButton
	b = DevBoard.button(grid, text, function()
		on = not on
		b.BackgroundColor3 = if on then C.accent else C.panelLight
		fn(on)
	end)
	return b
end

-- Press and hold HOLD_SECONDS to fire (a red fill shows the hold); letting go early cancels.
function DevBoard.hold(grid: Instance, text: string, fn: () -> ()): TextButton
	local b = DevBoard.button(grid, text, function() end)
	b.ClipsDescendants = true
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromHex("C0392B")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 0
	fill.Parent = b
	local token = 0
	b.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if
			t ~= Enum.UserInputType.MouseButton1
			and t ~= Enum.UserInputType.Touch
			and input.KeyCode ~= Enum.KeyCode.ButtonA
		then
			return
		end
		token += 1
		local mine = token
		local start = os.clock()
		while token == mine do
			local k = (os.clock() - start) / HOLD_SECONDS
			fill.Size = UDim2.fromScale(math.min(k, 1), 1)
			if k >= 1 then
				token += 1
				fill.Size = UDim2.fromScale(0, 1)
				fn()
				return
			end
			task.wait()
		end
		fill.Size = UDim2.fromScale(0, 1)
	end)
	b.InputEnded:Connect(function()
		token += 1
	end)
	return b
end

-- A horizontal slider over [min, max]; fn gets the value on every drag step.
function DevBoard.slider(
	page: Instance,
	title: string,
	min: number,
	max: number,
	value: number,
	fn: (number) -> ()
)
	local row = Instance.new("Frame")
	row.Name = title
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, -8, 0, ROW)
	row.LayoutOrder = nextOrder()
	row.Parent = page
	local label =
		HudTheme.label("L", "", UDim2.fromScale(0.38, 1), nil, HudTheme.TextSize.small, row)
	local track = Instance.new("TextButton")
	track.Text = ""
	track.AutoButtonColor = false
	track.BackgroundColor3 = C.panelLight
	track.BorderSizePixel = 0
	track.Position = UDim2.new(0.4, 0, 0.5, -10)
	track.Size = UDim2.new(0.6, 0, 0, 20)
	track.Parent = row
	HudTheme.corner(track, 10)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = C.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	HudTheme.corner(fill, 10)
	local function set(v: number, fire: boolean)
		v = math.clamp(v, min, max)
		fill.Size = UDim2.fromScale((v - min) / (max - min), 1)
		label.Text = `{title} {math.floor(v * 10 + 0.5) / 10}`
		if fire then
			fn(v)
		end
	end
	local dragging = false
	local function at(x: number)
		local k = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		set(min + k * (max - min), true)
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			at(input.Position.X)
		end
	end)
	track.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			at(input.Position.X)
		end
	end)
	track.InputEnded:Connect(function()
		dragging = false
	end)
	-- gamepad: A on the selected track steps a tenth up, wrapping to the bottom
	track.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonA then
			local k = fill.Size.X.Scale + 0.1
			set(min + (if k > 1.001 then 0 else k) * (max - min), true)
		end
	end)
	set(value, false)
end

-- A pick list over the panel; fn gets the chosen value. Closes on pick or on the backdrop.
function DevBoard.pick(board: Board, items: { { text: string, value: any } }, fn: (any) -> ())
	local back = Instance.new("TextButton")
	back.Text = ""
	back.AutoButtonColor = false
	back.BackgroundColor3 = Color3.new(0, 0, 0)
	back.BackgroundTransparency = 0.4
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 10
	back.Parent = board.panel
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundColor3 = C.panel
	scroll.BorderSizePixel = 0
	scroll.AnchorPoint = Vector2.new(0.5, 0.5)
	scroll.Position = UDim2.fromScale(0.5, 0.5)
	scroll.Size = UDim2.fromScale(0.85, 0.75)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 11
	scroll.Parent = back
	HudTheme.padding(scroll, 6)
	list(scroll, 4)
	back.Activated:Connect(function()
		back:Destroy()
	end)
	for i, item in items do
		local b = HudTheme.button(item.text, item.text, UDim2.new(1, -8, 0, ROW), scroll)
		b.BackgroundColor3 = C.panelLight
		b.LayoutOrder = i
		b.ZIndex = 12
		b.Activated:Connect(function()
			back:Destroy()
			fn(item.value)
		end)
	end
end

return DevBoard
