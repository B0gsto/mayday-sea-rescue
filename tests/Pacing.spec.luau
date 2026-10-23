-- Pacing: the docs/03 section 10 player (25-minute sessions, two a day, Silver grades, dailies,
-- occasional storm, solo or with one friend) against the real config and pure rules. Prints the
-- unlock timeline and the Cash at each session end, then asserts the section 10 targets.
-- Every number comes from a config or a pure rule module; only the play pattern below is assumed.
return function(t)
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local Progression = t.load("src/shared/ProgressionRules.luau")
	local ChallengeConfig = t.load("src/shared/Config/ChallengeConfig.luau")
	local ChallengeRules = t.load("src/shared/ChallengeRules.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")
	local StationConfig = t.load("src/shared/Config/StationConfig.luau")
	local IdleIncome = t.load("src/shared/IdleIncome.luau")
	local SeasonConfig = t.load("src/shared/Config/Season.luau")
	local SeasonRules = t.load("src/shared/SeasonRules.luau")
	local StockConfig = t.load("src/shared/Config/StockConfig.luau")
	local MonetizationConfig = t.load("src/shared/Config/MonetizationConfig.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")
	local Exercises = t.load("src/shared/Ops/Definitions/Exercises.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local Variants = t.load("src/shared/Config/RescueVariants.luau")
	local Album = t.load("src/shared/RescueAlbum.luau")
	local FriendBonus = t.load("src/shared/FriendBonus.luau")
	local VehicleUpgrades = t.load("src/shared/VehicleUpgrades.luau")

	local SESSION_MIN = 25
	local MAX_PLAY_MIN = 40 * 60
	local HOUR = 60

	-- docs/03 section 2.1: operations per hour by zone (same order as the zone rows).
	local OPS_PER_HOUR = { 9, 8, 7, 6, 5.5 }
	-- docs/03 section 10.1: the three-operation cold open chain is about 13 minutes.
	local TUTORIAL_MIN = { 1.5, 5.75, 5.75 }

	-- Zone rows: the docs 03 payout bases (ChallengeConfig) paired with the docs 03 Cash rates
	-- (MonetizationConfig), in zone order. Ranks come from CashPackZones (the real zone gates).
	local CASH_ZONES = MonetizationConfig.CashPackZones
	local BASES = ChallengeConfig.ZoneBase

	local function zoneAt(rank: number): number
		local index = 1
		for i, zone in CASH_ZONES do
			if rank >= zone.rankIndex then
				index = i
			end
		end
		return index
	end

	local function picks(weights: { [string]: number }, keys: { string }, roll: number): string
		local total = 0
		for _, key in keys do
			total += weights[key]
		end
		local target = roll * total
		for _, key in keys do
			target -= weights[key]
			if target < 0 then
				return key
			end
		end
		return keys[#keys]
	end

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

		local season = SeasonRules.newState()
		local tiersClaimed = 0
		local streak = StreakRules.newState()
		local albumState = Album.newState()
		local pot = { lastAt = 0, cash = 0 }
		local levels = IdleIncome.newLevels()
		local gear = { EngineTune = 0 }
		local owned = {}
		local upgrades = { JetSki = 0, RIB = 0, Lifeboat = 0 }
		local certs = {}
		local exerciseDone = {}
		local totalOps = 0
		local swimmerOps = 0
		local sinceSwimmer = 0
		local towSeen = false
		local stormSeen = false

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

		local function vehicles()
			local r = rank()
			if not owned.RIB and r >= ProgressionConfig.Vehicles.RIB.rankIndex then
				local price = ProgressionConfig.Vehicles.RIB.price
				if data.cash >= price then
					data.cash -= price
					owned.RIB = true
					mark("RIB bought")
				end
			end
			if not owned.Lifeboat and r >= ProgressionConfig.Vehicles.Lifeboat.rankIndex then
				local price = ProgressionConfig.Vehicles.Lifeboat.price
				if data.cash >= price then
					data.cash -= price
					owned.Lifeboat = true
					mark("Lifeboat bought")
				end
			end
			if
				not owned.RescueHelicopter
				and r >= ProgressionConfig.Vehicles.RescueHelicopter.rankIndex
			then
				local price = ProgressionConfig.Vehicles.RescueHelicopter.price
				if data.cash >= price then
					data.cash -= price
					owned.RescueHelicopter = true
					mark("Helicopter bought")
				end
			end
		end

		local function reserve(): number
			local r = rank()
			if not owned.RIB and r >= ProgressionConfig.Vehicles.RIB.rankIndex then
				return ProgressionConfig.Vehicles.RIB.price
			end
			if not owned.Lifeboat and r >= ProgressionConfig.Vehicles.Lifeboat.rankIndex then
				return ProgressionConfig.Vehicles.Lifeboat.price
			end
			if
				not owned.RescueHelicopter
				and r >= ProgressionConfig.Vehicles.RescueHelicopter.rankIndex
			then
				return ProgressionConfig.Vehicles.RescueHelicopter.price
			end
			return 0
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
			{ "JetSki", "Fit", 320 },
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
			local level = gear.EngineTune
			if level < #ProgressionConfig.GearLevelPrices then
				local nextLevel = level + 1
				local price = ProgressionConfig.GearLevelPrices[nextLevel]
				local gate = ProgressionConfig.GearLevelRank[nextLevel]
				local wait = if nextLevel == 1 then 18 elseif nextLevel == 2 then 50 else 0
				if rank() >= gate and playMin >= wait and data.cash >= price + reserve() then
					data.cash -= price
					gear.EngineTune = nextLevel
					if nextLevel == 1 then
						mark("First gear level")
					end
				end
			end
			-- Station workshop: a late-game Cash sink that raises the idle pot (docs/15 H6).
			if
				not legacy
				and owned.RescueHelicopter
				and levels.workshop < StationConfig.MaxLevel
			then
				local cost = StationConfig.UpgradeCost[levels.workshop + 1]
				if data.cash >= cost then
					data.cash -= cost
					levels.workshop += 1
					mark("Workshop " .. levels.workshop)
				end
			end
		end

		local sources = { op = 0, daily = 0, weekly = 0, season = 0, other = 0 }
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

		local function addXp(amount: number, now: number)
			if legacy then
				return
			end
			season.xp = math.min(SeasonRules.MAX_XP, season.xp + math.floor(amount))
			while SeasonRules.claimable(season, tiersClaimed + 1, now) do
				tiersClaimed += 1
				local reward = SeasonRules.claim(season, tiersClaimed, now)
				if reward then
					award(reward.cash, reward.rep, now, false, isGreat(now), "season")
				end
			end
		end

		local function canTow(): boolean
			return owned.RIB == true
		end

		local function runOperation(minutes: number, planned: number, now: number)
			local r = rank()
			local z = zoneAt(r)
			local base = BASES[z]
			local kind
			if totalOps < #Grading.Payout.Tutorial then
				kind = CallTypes.TutorialChain[totalOps + 1].kind
			else
				local kinds = {}
				for _, k in CallTypes.NormalKinds do
					if k ~= "Tow" or canTow() then
						table.insert(kinds, k)
					end
				end
				kind = picks(CallTypes.KindWeights, kinds, random())
			end
			local def = Operations.Defs[Operations.FromCallKind[kind]]
			local completeAt = now + minutes * 60
			playMin += minutes
			local scale = if minutes < planned - 1e-6 then minutes / planned else 1
			local great = isGreat(completeAt)
			local storm = great or opIndex % 5 == 4
			local reward
			if totalOps < #Grading.Payout.Tutorial then
				reward = Grading.Payout.Tutorial[totalOps + 1]
			else
				local weight = def.weight
				reward = { cash = base.cash * weight, rep = base.rep * weight }
			end
			award(reward.cash * scale, reward.rep * scale, completeAt, storm, great, "op")

			-- Album sticker roll (AlbumService) and its Season XP.
			if not legacy and totalOps >= #Grading.Payout.Tutorial and scale >= 1 then
				local variant = Variants.choose(def.id, random(), great)
				if variant then
					local _, setKind = Album.record(albumState, variant.id)
					if setKind then
						award(Variants.SetCash[setKind] or 0, 0, completeAt, false, great)
					end
					addXp(SeasonRules.stickerXp(season, variant.id), completeAt)
				end
			end
			addXp(
				math.floor(scale * SeasonRules.xpForOperation({
					grade = "Silver",
					storm = storm,
					isBig = def.isBig == true,
					variant = nil,
				})),
				completeAt
			)

			totalOps += 1
			opIndex += 1
			if totalOps == 1 then
				mark("First rescue")
			end
			if totalOps > #Grading.Payout.Tutorial then
				swimmerOps += 1
				sinceSwimmer += 1
				towSeen = towSeen or def.id == "DisabledVessel"
				stormSeen = stormSeen or storm
			end
		end

		local function readyCert(): string?
			for _, id in ProgressionConfig.CertOrder do
				if not certs[id] then
					local cert = ProgressionConfig.Certifications[id]
					local needs = true
					for _, need in cert.needs do
						needs = needs and certs[need] == true
					end
					if needs then
						if id == "Helm" or id == "CasualtyCare" then
							if totalOps >= 2 and exerciseDone[id] ~= true then
								return id
							end
						elseif id == "RescueSwimmer" then
							if swimmerOps >= cert.live.count then
								return id
							end
						elseif id == "Coxswain" then
							if sinceSwimmer >= cert.live.count and towSeen and stormSeen then
								return id
							end
						end
					end
				end
			end
			return nil
		end

		local function runExercise(id: string, now: number): number?
			local cert = ProgressionConfig.Certifications[id]
			local info = Exercises.Defs[cert.exercise]
			if not info or info.minutes > SESSION_MIN then
				return nil
			end
			certs[id] = true
			data.certs[id] = true
			data.exercises[cert.exercise] = "Silver"
			exerciseDone[id] = true
			mark(id .. " certification")
			if id == "RescueSwimmer" then
				sinceSwimmer = 0
				towSeen = false
				stormSeen = false
			end
			award(
				ProgressionConfig.ExerciseReward.cash,
				ProgressionConfig.ExerciseReward.rep,
				now,
				false,
				isGreat(now)
			)
			playMin += info.minutes
			return info.minutes
		end

		local sessions = {}
		local lastDay = 0
		for d = 1, 80 do
			for s = 1, 2 do
				if playMin >= MAX_PLAY_MIN then
					break
				end
				sessionNo += 1
				if d ~= lastDay then
					lastDay = d
					-- One cosmetic trinket a week from the rotating Chandlery (a Cash sink).
					if d % 7 == 1 and d > 1 then
						local cheapest = math.huge
						for _, item in StockConfig.Items do
							if item.kind ~= "Gear" then
								cheapest = math.min(cheapest, item.price)
							end
						end
						if data.cash > cheapest then
							data.cash -= cheapest
						end
					end
				end
				local startMinute = (
					if s == 1 then 9 * HOUR + (d * 13) % 50 else 19 * HOUR + (d * 29) % 50
				)
				local now = SeasonConfig.startUtc + (d - 1) * 86400 + startMinute * 60

				if not legacy then
					-- Station crew pot (docs/15 H6): collected at the start of every session.
					local claim = IdleIncome.claim(pot, levels, now)
					pot = claim.pot
					if claim.cash > 0 then
						award(claim.cash, 0, now, false, isGreat(now))
					end
				end

				local remaining = SESSION_MIN
				local cashAtStart = data.cash
				while remaining > 0.01 do
					local id = readyCert()
					if id then
						local minutes = runExercise(id, now)
						if minutes and minutes <= remaining then
							now += minutes * 60
							remaining -= minutes
							continue
						end
					end
					local z = zoneAt(rank())
					local planned = if totalOps < #Grading.Payout.Tutorial
						then TUTORIAL_MIN[totalOps + 1]
						else 60 / OPS_PER_HOUR[z]
					local minutes = math.min(planned, remaining)
					runOperation(minutes, planned, now)
					now += minutes * 60
					remaining -= minutes
				end
				if s == 2 then
					if not legacy then
						local crate = StreakRules.claim(streak, now)
						if crate then
							streak = crate.state
							award(crate.cash, 0, now, false, isGreat(now))
							addXp(SeasonConfig.xp.streak, now)
							mark("Streak crate")
						end
					end
					local r = rank()
					for _ = 1, ChallengeConfig.DailyCount do
						local cash, rep = ChallengeRules.rewardFor(ChallengeConfig.Pool[1], r)
						award(cash, rep, now, false, isGreat(now), "daily")
					end
					award(ChallengeConfig.DailyBonusCash, 0, now, false, isGreat(now))
					if not legacy then
						addXp(ChallengeConfig.DailyCount * SeasonConfig.xp.challenge, now)
					end
					mark("Daily set")
					if d % 7 == 0 then
						local weekly
						for _, def in ChallengeConfig.Pool do
							if def.scope == "weekly" then
								weekly = def
								break
							end
						end
						for _ = 1, ChallengeConfig.WeeklyCount do
							local cash, rep = ChallengeRules.rewardFor(weekly, r)
							award(cash, rep, now, false, isGreat(now), "weekly")
						end
						if not legacy then
							addXp(ChallengeConfig.WeeklyCount * SeasonConfig.xp.challenge, now)
						end
						mark("Weekly set")
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
			tiers = tiersClaimed,
			totalOps = totalOps,
			playMin = playMin,
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
				"  end: %.1f h, cash %d, rep %d, season tiers %d, ops %d",
				result.playMin / 60,
				result.cash,
				result.rep,
				result.tiers,
				result.totalOps
			)
		)
		if not result.legacy then
			print(
				string.format(
					"  rep by source: ops %d, dailies %d, weeklies %d, season %d",
					result.sources.op,
					result.sources.daily,
					result.sources.weekly,
					result.sources.season
				)
			)
		end
	end

	local before = run(0, true)
	local solo = run(0)
	local friend = run(1)
	report(before, "before (no station, streak, season, album, Great Storm)")
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
		-- this model runs the Helm exercise straight after call 2 (no gear walk); the real
		-- onboarding order and clock are tests/NewPlayerPace.spec.luau (8 to 13 min)
		between(solo, "Rank 2 Lifeguard", 7, 16)
	end)

	t.test("RIB at about 0:30", function()
		between(solo, "RIB bought", 24, 38)
		between(friend, "RIB bought", 24, 38)
	end)

	t.test("Coxswain and the lifeboat at about 1:15-1:35", function()
		between(solo, "Rank 4 Coxswain", 60, 90)
		between(solo, "Lifeboat bought", 60, 100)
	end)

	t.test("helicopter in week 1", function()
		between(solo, "Rank 5 Rescue Pilot", 140, 220)
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
		between(solo, "RIB Tuned engine", 55, 75)
		between(solo, "Jet ski Storm hull", 100, 125)
		between(solo, "Lifeboat Tuned engine", 115, 140)
	end)

	t.test("week 1 fits the planned upgrades", function()
		-- docs 03 section 10: RIB fully upgraded, lifeboat with two, jet ski fully upgraded
		t.expect(minutes(solo, "RIB Tow post") <= 6 * 60).toBe(true)
		t.expect(minutes(solo, "Lifeboat Storm hull") <= 6 * 60).toBe(true)
		t.expect(minutes(solo, "Jet ski Rescue seat") <= 6 * 60).toBe(true)
	end)

	t.test("session 1 still ends near the docs 03 3,200 Cash", function()
		t.expect(solo.sessions[1].cash >= 2500 and solo.sessions[1].cash <= 4000).toBe(true)
	end)

	t.test("Admiral at about 32 hours (not before 25)", function()
		local at = minutes(solo, "Rank 8 Admiral")
		t.expect(at >= 25 * 60 and at <= 38 * 60).toBe(true)
	end)

	t.test("one friend only speeds Cash, never Rep", function()
		t.expect(friend.rep).toBe(solo.rep)
		local friendRib = minutes(friend, "RIB bought")
		local soloRib = minutes(solo, "RIB bought")
		t.expect(friendRib <= soloRib).toBe(true)
	end)
end
