--!strict
-- ExerciseBoardController (RP-C1b): wires the station exercise board (ExerciseBoardService on the
-- server builds it, with a ProximityPrompt whose attribute Panel = "ExerciseBoard").
--   * The prompt opens the board read up close (UI/ExerciseBoard): this player's status per
--     exercise, the certification requirements and Start. Walking away, Escape or ButtonB closes it.
--   * Start fires Ops_StartExercise(exerciseId); the server gates it (OperationService
--     .StartExercise) and answers a refusal with Ops_ExerciseRefused { exerciseId, reason }. The
--     player attribute OpsExercise (the running exercise id) closes the board when it starts.
--   * Diegetic: each passed exercise's pinned sheet gets a red "PASSED" stamp with the best grade
--     (a local SurfaceGui on the sheet, so every player sees their own).
-- Data: PlayerDataChanged snapshots (ProgressionRules.snapshot), pulled once via Progression_GetData.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Exercises =
	require(Shared:WaitForChild("Ops"):WaitForChild("Definitions"):WaitForChild("Exercises"))
local Net = require(Shared:WaitForChild("Net"))
local Remotes = require(Shared:WaitForChild("Ops"):WaitForChild("Remotes"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local UI = script.Parent.Parent:WaitForChild("UI")
local ExerciseBoard = require(UI:WaitForChild("ExerciseBoard"))
local Layout = require(UI:WaitForChild("Layout"))

local ExerciseBoardController = {}

local BOARD_NAME = "StationExerciseBoard"
local WALK_AWAY = 14 -- studs from the board before it closes
local STAMP_RED = Color3.fromRGB(176, 36, 32)

local player = Players.LocalPlayer
local gui: ScreenGui
local board: ExerciseBoard.Board
local snapshot: { [string]: any }? = nil
local anchor: BasePart? = nil
local stamps: { [string]: SurfaceGui } = {}

local function rows(): { Exercises.BoardRow }
	local data = Rules.fromSnapshot(snapshot or {})
	return Exercises.board(data, player:GetAttribute("OpsExercise") ~= nil)
end

-- the red rubber stamp on each passed exercise's sheet (local to this player)
local function paintStamps()
	local model = Workspace:FindFirstChild(BOARD_NAME)
	if not model then
		return
	end
	local exercises = if snapshot and type(snapshot.exercises) == "table"
		then snapshot.exercises
		else {}
	for _, id in Exercises.Order do
		local sheet = model:FindFirstChild(`Sheet_{id}`)
		local best = exercises[id]
		local s = stamps[id]
		if best and sheet and sheet:IsA("BasePart") then
			if not s or s.Adornee ~= sheet then
				if s then
					s:Destroy()
				end
				local ns = Instance.new("SurfaceGui")
				ns.Name = `ExerciseStamp_{id}`
				ns.Face = Enum.NormalId.Front
				ns.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				ns.PixelsPerStud = 150
				ns.LightInfluence = 1
				ns.MaxDistance = 40
				ns.ZOffset = 1
				ns.Adornee = sheet
				local l = Instance.new("TextLabel")
				l.Name = "Stamp"
				l.BackgroundTransparency = 1
				l.AnchorPoint = Vector2.new(1, 0)
				l.Position = UDim2.new(1, -10, 0, 30)
				l.Size = UDim2.fromOffset(120, 34)
				l.Rotation = -8
				l.FontFace =
					Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold)
				l.TextSize = 20
				l.TextColor3 = STAMP_RED
				l.TextTransparency = 0.15
				local stroke = Instance.new("UIStroke")
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Color = STAMP_RED
				stroke.Thickness = 2
				stroke.Transparency = 0.2
				stroke.Parent = l
				l.Parent = ns
				ns.Parent = gui
				stamps[id] = ns
				s = ns
			end
			local label = (s :: SurfaceGui):FindFirstChild("Stamp") :: TextLabel
			label.Text = `PASSED  {string.upper(best)}`
		elseif s then
			s:Destroy()
			stamps[id] = nil
		end
	end
end

local function refresh()
	if board.isOpen() then
		board.update(rows())
	end
	paintStamps()
end

local function setOpen(value: boolean)
	board.setOpen(value)
	if value then
		board.update(rows())
		if UserInputService.GamepadEnabled then
			GuiService.SelectedObject = board.firstButton()
		end
	else
		anchor = nil
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(board.frame) then
			GuiService.SelectedObject = nil
		end
	end
end

local function onStart(exerciseId: string)
	board.notice("Telling Chief Aggie...")
	Remotes.event("Ops_StartExercise"):FireServer(exerciseId)
end

local function onPromptTriggered(prompt: ProximityPrompt)
	if prompt:GetAttribute("Panel") ~= "ExerciseBoard" then
		return
	end
	local part = prompt.Parent
	if not (part and part:IsA("BasePart")) then
		return
	end
	anchor = part
	setOpen(true)
end

local function watch()
	if not board.isOpen() then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local a = anchor
	if
		Layout.coldOpen()
		or not (root and root:IsA("BasePart") and a and a.Parent)
		or (root.Position - a.Position).Magnitude > WALK_AWAY
	then
		setOpen(false)
	end
end

function ExerciseBoardController.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "ExerciseBoard"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 24 -- above the Ops call card / debrief (15-22), below Cinematic (50)
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	board = ExerciseBoard.build(gui, onStart)
	-- the Close button closes through here too (selection and anchor reset)
	board.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not board.frame.Visible and anchor then
			setOpen(false)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	UserInputService.InputBegan:Connect(function(input)
		if
			board.isOpen()
			and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB)
		then
			setOpen(false)
		end
	end)
	RunService.Heartbeat:Connect(watch)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			snapshot = data
			refresh()
		end
	end)
	Remotes.event("Ops_ExerciseRefused").OnClientEvent:Connect(function(payload: any)
		if type(payload) == "table" and type(payload.reason) == "string" then
			board.notice(payload.reason)
		end
	end)
	-- an exercise starting closes the board (the step card takes over); the model may stream in late
	player:GetAttributeChangedSignal("OpsExercise"):Connect(function()
		if player:GetAttribute("OpsExercise") ~= nil and board.isOpen() then
			setOpen(false)
		end
		refresh()
	end)
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == BOARD_NAME then
			task.defer(paintStamps)
		end
	end)
end

function ExerciseBoardController.Start()
	task.spawn(function()
		local getData = Net.init():WaitForChild("Progression_GetData", 30)
		if not (getData and getData:IsA("RemoteFunction")) then
			return
		end
		for _ = 1, 10 do
			if snapshot then
				return
			end
			local ok, data = pcall(function()
				return getData:InvokeServer()
			end)
			if ok and type(data) == "table" then
				if not snapshot then
					snapshot = data
					refresh()
				end
				return
			end
			task.wait(1)
		end
	end)
end

return ExerciseBoardController
