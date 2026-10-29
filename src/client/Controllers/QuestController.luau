--!strict
-- QuestController (docs/23 (l) + (p), WP-21b / WP-27): the glyph over each quest giver whose boat is at your own
-- pontoon (Workspace.Npcs rigs with QuestIsland = your DockPlot, not Leaving), local to you: a gold "!" when they have
-- a quest for you today and you have none, a "?" over your quest's giver when it is ready to hand in. Reads
-- QuestService's player attributes (QuestOffer_<npcId>, QuestId, QuestStage). Also puts the "Quests" prompt on your
-- own island's QuestTablet (Workspace.QuestPontoons.Island<plot>), which opens UI/QuestTablet. And moored quest boats
-- (Workspace.QuestBoats, Moored) bob and sway on the shared wave field with their giver, locally (the server leaves
-- them still at the slot). Quests open later (QuestService gate): on QuestReveal, once per player, a calm wordless
-- intro: the Quests button appears with one pop of its steady gold ring and a chime, and when the first giver has tied
-- up, the camera eases over to them and back (skippable).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Menu = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Menu"))
local QuestData =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Quests"):WaitForChild("Data"))
local QuestTablet = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("QuestTablet"))
local Weather = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Weather"))

local QuestController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 196, 40)
local boards: { [Model]: BillboardGui } = {} -- several islands can each have a rig for the same giver
local BOB_RANGE = 400 -- studs from the camera a moored boat bobs
local SWAY = 0.7 -- share of the wave slope the hull follows
type Bob = { base: CFrame, rig: Model?, rel: CFrame }
local bobs: { [Model]: Bob } = {} -- moored boat -> its still (server) pivot and its giver

local function glyphFor(m: Model): string?
	if
		player:GetAttribute("CinematicPlaying") == true -- the talk shot (and any cutscene): it filled the top of the frame
			and player:GetAttribute("CinematicId") ~= "QuestReveal" -- the reveal shows the "!"
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

-- keeps `bobs` in step with the moored boats; one that unties goes back to its still pivot (the server sails it)
local function sweepBoats(npcs: Instance)
	for boat, b in bobs do
		if boat.Parent == nil or boat:GetAttribute("Moored") ~= true then
			boat:PivotTo(b.base)
			local rig = b.rig
			if rig and rig.Parent then
				rig:PivotTo(b.base * b.rel)
			end
			bobs[boat] = nil
		end
	end
	local folder = Workspace:FindFirstChild("QuestBoats")
	for _, boat in if folder then folder:GetChildren() else {} do
		if boat:IsA("Model") and boat:GetAttribute("Moored") == true then
			local b = bobs[boat]
			if not b then
				b = { base = boat:GetPivot(), rig = nil, rel = CFrame.identity }
				bobs[boat] = b
			end
			local bb = b :: Bob
			if not (bb.rig and bb.rig.Parent) then
				bb.rig = nil
				for _, m in npcs:GetChildren() do
					if
						m:IsA("Model")
						and m.Name == boat:GetAttribute("Giver")
						and m:GetAttribute("QuestIsland") == boat:GetAttribute("QuestIsland")
						and m:GetAttribute("Moored") == true
					then
						bb.rig, bb.rel = m, bb.base:ToObjectSpace(m:GetPivot())
					end
				end
			end
		end
	end
end

local function bob()
	local cam = Workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	for boat, b in bobs do
		local base = b.base
		local p = base.Position
		if (p - eye).Magnitude < BOB_RANGE then
			local h = Weather.heightAt(p)
			local bow = Weather.heightAt(p + base.LookVector * 4)
			local beam = Weather.heightAt(p + base.RightVector * 2.5)
			local cf = base
				* CFrame.new(0, h - p.Y, 0)
				* CFrame.Angles(math.atan2(bow - h, 4) * SWAY, 0, math.atan2(beam - h, 2.5) * SWAY)
			boat:PivotTo(cf)
			local rig = b.rig
			if rig and rig.Parent then
				rig:PivotTo(cf * b.rel)
			end
		end
	end
end

-- the "Quests" prompt on my own island's tablet only (streams in late; a moved plot drops the old one)
local function tabletPrompt()
	local plot = player:GetAttribute("DockPlot")
	local folder = Workspace:FindFirstChild("QuestPontoons")
	for _, isl in if folder then folder:GetChildren() else {} do
		local tablet = isl:FindFirstChild("QuestTablet", true) -- under TabletStand, once quests open
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

-- on foot, no cutscene, panel or build view: the reveal never cuts into play
local function free(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil
		and hum.SeatPart == nil
		and player:GetAttribute("CinematicPlaying") ~= true
		and player:GetAttribute("MenuOpen") ~= true
		and player:GetAttribute("BuildHidesMenu") ~= true
end

-- my first moored giver (nil while they are still sailing in)
local function moored(npcs: Instance): Model?
	for _, m in npcs:GetChildren() do
		if
			m:IsA("Model")
			and m:GetAttribute("QuestIsland") == player:GetAttribute("DockPlot")
			and m:GetAttribute("Moored") == true
			and m:GetAttribute("Leaving") ~= true
		then
			return m
		end
	end
	return nil
end

local revealed = false
local function reveal(npcs: Instance)
	if revealed or player:GetAttribute("QuestReveal") ~= true then
		return
	end
	revealed = true
	task.spawn(function()
		repeat
			task.wait(1)
		until free()
		Menu.pulse("Quests") -- one pop, then a steady ring till the panel opens
		AudioController.play("UI_Success")
		local giver, t0 = moored(npcs), os.clock()
		while not giver and os.clock() - t0 < 60 do -- they sail in (~26 s)
			task.wait(1)
			giver = moored(npcs)
		end
		repeat
			task.wait(0.5)
		until free()
		local cam = Workspace.CurrentCamera
		if not (giver and cam) then
			return
		end
		local at = giver:GetPivot().Position + Vector3.new(0, 2, 0)
		local flat = Vector3.new(at.X - cam.CFrame.Position.X, 0, at.Z - cam.CFrame.Position.Z)
		local dir = if flat.Magnitude > 1 then flat.Unit else Vector3.zAxis
		local eye = at - dir * 26 + Vector3.new(0, 10, 0)
		CameraController.PlayCinematic({
			{ from = cam.CFrame, to = CFrame.lookAt(eye, at), duration = 1.8 },
			{
				from = CFrame.lookAt(eye, at),
				to = CFrame.lookAt(eye + dir * 5, at),
				duration = 2.6,
			},
		}, { id = "QuestReveal", skippable = true })
	end)
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
	reveal(npcs)
	player:GetAttributeChangedSignal("QuestReveal"):Connect(function()
		reveal(npcs)
	end)
	task.spawn(function()
		while true do
			for _, c in npcs:GetChildren() do
				attach(c)
			end
			refresh()
			tabletPrompt()
			sweepBoats(npcs)
			task.wait(1)
		end
	end)
	RunService.Heartbeat:Connect(bob)
end

return QuestController
