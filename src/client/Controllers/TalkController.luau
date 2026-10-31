--!strict
-- TalkController: walk up to a quest giver (Workspace.Npcs child named in Quests/Data), press Talk
-- (ProximityPrompt: E / X / tap) and the camera eases into an over-the-shoulder shot of them, they turn to
-- face you, and their line shows with up to three numbered replies (keys 1-3, tap, gamepad D-pad + A).
-- Quest givers (Quests/Data, QuestService) moored at your own island get their tree from Quests/Rules.talk at the
-- moment you talk; a reply with an `action` goes to the server (Quest_Talk). At someone else's island (rig attribute
-- QuestIsland ~= your DockPlot) or sailing off they only say their idle line. B, Esc, the close button or walking away ends it and the camera eases back. Not during an operation,
-- a cinematic or in a seat. The camera moves are Camera/Cinematic shots (CameraController owns the camera).
-- Alive without clips (Talk/TalkPose, Transform turns on top of the stock Idle): a giver glances round, turns
-- their head to you when you come near, eases round to face you while you talk, nods and bobs through a line and
-- makes one gesture per line (nod, shrug, point, arms wide).
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
local TalkPose = require(script.Parent:WaitForChild("Talk"):WaitForChild("TalkPose"))
local VoiceTTS = require(script.Parent.VoiceTTS)

local TalkController = {}

local player = Players.LocalPlayer
local LEAVE_DISTANCE = 14 -- studs from the NPC: walking this far away ends the conversation
local EASE_IN, EASE_OUT = 0.8, 0.6 -- s
local TALK_FOV = 45
local TYPE_RATE = 60 -- characters per second the line types in at
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local LOOK_RANGE = 28 -- studs: a giver turns their head to you this close
local ALIVE_RANGE = 150 -- studs from the camera: past this nobody sees the head, so no turns
local TURN_RATE = 6 -- 1/s: how fast the body eases round to face you (and back)
local GESTURE_DELAY = 0.15 -- s after a line starts: the gesture lands with the voice

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
-- every quest giver's procedural pose state
type Rig = {
	seed: number,
	yaw: number,
	pitch: number,
	face: CFrame?, -- rotation the body eases to: toward you while talking, back home after
	gi: number, -- the gesture of the line shown (TalkPose.GESTURES, cycling)
	gAt: number, -- os.clock() it starts
	joints: { [string]: Instance },
	scanAt: number,
	held: { [Instance]: { CFrame } }, -- joint -> { the Animator's Transform, the one written here }
}
local rigs: { [Model]: Rig } = {}
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

-- a quest giver's tree from the player's quest attributes (nil: not a giver)
local function treeOf(m: Model): Dialogue.Tree?
	if not QuestData.npcById[m.Name] then
		return nil
	elseif
		m:GetAttribute("QuestIsland") ~= player:GetAttribute("DockPlot")
		or m:GetAttribute("Leaving")
	then
		return QuestRules.talk(m.Name, nil, nil, nil) -- not my giver: the idle line, no actions
	else
		return QuestRules.talk(
			m.Name,
			player:GetAttribute("QuestId") :: string?,
			player:GetAttribute("QuestStage") :: string?,
			player:GetAttribute(`QuestOffer_{m.Name}`) :: string?
		)
	end
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
	VoiceTTS.speak(node.line, t.tree.cast or "PATROL", { at = t.model, channel = "talk" })
	local rig = rigs[t.model]
	if rig then
		rig.gi += 1
		rig.gAt = os.clock() + GESTURE_DELAY
	end
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
	local home = model:GetPivot() -- animate() eases them round to face you (local only)
	local rig = rigs[model]
	if rig then
		rig.gi = 0 -- the greeting is a nod
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
	local rig = rigs[t.model]
	if rig then
		rig.face = t.home.Rotation -- eases back round (animate)
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
				toFov = cameraController.Comfort.get("fov"), -- the FOV the camera settles to after
				handheld = 0,
			},
		}, { skippable = false })
	end
end

-- the rig's R15 joints by name (Motor6D or AnimationConstraint), rescanned now and then for stream-in
local function jointsOf(m: Model, r: Rig): { [string]: Instance }
	local now = os.clock()
	if now >= r.scanAt then
		r.scanAt = now + 2
		table.clear(r.joints)
		for _, d in m:GetDescendants() do
			if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
				r.joints[d.Name] = d
			end
		end
	end
	return r.joints
end

-- Each joint's Transform turned on top of the Animator's (as WorkerController.applyTurns): a joint the playing track
-- skips keeps last frame's write, so that one turns from the Animator's last instead (no stacking).
local function apply(m: Model, r: Rig, want: TalkPose.Turns)
	local joints = jointsOf(m, r)
	for name, v in want do
		local j = joints[name]
		if j then
			local tf: CFrame = (j :: any).Transform
			local h = r.held[j]
			if h and tf == h[2] then
				tf = h[1]
			end
			local out = tf * CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z));
			(j :: any).Transform = out
			r.held[j] = { tf, out }
		end
	end
	for j, h in r.held do -- joints let go: back to the Animator's own
		if not (want[j.Name] and joints[j.Name] == j) then
			(j :: any).Transform = h[1]
			r.held[j] = nil
		end
	end
end

local NO_TURNS: TalkPose.Turns = {}

local function animate(dt: number)
	local cam = Workspace.CurrentCamera
	local head = player.Character and player.Character:FindFirstChild("Head")
	local target = if head and head:IsA("BasePart") then head.Position else nil
	local now = os.clock()
	local k = 1 - math.exp(-6 * dt)
	for m, r in rigs do
		if not m.Parent then
			rigs[m] = nil
			continue
		end
		local root = rootOf(m)
		if not root or (cam.CFrame.Position - root.Position).Magnitude > ALIVE_RANGE then
			apply(m, r, NO_TURNS)
			continue
		end
		local t = talking
		local talk = t ~= nil and t.model == m
		if talk and target then
			local to = (target - root.Position) * Vector3.new(1, 0, 1)
			if to.Magnitude > 0.1 then
				r.face = CFrame.lookAt(Vector3.zero, to)
			end
		end
		local face = r.face
		if face then
			local at = m:GetPivot()
			local rot = at.Rotation:Lerp(face, 1 - math.exp(-TURN_RATE * dt))
			if not talk and rot.LookVector:Dot(face.LookVector) > 0.9999 then
				rot, r.face = face, nil -- home again: the server's pose
			end
			m:PivotTo(CFrame.new(at.Position) * rot)
		end
		-- a slow glance round; the player's head when near (always while talking)
		local wy, wp = 35 * math.noise(now * 0.2, r.seed + 0.5), 0
		if target and (talk or (target - root.Position).Magnitude < LOOK_RANGE) then
			local y, p = TalkPose.look(
				root.CFrame:VectorToObjectSpace(target - (root.Position + Vector3.new(0, 1.5, 0)))
			)
			if y and p then
				wy, wp = y, p
			end
		end
		r.yaw += (wy - r.yaw) * k
		r.pitch += (wp - r.pitch) * k
		local speaking = talk and lineLabel.MaxVisibleGraphemes ~= -1
		apply(
			m,
			r,
			TalkPose.turns(r.yaw, r.pitch, now, speaking, if talk then r.gi else nil, now - r.gAt)
		)
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
	local model = m :: Model
	rigs[model] = rigs[model]
		or {
			seed = #m.Name * 7 + (string.byte(m.Name) or 0),
			yaw = 0,
			pitch = 0,
			gi = 0,
			gAt = 0,
			joints = {},
			scanAt = 0,
			held = {},
		}
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
	RunService.PreSimulation:Connect(animate) -- after the Animator, as WorkerController
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
