-- ProgressFixtures: every kind of saved progress loads through the real migration and lands playable
-- (owner, launch: "works for any type of user progress"). Fixtures: brand new, each tutorial beat, early,
-- mid, maxed, legacy shapes (ranks / Rep, phone, town, cars, gear, hired crew, Cash skill nodes, one-time
-- dock rows, v1 rarities) and corrupt saves. Each must migrate without error, stay the same on the next
-- save, keep a free way to earn Cash, a reachable next goal and keep every flag reader happy.
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local Config = t.load("src/shared/Config/ProgressionConfig.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local UnlockTree = t.load("src/shared/UnlockTree.luau")
	local Onboarding = t.load("src/shared/Onboarding.luau")
	local NextGoal = t.load("src/shared/NextGoal.luau")
	local W = t.load("src/shared/WorkerRules.luau")
	local SkillRules = t.load("src/shared/SkillRules.luau")
	local DepotRules = t.load("src/shared/DepotRules.luau")
	local BuildTimer = t.load("src/shared/BuildTimer.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")
	local SpinRules = t.load("src/shared/SpinRules.luau")
	local PetRules = t.load("src/shared/PetRules.luau")
	local GroupReward = t.load("src/shared/GroupReward.luau")
	local PlatformPrompts = t.load("src/shared/PlatformPrompts.luau")
	local DiscoveryRules = t.load("src/shared/DiscoveryRules.luau")
	local QuestRules = t.load("src/shared/Quests/Rules.luau")
	local CosmeticLoadout = t.load("src/shared/CosmeticLoadout.luau")
	local TrophyRules = t.load("src/shared/TrophyRules.luau")
	local SettingsRules = t.load("src/shared/SettingsRules.luau")
	local VehicleUpgrades = t.load("src/shared/VehicleUpgrades.luau")
	local NotifyDue = t.load("src/shared/NotifyDue.luau")

	local NOW = 1790000000
	local DAY = 86400

	local function worker(category, rarity, name)
		return { category = category, rarity = rarity, name = name, trait = "", special = "" }
	end

	local function maxedLevels()
		local levels = {}
		for key in DockConfig.Buildings do
			levels[key] = UnlockTree.maxLevel(key)
		end
		return levels
	end

	-- Fixtures: name -> a fresh raw save (as the DataStore hands it back)
	local F = {}
	F.brandNew = function()
		return nil
	end
	F.defaults = function()
		return Rules.defaultData()
	end
	-- the tutorial beats (Onboarding.beat): stand, Hut site, cold open, first rescue, Workshop buy, site, spin
	F.beatBuildHQ = function()
		return { version = 2, cash = 0, dock = { levels = { Harbour = 1 } } }
	end
	F.beatHQSite = function()
		return {
			version = 2,
			dock = { levels = { Harbour = 1 } },
			construction = { key = "HQ", level = 1, progress = 0.4, rate = 1, at = NOW - 30 },
		}
	end
	F.beatColdOpen = function()
		return { version = 2, dock = { levels = { Harbour = 1, HQ = 1 } } }
	end
	F.beatRescue = function()
		return { version = 2, coldOpenDone = true, dock = { levels = { Harbour = 1, HQ = 1 } } }
	end
	F.beatBuildStation = function()
		return {
			version = 2,
			coldOpenDone = true,
			tutorialStep = 1,
			totalRescues = 1,
			cash = 150,
			dock = { levels = { Harbour = 1, HQ = 1 } },
			workers = { worker("Builder", 1, "Nell") },
		}
	end
	F.beatBuildSite = function()
		return {
			version = 2,
			coldOpenDone = true,
			tutorialStep = 2,
			totalRescues = 1,
			dock = { levels = { Harbour = 1, HQ = 1 } },
			construction = { key = "Workshop", level = 1, progress = 0.2, rate = 1, at = NOW - 20 },
			depot = { stock = 3, at = NOW - 20 },
			workers = { worker("Builder", 1, "Nell") },
		}
	end
	F.beatSpin = function()
		return {
			version = 2,
			coldOpenDone = true,
			tutorialStep = 3,
			totalRescues = 2,
			dock = { levels = { Harbour = 1, HQ = 1, Workshop = 1 } },
			workers = { worker("Builder", 1, "Nell") },
		}
	end
	F.beatDone = function()
		local raw = F.beatSpin()
		raw.tutorialStep = 4
		return raw
	end
	-- 0 Cash, nothing affordable, no boat bought, everyone idle: the jet ski still rescues
	F.brokeEarly = function()
		return {
			version = 2,
			coldOpenDone = true,
			tutorialStep = 4,
			totalRescues = 6,
			cash = 0,
			dock = { levels = { Harbour = 1, HQ = 1, Workshop = 1 } },
		}
	end
	F.midGame = function()
		return {
			version = 2,
			cash = 23456,
			medals = 7,
			totalRescues = 420,
			coldOpenDone = true,
			tutorialStep = 4,
			vehicles = { RIB = true },
			vehicleUpgrades = { RIB = 3, JetSki = 1 },
			dock = {
				levels = {
					Harbour = 2,
					HQ = 2,
					Workshop = 2,
					Boathouse = 1,
					Depot = 1,
					Bunkhouse = 1,
				},
				prepaid = { Boathouse = 2 },
			},
			construction = { key = "FishShed", level = 1, progress = 0.6, rate = 3, at = NOW - 120 },
			depot = { stock = 12, at = NOW - 120 },
			workers = {
				worker("Builder", 3, "Ada"),
				worker("Gatherer", 2, "Bo"),
				worker("Rescuer", 1, "Cy"),
				worker("Hauler", 4, "Di"),
			},
			pity = { epic = 4, legendary = 30 },
			lastSeen = NOW - 3600,
			flags = {
				streak = StreakRules.flagTable({ lastDay = 20716, streak = 3, cosmeticDay = 0 }),
				spin = SpinRules.encode(SpinRules.newState()),
				shop = { cashBoost = 300 },
				opsCompleted = 55,
				lastVehicle = "RIB",
			},
		}
	end
	F.maxed = function()
		local vehicles = {}
		for id, v in Config.Vehicles do
			if not v.passOnly then
				vehicles[id] = true
			end
		end
		local upgrades = {}
		for id in VehicleUpgrades.Vehicles do
			upgrades[id] = VehicleUpgrades.MAX_MASK
		end
		local skills = {}
		for _, n in SkillRules.NODES do
			skills[n.id] = true
		end
		local workers = {}
		for i = 1, 90 do
			table.insert(workers, worker(W.CATEGORIES[i % #W.CATEGORIES + 1], 6, `W{i}`))
		end
		return {
			version = 2,
			cash = 1e15,
			medals = 1e9,
			totalRescues = 1e7,
			coldOpenDone = true,
			tutorialStep = 4,
			vehicles = vehicles,
			vehicleUpgrades = upgrades,
			dock = { levels = maxedLevels(), prepaid = {} },
			depot = { stock = 1e9, at = NOW - 3 * DAY },
			workers = workers,
			skills = skills,
			pity = { epic = 1e9, legendary = -5 },
			lastSeen = NOW - 3 * DAY,
			flags = { spinBoat = "StormRunner", opsCompleted = 1e6 },
		}
	end
	-- LEGACY: the ranks / Rep era (pre-hub-cut: phone, town, cars, gear, hired crew, one-time dock rows,
	-- Cash skill nodes, v1 rarities, a construction of a merged row)
	F.legacyRanks = function()
		return {
			cash = 12000,
			rep = 4200,
			rank = 6,
			dockLevel = 4,
			dockBuildings = {
				Pontoon = true,
				Boathouse = true,
				LifeboatSlip = true,
				Hangar = true,
				FlowerBed = true,
				Garage = true,
			},
			dockPrepaid = { Crane = true, PicnicTable = true },
			vehicles = { RIB = true, Lifeboat = true, FireTruck = true, PoliceCar = true },
			vehicleUpgrades = { JetSki = 7, RIB = 3, Ambulance = 1 },
			gear = { EngineTune = 3, StrongGrip = 1 },
			crew = { Mechanic = true, Lifeguard = true },
			workers = {
				{ category = "Gatherer", rarity = 3, name = "Old Tom" },
				{ category = "Rescuer", rarity = 2, name = "Mae" },
				{ category = "Driver", rarity = 1, name = "Cab" },
			},
			skills = { CaptSpeed1 = true, CaptSpeed2 = true },
			phone = { apps = { "Store", "Map" }, wallpaper = 2 },
			town = { house = "Cottage", car = "Sedan", job = "Medic" },
			cars = { Sedan = true },
			certs = { Swim = { level = 2 } },
			exercises = { Drill1 = true },
			construction = { key = "Crane", progress = 0.5, rate = 2, at = NOW - 600 },
			totalRescues = 340,
			coldOpenDone = true,
			flags = {
				station = { lv = 1, at = NOW, c = 500 },
				album = { a1 = 7 },
				lighthouses = { HarbourLight = true },
				foghub = { f1 = "__" },
				challenges = { w = 3 },
				challengeMonth = "2026-08",
				halloween = { c = 4 },
				logbook = { n = 9 },
				offDuty = true,
				cameraSettings = { shake = 0.5, seen_board = true },
			},
		}
	end
	F.legacyPhone = function()
		return {
			version = 1,
			cash = 800,
			dockLevel = 1,
			phone = { battery = 100 },
			dockBuildings = { Boathouse = true },
			vehicles = { RIB = true },
			workers = { { category = "Builder", rarity = 3, name = "Legend" } },
			coldOpenDone = true,
			totalRescues = 12,
		}
	end
	-- a save that gained the `dock` shell before its levels were written
	F.legacyDockShell = function()
		return {
			version = 2,
			dock = { prepaid = {} },
			dockLevel = 2,
			dockBuildings = { Boathouse = true },
		}
	end
	F.legacyDockEmptyLevels = function()
		return { version = 2, dock = { levels = {} }, dockBuildings = {} }
	end
	-- a save written mid-construction, or at the finish before the site was cleared, then a day away
	F.siteDayAway = function()
		return {
			version = 2,
			coldOpenDone = true,
			tutorialStep = 4,
			totalRescues = 30,
			dock = { levels = { Harbour = 1, HQ = 2, Workshop = 1 } },
			construction = { key = "HQ", level = 3, progress = 0.99, rate = 1, at = NOW - DAY },
			depot = { stock = 0, at = NOW - DAY },
			lastSeen = NOW - DAY,
		}
	end
	F.siteAlreadyBuilt = function()
		return {
			version = 2,
			dock = { levels = { Harbour = 1, HQ = 2 } },
			construction = { key = "HQ", level = 2, progress = 1, rate = 1, at = NOW },
		}
	end
	F.decorSite = function()
		return {
			version = 2,
			dock = { levels = { Harbour = 1, HQ = 1 } },
			construction = { key = "FlowerBed", progress = 0.3, rate = 1, at = NOW - 5 },
		}
	end
	-- many people vs a small Bunkhouse; a full flags table (retired flags first)
	F.overCap = function()
		local workers = {}
		for i = 1, 200 do
			table.insert(workers, worker("Gatherer", 1, `G{i}`))
		end
		return {
			version = 2,
			dock = { levels = { Harbour = 1, HQ = 1, Bunkhouse = 1 } },
			workers = workers,
		}
	end
	F.flagsFull = function()
		local flags = {}
		for i = 1, 40 do
			flags[`retired{i}`] = i
		end
		return { version = 2, flags = flags }
	end
	F.corrupt = function()
		return {
			version = "two",
			cash = "lots",
			rep = {},
			totalRescues = -50,
			medals = 0 / 0,
			vehicles = 5,
			vehicleUpgrades = { JetSki = "x", RIB = -3, [4] = 2 },
			coldOpenDone = "yes",
			tutorialStep = 99,
			dockLevel = 1e9,
			dock = { levels = { HQ = "3", Harbour = math.huge, Nope = 2, [1] = 1 }, prepaid = 7 },
			dockBuildings = "all",
			dockPrepaid = { [1] = true },
			construction = { key = 5, progress = "half", at = "now" },
			depot = { stock = -1e9, at = -5 },
			workers = {
				"x",
				{ category = 1 },
				{ category = "Medic", rarity = 0 / 0, name = "N" },
				7,
			},
			pity = "x",
			skills = { 1, 2, 3 },
			lastSeen = "yesterday",
			flags = {
				[1] = true,
				[string.rep("x", 40)] = true,
				streak = "s",
				spin = 3,
				pets = { p1 = "x", n = {}, a = "a" },
				group = { g = "abc" },
				platformPrompts = true,
				isles = "x",
				fog = { 1, 2 },
				quest = { a = {} },
				stock = 9,
				shop = "x",
				cameraSettings = { shake = "big" },
				mentorAt = {},
			},
			cosmetics = { hat = 5, [string.rep("s", 30)] = "x" },
			badgeCounters = "x",
		}
	end

	local function count(map)
		local n = 0
		for _ in map do
			n += 1
		end
		return n
	end

	-- Every building reaches its max on Cash alone from these levels (a running site only waits its turn).
	local function allReachable(levels)
		local lv = table.clone(levels)
		local changed = true
		while changed do
			changed = false
			for _, key in DockConfig.BUILDINGS do
				local n = UnlockTree.levelOf(lv, key) + 1
				if n <= UnlockTree.maxLevel(key) and UnlockTree.canBuild(key, n, lv, math.huge) then
					lv[key] = n
					changed = true
				end
			end
		end
		for key in DockConfig.Buildings do
			if UnlockTree.levelOf(lv, key) < UnlockTree.maxLevel(key) then
				return false, key
			end
		end
		return true, nil
	end

	local function workOf(c)
		local b = DockConfig.Buildings[c.key]
		if b then
			return BuildTimer.work(b.levels[math.clamp(c.level or 1, 1, #b.levels)].cash)
		end
		return BuildTimer.work(DockConfig.Decorations[c.key].cash, true)
	end

	-- The checks every loaded profile must pass. `raw` is the stored data, `d` what loading made of it.
	local function playable(name, raw, d)
		local function check(ok, what)
			t.expect({ name, what, ok }).toEqual({ name, what, true })
		end
		-- the next save writes the same thing (refunds and remaps happen once)
		t.expect({ name, Rules.migrate(d) }).toEqual({ name, d })
		check(d.version == Config.SchemaVersion, "version")
		check(type(d.cash) == "number" and d.cash >= 0 and d.cash < math.huge, "cash")
		check(UnlockTree.levelOf(d.dock.levels, "Harbour") >= 1, "the jetty stands")
		-- a free way to earn Cash: the jet ski launches, the client rebuilds the same gate
		check((Rules.canUseVehicle(d, "JetSki")), "jet ski")
		local snap = Rules.snapshot(d)
		check((Rules.canUseVehicle(Rules.fromSnapshot(snap), "JetSki")), "snapshot jet ski")
		-- the tutorial beat has a target the player can act on
		local site = d.construction
		local beat = Onboarding.beat({
			coldOpenDone = d.coldOpenDone,
			totalRescues = d.totalRescues,
			step = d.tutorialStep,
			owned = d.dockBuildings,
			constructionKey = site and site.key,
		})
		if beat == "BuildHQ" then
			check((UnlockTree.canBuild("HQ", 1, d.dock.levels, 0)), "the free Hut")
		elseif beat == "HQSite" or beat == "Build" then
			check(site ~= nil, "site")
		elseif beat == "BuildStation" then
			local b = DockConfig.Buildings.Workshop.levels[1]
			local cash = d.cash + Onboarding.topUp(d.cash, b.cash)
			check(
				site ~= nil or (UnlockTree.canBuild("Workshop", 1, d.dock.levels, cash)),
				"Workshop"
			)
		elseif beat == "Spin" then
			local spin = SpinRules.accrue(SpinRules.decode(d.flags.spin), d.totalRescues, NOW + DAY)
			check(spin.free >= 1, "a spin within a day")
		end
		-- the build tree: always a next goal (or all maxed) and every level reachable without Robux
		local reachable, stuck = allReachable(d.dock.levels)
		check(reachable, `tree reachable ({stuck})`)
		local goal = NextGoal.next({ cash = d.cash, levels = d.dock.levels, construction = site })
		local maxed = true
		for key in DockConfig.Buildings do
			maxed = maxed and UnlockTree.levelOf(d.dock.levels, key) >= UnlockTree.maxLevel(key)
		end
		check(goal ~= nil or maxed, "goal")
		-- people: kept (never more than earned or the cap), placed, paying; a day-2 return pays finite Cash
		local earned = if type(raw) == "table" and type(raw.workers) == "table"
			then #raw.workers
			else 0
		local cap = UnlockTree.bunkCap(d.dock.levels) + SkillRules.effects(d.skills).workerCapAdd
		check(#d.workers <= math.max(cap, earned), "worker cap")
		local fx = W.effects(W.crew(d.workers, d.dockBuildings), SkillRules.effects(d.skills))
		for _, away in { -DAY, 0, DAY, 1e12 } do
			local pay = W.offlinePay(fx, away)
			check(pay >= 0 and pay < math.huge, `offline pay {away}`)
		end
		-- the Depot and site catch up a day away and the site's time left is finite
		if site then
			local level = UnlockTree.levelOf(d.dock.levels, "Depot")
			local rate = DepotRules.crewRate(d.workers, {})
			local work = workOf(site)
			local p = {
				cap = DepotRules.cap(level),
				drop = DepotRules.bargeLoads(
					level,
					DepotRules.haulUnits(d.workers, d.dockBuildings),
					0
				),
				carry = DepotRules.carrySpeed(rate, work),
				loads = DepotRules.loadsFor(work),
			}
			local s =
				{ stock = d.depot.stock, progress = site.progress, next = DepotRules.nextAt(NOW) }
			local after = DepotRules.advance(s, p, DAY)
			check(after.progress == 1, "site done after a day")
			check(DepotRules.timeLeft(s, p) < math.huge, "site time left")
		end
		-- every flag reader decodes whatever the save holds
		local f = d.flags
		local streak = StreakRules.fromFlagTable(f.streak)
		StreakRules.preview(streak, NOW + DAY)
		NotifyDue.entry(f.streak, NOW, nil)
		check(StreakRules.claim(streak, NOW + 3 * DAY) ~= nil, "day-2 return reward")
		SpinRules.accrue(SpinRules.decode(f.spin), d.totalRescues, NOW)
		PetRules.decode(f.pets)
		GroupReward.decode(f.group)
		PlatformPrompts.decode(f.platformPrompts)
		DiscoveryRules.decode(f.isles)
		DiscoveryRules.decodeFog(f.fog)
		QuestRules.decode(f.quest)
		CosmeticLoadout.owned(f, d.totalRescues)
		CosmeticLoadout.show(f, d.totalRescues)
		TrophyRules.wheelPrizes(f)
		if type(f.cameraSettings) == "table" then
			for k, v in f.cameraSettings do
				SettingsRules.clean(k, v)
			end
		end
		check(count(f) <= Rules.MAX_FLAGS, "flag budget")
	end

	local function load(raw)
		return Rules.migrate(raw)
	end

	t.test("every fixture loads playable", function()
		for name, make in F do
			playable(name, make(), load(make()))
		end
	end)

	t.test("the tutorial fixtures land on their beat", function()
		local want = {
			brandNew = "BuildHQ",
			beatBuildHQ = "BuildHQ",
			beatHQSite = "HQSite",
			beatColdOpen = "ColdOpen",
			beatRescue = "Rescue",
			beatBuildStation = "BuildStation",
			beatBuildSite = "Build",
			beatSpin = "Spin",
			beatDone = "Done",
			brokeEarly = "Done",
			legacyRanks = "Done",
			midGame = "Done",
		}
		for name, beat in want do
			local d = load(F[name]())
			local got = Onboarding.beat({
				coldOpenDone = d.coldOpenDone,
				totalRescues = d.totalRescues,
				step = d.tutorialStep,
				owned = d.dockBuildings,
				constructionKey = d.construction and d.construction.key,
			})
			t.expect({ name, got }).toEqual({ name, beat })
		end
	end)

	t.test("quests stay hidden until the tree gate; a save with quests keeps them", function()
		local function open(raw)
			local d = load(raw)
			local s = QuestRules.decode(d.flags.quest)
			return QuestRules.open(s, UnlockTree.unlocked("Quests", d.dock.levels)), s
		end
		for _, name in { "brandNew", "beatBuildHQ", "beatSpin", "beatDone", "brokeEarly" } do
			t.expect({ name, (open(F[name]())) }).toEqual({ name, false })
		end
		t.expect((open(F.midGame()))).toBe(true) -- the Rescue Post stands
		-- an old save mid-quest at HQ Lv1: quest and progress kept, quests open, and the open bit round-trips
		local raw = F.beatDone()
		raw.flags = { quest = { a = "Dog", s = "back", xBell = true, nQuestMaud = 20123 } }
		local ok, s = open(raw)
		t.expect(ok).toBe(true)
		t.expect(s.active).toBe("Dog")
		t.expect(s.stage).toBe("back")
		t.expect(s.done.Bell).toBe(true)
		t.expect(QuestRules.started(s)).toBe(true) -- no reveal for it
		s.open = true
		t.expect(QuestRules.decode(QuestRules.encode(s)).open).toBe(true)
		t.expect(QuestRules.decode(QuestRules.encode(QuestRules.new())).open).toBeNil()
	end)

	t.test("legacy saves keep what they earned and drop removed content", function()
		local d = load(F.legacyRanks())
		t.expect(d.rep).toBe(4200) -- kept as saved, never read
		t.expect(d.vehicles.RIB).toBe(true)
		t.expect(d.vehicles.Lifeboat).toBe(true)
		t.expect(d.vehicles.FireTruck).toBeNil()
		t.expect(d.vehicleUpgrades.Ambulance).toBeNil()
		t.expect(d.dockBuildings.FlowerBed).toBe(true)
		t.expect(d.dockBuildings.Garage).toBeNil()
		t.expect(d.dockPrepaid.PicnicTable).toBe(true) -- a paid decoration is never lost
		t.expect(d.construction.key).toBe("Harbour") -- the Crane site became Harbour Lv3
		t.expect(d.construction.level).toBe(3)
		t.expect(#d.workers).toBe(2) -- the Driver category is gone
		t.expect(d.workers[1].rarity).toBe(5) -- v1 legendary
		t.expect((d :: any).phone).toBeNil()
		t.expect((d :: any).town).toBeNil()
		t.expect((d :: any).cars).toBeNil()
		t.expect((d :: any).rank).toBeNil()
		t.expect(d.flags.station).toBeNil()
		t.expect(d.cash > 12000).toBe(true) -- gear, crew, Cash skill nodes and merged rows paid back
		t.expect(load(F.legacyPhone()).workers[1].rarity).toBe(5)
	end)

	t.test("a full flags table never drops a live flag for a retired one", function()
		local raw = F.legacyRanks()
		for i = 1, 40 do
			raw.flags[`retired{i}`] = i
		end
		raw.flags.shop = { cashBoost = 300, tickets = 2 } -- paid boosts
		raw.flags.streak = StreakRules.flagTable({ lastDay = 20716, streak = 5, cosmeticDay = 0 })
		raw.flags.spin = SpinRules.encode(SpinRules.newState())
		raw.flags.pets = PetRules.encode(PetRules.newState())
		local d = load(raw)
		t.expect(count(d.flags)).toBe(Rules.MAX_FLAGS)
		t.expect(d.flags.shop).toEqual(raw.flags.shop)
		t.expect(d.flags.streak).toEqual(raw.flags.streak)
		t.expect(d.flags.spin ~= nil).toBe(true)
		t.expect(d.flags.pets ~= nil).toBe(true)
		t.expect(d.flags.cameraSettings ~= nil).toBe(true)
		-- the retired flags give way, kept as saved while there is room
		t.expect(load({ flags = { album = { a1 = 7 } } }).flags.album).toEqual({ a1 = 7 })
	end)

	t.test("any field of a late save corrupted to any type still loads playable", function()
		local junk = {
			false,
			true,
			0,
			-1,
			1e308,
			-1e308,
			"x",
			string.rep("y", 300),
			{},
			{ 1, 2 },
			{ a = { b = {} } },
		}
		for _, base in { "maxed", "midGame", "legacyRanks" } do
			local fields = {}
			for key, value in F[base]() do
				table.insert(fields, { key })
				if type(value) == "table" then
					for sub in value do
						table.insert(fields, { key, sub })
					end
				end
			end
			for _, path in fields do
				for _, value in junk do
					local raw = F[base]()
					if #path == 1 then
						raw[path[1]] = value
					else
						raw[path[1]][path[2]] = value
					end
					local ok, d = pcall(load, raw)
					t.expect({ base, path[1], path[2], ok })
						.toEqual({ base, path[1], path[2], true })
					playable(`{base}.{path[1]}.{path[2]}`, raw, d)
				end
			end
		end
	end)

	-- The real DataService load/save path with a fake DataStore (as in tests/Data.spec.luau).
	local function service()
		local DS = t.load("src/server/Services/DataService.luau")
		local clock = { t = NOW }
		DS._test.setDeps({
			jobId = function()
				return "job-A"
			end,
			now = function()
				return math.floor(clock.t)
			end,
			clock = function()
				return clock.t
			end,
			wait = function(s)
				clock.t += s
			end,
			spawn = function(fn, ...)
				fn(...)
			end,
			random = function()
				return 0.5
			end,
			budget = function()
				return math.huge
			end,
			warn = function() end,
		})
		local store = { values = {} }
		function store:UpdateAsync(key, fn)
			local result = fn(DS.Logic.deepCopy(self.values[key]))
			if result ~= nil then
				self.values[key] = DS.Logic.deepCopy(result)
			end
			return result
		end
		DS._test.setStore(store)
		return DS, store, clock
	end

	local function player(id)
		local p = { UserId = id, Name = `P{id}`, Parent = true, attrs = {} }
		function p:GetAttribute(k)
			return self.attrs[k]
		end
		function p:SetAttribute(k, v)
			self.attrs[k] = v
		end
		function p:Kick() end
		return p
	end

	t.test("old records load through DataService, play, save and rejoin unchanged", function()
		for name, make in F do
			local DS, store, clock = service()
			local p = player(7)
			local raw = make()
			-- the oldest records had no version (v1) and no receipt ledger
			store.values.Player_7 = if raw == nil then nil else { data = raw }
			DS._test.playerAdded(p)
			local d = DS.Get(p)
			t.expect({ name, d ~= nil, p.attrs.DataTemporary }).toEqual({ name, true, nil })
			playable(name, raw, d)
			d.cash += 100 -- a rescue
			DS.MarkDirty(p)
			DS._test.playerRemoving(p)
			local saved = store.values.Player_7
			t.expect({ name, saved.version, saved.session })
				.toEqual({ name, DS.Logic.RECORD_VERSION, nil })
			t.expect({ name, saved.data.lastSeen }).toEqual({ name, clock.t })
			DS._test.playerAdded(p)
			local again = DS.Get(p)
			t.expect({ name, again }).toEqual({ name, saved.data })
			DS._test.playerRemoving(p)
		end
	end)

	t.test(
		"offline pay on join is saved with the new lastSeen: a rejoin never pays twice",
		function()
			local DS, store, clock = service()
			local p = player(9)
			local raw = F.midGame()
			raw.workers = { worker("Gatherer", 6, "G1"), worker("Gatherer", 6, "G2") }
			raw.dock.levels.FishShed = 1
			raw.lastSeen = NOW - DAY
			store.values.Player_9 = { version = 2, data = raw, receipts = {} }
			local function join()
				DS._test.playerAdded(p)
				local d = DS.Get(p)
				local fx =
					W.effects(W.crew(d.workers, d.dockBuildings), SkillRules.effects(d.skills))
				local pay = W.offlinePay(fx, clock.t - (d.lastSeen or clock.t))
				d.cash += pay -- WorkerService.PayOffline
				DS.MarkDirty(p)
				return pay, d.cash
			end
			local pay, cash = join()
			t.expect(pay > 0).toBe(true)
			clock.t += 5 -- leaves while the Collect prompt is still up
			DS._test.playerRemoving(p)
			t.expect(store.values.Player_9.data.cash).toBe(cash)
			local again = join()
			t.expect(again).toBe(0)
			DS._test.playerRemoving(p)
		end
	)
end
