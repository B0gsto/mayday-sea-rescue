--!strict
-- BoardView: the on-scene commander's scene board for every crew on a Capsized Ferry operation.
-- Listens to Ops_Board (S->C, sent when scene_command completes) and to the `board` field of
-- Ops_State (for crews that start listening late), and draws a compact read-only panel:
-- who is OSC and which unit has each task. FerryUi starts it when the first ferry mechanic
-- loads; `BoardView.start()` is idempotent. Hidden when the operation closes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudTheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Ops = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops")
local Remotes = require(Ops:WaitForChild("Remotes"))
local SceneBoard = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ferry"):WaitForChild("SceneBoard")
) :: any

local BoardView = {}

local started = false
local gui: ScreenGui? = nil
local body: TextLabel? = nil
local shownOp: string? = nil
local lastKey: string? = nil

local function ensureGui(): (ScreenGui, TextLabel)
	if gui and body and gui.Parent then
		return gui, body
	end
	local C = HudTheme.Colors
	local g = Instance.new("ScreenGui")
	g.Name = "FerrySceneBoard"
	g.ResetOnSpawn = false
	g.DisplayOrder = 5
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -16, 0, 96)
	frame.Size = UDim2.fromOffset(280, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = C.panel
	frame.BackgroundTransparency = HudTheme.PanelTransparency
	frame.Parent = g
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, HudTheme.Corner)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 10)
	end
	pad.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Font = HudTheme.BodyFont
	label.TextSize = 15
	label.TextColor3 = C.text
	label.Parent = frame
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui, body = g, label
	return g, label
end

local function hide()
	shownOp, lastKey = nil, nil
	if gui then
		gui:Destroy()
		gui, body = nil, nil
	end
end

local function show(data: any)
	if type(data) ~= "table" or type(data.opId) ~= "string" then
		return
	end
	local lines = {
		`<font face="FredokaOne">SCENE BOARD</font>  OSC: {tostring(data.osc or "?")}`,
	}
	local board = if type(data.board) == "table" then data.board else nil
	if board then
		for _, t in SceneBoard.Tasks do
			local names = {}
			for unit, tid in board do
				if tid == t.id then
					table.insert(names, tostring(unit))
				end
			end
			table.sort(names)
			local who = if #names > 0 then table.concat(names, ", ") else "(empty)"
			table.insert(lines, `<b>{t.short}</b>: {who}`)
		end
	end
	if type(data.tasksCovered) == "number" then
		table.insert(lines, `Tasks covered: {math.floor(data.tasksCovered * 100 + 0.5)}%`)
	elseif type(data.assigned) == "number" then
		table.insert(lines, `Units assigned: {data.assigned}`)
	end
	local text = table.concat(lines, "\n")
	if shownOp == data.opId and lastKey == text then
		return
	end
	shownOp, lastKey = data.opId, text
	local _, label = ensureGui()
	label.Text = text
end

function BoardView.start()
	if started then
		return
	end
	started = true
	Remotes.event("Ops_Board").OnClientEvent:Connect(show)
	Remotes.event("Ops_State").OnClientEvent:Connect(function(snap: any)
		if type(snap) ~= "table" then
			return
		end
		if snap.board then
			show(snap.board)
		elseif shownOp == snap.opId and snap.state ~= "Active" then
			hide()
		end
	end)
	Remotes.event("Ops_Closed").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and data.opId == shownOp then
			hide()
		end
	end)
	Remotes.event("Ops_Debrief").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" and data.opId == shownOp then
			hide()
		end
	end)
end

return BoardView
