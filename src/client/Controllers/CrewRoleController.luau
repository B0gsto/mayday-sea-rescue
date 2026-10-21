--!strict
-- CrewRoleController (G30): the small role icon over each crew member's head, beside the name tag.
-- Icons only (no text, no menu): Navigator = heading arrow, Medic = cross. Helm and Crew (riding,
-- swimming) show no icon (playtest: noise over every rider). The server writes Player attribute
-- CrewRole from what the crew member is doing (CrewService); this draws it for the local player's
-- crew, including the local player (visible in the chase camera).
--
-- Crew membership comes from the CrewJoin / CrewLeave echoes (CrewService): only crewmates show an
-- icon. CrewRoleController.attach(model, role) -> () -> () is for review shots / smoke tests (it
-- puts the same icon on any rig with a Head).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Glyph = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Glyph"))
local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local CrewRoleController = {}
CrewRoleController.Priority = 90

local ICON = "CrewRoleIcon"
local DISTANCE = 140
local COLOURS: { [string]: Color3 } = {
	Navigator = HudTheme.Colors.bar,
	Medic = HudTheme.Colors.ready,
}

local player = Players.LocalPlayer
local crew: { [number]: boolean } = { [player.UserId] = true }
local shown: { [Player]: BillboardGui } = {}

local bar = Glyph.bar

local function heading(parent: GuiObject, colour: Color3)
	bar(parent, Vector2.new(0.09, 0.46), Vector2.new(0.36, 0.55), 30, colour)
	bar(parent, Vector2.new(0.09, 0.46), Vector2.new(0.64, 0.55), -30, colour)
	bar(parent, Vector2.new(0.09, 0.22), Vector2.new(0.5, 0.73), 0, colour)
end

local function medic(parent: GuiObject, colour: Color3)
	Glyph.draw("cross", parent, colour)
end

-- Helm (riding) and Crew (swimming) draw nothing: the boat and the water already say it.
local GLYPHS: { [string]: (GuiObject, Color3) -> () } = {
	Navigator = heading,
	Medic = medic,
}

local function build(head: BasePart, role: string): BillboardGui
	local colour = COLOURS[role] or HudTheme.Colors.text
	local gui = Instance.new("BillboardGui")
	gui.Name = ICON
	gui.Adornee = head
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = DISTANCE
	gui.Size = UDim2.fromScale(0.95, 0.95) -- studs; shrinks with distance like the name tag
	gui.StudsOffsetWorldSpace = Vector3.new(1.35, 2.15, 0) -- beside the default name tag
	gui.ResetOnSpawn = false

	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.5)
	badge.Size = UDim2.fromScale(1, 1)
	badge.BackgroundColor3 = HudTheme.Colors.panel
	badge.BackgroundTransparency = 0.18
	badge.BorderSizePixel = 0
	badge.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.24, 0)
	round.Parent = badge
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = 2
	stroke.Transparency = 0.05
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = badge

	local glyph = Instance.new("Frame")
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(0.72, 0.72)
	glyph.BackgroundTransparency = 1
	glyph.Parent = badge
	local draw = GLYPHS[role]
	if draw then
		draw(glyph, colour)
	end
	return gui
end

local function detach(p: Player)
	local gui = shown[p]
	if gui then
		shown[p] = nil
		gui:Destroy()
	end
end

local function refresh(p: Player)
	detach(p)
	if p.Parent == nil or not crew[p.UserId] then
		return
	end
	local role = p:GetAttribute("CrewRole")
	local character = p.Character
	local head = character and character:FindFirstChild("Head")
	if type(role) ~= "string" or not GLYPHS[role] then
		return
	end
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = build(head, role)
	gui.Parent = head
	shown[p] = gui
end

-- Review shots / smoke tests: the same icon on any rig with a Head.
function CrewRoleController.attach(model: Model, role: string): () -> ()
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return function() end
	end
	local gui = build(head, role)
	gui.Parent = head
	return function()
		gui:Destroy()
	end
end

local function syncMembers(ids: { any })
	crew = {}
	for _, id in ids do
		if type(id) == "number" then
			crew[id] = true
		end
	end
	crew[player.UserId] = true
	for _, p in Players:GetPlayers() do
		refresh(p)
	end
end

local function track(p: Player)
	if p == player then
		return
	end
	p:GetAttributeChangedSignal("CrewRole"):Connect(function()
		refresh(p)
	end)
	p.CharacterAdded:Connect(function()
		task.defer(refresh, p)
	end)
	p.CharacterRemoving:Connect(function()
		detach(p)
	end)
end

function CrewRoleController.Start()
	local lastRole: any = player:GetAttribute("CrewRole")
	player:GetAttributeChangedSignal("CrewRole"):Connect(function()
		local role = player:GetAttribute("CrewRole")
		if type(role) == "string" and role ~= "" and role ~= lastRole then
			AudioController.play("UI_Click", nil, 1, 1)
		end
		lastRole = role
		refresh(player)
	end)
	player.CharacterAdded:Connect(function()
		task.defer(refresh, player)
	end)
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(detach)
	Net.event("CrewJoin").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.members) ~= "table" then
			return
		end
		syncMembers(payload.members)
	end)
	Net.event("CrewLeave").OnClientEvent:Connect(function()
		syncMembers({ player.UserId })
	end)
	for _, p in Players:GetPlayers() do
		track(p)
		refresh(p)
	end
end

return CrewRoleController
