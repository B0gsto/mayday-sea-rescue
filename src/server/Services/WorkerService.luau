--!strict
-- WorkerService (docs/23 (o), WP-26): rescued people become your workers. RescueService rolls each survivor
-- (WorkerRules.roll) on pick-up and calls Recruit when they land at your berth; data.workers keeps them.
-- Every 5 s per player: WorkerRules.assign places them (best rarity first) at their building on your island
-- or on the jetty. The server only publishes them (ReplicatedStorage.Workers.<UserId>.<index>: a Configuration
-- with the worker and its feet CFrame `Spot`); every client draws, animates, paths and culls the rigs itself
-- (WorkerController), cloned from RIGS shared R15 templates (ReplicatedStorage.WorkerRigs, NpcFactory) so a
-- server of 6 full islands (~186 workers) costs the server nothing per frame. Effects go out as player attributes the hooks read: WorkerBuildDiscount (DockService, the tablet,
-- BuildSeq), WorkerBoatScale (VehicleService Boat to me, UI/Menu), WorkerCraftSpeed (VehicleService
-- SpeedMultiplier), WorkerPayBonus (OperationService debrief pay). Gatherers pay every minute, Rescuers send an
-- NPC rescue boat out of your cove every RESCUE_PERIOD (Cash, sometimes a new worker). On join the time away
-- pays Gatherers + Rescuers at OFFLINE_RATE, capped (attribute WorkerOffline: the client's coin burst).
-- Studio: ServerStorage.WorkerDev:Invoke("recruit", category, rarity, name) as if landed at the first player's
-- berth; ("offline", seconds) pays as if they were away that long; ("status") -> a summary string;
-- ("fill") shows 31 fake workers on each of the 6 islands (perf tests), ("unfill") clears them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(Shared:WaitForChild("Marina"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local DataService = require(script.Parent.DataService)
local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)
local ProgressionService = require(script.Parent.ProgressionService)

local WorkerService = {}

WorkerService.IDLE_SHOWN = 6 -- idle workers standing on the jetty (the rest are "inside") -- tune
local RIGS = 12 -- outfit templates the clients clone (more = more variety, more memory)
local TRIP_OUT = 260 -- studs the rescue boat sails out of the cove
local TRIP_LEG = 22 -- s each way

type State = {
	folder: Folder, -- Workspace.Workers.<UserId>: the rescue boat
	data: Folder, -- ReplicatedStorage.Workers.<UserId>: the shown workers
	shown: { [number]: Configuration }, -- by data.workers index (the list only grows)
	fresh: { [number]: boolean }, -- recruited this session: walks in from the jetty
	nextTrip: number,
	tripBusy: boolean,
	gatherAt: number,
}

local folder: Folder? = nil
local dataRoot: Folder? = nil
local states: { [Player]: State } = {}
local rng = Random.new()

local function effectsOf(data: ProgressionRules.PlayerData): WorkerRules.Effects
	return WorkerRules.effects(WorkerRules.units(data.workers, data.dockBuildings))
end

-- Feet CFrames in the berth frame `bay` ------------------------------------------------------------

-- In front of the building's open front, side by side, facing the work they do inside it (docs/24 C: the worker
-- buildings are open yards, so the crew stands just inside the front edge rather than out on the lane); 4.5 apart
-- so the swings miss the neighbour.
local WORK_INSET = { -- studs in from the front edge (docs/24 C open work areas)
	Workshop = 2.5,
	FishShed = 2.5,
	BoatYard = 1.5, -- clear of the bow overhang
	RescueBoathouse = 2.5,
	Clinic = 4, -- inside the pavilion, at the beds
}
local function workSpot(bay: CFrame, category: string, slot: number, slots: number): CFrame?
	local key = WorkerRules.buildingOf(category)
	local def = key and DockConfig.Buildings[key]
	if not def then
		return nil
	end
	local at = bay * def.spot
	local inset = if key then WORK_INSET[key] else nil
	local z = if inset then -(def.size.Y / 2 - inset) else -(def.size.Y / 2 + 3.5)
	local p = (at * CFrame.new((slot - (slots + 1) / 2) * 4.5, 0.8, z)).Position
	return CFrame.lookAt(p, p - at.LookVector)
end

-- On the jetty by the quay, two by two, facing the berth (the bunkhouse until art lands).
local function idleSpot(bay: CFrame, n: number): CFrame
	local J = Marina.JETTY
	local x = if n % 2 == 1 then J.x0 + 2 else J.x1 - 2
	local p = (bay * CFrame.new(x, Marina.DECK_TOP, J.z1 - 3 - math.floor((n - 1) / 2) * 3.5)).Position
	return CFrame.lookAt(p, p + bay.RightVector)
end

local function arrival(bay: CFrame): CFrame
	local J = Marina.JETTY
	return bay * CFrame.new((J.x0 + J.x1) / 2, Marina.DECK_TOP, 0)
end

-- One worker as data for the clients (WorkerController draws the rig): attributes WorkerCategory, WorkerRarity,
-- WorkerName, Rig (a WorkerRigs template), Spot (feet CFrame), Work (at their building), From (walk in from here).
local function publish(
	parent: Instance,
	i: number,
	w: WorkerRules.Worker,
	spot: CFrame,
	work: boolean,
	from: CFrame?
): Configuration
	local cfg = Instance.new("Configuration")
	cfg.Name = tostring(i)
	cfg:SetAttribute("WorkerCategory", w.category)
	cfg:SetAttribute("WorkerRarity", w.rarity)
	cfg:SetAttribute("WorkerName", w.name)
	cfg:SetAttribute("Rig", (i * 5 + #w.name) % RIGS + 1)
	cfg:SetAttribute("Spot", spot)
	cfg:SetAttribute("Work", work)
	cfg:SetAttribute("From", from)
	cfg.Parent = parent
	return cfg
end

-- Publishes every shown worker (ReplicatedStorage.Workers.<UserId>) and the effects.
local function sync(player: Player)
	local data = DataService.Get(player)
	local st = states[player]
	if not data or not st then
		return
	end
	local fx = effectsOf(data)
	player:SetAttribute("WorkerBuildDiscount", fx.buildDiscount)
	player:SetAttribute("WorkerBoatScale", fx.boatScale)
	player:SetAttribute("WorkerCraftSpeed", fx.craftSpeed)
	player:SetAttribute("WorkerPayBonus", fx.payBonus)
	player:SetAttribute("WorkerCount", #data.workers)
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return
	end
	local place = WorkerRules.assign(data.workers, data.dockBuildings)
	local slots = WorkerRules.slots(data.dockBuildings)
	local idle = 0
	for i, w in data.workers do
		local spot: CFrame? = nil
		if place[i] then
			spot = workSpot(bay, w.category, place[i], slots)
		else
			idle += 1
			spot = if idle <= WorkerService.IDLE_SHOWN then idleSpot(bay, idle) else nil
		end
		local cfg = st.shown[i]
		if not spot then
			if cfg then
				cfg:Destroy()
				st.shown[i] = nil
			end
		elseif not cfg then
			-- a new recruit appears on the jetty and walks over (WorkerController)
			st.shown[i] = publish(
				st.data,
				i,
				w,
				spot,
				place[i] ~= nil,
				if st.fresh[i] then arrival(bay) else nil
			)
			st.fresh[i] = nil
		else
			cfg:SetAttribute("Spot", spot) -- same value: no change, nothing replicates
			cfg:SetAttribute("Work", place[i] ~= nil)
		end
	end
end

-- Recruit: a survivor landed at `player`'s berth (RescueService). Past the cap only a rarer one stays (admit).
function WorkerService.Recruit(player: Player, category: any, rarity: any, name: any)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local clean = WorkerRules.clean({ { category = category, rarity = rarity, name = name } })[1]
	local i = clean and WorkerRules.admit(data.workers, clean)
	if not i then
		return
	end
	DataService.MarkDirty(player)
	ProgressionService.Refresh(player)
	local st = states[player]
	if st then
		if st.shown[i] then -- replaced: the one leaving goes
			st.shown[i]:Destroy()
			st.shown[i] = nil
		end
		st.fresh[i] = true
	end
	task.defer(sync, player)
end

-- The NPC rescue boat: out of your cove and back (a placeholder Lego boat until art lands), then the pay.
local function rescueTrip(player: Player, st: State, bay: CFrame, cash: number)
	st.tripBusy = true
	local m = Instance.new("Model")
	m.Name = "WorkerRescueBoat"
	local function brick(size: Vector3, offset: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		p.CFrame = offset
		p.Parent = m
		return p
	end
	local start = bay * CFrame.new(12, 0.6, -20)
	local hull = brick(Vector3.new(5, 1.6, 12), start, Color3.fromRGB(224, 56, 40))
	hull.Anchored = true
	m.PrimaryPart = hull
	for _, part in
		{
			brick(
				Vector3.new(4, 2, 4),
				start * CFrame.new(0, 1.8, 1.5),
				Color3.fromRGB(242, 240, 232)
			),
			brick(
				Vector3.new(5.2, 0.4, 12.2),
				start * CFrame.new(0, 0.9, 0),
				Color3.fromRGB(250, 208, 40)
			),
		}
	do
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hull, part
		weld.Parent = part
		part.Massless = true
	end
	m.Parent = st.folder
	local out = start * CFrame.new(0, 0, -TRIP_OUT)
	task.spawn(function()
		local turn = CFrame.Angles(0, math.pi, 0)
		local seconds = { TRIP_LEG, 3, TRIP_LEG }
		for k, leg in { out, out * turn, start * turn } do
			local tween = TweenService:Create(
				hull,
				TweenInfo.new(seconds[k], Enum.EasingStyle.Sine),
				{ CFrame = leg }
			)
			tween:Play()
			tween.Completed:Wait()
		end
		m:Destroy()
		st.tripBusy = false
		if states[player] ~= st then
			return -- left meanwhile
		end
		ProgressionService.Award(player, cash, "Workers:Rescue", true)
		if rng:NextNumber() < WorkerRules.RESCUE_RECRUIT then
			local category, rarity, name = WorkerRules.roll(rng:NextInteger(1, 2147483646))
			WorkerService.Recruit(player, category, rarity, name)
		end
	end)
end

-- Gatherers every minute, Rescuers every RESCUE_PERIOD (only while you are here).
local function earn(player: Player, now: number)
	local data = DataService.Get(player)
	local st = states[player]
	if not data or not st then
		return
	end
	local fx = effectsOf(data)
	if now >= st.gatherAt then
		st.gatherAt = now + 60
		if fx.gatherPerMin > 0 then
			ProgressionService.Award(player, fx.gatherPerMin, "Workers:Gather", true)
		end
	end
	local bay = player:GetAttribute("BayCFrame")
	if fx.rescuePerTrip <= 0 then
		st.nextTrip = now + WorkerRules.RESCUE_PERIOD
	elseif now >= st.nextTrip and not st.tripBusy and typeof(bay) == "CFrame" then
		st.nextTrip = now + WorkerRules.RESCUE_PERIOD
		rescueTrip(player, st, bay, fx.rescuePerTrip)
	end
end

local function clearState(player: Player)
	local st = states[player]
	states[player] = nil
	if st then
		st.folder:Destroy()
		st.data:Destroy()
	end
end

-- The time away (from the last save), capped: Gatherers and Rescuers at a reduced rate. Once, on join.
function WorkerService.PayOffline(player: Player, data: ProgressionRules.PlayerData)
	local away = if data.lastSeen then os.time() - data.lastSeen else 0
	local pay = WorkerRules.offlinePay(effectsOf(data), away)
	if pay > 0 then
		ProgressionService.Award(player, pay, "Workers:Offline", true)
		player:SetAttribute("WorkerOffline", pay)
	end
end

function WorkerService.Init()
	local f = Instance.new("Folder")
	f.Name = "Workers"
	f.Parent = Workspace
	folder = f
	local d = Instance.new("Folder")
	d.Name = "Workers"
	d.Parent = ReplicatedStorage
	dataRoot = d
	local rigs = Instance.new("Folder")
	rigs.Name = "WorkerRigs"
	rigs.Parent = ReplicatedStorage
	for k = 1, RIGS do -- built once; each client clones them
		task.spawn(function()
			local model, height = NpcFactory.spawn(
				"Passenger",
				{ seed = k * 7919, storm = false, name = tostring(k) }
			)
			model:SetAttribute("RootHeight", height)
			model.Parent = rigs
		end)
	end
	Players.PlayerRemoving:Connect(clearState)
	DataService.OnLoaded(function(player: Player, data: ProgressionRules.PlayerData)
		local pf = Instance.new("Folder")
		pf.Name = tostring(player.UserId)
		pf.Parent = folder
		local df = Instance.new("Folder")
		df.Name = pf.Name
		df.Parent = dataRoot
		local now = os.clock()
		states[player] = {
			folder = pf,
			data = df,
			shown = {},
			fresh = {},
			nextTrip = now + WorkerRules.RESCUE_PERIOD,
			tripBusy = false,
			gatherAt = now + 60,
		}
		WorkerService.PayOffline(player, data)
		sync(player)
	end)
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "WorkerDev"
		dev.OnInvoke = function(cmd: string, a: any, b: any, c: any): any
			local player = Players:GetPlayers()[1]
			local data = player and DataService.Get(player)
			if not data then
				return "no data"
			end
			if cmd == "fill" or cmd == "unfill" then
				for k = 1, Marina.COUNT do
					local old = (dataRoot :: Folder):FindFirstChild(`Fill{k}`)
					if old then
						old:Destroy()
					end
					if cmd == "fill" then
						local ff = Instance.new("Folder")
						ff.Name = `Fill{k}`
						local bay = Marina.berth(k)
						local n = 0
						for _, category in WorkerRules.CATEGORIES do
							for slot = 1, WorkerRules.slots({ Station = true }) do
								n += 1
								local w = { category = category, rarity = 1 + n % 3, name = "Fill" }
								publish(
									ff,
									n,
									w,
									workSpot(bay, category, slot, 5) :: CFrame,
									true,
									nil
								)
							end
						end
						for idle = 1, WorkerService.IDLE_SHOWN do
							n += 1
							local w = { category = "Medic", rarity = 1, name = "Fill" }
							publish(ff, n, w, idleSpot(bay, idle), false, nil)
						end
						ff.Parent = dataRoot
					end
				end
				return "ok"
			elseif cmd == "recruit" then
				WorkerService.Recruit(player, a, b, c)
			elseif cmd == "offline" then
				data.lastSeen = os.time() - a
				local before = data.cash
				WorkerService.PayOffline(player, data)
				return data.cash - before
			end
			local out = {}
			for _, w in data.workers do
				table.insert(out, `{w.category}{w.rarity}`)
			end
			local st = states[player]
			local npcs = 0
			if st then
				for _ in st.shown do
					npcs += 1
				end
			end
			return `workers {#data.workers} [{table.concat(out, " ")}] npcs {npcs} rescued {data.totalRescues}`
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

function WorkerService.Start()
	task.spawn(function()
		while true do
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				sync(player)
				earn(player, now)
			end
			task.wait(5)
		end
	end)
end

return WorkerService
