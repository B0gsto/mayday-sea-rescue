--!strict
-- NextGoalController: the goal-gradient chip by the Cash / rank strip (docs/03 section 10, docs/16
-- K6). One row: the next rank (star, Rep) or the next boat (its dark silhouette, Cash), whichever is
-- nearer, with the numbers and a thin bar. It peeks in for PEEK seconds when the goal moves (cash,
-- rep, a new goal), then gets out of the view; I / gamepad RB brings it back and opens both goals
-- (tapping the chip too); that view is information only, nothing to pick.
-- Hidden in the cold open and while OnboardingController's world beacon has a goal, so the chip
-- never competes with the new-player beacon. Placement is Layout's "goal" region.
-- Snapshot data is the existing PlayerDataChanged push (NextGoal reads it); no new remote.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local NextGoal = require(Shared:WaitForChild("NextGoal"))
local UI = script.Parent.Parent:WaitForChild("UI")
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Layout = require(UI:WaitForChild("Layout"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local OnboardingController = require(script.Parent:WaitForChild("OnboardingController"))

local C = HudTheme.Colors
local player = Players.LocalPlayer

local NextGoalController = {}
NextGoalController.Priority = 86 -- after OnboardingController (85): reads its beacon state

type Row = {
	frame: Frame,
	icon: TextLabel,
	name: TextLabel,
	value: TextLabel,
	fill: Frame,
	silhouette: ViewportFrame, -- Vehicle goals: the next boat's shape, dark (docs/16 K6)
}

local SILHOUETTE = Color3.fromRGB(20, 26, 36)

local gui: ScreenGui
local region: Frame
local chip: TextButton
local chipRow: Frame
local icon: TextLabel
local iconScale: UIScale
local chipParts: Row
local fill: Frame
local info: TextButton
local infoRows: { Row } = {}
local snapshot: { [string]: any }? = nil
local shown = false
local hasGoal = false
local infoOpen = false
local infoSerial = 0
local lastKey: string? = nil
local lastFraction = 0
local lastPulseAt = 0
local PEEK = 6 -- s on screen after the goal moves -- tune
local peekUntil = 0
local seenKey: string? = nil
local seenValue: number? = nil

local function numberText(goal: NextGoal.Goal): string
	return `{HudTheme.formatNumber(goal.value)} / {HudTheme.formatNumber(goal.target)}`
end

-- The boat's preview model (VehicleService fills ReplicatedStorage.VehiclePreviews), side on, tinted
-- dark. Without a preview yet the star icon stays.
local function showSilhouette(vp: ViewportFrame, vehicleId: string): boolean
	if vp:GetAttribute("VehicleId") == vehicleId then
		return true
	end
	local folder = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	local source = folder and folder:FindFirstChild(vehicleId)
	if not (source and source:IsA("Model")) then
		return false
	end
	vp:ClearAllChildren()
	local model = source:Clone()
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(cf.Position + cf.RightVector * size.Magnitude * 1.9, cf.Position)
	camera.Parent = vp
	vp.CurrentCamera = camera
	vp:SetAttribute("VehicleId", vehicleId)
	return true
end

local function paint(row: Row, goal: NextGoal.Goal)
	local boat = goal.vehicleId ~= nil and showSilhouette(row.silhouette, goal.vehicleId)
	row.silhouette.Visible = boat
	row.icon.Text = if boat then "" else "★"
	row.icon.TextColor3 = if goal.kind == "Rank" then C.gold else C.accent
	row.name.Text = goal.label
	row.value.Text = numberText(goal)
end

local function pulse()
	lastPulseAt = os.clock()
	AudioController.play("Logbook_Chime", nil, 0.5, 1.04)
	iconScale.Scale = 1
	TweenService:Create(
		iconScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1.35 }
	):Play()
	task.delay(0.14, function()
		TweenService:Create(
			iconScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)
	fill.BackgroundColor3 = C.ready
	TweenService:Create(fill, TweenInfo.new(0.6), { BackgroundColor3 = C.bar }):Play()
end

local function paintInfo(goals: { NextGoal.Goal })
	for i, row in infoRows do
		local goal = goals[i]
		row.frame.Visible = goal ~= nil
		if goal then
			paint(row, goal)
			row.fill.Size = UDim2.fromScale(goal.fraction, 1)
		end
	end
end

local function setInfo(open: boolean)
	infoOpen = open and shown
	info.Visible = infoOpen
	infoSerial += 1
	if infoOpen then
		local serial = infoSerial
		task.delay(8, function()
			if serial == infoSerial then
				setInfo(false)
			end
		end)
	end
end

local function setShown(value: boolean)
	if value == shown then
		return
	end
	shown = value
	region.Visible = value
	if not value then
		setInfo(false)
	end
end

local function refreshShown()
	setShown(
		snapshot ~= nil
			and hasGoal
			and (infoOpen or os.clock() < peekUntil)
			and not Layout.coldOpen()
			and not OnboardingController.beaconActive()
			and not (Layout.current().touch and Layout.promptBusy())
	)
end

local function checkPulse(goal: NextGoal.Goal?)
	if not goal or not shown or not lastKey then
		return
	end
	local finished = (goal.fraction >= 1 and lastFraction < 1)
		or (goal.key ~= lastKey and lastFraction >= 1)
	if finished and os.clock() - lastPulseAt > 4 then
		pulse()
	end
end

local function render()
	if not snapshot then
		return
	end
	local goals = NextGoal.goals(snapshot)
	local best = goals[1]
	hasGoal = best ~= nil
	local changed = best ~= nil and best.key ~= lastKey
	if best then
		paint(chipParts, best)
		if changed then
			chipRow.Position = UDim2.fromOffset(16, 0)
			TweenService:Create(
				chipRow,
				TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(0, 0) }
			):Play()
		end
		TweenService:Create(
			fill,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad),
			{ Size = UDim2.fromScale(best.fraction, 1) }
		):Play()
	end
	if infoOpen then
		paintInfo(goals)
	end
	if best and (best.key ~= seenKey or best.value ~= seenValue) then
		seenKey, seenValue = best.key, best.value
		peekUntil = os.clock() + PEEK
	end
	refreshShown()
	checkPulse(best)
	lastKey = if best then best.key else nil
	lastFraction = if best then best.fraction else 0
	refreshShown()
end

local function onData(data: any)
	if type(data) ~= "table" then
		return
	end
	snapshot = data
	render()
end

local function buildRow(parent: Instance, height: number): Row
	local frame = Instance.new("Frame")
	frame.Name = "Goal"
	frame.Size = UDim2.new(1, 0, 0, height)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local rowIcon =
		HudTheme.label("Icon", "", UDim2.fromOffset(22, 22), HudTheme.HeaderFont, 18, frame)
	rowIcon.Position = UDim2.fromOffset(0, 4)
	rowIcon.TextXAlignment = Enum.TextXAlignment.Center
	local rowName =
		HudTheme.label("Name", "", UDim2.fromOffset(80, 16), HudTheme.BodyFont, 13, frame)
	rowName.Position = UDim2.fromOffset(30, 0)
	rowName.TextColor3 = C.textDim
	local rowValue =
		HudTheme.label("Value", "", UDim2.fromOffset(130, 18), HudTheme.HeaderFont, 15, frame)
	rowValue.AnchorPoint = Vector2.new(1, 0)
	rowValue.Position = UDim2.new(1, 0, 0, 2)
	rowValue.TextXAlignment = Enum.TextXAlignment.Right
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(30, height - 6)
	bar.Size = UDim2.new(1, -30, 0, 3)
	bar.BackgroundColor3 = C.locked
	bar.BorderSizePixel = 0
	bar.Parent = frame
	local rowFill = Instance.new("Frame")
	rowFill.Name = "Fill"
	rowFill.Size = UDim2.fromScale(0, 1)
	rowFill.BackgroundColor3 = C.bar
	rowFill.BorderSizePixel = 0
	rowFill.Parent = bar
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Silhouette"
	vp.Position = UDim2.fromOffset(-6, 0)
	vp.Size = UDim2.fromOffset(34, 30)
	vp.BackgroundTransparency = 1
	vp.Ambient = SILHOUETTE
	vp.LightColor = SILHOUETTE
	vp.ImageColor3 = SILHOUETTE
	vp.Visible = false
	vp.Parent = frame
	return {
		frame = frame,
		icon = rowIcon,
		name = rowName,
		value = rowValue,
		fill = rowFill,
		silhouette = vp,
	}
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "NextGoal"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	region = Layout.region(gui, "goal")
	region.Visible = false

	chip = Instance.new("TextButton")
	chip.Name = "GoalChip"
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = C.panel
	chip.BackgroundTransparency = HudTheme.PanelTransparency
	chip.BorderSizePixel = 0
	chip.AutoButtonColor = false
	chip.Text = ""
	HudTheme.corner(chip)
	HudTheme.stroke(chip)
	HudTheme.padding(chip, 8)
	chip.Parent = region

	-- the open glyph sits left of the chip, clear of the right-hand column
	local glyph = InputGlyph.chip(region, Enum.KeyCode.I, Enum.KeyCode.ButtonR1)
	glyph.AnchorPoint = Vector2.new(1, 0)
	glyph.Position = UDim2.fromOffset(-4, 8)

	chipRow = Instance.new("Frame")
	chipRow.Name = "Content"
	chipRow.Size = UDim2.fromScale(1, 1)
	chipRow.BackgroundTransparency = 1
	chipRow.Parent = chip
	local row = buildRow(chipRow, 28)
	-- the chip has one row; keep its parts as named locals
	icon = row.icon
	chipParts = row
	fill = row.fill
	iconScale = Instance.new("UIScale")
	iconScale.Parent = icon

	info = Instance.new("TextButton")
	info.Name = "GoalInfo"
	info.AnchorPoint = Vector2.new(1, 0)
	info.Position = UDim2.new(1, 0, 0, 52)
	info.Size = UDim2.fromOffset(260, 100)
	info.BackgroundColor3 = C.panel
	info.BackgroundTransparency = HudTheme.PromptTransparency
	info.BorderSizePixel = 0
	info.AutoButtonColor = false
	info.Text = ""
	HudTheme.corner(info)
	HudTheme.stroke(info)
	HudTheme.padding(info, 8)
	info.Visible = false
	info.Parent = region
	for i = 1, 2 do
		local r = buildRow(info, 38)
		r.frame.Position = UDim2.fromOffset(0, (i - 1) * 42)
		table.insert(infoRows, r)
	end

	chip.Activated:Connect(function()
		setInfo(not infoOpen)
	end)
	info.Activated:Connect(function()
		setInfo(false)
	end)
end

function NextGoalController.Init()
	build()
	Net.event("PlayerDataChanged").OnClientEvent:Connect(onData)
	Layout.onColdOpen(refreshShown)
	Layout.onPromptBusy(refreshShown)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local key = input.KeyCode
		if not hasGoal or (key ~= Enum.KeyCode.I and key ~= Enum.KeyCode.ButtonR1) then
			return
		end
		-- I is free; RB belongs to photo mode zoom / product-card paging while those are up
		if key == Enum.KeyCode.ButtonR1 and processed then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if not shown then
			peekUntil = os.clock() + PEEK
			refreshShown()
		end
		setInfo(not infoOpen)
	end)
end

function NextGoalController.Start()
	local getData = Net.init():WaitForChild("Progression_GetData", 30)
	if getData and getData:IsA("RemoteFunction") then
		task.spawn(function()
			for _ = 1, 10 do
				local ok, data = pcall(function()
					return getData:InvokeServer()
				end)
				if snapshot then
					return -- a push arrived first
				end
				if ok and type(data) == "table" then
					onData(data)
					return
				end
				task.wait(1)
			end
		end)
	end
	-- the beacon has no event of its own; a slow poll keeps the chip out of its way
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			refreshShown()
		end
	end)
end

return NextGoalController
