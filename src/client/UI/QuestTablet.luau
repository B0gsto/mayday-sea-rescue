--!strict
-- QuestTablet (docs/23 (p), WP-27): the quest tablet by your own pontoon (QuestController binds its prompt). A Kit
-- panel docked right lists your active quest and today's offers from the givers whose boats are at your pontoon (Kit
-- cards: island art, the place, the reward on the art; Accept closes the tablet). Tapping a card eases the camera onto that giver's boat; its button
-- accepts an offer, hands in a quest that is "back" or drops one still "go" (Quest_Talk, the same as talking to
-- them; greyed until the boat is tied up). Escape / B / the red X closes and eases the camera back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestData = require(Shared:WaitForChild("Quests"):WaitForChild("Data"))
local Rules = require(Shared:WaitForChild("Quests"):WaitForChild("Rules"))
local Stickers =
	require(Shared:WaitForChild("Config"):WaitForChild("UiImages")).Stickers :: { [string]: string }
local Controllers = script.Parent.Parent:WaitForChild("Controllers")
local AudioController = require(Controllers:WaitForChild("AudioController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local InputGlyph = require(script.Parent:WaitForChild("InputGlyph"))
local Kit = script.Parent:WaitForChild("Kit")
local Card = require(Kit:WaitForChild("Card"))
local PanelUI = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local S = Theme.Size
local LIST_W = 640 -- du
local LEAVE = 20 -- studs from the tablet (a teleport) closes it

local QuestTablet = {}

local gui: ScreenGui? = nil
local panel: PanelUI.Panel
local modal: InputGlyph.Modal
local opened = false
local tablet: BasePart? = nil
local camValue: CFrameValue? = nil
local camTween: Tween? = nil
local returnCf: CFrame? = nil
local saved: { walk: number, jump: number, height: number }? = nil
local shown = "" -- what the cards on screen show; rebuilt when it changes

local function send(npcId: string, action: string)
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild("Quest_Talk")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(npcId, action)
		AudioController.play("UI_Click")
	end
end

-- the givers at my pontoon (not sailing off), by npc id
local function here(): { [string]: Model }
	local out = {}
	local plot = player:GetAttribute("DockPlot")
	local npcs = Workspace:FindFirstChild("Npcs")
	for _, m in if npcs then npcs:GetChildren() else {} do
		if
			m:IsA("Model")
			and QuestData.npcById[m.Name]
			and m:GetAttribute("QuestIsland") == plot
			and not m:GetAttribute("Leaving")
		then
			out[m.Name] = m
		end
	end
	return out
end

local function fly(target: CFrame, t: number, after: (() -> ())?)
	local cv = camValue
	if not cv then
		local made = Instance.new("CFrameValue")
		made.Value = Workspace.CurrentCamera.CFrame
		made:GetPropertyChangedSignal("Value"):Connect(function()
			CameraController.SetOverride(made.Value)
		end)
		camValue, cv = made, made
	end
	if camTween then
		camTween:Cancel()
	end
	local tw = TweenService:Create(
		cv :: CFrameValue,
		TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = target }
	)
	camTween = tw
	if after then
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				after()
			end
		end)
	end
	tw:Play()
end

-- the camera eases onto the giver's boat from the tablet's side, the boat left of the panel
local function focus(rig: Model?)
	local t = tablet
	if not (rig and t) then
		return
	end
	local p = rig:GetPivot().Position
	local d = (p - t.Position) * Vector3.new(1, 0, 1)
	d = if d.Magnitude > 0.1 then d.Unit else Vector3.zAxis
	fly(CFrame.lookAt(p - d * 20 + Vector3.new(0, 9, 0), p) * CFrame.new(5, 0, 0), 0.6)
	AudioController.play("UI_Click")
end

local function card(
	order: number,
	quest: QuestData.Quest,
	color: string,
	label: string,
	action: string,
	ready: boolean,
	rig: Model?
): GuiObject
	local npc = QuestData.npcById[quest.npc]
	local placeId, place = Rules.place(quest)
	local sticker = Stickers[placeId]
	local c = Card.new(panel.body, {
		art = if action == "handIn" or not sticker then "quests" else sticker,
		title = if action == "handIn" then npc.name else place, -- the ask itself is spoken by the giver
		color = color,
		price = quest.cash,
		currency = "Cash",
		onBuy = function()
			send(quest.npc, action)
			if action == "accept" then
				QuestTablet.close()
			end
		end,
	})
	c.root.LayoutOrder = order
	local reward = Style.label(c.art, `+{Theme.short(quest.cash)}`, Theme.Text.small)
	reward.AnchorPoint = Vector2.new(0.5, 1)
	reward.Position = UDim2.fromScale(0.5, 1)
	reward.Size = UDim2.new(1, 0, 0, 28)
	reward.ZIndex = 3
	c.setState(if ready then "buy" else "disabled")
	c.price.setText(label)
	local glyph = c.price.root:FindFirstChild("Glyph", true)
	if glyph and glyph:IsA("GuiObject") then
		glyph.Visible = false -- a word, not a price
	end
	local block = c.price.root:FindFirstChild("Block")
	if action == "drop" and ready and block and block:IsA("Frame") then
		Style.recolor(block, Style.grad("red"))
	end
	-- the whole card (under the button) focuses the giver
	local tap = Style.button(c.root, UDim2.fromScale(1, 1))
	tap.Name = "Focus"
	tap.ZIndex = 0
	Style.press(tap, function()
		focus(rig)
	end, S.corner)
	return tap
end

local function rebuild()
	local rigs = here()
	local activeId = player:GetAttribute("QuestId")
	local active = if type(activeId) == "string" then QuestData.byId[activeId] else nil
	local back = player:GetAttribute("QuestStage") == "back"
	local rows: { { quest: QuestData.Quest, action: string } } = {}
	if active then
		table.insert(rows, { quest = active, action = if back then "handIn" else "drop" })
	end
	for _, npc in QuestData.Npcs do
		local offerId = player:GetAttribute(`QuestOffer_{npc.id}`)
		local q = if type(offerId) == "string" then QuestData.byId[offerId] else nil
		if q and rigs[npc.id] and not (active and active.npc == npc.id) then
			table.insert(rows, { quest = q, action = "accept" })
		end
	end
	local sig = ""
	for _, r in rows do
		local rig: Model? = rigs[r.quest.npc]
		sig ..= `{r.quest.id}:{r.action}:{rig ~= nil}:{rig and rig:GetAttribute("Moored") == true};`
	end
	if sig == shown then
		return
	end
	shown = sig
	for _, c in panel.body:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local first: GuiObject? = nil
	for i, r in rows do
		local rig: Model? = rigs[r.quest.npc]
		local moored = rig ~= nil and rig:GetAttribute("Moored") == true
		local tap = card(
			i,
			r.quest,
			if r.action == "accept" then "yellow" else "green",
			if r.action == "accept"
				then "Accept"
				elseif r.action == "handIn" then "Hand in"
				else "Drop",
			r.action,
			moored and (r.action ~= "accept" or not active),
			rig
		)
		first = first or tap
	end
	if #rows == 0 then
		local none = Style.label(panel.body, "None today", Theme.Text.heading, true)
		none.Size = UDim2.new(1, 0, 0, 80)
	end
	modal.open(first or panel.closeButton)
end

function QuestTablet.close()
	if not opened then
		return
	end
	opened = false
	Style.pop(panel.root, false)
	modal.close()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local s = saved
	if hum and s then
		hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = s.walk, s.jump, s.height
	end
	saved = nil
	if camValue then
		fly(returnCf or (camValue :: CFrameValue).Value, 0.6, function()
			CameraController.ClearOverride()
			if camValue then
				camValue:Destroy()
				camValue = nil
			end
		end)
	end
	AudioController.play("UI_Click")
end

local function build(): ScreenGui
	local g = Instance.new("ScreenGui")
	g.Name = "QuestTablet"
	g.ResetOnSpawn = false
	g.DisplayOrder = 25
	g.IgnoreGuiInset = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.Parent = player:WaitForChild("PlayerGui")
	local canvas = Style.canvas(g)
	panel = PanelUI.new(canvas, {
		title = "Quests",
		icon = "quests",
		size = Vector2.new(LIST_W, 2000),
		onClose = QuestTablet.close,
	})
	panel.root.AnchorPoint = Vector2.new(1, 0.5)
	panel.root.Position = UDim2.new(1, -S.margin, 0.5, 0)
	modal = InputGlyph.modal("QuestTablet", QuestTablet.close)
	-- Escape closes; ContextActionService never sees it, so read it here (as DockController does)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Escape then
			QuestTablet.close()
		end
	end)
	return g
end

function QuestTablet.open(part: BasePart)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if opened or not hum then
		return
	end
	gui = gui or build()
	opened, tablet, shown = true, part, ""
	returnCf = Workspace.CurrentCamera.CFrame
	saved = { walk = hum.WalkSpeed, jump = hum.JumpPower, height = hum.JumpHeight }
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
	Style.pop(panel.root, true)
	rebuild()
	AudioController.play("UI_Click")
	task.spawn(function()
		while opened do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if
				hum.Health <= 0
				or not (root and root:IsA("BasePart"))
				or (root.Position - part.Position).Magnitude > LEAVE
			then
				QuestTablet.close()
				break
			end
			rebuild()
			task.wait(0.5)
		end
	end)
end

return QuestTablet
