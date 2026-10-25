--!strict
-- DockService (docs/23 WP-1; WP-19b): your island is your plot. Builds the six player islands' docks
-- (shared/Marina = HubLayout.Islands) as placeholder Parts in Workspace.Marina, gives each joining player the
-- lowest free island and frees it on leave. Every island has a bare jetty down its cove; Lv 1 adds the owner's
-- Lego name sign and flag; an unclaimed island is just land and the jetty. The dock level lives in the profile
-- (data.dockLevel, default 1) so later levels rebuild on whichever island the player gets. VehicleService
-- launches at the island's Berth part (BayLaunch frame) and stands the player on the island spawn (GetSpawn).
-- Levels 2..5 (WP-4, DockConfig): each adds the DockPieces of that level on the plot, built here so everyone
-- sees them. Bought with Cash + rank (Dock_Upgrade) or Robux (MonetizationConfig DockLevel<n>, skips both);
-- a buy plays the Lego build beat: the pieces exist here in their final state, the Dock_Build event lets
-- every client drop them in (shared/BuildSeq), and two builder NPCs stand by the build station (WP-14d).
-- The build station by the spawn (docs/23 (j) rule 4) carries the tablet whose prompt opens the owner's
-- top-down build mode (DockController). Its catalog is DockBlueprints.catalog: levels, buildings, quest
-- blueprints and the Cash-only Decorations on the spare lots.
--
-- API: GetBerth(player) -> BasePart?, GetPlot(player) -> number?, GetSpawn(player) -> CFrame?,
-- GetLevel(player) -> number, Berths() -> { BasePart }, Refresh(player) (rebuild from the profile).
-- Player attributes: DockPlot (index), BayCFrame (the berth CFrame; StreakController, MapController read it),
-- DockLevel (built level, DockController's build mode reads it), Dock<key> / Decor<key> (owned).
-- Remote: Dock_Upgrade C->S function (level | building/decor key) -> ok, reason ("Level" | "Rank" |
-- "Cash" | "Owned" | "Data" | "Busy").
-- Buildings (docs/23 h, WP-10b; DockConfig.Buildings): the helipad + hangar on their island lots and the
-- sub pen over the cove's sub berth. Owned ones live in data.dockBuildings; Dock_Upgrade(key) buys one with Cash +
-- rank, products DockHangar / DockSubPen with Robux. Their vehicle boards are server/Dock/BoatBoard's.
-- Studio: ServerStorage.DockDev:Invoke("level", n) sets the first player's dock level; ("building", key)
-- gives them a building ("all": every one); ("decor", key) gives them a decoration ("all": every one);
-- ("trophies") every rescue milestone and island stamp.
-- Berth attributes: LaunchBay = true, PlotIndex, Owner (UserId, nil when empty), Hangar / SubPen
-- (built). Player attributes DockHangar / DockSubPen / Decor<key> (owned; the build tablet).
-- WP-13: plots are handed out once the profile loads (GetBerth claims earlier if asked). Harbour Master
-- (docs/23 d.1, Marina.harbourMaster): the highest rank among Lv 5 docks gets a gold name sign and a tall gold
-- beacon on their island; picked on join / leave / a level change (nobody's island ever moves). Lv 5 trophy hall: a cup per rescue milestone (BadgeRules.trophies) and a
-- plaque per island stamp (DiscoveryRules), rebuilt from the profile every few seconds when it changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local DockService = {}
DockService.Priority = 40 -- before VehicleService (50): the berths exist when it starts

local WOOD = Color3.fromRGB(122, 92, 62)
local DARK_WOOD = Color3.fromRGB(84, 62, 44)
local BOARD = Color3.fromRGB(236, 230, 214)
local GOLD = Color3.fromRGB(222, 178, 60)
local HARD_HAT = Color3.fromRGB(250, 205, 35)

type Plot = {
	index: number,
	model: Model,
	frame: CFrame, -- the berth frame (Marina.berth, sea level)
	berth: Part,
	sign: Model, -- name sign + flag, parented only while owned
	labels: { TextLabel },
	board: Part, -- the sign's face brick (the owner's flag colour, gold for the Harbour Master)
	trim: { Part }, -- its frame bricks, posts and bases, a darker shade of the face
	studs: { Part }, -- the stud row along its top edge, the face colour
	flag: Part,
	levels: Model?, -- Lv 2..built pieces
	built: number,
	buildings: { [string]: Model },
	counts: { TextLabel },
	trophies: Model?,
	trophyKey: string,
	master: Model?, -- the Harbour Master's gold beacon
	buildStation: Model?, -- the tablet station by the spawn (WP-14d), while owned
	decorations: Model?, -- the owner's bought decorations
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

-- The sign's frame, posts and bases: the face colour, darker (only SmoothPlastic: it is a Lego brick).
local function signTrim(c: Color3): Color3
	return Color3.new(c.R * 0.62, c.G * 0.62, c.B * 0.62)
end

-- A Lego name sign: a chunky brick face (18 x 4.4 studs, readable from the water and the bridge) with a
-- darker brick frame, square brick posts on 2x brick bases and a stud row along the top. The two
-- SurfaceGui labels are white FredokaOne with a black stroke, TextScaled with a size cap so any
-- DisplayName fits inside the frame with padding.
local function nameSign(
	sign: Model,
	arch: CFrame,
	faceColor: Color3
): (Part, { TextLabel }, { Part }, { Part })
	local trim: { Part } = {}
	local studs: { Part } = {}
	local function brick(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		accent: boolean?
	): Part
		local p = part(sign, name, size, arch * cf, color, Enum.Material.SmoothPlastic)
		table.insert(if accent then studs else trim, p)
		return p
	end
	local dark = signTrim(faceColor)
	for _, dx in { -10.4, 10.4 } do
		brick("SignBase", Vector3.new(3.2, 0.8, 3.2), CFrame.new(dx, 0.4, 0), dark)
		brick("SignPost", Vector3.new(1.6, 5.7, 1.6), CFrame.new(dx, 3.65, 0), dark)
	end
	for _, dy in { -2.5, 2.5 } do
		brick("SignFrame", Vector3.new(19.2, 0.6, 1), CFrame.new(0, 9.3 + dy, 0), dark)
	end
	for _, dx in { -9.3, 9.3 } do
		brick("SignFrame", Vector3.new(0.6, 5.6, 1), CFrame.new(dx, 9.3, 0), dark)
	end
	for _, dx in { -6, 0, 6 } do
		local stud = brick(
			"SignStud",
			Vector3.new(0.5, 1, 1),
			CFrame.new(dx, 12.35, 0) * CFrame.Angles(0, 0, math.pi / 2),
			faceColor,
			true
		)
		stud.Shape = Enum.PartType.Cylinder
	end
	local board = part(
		sign,
		"NameBoard",
		Vector3.new(18, 4.4, 0.8),
		arch * CFrame.new(0, 9.3, 0),
		faceColor,
		Enum.Material.SmoothPlastic
	)
	local labels = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 30
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.93, 0.84)
		label.Position = UDim2.fromScale(0.035, 0.08)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 100
		fit.MinTextSize = 8
		fit.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 5
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
		table.insert(labels, label)
	end
	return board, labels, trim, studs
end

local function buildPlot(folder: Instance, i: number): Plot
	local b = Marina.berth(i)
	local top = Marina.DECK_TOP
	local model = Instance.new("Model")
	model.Name = `Plot{i}`
	-- the jetty down the cove (its lot, run on to the quay wall) and the finger beside the berth
	local jetty = Marina.LOTS.Jetty
	local jcf = b * jetty.cf
	local len = jetty.size.Y + 4
	part(
		model,
		"Jetty",
		Vector3.new(jetty.size.X, 1, len),
		jcf * CFrame.new(0, -0.5, 2),
		WOOD,
		Enum.Material.Wood
	)
	for z = -jetty.size.Y / 2 + 1, jetty.size.Y / 2 - 6, 12 do
		for _, x in { -jetty.size.X / 2 + 0.6, jetty.size.X / 2 - 0.6 } do
			post(model, jcf * CFrame.new(x, 0, z), top + 0.8, -10)
		end
	end
	local j = Marina.JETTY
	part(
		model,
		"Finger",
		Vector3.new(j.x1 - j.x0, 1, j.z1 - j.out),
		b * CFrame.new((j.x0 + j.x1) / 2, top - 0.5, (j.z1 + j.out) / 2),
		WOOD,
		Enum.Material.Wood
	)
	for _, z in { j.out + 1, (j.out + j.z1) / 2 } do
		post(model, b * CFrame.new(j.x1 - 0.6, 0, z), top + 0.8, -10)
	end

	-- the owner's sign (only while the island has an owner): a Lego name sign over the jetty's quay end,
	-- facing the cove, and a flag beside it
	local sign = Instance.new("Model")
	sign.Name = "Sign"
	local isle = b * Marina.ISLAND
	local arch = isle * CFrame.new(0, 0, -28.5)
	local board, labels, trim, studs = nameSign(sign, arch, BOARD)
	local poleAt = isle * CFrame.new(-12, 0, -27)
	part(
		sign,
		"FlagPole",
		Vector3.new(0.5, 24, 0.5),
		poleAt * CFrame.new(0, 12, 0),
		Color3.fromRGB(200, 200, 205),
		Enum.Material.Metal
	)
	local flag = part(
		sign,
		"Flag",
		Vector3.new(0.15, 4, 6.5),
		poleAt * CFrame.new(0, 21.8, -3.5),
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
		index = i,
		model = model,
		frame = b,
		berth = berth,
		sign = sign,
		labels = labels,
		board = board,
		trim = trim,
		studs = studs,
		flag = flag,
		built = 1,
		counts = {},
		buildings = {},
		trophyKey = "",
	}
end

local buildRemote: RemoteEvent? = nil
local BUILD_WATCH = 6 -- s the builder NPCs stay (matches the client's build beat)

-- Everyone animates the new model in (WP-14c): the pieces are already in their final state here.
local function announceBuild(plot: Plot, parentName: string?, modelName: string)
	if buildRemote then
		buildRemote:FireAllClients({ plot = plot.index, parent = parentName, name = modelName })
	end
end

-- Build the plot's level pieces up to `level` (beat = the new ones play the build animation); a lower
-- level starts over.
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
		local m = DockPieces.build(n, plot.frame)
		for _, d in m:GetDescendants() do
			if d.Name == "Flag" and d:IsA("BasePart") and owner then
				d.Color = Marina.flagColor(owner.UserId)
			elseif d.Name == "Count" and d:IsA("TextLabel") then
				table.insert(plot.counts, d)
			end
		end
		m.Parent = levels
		if beat then
			announceBuild(plot, "Levels", `Lv{n}`)
		end
		plot.built = n
	end
	plot.model:SetAttribute("DockLevel", level)
	if owner then
		owner:SetAttribute("DockLevel", level)
	end
end

-- bought buildings, then quest blueprints (DockConfig.Blueprints, WP-21b)
local BUILT = table.clone(DockConfig.BUILDINGS)
for key in DockConfig.Blueprints do
	table.insert(BUILT, key)
end

-- The owner's bought buildings stand on the plot (the helipad only on a Lv 3+ boathouse); beat: new
-- ones play the build animation.
local function syncBuildings(plot: Plot, owner: Player?, beat: boolean)
	local data: any = owner and DataService.Get(owner)
	local owned = if data and type(data.dockBuildings) == "table" then data.dockBuildings else {}
	local level = if data then data.dockLevel or 1 else 1
	for _, key in BUILT do
		local b = DockConfig.Buildings[key]
		local want = owner ~= nil and owned[key] == true and level >= (if b then b.needs else 1)
		local have = plot.buildings[key]
		if want and not have and owner then
			local m = DockPieces.building(key, plot.frame)
			for _, d in m:GetDescendants() do
				if d.Name == "Flag" and d:IsA("BasePart") then
					d.Color = Marina.flagColor(owner.UserId)
				elseif d.Name == "Owner" and d:IsA("TextLabel") then
					d.Text = owner.DisplayName
				end
			end
			m.Parent = plot.model
			if beat then
				announceBuild(plot, nil, key)
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

-- The owner's decorations (WP-14d) stand on their spare lots; beat: new ones play the build animation.
local function syncDecor(plot: Plot, owner: Player?, beat: boolean)
	local data: any = owner and DataService.Get(owner)
	local owned = if data and type(data.dockBuildings) == "table" then data.dockBuildings else {}
	local holder = plot.decorations
	if owner and not holder then
		local made = Instance.new("Model")
		made.Name = "Decorations"
		made.Parent = plot.model
		plot.decorations = made
		holder = made
	end
	for _, key in DockConfig.DECOR do
		local want = owner ~= nil and owned[key] == true
		local have = holder and holder:FindFirstChild(key)
		if want and not have and holder and owner then
			local m = DockPieces.decoration(key, plot.frame)
			for _, d in m:GetDescendants() do
				if d.Name == "Flag" and d:IsA("BasePart") then
					d.Color = Marina.flagColor(owner.UserId)
				end
			end
			m.Parent = holder
			if beat then
				announceBuild(plot, "Decorations", key)
			end
		elseif have and not want then
			have:Destroy()
		end
		if owner then
			owner:SetAttribute("Decor" .. key, owned[key] == true)
		end
	end
	if not owner and plot.decorations then
		plot.decorations:Destroy()
		plot.decorations = nil
	end
end

-- The Crew rigs already wear the rescue helmet; swap it for a chunky yellow builder's hard hat (WP-14c).
local function hardHat(model: Model)
	local found = model:FindFirstChild("Head")
	if not (found and found:IsA("BasePart")) then
		return
	end
	local head = found :: BasePart
	for _, a in model:GetChildren() do
		if a:IsA("Accessory") and a.AccessoryType == Enum.AccessoryType.Hat then
			a:Destroy()
		end
	end
	local function cap(name: string, size: Vector3, offset: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = head.CFrame * offset
		p.Color = HARD_HAT
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = false, false, false, false
		p.Massless = true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = head, p
		w.Parent = p
		p.Parent = model
	end
	cap("HardHat", Vector3.new(1.7, 0.5, 1.7), CFrame.new(0, head.Size.Y / 2 + 0.2, 0))
	cap("HardHatBrim", Vector3.new(1.7, 0.12, 0.5), CFrame.new(0, head.Size.Y / 2 + 0.02, -0.85))
end

-- Two builder NPCs (R15 crew, hard hats, NpcFactory's building) by the station while the beat plays, gone after.
local function spawnBuilders(plot: Plot)
	local at = DockConfig.stationSpot(plot.frame)
	for side = -1, 1, 2 do
		task.spawn(function()
			local feet = at * CFrame.new(side * 5.5, 0, -7.2)
			local m = NpcFactory.spawn("Crew", {
				seed = math.random(1, 1_000_000),
				pose = "Idle",
				cframe = CFrame.lookAt(feet.Position, at.Position),
				parent = Workspace,
			})
			hardHat(m)
			task.delay(BUILD_WATCH, function()
				m:Destroy()
			end)
		end)
	end
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
		local m = DockPieces.trophies(plot.frame, cups, plaques)
		m.Parent = plot.model
		plot.trophies = m
	end
end

-- The Harbour Master's island: the name sign turns gold and a tall gold beacon stands beside the jetty.
local function setMaster(plot: Plot, on: boolean)
	local owner = owners[plot.index]
	local face = if on then GOLD elseif owner then Marina.flagColor(owner.UserId) else BOARD
	plot.board.Color = face
	for _, p in plot.trim do
		p.Color = signTrim(face)
	end
	for _, p in plot.studs do
		p.Color = face
	end
	plot.berth:SetAttribute("HarbourMaster", if on then true else nil)
	if on and not plot.master then
		local m = Instance.new("Model")
		m.Name = "HarbourMaster"
		local at = plot.frame * Marina.ISLAND * CFrame.new(12, 0, -27)
		local pole = part(
			m,
			"Pole",
			Vector3.new(34, 0.9, 0.9),
			at * CFrame.new(0, 17, 0) * CFrame.Angles(0, 0, math.pi / 2),
			GOLD,
			Enum.Material.Metal
		)
		pole.Shape = Enum.PartType.Cylinder
		local lens = part(
			m,
			"Beacon",
			Vector3.new(3, 3, 3),
			at * CFrame.new(0, 35.5, 0),
			GOLD,
			Enum.Material.Neon
		)
		lens.Shape = Enum.PartType.Ball
		local glow = Instance.new("PointLight")
		glow.Color = GOLD
		glow.Range = 60
		glow.Brightness = 4
		glow.Parent = lens
		local a0 = Instance.new("Attachment")
		a0.Parent = lens
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 260, 0)
		a1.Parent = lens
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 4, 10
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(GOLD)
		beam.Transparency = NumberSequence.new(0.6, 1)
		beam.Parent = lens
		m.Parent = plot.model
		plot.master = m
	elseif not on and plot.master then
		plot.master:Destroy()
		plot.master = nil
	end
end

-- Everyone with a plot and a loaded profile, in plot order, as Harbour Master candidates.
local function candidates(): { Marina.Candidate }
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
	return list
end

-- Re-pick the Harbour Master (join, leave, level change); only the sign's colours change hands.
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

-- Lv 1 for the owner (the sign and the build station), or the bare jetty when empty.
local function dress(plot: Plot, owner: Player?)
	plot.berth:SetAttribute("Owner", if owner then owner.UserId else nil)
	for _, label in plot.labels do
		label.Text = if owner then owner.DisplayName else ""
	end
	plot.sign.Parent = if owner then plot.model else nil
	if owner then
		plot.flag.Color = Marina.flagColor(owner.UserId)
		setMaster(plot, master == owner)
		if not plot.buildStation then
			local st = DockPieces.buildStation(plot.frame)
			st.Parent = plot.model
			plot.buildStation = st
		end
		syncDecor(plot, owner, false)
	else
		sync(plot, nil, 1, false)
		syncBuildings(plot, nil, false)
		syncDecor(plot, nil, false)
		syncTrophies(plot, nil)
		setMaster(plot, false)
		if plot.buildStation then
			plot.buildStation:Destroy()
			plot.buildStation = nil
		end
	end
end

-- The player's built level now matches the profile (beat: the build animation + builders play).
local function show(player: Player, beat: boolean)
	local i = byPlayer[player]
	local data: any = DataService.Get(player)
	if i and data then
		sync(plots[i], player, data.dockLevel or 1, beat)
		syncBuildings(plots[i], player, beat)
		syncDecor(plots[i], player, beat)
		if beat then
			spawnBuilders(plots[i])
		end
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

-- Cash-only purchase of a decoration (WP-14d); no rank gate, no Robux product.
local function buyDecor(player: Player, data: any, key: string): (boolean, string)
	data.dockBuildings = if type(data.dockBuildings) == "table" then data.dockBuildings else {}
	local ok, reason, price =
		DockConfig.canBuyDecor(key, data.dockBuildings[key] == true, data.cash)
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

-- Cash + rank purchase of the next level (Robux goes through the DockLevel<n> products), of a building,
-- or Cash-only decor.
local function buy(player: Player, level: any): (boolean, string)
	local data: any = DataService.Get(player)
	if not data then
		return false, "Data"
	end
	if busy[player] then
		return false, "Busy"
	end
	if type(level) == "string" then
		if DockConfig.Buildings[level] then
			return buyBuilding(player, data, level)
		elseif DockConfig.Decorations[level] then
			return buyDecor(player, data, level)
		end
		return false, "Level"
	end
	if type(level) ~= "number" then
		return false, "Level"
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
	local i = Marina.assign(owners)
	if not i then
		warn(`[DockService] no free island for {player.Name}`) -- shortcut: 6 islands = server size; a 7th player has no dock
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

function DockService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Marina"
	for i = 1, Marina.COUNT do
		plots[i] = buildPlot(folder, i)
		dress(plots[i], nil)
	end
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

	-- the Lego build beat (WP-14c): clients drop the new model's pieces in (DockController)
	local buildEvent = Instance.new("RemoteEvent")
	buildEvent.Name = "Dock_Build"
	buildEvent.Parent = folderNet
	buildRemote = buildEvent

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
			elseif cmd == "decor" and data then
				data.dockBuildings = if type(data.dockBuildings) == "table"
					then data.dockBuildings
					else {}
				for _, key in DockConfig.DECOR do
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
			syncDecor(plots[i], player, false)
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

-- Rebuild the player's plot from the profile, new pieces rising in (QuestService after a blueprint unlock).
function DockService.Refresh(player: Player)
	show(player, true)
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

-- Where the player spawns and respawns: their island's spawn (VehicleService stands them there), nil without one.
function DockService.GetSpawn(player: Player): CFrame?
	local i = byPlayer[player]
	return if i then Marina.spawn(i) else nil
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
