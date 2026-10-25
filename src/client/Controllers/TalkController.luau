--!strict
-- TalkController: walk up to a town NPC (Workspace.Npcs child named in Shared/Dialogue.TREES), press Talk
-- (ProximityPrompt: E / X / tap) and the camera eases into an over-the-shoulder shot of them, they turn to
-- face you, and their line shows with up to three numbered replies (keys 1-3, tap, gamepad D-pad + A).
-- Quest givers (Quests/Data, QuestService) get their tree from Quests/Rules.talk at the moment you talk; a reply
-- with an `action` goes to the server (Quest_Talk). B, Esc, the close button or walking away ends it and the camera eases back. Not during an operation,
-- a cinematic or in a seat. The camera moves are Camera/Cinematic shots (CameraController owns the camera).
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Dialogue = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dialogue"))
local QuestData =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("Data"))
local QuestRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("Rules"))
local UI = script.Parent.Parent:WaitForChild("UI")
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local VoiceCast = require(UI:WaitForChild("VoiceCast"))
local VoiceTTS = require(script.Parent.VoiceTTS)

local TalkController = {}

local player = Players.LocalPlayer
local LEAVE_DISTANCE = 14 -- studs from the NPC: walking this far away ends the conversation
local EASE_IN, EASE_OUT = 0.8, 0.6 -- s
local TALK_FOV = 45
local TYPE_RATE = 60 -- characters per second the line types in at
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

local cameraController: any = nil
local opsController: any = nil
type Talk = {
	model: Model,
	tree: Dialogue.Tree,
	node: string,
	home: CFrame,
	back: CFrame,
}
local talking: Talk? = nil
-- every TalkPrompt; strong keys (a weak table loses Instance keys to GC while they live), pruned when destroyed
local prompts: { [ProximityPrompt]: true } = {}
local gui: ScreenGui
local panel: Frame
local nameLabel: TextLabel
local lineLabel: TextLabel
local list: Frame
local modal: InputGlyph.Modal
local typing = 0

local function rootOf(m: Model?): BasePart?
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function busy(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return talking ~= nil
		or (hum == nil or hum.SeatPart ~= nil or hum.Health <= 0)
		or player:GetAttribute("CinematicPlaying") == true
		or (opsController and opsController.GetState() ~= nil)
end

local finish: () -> ()
local show: (id: string?) -> ()

-- reply `i` of the shown node: a quest action goes to the server, then the next node (nil ends it)
local function pick(t: Talk, i: number)
	local node = Dialogue.node(t.tree, t.node)
	local option = node and node.options[i]
	if option and option.action then
		local remote = ReplicatedStorage:FindFirstChild("Net")
		remote = remote and remote:FindFirstChild("Quest_Talk")
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer(t.model.Name, option.action)
		end
	end
	show(Dialogue.choose(t.tree, t.node, i))
end

-- the model's tree: a town NPC's fixed one, or a quest giver's from the player's quest attributes
local function treeOf(m: Model): Dialogue.Tree?
	if QuestData.npcById[m.Name] then
		return QuestRules.talk(
			m.Name,
			player:GetAttribute("QuestId") :: string?,
			player:GetAttribute("QuestStage") :: string?,
			player:GetAttribute(`QuestOffer_{m.Name}`) :: string?
		)
	end
	return Dialogue.TREES[m.Name]
end

show = function(id: string?)
	local t = talking
	local node = t and id and Dialogue.node(t.tree, id)
	if not (t and id and node) then
		finish()
		return
	end
	t.node = id
	lineLabel.Text = node.line
	lineLabel.MaxVisibleGraphemes = 0
	VoiceTTS.speak(
		node.line,
		t.tree.cast or VoiceCast.castFor(t.tree.name, "AGGIE"),
		{ at = t.model, channel = "talk" }
	)
	typing = 0
	for _, c in list:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	local first: GuiButton? = nil
	for i, o in node.options do
		local b = HudTheme.button(`Reply{i}`, `{i}   {o.text}`, UDim2.new(1, 0, 0, 44), list)
		b.LayoutOrder = i
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.BackgroundColor3 = HudTheme.Colors.panelLight
		HudTheme.padding(b, 12)
		b.Activated:Connect(function()
			if talking == t then
				pick(t, i)
			end
		end)
		first = first or b
	end
	modal.open(first)
end

local function onKey(
	_: string,
	state: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	local t = talking
	if state ~= Enum.UserInputState.Begin or not t then
		return Enum.ContextActionResult.Pass
	end
	local i = table.find(KEYS, input.KeyCode)
	if i and list:FindFirstChild(`Reply{i}`) then
		pick(t, i) -- same as a click on that reply
	end
	return Enum.ContextActionResult.Sink -- keep 1-3 off the backpack hotbar while talking
end

local function begin(model: Model, tree: Dialogue.Tree)
	local npcRoot, me = rootOf(model), rootOf(player.Character)
	local cam = Workspace.CurrentCamera
	if busy() or not (npcRoot and me) then
		return
	end
	local home = model:GetPivot()
	-- the NPC turns to face the player (local only; the server's next move overrides it)
	local npcPos = home.Position
	local toMe = (me.Position - npcPos) * Vector3.new(1, 0, 1)
	if toMe.Magnitude > 0.1 then
		model:PivotTo(CFrame.lookAt(npcPos, npcPos + toMe))
	end
	-- over the player's right shoulder, framing the NPC's face
	local ahead = (npcRoot.Position - me.Position) * Vector3.new(1, 0, 1)
	ahead = if ahead.Magnitude > 0.1 then ahead.Unit else me.CFrame.LookVector
	local right = ahead:Cross(Vector3.yAxis)
	local eye = me.Position + Vector3.new(0, 2, 0) - ahead * 3.5 + right * 2.6
	local face = npcRoot.Position + Vector3.new(0, 0.4, 0) - right * 0.3 -- below the face: it sits above the reply panel
	local shot = CFrame.lookAt(eye, face)
	talking = {
		model = model,
		tree = tree,
		home = home,
		back = me.CFrame:ToObjectSpace(cam.CFrame),
		node = tree.start,
	}
	cameraController.PlayCinematic({
		{
			from = cam.CFrame,
			to = shot,
			duration = EASE_IN,
			fov = cam.FieldOfView,
			toFov = TALK_FOV,
			handheld = 0.1,
		},
		{
			from = shot,
			to = shot,
			duration = 1e6,
			fov = TALK_FOV,
			toFov = TALK_FOV,
			handheld = 0.1,
		},
	}, { skippable = false })
	nameLabel.Text = tree.name
	gui.Enabled = true
	ContextActionService:BindActionAtPriority(
		"Talk_Reply",
		onKey,
		false,
		Enum.ContextActionPriority.High.Value + 5,
		Enum.KeyCode.One,
		Enum.KeyCode.Two,
		Enum.KeyCode.Three
	)
	show(tree.start)
end

finish = function()
	local t = talking
	if not t then
		return
	end
	talking = nil
	VoiceTTS.stop("talk")
	gui.Enabled = false
	modal.close()
	ContextActionService:UnbindAction("Talk_Reply")
	if t.model.Parent then
		t.model:PivotTo(t.home)
	end
	local me = rootOf(player.Character)
	local cam = Workspace.CurrentCamera
	if me and player:GetAttribute("CinematicPlaying") == true then
		-- ease back to the view the player had, relative to where they stand now
		cameraController.PlayCinematic({
			{
				from = cam.CFrame,
				to = me.CFrame * t.back,
				duration = EASE_OUT,
				fov = cam.FieldOfView,
				toFov = 70,
				handheld = 0,
			},
		}, { skippable = false })
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Talk"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 55 -- above the Cinematic letterbox
	gui.Enabled = false
	gui:SetAttribute("CinematicKeep", true) -- OpsController hides every other ScreenGui during the shot
	-- box: the panel plus a close button pinned to its top-right corner (out of the panel's list layout)
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -20)
	box.Size = UDim2.fromScale(0.9, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(560, math.huge)
	cap.Parent = box
	box.Parent = gui
	panel = HudTheme.panel("Panel", UDim2.fromScale(1, 0), box)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = HudTheme.PromptTransparency
	HudTheme.padding(panel, 14)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	nameLabel = HudTheme.label(
		"Name",
		"",
		UDim2.new(1, -44, 0, 22),
		HudTheme.HeaderFont,
		HudTheme.TextSize.small,
		panel
	)
	nameLabel.TextColor3 = HudTheme.Colors.accent
	nameLabel.LayoutOrder = 1
	lineLabel = HudTheme.label(
		"Line",
		"",
		UDim2.fromScale(1, 0),
		HudTheme.BodyFont,
		HudTheme.TextSize.title,
		panel
	)
	lineLabel.AutomaticSize = Enum.AutomaticSize.Y
	lineLabel.TextWrapped = true
	lineLabel.TextTruncate = Enum.TextTruncate.None
	lineLabel.LayoutOrder = 2
	list = Instance.new("Frame")
	list.Name = "Replies"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 3
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	list.Parent = panel
	local close = HudTheme.button("Close", "X", UDim2.fromOffset(36, 36), box)
	close.BackgroundColor3 = HudTheme.Colors.panelLight
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.ZIndex = 2
	close.Activated:Connect(function()
		finish()
	end)
	modal = InputGlyph.modal("Talk", function()
		finish()
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function watch(m: Instance)
	local tree = if m:IsA("Model") then treeOf(m) else nil
	if not tree then
		return
	end
	-- the root streams in late (cold open at sea) and is rebuilt after a stream-out: attach on every arrival
	local function attach(root: Instance)
		if
			root.Name ~= "HumanoidRootPart"
			or not root:IsA("BasePart")
			or root:FindFirstChild("TalkPrompt")
		then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TalkPrompt"
		prompt.ActionText = "Talk"
		prompt.ObjectText = tree.name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt:SetAttribute("FootOnly", true)
		prompt.Triggered:Connect(function()
			local now = treeOf(m :: Model) -- a quest giver's tree changes with your quest
			if now then
				begin(m :: Model, now)
			end
		end)
		prompt.Parent = root
		prompts[prompt] = true
	end
	m.ChildAdded:Connect(attach)
	local root = m:FindFirstChild("HumanoidRootPart")
	if root then
		attach(root)
	end
end

function TalkController.Start()
	cameraController =
		require(script.Parent:WaitForChild("CameraController") :: ModuleScript) :: any
	opsController = require(script.Parent:WaitForChild("OpsController") :: ModuleScript) :: any
	build()
	RunService.RenderStepped:Connect(function(dt: number)
		-- no Talk prompt while one can't start (seated in a boat, a call offer, a cutscene): it used to show and do nothing
		local free = not busy()
		for p in prompts do
			if p.Parent then
				p.Enabled = free
			else
				prompts[p] = nil -- its root streamed out or was rebuilt
			end
		end
		local t = talking
		if not t then
			return
		end
		typing += dt * TYPE_RATE
		lineLabel.MaxVisibleGraphemes = if typing >= #lineLabel.Text then -1 else math.floor(typing)
		local me, npc = rootOf(player.Character), rootOf(t.model)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if
			not (me and npc and hum and hum.Health > 0 and hum.SeatPart == nil)
			or (me.Position - npc.Position).Magnitude > LEAVE_DISTANCE
			or (opsController and opsController.GetState() ~= nil)
		then
			finish()
		end
	end)
	-- Esc opens the Roblox menu (a game cannot bind it): leaving for the menu ends the conversation
	GuiService.MenuOpened:Connect(function()
		finish()
	end)
	local npcs = Workspace:WaitForChild("Npcs")
	npcs.ChildAdded:Connect(function(c)
		task.spawn(watch, c)
	end)
	for _, c in npcs:GetChildren() do
		task.spawn(watch, c)
	end
end

return TalkController
