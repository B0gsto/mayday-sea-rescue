--!strict
-- DockService (docs/23 WP-1; WP-19b; the unlock tree, WP-28): your island is your plot. Builds the six player
-- islands' docks (shared/Marina = RingLayout.Islands) as placeholder Parts in Workspace.Marina, gives each joining
-- player the lowest free island and frees it on leave. Every island has a bare jetty down its cove; an owner
-- adds their Lego name sign and flag; an unclaimed island is just land and the jetty. What you built lives in
-- the profile (data.dockBuildings) so it rebuilds on whichever island you get. VehicleService launches at the
-- island's Berth part (BayLaunch frame) and stands the player on the island spawn (GetSpawn).
-- The unlock tree (docs/23 (q), DockConfig.Buildings + shared/UnlockTree): each building stands on its spot once
-- owned; it is bought with Cash once its prerequisites stand (Dock_Upgrade) or with its Robux product (skips
-- the Cash, never the prerequisites: the grant waits until they stand). A buy starts one construction at a
-- time (docs/24 B): shared/BuildTimer measures its work, the island's Builders (and the two base crew NPCs)
-- cut the time, the progress is saved with the profile and the site is published on the plot as SiteKey /
-- SiteProgress / SiteRate / SiteBuilders for every client (ConstructionController). The building is not owned
-- until the site finishes; then the model that was standing there (DockPieces, hidden above the progress
-- height on every client) is the finished one and the build beat plays. Quest blueprints still arrive whole.
-- Bricks (docs/25 K4, shared/DepotRules): the site draws loads from data.depot, the supply barge refills it every
-- minute (each island's barge runs PlotIndex * BARGE_STAGGER s late), and the plot publishes DepotStock /
-- DepotCap / BargeNext / HaulRate / CarryRate / SiteWaiting; SiteRate is the rate the site really finishes at.
-- The build station by the spawn carries the tablet whose prompt opens the owner's top-down build mode
-- (DockController); its catalog is DockBlueprints.catalog: tree buildings, quest blueprints and decor.
--
-- API: GetBerth(player) -> BasePart?, GetPlot(player) -> number?, GetSpawn(player) -> CFrame?,
-- Owns(player, key) -> boolean (a DockConfig building), Berths() -> { BasePart }, Refresh(player) (rebuild).
-- Player attributes: DockPlot (index), BayCFrame (the berth CFrame; MapController reads it),
-- Dock<key> / Decor<key> (owned; the build tablet). Berth attributes: LaunchBay = true, PlotIndex, Owner
-- (UserId, nil when empty), <key> = true per building standing (BoatBoard reads Boathouse / Hangar / SubPen).
-- Remote: Dock_Upgrade C->S function (building / decor key) -> ok, reason ("Needs" | "Cash" | "Owned" |
-- "Data" | "Busy" | "Building" | "Unknown"). Dock_Finish C->S (no args) prompts the FinishNow tier for the
-- running site's current time left; its receipt finishes the site. Vehicle boards are server/Dock/BoatBoard's.
-- Studio: ServerStorage.DockDev:Invoke("building", key) gives the first player a building ("all": every one);
-- ("decor", key) a decoration ("all": every one); ("trophies") every rescue milestone and island stamp;
-- WorkerDev ("finishbuild") finishes the running site at once.
-- Harbour Master (docs/23 d.1, Marina.harbourMaster): the most people rescued among islands with a Station gets
-- a gold name sign and a tall gold beacon; picked on join / leave / a build (nobody's island ever moves). The
-- trophy hall: its plinths show the owner's specials, rarest survivors, wheel prizes and rescue-milestone cups
-- (TrophyRules), the shelf the other cups, a plaque per island stamp (DiscoveryRules); rebuilt from the profile
-- every few seconds when it changes.
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BadgeConfig = require(Shared:WaitForChild("Config"):WaitForChild("BadgeConfig"))
local BadgeRules = require(Shared:WaitForChild("BadgeRules"))
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DepotRules = require(Shared:WaitForChild("DepotRules"))
local DiscoveryRules = require(Shared:WaitForChild("DiscoveryRules"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local DockPieces = require(Shared:WaitForChild("DockPieces"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local Marina = require(Shared:WaitForChild("Marina"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local MonetizationService = require(script.Parent:WaitForChild("MonetizationService"))
local Net = require(Shared:WaitForChild("Net"))
local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local PrizeWheel = require(Shared:WaitForChild("PrizeWheel"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local SkillRules = require(Shared:WaitForChild("SkillRules"))
local SkillService = require(script.Parent:WaitForChild("SkillService"))
local SpinService = require(script.Parent:WaitForChild("SpinService"))
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))
local TrophyRules = require(Shared:WaitForChild("TrophyRules"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))

local DockService = {}
DockService.Priority = 40 -- before VehicleService (50): the berths exist when it starts

local WOOD = Color3.fromRGB(105, 64, 40) -- WP-25: Lego reddish brown
local DARK_WOOD = Color3.fromRGB(75, 48, 32)
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
	bands: { Frame }, -- the quay walks's tile bands, the flag colour (WP-25 r4), while the streets stand
	streets: Model?, -- docs/25 J: the plaza and the street grid, from HQ Lv1
	buildings: { [string]: Model },
	levels: { [string]: number }, -- the level each standing model shows
	counts: { TextLabel },
	trophies: Model?,
	trophyKey: string,
	master: Model?, -- the Harbour Master's gold beacon
	buildStation: Model?, -- the tablet station on the jetty head (WP-14d, docs/25 J), while owned
	decorations: Model?, -- the owner's bought decorations
	site: Model?, -- the building being built (DockPieces, still not owned), while a construction runs
	siteKey: string?,
	siteLevel: number?,
	crew: { { model: Model, height: number } }?, -- the two base builder NPCs walking to / from the site
	wheel: Model?, -- the prize wheel set on the plaza (docs/24 D), from HQ Lv1 (docs/25 J)
	wheelPrompt: ProximityPrompt?,
	wheelCount: TextLabel?,
	wheelConn: RBXScriptConnection?,
	rescueBoard: Model?, -- the rescue board on the plaza, with the wheel (docs/25 J)
}

local plots: { Plot } = {}
local owners: { [number]: Player } = {}
local byPlayer: { [Player]: number } = {}
local master: Player? = nil

local spinning: { [number]: boolean } = {}

-- The wheel's SPIN button and token machine (docs/24 D). All checks stay here and in SpinService.
local function wheelSpin(plotIndex: number, player: Player): boolean
	if owners[plotIndex] ~= player or spinning[plotIndex] then
		return false
	end
	local result = SpinService.WheelSpin(player)
	if result.ok ~= true then
		return false
	end
	spinning[plotIndex] = true
	local plot = plots[plotIndex]
	local prompt = plot and plot.wheelPrompt
	if prompt then
		prompt.Enabled = false
	end
	task.delay(result.duration or 4.5, function()
		spinning[plotIndex] = nil
		if owners[plotIndex] and prompt then
			prompt.Enabled = true
		end
	end)
	return true
end

local function wheelBuy(plotIndex: number, player: Player, key: string): boolean
	if owners[plotIndex] ~= player then
		return false
	end
	local item = MonetizationConfig.Products[key]
	if not item or item.id == 0 or item.ready == false then
		return false
	end
	local policy = MonetizationService.GetPolicy(player)
	if not (policy and policy.ArePaidRandomItemsRestricted == false) then
		return false
	end
	MarketplaceService:PromptProductPurchase(player, item.id)
	return true
end

local function paintWheel(plot: Plot)
	local owner = owners[plot.index]
	local free = owner and owner:GetAttribute("FreeSpins")
	local n = if type(free) == "number" then free else 0
	if plot.wheelCount then
		plot.wheelCount.Text = `SPINS {n}`
	end
	if plot.wheelPrompt then
		plot.wheelPrompt.ObjectText = if owner then `{n} free` else ""
		plot.wheelPrompt.Enabled = if owner then true else false
	end
end

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
		Enum.Material.SmoothPlastic
	)
	p.Shape = Enum.PartType.Cylinder
end

-- WP-25: chunky Lego studs on a deck's top (the stud tile DockPieces and IslandPlates use)
local function studTop(p: Part)
	local t = Instance.new("Texture")
	t.Face = Enum.NormalId.Top
	t.Texture = "rbxassetid://18878365966"
	t.StudsPerTileU, t.StudsPerTileV = 8, 8
	t.Color3 = p.Color:Lerp(Color3.new(0, 0, 0), 0.15)
	t.Transparency = 0.2
	t.Parent = p
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
	-- WP-25: twice the old size, an arch over the jetty's root that frames the boat approach
	local BW, BH, Y = 26, 6, 12 -- the board, its centre height
	local px = BW / 2 + 1.7
	for _, dx in { -px, px } do
		brick("SignBase", Vector3.new(3.6, 1, 3.6), CFrame.new(dx, 0.5, 0), dark)
		brick(
			"SignPost",
			Vector3.new(2.2, Y + BH / 2, 2.2),
			CFrame.new(dx, 1 + (Y + BH / 2) / 2, 0),
			dark
		)
		local cap = brick(
			"SignStud",
			Vector3.new(0.6, 1.4, 1.4),
			CFrame.new(dx, Y + BH / 2 + 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			faceColor,
			true
		)
		cap.Shape = Enum.PartType.Cylinder
	end
	for _, dy in { -1, 1 } do
		brick(
			"SignFrame",
			Vector3.new(BW + 1.6, 0.8, 1.2),
			CFrame.new(0, Y + dy * (BH / 2 + 0.4), 0),
			dark
		)
	end
	for _, dx in { -1, 1 } do
		brick("SignFrame", Vector3.new(0.8, BH, 1.2), CFrame.new(dx * (BW / 2 + 0.4), Y, 0), dark)
	end
	for _, dx in { -9, -3, 3, 9 } do
		local stud = brick(
			"SignStud",
			Vector3.new(0.6, 1.4, 1.4),
			CFrame.new(dx, Y + BH / 2 + 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
			faceColor,
			true
		)
		stud.Shape = Enum.PartType.Cylinder
	end
	local board = part(
		sign,
		"NameBoard",
		Vector3.new(BW, BH, 0.8),
		arch * CFrame.new(0, Y, 0),
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
	studTop(
		part(
			model,
			"Jetty",
			Vector3.new(jetty.size.X, 1, len),
			jcf * CFrame.new(0, -0.5, 2),
			WOOD,
			Enum.Material.SmoothPlastic
		)
	)
	for z = -jetty.size.Y / 2 + 1, jetty.size.Y / 2 - 6, 12 do
		for _, x in { -jetty.size.X / 2 + 0.6, jetty.size.X / 2 - 0.6 } do
			post(model, jcf * CFrame.new(x, 0, z), top + 0.8, -10)
		end
	end
	local j = Marina.JETTY
	studTop(
		part(
			model,
			"Finger",
			Vector3.new(j.x1 - j.x0, 1, j.z1 - j.out),
			b * CFrame.new((j.x0 + j.x1) / 2, top - 0.5, (j.z1 + j.out) / 2),
			WOOD,
			Enum.Material.SmoothPlastic
		)
	)
	for _, z in { j.out + 1, (j.out + j.z1) / 2 } do
		post(model, b * CFrame.new(j.x1 - 0.6, 0, z), top + 0.8, -10)
	end

	-- docs/25 J: the jetty head, a deck off the west side of the jetty's quay end that carries the build stand
	local head = DockConfig.JETTY_HEAD
	local hcf = jcf * CFrame.new(head.offset.X, 0, head.offset.Y)
	studTop(
		part(
			model,
			"JettyHead",
			Vector3.new(head.size.X, 1, head.size.Y),
			hcf * CFrame.new(0, -0.5, 0),
			WOOD,
			Enum.Material.SmoothPlastic
		)
	)
	for _, x in { -head.size.X / 2 + 0.6, 0, head.size.X / 2 - 0.6 } do
		post(model, hcf * CFrame.new(x, 0, -head.size.Y / 2 + 0.6), top + 0.8, -10)
	end

	DockPieces.base(b).Parent = model -- docs/25 J: only the plate's quay edge (every island, owned or not)

	-- the owner's sign (only while the island has an owner): a Lego name sign over the jetty's quay end,
	-- facing the cove, and a flag beside it
	local sign = Instance.new("Model")
	sign.Name = "Sign"
	local isle = b * Marina.ISLAND
	local arch = isle * CFrame.new(0, 0, -28.5)
	local board, labels, trim, studs = nameSign(sign, arch, BOARD)
	local poleAt = isle * CFrame.new(-34, 0, -28)
	studTop(
		part(
			sign,
			"FlagBase",
			Vector3.new(3.2, 1, 3.2),
			poleAt * CFrame.new(0, 0.5, 0),
			Color3.fromRGB(242, 240, 232),
			Enum.Material.SmoothPlastic
		)
	)
	part(
		sign,
		"FlagPole",
		Vector3.new(0.9, 24, 0.9),
		poleAt * CFrame.new(0, 12, 0),
		Color3.fromRGB(242, 240, 232),
		Enum.Material.SmoothPlastic
	)
	local flag = part(
		sign,
		"Flag",
		Vector3.new(0.3, 4.5, 7),
		poleAt * CFrame.new(0, 21.6, -3.9),
		BOARD,
		Enum.Material.SmoothPlastic
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
		bands = {},
		counts = {},
		buildings = {},
		levels = {},
		trophyKey = "",
	}
end

local buildRemote: RemoteEvent? = nil

-- Everyone animates the new model in (WP-14c): the pieces are already in their final state here.
local function announceBuild(plot: Plot, parentName: string?, modelName: string)
	if buildRemote then
		buildRemote:FireAllClients({ plot = plot.index, parent = parentName, name = modelName })
	end
end

-- bought buildings, then quest blueprints (DockConfig.Blueprints, WP-21b)
local BUILT = table.clone(DockConfig.BUILDINGS)
for key in DockConfig.Blueprints do
	table.insert(BUILT, key)
end

-- docs/25 J: the prize wheel set (odds board, tokens) arrives with the HQ, on the plaza west of the avenue (docs/25
-- map: island r -30), facing the cove; the set runs along the plaza, clear of the HQ and the sign's flag pole
local function placeWheel(plot: Plot)
	local i = plot.index
	local at = plot.frame * Marina.ISLAND * CFrame.new(-28, 0, -14)
	local wheel = PrizeWheel.build(at, {
		spin = function(player: Player)
			return wheelSpin(i, player)
		end,
		buy = function(player: Player, key: string)
			return wheelBuy(i, player, key)
		end,
	})
	wheel:SetAttribute("Plot", i)
	wheel.Parent = plot.model
	CollectionService:AddTag(wheel, "PrizeWheel")
	local cap = wheel:FindFirstChild("SpinButton", true)
	local count = wheel:FindFirstChild("FreeCount", true)
	plot.wheel = wheel
	plot.wheelPrompt = cap and cap:FindFirstChildOfClass("ProximityPrompt")
	plot.wheelCount = if count and count:IsA("TextLabel") then count else nil
	paintWheel(plot)
	-- the rescue board mirrors the wheel east of the avenue, facing the cove
	local board = LeaderboardService.Board(plot.frame * Marina.ISLAND * CFrame.new(28, 5.7, -14))
	board.Parent = plot.model
	plot.rescueBoard = board
end

-- docs/25 J: the streets (plaza, avenue, lanes, bridge road, the quay walks' owner bands) and the prize wheel stand
-- while the HQ does; a bare island has neither.
local function syncStreets(plot: Plot, owner: Player?, beat: boolean)
	local hq: Model? = plot.buildings.HQ
	local want = owner ~= nil and hq ~= nil
	if want and owner and not plot.streets then
		local m = DockPieces.streets(plot.frame)
		plot.bands = DockPieces.quayBands(m, plot.frame)
		for _, f in plot.bands do
			f.BackgroundColor3 = Marina.flagColor(owner.UserId)
		end
		m.Parent = plot.model
		plot.streets = m
		placeWheel(plot)
		if beat then
			announceBuild(plot, nil, "Streets")
		end
	elseif not want and plot.streets then
		plot.streets:Destroy()
		plot.streets, plot.bands = nil, {}
		if plot.wheel then
			plot.wheel:Destroy()
		end
		if plot.rescueBoard then
			plot.rescueBoard:Destroy()
		end
		plot.wheel, plot.wheelPrompt, plot.wheelCount, plot.rescueBoard = nil, nil, nil, nil
	end
end

-- The owner's bought buildings stand on the plot at their level; beat: new ones play the build animation.
local function syncBuildings(plot: Plot, owner: Player?, beat: boolean)
	local data: any = owner and DataService.Get(owner)
	local owned = if data and type(data.dockBuildings) == "table" then data.dockBuildings else {}
	local levels = if data and data.dock then data.dock.levels else {}
	if not owner then
		plot.counts = {}
	end
	for _, key in BUILT do
		local b = DockConfig.Buildings[key]
		local wantLevel = if b then UnlockTree.levelOf(levels, key) else 0
		local want = if b then wantLevel >= 1 else owner ~= nil and owned[key] == true
		local have = plot.buildings[key]
		local shown = plot.levels[key] or 0
		-- MissingMesh: built while its mesh failed to load (DepotArtService refreshes once it loads)
		local stale = if have then have:GetAttribute("MissingMesh") ~= nil else false
		if want and owner and (not have or stale or (b and shown < wantLevel)) then
			local m
			if b and plot.siteKey == key and plot.site and (plot.siteLevel or 1) == wantLevel then
				m = plot.site -- the site finished: the bricks that stood there are the building
				plot.site, plot.siteKey, plot.siteLevel = nil, nil, nil
				m.Name = key
			else
				m = DockPieces.building(key, plot.frame, if b then wantLevel else nil)
				-- a first mesh load yields: another sync or the owner's release may have run meanwhile
				if plot.buildings[key] ~= have or owners[plot.index] ~= owner then
					m:Destroy()
					continue
				end
			end
			if have then
				have:Destroy()
			end
			for _, d in m:GetDescendants() do
				if d.Name == "Flag" and d:IsA("BasePart") then
					d.Color = Marina.flagColor(owner.UserId)
				elseif d.Name == "Owner" and d:IsA("TextLabel") then
					d.Text = owner.DisplayName
				elseif d.Name == "Count" and d:IsA("TextLabel") then
					table.insert(plot.counts, d) -- the pontoon's rescue board
				end
			end
			m.Parent = plot.model
			if beat then
				announceBuild(plot, nil, key)
			end
			plot.buildings[key] = m
			plot.levels[key] = wantLevel
		elseif have and not want then
			have:Destroy()
			plot.buildings[key] = nil
			plot.levels[key] = nil
		end
		if b then
			plot.berth:SetAttribute(key, if want then true else nil)
			plot.berth:SetAttribute(`{key}Level`, if want then wantLevel else nil)
		else
			plot.berth:SetAttribute(key, if want then true else nil)
		end
		if owner then
			owner:SetAttribute("Dock" .. key, want)
			if b then
				owner:SetAttribute(`DockLevel{key}`, wantLevel)
			end
		end
	end
	syncStreets(plot, owner, beat)
	-- old boards read the merged aliases (Hangar, Helipad, Station, ...)
	for _, key in { "Pontoon", "Crane", "LifeboatSlip", "Hangar", "Helipad", "Station" } do
		plot.berth:SetAttribute(key, if owned[key] == true then true else nil)
		if owner then
			owner:SetAttribute("Dock" .. key, owned[key] == true)
		end
	end
end

local function tableOf(v: any): { [string]: any }
	return if type(v) == "table" then v else {}
end

-- Re-derive the old boolean maps after levels change; decor and quest blueprints stay booleans.
local function deriveDock(data: any)
	data.dock = if type(data.dock) == "table"
		then data.dock
		else { levels = { Harbour = 1 }, prepaid = {} }
	data.dock.levels = tableOf(data.dock.levels)
	data.dock.prepaid = tableOf(data.dock.prepaid)
	local oldOwned = tableOf(data.dockBuildings)
	local oldPrepaid = tableOf(data.dockPrepaid)
	local out = UnlockTree.ownedSet(data.dock.levels)
	for key, owned in oldOwned do
		if DockConfig.Blueprints[key] or DockConfig.Decorations[key] then
			out[key] = owned
		end
	end
	data.dockBuildings = out
	local prepaid: { [string]: boolean } = {}
	for key, n in data.dock.prepaid do
		if n > UnlockTree.levelOf(data.dock.levels, key) then
			prepaid[key] = true
		end
	end
	for key, paid in oldPrepaid do
		if DockConfig.Decorations[key] then
			prepaid[key] = paid
		end
	end
	data.dockPrepaid = prepaid
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
			local m
			if plot.siteKey == key and plot.site then
				m = plot.site
				plot.site, plot.siteKey = nil, nil
				m.Name = key
			else
				m = DockPieces.decoration(key, plot.frame)
			end
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

-- The skill tree's build totals (SkillService attributes; no skills = today's numbers).
local function buildSkill(player: Player): BuildTimer.Skill
	return {
		max = BuildTimer.BUILDERS + (tonumber(player:GetAttribute("SkillExtraBuilders")) or 0),
		mult = tonumber(player:GetAttribute("SkillBuildRate")) or 1,
		crew = tonumber(player:GetAttribute("SkillBaseCrew")) or 0,
	}
end

local function baseCrew(player: Player): number
	return BuildTimer.BASE_CREW + (tonumber(player:GetAttribute("SkillBaseCrew")) or 0)
end

local function workOf(key: string, level: number?): number
	local b = DockConfig.Buildings[key]
	if b then
		return BuildTimer.work(b.levels[math.clamp(level or 1, 1, #b.levels)].cash)
	end
	local d = DockConfig.Decorations[key]
	return BuildTimer.work(d and d.cash or 0, true)
end

local BARGE_STAGGER = 10 -- s between the islands' barges

local function bargeOffset(player: Player): number
	return (byPlayer[player] or 0) * BARGE_STAGGER
end

-- docs/25 K4: the Depot's numbers for this island now (with a site: its carry speed and loads) and the
-- Builders' crew rate.
local function depotParams(player: Player, data: any): (DepotRules.Params, number)
	local e = SkillRules.effects(data.skills)
	local skill = buildSkill(player)
	local rate = DepotRules.crewRate(
		data.workers,
		{ max = skill.max, mult = skill.mult, crew = skill.crew, carry = e.buildersCarry }
	)
	local level = UnlockTree.levelOf(data.dock.levels, "Depot")
	local haul = DepotRules.haulUnits(
		data.workers,
		data.dockBuildings,
		{ Hauler = tonumber(player:GetAttribute("SkillSlotsHauler")) or 0 }
	)
	local p: DepotRules.Params =
		{ cap = DepotRules.cap(level), drop = DepotRules.bargeLoads(level, haul, e.depotRefill) }
	local c = data.construction
	if c then
		local work = workOf(c.key, c.level)
		p.carry, p.loads = DepotRules.carrySpeed(rate, work), DepotRules.loadsFor(work)
	end
	return p, rate
end

-- Steps the Depot (and the site drawing from it) up to `now`: one tick, or the whole time away on join.
-- -> s the site waited on an empty Depot, the params used, the crew rate.
local function stepDepot(
	player: Player,
	data: any,
	now: number
): (number, DepotRules.Params, number)
	local c = data.construction
	local from = data.depot.at or (c and c.at) or now
	local p, rate = depotParams(player, data)
	local state, waited = DepotRules.advance({
		stock = data.depot.stock,
		progress = c and c.progress,
		next = DepotRules.nextAt(from, bargeOffset(player)),
	}, p, now - from)
	data.depot.stock, data.depot.at = state.stock, now
	if c then
		c.progress, c.rate, c.at = state.progress or c.progress, rate, now
	end
	return waited, p, rate
end

-- Seconds until the running site finishes, barge waits included (the tablet's timer, the FinishNow tier).
local function siteLeft(player: Player, data: any): number
	local c = data.construction
	if not c then
		return 0
	end
	local p = depotParams(player, data)
	return (
		DepotRules.timeLeft({
			stock = data.depot.stock,
			progress = c.progress,
			next = DepotRules.nextAt(os.time(), bargeOffset(player)),
		}, p)
	)
end

-- The K4 plot attributes the Depot, barge, Hauler and Builder visuals read.
local function publishDepot(
	plot: Plot,
	player: Player,
	data: any,
	p: DepotRules.Params,
	rate: number,
	waited: number
)
	local t = Workspace:GetServerTimeNow()
	plot.model:SetAttribute("DepotStock", math.floor(data.depot.stock + 1e-6))
	plot.model:SetAttribute("DepotCap", p.cap)
	plot.model:SetAttribute(
		"BargeNext",
		math.floor(t + DepotRules.nextAt(t, bargeOffset(player)) + 0.5)
	)
	plot.model:SetAttribute("HaulRate", p.drop * 60 / DepotRules.BARGE_PERIOD)
	plot.model:SetAttribute("CarryRate", (p.carry or rate / DepotRules.LOAD_WORK) * 60)
	plot.model:SetAttribute("SiteWaiting", if data.construction and waited > 0 then true else nil)
end

-- What the build cost in Cash (the FinishNow refund on a lost race), buildings and decor alike.
local function cashOf(key: string, level: number?): number
	local b = DockConfig.Buildings[key]
	if b then
		return b.levels[math.clamp(level or 1, 1, #b.levels)].cash
	end
	local d = DockConfig.Decorations[key]
	return d and d.cash or 0
end

-- Where a site stands (berth frame) and its footprint, for the base crew's walk.
local function siteSpot(plot: Plot, key: string): (CFrame?, Vector2?)
	local b = DockConfig.Buildings[key]
	if b then
		return plot.frame * b.spot, b.size
	end
	local d = DockConfig.Decorations[key]
	if d then
		return DockConfig.decorSpot(key, plot.frame), d.size
	end
	return nil, nil
end

-- Clear the published site state and any site model on a plot (released, or the build is done).
local function clearSite(plot: Plot)
	if plot.site then
		plot.site:Destroy()
		plot.site = nil
	end
	plot.siteKey, plot.siteLevel = nil, nil
	plot.model:SetAttribute("SiteKey", nil)
	plot.model:SetAttribute("SiteProgress", nil)
	plot.model:SetAttribute("SiteRate", nil)
	plot.model:SetAttribute("SiteBuilders", nil)
	plot.model:SetAttribute("SiteLevel", nil)
	plot.model:SetAttribute("SiteWaiting", nil)
end

-- The model that rises with the progress; it stays unowned (no effects, unlocks or worker slots) until done.
local function makeSite(plot: Plot, key: string, level: number?)
	if plot.siteKey == key and plot.siteLevel == level and plot.site then
		return
	end
	clearSite(plot)
	local m = if DockConfig.Buildings[key]
		then DockPieces.building(key, plot.frame, level)
		elseif DockConfig.Decorations[key] then DockPieces.decoration(key, plot.frame)
		else nil
	if not m then
		return
	end
	if plot.site or not owners[plot.index] then -- a first mesh load yielded: another site or a release came first
		m:Destroy()
		return
	end
	m.Name = `Site_{key}`
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- clients hide its parts: they must all arrive together
	m.Parent = plot.model
	plot.site, plot.siteKey, plot.siteLevel = m, key, level
end

-- The one construction's state for clients (ConstructionController draws it; the tablet shows its timer).
local function syncSite(plot: Plot, data: any, player: Player)
	local c = data.construction
	if c then
		plot.model:SetAttribute("SiteKey", c.key)
		plot.model:SetAttribute("SiteLevel", c.level)
		plot.model:SetAttribute("SiteProgress", c.progress)
		local left = siteLeft(player, data)
		local work = workOf(c.key, c.level)
		plot.model:SetAttribute(
			"SiteRate",
			if left > 0 then (1 - c.progress) * work / left else c.rate
		)
		plot.model:SetAttribute(
			"SiteBuilders",
			#BuildTimer.builders(data.workers, buildSkill(player).max) + baseCrew(player)
		)
	else
		clearSite(plot)
	end
end

local function crewWalk(m: Model, height: number, to: Vector3, look: Vector3)
	local from = m:GetPivot().Position - Vector3.new(0, height, 0)
	local dist = (to - from).Magnitude
	local steps = math.max(1, math.ceil(dist / 2.2))
	for i = 1, steps do
		if m.Parent == nil then
			return
		end
		local p = from:Lerp(to, i / steps)
		m:PivotTo(CFrame.lookAt(p + Vector3.new(0, height, 0), look + Vector3.new(0, height, 0)))
		task.wait(math.clamp(dist / steps / 9, 0.05, 0.2)) -- ~9 studs/s
	end
end

-- The hard-hat base crew (two, or three with the Builder skill): station -> site, back when done.
local function spawnCrew(plot: Plot, count: number?)
	if plot.crew then
		return
	end
	local key = plot.siteKey
	local site = key and siteSpot(plot, key)
	if not site then
		return
	end
	local at = DockConfig.stationSpot(plot.frame)
	plot.crew = {}
	local n = math.max(1, count or BuildTimer.BASE_CREW)
	for k = 1, n do
		local side = (k - (n + 1) / 2) * (if n == 2 then 11 else 6)
		task.spawn(function()
			local feet = at * CFrame.new(side, 0, -7.2)
			local m, height = NpcFactory.spawn("Crew", {
				seed = math.random(1, 1_000_000),
				pose = "Idle",
				cframe = CFrame.lookAt(feet.Position, at.Position),
				parent = Workspace,
			})
			hardHat(m)
			local crew = plot.crew
			if not crew or plot.siteKey ~= key then
				m:Destroy()
				return
			end
			table.insert(crew, { model = m, height = height })
			local to = site * CFrame.new(side * 4.5, 0, 6)
			crewWalk(m, height, to.Position, site.Position)
		end)
	end
end

-- Walk the base crew back to the station, then let them go (the site is done).
local function sendCrewHome(plot: Plot)
	local crew = plot.crew
	plot.crew = nil
	if not crew then
		return
	end
	local at = DockConfig.stationSpot(plot.frame)
	for k, row in crew do
		task.spawn(function()
			local m = row.model
			if m.Parent then
				local side = if k % 2 == 1 then -1 else 1
				local to = at * CFrame.new(side * 5.5, 0, -7.2)
				crewWalk(m, row.height, to.Position, at.Position)
			end
			task.wait(0.4)
			m:Destroy()
		end)
	end
end

local function clearCrew(plot: Plot)
	local crew: { { model: Model, height: number } } = plot.crew or {}
	for _, row in crew do
		row.model:Destroy()
	end
	plot.crew = nil
end

-- The trophy hall's plinths (TrophyRules: specials, rare survivors, wheel prizes, cups), shelf and plaques, rebuilt
-- only when that line, the stamps or the hall's plinths changed.
local function syncTrophies(plot: Plot, owner: Player?)
	local data: any = owner and DataService.Get(owner)
	local items: { TrophyRules.Item }, plaques = {}, {}
	if data and tableOf(data.dockBuildings).TrophyHall == true then
		local cups = {}
		for _, key in BadgeRules.trophies(tableOf(data.badgeCounters), tableOf(data.badgesAwarded)) do
			table.insert(cups, BadgeConfig.Badges[key].name)
		end
		items = TrophyRules.items(
			tableOf(data.workers) :: any,
			TrophyRules.wheelPrizes(tableOf(data.flags)),
			cups
		)
		local state = DiscoveryRules.decode(tableOf(data.flags).isles)
		for _, page in DiscoveryRules.Pages do
			if DiscoveryRules.has(state, page.id, 4) then -- bit 4: the island stamp
				table.insert(plaques, { name = page.name, colour = page.colour })
			end
		end
	end
	local names = {}
	for _, it in items do
		table.insert(names, `{it.kind}:{it.name}:{it.rarity}:{it.category}`)
	end
	for _, p in plaques do
		table.insert(names, p.name)
	end
	-- the add-on mesh's plinths take the first items (DockPieces.trophies): 8 at Lv2, 14 at Lv3
	local hall = plot.buildings.TrophyHall
	local plinths = if hall and hall:FindFirstChild("TrophyHallMesh")
		then (if (plot.levels.TrophyHall or 1) >= 3 then 14 else 8)
		else 0
	local key = if data then `{table.concat(names, ",")}|{plinths}` else ""
	if key == plot.trophyKey then
		return
	end
	plot.trophyKey = key
	if plot.trophies then
		plot.trophies:Destroy()
		plot.trophies = nil
	end
	if #items + #plaques > 0 then
		local m = DockPieces.trophies(plot.frame, items, plaques, plinths)
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
		local at = plot.frame * Marina.ISLAND * CFrame.new(21, 0, -28)
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
			Vector3.new(2.2, 2.2, 2.2),
			at * CFrame.new(0, 35.1, 0),
			GOLD,
			Enum.Material.Neon
		)
		lens.Shape = Enum.PartType.Ball
		local glow = Instance.new("PointLight")
		glow.Color = GOLD
		glow.Range = 36 -- WP-25 r6: softer, the bloom washed out the berth
		glow.Brightness = 1.5
		glow.Parent = lens
		local a0 = Instance.new("Attachment")
		a0.Parent = lens
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 45, 0)
		a1.Parent = lens
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 1.6, 4
		beam.FaceCamera = true
		beam.LightEmission = 0.25
		beam.Color = ColorSequence.new(GOLD)
		beam.Transparency = NumberSequence.new(0.88, 1)
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
			table.insert(list, {
				key = p,
				rescued = data.totalRescues,
				station = tableOf(data.dockBuildings).Station == true,
			})
		end
	end
	for i = 1, Marina.COUNT do
		if owners[i] then
			add(owners[i])
		end
	end
	return list
end

-- Re-pick the Harbour Master (join, leave, a build); only the sign's colours change hands.
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

-- The owner's sign and build station, or the bare jetty when empty.
local function dress(plot: Plot, owner: Player?)
	plot.berth:SetAttribute("Owner", if owner then owner.UserId else nil)
	for _, label in plot.labels do
		label.Text = if owner then owner.DisplayName else ""
	end
	plot.sign.Parent = if owner then plot.model else nil
	if owner then
		plot.flag.Color = Marina.flagColor(owner.UserId)
		for _, f in plot.bands do
			f.BackgroundColor3 = plot.flag.Color
		end
		setMaster(plot, master == owner)
		if not plot.buildStation then
			local st = DockPieces.buildStation(plot.frame)
			st.Parent = plot.model
			plot.buildStation = st
		end
		syncDecor(plot, owner, false)
	else
		clearSite(plot)
		clearCrew(plot)
		syncBuildings(plot, nil, false)
		syncDecor(plot, nil, false)
		syncTrophies(plot, nil)
		setMaster(plot, false)
		if plot.buildStation then
			plot.buildStation:Destroy()
			plot.buildStation = nil
		end
	end
	if plot.wheelConn then
		plot.wheelConn:Disconnect()
		plot.wheelConn = nil
	end
	if owner then
		plot.wheelConn = owner:GetAttributeChangedSignal("FreeSpins"):Connect(function()
			paintWheel(plot)
		end)
	end
	paintWheel(plot)
end

-- One construction at a time per island (docs/24 B): the site rises from nothing, the crew walks over.
local function startConstruction(player: Player, data: any, key: string, level: number?)
	local buildLevel = if DockConfig.Buildings[key]
		then math.clamp(level or 1, 1, #DockConfig.Buildings[key].levels)
		else nil
	-- docs/24 E: a tutorial Workshop Lv1 (Cash or Robux) advances the saved step so a rejoin is at the site
	if
		key == Onboarding.WORKSHOP
		and (buildLevel or 1) == 1
		and (data.tutorialStep or 0) < Onboarding.STEP_SITE
	then
		local beat = Onboarding.beat({
			coldOpenDone = data.coldOpenDone == true,
			totalRescues = data.totalRescues or 0,
			step = data.tutorialStep,
			owned = data.dockBuildings or {},
			constructionKey = nil,
		})
		-- "Rescue": a cold open that ended without a delivery (0 rescues) still buys the tutorial Workshop
		if beat == "BuildStation" or beat == "Rescue" then
			data.tutorialStep = Onboarding.STEP_SITE
			DataService.MarkDirty(player)
			ProgressionService.Refresh(player) -- the buy's own Refresh ran before this step moved
		end
	end
	Telemetry.Build(
		player,
		key,
		buildLevel or 1,
		false,
		(data.tutorialStep or 0) >= Onboarding.STEP_DONE
	)
	stepDepot(player, data, os.time()) -- the Depot fills up to now before the site draws from it
	data.construction = {
		key = key,
		level = buildLevel,
		progress = 0,
		rate = BuildTimer.rateOf(data.workers, buildSkill(player)),
		at = os.time(),
	}
	DataService.MarkDirty(player)
	local i = byPlayer[player]
	if i then
		makeSite(plots[i], key, buildLevel)
		syncSite(plots[i], data, player)
		spawnCrew(plots[i], baseCrew(player))
	end
	task.spawn(DataService.Save, player, false)
end

-- A Robux-paid building whose prerequisites now stand starts its own construction (one at a time).
local function startPrepaid(player: Player, data: any)
	if data.construction then
		return
	end
	deriveDock(data)
	local levels = data.dock.levels
	-- one paid level per row waits: the next one that is legal now starts
	for _, key in DockConfig.BUILDINGS do
		local n = tableOf(data.dock.prepaid)[key]
		if n then
			local current = UnlockTree.levelOf(levels, key)
			if n <= current then
				data.dock.prepaid[key] = nil
			elseif n == current + 1 and UnlockTree.canBuild(key, n, levels, math.huge) then
				data.dock.prepaid[key] = nil
				deriveDock(data)
				startConstruction(player, data, key, n)
				return
			end
		end
	end
	for _, key in DockConfig.DECOR do
		if tableOf(data.dockPrepaid)[key] then
			data.dockPrepaid[key] = nil
			startConstruction(player, data, key)
			return
		end
	end
end

-- A construction saved with the profile: make sure its site and crew are up.
local function resumeSite(plot: Plot, player: Player, data: any)
	local c = data.construction
	if not c then
		clearSite(plot)
		clearCrew(plot)
		return
	end
	makeSite(plot, c.key, c.level)
	syncSite(plot, data, player)
	spawnCrew(plot, baseCrew(player))
	DataService.MarkDirty(player)
end

-- The player's island now matches the profile (beat: new quest/Dev pieces play the build animation).
local function show(player: Player, beat: boolean)
	local i = byPlayer[player]
	local data: any = DataService.Get(player)
	if i and data then
		local plot = plots[i]
		resumeSite(plot, player, data)
		syncBuildings(plot, player, beat)
		syncDecor(plot, player, beat)
		startPrepaid(player, data)
		crown()
	end
end

local busy: { [Player]: boolean } = {}
local lastBuild: { [Player]: { key: string, cash: number } } = {}
local lastPrompt: { [Player]: number } = {}

local FINISH_MIN_LEFT = 3 -- under this the site finishes on its own
local FINISH_PROMPT_COOLDOWN = 1

-- The client asks to finish (it never names a tier): prompt the product matching the site's time left now.
local function promptFinish(player: Player)
	local now = os.clock()
	if now - (lastPrompt[player] or 0) < FINISH_PROMPT_COOLDOWN then
		return
	end
	lastPrompt[player] = now
	local data: any = DataService.Get(player)
	local c = data and data.construction
	if not (c and byPlayer[player]) then
		return
	end
	local left = siteLeft(player, data)
	if left < FINISH_MIN_LEFT then
		return
	end
	local product = MonetizationConfig.Products[`FinishNow{BuildTimer.finishTier(left)}`]
	if not product or product.ready == false or product.id == 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.id)
end

-- Cash purchase of tree building `key` once its prerequisites stand (Robux goes through its product).
local function buyBuilding(player: Player, data: any, key: string, level: number): (boolean, string)
	deriveDock(data)
	-- docs/24 E: the tutorial tops up a short wallet to exactly the Workshop price, once (the buy's
	-- coin burst shows it). startConstruction moves the saved step on (Robux starts the same site).
	local beat = Onboarding.beat({
		coldOpenDone = data.coldOpenDone == true,
		totalRescues = data.totalRescues or 0,
		step = data.tutorialStep,
		owned = data.dockBuildings,
		constructionKey = if data.construction then data.construction.key else nil,
	})
	if key == Onboarding.WORKSHOP and beat == "BuildStation" then
		local gap = Onboarding.topUp(data.cash, DockConfig.Buildings[key].levels[1].cash)
		if gap > 0 then
			data.cash += gap
			DataService.MarkDirty(player)
		end
	end
	local ok, reason, price = UnlockTree.canBuild(key, level, data.dock.levels, data.cash)
	if not ok or not price then
		return false, reason or "Owned"
	end
	data.cash -= price
	Telemetry.CashSpent(player, price, data.cash, "Dock", key)
	ProgressionService.Refresh(player)
	startConstruction(player, data, key, level)
	return true, "ok"
end

-- Cash purchase of a decoration (WP-14d); needs only the jetty (its Robux product: the grant below).
local function buyDecor(player: Player, data: any, key: string): (boolean, string)
	data.dockBuildings = tableOf(data.dockBuildings)
	local ok, reason, price =
		DockConfig.canBuyDecor(key, data.dockBuildings[key] == true, data.cash)
	if not ok or not price then
		return false, reason or "Owned"
	end
	data.cash -= price
	Telemetry.CashSpent(player, price, data.cash, "Dock", key)
	ProgressionService.Refresh(player)
	startConstruction(player, data, key)
	return true, "ok"
end

-- A Cash purchase: a tree building or a decoration.
local function buy(player: Player, key: any): (boolean, string)
	local data: any = DataService.Get(player)
	if not data then
		return false, "Data"
	end
	if data.construction then
		return false, "Building" -- one site at a time (docs/24 B)
	end
	if type(key) == "string" and DockConfig.Buildings[key] then
		local n = UnlockTree.levelOf(data.dock.levels, key) + 1
		if tableOf(data.dock.prepaid)[key] == n then
			return false, "Owned" -- Robux paid already: it builds next, never charge Cash for it too
		end
		if busy[player] then
			return false, "Busy"
		end
		return buyBuilding(player, data, key, n)
	elseif busy[player] then
		return false, "Busy"
	elseif type(key) == "string" and DockConfig.Decorations[key] then
		return buyDecor(player, data, key)
	end
	return false, "Unknown"
end

-- The work is done: the building becomes owned (effects, unlocks, worker slots) and the site stands.
local function finishConstruction(plot: Plot, player: Player, data: any)
	local c = data.construction
	if not c then
		return
	end
	lastBuild[player] = { key = c.key, cash = cashOf(c.key, c.level) }
	Telemetry.Build(player, c.key, c.level or 1, true, false)
	data.construction = nil
	if DockConfig.Buildings[c.key] then
		local n = math.clamp(c.level or 1, 1, #DockConfig.Buildings[c.key].levels)
		if n > UnlockTree.levelOf(data.dock.levels, c.key) then
			data.dock.levels[c.key] = n
			if c.key == "HQ" then
				SkillService.grantMedals(player, SkillRules.HQ_MEDALS, "HQ") -- docs/25 K3, once per new level
			end
		end
	else
		data.dockBuildings = tableOf(data.dockBuildings)
		data.dockBuildings[c.key] = true
	end
	deriveDock(data)
	DataService.MarkDirty(player)
	syncBuildings(plot, player, false)
	syncDecor(plot, player, false)
	clearSite(plot)
	sendCrewHome(plot)
	ProgressionService.Refresh(player)
	-- docs/24 E: the Workshop's completion hands out the one tutorial spin (the chip then pulses Spin)
	if c.key == Onboarding.WORKSHOP then
		local ok, spin = pcall(require, script.Parent:WaitForChild("SpinService"))
		if ok and type(spin) == "table" and type(spin.Tutorial) == "function" then
			spin.Tutorial(player)
		end
	end
	task.spawn(DataService.Save, player, false)
	-- let every client see the finished site play its beat before the next paid build starts
	task.delay(2, function()
		local latest: any = DataService.Get(player)
		if latest and latest.construction == nil and byPlayer[player] then
			startPrepaid(player, latest)
		end
	end)
end

-- A build and the barge keep going while the owner is away: one DepotRules step before the plot is shown.
local function applyOffline(player: Player, data: any)
	stepDepot(player, data, os.time())
	DataService.MarkDirty(player)
	local c = data.construction
	local i = byPlayer[player]
	if c and c.progress >= 1 and i then
		finishConstruction(plots[i], player, data)
	end
end

-- One second of the island's Depot and running construction; it publishes both for every client.
local function tickConstruction(plot: Plot, player: Player, data: any)
	local before = data.depot.stock
	local waited, p, rate = stepDepot(player, data, os.time())
	local c = data.construction
	if c and c.progress >= 1 then
		finishConstruction(plot, player, data)
		p, rate = depotParams(player, data)
	elseif c then
		makeSite(plot, c.key, c.level)
		syncSite(plot, data, player)
		spawnCrew(plot, baseCrew(player))
	end
	if owners[plot.index] ~= player then
		return -- released while a first mesh load yielded: the island is empty now
	end
	publishDepot(plot, player, data, p, rate, waited)
	if c or data.depot.stock ~= before then
		DataService.MarkDirty(player)
	end
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
		for _, name in
			{ "DepotStock", "DepotCap", "BargeNext", "HaulRate", "CarryRate", "SiteWaiting" }
		do
			plots[i].model:SetAttribute(name, nil) -- an empty island has no Depot
		end
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

	-- plots are claimed when the profile loads (Start), so the Harbour Master's count is known
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		busy[player] = nil
		lastBuild[player] = nil
		lastPrompt[player] = nil
	end)

	local folderNet = Net.init()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Dock_Upgrade"
	remote.OnServerInvoke = function(player: Player, key: any): (boolean, string)
		local ok, reason = buy(player, key)
		if reason ~= "Busy" then -- one purchase per second; a refused tap must not re-arm it (taps < 1 s apart stuck it)
			busy[player] = true
			task.delay(1, function()
				busy[player] = nil
			end)
		end
		return ok, reason
	end
	remote.Parent = folderNet

	-- the Lego build beat (WP-14c): clients drop the new model's pieces in (DockController)
	local buildEvent = Instance.new("RemoteEvent")
	buildEvent.Name = "Dock_Build"
	buildEvent.Parent = folderNet
	buildRemote = buildEvent

	Net.event("Dock_Finish").OnServerEvent:Connect(promptFinish)

	-- Robux skips the Cash, never the order: a level whose HQ gate/prerequisites are missing is granted as
	-- prepaid (show builds it once legal); a retried receipt for the same level is harmless.
	for _, key in DockConfig.BUILDINGS do
		local b = DockConfig.Buildings[key]
		for n, lvl in b.levels do
			local target = n
			if lvl.product then
				MonetizationService.OnProduct(lvl.product, function(_player, data: any)
					deriveDock(data)
					local current = UnlockTree.levelOf(data.dock.levels, key)
					local paid = data.dock.prepaid[key]
					local building = data.construction
					if
						target <= current
						or (paid and paid >= target)
						or (building and building.key == key and (building.level or 1) == target)
					then
						return true
					end
					if data.construction then
						data.dock.prepaid[key] = math.max(paid or 0, target)
						deriveDock(data)
						return true
					end
					if UnlockTree.canRobux(key, target, data.dock.levels) then
						startConstruction(_player, data, key, target)
					else
						data.dock.prepaid[key] = math.max(paid or 0, target)
						deriveDock(data)
					end
					return true
				end, function(player)
					show(player, false)
				end)
			end
		end
	end
	for key, d in DockConfig.Decorations do
		if d.product then
			MonetizationService.OnProduct(d.product, function(_player, data: any)
				deriveDock(data)
				if
					data.dockBuildings[key]
					or data.dockPrepaid[key]
					or (data.construction and data.construction.key == key)
				then
					return true
				end
				if data.construction then
					data.dockPrepaid[key] = true
					return true
				end
				startConstruction(_player, data, key)
				return true
			end, function(player)
				show(player, false)
			end)
		end
	end
	-- Robux Finish now (docs/24 B): finish through the same path as FinishBuild; a receipt that lands after
	-- the site stood pays a tenth of its Cash price back, so the Robux is never lost.
	for tier = 1, 3 do
		MonetizationService.OnProduct(`FinishNow{tier}`, function(player, data: any)
			local c = data.construction
			-- the tier must cover the time left (a client can prompt a cheaper tier's id itself)
			if c and c.progress < 1 and BuildTimer.finishTier(siteLeft(player, data)) <= tier then
				c.progress = 1 -- the receipt's save holds it; the next tick / rejoin finishes
				return true
			end
			local last = lastBuild[player]
			data.cash = (data.cash or 0) + math.floor((if last then last.cash else 0) * 0.1)
			return true
		end, function(player)
			local data: any = DataService.Get(player)
			local c = data and data.construction
			if c and c.progress >= 1 then
				DockService.FinishBuild(player) -- never a later site a receipt retry finds running
			end
		end)
	end

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DockDev"
		dev.OnInvoke = function(cmd: string, n: any): any
			local player = Players:GetPlayers()[1]
			local data: any = player and DataService.Get(player)
			if cmd == "trophies" and data then
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
			elseif cmd == "reset" and data then -- back to the bare start (art renders)
				data.dock = { levels = { Harbour = 1 }, prepaid = {} }
				data.dockBuildings, data.dockPrepaid = {}, {}
				deriveDock(data)
				DataService.MarkDirty(player)
				show(player, false)
				return true
			elseif cmd == "building" and data then
				deriveDock(data)
				local name, levelText = string.match(tostring(n), "^(.-):(%d+)$")
				for key, b in DockConfig.Buildings do
					if n == key or name == key or n == "all" then
						data.dock.levels[key] = if n == "all"
							then #b.levels
							else math.clamp(tonumber(levelText) or #b.levels, 1, #b.levels)
					end
				end
				deriveDock(data)
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
		applyOffline(player, data) -- a build finished while away stands on rejoin
		show(player, false)
		crown() -- GetBerth may have claimed before the profile loaded
	end)
	task.spawn(function() -- one construction tick a second per owner
		while true do
			for player, i in byPlayer do
				local plot = plots[i]
				local data: any = DataService.Get(player)
				if data and plot then
					tickConstruction(plot, player, data)
				end
			end
			task.wait(1)
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

-- Studio playtest hook (WorkerDev): finish the running site at once.
function DockService.FinishBuild(player: Player): boolean
	local data: any = DataService.Get(player)
	local i = byPlayer[player]
	if not (data and data.construction and i) then
		return false
	end
	data.construction.progress = 1
	finishConstruction(plots[i], player, data)
	return true
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

-- The level of island building `key` (0 when unbuilt); decor returns 1/0.
function DockService.Level(player: Player, key: string): number
	local data: any = DataService.Get(player)
	if not data then
		return 0
	end
	if DockConfig.Buildings[key] then
		return UnlockTree.levelOf(if data.dock then data.dock.levels else {}, key)
	end
	return if type(data.dockBuildings) == "table" and data.dockBuildings[key] == true then 1 else 0
end

-- Does the player own island building `key` (DockConfig.Buildings), merged aliases included? VehicleService:
-- the pontoon's second berth, the crane's no-wait relaunch.
function DockService.Owns(player: Player, key: string): boolean
	return DockService.Level(player, key) >= 1
end

function DockService.Berths(): { BasePart }
	local out: { BasePart } = {}
	for _, plot in plots do
		table.insert(out, plot.berth)
	end
	return out
end

return DockService
