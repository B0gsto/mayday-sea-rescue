--!strict
-- DockService (docs/23 WP-1; WP-19b; the unlock tree, WP-28): your island is your plot. Builds the six player
-- islands' docks (shared/Marina = RingLayout.Islands) as placeholder Parts in Workspace.Marina, gives each joining
-- player the lowest free island and frees it on leave. Every island has a bare jetty down its cove; an owner
-- adds their Lego name sign and flag; an unclaimed island is just land and the jetty. What you built lives in
-- the profile (data.dockBuildings) so it rebuilds on whichever island you get. VehicleService launches at the
-- island's Berth part (BayLaunch frame) and stands the player on the island spawn (GetSpawn).
-- The unlock tree (docs/23 (q), DockConfig.Buildings + shared/UnlockTree): each building stands on its spot once
-- owned; it is bought with Cash once its prerequisites stand (Dock_Upgrade) or with its Robux product (skips
-- the Cash, never the prerequisites: the grant refuses until they stand, so the receipt waits). A buy plays the
-- Lego build beat: the pieces exist here in their final state, the Dock_Build event lets every client drop
-- them in (shared/BuildSeq), and two builder NPCs stand by the build station (WP-14d). The build station by
-- the spawn carries the tablet whose prompt opens the owner's top-down build mode (DockController); its
-- catalog is DockBlueprints.catalog: tree buildings, quest blueprints and the Cash-only Decorations.
--
-- API: GetBerth(player) -> BasePart?, GetPlot(player) -> number?, GetSpawn(player) -> CFrame?,
-- Owns(player, key) -> boolean (a DockConfig building), Berths() -> { BasePart }, Refresh(player) (rebuild).
-- Player attributes: DockPlot (index), BayCFrame (the berth CFrame; StreakController, MapController read it),
-- Dock<key> / Decor<key> (owned; the build tablet). Berth attributes: LaunchBay = true, PlotIndex, Owner
-- (UserId, nil when empty), <key> = true per building standing (BoatBoard reads Boathouse / Hangar / SubPen).
-- Remote: Dock_Upgrade C->S function (building / decor key) -> ok, reason ("Needs" | "Cash" | "Owned" |
-- "Data" | "Busy" | "Unknown"). Vehicle boards are server/Dock/BoatBoard's.
-- Studio: ServerStorage.DockDev:Invoke("building", key) gives the first player a building ("all": every one);
-- ("decor", key) a decoration ("all": every one); ("trophies") every rescue milestone and island stamp.
-- Harbour Master (docs/23 d.1, Marina.harbourMaster): the most people rescued among islands with a Station gets
-- a gold name sign and a tall gold beacon; picked on join / leave / a build (nobody's island ever moves). The
-- trophy hall: a cup per rescue milestone (BadgeRules.trophies) and a plaque per island stamp (DiscoveryRules),
-- rebuilt from the profile every few seconds when it changes.
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
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))
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
	bands: { Frame }, -- the quay walks's tile bands, the flag colour (WP-25 r4)
	markers: { [string]: Model }, -- empty lots' pads and peg flags (WP-25 r4)
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

	DockPieces.base(b).Parent = model -- WP-25: paths, trees, the lifebuoy stand (every island, owned or not)

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
	local bands = DockPieces.quayBands(sign, b)

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
		bands = bands,
		markers = {},
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

-- bought buildings, then quest blueprints (DockConfig.Blueprints, WP-21b)
local BUILT = table.clone(DockConfig.BUILDINGS)
for key in DockConfig.Blueprints do
	table.insert(BUILT, key)
end

-- the lots that get a marker while empty (WP-25 r4): on the plate, not over the water or on another building
local MARKED: { [string]: { spot: CFrame, size: Vector2 } } = {}
for _, key in BUILT do
	local def = DockConfig.Buildings[key]
	if key == "Pontoon" or key == "Crane" or key == "TrophyHall" or key == "SubPen" then
		continue
	elseif def then
		MARKED[key] = { spot = def.spot, size = def.size }
	else
		local lot = Marina.LOTS[DockConfig.Blueprints[key].lot]
		MARKED[key] = { spot = lot.cf, size = lot.size }
	end
end

-- The owner's bought buildings stand on the plot; beat: new ones play the build animation.
local function syncBuildings(plot: Plot, owner: Player?, beat: boolean)
	local data: any = owner and DataService.Get(owner)
	local owned = if data and type(data.dockBuildings) == "table" then data.dockBuildings else {}
	if not owner then
		plot.counts = {}
	end
	for _, key in BUILT do
		local want = owner ~= nil and owned[key] == true
		local have = plot.buildings[key]
		if want and not have and owner then
			local m = DockPieces.building(key, plot.frame)
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
		elseif have and not want then
			have:Destroy()
			plot.buildings[key] = nil
		end
		local lot, marker = MARKED[key], plot.markers[key]
		if lot and not want and not marker then
			local made = DockPieces.lotMarker(plot.frame, plot.frame * lot.spot, lot.size)
			made.Parent = plot.model
			plot.markers[key] = made
		elseif marker and want then
			marker:Destroy()
			plot.markers[key] = nil
		end
		local mk = plot.markers[key]
		if mk then -- the peg flag and the pad's rim take the owner's colour
			local peg = mk:FindFirstChild("Flag")
			if peg and peg:IsA("BasePart") then
				peg.Color = if owner
					then Marina.flagColor(owner.UserId)
					else Color3.fromRGB(242, 240, 232)
			end
			for _, d in mk:GetDescendants() do
				if d.Name == "Rim" and d:IsA("Frame") then
					d.BackgroundColor3 = if owner
						then Marina.flagColor(owner.UserId)
						else Color3.fromRGB(99, 95, 98)
				end
			end
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

-- The trophy hall's cups and plaques, rebuilt only when the owner's list changed.
local function syncTrophies(plot: Plot, owner: Player?)
	local data: any = owner and DataService.Get(owner)
	local cups, plaques = {}, {}
	if data and tableOf(data.dockBuildings).TrophyHall == true then
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

-- The player's island now matches the profile (beat: the build animation + builders play).
local function show(player: Player, beat: boolean)
	local i = byPlayer[player]
	local data: any = DataService.Get(player)
	if data and type(data.dockPrepaid) == "table" and type(data.dockBuildings) == "table" then
		-- Robux-paid buildings go up the moment their prerequisites stand
		if #UnlockTree.settle(data.dockBuildings, data.dockPrepaid) > 0 then
			DataService.MarkDirty(player)
			ProgressionService.Refresh(player)
			task.spawn(DataService.Save, player, false)
		end
	end
	if i and data then
		syncBuildings(plots[i], player, beat)
		syncDecor(plots[i], player, beat)
		if beat then
			spawnBuilders(plots[i])
		end
		crown()
	end
end

local busy: { [Player]: boolean } = {}

-- Cash purchase of tree building `key` once its prerequisites stand (Robux goes through its product).
local function buyBuilding(player: Player, data: any, key: string): (boolean, string)
	data.dockBuildings = if type(data.dockBuildings) == "table" then data.dockBuildings else {}
	local ok, reason, price = UnlockTree.canBuy(
		key,
		data.dockBuildings,
		data.cash,
		tonumber(player:GetAttribute("WorkerBuildDiscount")) -- Builders at work (WorkerService)
	)
	if not ok or not price then
		return false, reason or "Owned"
	end
	data.cash -= price
	data.dockBuildings[key] = true
	Telemetry.CashSpent(player, price, data.cash, "Dock", key)
	Telemetry.Funnel(player, "FirstBuilding") -- the first island building (WP-28: replaces FirstRank)
	DataService.MarkDirty(player)
	ProgressionService.Refresh(player)
	show(player, true)
	task.spawn(DataService.Save, player, false)
	return true, "ok"
end

-- Cash purchase of a decoration (WP-14d); needs only the jetty (its Robux product: the grant below).
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

-- A Cash purchase: a tree building or a decoration.
local function buy(player: Player, key: any): (boolean, string)
	local data: any = DataService.Get(player)
	if not data then
		return false, "Data"
	end
	if busy[player] then
		return false, "Busy"
	end
	if type(key) == "string" and DockConfig.Buildings[key] then
		return buyBuilding(player, data, key)
	elseif type(key) == "string" and DockConfig.Decorations[key] then
		return buyDecor(player, data, key)
	end
	return false, "Unknown"
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

	-- plots are claimed when the profile loads (Start), so the Harbour Master's count is known
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		busy[player] = nil
	end)

	local folderNet = Net.init()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "Dock_Upgrade"
	remote.OnServerInvoke = function(player: Player, key: any): (boolean, string)
		local ok, reason = buy(player, key)
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

	-- Robux skips the Cash, never the order: a building whose prerequisites are missing is granted as prepaid
	-- (show builds it once they stand; decor needs only the jetty); a retried receipt is harmless
	for _, rows: { [string]: any } in { DockConfig.Buildings :: any, DockConfig.Decorations } do
		for key, b in rows do
			if b.product then
				MonetizationService.OnProduct(b.product, function(_player, data: any)
					data.dockBuildings = if type(data.dockBuildings) == "table"
						then data.dockBuildings
						else {}
					if data.dockBuildings[key] then
						return true
					end
					if
						DockConfig.Buildings[key]
						and not UnlockTree.canRobux(key, data.dockBuildings)
					then
						data.dockPrepaid = if type(data.dockPrepaid) == "table"
							then data.dockPrepaid
							else {}
						data.dockPrepaid[key] = true
						return true
					end
					data.dockBuildings[key] = true
					return true
				end, function(player)
					show(player, true)
				end)
			end
		end
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
	DataService.OnLoaded(function(player: Player)
		claim(player)
		local i = byPlayer[player]
		if i then
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

-- Does the player own island building `key` (DockConfig.Buildings)? VehicleService: the pontoon's second
-- berth, the crane's no-wait relaunch.
function DockService.Owns(player: Player, key: string): boolean
	local data: any = DataService.Get(player)
	return data ~= nil and type(data.dockBuildings) == "table" and data.dockBuildings[key] == true
end

function DockService.Berths(): { BasePart }
	local out: { BasePart } = {}
	for _, plot in plots do
		table.insert(out, plot.berth)
	end
	return out
end

return DockService
