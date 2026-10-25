--!strict
-- WorkerService (docs/23 (o), WP-26): rescued people become your workers. RescueService rolls each survivor
-- (WorkerRules.roll) on pick-up and calls Recruit when they land at your berth; data.workers keeps them.
-- Every 5 s per player: WorkerRules.assign places them (best rarity first) at their building on your island
-- or on the jetty, and R15 NPCs (NpcFactory, Workspace.Workers.<UserId>) stand there idling; a new or moved one
-- walks over. Effects go out as player attributes the hooks read: WorkerBuildDiscount (DockService, the tablet,
-- BuildSeq), WorkerBoatScale (VehicleService Boat to me, UI/Menu), WorkerCraftSpeed (VehicleService
-- SpeedMultiplier), WorkerPayBonus (OperationService debrief pay). Gatherers pay every minute, Rescuers send an
-- NPC rescue boat out of your cove every RESCUE_PERIOD (Cash, sometimes a new worker). On join the time away
-- pays Gatherers + Rescuers at OFFLINE_RATE, capped (attribute WorkerOffline: the client's coin burst).
-- Studio: ServerStorage.WorkerDev:Invoke("recruit", category, rarity, name) as if landed at the first player's
-- berth; ("offline", seconds) pays as if they were away that long; ("status") -> a summary string.
local CollectionService = game:GetService("CollectionService")
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
local WALK_SPEED = 9 -- studs/s
local TRIP_OUT = 260 -- studs the rescue boat sails out of the cove
local TRIP_LEG = 22 -- s each way
local ANIM = { Idle = "rbxassetid://507766666", Walk = "rbxassetid://507777826" }

type Npc = { model: Model, spot: CFrame?, height: number }
type State = {
	folder: Folder,
	npcs: { [number]: Npc }, -- by data.workers index (the list only grows)
	loading: { [number]: boolean },
	fresh: { [number]: boolean }, -- recruited this session: walks in from the jetty
	nextTrip: number,
	tripBusy: boolean,
	gatherAt: number,
}

local folder: Folder? = nil
local states: { [Player]: State } = {}
local rng = Random.new()

local function effectsOf(data: ProgressionRules.PlayerData): WorkerRules.Effects
	return WorkerRules.effects(WorkerRules.units(data.workers, data.dockBuildings))
end

local function play(model: Model, id: string)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.2)
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	pcall(function()
		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play(0.2)
	end)
end

-- Feet CFrames in the berth frame `bay` ------------------------------------------------------------

-- In front of the building's door (its -Z side), side by side, facing out.
local function workSpot(bay: CFrame, category: string, slot: number, slots: number): CFrame?
	local key = WorkerRules.buildingOf(category)
	local def = key and DockConfig.Buildings[key]
	if not def then
		return nil
	end
	local at = bay * def.spot
	local p = (at * CFrame.new((slot - (slots + 1) / 2) * 3.5, 0.8, -(def.size.Y / 2 + 3.5))).Position
	return CFrame.lookAt(p, p + at.LookVector)
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

local function walk(npc: Npc, path: { CFrame })
	local root = npc.model.PrimaryPart
	if not root then
		npc.model:PivotTo(path[#path])
		return
	end
	play(npc.model, ANIM.Walk)
	task.spawn(function()
		for _, feet in path do
			local target = feet * CFrame.new(0, npc.height, 0)
			local from = root.Position
			local face = CFrame.lookAt(from, Vector3.new(target.X, from.Y, target.Z))
			root.CFrame = if (target.Position - from).Magnitude > 0.5 then face else root.CFrame
			local tween = TweenService:Create(
				root,
				TweenInfo.new(
					(target.Position - from).Magnitude / WALK_SPEED,
					Enum.EasingStyle.Linear
				),
				{ CFrame = CFrame.new(target.Position) * face.Rotation }
			)
			tween:Play()
			tween.Completed:Wait()
			if not npc.model.Parent then
				return
			end
		end
		root.CFrame = path[#path] * CFrame.new(0, npc.height, 0)
		play(npc.model, ANIM.Idle)
	end)
end

local function spawnNpc(player: Player, st: State, i: number, w: WorkerRules.Worker, at: CFrame)
	st.loading[i] = true
	task.spawn(function()
		local model, height = NpcFactory.spawn("Passenger", {
			name = `Worker_{w.name}`,
			pose = "Idle",
			seed = player.UserId * 7 + i * 131,
			cframe = at,
			parent = st.folder :: Instance?,
		})
		st.loading[i] = nil
		if states[player] ~= st then
			model:Destroy()
			return
		end
		model:SetAttribute("WorkerCategory", w.category)
		model:SetAttribute("WorkerRarity", w.rarity)
		model:SetAttribute("WorkerName", w.name)
		model:SetAttribute("WorkerOwner", player.UserId)
		CollectionService:AddTag(model, "WorkerBadge")
		st.npcs[i] = { model = model, spot = at, height = height }
	end)
end

-- Places every worker's NPC (spawn, walk, hide) and publishes the effects.
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
		local npc = st.npcs[i]
		if not spot then
			if npc then
				npc.model:Destroy()
				st.npcs[i] = nil
			end
		elseif not npc and not st.loading[i] then
			-- a new recruit appears on the jetty and walks over once its rig is in (the next sync)
			spawnNpc(player, st, i, w, if st.fresh[i] then arrival(bay) else spot)
			st.fresh[i] = nil
		elseif npc and npc.spot ~= spot then
			local from = npc.spot
			npc.spot = spot
			local quay = arrival(bay) * CFrame.new(0, 0, Marina.JETTY.z1 - 2)
			-- off the jetty by its quay end, then over (a straight line otherwise)
			walk(
				npc,
				if from and (from.Position - arrival(bay).Position).Magnitude < 1
					then { quay, spot }
					else { spot }
			)
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
		if st.npcs[i] then -- replaced: the one leaving goes
			st.npcs[i].model:Destroy()
			st.npcs[i] = nil
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
	Players.PlayerRemoving:Connect(clearState)
	DataService.OnLoaded(function(player: Player, data: ProgressionRules.PlayerData)
		local pf = Instance.new("Folder")
		pf.Name = tostring(player.UserId)
		pf.Parent = folder
		local now = os.clock()
		states[player] = {
			folder = pf,
			npcs = {},
			loading = {},
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
			if cmd == "recruit" then
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
				for _ in st.npcs do
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
