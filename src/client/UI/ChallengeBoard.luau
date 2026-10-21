--!strict
-- ChallengeBoard: the player's rolls on the station challenge board (LU-1). The server builds the
-- physical board; this local SurfaceGui draws that player's daily and weekly challenges as icons,
-- one-word labels and numbers, with a tick when a challenge is done.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("ChallengeConfig"))

local PAPER = Color3.fromRGB(24, 34, 40)
local INK = Color3.fromRGB(236, 237, 234)
local DIM = Color3.fromRGB(170, 184, 192)
local ACCENT = Color3.fromRGB(217, 104, 46)
local READY = Color3.fromRGB(111, 191, 142)
local TYPE = Font.new("rbxasset://fonts/families/BuilderSans.json")

local BY_ID: { [string]: any } = {}
for _, def in Config.Pool do
	BY_ID[def.id] = def
end

export type View = {
	daily: { { id: string, progress: number, target: number, done: boolean } },
	weekly: { { id: string, progress: number, target: number, done: boolean } },
	stamps: number,
}

export type Board = { update: (view: View?) -> () }

local ChallengeBoard = {}

local function label(
	parent: Instance,
	text: string,
	position: UDim2,
	size: UDim2,
	pixels: number,
	color: Color3,
	bold: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Position = position
	l.Size = size
	l.FontFace =
		Font.new(TYPE.Family, if bold then Enum.FontWeight.Bold else Enum.FontWeight.Medium)
	l.TextSize = pixels
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function row(parent: Instance, showName: boolean): (Frame, TextLabel, TextLabel, TextLabel)
	local bg = Instance.new("Frame")
	bg.Name = "Row"
	bg.BackgroundColor3 = PAPER
	bg.BackgroundTransparency = 1
	bg.BorderSizePixel = 0
	bg.Position = UDim2.fromOffset(0, 0)
	bg.Size = UDim2.new(1, 0, 0, 36)
	bg.Parent = parent
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundColor3 = INK
	line.BackgroundTransparency = 0.88
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0, 1)
	line.Position = UDim2.fromScale(0, 1)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = bg
	local icon = label(bg, "", UDim2.fromOffset(4, 0), UDim2.fromOffset(34, 36), 26, INK)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	local name = label(bg, "", UDim2.fromOffset(46, 0), UDim2.new(1, -150, 0, 36), 22, DIM, false)
	name.Visible = showName
	local value = label(bg, "", UDim2.new(1, -8, 0, 0), UDim2.fromOffset(120, 36), 26, INK, true)
	value.AnchorPoint = Vector2.new(1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	return bg, icon, name, value
end

function ChallengeBoard.mount(panel: BasePart): Board
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ChallengePrint"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 90
	gui.LightInfluence = 0.2
	gui.MaxDistance = 80
	gui.ClipsDescendants = true
	gui.Adornee = panel
	gui.Parent = panel

	local root = Instance.new("Frame")
	root.Name = "Board"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	local title =
		label(root, "CHALLENGES", UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 40), 36, ACCENT, true)
	title.TextXAlignment = Enum.TextXAlignment.Center

	-- One column of headings and rows sized by a UIListLayout: 3 daily + 5 weekly fit the panel.
	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(10, 52)
	rows.Size = UDim2.new(1, -20, 1, -60)
	rows.Parent = root
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = rows

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function heading(text: string, height: number)
		local l =
			label(rows, text, UDim2.fromOffset(4, 0), UDim2.new(1, 0, 0, height), 20, DIM, true)
		l.LayoutOrder = nextOrder()
		return l
	end
	local function gap(height: number)
		local f = Instance.new("Frame")
		f.Name = "Gap"
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, height)
		f.LayoutOrder = nextOrder()
		f.Parent = rows
	end

	heading("DAILY", 22)
	local daily = {}
	for i = 1, Config.DailyCount do
		local bg, icon, name, value = row(rows, false)
		daily[i] = { icon = icon, name = name, value = value }
		bg.LayoutOrder = nextOrder()
	end
	gap(8)
	heading("WEEKLY", 22)
	local weekly = {}
	for i = 1, Config.WeeklyCount do
		local bg, icon, name, value = row(rows, true)
		weekly[i] = { icon = icon, name = name, value = value }
		bg.LayoutOrder = nextOrder()
	end

	local function update(view: View?)
		for i, cell in daily do
			local slot = if view then view.daily[i] else nil
			local def = if slot then BY_ID[slot.id] else nil
			cell.icon.Text = if def then def.icon else "·"
			if slot then
				cell.value.Text = if slot.done then "✓" else `{slot.progress}/{slot.target}`
				cell.value.TextColor3 = if slot.done then READY else INK
			else
				cell.value.Text = "--"
				cell.value.TextColor3 = DIM
			end
		end
		for i, cell in weekly do
			local slot = if view then view.weekly[i] else nil
			local def = if slot then BY_ID[slot.id] else nil
			cell.icon.Text = if def then def.icon else "·"
			cell.name.Text = if def then def.label else "--"
			if slot then
				cell.value.Text = if slot.done then "✓" else `{slot.progress}/{slot.target}`
				cell.value.TextColor3 = if slot.done then READY else INK
			else
				cell.value.Text = "--"
				cell.value.TextColor3 = DIM
			end
		end
	end

	local board: Board = { update = update }
	update(nil)
	return board
end

return ChallengeBoard
