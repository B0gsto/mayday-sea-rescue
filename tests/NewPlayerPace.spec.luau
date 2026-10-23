-- NewPlayerPace: the first 15 minutes, walked headlessly. A fresh profile goes through the cold
-- open and the tutorial calls CallLogic picks with the real payouts, buys the jet ski Engine
-- upgrade as soon as it is affordable (docs/16 B5) and ranks up on Rep alone (docs/16 K7). Only
-- the clock is assumed: the Round 4 Studio timings (docs/research/playtest-first-20-min.md).
-- Prints the milestone minutes per scenario.
return function(t)
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local VehicleUpgrades = t.load("src/shared/VehicleUpgrades.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")

	-- Round 4 clock (minutes from spawn): cold open Complete 0:19, call 2 accepted at the board
	-- 0:48 and done 5:55 (5.1 min incl. launch and travel). Opening the phone and buying the
	-- upgrade: 1 minute (assumed).
	local COLD_OPEN = 0.31
	local FIRST_ACCEPT = 0.8
	local CALL_MIN = 5.1
	local BUY_MIN = 1
	local ENGINE = (VehicleUpgrades.entry("JetSki", "Engine") :: any).price
	local function run(approachGrades: { string })
		local data = Rules.defaultData()
		local now = 0
		local completed = 0 -- OperationService st.completed (the cold open is one)
		local events = {}
		local seen = {}
		local cashAt = {}
		local function mark(label: string)
			if not seen[label] then
				seen[label] = now
				table.insert(events, label)
			end
		end
		local function award(cash: number, rep: number)
			local c, r = Rules.applyAward(cash, rep, "Calm", false)
			data.cash += c
			data.rep += r
			table.insert(cashAt, { at = now, cash = data.cash })
			if data.cash >= ENGINE then
				mark("upgrade affordable")
			end
			if Rules.rankIndex(data) >= 2 then
				mark("first rank-up")
			end
		end
		local function operation(kind: string)
			local def = Operations.Defs[Operations.FromCallKind[kind]]
			local grade = approachGrades[completed + 1] or approachGrades[#approachGrades]
			local tut = if completed < #Grading.Payout.Tutorial then completed else nil
			local reward = Grading.payout(def.weight, grade, 1, tut)
			completed += 1
			award(reward.cash, reward.rep)
		end

		now = COLD_OPEN
		operation("Swimmer")
		mark("first reward")
		now = FIRST_ACCEPT
		while now < 20 do
			if not seen["upgrade bought"] and data.cash >= ENGINE then
				now += BUY_MIN
				local streak = StreakRules.claim(StreakRules.newState(), 1792800000)
				if streak then
					award(streak.cash, 0) -- the daily crate on the way
				end
				data.cash -= ENGINE
				mark("upgrade bought")
			end
			if completed > 1 then
				now += CallTypes.Scheduler.OfferDelay / 60
			end
			local choice = CallLogic.chooseCall(completed, "Calm", function()
				return 0.5
			end)
			now += CALL_MIN
			operation(choice.kind)
		end
		local cash10 = 0
		for _, row in cashAt do
			if row.at <= 10 then
				cash10 = row.cash
			end
		end
		if seen["upgrade bought"] and seen["upgrade bought"] <= 10 then
			cash10 -= ENGINE
		end
		return {
			at = seen,
			events = events,
			rib = cash10 / ProgressionConfig.Vehicles.RIB.price,
		}
	end

	local scenarios = {
		{ name = "Silver", r = run({ "Silver" }) },
		{ name = "Bronze call 2, Silver after", r = run({ "Silver", "Bronze", "Silver" }) },
	}
	print("\nNewPlayerPace (minutes from spawn)")
	for _, s in scenarios do
		local parts = {}
		for _, label in s.r.events do
			table.insert(parts, string.format("%s %.1f", label, s.r.at[label]))
		end
		print(
			string.format(
				"  %-34s %s | RIB %d%% at 10:00",
				s.name,
				table.concat(parts, ", "),
				math.floor(s.r.rib * 100 + 0.5)
			)
		)
	end

	local main, bronze = scenarios[1].r, scenarios[2].r

	t.test("first reward under 3 minutes", function()
		t.expect(main.at["first reward"] < 3).toBe(true)
	end)

	t.test("first upgrade bought by about 6 minutes", function()
		for _, r in { main, bronze } do
			t.expect(r.at["upgrade bought"] ~= nil and r.at["upgrade bought"] <= 8).toBe(true)
		end
	end)

	t.test("first rank-up on Rep alone by about 11 minutes", function()
		for _, r in { main, bronze } do
			local at = r.at["first rank-up"]
			t.expect(at ~= nil and at <= 13).toBe(true)
		end
	end)

	t.test("the RIB is in sight at 10 minutes", function()
		t.expect(main.rib >= 0.2).toBe(true)
	end)
end
