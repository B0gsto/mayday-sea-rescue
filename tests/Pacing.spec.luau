-- Pacing: the docs/03 section 10 player (25-minute sessions, two a day, Silver grades,
-- occasional storm, solo or with one friend) against the real config and pure rules. Prints the
-- unlock timeline and the Cash at each session end, then asserts the section 10 targets.
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

	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local DockConfig = t.load("src/shared/Config/DockConfig.luau")

	local SESSION_MIN = 25
	local MAX_PLAY_MIN = 40 * 60
	local HOUR = 60

	-- docs/03 section 10.1: the three-operation cold open chain is about 13 minutes.
	local TUTORIAL_MIN = { 1.5, 5.75, 5.75 }
	-- docs/23 (2026-10-25): every later call is a real CallLogic call (zone tier by the best craft, pay x
	-- distancePay). Its clock: per call the radio, the offer gap and the debrief; per trip out and back to
	-- the dock at the docs/02 cruise (CallLogic.travelSeconds) plus slow down, climb on and climb off; a
	-- land call adds the walk up the beach. Victims over the craft's seats mean another trip. -- tune
	local CALL_S, TRIP_S, LAND_S = 45, 35, 30
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
				table.insert(
					timeline,
					{ at = playMin, label = label, cash = data.cash, rep = data.rep }
				)
			end
		end

		local streak = StreakRules.newState()
		local owned = {}
		local upgrades = { JetSki = 0, RIB = 0, Lifeboat = 0 }
		local totalOps = 0

		local function isGreat(_now: number): boolean
			return false -- the hourly Great Storm clock was cut (always sunny)
		end

		local function rank(): number
			return Progression.rankIndex(data)
		end

		local function checkRank()
			local r = rank()
			if r > 1 then
				mark("Rank " .. r .. " " .. ProgressionConfig.Ranks[r].displayName)
			end
		end

		-- the free ladder: RIB, lifeboat, then the helicopter, bought at the hangar board (docs/23 h), so
		-- its bill includes the hangar (which stands on the dock Lv 3 boathouse)
		local dockLevel = 1
		local built = {}
		local LADDER = {
			{ "RIB", "RIB bought" },
			{ "Lifeboat", "Lifeboat bought" },
			{ "RescueHelicopter", "Helicopter bought" },
		}

		local function bill(id: string): number
			local home = DockConfig.buildingOf(id)
			local extra = if home and not built[home] then DockConfig.Buildings[home].cash else 0
			return ProgressionConfig.Vehicles[id].price + extra
		end

		local function vehicles()
			for _, step in LADDER do
				local id = step[1]
				if not owned[id] then
					local home = DockConfig.buildingOf(id)
					if
						rank() >= ProgressionConfig.Vehicles[id].rankIndex
						and data.cash >= bill(id)
					then
						if
							home
							and not built[home]
							and dockLevel >= DockConfig.Buildings[home].needs
						then
							data.cash -= DockConfig.Buildings[home].cash
							built[home] = true
							mark(home .. " built")
						end
						if not home or built[home] then
							data.cash -= ProgressionConfig.Vehicles[id].price
							owned[id] = true
							mark(step[2])
						end
					end
					return -- one ladder step at a time
				end
			end
		end

		local function reserve(): number
			for _, step in LADDER do
				local id = step[1]
				if not owned[id] then
					return if rank() >= ProgressionConfig.Vehicles[id].rankIndex
						then bill(id)
						else 0
				end
			end
			return 0
		end

		-- docs/23 d.2 and h: dock levels, the other buildings and their craft, with Cash left over after
		-- the next ladder bill (the dock never delays a vehicle)
		local function dockNext()
			local r = rank()
			local ok, _, price =
				DockConfig.canBuy(dockLevel, dockLevel + 1, data.cash - reserve(), r)
			if ok then
				data.cash -= price
				dockLevel += 1
				mark("Dock Lv " .. dockLevel)
			end
			for _, key in DockConfig.BUILDINGS do
				local can, _, cost = DockConfig.canBuyBuilding(
					key,
					built[key] == true,
					dockLevel,
					data.cash - reserve(),
					r
				)
				if can then
					data.cash -= cost
					built[key] = true
					mark(key .. " built")
				end
			end
			for _, id in { "Submarine", "Seaplane" } do
				local v = ProgressionConfig.Vehicles[id]
				local home = DockConfig.buildingOf(id) :: string
				if
					not owned[id]
					and built[home]
					and r >= v.rankIndex
					and data.cash - reserve() >= v.price
				then
					data.cash -= v.price
					owned[id] = true
					mark(id .. " bought")
				end
			end
		end

		-- docs 03 section 10: RIB engine at 1:05, jet ski storm hull at 1:55, lifeboat engine at
		-- 2:05; week 1 fits the rest. A vehicle's next bill is still reserved first.
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
						rank(),
						isOwned
					)
					if ok and data.cash >= price + reserve() then
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

		local function purchases()
			vehicles()
			upgradesNext()
			dockNext()
		end

		local sources = { op = 0, other = 0 }
		local function award(
			cash: number,
			rep: number,
			_now: number,
			storm: boolean?,
			great: boolean?,
			source: string?
		)
			local finalCash, finalRep = Progression.applyAward(
				cash * friendMult,
				rep,
				if storm then "Storm" else "Calm",
				great == true
			)
			if great then
				finalRep *= 2
			end
			data.cash += finalCash
			local beforeRep = data.rep
			data.rep += finalRep
			if data.rep < beforeRep then
				error(string.format("rep fell at %.1f: %d -> %d", playMin, beforeRep, data.rep))
			end
			sources[source or "other"] += data.rep - beforeRep
			purchases()
			checkRank()
		end

		-- the next real call (docs/23 e.2): its pay weight x distancePay and minutes
		local perCraft = {}
		local function nextCall(storm: boolean): (number, number)
			local ids = { "JetSki" }
			for id in owned do
				table.insert(ids, id)
			end
			local choice = CallLogic.chooseCall(
				totalOps,
				if storm then "Storm" else "Calm",
				random,
				CallLogic.craftReach(ids)
			)
			local spec = CallTypes.Kinds[choice.kind]
			local site = if spec.land then CallLogic.landSite(nil, random, choice.zone) else nil
			local at = if site then site.beach else CallLogic.pickSpawnPoint(choice.zone, random)
			local distance = CallLogic.flatDistance(at, CallTypes.STATION)
			-- the reach comes from every owned craft; the player takes whichever owned boat is quickest
			local seconds, best = math.huge, "JetSki"
			for _, id in { "JetSki", "RIB", "Lifeboat" } do
				if id == "JetSki" or owned[id] then
					local craft = VehicleConfig[id]
					local trips =
						math.ceil((choice.victims or spec.victims) / craft.survivorCapacity)
					local s = CALL_S
						+ (if site then LAND_S else 0)
						+ trips
							* (TRIP_S + 2 * CallLogic.travelSeconds(distance, craft.topSpeed))
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
			return Operations.Defs[Operations.FromCallKind[choice.kind]].weight * pay, seconds / 60
		end

		local function runOperation(minutes: number, planned: number, now: number, weight: number?)
			local completeAt = now + minutes * 60
			playMin += minutes
			local scale = if minutes < planned - 1e-6 then minutes / planned else 1
			local great = isGreat(completeAt)
			local storm = great or opIndex % 5 == 4
			local reward = if weight
				then Grading.payout(weight, "Silver", 1, nil)
				else Grading.Payout.Tutorial[totalOps + 1]
			award(reward.cash * scale, reward.rep * scale, completeAt, storm, great, "op")

			totalOps += 1
			opIndex += 1
			if totalOps == 1 then
				mark("First rescue")
			end
		end

		local sessions = {}
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
				local cashAtStart = data.cash
				while remaining > 0.01 do
					local planned, weight = TUTORIAL_MIN[totalOps + 1], nil
					if not planned then
						weight, planned = nextCall(opIndex % 5 == 4)
					end
					local minutes = math.min(planned, remaining)
					runOperation(minutes, planned, now, weight)
					now += minutes * 60
					remaining -= minutes
				end
				if s == 2 then
					if not legacy then
						local crate = StreakRules.claim(streak, now)
						if crate then
							streak = crate.state
							award(crate.cash, 0, now, false, isGreat(now))
							mark("Streak crate")
						end
					end
				end
				table.insert(sessions, {
					at = playMin,
					day = d,
					session = s,
					cash = data.cash,
					gained = data.cash - cashAtStart,
					rep = data.rep,
				})
			end
			if playMin >= MAX_PLAY_MIN then
				break
			end
		end

		for label, entry in seen do
			assert(entry, label)
		end
		return {
			timeline = timeline,
			sources = sources,
			legacy = legacy == true,
			sessions = sessions,
			cash = data.cash,
			rep = data.rep,
			totalOps = totalOps,
			playMin = playMin,
			perCraft = perCraft,
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
			print(
				string.format(
					"  %5.1f min  %-26s cash %7d  rep %6d",
					entry.at,
					entry.label,
					entry.cash,
					entry.rep
				)
			)
		end
		for i, session in result.sessions do
			if i <= 12 or i % 10 == 0 then
				print(
					string.format(
						"  session %2d (day %d): cash %7d (+%d), rep %d",
						i,
						session.day,
						session.cash,
						session.gained,
						session.rep
					)
				)
			end
		end
		print(
			string.format(
				"  end: %.1f h, cash %d, rep %d, ops %d",
				result.playMin / 60,
				result.cash,
				result.rep,
				result.totalOps
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
	report(before, "before (no streak, Great Storm)")
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

	t.test("first rescue under 3 minutes", function()
		t.expect(minutes(solo, "First rescue") < 3).toBe(true)
	end)

	t.test("first rank at about 7-16 minutes", function()
		-- ranks are Rep only (docs/16 K7); the onboarding clock is tests/NewPlayerPace.spec.luau
		between(solo, "Rank 2 Lifeguard", 7, 16)
	end)

	t.test("RIB at about 15-25 minutes (docs/16 K7)", function()
		between(solo, "RIB bought", 15, 25)
		between(friend, "RIB bought", 15, 25)
	end)

	-- docs/16 cut the dailies, weeklies, the season track and Crew Pay: Rep now comes from rescues
	-- (and the crate's Cash), so the mid and late ranks sit later than docs 03 section 10 until WP2 retunes.
	-- docs/23 calls take 3.5 to 4.5 minutes (not docs 03's 6.5), so Coxswain lands early in session 3
	t.test("Coxswain and the lifeboat at about 1:00-2:00", function()
		between(solo, "Rank 4 Coxswain", 50, 110)
		between(solo, "Lifeboat bought", 60, 150)
	end)

	t.test("helicopter in week 1", function()
		between(solo, "Rank 5 Rescue Pilot", 140, 280)
		-- docs 03 section 10.2: past 8 hours, cut its price (the bill includes the docs/23 hangar)
		between(solo, "Helicopter bought", 170, 8 * 60)
	end)

	t.test("the first 2 hours still carry the early unlocks", function()
		-- docs 03 also fills this window with lighthouse missions and vehicle upgrades; neither is
		-- config-backed yet, so this checks the unlocks the config can time: at least six, and no
		-- modeled gap over half an hour before the lifeboat.
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
		between(solo, "RIB Tuned engine", 55, 100) -- after dock Lv 2 and the garage (docs/23)
		between(solo, "Jet ski Storm hull", 100, 160)
		between(solo, "Lifeboat Tuned engine", 115, 170)
	end)

	t.test("week 1 fits the planned upgrades", function()
		-- docs 03 section 10: RIB fully upgraded, lifeboat with two, jet ski Engine and Hull (it has no seat)
		t.expect(minutes(solo, "RIB Extra seat") <= 10 * 60).toBe(true)
		t.expect(minutes(solo, "Lifeboat Storm hull") <= 10 * 60).toBe(true)
	end)

	t.test("session 1 buys the RIB (docs/16 K7) and still ends with Cash", function()
		t.expect(solo.sessions[1].cash >= 1500 and solo.sessions[1].cash <= 4000).toBe(true)
	end)

	t.test(
		"Commodore at about day 16 (docs 03 section 10.1); Admiral not before 25 hours",
		function()
			between(solo, "Rank 7 Commodore", 12 * 60, 30 * 60)
			local admiral = find(solo, "Rank 8 Admiral")
			t.expect(admiral == nil or admiral.at >= 25 * 60).toBe(true)
		end
	)

	t.test("one friend only speeds Cash, never Rep", function()
		-- Rep moves only through earlier craft (reach sets distance pay), never the friend bonus itself
		t.expect(math.abs(friend.rep - solo.rep) <= solo.rep * 0.03).toBe(true)
		local friendRib = minutes(friend, "RIB bought")
		local soloRib = minutes(solo, "RIB bought")
		t.expect(friendRib <= soloRib).toBe(true)
	end)

	t.test("docs/23: a free player reaches every dock level, building and craft", function()
		-- a dock piece never comes before the RIB, and the last (dock Lv 5) is a long goal, not a wall
		t.expect(minutes(solo, "Dock Lv 2") >= minutes(solo, "RIB bought")).toBe(true)
		for _, label in { "Dock Lv 3", "Dock Lv 4", "Garage built", "Hangar built", "SubPen built" } do
			t.expect(minutes(solo, label) <= 20 * 60).toBe(true)
		end
		for _, label in { "Submarine bought", "Seaplane bought", "Dock Lv 5" } do
			t.expect(minutes(solo, label) <= 30 * 60).toBe(true)
		end
		t.expect(minutes(solo, "Dock Lv 5") >= 10 * 60).toBe(true)
	end)
end
