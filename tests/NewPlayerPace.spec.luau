-- NewPlayerPace: the docs/15 section 3 first 15 minutes, walked headlessly. A fresh profile goes
-- through the real onboarding sequence (cold open, the tutorial calls CallLogic picks, the beacon
-- goals and offer holds of Onboarding, the gear, the Helm exercise) with the real payouts and
-- certification rules. Only the clock is assumed: the Round 4 Studio timings
-- (docs/research/playtest-first-20-min.md). Prints the milestone minutes per scenario.
return function(t)
	local ProgressionConfig = t.load("src/shared/Config/ProgressionConfig.luau")
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local Onboarding = t.load("src/shared/Onboarding.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")
	local CallLogic = t.load("src/shared/Calls/CallLogic.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")
	-- shortcut: the exercise board's times, inlined when WP1 cut the exercises; WP9 rewrites this pace model
	local Exercises = {
		Defs = {
			ExerciseBoatHandling = { minutes = 3 },
			ExerciseCasualtyCare = { minutes = 2.5 },
			ExerciseSwimTest = { minutes = 2.5 },
			ExerciseCoxswain = { minutes = 3.5 },
		},
	}
	local Grading = t.load("src/shared/Ops/Grading.luau")
	local ChallengeRules = t.load("src/shared/ChallengeRules.luau")
	local StreakRules = t.load("src/shared/StreakRules.luau")

	-- Round 4 clock (minutes from spawn): cold open Complete 0:19, call 2 accepted at the board
	-- 0:48 and done 5:55 (5.1 min incl. launch and travel). Walks to the Chandlery or the exercise
	-- board were not reached in Studio: 1 minute each (assumed).
	local COLD_OPEN = 0.31
	local FIRST_ACCEPT = 0.8
	local CALL_MIN = 5.1
	local WALK_MIN = 1
	local UID = 1
	local HELM = ProgressionConfig.Certifications.Helm
	local function run(approachGrades: { string }, dailyOnCall2: boolean)
		local data = Rules.defaultData()
		local now = 0
		local completed = 0 -- OperationService st.completed (the cold open is one)
		local events = {}
		local seen = {}
		local cashAt = {}
		local idle = 0
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
			if data.cash >= ProgressionConfig.GearLevelPrices[1] then
				mark("gear affordable")
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
			-- the cold open credits a Silver approach (G50); live calls grade the player's own
			local steps = {
				{ id = "approach", grade = grade, userId = UID, mechanicId = "approach" },
			}
			Rules.recordOperation(data, kind, steps, UID)
			completed += 1
			award(reward.cash, reward.rep)
		end

		now = COLD_OPEN
		operation("Swimmer")
		mark("first reward")
		now = FIRST_ACCEPT
		while now < 20 do
			local snap = Rules.snapshot(data) -- what both sides read (ProgressionService.GetData)
			local function facts(offerReady: boolean, certEarned: boolean)
				return {
					coldOpenDone = true,
					stationReached = true,
					boardReached = true,
					callsCompleted = completed - 1,
					offerReady = offerReady,
					gearOwned = next(snap.gear) ~= nil,
					certEarned = certEarned,
					seconds = (now - COLD_OPEN) * 60,
				}
			end
			-- OperationService.onboardingHoldsOffers, then the client's beacon (OnboardingController)
			local held = completed > 1
				and Onboarding.holdsOffers(
					Onboarding.goal(facts(false, Onboarding.certDone(snap.certs)))
				)
			local goal = Onboarding.goal(facts(not held, Onboarding.certDone(snap.certs)))
			if goal == "Station" then
				-- the beacon sits on the station and no tasking comes: wait for the next unlock
				local nextAt = COLD_OPEN
					+ (
							if next(data.gear) == nil
								then Onboarding.GEAR_AT
								else Onboarding.CERT_AT
						)
						/ 60
				idle += nextAt - now
				now = nextAt
			elseif goal == "Gear" then
				now += WALK_MIN
				local streak = StreakRules.claim(StreakRules.newState(), 1792800000)
				if streak then
					award(streak.cash, 0) -- the porch crate on the way (docs/15: crate at 5:00)
				end
				local ok, _, price = Rules.canBuyGear(data, "EngineTune")
				assert(ok, "first gear not affordable at the beacon")
				data.cash -= price
				data.gear.EngineTune = 1
				mark("gear bought")
			elseif goal == "Cert" then
				mark("cert exercise available")
				local ex = Exercises.Defs[HELM.exercise]
				now += WALK_MIN + ex.minutes
				local steps = { { id = "approach", grade = "Silver", userId = UID } }
				local res = Rules.recordExercise(data, HELM.exercise, "Silver", steps, UID)
				award(res.reward.cash, res.reward.rep)
			else
				if completed > 1 then
					now += CallTypes.Scheduler.OfferDelay / 60
				end
				local choice = CallLogic.chooseCall(completed, "Calm", function()
					return 0.5
				end)
				now += CALL_MIN
				operation(choice.kind)
				if completed == 2 and dailyOnCall2 then
					-- Round 4: a 2-target daily (two PIW ops) completed with call 2
					local cash, rep =
						ChallengeRules.rewardFor(ChallengeRules.def("d_piw"), Rules.rankIndex(data))
					award(cash, rep)
				end
			end
		end
		local cash10 = 0
		for _, row in cashAt do
			if row.at <= 10 then
				cash10 = row.cash
			end
		end
		local gearPrice = if data.gear.EngineTune then ProgressionConfig.GearLevelPrices[1] else 0
		if seen["gear bought"] and seen["gear bought"] <= 10 then
			cash10 -= gearPrice
		end
		return {
			at = seen,
			events = events,
			rib = cash10 / ProgressionConfig.Vehicles.RIB.price,
			idle = idle,
		}
	end

	local scenarios = {
		{ name = "Silver, daily on call 2 (Round 4)", r = run({ "Silver" }, true) },
		{ name = "Silver, no early daily", r = run({ "Silver" }, false) },
		{ name = "Bronze call 2, Silver after", r = run({ "Silver", "Bronze", "Silver" }, false) },
	}
	print("\nNewPlayerPace (minutes from spawn)")
	for _, s in scenarios do
		local parts = {}
		for _, label in s.r.events do
			table.insert(parts, string.format("%s %.1f", label, s.r.at[label]))
		end
		print(
			string.format(
				"  %-34s %s | RIB %d%% at 10:00 | idle %.1f min",
				s.name,
				table.concat(parts, ", "),
				math.floor(s.r.rib * 100 + 0.5),
				s.r.idle
			)
		)
	end

	local main, noDaily, bronze = scenarios[1].r, scenarios[2].r, scenarios[3].r

	t.test("first reward under 3 minutes", function()
		t.expect(main.at["first reward"] < 3).toBe(true)
	end)

	t.test("first gear bought at about 5 minutes", function()
		for _, r in { main, noDaily, bronze } do
			t.expect(r.at["gear bought"] >= 4 and r.at["gear bought"] <= 8).toBe(true)
		end
	end)

	t.test("first rank-up at about 10 minutes (8 to 13)", function()
		for _, r in { main, noDaily } do
			local at = r.at["first rank-up"]
			t.expect(at ~= nil and at >= 8 and at <= 13).toBe(true)
		end
		-- a Bronze approach on call 2 waits for the next Silver approach (Helm live count)
		t.expect(bronze.at["first rank-up"] ~= nil and bronze.at["first rank-up"] <= 18).toBe(true)
	end)

	t.test("the certification exercise comes before the rank-up", function()
		t.expect(main.at["cert exercise available"] <= main.at["first rank-up"]).toBe(true)
	end)

	t.test("no new player waits long at the station for an unlock", function()
		for _, r in { main, noDaily, bronze } do
			t.expect(r.idle <= 1).toBe(true)
		end
	end)

	t.test("the RIB is in sight at 10 minutes", function()
		t.expect(main.rib >= 0.4).toBe(true)
		t.expect(noDaily.rib >= 0.2).toBe(true)
	end)
end
