--!strict
-- Quests panel: a read-only board of today's offers and the active quest (island art, place, giver, reward). Accepting happens
-- at the giver's boat (TalkController) or your quest tablet (UI/QuestTablet), so every row points at the person.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestData = require(Shared:WaitForChild("Quests"):WaitForChild("Data"))
local Rules = require(Shared:WaitForChild("Quests"):WaitForChild("Rules"))
local Stickers =
	require(Shared:WaitForChild("Config"):WaitForChild("UiImages")).Stickers :: { [string]: string }

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer

local Quests = {}

local function art(quest: QuestData.Quest): string
	local id = Rules.place(quest)
	local sticker = Stickers[id]
	return if type(sticker) == "string" and sticker ~= "" then sticker else "quests"
end

-- one row: island art, the place (1-2 words), an optional giver name, the reward (the ask is spoken by the giver)
local function row(
	parent: Instance,
	order: number,
	color: string,
	image: string,
	title: string,
	who: string?,
	tagText: string
)
	local root = Instance.new("Frame")
	root.Name = "Quest"
	root.LayoutOrder = order
	root.Size = UDim2.new(1, 0, 0, 110)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local _, face = Style.block(root, Style.grad(color))
	local well = Instance.new("Frame")
	well.Name = "Art"
	well.BackgroundColor3 = Color3.new(1, 1, 1)
	well.BackgroundTransparency = 0.6
	well.AnchorPoint = Vector2.new(0, 0.5)
	well.Position = UDim2.new(0, 12, 0.5, 0)
	well.Size = UDim2.fromOffset(80, 80)
	Style.corner(well, Theme.Size.cornerSmall)
	well.Parent = face
	if string.find(image, "://", 1, true) then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = image
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = well
	else
		Style.icon(well, image)
	end
	local t = Style.label(face, title, Theme.Text.heading)
	t.Position = UDim2.fromOffset(108, if who then 12 else 0)
	t.Size = UDim2.new(1, -320, 0, if who then 44 else 100)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = false
	t.TextTruncate = Enum.TextTruncate.AtEnd
	if who then
		local w = Style.label(face, who, Theme.Text.small)
		w.Position = UDim2.fromOffset(108, 56)
		w.Size = UDim2.new(1, -320, 0, 34)
		w.TextXAlignment = Enum.TextXAlignment.Left
		w.TextWrapped = false
	end
	local tag = Style.label(face, tagText, Theme.Text.heading)
	tag.Name = "Tag"
	tag.AnchorPoint = Vector2.new(1, 0.5)
	tag.Position = UDim2.new(1, -18, 0.5, 0)
	tag.Size = UDim2.fromOffset(190, 50)
	tag.TextXAlignment = Enum.TextXAlignment.Right
	tag.TextWrapped = false
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
			local npc = QuestData.npcById[active.npc]
			local back = player:GetAttribute("QuestStage") == "back"
			local _, place = Rules.place(active)
			row(
				panel.body,
				order,
				"green",
				if back then "quests" else art(active),
				if back then npc.name else place,
				nil,
				`+{Theme.short(active.cash)}`
			)
		end
		for _, npc in QuestData.Npcs do
			local offerId = player:GetAttribute(`QuestOffer_{npc.id}`)
			local quest = if type(offerId) == "string" then QuestData.byId[offerId] else nil
			if quest and not (active and active.npc == npc.id) then
				order += 1
				local _, place = Rules.place(quest)
				row(
					panel.body,
					order,
					"yellow",
					art(quest),
					place,
					npc.name,
					`+{Theme.short(quest.cash)}`
				)
			end
		end
		if order == 0 then
			local none = Style.label(panel.body, "None today", Theme.Text.heading, true)
			none.Size = UDim2.new(1, 0, 0, 80)
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
