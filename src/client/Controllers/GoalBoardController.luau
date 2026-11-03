--!strict
-- GoalBoardController: a Lego counter board (GoalBoard) on your next build's empty lot, the in-world twin of the
-- Next chip (live 2026-11-01: after the Workshop most players never saw a goal to save toward). Its face: the
-- building's icon, a Cash bar and "240/400", live. When the bar fills: one pop (VFXKit buy_pop, its FX_Pop), the
-- bar stays green (no outline, no pulse: owner 2026-11-03). Only on your own island, only after the
-- tutorial's Workshop, never over water (sea plates) or a running site. Client-only, no text beyond the number.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local GoalBoard = require(Shared:WaitForChild("GoalBoard"))
local Net = require(Shared:WaitForChild("Net"))
local NextGoal = require(Shared:WaitForChild("NextGoal"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local UI = script.Parent.Parent:WaitForChild("UI")
local BuildGlyph = require(UI:WaitForChild("BuildGlyph"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Theme = require(UI:WaitForChild("Kit"):WaitForChild("Theme"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local GoalBoardController = {}
local player = Players.LocalPlayer

local PPS = 50 -- SurfaceGui pixels a stud: the 12 x 6 face is 600 x 300 px
local POP_NEAR = 160 -- studs: a bar that filled out of sight pops when you come this close
local BRICK = Color3.fromHex("FFC928") -- the Next chip's yellow icon bricks

type Face = { fill: Frame, amount: TextLabel, scale: UIScale }
type Board = {
	key: string,
	model: Model,
	faces: { Face },
	full: boolean,
	popped: boolean,
}

local snapshot: { [string]: any }? = nil
local board: Board? = nil

local function plotModel(): Instance?
	local i = player:GetAttribute("DockPlot")
	local marina = Workspace:FindFirstChild("Marina")
	return if type(i) == "number" and marina then marina:FindFirstChild(`Plot{i}`) else nil
end

local function face(part: BasePart, side: Enum.NormalId, key: string): Face
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Counter{side.Name}`
	gui.Face = side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0.4
	gui.MaxDistance = 400
	gui.Parent = part
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(1, -24, 1, -24)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	-- the icon on a white tile, left
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.BackgroundColor3 = Color3.new(1, 1, 1)
	tile.Position = UDim2.fromOffset(8, 8)
	tile.Size = UDim2.fromOffset(236, 236)
	Style.corner(tile, 28)
	Style.stroke(tile, 8, true)
	tile.Parent = root
	local art = Instance.new("Frame")
	art.BackgroundTransparency = 1
	art.Position = UDim2.fromScale(0.12, 0.12)
	art.Size = UDim2.fromScale(0.76, 0.76)
	art.Parent = tile
	BuildGlyph(art, { kind = "Building", key = key })
	for _, b in art:GetChildren() do
		if b:IsA("Frame") and b.BackgroundColor3 == Color3.new(1, 1, 1) then
			b.BackgroundColor3 = BRICK
		end
	end
	-- the bar, right top: ink track, yellow fill (green when full)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Theme.Colors.ink
	track.Position = UDim2.fromOffset(268, 28)
	track.Size = UDim2.new(1, -276, 0, 84)
	Style.corner(track, 42)
	Style.stroke(track, 6, true)
	track.Parent = root
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(0, 1)
	Style.corner(fill, 42)
	Style.gradient(fill, Style.grad("yellow"))
	fill.Parent = track
	-- coin + "240/400", right bottom
	local coin = Instance.new("ImageLabel")
	coin.Name = "Coin"
	coin.BackgroundTransparency = 1
	coin.Image = UiImages.Hud.Coin
	coin.ScaleType = Enum.ScaleType.Fit
	coin.Position = UDim2.fromOffset(268, 140)
	coin.Size = UDim2.fromOffset(92, 92)
	coin.Parent = root
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.BackgroundTransparency = 1
	amount.Font = Enum.Font.FredokaOne
	amount.TextColor3 = Color3.new(1, 1, 1)
	amount.TextScaled = true
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.Position = UDim2.fromOffset(372, 136)
	amount.Size = UDim2.new(1, -380, 0, 100)
	amount.Parent = root
	Style.stroke(amount, 6)
	return { fill = fill, amount = amount, scale = scale }
end

local function clear()
	if board then
		board.model:Destroy()
		board = nil
	end
end

local function place(key: string, bay: CFrame, plot: Instance): Board
	clear()
	local b = DockConfig.Buildings[key]
	-- BayCFrame is the berth part, 0.2 over the island frame the lots hang from (DockService buildPlot)
	local lot = bay * CFrame.new(0, -0.2, 0) * b.spot
	local m = GoalBoard.build(lot * CFrame.new(0, 0, -b.size.Y / 2 + 3)) -- at the lot's front, facing out
	local part = m.PrimaryPart :: BasePart
	local faces = { face(part, Enum.NormalId.Front, key), face(part, Enum.NormalId.Back, key) }
	m.Parent = plot
	return { key = key, model = m, faces = faces, full = false, popped = true }
end

local function pop(b: Board)
	b.popped = true
	VFXKit.play("buy_pop", b.model.PrimaryPart :: BasePart, { radius = GoalBoard.W / 2 })
	if Comfort.reducedMotion() then
		return
	end
	for _, f in b.faces do
		f.scale.Scale = 1.18
		TweenService
			:Create(f.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			})
			:Play()
	end
end

local function refresh()
	local s = snapshot
	local plot = plotModel()
	local bay = player:GetAttribute("BayCFrame")
	local levels = if s
			and type(s.dock) == "table"
			and type(s.dock.levels) == "table"
		then s.dock.levels
		else nil
	if
		not (s and levels and plot and typeof(bay) == "CFrame")
		or plot:GetAttribute("SiteKey") ~= nil
	then
		clear()
		return
	end
	local g = if (tonumber(levels.Workshop) or 0) >= 1
		then NextGoal.next({ cash = tonumber(s.cash) or 0, levels = levels })
		else nil -- the tutorial's own beats lead until its Workshop stands
	if not g or g.kind ~= "Build" or g.level ~= 1 or DockConfig.SEA_PLATE_CASH[g.key] then
		clear()
		return
	end
	local b: Board
	if board and board.key == g.key and board.model.Parent == plot then
		b = board
	else
		b = place(g.key, bay :: CFrame, plot)
		b.full = g.progress >= 1 -- already full when it appears: steady, no pop
		board = b
	end
	local full = g.progress >= 1
	if full and not b.full then
		b.popped = false -- pops now, or once you come near
	end
	b.full = full
	local text = `{Theme.short(math.min(g.cash, g.price))}/{Theme.short(g.price)}`
	for _, f in b.faces do
		f.fill.Size = UDim2.fromScale(g.progress, 1)
		f.fill.Visible = g.progress > 0.02
		Style.gradient(f.fill, Style.grad(if full then "green" else "yellow"))
		f.amount.Text = text
	end
	local cam = Workspace.CurrentCamera
	local part = b.model.PrimaryPart
	if
		not b.popped
		and cam
		and part
		and (cam.CFrame.Position - part.Position).Magnitude < POP_NEAR
	then
		pop(b)
	end
end

function GoalBoardController.Start()
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			snapshot = data
		end
	end)
	task.spawn(function()
		local getData = Net.init():WaitForChild("Progression_GetData", 30) :: RemoteFunction?
		local ok, data = pcall(function()
			return getData and getData:InvokeServer()
		end)
		if ok and type(data) == "table" and not snapshot then
			snapshot = data
		end
	end)
	while true do
		refresh()
		task.wait(0.25)
	end
end

return GoalBoardController
