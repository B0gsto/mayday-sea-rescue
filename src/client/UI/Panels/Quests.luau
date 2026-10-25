--!strict
-- Quests panel: a read-only board of today's offers and the active quest. Accepting happens
-- at the giver's boat (TalkController) or your quest tablet (UI/QuestTablet), so every row points at the person.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestData =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("Data"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer

local Quests = {}

local function row(parent: Instance, order: number, color: string): (Frame, Frame)
	local root = Instance.new("Frame")
	root.Name = "Quest"
	root.LayoutOrder = order
	root.Size = UDim2.new(1, 0, 0, 126)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local _, face = Style.block(root, Style.grad(color))
	return root, face
end

function Quests.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Quests",
		icon = "quests",
		size = Vector2.new(760, 580),
		onClose = onClose,
	})

	local function rebuild()
		for _, c in panel.body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local activeId = player:GetAttribute("QuestId")
		local active = if type(activeId) == "string" then QuestData.byId[activeId] else nil
		local order = 0
		if active then
			order += 1
			local _, face = row(panel.body, order, "green")
			local npc = QuestData.npcById[active.npc]
			local title = Style.label(
				face,
				`{if player:GetAttribute("QuestStage") == "back" then "Return to " else ""}{npc and npc.name or active.npc}`,
				Theme.Text.heading
			)
			title.Position = UDim2.fromOffset(18, 10)
			title.Size = UDim2.new(1, -160, 0, 40)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextWrapped = false
			local ask = Style.label(face, active.ask, Theme.Text.small)
			ask.Position = UDim2.fromOffset(18, 54)
			ask.Size = UDim2.new(1, -180, 0, 50)
			ask.TextXAlignment = Enum.TextXAlignment.Left
			ask.TextTruncate = Enum.TextTruncate.AtEnd
			local reward = Style.label(face, `+{Theme.short(active.cash)} Cash`, Theme.Text.small)
			reward.Name = "Reward"
			reward.AnchorPoint = Vector2.new(1, 0.5)
			reward.Position = UDim2.new(1, -18, 0.5, 0)
			reward.Size = UDim2.fromOffset(180, 36)
			reward.TextXAlignment = Enum.TextXAlignment.Right
			reward.TextWrapped = false
		end
		for _, npc in QuestData.Npcs do
			local offerId = player:GetAttribute(`QuestOffer_{npc.id}`)
			local quest = if type(offerId) == "string" then QuestData.byId[offerId] else nil
			order += 1
			local _, face = row(panel.body, order, if quest then "yellow" else "blue")
			local title = Style.label(face, npc.name, Theme.Text.heading)
			title.Position = UDim2.fromOffset(18, 10)
			title.Size = UDim2.new(1, -180, 0, 40)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextWrapped = false
			local lineText = if quest
				then quest.ask
				elseif active and active.npc == npc.id then "Your quest is with you."
				else npc.idle
			local line = Style.label(face, lineText, Theme.Text.small)
			line.Position = UDim2.fromOffset(18, 54)
			line.Size = UDim2.new(1, -200, 0, 50)
			line.TextXAlignment = Enum.TextXAlignment.Left
			line.TextTruncate = Enum.TextTruncate.AtEnd
			local tag = Style.label(
				face,
				if quest then `!  +{Theme.short(quest.cash)}` else npc.role,
				Theme.Text.small
			)
			tag.Name = "Tag"
			tag.AnchorPoint = Vector2.new(1, 0.5)
			tag.Position = UDim2.new(1, -18, 0.5, 0)
			tag.Size = UDim2.fromOffset(190, 40)
			tag.TextXAlignment = Enum.TextXAlignment.Right
			tag.TextWrapped = false
		end
	end

	rebuild()
	player.AttributeChanged:Connect(function(name)
		if (string.sub(name, 1, 5) == "Quest" or name == "CinematicPlaying") and panel.isOpen() then
			rebuild()
		end
	end)

	return {
		open = function()
			panel.open()
			rebuild()
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Quests
