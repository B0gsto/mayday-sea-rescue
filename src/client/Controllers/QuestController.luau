--!strict
-- QuestController (docs/23 (l), WP-21b): the glyph over each quest giver (Quests/Data, Workspace.Npcs), local to
-- you: a gold "!" when they have a quest for you today and you have none, a "?" over your quest's giver when it is
-- ready to hand in. Reads QuestService's player attributes (QuestOffer_<npcId>, QuestId, QuestStage).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local QuestData =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("Data"))

local QuestController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 196, 40)
local boards: { [string]: { board: BillboardGui, model: Model } } = {}

local function glyphFor(npcId: string): string?
	if player:GetAttribute("CinematicPlaying") == true then
		return nil -- the talk shot (and any cutscene): it filled the top of the frame
	end
	local active = player:GetAttribute("QuestId")
	local quest = active and QuestData.byId[active :: string]
	if quest then
		return if quest.npc == npcId and player:GetAttribute("QuestStage") == "back"
			then "?"
			else nil
	end
	return if player:GetAttribute(`QuestOffer_{npcId}`) then "!" else nil
end

local function refresh()
	for id, b in boards do
		local board = b.board
		if not (board.Adornee and board.Adornee:IsDescendantOf(Workspace)) then
			local head = b.model:FindFirstChild("Head") -- streamed back in: a new head
			if head then
				board.Adornee = head
			end
		end
		local g = glyphFor(id)
		board.Enabled = g ~= nil
		local label = board:FindFirstChild("Glyph", true)
		if g and label and label:IsA("TextLabel") then
			label.Text = g
		end
	end
end

local function attach(m: Instance)
	if not (m:IsA("Model") and QuestData.npcById[m.Name]) or boards[m.Name] then
		return
	end
	local head = m:FindFirstChild("Head") -- not streamed in yet: the next sweep tries again
	if not (head and head:IsA("BasePart")) then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "QuestGlyph"
	board.Adornee = head
	board.Size = UDim2.fromScale(2.4, 2.4)
	board.StudsOffset = Vector3.new(0, 2.6, 0)
	board.LightInfluence = 0
	board.MaxDistance = 220
	board.AlwaysOnTop = false -- on top it never drew in play (Studio, 2026-10-25)
	board.ResetOnSpawn = false
	local disc = Instance.new("Frame")
	disc.Size = UDim2.fromScale(1, 1)
	disc.BackgroundColor3 = GOLD
	disc.Parent = board
	HudTheme.corner(disc, 999)
	HudTheme.stroke(disc, Color3.new(1, 1, 1), 3)
	local label = HudTheme.label("Glyph", "!", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 40, disc)
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextColor3 = Color3.fromRGB(40, 30, 10)
	board.Parent = player:WaitForChild("PlayerGui") -- not under the head: it outlives a stream-out
	boards[m.Name] = { board = board, model = m }
	m.Destroying:Connect(function()
		if boards[m.Name] and boards[m.Name].board == board then
			boards[m.Name] = nil
			board:Destroy()
		end
	end)
end

function QuestController.Start()
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Quest" or name == "CinematicPlaying" then
			refresh()
		end
	end)
	local npcs = Workspace:WaitForChild("Npcs")
	task.spawn(function()
		while true do
			for _, c in npcs:GetChildren() do
				attach(c)
			end
			refresh()
			task.wait(1)
		end
	end)
end

return QuestController
