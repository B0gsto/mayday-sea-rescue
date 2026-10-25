--!strict
-- DockService (docs/23 WP-1): the marina and your own dock. Builds the 16 plots (shared/Marina) as placeholder
-- Parts in Workspace.Marina, gives each joining player the lowest free plot and frees it on leave. Lv 1 is a bare
-- jetty, a name board and a flag in the player's colour; an empty plot is just the jetty. The dock level lives
-- in the profile (data.dockLevel, default 1) so later levels rebuild on whichever plot the player gets.
-- VehicleService launches at the plot's Berth part (BayLaunch frame) and stands the player on the jetty.
--
-- API: GetBerth(player) -> BasePart?, GetPlot(player) -> number?, GetLevel(player) -> number, Berths() -> { BasePart }.
-- Player attributes: DockPlot (index), BayCFrame (the berth CFrame; StreakController, MapController read it).
-- Berth attributes: LaunchBay = true, PlotIndex, Owner (UserId, nil when empty).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent:WaitForChild("DataService"))
local Marina = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Marina"))

local DockService = {}
DockService.Priority = 40 -- before VehicleService (50): the berths exist when it starts

local WOOD = Color3.fromRGB(122, 92, 62)
local DARK_WOOD = Color3.fromRGB(84, 62, 44)
local BOARD = Color3.fromRGB(236, 230, 214)

type Plot =
	{ model: Model, berth: Part, label: TextLabel, gui: SurfaceGui, board: Part, flag: Part }

local plots: { Plot } = {}
local owners: { [number]: Player } = {}
local byPlayer: { [Player]: number } = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function post(parent: Instance, cf: CFrame, top: number, bottom: number)
	local p = part(
		parent,
		"Piling",
		Vector3.new(top - bottom, 1.2, 1.2),
		CFrame.new(cf.X, (top + bottom) / 2, cf.Z) * CFrame.Angles(0, 0, math.pi / 2),
		DARK_WOOD,
		Enum.Material.Wood
	)
	p.Shape = Enum.PartType.Cylinder
end

local function buildPlot(folder: Instance, i: number): Plot
	local b = Marina.berth(i)
	local top = Marina.DECK_TOP
	local model = Instance.new("Model")
	model.Name = `Plot{i}`
	local center = (Marina.PLOT_X[1] + Marina.PLOT_X[2]) / 2
	part(
		model,
		"Deck",
		Vector3.new(Marina.PLOT_X[2] - Marina.PLOT_X[1], 1, Marina.DECK),
		b * CFrame.new(center, top - 0.5, Marina.BERTH / 2 + Marina.DECK / 2),
		WOOD,
		Enum.Material.Wood
	)
	local j = Marina.JETTY
	local z1 = Marina.BERTH / 2
	part(
		model,
		"Jetty",
		Vector3.new(j.x1 - j.x0, 1, z1 - j.out),
		b * CFrame.new((j.x0 + j.x1) / 2, top - 0.5, (z1 + j.out) / 2),
		WOOD,
		Enum.Material.Wood
	)
	for _, at in
		{
			Vector3.new(j.x0 + 0.6, 0, j.out + 1),
			Vector3.new(j.x1 - 0.6, 0, j.out + 1),
			Vector3.new(j.x0 + 0.6, 0, 8),
			Vector3.new(j.x1 - 0.6, 0, 8),
		}
	do
		post(model, b * CFrame.new(at), top + 0.8, -8)
	end

	-- name board on the deck edge, facing the water (Front = local -Z = out to sea)
	local boardAt = b * CFrame.new(center, top + 3.2, z1 + 1)
	for _, dx in { -4.6, 4.6 } do
		part(
			model,
			"BoardPost",
			Vector3.new(0.4, 4.4, 0.4),
			boardAt * CFrame.new(dx, -1, 0.3),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	local board = part(
		model,
		"NameBoard",
		Vector3.new(10, 2.4, 0.3),
		boardAt,
		BOARD,
		Enum.Material.SmoothPlastic
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(30, 38, 52)
	label.Parent = gui

	-- flag: a pole at the deck's jetty corner, the cloth in the owner's colour
	local poleAt = b * CFrame.new(Marina.PLOT_X[2] - 3, top, z1 + 3)
	part(
		model,
		"FlagPole",
		Vector3.new(0.4, 14, 0.4),
		poleAt * CFrame.new(0, 7, 0),
		Color3.fromRGB(200, 200, 205),
		Enum.Material.Metal
	)
	local flag = part(
		model,
		"Flag",
		Vector3.new(0.15, 2.6, 4.2),
		poleAt * CFrame.new(0, 12.6, -2.3),
		BOARD,
		Enum.Material.Fabric
	)
	flag.CanCollide = false

	local berth = part(
		model,
		`Berth{i}`,
		Vector3.new(14, 0.4, Marina.BERTH),
		b * CFrame.new(0, 0.2, 0),
		WOOD,
		Enum.Material.SmoothPlastic
	)
	berth.Transparency = 1
	berth.CanCollide = false
	berth.CanQuery = false
	berth.CanTouch = false
	berth.CastShadow = false
	berth:SetAttribute("LaunchBay", true)
	berth:SetAttribute("PlotIndex", i)
	model.PrimaryPart = berth
	model.Parent = folder
	return { model = model, berth = berth, label = label, gui = gui, board = board, flag = flag }
end

-- Lv 1 for the owner, or the plain jetty when empty.
local function dress(plot: Plot, owner: Player?)
	plot.berth:SetAttribute("Owner", if owner then owner.UserId else nil)
	plot.label.Text = if owner then owner.DisplayName else ""
	plot.gui.Enabled = owner ~= nil
	plot.board.Transparency = if owner then 0 else 1
	plot.flag.Transparency = if owner then 0 else 1
	if owner then
		plot.flag.Color = Marina.flagColor(owner.UserId)
	end
end

local function claim(player: Player)
	if byPlayer[player] or player.Parent ~= Players then
		return
	end
	local i = Marina.assign(owners)
	if not i then
		warn(`[DockService] no free plot for {player.Name}`) -- shortcut: 16 plots = server size; a 17th player has no dock
		return
	end
	owners[i], byPlayer[player] = player, i
	dress(plots[i], player)
	player:SetAttribute("DockPlot", i)
	player:SetAttribute("BayCFrame", plots[i].berth.CFrame)
end

local function release(player: Player)
	local i = byPlayer[player]
	if i then
		owners[i], byPlayer[player] = nil, nil
		dress(plots[i], nil)
	end
end

function DockService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Marina"
	local spineLen = Marina.spineEndZ() - Marina.ROOT_Z
	part(
		folder,
		"Spine",
		Vector3.new(Marina.SPINE_W, 1, spineLen),
		CFrame.new(Marina.SPINE_X, Marina.DECK_TOP - 0.5, Marina.ROOT_Z + spineLen / 2),
		WOOD,
		Enum.Material.Wood
	)
	-- the boardwalk along the beach to the west breakwater root (the walk into town)
	local x0, x1 = Marina.SPINE_X - Marina.SPINE_W / 2, -326
	part(
		folder,
		"Boardwalk",
		Vector3.new(x1 - x0, 1, 8),
		CFrame.new((x0 + x1) / 2, Marina.DECK_TOP + 0.5, 12),
		WOOD,
		Enum.Material.Wood
	)
	for i = 1, Marina.COUNT do
		plots[i] = buildPlot(folder, i)
		dress(plots[i], nil)
	end
	folder.Parent = Workspace

	Players.PlayerAdded:Connect(claim)
	for _, player in Players:GetPlayers() do
		claim(player)
	end
	Players.PlayerRemoving:Connect(release)
end

function DockService.Start()
	DataService.OnLoaded(function(player: Player, data: any)
		claim(player) -- the profile can load before our PlayerAdded handler runs
		local i = byPlayer[player]
		if i then
			plots[i].model:SetAttribute("DockLevel", data.dockLevel or 1) -- later levels build from this
		end
	end)
end

function DockService.GetPlot(player: Player): number?
	return byPlayer[player]
end

function DockService.GetBerth(player: Player): BasePart?
	claim(player) -- callers may run before our PlayerAdded handler (BayDecor on profile load)
	local i = byPlayer[player]
	return if i then plots[i].berth else nil
end

function DockService.GetLevel(player: Player): number
	local data: any = DataService.Get(player)
	return if data and type(data.dockLevel) == "number" then data.dockLevel else 1
end

function DockService.Berths(): { BasePart }
	local out: { BasePart } = {}
	for _, plot in plots do
		table.insert(out, plot.berth)
	end
	return out
end

return DockService
