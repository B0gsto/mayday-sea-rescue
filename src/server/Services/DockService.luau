--!strict
-- DockService (docs/23 WP-1): the marina and your own dock. Builds the 16 plots (shared/Marina) as placeholder
-- Parts in Workspace.Marina, gives each joining player the lowest free plot and frees it on leave. Lv 1 is a bare
-- jetty, a name board and a flag in the player's colour; an empty plot is just the jetty. The dock level lives
-- in the profile (data.dockLevel, default 1) so later levels rebuild on whichever plot the player gets.
-- VehicleService launches at the plot's Berth part (BayLaunch frame) and stands the player on the jetty.
-- Levels 2..5 (WP-4, DockConfig): each adds the DockPieces of that level on the plot, built here so everyone
-- sees them. Bought with Cash + rank (Dock_Upgrade) or Robux (MonetizationConfig DockLevel<n>, skips both);
-- the new pieces rise into place (the build beat). The owner's ghost of the next level is DockController's.
--
-- API: GetBerth(player) -> BasePart?, GetPlot(player) -> number?, GetLevel(player) -> number, Berths() -> { BasePart }.
-- Player attributes: DockPlot (index), BayCFrame (the berth CFrame; StreakController, MapController read it),
-- DockLevel (built level, DockController's ghost reads it).
-- Remote: Dock_Upgrade C->S function (level | building key) -> ok, reason ("Level" | "Rank" | "Cash" |
-- "Owned" | "Data" | "Busy").
-- Buildings (docs/23 h, WP-10b; DockConfig.Buildings): the car garage (one of the 16 bays along Penhallow
-- Road, Marina.garage), the helipad + hangar on the Lv 3+ boathouse roof and the sub pen beside the berth.
-- Owned ones live in data.dockBuildings; Dock_Upgrade(key) buys one with Cash + rank, products DockGarage /
-- DockHangar / DockSubPen with Robux. Their vehicle boards are server/Dock/BoatBoard's.
-- Studio: ServerStorage.DockDev:Invoke("level", n) sets the first player's dock level; ("building", key)
-- gives them a building ("all": every one); ("trophies") every rescue milestone and island stamp.
-- Berth attributes: LaunchBay = true, PlotIndex, Owner (UserId, nil when empty), Garage / Hangar / SubPen
-- (built). Player attributes DockGarage / DockHangar / DockSubPen (owned; DockController's ghosts).
-- WP-13: plots are handed out once the profile loads (GetBerth claims earlier if asked). Harbour Master
-- (docs/23 d.1, Marina.harbourMaster): the highest rank among Lv 5 docks gets a gold name board and a tall gold
-- flag; picked on join / leave / a level change, and a joining Harbour Master gets the head plot when it is free
-- (nobody else's dock ever moves). Lv 5 trophy hall: a cup per rescue milestone (BadgeRules.trophies) and a
-- plaque per island stamp (DiscoveryRules), rebuilt from the profile every few seconds when it changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BadgeConfig = require(Shared:WaitForChild("Config"):WaitForChild("BadgeConfig"))
local BadgeRules = require(Shared:WaitForChild("BadgeRules"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DiscoveryRules = require(Shared:WaitForChild("DiscoveryRules"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local DockPieces = require(Shared:WaitForChild("DockPieces"))
local Marina = require(Shared:WaitForChild("Marina"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local DockService = {}
DockService.Priority = 40 -- before VehicleService (50): the berths exist when it starts

local WOOD = Color3.fromRGB(122, 92, 62)
local DARK_WOOD = Color3.fromRGB(84, 62, 44)
local BOARD = Color3.fromRGB(236, 230, 214)
local GOLD = Color3.fromRGB(222, 178, 60)

type Plot = {
	model: Model,
	berth: Part,
	label: TextLabel,
	gui: SurfaceGui,
	board: Part,
	flag: Part,
	levels: Model?, -- Lv 2..built pieces
	built: number,
	buildings: { [string]: Model },
	counts: { TextLabel },
	trophies: Model?,
	trophyKey: string,
	master: Model?, -- the Harbour Master's tall flag
}

local plots: { Plot } = {}
local owners: { [number]: Player } = {}
local byPlayer: { [Player]: number } = {}
local master: Player? = nil

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
	return {
		model = model,
		berth = berth,
		label = label,
		gui = gui,
		board = board,
		flag = flag,
		built = 1,
		counts = {},
		buildings = {},
		trophyKey = "",
	}
end

-- the build beat: every part rises 6 studs from below, faded in, staggered
local function rise(m: Model)
	local k = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local final, alpha = d.CFrame, d.Transparency
			d.CFrame = final - Vector3.new(0, 6, 0)
			d.Transparency = 1
			k += 1
			TweenService:Create(
				d,
				TweenInfo.new(
					0.7,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out,
					0,
					false,
					0.04 * k
				),
				{ CFrame = final, Transparency = alpha }
			):Play()
		end
	end
end

-- Build the plot's level pieces up to `level` (beat = the new ones rise in); a lower level starts over.
local function sync(plot: Plot, owner: Player?, level: number, beat: boolean)
	if level < plot.built and plot.levels then
		plot.levels:Destroy()
		plot.levels, plot.built, plot.counts = nil, 1, {}
	end
	for n = plot.built + 1, math.min(level, DockConfig.MAX) do
		local levels = plot.levels or Instance.new("Model")
		levels.Name = "Levels"
		levels.Parent = plot.model
		plot.levels = levels
		local m = DockPieces.build(n, plot.berth.CFrame - Vector3.new(0, 0.2, 0))
		for _, d in m:GetDescendants() do
			if d.Name == "Flag" and d:IsA("BasePart") and owner then
				d.Color = Marina.flagColor(owner.UserId)
			elseif d.Name == "Count" and d:IsA("TextLabel") then
				table.insert(plot.counts, d)
			end
		end
		m.Parent = levels
		if beat then
			rise(m)
		end
		plot.built = n
	end
	plot.model:SetAttribute("DockLevel", level)
	if owner then
		owner:SetAttribute("DockLevel", level)
	end
end

-- The owner's bought buildings stand on the plot (the helipad only on a Lv 3+ boathouse); beat: new ones rise.
local function syncBuildings(plot: Plot, owner: Player?, beat: boolean)
	local data: any = owner and DataService.Get(owner)
	local owned = if data and type(data.dockBuildings) == "table" then data.dockBuildings else {}
	local level = if data then data.dockLevel or 1 else 1
	for _, key in DockConfig.BUILDINGS do
		local want = owner ~= nil
			and owned[key] == true
			and level >= DockConfig.Buildings[key].needs
		local have = plot.buildings[key]
		if want and not have and owner then
			local frame = if key == "Garage"
				then Marina.garage(plot.berth:GetAttribute("PlotIndex") :: number)
				else plot.berth.CFrame - Vector3.new(0, 0.2, 0)
			local m = DockPieces.building(key, frame)
			for _, d in m:GetDescendants() do
				if d.Name == "Flag" and d:IsA("BasePart") then
					d.Color = Marina.flagColor(owner.UserId)
				elseif d.Name == "Owner" and d:IsA("TextLabel") then
					d.Text = owner.DisplayName
				end
			end
			m.Parent = plot.model
			if beat then
				rise(m)
			end
			plot.buildings[key] = m
		elseif have and not want then
			have:Destroy()
			plot.buildings[key] = nil
		end
		plot.berth:SetAttribute(key, if want then true else nil)
		if owner then
			owner:SetAttribute("Dock" .. key, owned[key] == true)
		end
	end
end

local function tableOf(v: any): { [string]: any }
	return if type(v) == "table" then v else {}
end

-- The Lv 5 trophy hall's cups and plaques, rebuilt only when the owner's list changed.
local function syncTrophies(plot: Plot, owner: Player?)
	local data: any = owner and DataService.Get(owner)
	local cups, plaques = {}, {}
	if data and (data.dockLevel or 1) >= 5 then
		for _, key in BadgeRules.trophies(tableOf(data.badgeCounters), tableOf(data.badgesAwarded)) do
			table.insert(cups, BadgeConfig.Badges[key].name)
		end
		local state = DiscoveryRules.decode(tableOf(data.flags).isles)
		for _, page in DiscoveryRules.Pages do
			if DiscoveryRules.has(state, page.id, 4) then -- bit 4: the island stamp
				table.insert(plaques, { name = page.name, colour = page.colour })
			end
		end
	end
	local names = {}
	for _, p in plaques do
		table.insert(names, p.name)
	end
	local key = if data then `{table.concat(cups, ",")}|{table.concat(names, ",")}` else ""
	if key == plot.trophyKey then
		return
	end
	plot.trophyKey = key
	if plot.trophies then
		plot.trophies:Destroy()
		plot.trophies = nil
	end
	if #cups + #plaques > 0 then
		local m = DockPieces.trophies(plot.berth.CFrame - Vector3.new(0, 0.2, 0), cups, plaques)
		m.Parent = plot.model
		plot.trophies = m
	end
end

-- The Harbour Master's plot: a gold name board and a tall gold flag at the deck's back corner.
local function setMaster(plot: Plot, on: boolean)
	plot.board.Color = if on then GOLD else BOARD
	plot.board.Material = if on then Enum.Material.Metal else Enum.Material.SmoothPlastic
	plot.berth:SetAttribute("HarbourMaster", if on then true else nil)
	if on and not plot.master then
		local m = Instance.new("Model")
		m.Name = "HarbourMaster"
		local at = plot.berth.CFrame
			* CFrame.new(
				Marina.PLOT_X[2] - 1.5,
				Marina.DECK_TOP - 0.2,
				Marina.BERTH / 2 + Marina.DECK - 1.5
			)
		local pole = part(
			m,
			"Pole",
			Vector3.new(30, 0.6, 0.6),
			at * CFrame.new(0, 15, 0) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			Enum.Material.Metal
		)
		pole.Shape = Enum.PartType.Cylinder
		local top = part(
			m,
			"Finial",
			Vector3.new(1.4, 1.4, 1.4),
			at * CFrame.new(0, 30.5, 0),
			GOLD,
			Enum.Material.Neon
		)
		top.Shape = Enum.PartType.Ball
		part(
			m,
			"MasterFlag",
			Vector3.new(0.15, 4, 7),
			at * CFrame.new(0, 27.6, -3.7),
			GOLD,
			Enum.Material.Fabric
		).CanCollide =
			false
		m.Parent = plot.model
		plot.master = m
	elseif not on and plot.master then
		plot.master:Destroy()
		plot.master = nil
	end
end

-- Everyone with a plot and a loaded profile (plus `extra`), in plot order, as Harbour Master candidates.
local function candidates(extra: Player?): { Marina.Candidate }
	local list: { Marina.Candidate } = {}
	local function add(p: Player)
		local data: any = DataService.Get(p)
		if data then
			table.insert(
				list,
				{ key = p, rank = ProgressionRules.rankIndex(data), level = data.dockLevel or 1 }
			)
		end
	end
	for i = 1, Marina.COUNT do
		if owners[i] then
			add(owners[i])
		end
	end
	if extra then
		add(extra)
	end
	return list
end

-- Re-pick the Harbour Master (join, leave, level change); only the flag and the board change hands.
local function crown()
	local pick = Marina.harbourMaster(candidates(), master)
	if pick == master then
		return
	end
	master = pick
	for i, plot in plots do
		setMaster(plot, master ~= nil and owners[i] == master)
	end
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
	else
		sync(plot, nil, 1, false)
		syncBuildings(plot, nil, false)
		syncTrophies(plot, nil)
		setMaster(plot, false)
	end
end

-- The player's built level now matches the profile (beat: the new pieces rise in).
local function show(player: Player, beat: boolean)
	local i = byPlayer[player]
	local data: any = DataService.Get(player)
	if i and data then
		sync(plots[i], player, data.dockLevel or 1, beat)
		syncBuildings(plots[i], player, beat)
		crown()
	end
end

local busy: { [Player]: boolean } = {}

-- Cash + rank purchase of building `key` (Robux goes through its Dock<key> product).
local function buyBuilding(player: Player, data: any, key: string): (boolean, string)
	data.dockBuildings = if type(data.dockBuildings) == "table" then data.dockBuildings else {}
	local ok, reason, price = DockConfig.canBuyBuilding(
		key,
		data.dockBuildings[key] == true,
		data.dockLevel or 1,
		data.cash,
		ProgressionRules.rankIndex(data)
	)
	if not ok or not price then
		return false, reason or "Owned"
	end
	data.cash -= price
	data.dockBuildings[key] = true
	Telemetry.CashSpent(player, price, data.cash, "Dock", key)
	DataService.MarkDirty(player)
	ProgressionService.Refresh(player)
	show(player, true)
	task.spawn(DataService.Save, player, false)
	return true, "ok"
end

-- Cash + rank purchase of the next level (Robux goes through the DockLevel<n> products), or of a building.
local function buy(player: Player, level: any): (boolean, string)
	local data: any = DataService.Get(player)
	if not data then
		return false, "Data"
	end
	if busy[player] then
		return false, "Busy"
	end
	if type(level) == "string" and DockConfig.Buildings[level] then
		return buyBuilding(player, data, level)
	end
	if type(level) ~= "number" then
		return false, "Busy"
	end
	local ok, reason, price =
		DockConfig.canBuy(data.dockLevel or 1, level, data.cash, ProgressionRules.rankIndex(data))
	if not ok or not price then
		return false, reason or "Level"
	end
	data.cash -= price
	data.dockLevel = level
	Telemetry.CashSpent(player, price, data.cash, "Dock", `Lv{level}`)
	DataService.MarkDirty(player)
	ProgressionService.Refresh(player)
	show(player, true)
	task.spawn(DataService.Save, player, false)
	return true, "ok"
end

local function claim(player: Player)
	if byPlayer[player] or player.Parent ~= Players or not plots[1] then -- no plots before Init
		return
	end
	-- a joining Harbour Master takes the head plot when it is free
	local head = DataService.Get(player) ~= nil
		and Marina.harbourMaster(candidates(player), master) == player
	local i = Marina.assign(owners, head)
	if not i then
		warn(`[DockService] no free plot for {player.Name}`) -- shortcut: 16 plots = server size; a 17th player has no dock
		return
	end
	owners[i], byPlayer[player] = player, i
	dress(plots[i], player)
	player:SetAttribute("DockPlot", i)
	player:SetAttribute("BayCFrame", plots[i].berth.CFrame)
	crown()
end

local function release(player: Player)
	local i = byPlayer[player]
	if i then
		owners[i], byPlayer[player] = nil, nil
		if master == player then
			master = nil
		end
		dress(plots[i], nil)
		crown()
	end
end

-- The garage row's 16 lots along Penhallow Road (the garages stand on them once bought): the hedge and post
-- dressing in the footprint goes; each lot's slab runs 2 studs past the door onto the footway so a car
-- rolls straight out (no terrain carving: 4-stud voxels left a trench at the door).
local function garageLots(folder: Instance)
	local g = Marina.GARAGE
	local first, last = Marina.garage(1), Marina.garage(Marina.COUNT)
	local centre = first:Lerp(last, 0.5) * CFrame.new(0, 0, g.DEPTH / 2 - 1.5)
	local size = Vector3.new(g.WIDTH * Marina.COUNT + 2, 24, g.DEPTH + 5)
	local clear = centre * CFrame.new(0, size.Y / 2 + 0.05, 0)
	local dressing = Workspace:FindFirstChild("Dressing")
	if dressing then
		for _, p in Workspace:GetPartBoundsInBox(clear, size) do
			if p:IsDescendantOf(dressing) then
				p:Destroy()
			end
		end
	end
	for i = 1, Marina.COUNT do
		local lot = part(
			folder,
			`GarageLot{i}`,
			Vector3.new(g.WIDTH, 1, g.DEPTH + 2),
			Marina.garage(i) * CFrame.new(0, -0.5, g.DEPTH / 2 - 1),
			if i % 2 == 0 then Color3.fromRGB(150, 152, 156) else Color3.fromRGB(162, 164, 168),
			Enum.Material.SmoothPlastic
		)
		lot:SetAttribute("PlotIndex", i)
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
	garageLots(folder)
	folder.Parent = Workspace

	-- plots are claimed when the profile loads (Start), so the Harbour Master's rank is known
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		busy[player] = nil
	end)

	local folderNet = Net.init()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Dock_Upgrade"
	remote.OnServerInvoke = function(player: Player, level: any): (boolean, string)
		local ok, reason = buy(player, level)
		busy[player] = true -- one purchase per second
		task.delay(1, function()
			busy[player] = nil
		end)
		return ok, reason
	end
	remote.Parent = folderNet

	-- Robux skips Cash and rank; the grant only raises the level, so a retried receipt is harmless
	for n, lv in DockConfig.Levels do
		MonetizationService.OnProduct(lv.product, function(_player, data: any)
			data.dockLevel = math.max(data.dockLevel or 1, n)
			return true
		end, function(player)
			show(player, true)
		end)
	end
	for key, b in DockConfig.Buildings do
		MonetizationService.OnProduct(b.product, function(_player, data: any)
			data.dockBuildings = if type(data.dockBuildings) == "table"
				then data.dockBuildings
				else {}
			data.dockBuildings[key] = true
			return true
		end, function(player)
			show(player, true)
		end)
	end

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DockDev"
		dev.OnInvoke = function(cmd: string, n: any): any
			local player = Players:GetPlayers()[1]
			local data: any = player and DataService.Get(player)
			if cmd == "level" and data then
				data.dockLevel = math.clamp(tonumber(n) or 1, 1, DockConfig.MAX)
				DataService.MarkDirty(player)
				show(player, true)
				return data.dockLevel
			elseif cmd == "trophies" and data then
				data.badgeCounters = tableOf(data.badgeCounters)
				for _, key in BadgeConfig.Order do
					data.badgeCounters[key] = math.max(data.badgeCounters[key] or 0, 100)
				end
				data.flags = tableOf(data.flags)
				local isles = tableOf(data.flags.isles)
				for _, page in DiscoveryRules.Pages do
					isles[page.id] = bit32.bor(isles[page.id] or 0, 7)
				end
				data.flags.isles = isles
				DataService.MarkDirty(player)
				return true
			elseif cmd == "building" and data then
				data.dockBuildings = if type(data.dockBuildings) == "table"
					then data.dockBuildings
					else {}
				for key in DockConfig.Buildings do
					if n == key or n == "all" then
						data.dockBuildings[key] = true
					end
				end
				DataService.MarkDirty(player)
				show(player, true)
				return true
			end
			return nil
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

function DockService.Start()
	DataService.OnLoaded(function(player: Player, data: any)
		claim(player)
		local i = byPlayer[player]
		if i then
			sync(plots[i], player, data.dockLevel or 1, false)
			syncBuildings(plots[i], player, false)
			crown() -- GetBerth may have claimed before the profile loaded
		end
	end)
	-- the rescue boards show each owner's real rescue count (survivors delivered, RescueService)
	task.spawn(function()
		while true do
			for i, owner in owners do
				local data: any = DataService.Get(owner)
				local n = tostring(data and data.totalRescues or 0)
				for _, label in plots[i].counts do
					label.Text = n
				end
				syncTrophies(plots[i], owner)
			end
			task.wait(3)
		end
	end)
end

function DockService.GetPlot(player: Player): number?
	return byPlayer[player]
end

function DockService.GetBerth(player: Player): BasePart?
	claim(player) -- callers may run before the profile loads; nil before Init built the plots
	local i = byPlayer[player]
	local plot = i and plots[i]
	return if plot then plot.berth else nil
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
