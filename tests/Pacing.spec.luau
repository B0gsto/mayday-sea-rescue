-- Pacing: the docs/03 section 10 player (25-minute sessions, two a day, Silver grades,
-- occasional storm, solo or with one friend) against the real config and pure rules. Prints the
-- unlock timeline and the Cash at each session end, then asserts the targets. No ranks (docs/23 (q)):
-- progress is the island's unlock tree, bought with Cash only.
-- Every number comes from a config or a pure rule module; only the play pattern below is assumed.
return function(t)
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local Progression = t.load("src/shared/ProgressionRules.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local FriendBonus = t.load("src/shared/FriendBonus.luau")
	local VehicleUpgrades = t.load("src/shared/VehicleUpgrades.luau")
	local UnlockTree = t.load("src/shared/UnlockTree.luau")
	local WorkerRules = t.load("src/shared/WorkerRules.luau")

	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")
	local RingLayout = t.load("src/shared/Config/RingLayout.luau")
	-- docs/23 (k): calls count from the player's island berth; the sim plays every island in turn (the east
	-- island has Skerry Isle on its doorstep, the west one sails farther), so the averages are the server's
	local HOMES = {}
	for _, island in RingLayout.Islands do
		table.insert(HOMES, CallLogic.homeOf(island.berths.Boat))
	end

	-- The free player's walk through the tree (docs/23 (q)): the boathouse and RIB first, the fish shed (its
	-- Gatherers earn while you play, WP-26), the lifeboat, the rescue boathouse, the helicopter's branch, then
	-- the rest. Every prerequisite comes before its item (planNext asserts it).
	local PLAN = {
		"Workshop",
		"Boathouse",
		"RIB",
		"Pontoon",
		"FishShed",
		"LifeboatSlip",
		"Lifeboat",
		"LookoutTower",
		"RescueBoathouse",
		"Helipad",
		"Hangar",
		"RescueHelicopter",
		"BoatYard",
		"Crane",
		"SubPen",
		"Submarine",
		"Station",
		"TrophyHall",
		"Clinic",
	}
	local LABEL = { RescueHelicopter = "Helicopter" }

	local SESSION_MIN = 25
	local MAX_PLAY_MIN = 40 * 60
	local HOUR = 60

	-- docs/03 section 10.1: the three-operation cold open chain is about 13 minutes.
	local TUTORIAL_MIN = { 1.5, 5.75, 5.75 }
	-- docs/23 (2026-10-25): every later call is a real CallLogic call (zone tier by the best craft, pay x
	-- distancePay). Its clock: per call the answer, the offer gap and the debrief; per trip out and back to
	-- the dock at the docs/02 cruise (CallLogic.travelSeconds) plus slow down, climb on and climb off.
	-- Victims over the craft's seats mean another trip. -- tune
	local CALL_S, TRIP_S = 45, 35
	local START_UTC = 1792800000 -- 2026-10-24 00:00:00 UTC

	local function run(friends: number, legacy: boolean?)
		local data = Progression.defaultData()
		local friendMult = if legacy then 1 else FriendBonus.multiplier(friends)
		local playMin = 0
		local opIndex = 0
		local sessionNo = 0
		local seed = 20261020
		local function random(): number
			seed = (seed * 75 + 74) % 65537
			return seed / 65537
		end

		local timeline = {}
		local seen = {}
		local function mark(label: string)
			if not seen[label] then
				seen[label] = true
				table.insert(timeline, { at = playMin, label = label, cash = data.cash })
			end
		end

		local streak = StreakRules.newState()
		local owned = data.vehicles -- the craft bought (the jet ski is free)
		local built = data.dockBuildings -- the island's buildings (the unlock tree, docs/23 (q))
		local upgrades = { JetSki = 0, RIB = 0, Lifeboat = 0 }
		local totalOps = 0
		-- WP-26: every person delivered home becomes a worker (the roll on a counter seed); `legacy` has none.
		-- Rescuer boats' occasional extra worker is left out (the cap is reached within hours anyway).
		local rolls = 0
		local function fx()
			return WorkerRules.effects(WorkerRules.units(data.workers, built))
		end
		local function recruit(people: number)
			for _ = 1, if legacy then 0 else people do
				rolls += 1
				local category, rarity, name = WorkerRules.roll(rolls * 7919)
				WorkerRules.admit(
					data.workers,
					{ category = category, rarity = rarity, name = name }
				)
				if #data.workers == WorkerRules.CAP then
					mark("Workers full")
				end
			end
		end

		local function isGreat(_now: number): boolean
			return false -- the hourly Great Storm clock was cut (always sunny)
		end

		-- docs/23 (q): a free player walks the unlock tree in PLAN order with Cash only, each item as soon
		-- as it is affordable (a due upgrade goes first: they are cheap and make the craft better)
		local planIndex = 1
		local function planNext()
			while PLAN[planIndex] do
				local key = PLAN[planIndex]
				if DockConfig.Buildings[key] then
					local ok, reason, price =
						UnlockTree.canBuy(key, built, data.cash, fx().buildDiscount)
					assert(reason ~= "Needs", `PLAN buys {key} before its prerequisites`)
					if not ok or not price then
						return
					end
					data.cash -= price
					built[key] = true
					mark(key .. " built")
				else
					local ok, reason, price = Progression.canBuyVehicle(data, key)
					assert(not string.find(reason, "Needs", 1, true), `PLAN buys {key} first`)
					if not ok then
						return
					end
					data.cash -= price
					owned[key] = true
					mark((LABEL[key] or key) .. " bought")
				end
				planIndex += 1
			end
		end

		-- docs 03 section 10: RIB engine, jet ski storm hull, lifeboat engine; week 1 fits the rest.
		local UPGRADE_AT = {
			{ "RIB", "Engine", 65 },
			{ "JetSki", "Hull", 110 },
			{ "Lifeboat", "Engine", 125 },
			{ "RIB", "Hull", 280 },
			{ "JetSki", "Engine", 290 },
			{ "RIB", "Fit", 300 },
			{ "Lifeboat", "Hull", 310 },
		}

		local function upgradesNext()
			for _, row in UPGRADE_AT do
				local vehicleId, upgradeId, at = row[1], row[2], row[3]
				local isOwned = vehicleId == "JetSki" or owned[vehicleId] == true
				if isOwned and playMin >= at then
					local ok, _, price = VehicleUpgrades.canBuy(
						vehicleId,
						upgradeId,
						upgrades[vehicleId],
						data.cash,
						isOwned
					)
					if ok then
						data.cash -= price
						upgrades[vehicleId] += VehicleUpgrades.bit(upgradeId)
						local upgrade = VehicleUpgrades.entry(vehicleId, upgradeId)
						mark(
							`{VehicleUpgrades.SHORT[vehicleId]} {if upgrade
								then upgrade.name
								else upgradeId}`
						)
					end
				end
			end
		end

		local function award(cash: number, storm: boolean?, great: boolean?)
			data.cash += (Progression.applyAward(
				cash * friendMult,
				if storm then "Storm" else "Calm",
				great == true
			))
			upgradesNext()
			planNext()
		end

		-- the next real call (docs/23 e.2): its pay weight x distancePay and minutes
		local perCraft = {}
		local function nextCall(storm: boolean): (number, number, number)
			local ids = { "JetSki" }
			for id in owned do
				table.insert(ids, id)
			end
			local home = HOMES[totalOps % #HOMES + 1]
			local choice = CallLogic.chooseCall(
				totalOps,
				if storm then "Storm" else "Calm",
				random,
				CallLogic.craftReach(ids),
				false,
				home
			)
			local spec = CallTypes.Kinds[choice.kind]
			local at = CallLogic.pickSpawnPoint(choice.zone, random, nil, home)
			local distance = CallLogic.flatDistance(at, home)
			-- the reach comes from every owned craft; the player takes whichever owned boat is quickest
			local seconds, best = math.huge, "JetSki"
			local speed = fx().craftSpeed
			for _, id in { "JetSki", "RIB", "Lifeboat" } do
				if id == "JetSki" or owned[id] then
					local craft = VehicleConfig[id]
					local trips =
						math.ceil((choice.victims or spec.victims) / craft.survivorCapacity)
					local s = CALL_S
						+ trips
							* (TRIP_S + 2 * CallLogic.travelSeconds(
								distance,
								craft.topSpeed * speed
							))
					if s < seconds then
						seconds, best = s, id
					end
				end
			end
			local pay = CallLogic.distancePay(distance)
			local row = perCraft[best] or { calls = 0, minutes = 0, pay = 0 }
			perCraft[best] = row
			row.calls += 1
			row.minutes += seconds / 60
			row.pay += pay
			return Operations.Defs[Operations.FromCallKind[choice.kind]].weight * pay,
				seconds / 60,
				choice.victims or spec.victims
		end

		local function runOperation(
			minutes: number,
			planned: number,
			now: number,
			weight: number?,
			people: number
		)
			local completeAt = now + minutes * 60
			playMin += minutes
			local scale = if minutes < planned - 1e-6 then minutes / planned else 1
			local great = isGreat(completeAt)
			local storm = great or opIndex % 5 == 4
			local reward = if weight
				then Grading.payout(weight, "Silver", 1, nil)
				else Grading.Payout.Tutorial[totalOps + 1]
			local f = fx()
			-- Gatherers and the Rescuers' boat earn through the op's minutes (flat Cash, no multipliers)
			data.cash += math.floor(
				(f.gatherPerMin + f.rescuePerTrip * 60 / WorkerRules.RESCUE_PERIOD) * minutes
			)
			award(reward.cash * scale * (1 + f.payBonus), storm, great)
			if scale == 1 then
				recruit(people)
			end

			totalOps += 1
			opIndex += 1
			if totalOps == 1 then
				mark("First rescue")
			end
		end

		local sessions = {}
		local lastEnd: number? = nil
		for d = 1, 80 do
			for s = 1, 2 do
				if playMin >= MAX_PLAY_MIN then
					break
				end
				sessionNo += 1
				local startMinute = (
					if s == 1 then 9 * HOUR + (d * 13) % 50 else 19 * HOUR + (d * 29) % 50
				)
				local now = START_UTC + (d - 1) * 86400 + startMinute * 60

				local remaining = SESSION_MIN
				if lastEnd and not legacy then
					data.cash += WorkerRules.offlinePay(fx(), now - lastEnd) -- collected on join
				end
				local cashAtStart = data.cash
				while remaining > 0.01 do
					local planned, weight, people = TUTORIAL_MIN[totalOps + 1], nil, 1
					if not planned then
						weight, planned, people = nextCall(opIndex % 5 == 4)
					end
					local minutes = math.min(planned, remaining)
					runOperation(minutes, planned, now, weight, people)
					now += minutes * 60
					remaining -= minutes
				end
				if s == 2 then
					if not legacy then
						local crate = StreakRules.claim(streak, now)
						if crate then
							streak = crate.state
							award(crate.cash, false, isGreat(now))
							mark("Streak crate")
						end
					end
				end
				lastEnd = now
				table.insert(sessions, {
					at = playMin,
					day = d,
					session = s,
					cash = data.cash,
					gained = data.cash - cashAtStart,
				})
			end
			if playMin >= MAX_PLAY_MIN then
				break
			end
		end

		return {
			timeline = timeline,
			legacy = legacy == true,
			sessions = sessions,
			cash = data.cash,
			totalOps = totalOps,
			playMin = playMin,
			perCraft = perCraft,
			workers = #data.workers,
		}
	end

	local function find(result: any, label: string): any
		for _, entry in result.timeline do
			if entry.label == label then
				return entry
			end
		end
		return nil
	end

	local function report(result: any, name: string)
		print(`\nPacing: {name} (Cash at session end; unlock timeline)`)
		for _, entry in result.timeline do
			print(string.format("  %5.1f min  %-26s cash %7d", entry.at, entry.label, entry.cash))
		end
		for i, session in result.sessions do
			if i <= 12 or i % 10 == 0 then
				print(
					string.format(
						"  session %2d (day %d): cash %7d (+%d)",
						i,
						session.day,
						session.cash,
						session.gained
					)
				)
			end
		end
		print(
			string.format(
				"  end: %.1f h, cash %d, ops %d, workers %d",
				result.playMin / 60,
				result.cash,
				result.totalOps,
				result.workers
			)
		)
		for _, id in { "JetSki", "RIB", "Lifeboat" } do
			local row = result.perCraft[id]
			if row then
				print(
					string.format(
						"  %-8s %4d calls, %.1f min/call, distance pay x%.2f",
						id,
						row.calls,
						row.minutes / row.calls,
						row.pay / row.calls
					)
				)
			end
		end
	end

	local before = run(0, true)
	local solo = run(0)
	local friend = run(1)
	report(before, "before (no streak crate)")
	report(solo, "after, solo")
	report(friend, "after, one friend")

	local function minutes(result: any, label: string): number
		local entry = find(result, label)
		assert(entry, `missing pacing milestone: {label}`)
		return entry.at
	end

	local function between(result: any, label: string, low: number, high: number)
		local at = minutes(result, label)
		t.expect(at >= low and at <= high).toBe(true)
	end

	t.test("the plan covers the whole tree and every free craft", function()
		local inPlan = {}
		for _, key in PLAN do
			t.expect(inPlan[key]).toBeNil()
			inPlan[key] = true
		end
		for key in DockConfig.Buildings do
			t.expect(inPlan[key]).toBe(true)
		end
		for id, v in ProgressionConfig.Vehicles do
			t.expect(inPlan[id] == true or v.price == 0).toBe(true)
		end
	end)

	t.test("first rescue under 3 minutes", function()
		t.expect(minutes(solo, "First rescue") < 3).toBe(true)
	end)

	t.test(
		"the first island building in session 1 (the onboarding clock: NewPlayerPace)",
		function()
			between(solo, "Workshop built", 3, 20)
		end
	)

	t.test("boathouse and RIB in the first hour", function()
		between(solo, "Boathouse built", 15, 45)
		between(solo, "RIB bought", 20, 60)
		between(friend, "RIB bought", 15, 60)
	end)

	t.test("the lifeboat at about 1:30-3:00", function()
		between(solo, "Lifeboat bought", 90, 180)
	end)

	t.test("helicopter in week 1", function()
		-- docs 03 section 10.2: past 8 hours, cut its price (the bill includes the helipad and hangar)
		between(solo, "Helicopter bought", 180, 8 * 60)
	end)

	t.test("the first 2 hours still carry the early unlocks", function()
		-- at least six unlocks the config can time, and no modeled gap over half an hour before the lifeboat
		local anchors = {}
		for _, entry in solo.timeline do
			if entry.at <= 75 then
				table.insert(anchors, entry.at)
			end
		end
		t.expect(#anchors >= 6).toBe(true)
		table.insert(anchors, 0)
		table.sort(anchors)
		for i = 2, #anchors do
			t.expect(anchors[i] - anchors[i - 1] <= 30).toBe(true)
		end
	end)

	t.test("vehicle upgrades land when docs 03 section 10 expects", function()
		between(solo, "RIB Tuned engine", 55, 130)
		between(solo, "Jet ski Storm hull", 100, 200)
		between(solo, "Lifeboat Tuned engine", 115, 240)
	end)

	t.test("week 1 fits the planned upgrades", function()
		-- docs 03 section 10: RIB fully upgraded, lifeboat with two, jet ski Engine and Hull (it has no seat)
		t.expect(minutes(solo, "RIB Extra seat") <= 10 * 60).toBe(true)
		t.expect(minutes(solo, "Lifeboat Storm hull") <= 10 * 60).toBe(true)
	end)

	t.test("one friend only speeds things up", function()
		t.expect(minutes(friend, "RIB bought") <= minutes(solo, "RIB bought")).toBe(true)
		t.expect(minutes(friend, "Clinic built") <= minutes(solo, "Clinic built")).toBe(true)
	end)

	t.test("docs/23 (q): a free player reaches every building and craft on Cash alone", function()
		for _, key in PLAN do
			local label = if DockConfig.Buildings[key]
				then key .. " built"
				else (LABEL[key] or key) .. " bought"
			t.expect(minutes(solo, label) <= 30 * 60).toBe(true)
		end
		-- the last building is a long goal, not a wall
		t.expect(minutes(solo, PLAN[#PLAN] .. " built") >= 10 * 60).toBe(true)
	end)
end
