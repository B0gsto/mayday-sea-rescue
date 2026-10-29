--!strict
-- WorkerService (docs/23 (o), WP-26): rescued people become your workers. RescueService rolls each survivor
-- (WorkerRules.roll) on pick-up and calls Recruit when they land at your berth; data.workers keeps them.
-- Every 5 s per player: WorkerRules.assign places them (best rarity first) at their building on your island
-- or on the jetty. The server only publishes them (ReplicatedStorage.Workers.<UserId>.<index>: a Configuration
-- with the worker and its feet CFrame `Spot`); every client draws, animates, paths and culls the rigs itself
-- (WorkerController), cloned from shared R15 templates (ReplicatedStorage.WorkerRigs, NpcFactory) so a
-- server of 6 full islands (~186 workers) costs the server nothing per frame. Builders walk to a running
-- construction site (docs/24 B; DockService publishes SiteKey on the plot) and each worker carries the job its
-- client animations read (`Job`). Effects go out as player attributes the hooks read: WorkerBoatScale
-- (VehicleService Boat to me, UI/Menu), WorkerCraftSpeed (VehicleService
-- SpeedMultiplier), WorkerPayBonus (OperationService debrief pay); the skill tree's `Skill*` attributes
-- (SkillService) raise the same numbers, the caps, slots and the roll; Welcome Home pays each arrival, Glow Up's
-- Medics may raise their rarity, Mentor trains a Common every 2 h. Gatherers pay every minute, Rescuers
-- send an NPC rescue boat out of your cove every rescuePeriod (Cash, sometimes a new worker). On join the time away
-- pays Gatherers + Rescuers at OFFLINE_RATE, capped (attribute WorkerOffline: the client's join reward prompt, RewardController).
-- Studio: ServerStorage.WorkerDev:Invoke("recruit", category, rarity, name) as if landed at the first player's
-- berth; ("offline", seconds) pays as if they were away that long; ("finishbuild") finishes the running site;
-- ("status") -> a summary string;
-- ("fill") shows 31 fake workers on each of the 6 islands (perf tests), ("unfill") clears them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("Config"):WaitForChild("AssetIds"))
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(Shared:WaitForChild("Marina"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local DataService = require(script.Parent.DataService)
local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)
local ProgressionService = require(script.Parent.ProgressionService)

local WorkerService = {}

WorkerService.IDLE_SHOWN = 6 -- idle workers standing on the jetty (the rest are "inside") -- tune
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

-- The skill tree's totals (SkillService publishes them as attributes; no skills = no change).
local function skillOf(player: Player): WorkerRules.Skill
	local function attr(name: string, default: number): number
		return tonumber(player:GetAttribute(name)) or default
	end
	return {
		gatherMult = attr("SkillGatherMult", 1) - 1,
		tripPayMult = attr("SkillTripPayMult", 1) - 1,
		tripScale = 1 - attr("SkillTripScale", 1),
		recruitChance = attr("SkillRecruitChance", 0),
		offlineRate = attr("SkillOfflineAdd", 0),
		speedCapAdd = attr("SkillSpeedCapAdd", 0),
		boatCapAdd = attr("SkillBoatCapAdd", 0),
		medicCapAdd = attr("SkillMedicCapAdd", 0),
		medicPerUnit = attr("SkillMedicPerUnit", 0),
		offlineCapAdd = attr("SkillOfflineCapAdd", 0),
		rarityUp = attr("SkillRarityUp", 0),
	}
end

local function extraSlots(player: Player): { [string]: number }
	local out = {}
	for _, category in WorkerRules.CATEGORIES do
		out[category] = tonumber(player:GetAttribute(`SkillSlots{category}`)) or 0
	end
	return out
end

local function effectsOf(player: Player, data: ProgressionRules.PlayerData): WorkerRules.Effects
	return WorkerRules.effects(
		WorkerRules.crew(
			data.workers,
			data.dockBuildings,
			extraSlots(player),
			tonumber(player:GetAttribute("SkillTeamSpirit")) or 0
		),
		skillOf(player)
	)
end

-- Feet CFrames in the berth frame `bay` ------------------------------------------------------------

-- One feet spot per yard slot, in 1x yard-local studs (+Z into the yard, -Z the open front; scale multiplies
-- them like the built model). Each one stands by its own work object (bench, stall, boat, bed) and looks at it,
-- so 2-3 of a crew spread round the yard instead of posing in a line (docs/24 C art pass).
type WorkSlot = { x: number, z: number, tx: number, tz: number, y: number? } -- y: scaled feet height (default 0.8)
local WORK_SPOTS: { [string]: { WorkSlot } } = {
	Workshop = {
		{ x = -3.4, z = -6.9, tx = -3.4, tz = -4.6 }, -- the low bench, left
		{ x = 7.5, z = 2.0, tx = 7.5, tz = 4.4 }, -- the half-built crate (hammer)
		{ x = 3.4, z = -6.9, tx = 3.4, tz = -4.6 }, -- the low bench, right
		{ x = -8.6, z = 2.4, tx = -5, tz = 2.4 }, -- the half-built boat frame
		{ x = -8.6, z = -5.2, tx = -8.6, tz = -3.4 }, -- the sawhorse
	},
	FishShed = {
		{ x = -5.8, z = 0.6, tx = -5.8, tz = -2 }, -- behind a stall counter
		{ x = 5.8, z = 0.6, tx = 5.8, tz = -2 },
		{ x = 0, z = 1.4, tx = 0, tz = 3.9 }, -- the drying rack
		{ x = 1.8, z = -4.2, tx = 0, tz = -1 }, -- the fish crates
		{ x = -8.2, z = 4.4, tx = -7.6, tz = 1.2 }, -- the ice crate (4+ studs from the counter pacer)
	},
	BoatYard = {
		{ x = -5.4, z = -1, tx = 0, tz = -1 }, -- the hull, port side
		{ x = 5.4, z = 1.4, tx = 0, tz = 1.4 },
		{ x = 0, z = -8.6, tx = 0, tz = -4 }, -- the bow
		{ x = 0, z = 8.4, tx = 0, tz = 4 }, -- the stern
		{ x = 6.6, z = -3.2, tx = 7.3, tz = -0.6 }, -- the tool chests
	},
	RescueBoathouse = {
		{ x = -5, z = -1, tx = -5, tz = 4.4 }, -- the trailer
		{ x = -9.6, z = -3.4, tx = -9.9, tz = -5.8 }, -- the lifebuoy rack
		{ x = 7, z = -5.2, tx = 7, tz = -2.7 }, -- the work table
		{ x = 3.8, z = -2.6, tx = 0, tz = -2.6 }, -- the rescue boat
		{ x = 8.6, z = 2, tx = 8.6, tz = 5.8 }, -- the lifeguard chair
	},
	Clinic = {
		{ x = -4.8, z = -1.8, tx = -4.8, tz = 2.6 }, -- at the foot of bed A
		{ x = 4.8, z = 6.9, tx = 4.8, tz = 2.6 }, -- at the head of bed B
		{ x = 0, z = -0.6, tx = 0, tz = 3.3 }, -- the stretcher
		{ x = 6.4, z = -2, tx = 7.4, tz = 1.6 }, -- the IV stand
		{ x = -7.6, z = 1, tx = -8, tz = 3.3 }, -- the medicine crate
	},
}
-- docs/25 B: the Workshop's, Fish Market's, Clinic's, Boat Yard's and Rescue Boathouse's Lv2 / Lv3 add-ons
-- (M_Bld_WorkshopAddons, M_Bld_FishMarketAddons, M_Bld_ClinicAddons, M_Bld_BoatYardAddons, M_Bld_RescueBoathouseAddons,
-- DockPieces): their ATT_Work_* marks (scaled studs from the yard centre)
-- join or replace the yard's spots, facing the bench (+X), saw or hull (+Z), the stall counter or the smokehouse rack
-- (+-X), the bed (+Z) or the clinic counter (-Z).
-- shortcut: assumes the add-on mesh loaded (else these spots face empty yard); check DockPieces.meshes if it fails.
local function addonSlot(key: string, asset: string, name: string, tx: number, tz: number): WorkSlot
	local p = AssetIds.Attachments[asset][name]
	local s = DockConfig.Buildings[key].scale or 1
	return { x = p.X / s, z = p.Z / s, tx = (p.X + tx) / s, tz = (p.Z + tz) / s }
end
local YARD = WORK_SPOTS.Workshop
local WORKSHOP_LV2 = {
	YARD[1],
	YARD[2],
	YARD[3],
	addonSlot("Workshop", "M_Bld_WorkshopAddons", "ATT_Work_Bench2", 2, 0),
	addonSlot("Workshop", "M_Bld_WorkshopAddons", "ATT_Work_Bench3", 2, 0),
	addonSlot("Workshop", "M_Bld_WorkshopAddons", "ATT_Work_SawBench", 0, 2),
}
local WORKSHOP_LV3 = table.clone(WORKSHOP_LV2)
table.insert(
	WORKSHOP_LV3,
	addonSlot("Workshop", "M_Bld_WorkshopAddons", "ATT_Work_BoatFrame", 0, 2)
)
-- the Fishers' 4 (Lv2) / 8 (Lv3) slots reach the new stalls and racks before the market's crate spots
local MARKET = WORK_SPOTS.FishShed
local function fishSlot(name: string, tx: number): WorkSlot
	return addonSlot("FishShed", "M_Bld_FishMarketAddons", name, tx, 0)
end
local FISH_LV2 =
	{ MARKET[1], MARKET[2], fishSlot("ATT_Work_Stall3", 2), fishSlot("ATT_Work_Stall4", -2) }
local FISH_LV3 = table.clone(FISH_LV2)
table.insert(FISH_LV3, fishSlot("ATT_Work_RackLeft", 2))
table.insert(FISH_LV3, fishSlot("ATT_Work_RackRight", -2))
for i = 3, #MARKET do
	table.insert(FISH_LV2, MARKET[i])
	table.insert(FISH_LV3, MARKET[i])
end
-- the Medics' Lv2 pavilion beds and counter, then the Lv3 hospital beds and desk, ahead of the tent's spots
local TENT = WORK_SPOTS.Clinic
local function medicSlot(name: string, tz: number): WorkSlot
	return addonSlot("Clinic", "M_Bld_ClinicAddons", name, 0, tz)
end
local CLINIC_LV2 = {
	TENT[1],
	TENT[2],
	medicSlot("ATT_Work_Bed1", 2),
	medicSlot("ATT_Work_Bed2", 2),
	medicSlot("ATT_Work_Bed3", 2),
	medicSlot("ATT_Work_MedicCounter", -2),
}
local CLINIC_LV3 = table.clone(CLINIC_LV2)
for _, name in
	{ "ATT_Work_Bed4", "ATT_Work_Bed5", "ATT_Work_Bed6", "ATT_Work_Bed7", "ATT_Work_Desk" }
do
	table.insert(CLINIC_LV3, medicSlot(name, 2))
end
for i = 3, #TENT do
	table.insert(CLINIC_LV2, TENT[i])
	table.insert(CLINIC_LV3, TENT[i])
end
-- the Mechanics' Lv2 engine stand (ATT_Work_Hull) and tool bench, then the Lv3 dock walkway (the stand's spot is on
-- the dock wall's coping at Lv3); the code slots by the cab ladder and the gone tool chests drop out
local YARD_BOAT = WORK_SPOTS.BoatYard
local function mechSlot(name: string, tx: number, y: number?): WorkSlot
	local s = addonSlot("BoatYard", "M_Bld_BoatYardAddons", name, tx, 0)
	s.y = y
	return s
end
local BOATYARD_LV2 = {
	YARD_BOAT[1],
	mechSlot("ATT_Work_Hull", 2),
	mechSlot("ATT_Work_Bench", -2),
	YARD_BOAT[3],
	YARD_BOAT[4],
}
local BOATYARD_LV3 = {
	YARD_BOAT[1],
	mechSlot("ATT_Work_Hull", 2, AssetIds.Attachments.M_Bld_BoatYardAddons.ATT_Work_Hull.Y),
	mechSlot("ATT_Work_Bench", -2),
	mechSlot("ATT_Work_Dock", 2, AssetIds.Attachments.M_Bld_BoatYardAddons.ATT_Work_Dock.Y),
	YARD_BOAT[3],
	YARD_BOAT[4],
}
-- the Rescuers' Lv2 RIB pontoon and fuel pump, then the Lv3 lifeboat walkway and davit, on the decks (WorkSlot.y);
-- the lifeguard chair's slot drops out at Lv3 with the chair
local SHED = WORK_SPOTS.RescueBoathouse
local function rescueSlot(name: string, tx: number, tz: number): WorkSlot
	local s = addonSlot("RescueBoathouse", "M_Bld_RescueBoathouseAddons", name, tx, tz)
	s.y = AssetIds.Attachments.M_Bld_RescueBoathouseAddons[name].Y
	return s
end
local SHED_LV2 = {
	SHED[1],
	rescueSlot("ATT_Work_Pontoon", 2, 0),
	rescueSlot("ATT_Work_Fuel", 0, 2),
	SHED[2],
	SHED[3],
	SHED[4],
	SHED[5],
}
local SHED_LV3 = {
	SHED[1],
	rescueSlot("ATT_Work_Pontoon", 2, 0),
	rescueSlot("ATT_Work_Berth", 2, 0),
	rescueSlot("ATT_Work_Davit", 0, -2),
	rescueSlot("ATT_Work_Fuel", 0, 2),
	SHED[2],
	SHED[3],
	SHED[4],
}
local ADDON_LEVELS: { [string]: { [number]: { WorkSlot } } } = {
	Workshop = { [2] = WORKSHOP_LV2, [3] = WORKSHOP_LV3 },
	FishShed = { [2] = FISH_LV2, [3] = FISH_LV3 },
	Clinic = { [2] = CLINIC_LV2, [3] = CLINIC_LV3 },
	BoatYard = { [2] = BOATYARD_LV2, [3] = BOATYARD_LV3 },
	RescueBoathouse = { [2] = SHED_LV2, [3] = SHED_LV3 },
}
-- the first Rescuers keep watch on the Lookout's gallery deck (M_Bld_LookoutAddons), looking out front: one at the
-- Lv2 lantern, two at Lv3 (the searchlight side too); the rest work the Rescue Boathouse
local WATCH = { "ATT_Watch_Lamp", "ATT_Watch_Spotlight" }

local function workSpot(
	bay: CFrame,
	category: string,
	slot: number,
	_slots: number,
	levels: { [string]: number }?
): CFrame?
	local key = WorkerRules.buildingOf(category)
	local def = key and DockConfig.Buildings[key]
	if not def then
		return nil
	end
	local watch = if category == "Rescuer" and levels
		then math.min(UnlockTree.levelOf(levels, "LookoutTower") - 1, #WATCH)
		else 0
	if slot <= watch then
		local tower = bay * DockConfig.Buildings.LookoutTower.spot
		local p = AssetIds.Attachments.M_Bld_LookoutAddons[WATCH[slot]]
		return CFrame.lookAt(
			(tower * CFrame.new(p)).Position,
			(tower * CFrame.new(p.X, p.Y, p.Z - 4)).Position
		)
	end
	slot -= math.max(watch, 0)
	local at = bay * def.spot
	local scale = def.scale or 1
	local byLevel = if key and levels then ADDON_LEVELS[key] else nil
	local list = (byLevel and levels and byLevel[UnlockTree.levelOf(levels, key :: string)])
		or (if key then WORK_SPOTS[key] else nil)
	if list and #list > 0 then
		local s = list[(slot - 1) % #list + 1]
		local p = (at * CFrame.new(s.x * scale, s.y or 0.8, s.z * scale)).Position
		local look = (at * CFrame.new(s.tx * scale, s.y or 0.8, s.tz * scale)).Position
		return CFrame.lookAt(p, look)
	end
	local p = (at * CFrame.new((slot - (_slots + 1) / 2) * 4.5, 0.8, -(def.size.Y / 2 + 3.5))).Position
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

-- The job loop each client draws from `Job` (docs/24 C); a Builder hammers at the workshop and on a site.
local JOB: { [string]: string } = {
	Gatherer = "Fish",
	Mechanic = "Repair",
	Rescuer = "Rescue",
	Medic = "Heal",
	Builder = "Build",
	Hauler = "Haul", -- docs/25 K4: barge -> Depot pile
}

-- The owner's plot publishes SiteKey while a construction runs (DockService).
local function siteKey(player: Player): string?
	local i = player:GetAttribute("DockPlot")
	if type(i) ~= "number" then
		return nil
	end
	local marina = Workspace:FindFirstChild("Marina")
	local plot = marina and marina:FindFirstChild(`Plot{i}`)
	local key = plot and plot:GetAttribute("SiteKey")
	return if type(key) == "string" then key else nil
end

-- A feet spot round the site's footprint, one per Builder (the front of the building is -Z).
local function buildSpot(bay: CFrame, key: string, n: number, count: number): CFrame?
	local b = DockConfig.Buildings[key]
	local at: CFrame?
	local size: Vector2
	if b then
		at, size = bay * b.spot, b.size
	else
		local d = DockConfig.Decorations[key]
		if not d then
			return nil
		end
		at, size = DockConfig.decorSpot(key, bay), d.size
	end
	if not at then
		return nil
	end
	local hw, hd = size.X / 2 + 3, size.Y / 2 + 3
	local a = (n - 1) / math.max(count, 1) * math.pi * 2
	local p = at.Position + Vector3.new(math.cos(a) * hw, 0.8, math.sin(a) * hd)
	return CFrame.lookAt(p, at.Position + Vector3.new(0, 0.8, 0))
end

-- One worker as data for the clients (WorkerController draws the rig): docs/25 K1 attributes SurvivorName,
-- Rarity, Category, Trait, Special, Workplace (the building key, "" while waiting) and Job (the animation loop
-- another client controller plays); plus WorkerCategory, WorkerRarity, WorkerName for the current badge, Rig
-- (a WorkerRigs template), Spot (feet CFrame), Work (at their building) and From (walk in from here).
local function publish(
	parent: Instance,
	i: number,
	w: WorkerRules.Worker,
	spot: CFrame,
	work: boolean,
	from: CFrame?,
	job: string,
	workplace: string?
): Configuration
	local cfg = Instance.new("Configuration")
	cfg.Name = tostring(i)
	cfg:SetAttribute("SurvivorName", w.name)
	cfg:SetAttribute("Rarity", w.rarity)
	cfg:SetAttribute("Category", w.category)
	cfg:SetAttribute("Trait", w.trait or "")
	cfg:SetAttribute("Special", w.special or "")
	cfg:SetAttribute("Workplace", workplace or "")
	cfg:SetAttribute("WorkerCategory", w.category)
	cfg:SetAttribute("WorkerRarity", w.rarity)
	cfg:SetAttribute("WorkerName", w.name)
	cfg:SetAttribute("Rig", WorkerRules.rigOf(i, w.name))
	cfg:SetAttribute("Spot", spot)
	cfg:SetAttribute("Work", work)
	cfg:SetAttribute("From", from)
	cfg:SetAttribute("Job", job)
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
	local fx = effectsOf(player, data)
	player:SetAttribute("WorkerBoatScale", fx.boatScale)
	player:SetAttribute("WorkerCraftSpeed", fx.craftSpeed)
	player:SetAttribute("WorkerPayBonus", fx.payBonus)
	player:SetAttribute("WorkerCount", #data.workers)
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return
	end
	local place = WorkerRules.assign(data.workers, data.dockBuildings, extraSlots(player))
	local slots = WorkerRules.slots(data.dockBuildings)
	local site = siteKey(player)
	local order, count = {}, 0
	local maxBuilders = BuildTimer.BUILDERS
		+ (tonumber(player:GetAttribute("SkillExtraBuilders")) or 0)
	if site then
		for k, index in BuildTimer.builders(data.workers, maxBuilders) do
			order[index] = k
			count = k
		end
	end
	local idle = 0
	for i, w in data.workers do
		local spot: CFrame? = nil
		local job = "Idle"
		if order[i] and site then
			spot = buildSpot(bay, site, order[i], count)
			job = "Build"
		elseif place[i] then
			spot = workSpot(bay, w.category, place[i], slots, data.dock.levels)
			job = JOB[w.category] or "Idle"
		else
			idle += 1
			spot = if idle <= WorkerService.IDLE_SHOWN then idleSpot(bay, idle) else nil
		end
		local workplace = if order[i] and site
			then site
			elseif place[i] then WorkerRules.buildingOf(w.category) or ""
			else ""
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
				job ~= "Idle",
				if st.fresh[i] then arrival(bay) else nil,
				job,
				workplace
			)
			st.fresh[i] = nil
		else
			cfg:SetAttribute("Spot", spot) -- same value: no change, nothing replicates
			cfg:SetAttribute("Work", job ~= "Idle")
			cfg:SetAttribute("Job", job)
			cfg:SetAttribute("Workplace", workplace)
		end
	end
end

-- Recruit: a survivor landed at `player`'s berth (RescueService), rolled at spawn. Past the cap only a rarer
-- one stays (admit).
function WorkerService.Recruit(
	player: Player,
	category: any,
	rarity: any,
	name: any,
	trait: any?,
	special: any?
)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local clean = WorkerRules.clean({
		{ category = category, rarity = rarity, name = name, trait = trait, special = special },
	})[1]
	-- the roll checked the call owner's crew; the deliverer (crew, free roam) or a twin from the same call may
	-- already have this special: then they join as a plain survivor
	if clean and clean.special ~= "" and WorkerRules.ownedSpecials(data.workers)[clean.special] then
		clean.special = ""
		clean.name = WorkerRules.plainName(#data.workers + clean.rarity)
	end
	local welcome = tonumber(player:GetAttribute("SkillArrivalPay")) or 0
	if clean and welcome > 0 then -- Welcome Home: every arrival pays, kept or not
		ProgressionService.Award(player, welcome, "Workers:Welcome", true)
	end
	if clean and rng:NextNumber() < effectsOf(player, data).glowUp then -- Glow Up: a Medic raises them
		if WorkerRules.promote(clean, rng:NextInteger(1, 2147483646)) and data.pity then
			-- a promoted Epic / Legendary counts like a rolled one: its pity starts again
			if clean.rarity == WorkerRules.EPIC then
				data.pity.epic = 0
			elseif clean.rarity == WorkerRules.LEGENDARY then
				data.pity.legendary = 0
			end
		end
	end
	local cap = UnlockTree.bunkCap(data.dock.levels)
		+ (tonumber(player:GetAttribute("SkillWorkerCapAdd")) or 0)
	local i = clean and WorkerRules.admit(data.workers, clean, cap)
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
local function rescueTrip(player: Player, st: State, bay: CFrame, cash: number, chance: number)
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
		-- one recruit chance per seat: Big Boat (SkillBoatSeats) adds two
		for _ = 1, 1 + (tonumber(player:GetAttribute("SkillBoatSeats")) or 0) do
			if rng:NextNumber() < chance then
				-- an NPC rescue-boat recruit rolls at recruit time as before (no pity)
				local data = DataService.Get(player)
				local w = WorkerRules.roll(rng:NextInteger(1, 2147483646), {
					rareAdd = tonumber(player:GetAttribute("SkillRareChanceAdd")) or 0,
					traitReroll = (tonumber(player:GetAttribute("SkillTraitReroll")) or 0) > 0,
					owned = if data then WorkerRules.ownedSpecials(data.workers) else nil,
				})
				WorkerService.Recruit(player, w.category, w.rarity, w.name, w.trait, w.special)
			end
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
	local fx = effectsOf(player, data)
	if now >= st.gatherAt then
		st.gatherAt = now + 60
		if fx.gatherPerMin > 0 then
			ProgressionService.Award(player, fx.gatherPerMin, "Workers:Gather", true)
		end
	end
	local bay = player:GetAttribute("BayCFrame")
	if fx.rescuePerTrip <= 0 then
		st.nextTrip = now + fx.rescuePeriod
	elseif now >= st.nextTrip and not st.tripBusy and typeof(bay) == "CFrame" then
		st.nextTrip = now + fx.rescuePeriod
		rescueTrip(player, st, bay, fx.rescuePerTrip, fx.recruitChance)
	end
end

-- Mentor: every MENTOR_PERIOD (saved in flags.mentorAt, time away counts) a Legendary trains a Common.
local function mentor(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if (tonumber(player:GetAttribute("SkillMentor")) or 0) <= 0 then
		if data.flags.mentorAt ~= nil then
			ProgressionService.SetFlag(player, "mentorAt", nil)
		end
		return
	end
	local now = os.time()
	local last = tonumber(data.flags.mentorAt)
	if not last then
		ProgressionService.SetFlag(player, "mentorAt", now)
		return
	end
	local i = WorkerRules.mentor(data.workers, last, now)
	-- the clock saves first, so a full flags table can't train every tick
	if i and ProgressionService.SetFlag(player, "mentorAt", now) then
		WorkerRules.promote(data.workers[i], rng:NextInteger(1, 2147483646))
		local st = states[player]
		if st and st.shown[i] then -- republished with the new rarity on the next sync
			st.shown[i]:Destroy()
			st.shown[i] = nil
		end
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
	local pay = WorkerRules.offlinePay(effectsOf(player, data), away)
	if pay > 0 then
		-- the attribute first: the client holds the pay off the wallet before the paid snapshot lands
		player:SetAttribute("WorkerOffline", pay)
		ProgressionService.Award(player, pay, "Workers:Offline", true)
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
	for k = 1, WorkerRules.RIGS do -- built once; each client clones them
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
		clearState(player) -- a reload (DataDev "rejoin") must not leave a second, stale worker folder
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
			nextTrip = now + effectsOf(player, data).rescuePeriod,
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
			if cmd == "finishbuild" then
				return require(script.Parent.DockService).FinishBuild(player)
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
								local w = {
									category = category,
									rarity = 1 + n % 3,
									name = "Fill",
									trait = "",
									special = "",
								}
								publish(
									ff,
									n,
									w,
									workSpot(bay, category, slot, 5) :: CFrame,
									true,
									nil,
									JOB[category] or "Gather"
								)
							end
						end
						for idle = 1, WorkerService.IDLE_SHOWN do
							n += 1
							local w = {
								category = "Medic",
								rarity = 1,
								name = "Fill",
								trait = "",
								special = "",
							}
							publish(ff, n, w, idleSpot(bay, idle), false, nil, "Idle")
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
				mentor(player)
				sync(player)
				earn(player, now)
			end
			task.wait(5)
		end
	end)
end

return WorkerService
