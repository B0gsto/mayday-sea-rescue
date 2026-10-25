--!strict
-- QuestController (docs/23 (l) + (p), WP-21b / WP-27): the glyph over each quest giver whose boat is at your own
-- pontoon (Workspace.Npcs rigs with QuestIsland = your DockPlot, not Leaving), local to you: a gold "!" when they have
-- a quest for you today and you have none, a "?" over your quest's giver when it is ready to hand in. Reads
-- QuestService's player attributes (QuestOffer_<npcId>, QuestId, QuestStage). Also puts the "Quests" prompt on your
-- own island's QuestTablet (Workspace.QuestPontoons.Island<plot>), which opens UI/QuestTablet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local QuestData =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("Data"))
local QuestTablet = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("QuestTablet"))

local QuestController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 196, 40)
local boards: { [Model]: BillboardGui } = {} -- several islands can each have a rig for the same giver

local function glyphFor(m: Model): string?
	if
		player:GetAttribute("CinematicPlaying") == true -- the talk shot (and any cutscene): it filled the top of the frame
		or m:GetAttribute("QuestIsland") ~= player:GetAttribute("DockPlot") -- someone else's givers
		or m:GetAttribute("Leaving") == true
	then
		return nil
	end
	local npcId = m.Name
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
	for model, board in boards do
		if not (board.Adornee and board.Adornee:IsDescendantOf(Workspace)) then
			local head = model:FindFirstChild("Head") -- streamed back in: a new head
			if head then
				board.Adornee = head
			end
		end
		local g = glyphFor(model)
		board.Enabled = g ~= nil
		local label = board:FindFirstChild("Glyph", true)
		if g and label and label:IsA("TextLabel") then
			label.Text = g
		end
	end
end

local function attach(m: Instance)
	if not (m:IsA("Model") and QuestData.npcById[m.Name]) or boards[m] then
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
	boards[m] = board
	m.Destroying:Connect(function()
		boards[m] = nil
		board:Destroy()
	end)
end

-- the "Quests" prompt on my own island's tablet only (streams in late; a moved plot drops the old one)
local function tabletPrompt()
	local plot = player:GetAttribute("DockPlot")
	local folder = Workspace:FindFirstChild("QuestPontoons")
	for _, isl in if folder then folder:GetChildren() else {} do
		local tablet = isl:FindFirstChild("QuestTablet")
		local prompt = tablet and tablet:FindFirstChild("QuestPrompt")
		local mine = isl.Name == `Island{plot}`
		if prompt and not mine then
			prompt:Destroy()
		elseif mine and tablet and tablet:IsA("BasePart") and not prompt then
			local p = Instance.new("ProximityPrompt")
			p.Name = "QuestPrompt"
			p.ActionText = "Quests"
			p.ObjectText = "Tablet"
			p.HoldDuration = 0
			p.MaxActivationDistance = 12
			p.RequiresLineOfSight = false
			p.Triggered:Connect(function()
				QuestTablet.open(tablet)
			end)
			p.Parent = tablet
		end
	end
end

function QuestController.Start()
	player.AttributeChanged:Connect(function(name)
		if
			string.sub(name, 1, 5) == "Quest"
			or name == "CinematicPlaying"
			or name == "DockPlot"
		then
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
			tabletPrompt()
			task.wait(1)
		end
	end)
end

return QuestController
