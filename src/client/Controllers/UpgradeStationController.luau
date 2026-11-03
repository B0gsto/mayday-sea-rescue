--!strict
-- UpgradeStationController (docs/30 section 2): the Upgrade Station's board and the level-up moment. Every station's
-- board shows YOUR boat: Lv N / 50, a full bar with the five hull stages marked, the next level's jump, its price, your
-- Cash and what is missing. The button is the green Part's prompt (PromptCueController's kit pill: tap, key, gamepad),
-- in range from the bay and on foot. The moment plays on your boat, locally anchored: up, a spin, the VFXKit blast at
-- the top while the server swaps in the new boat, the slam. Reduced motion: a small lift, no spin, no shake.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatLevels = require(Shared:WaitForChild("BoatLevels"))
local Net = require(Shared:WaitForChild("Net"))
local UpgradeStation = require(Shared:WaitForChild("UpgradeStation"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Theme = require(UI:WaitForChild("Kit"):WaitForChild("Theme"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local UpgradeStationController = {}
local player = Players.LocalPlayer

local PPS = 25 -- SurfaceGui pixels a stud: the 44 x 28 board is 1100 x 700
local LIFT = 16 -- studs at x1 scale -- tune
local RED = Color3.fromRGB(255, 96, 86)
local GREEN = Color3.fromRGB(120, 240, 130)

type Board = {
	level: TextLabel,
	fill: Frame,
	next: TextLabel,
	speed: TextLabel,
	room: TextLabel,
	price: TextLabel,
	cash: TextLabel,
	missing: TextLabel,
	scale: UIScale,
	prompt: ProximityPrompt?,
	action: TextLabel,
}

local boards: { Board } = {}
local snapshot: { [string]: any }? = nil

local function text(
	parent: Instance,
	at: UDim2,
	size: UDim2,
	xAlign: Enum.TextXAlignment?
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	label.Position = at
	label.Size = size
	label.Parent = parent
	Style.stroke(label, 5)
	return label
end

local function icon(parent: Instance, name: string, at: UDim2, size: number)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Position = at
	box.Size = UDim2.fromOffset(size, size)
	box.Parent = parent
	Style.icon(box, name)
end

local function buildBoard(part: BasePart, button: BasePart?, prompt: ProximityPrompt?): Board
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoatBoard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.MaxDistance = 900
	gui.Parent = part
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local level = text(root, UDim2.fromOffset(40, 16), UDim2.fromOffset(1020, 130))
	-- the bar: every stage's start marked, so how far is left is plain
	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Colors.ink
	track.Position = UDim2.fromOffset(40, 156)
	track.Size = UDim2.fromOffset(1020, 60)
	Style.corner(track, 30)
	track.Parent = root
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.fromScale(0, 1)
	Style.corner(fill, 30)
	Style.gradient(fill, Style.grad("green"))
	fill.Parent = track
	for _, stage in BoatLevels.Stages do
		local x = BoatLevels.progress(stage.first)
		if stage.first > 1 then
			local tick = Instance.new("Frame")
			tick.BackgroundColor3 = Color3.new(1, 1, 1)
			tick.BorderSizePixel = 0
			tick.Position = UDim2.new(x, -3, 0, 0)
			tick.Size = UDim2.new(0, 6, 1, 0)
			tick.Parent = track
		end
		local name = text(
			root,
			UDim2.fromOffset(40 + 1020 * x, 220),
			UDim2.fromOffset(210, 48),
			Enum.TextXAlignment.Left
		)
		name.Text = stage.name
	end
	-- the next level: the piece, then its jumps with icons
	local nextLabel = text(root, UDim2.fromOffset(40, 276), UDim2.fromOffset(1020, 72))
	icon(root, "boost", UDim2.fromOffset(70, 356), 110)
	local speed =
		text(root, UDim2.fromOffset(190, 362), UDim2.fromOffset(350, 100), Enum.TextXAlignment.Left)
	icon(root, "crew", UDim2.fromOffset(580, 356), 110)
	local room =
		text(root, UDim2.fromOffset(700, 362), UDim2.fromOffset(350, 100), Enum.TextXAlignment.Left)
	-- price, your Cash, what is missing
	icon(root, "cash", UDim2.fromOffset(40, 484), 100)
	local price =
		text(root, UDim2.fromOffset(150, 488), UDim2.fromOffset(330, 92), Enum.TextXAlignment.Left)
	local cash =
		text(root, UDim2.fromOffset(500, 488), UDim2.fromOffset(560, 92), Enum.TextXAlignment.Right)
	local missing = text(root, UDim2.fromOffset(40, 586), UDim2.fromOffset(1020, 96))
	local scale = Instance.new("UIScale")
	scale.Parent = missing
	-- the green button's own label
	local action = Instance.new("TextLabel")
	if button then
		local face = Instance.new("SurfaceGui")
		face.Name = "BoatButton"
		face.Face = Enum.NormalId.Front
		face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		face.PixelsPerStud = PPS
		face.LightInfluence = 0
		face.MaxDistance = 900
		face.Parent = button
		action.BackgroundTransparency = 1
		action.Font = Enum.Font.FredokaOne
		action.TextColor3 = Color3.new(1, 1, 1)
		action.TextScaled = true
		action.Position = UDim2.fromScale(0.1, 0.1)
		action.Size = UDim2.fromScale(0.8, 0.8)
		action.Parent = face
		Style.stroke(action, 6)
	end
	return {
		level = level,
		fill = fill,
		next = nextLabel,
		speed = speed,
		room = room,
		price = price,
		cash = cash,
		missing = missing,
		scale = scale,
		prompt = prompt,
		action = action,
	}
end

local function refresh()
	local snap = snapshot
	if not snap then
		return
	end
	local row = BoatLevels.row(snap.boatLevel)
	local nextRow = BoatLevels.nextRow(snap.boatLevel)
	local money = tonumber(snap.cash) or 0
	for _, b in boards do
		b.level.Text = `Lv {row.level} / {BoatLevels.MAX}`
		b.fill.Size = UDim2.fromScale(math.max(BoatLevels.progress(row.level), 0.04), 1)
		b.cash.Text = `You {Theme.short(math.floor(money))}`
		if b.prompt then
			b.prompt.Enabled = nextRow ~= nil
		end
		if nextRow then
			b.next.Text = if nextRow.hull ~= row.hull
				then `New boat: {BoatLevels.Stages[nextRow.stage].name}!`
				else nextRow.piece
			b.speed.Text = `{row.speed} -> {nextRow.speed}`
			b.room.Text = `{row.room} -> {nextRow.room}`
			b.price.Text = Theme.short(nextRow.price)
			local short = nextRow.price - money
			b.missing.Text = if short > 0
				then `Need {Theme.short(math.ceil(short))} more`
				else "Ready!"
			b.missing.TextColor3 = if short > 0 then RED else GREEN
			b.action.Text = "Upgrade"
		else
			b.next.Text = "Top of the ladder"
			b.speed.Text = `{row.speed}`
			b.room.Text = `{row.room}`
			b.price.Text = "-"
			b.missing.Text = "Max!"
			b.missing.TextColor3 = GREEN
			b.action.Text = "Max"
		end
	end
end

-- One pop on what is missing when the Cash is short (no flash).
local function popMissing()
	for _, b in boards do
		b.scale.Scale = 1.18
		TweenService:Create(b.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 })
			:Play()
	end
end

-- The moment, on the owner's own screen. The server's "Swap" retargets it to the new boat mid-air.
type Moment = { model: Model?, started: number, level: number, rest: { [Model]: CFrame } }
local running: Moment? = nil

local function pose(run: Moment, model: Model, t: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local rest = run.rest[model]
	if not rest then
		rest = model:GetPivot()
		run.rest[model] = rest
		root.Anchored = true -- local only: the owner simulates this hull, nobody else sees it hold
	end
	local lift, spin, tilt = UpgradeStation.pose(t, Comfort.reducedMotion())
	local scale = BoatLevels.row(run.level).scale
	model:PivotTo(
		(rest :: CFrame)
			* CFrame.new(0, lift * LIFT * scale, 0)
			* CFrame.Angles(0, spin, 0)
			* CFrame.Angles(tilt, 0, 0)
	)
end

local function finish(run: Moment)
	for model, rest in run.rest do
		local root = model.PrimaryPart
		if root and model.Parent then
			model:PivotTo(rest)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.Anchored = false
		end
	end
	if running == run then
		running = nil
	end
end

local function start(model: Model?, level: number)
	local run: Moment = { model = model, started = os.clock(), level = level, rest = {} }
	running = run
	local blasted = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - run.started
		if running ~= run or t >= UpgradeStation.MOMENT then
			connection:Disconnect()
			finish(run)
			return
		end
		local m = run.model
		if m and m.Parent then
			pose(run, m, t)
			if not blasted and t >= UpgradeStation.BLAST_AT then
				blasted = true
				VFXKit.play(
					"boat_levelup",
					m:GetPivot(),
					{ radius = 10 * BoatLevels.row(level).scale }
				)
			end
		end
	end)
end

local function onMoment(kind: string, ownerId: number, model: Model?, level: number)
	if ownerId ~= player.UserId then
		if kind == "Swap" and model then
			VFXKit.play("boat_levelup", model:GetPivot(), { still = true })
		end
		return
	end
	if kind == "Start" then
		start(model, level)
	elseif running and model then
		running.model = model
	end
end

local function hook(stationModel: Instance)
	local board = stationModel:WaitForChild("Board", 10)
	local button = stationModel:WaitForChild("Button", 10)
	if not (board and board:IsA("BasePart") and button and button:IsA("BasePart")) then
		return
	end
	local prompt = button:WaitForChild("UpgradeBoat", 10)
	table.insert(
		boards,
		buildBoard(board, button, if prompt and prompt:IsA("ProximityPrompt") then prompt else nil)
	)
	refresh()
end

function UpgradeStationController.Start()
	Net.event("BoatLevelMoment").OnClientEvent:Connect(onMoment)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(raw: any)
		if type(raw) == "table" then
			snapshot = raw
			refresh()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if prompt.Name ~= "UpgradeBoat" or who ~= player then
			return
		end
		local ok, reason = Net.func("Boat_LevelUp"):InvokeServer()
		if not ok and reason == "Need Cash" then
			popMissing()
			AudioController.play("UI_Prompt")
		end
	end)
	task.spawn(function()
		local remote = Net.init():WaitForChild("Progression_GetData", 10)
		if remote and remote:IsA("RemoteFunction") then
			local ok, raw = pcall(function()
				return remote:InvokeServer()
			end)
			if ok and type(raw) == "table" then
				snapshot = raw
				refresh()
			end
		end
	end)
	local folder = Workspace:WaitForChild("UpgradeStations", 60)
	if folder then
		for _, station in folder:GetChildren() do
			task.spawn(hook, station)
		end
		folder.ChildAdded:Connect(hook)
	end
end

return UpgradeStationController
