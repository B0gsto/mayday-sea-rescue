--!strict
-- ExerciseBoard (RP-C1b): the station exercise board read up close (docs 09 section 9.2). Opens
-- only from the board's ProximityPrompt in the boat hall (ExerciseBoardController); there is no
-- HUD button. One card per exercise in board order: title, about how long, what it drills, this
-- player's status (best grade), what the certification needs and Start (or why not yet).
-- Mouse / touch: tap Start or Close. Gamepad: the D-pad moves between the Start buttons, A
-- starts, B closes. Keyboard: Escape closes. Sized in design units like the HUD (Layout scale).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Exercises =
	require(Shared:WaitForChild("Ops"):WaitForChild("Definitions"):WaitForChild("Exercises"))
local HudTheme = require(script.Parent.HudTheme)
local Layout = require(script.Parent.Layout)

local C = HudTheme.Colors

export type Board = {
	frame: Frame,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	update: (rows: { Exercises.BoardRow }) -> (),
	notice: (text: string?) -> (),
	firstButton: () -> GuiObject?,
}

local ExerciseBoard = {}

local CARD_HEIGHT = 132
local WIDTH, HEIGHT = 680, 470 -- design units (clamped to the usable area)

function ExerciseBoard.build(gui: ScreenGui, onStart: (exerciseId: string) -> ()): Board
	local frame = HudTheme.panel("ExerciseBoard", UDim2.fromOffset(WIDTH, HEIGHT), gui)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = HudTheme.PromptTransparency
	frame.Visible = false
	HudTheme.padding(frame, 14)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local function fit(mt: Layout.Metrics)
		scale.Scale = mt.scale
		frame.Size =
			UDim2.fromOffset(math.min(WIDTH, mt.usable.X - 40), math.min(HEIGHT, mt.usable.Y - 24))
	end
	fit(Layout.current())
	Layout.onMetrics(fit)

	local title = HudTheme.label(
		"Title",
		"STATION EXERCISES",
		UDim2.new(1, -150, 0, 30),
		HudTheme.HeaderFont,
		22,
		frame
	)
	title.TextColor3 = C.accent
	local sub = HudTheme.label(
		"Sub",
		"Chief Aggie runs these with the manikin. Pass one, then prove it on live calls.",
		UDim2.new(1, -150, 0, 20),
		HudTheme.BodyFont,
		15,
		frame
	)
	sub.Position = UDim2.fromOffset(0, 30)
	sub.TextColor3 = C.textDim

	local close =
		HudTheme.button("Close", "Close", UDim2.fromOffset(120, HudTheme.MinButtonHeight), frame)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.BackgroundColor3 = C.panelLight

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 62)
	list.Size = UDim2.new(1, 0, 1, -62 - 26)
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = C.textDim
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.Selectable = false
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local footer =
		HudTheme.label("Notice", "", UDim2.new(1, 0, 0, 22), HudTheme.BodyFont, 15, frame)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.TextColor3 = C.gold

	local open = false
	local firstStart: GuiObject? = nil
	local board: Board

	local function card(row: Exercises.BoardRow, order: number)
		local f = Instance.new("Frame")
		f.Name = row.id
		f.LayoutOrder = order
		f.Size = UDim2.new(1, -8, 0, CARD_HEIGHT)
		f.BackgroundColor3 = C.panelLight
		f.BackgroundTransparency = 0.35
		f.BorderSizePixel = 0
		HudTheme.corner(f)
		HudTheme.padding(f, 10)
		f.Parent = list
		local mins = if row.minutes < 1
			then "under a minute"
			else `about {math.ceil(row.minutes)} min`
		local head =
			HudTheme.label("Name", row.title, UDim2.new(1, -170, 0, 24), HudTheme.HeaderFont, 19, f)
		local meta = HudTheme.label(
			"Meta",
			`{mins}  |  {if row.certification then `for {row.certification}` else "optional"}`,
			UDim2.new(1, -170, 0, 18),
			HudTheme.BodyFont,
			14,
			f
		)
		meta.Position = UDim2.fromOffset(0, 24)
		meta.TextColor3 = C.textDim
		local summary = HudTheme.label(
			"Summary",
			row.summary,
			UDim2.new(1, -170, 0, 38),
			HudTheme.BodyFont,
			15,
			f
		)
		summary.Position = UDim2.fromOffset(0, 44)
		summary.TextWrapped = true
		summary.TextTruncate = Enum.TextTruncate.None
		summary.TextYAlignment = Enum.TextYAlignment.Top
		local req = HudTheme.label(
			"Requirement",
			row.requirement,
			UDim2.new(1, -170, 0, 28),
			HudTheme.BodyFont,
			14,
			f
		)
		req.Position = UDim2.fromOffset(0, 84)
		req.TextWrapped = true
		req.TextTruncate = Enum.TextTruncate.None
		req.TextYAlignment = Enum.TextYAlignment.Top
		req.TextColor3 = C.bar
		head.TextColor3 = C.text

		local status = HudTheme.label(
			"Status",
			row.status,
			UDim2.fromOffset(160, 20),
			HudTheme.HeaderFont,
			15,
			f
		)
		status.AnchorPoint = Vector2.new(1, 0)
		status.Position = UDim2.new(1, 0, 0, 2)
		status.TextXAlignment = Enum.TextXAlignment.Right
		status.TextColor3 = if row.best then C.ready else C.textDim

		if row.canStart then
			local b = HudTheme.button(
				"Start",
				if row.best then "Run it again" else "Start",
				UDim2.fromOffset(150, HudTheme.MinButtonHeight),
				f
			)
			b.AnchorPoint = Vector2.new(1, 1)
			b.Position = UDim2.fromScale(1, 1)
			b.Activated:Connect(function()
				onStart(row.id)
			end)
			if not firstStart then
				firstStart = b
			end
		else
			local why = HudTheme.label(
				"Locked",
				row.reason,
				UDim2.fromOffset(150, 40),
				HudTheme.BodyFont,
				14,
				f
			)
			why.AnchorPoint = Vector2.new(1, 1)
			why.Position = UDim2.fromScale(1, 1)
			why.TextXAlignment = Enum.TextXAlignment.Right
			why.TextWrapped = true
			why.TextTruncate = Enum.TextTruncate.None
			why.TextColor3 = C.textDim
		end
	end

	board = {
		frame = frame,
		setOpen = function(value: boolean)
			open = value
			frame.Visible = value
			if not value then
				footer.Text = ""
			end
		end,
		isOpen = function()
			return open
		end,
		update = function(rows: { Exercises.BoardRow })
			for _, child in list:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			firstStart = nil
			for i, row in rows do
				card(row, i)
			end
		end,
		notice = function(text: string?)
			footer.Text = text or ""
		end,
		firstButton = function(): GuiObject?
			return firstStart or close
		end,
	}
	close.Activated:Connect(function()
		board.setOpen(false)
	end)
	return board
end

return ExerciseBoard
