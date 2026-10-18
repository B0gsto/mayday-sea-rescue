-- Certs: training exercises (docs 09 section 9.2), certifications and the rank gate (docs 03
-- section 3 and 3.1): exercise definitions, passes and first-pass rewards, live operation
-- progress, prerequisites, promotion waiting for a certification, migration and grandfathering.
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")
	local Config = t.load("src/shared/Config/ProgressionConfig.luau")
	local Exercises = t.load("src/shared/Ops/Definitions/Exercises.luau")
	local Operations = t.load("src/shared/Ops/Operations.luau")
	local Grading = t.load("src/shared/Ops/Grading.luau")

	local ME = 101
	local mechanics = {}
	do
		local fs = t.lune("fs")
		for _, name in fs.readDir(t.gameDir .. "/src/client/Mechanics") do
			mechanics[(string.gsub(name, "%.luau$", ""))] = true
		end
	end

	local function data(rep)
		local d = Rules.defaultData()
		d.rep = rep or 0
		return d
	end

	-- every step of an exercise, done by me at one grade
	local function run(exerciseId, grade, by)
		local ex = Exercises.get(exerciseId)
		local steps = {}
		for _, s in ex.def.steps do
			table.insert(
				steps,
				{ id = s.id, grade = grade, userId = by or ME, mechanicId = s.mechanicId }
			)
		end
		return steps
	end

	-- a live PIW: the listed step ids at the grade by me, the rest by an NPC
	local function piw(grades, recoveryMechanic)
		local steps = {}
		for _, s in Operations.Defs.PersonInWater.steps do
			local g = grades[s.id]
			table.insert(steps, {
				id = s.id,
				grade = g or "Silver",
				userId = if g then ME else nil,
				mechanicId = if s.id == "recovery"
					then (recoveryMechanic or "recover_throwbag")
					else s.mechanicId,
			})
		end
		return steps
	end

	t.test("exercise definitions are real procedures on existing mechanics", function()
		t.expect(#Exercises.Order).toBe(4)
		for _, id in Exercises.Order do
			local ex = Exercises.get(id)
			t.expect(ex.def.id).toBe(id)
			t.expect(Exercises.isExercise(id)).toBe(true)
			t.expect(Operations.get(id)).toBeNil() -- never offered as a live call
			local seen = {}
			for _, s in ex.def.steps do
				t.expect(seen[s.id]).toBeNil()
				seen[s.id] = true
				t.expect(mechanics[s.mechanicId]).toBe(true)
				t.expect(s.npcAllowed).toBe(false) -- an exercise is always the player's own
				t.expect(s.weight > 0 and s.timeoutSec > 0 and #s.gradeBands >= 1).toBeTruthy()
				for _, b in s.gradeBands do
					if b.higherIsBetter then
						t.expect(b.gold >= b.silver and b.silver >= b.bronze).toBeTruthy()
					else
						t.expect(b.gold <= b.silver and b.silver <= b.bronze).toBeTruthy()
					end
				end
			end
			if ex.certification then
				t.expect(#ex.def.steps >= 3).toBeTruthy() -- multi-step, not go-press-return
				t.expect(Config.Certifications[ex.certification].exercise).toBe(id)
				t.expect(Exercises.forCertification(ex.certification).id).toBe(id)
			end
		end
		t.expect(Exercises.isExercise("PersonInWater")).toBe(false)
		t.expect(Exercises.get("ExerciseReopeningDay").cannotFail).toBe(true)
		t.expect(Exercises.get("ExerciseReopeningDay").def.steps[1].onFail).toBe("continue")
	end)

	t.test("exercise scenarios use the live recovery and medical rules", function()
		local swim = Exercises.get("ExerciseSwimTest").def
		t.expect(swim.states.Panicking).toBe(1)
		t.expect(Operations.RecoveryMethod.Panicking).toBe("swimmer")
		local drill = Exercises.get("ExerciseReopeningDay").def
		t.expect(Operations.RecoveryMethod[Operations.roll(drill.states, 0.5)]).toBe("throwbag")
		-- the casualty care manikin can roll the not-breathing (CPR) case
		local care = Exercises.get("ExerciseCasualtyCare").def
		t.expect(care.states.Unresponsive > 0 and care.lifejacketChance < 1).toBeTruthy()
		-- a mixed run grades like a live operation
		local scored = {}
		for _, s in Exercises.get("ExerciseBoatHandling").def.steps do
			table.insert(scored, { grade = "Silver", weight = s.weight })
		end
		t.expect(Grading.operationGrade(scored)).toBe("Silver")
	end)

	t.test("an exercise pays only on the first pass and keeps the best grade", function()
		local d = data()
		local r1 = Rules.recordExercise(
			d,
			"ExerciseCasualtyCare",
			"Bronze",
			run("ExerciseCasualtyCare", "Bronze"),
			ME
		)
		t.expect(r1.passed).toBe(true)
		t.expect(r1.firstPass).toBe(true)
		t.expect(r1.reward.cash).toBe(Config.ExerciseReward.cash)
		t.expect(r1.reward.rep).toBe(Config.ExerciseReward.rep)
		t.expect(d.exercises.ExerciseCasualtyCare).toBe("Bronze")
		local r2 = Rules.recordExercise(
			d,
			"ExerciseCasualtyCare",
			"Gold",
			run("ExerciseCasualtyCare", "Gold"),
			ME
		)
		t.expect(r2.firstPass).toBe(false)
		t.expect(r2.reward.rep).toBe(0)
		t.expect(d.exercises.ExerciseCasualtyCare).toBe("Gold")
		Rules.recordExercise(
			d,
			"ExerciseCasualtyCare",
			"Silver",
			run("ExerciseCasualtyCare", "Silver"),
			ME
		)
		t.expect(d.exercises.ExerciseCasualtyCare).toBe("Gold") -- best is kept
	end)

	t.test("a failed run or an NPC step is no pass; the drill cannot fail", function()
		local d = data()
		local fail =
			Rules.recordExercise(d, "ExerciseSwimTest", "Fail", run("ExerciseSwimTest", "Fail"), ME)
		t.expect(fail.passed).toBe(false)
		t.expect(#fail.badges).toBe(0)
		local npc = run("ExerciseSwimTest", "Gold")
		npc[2].userId = nil
		t.expect(Rules.recordExercise(d, "ExerciseSwimTest", "Silver", npc, ME).passed).toBe(false)
		t.expect(Rules.exercisePassed(d, "ExerciseSwimTest")).toBe(false)
		local drill = Rules.recordExercise(
			d,
			"ExerciseReopeningDay",
			"Fail",
			run("ExerciseReopeningDay", "Fail"),
			ME,
			true
		)
		t.expect(drill.passed).toBe(true)
		t.expect(drill.reward.rep).toBe(Config.DrillReward.rep)
		t.expect(d.exercises.ExerciseReopeningDay).toBe("Bronze")
		t.expect(#drill.earned).toBe(0)
	end)

	t.test("Helm: exercise plus 2 operations with the approach at Silver", function()
		local d = data(0)
		local r = Rules.recordOperation(d, "PersonInWater", piw({ approach = "Silver" }), ME)
		t.expect(r.counted[1]).toBe("Helm")
		t.expect(d.certLive.Helm).toBe(1)
		-- Bronze approach, an NPC approach, the cold open's Assist ease: none count
		Rules.recordOperation(d, "PersonInWater", piw({ approach = "Bronze" }), ME)
		Rules.recordOperation(d, "PersonInWater", piw({}), ME)
		local eased = piw({ approach = "Gold" })
		for _, s in eased do
			if s.id == "approach" then
				s.assistEase = true
			end
		end
		Rules.recordOperation(d, "PersonInWater", eased, ME)
		t.expect(d.certLive.Helm).toBe(1)
		t.expect(Rules.certHint(d)).toBe("Helm: pass the exercise at the station")
		-- a tow's alongside step counts too
		local tow = { { id = "alongside", grade = "Gold", userId = ME, mechanicId = "alongside" } }
		Rules.recordOperation(d, "DisabledVessel", tow, ME)
		t.expect(d.certLive.Helm).toBe(2)
		t.expect(Rules.hasCert(d, "Helm")).toBe(false) -- exercise still missing
		local ex = Rules.recordExercise(
			d,
			"ExerciseBoatHandling",
			"Silver",
			run("ExerciseBoatHandling", "Silver"),
			ME
		)
		t.expect(ex.earned[1]).toBe("Helm")
		t.expect(Rules.hasCert(d, "Helm")).toBe(true)
		local certBadge = nil
		for _, b in ex.badges do
			if b.kind == "cert" then
				certBadge = b
			end
		end
		t.expect(certBadge.id).toBe("Cert:Helm")
		t.expect(certBadge.badge).toBe("CertHelm")
	end)

	t.test("Casualty Care needs survey and treatment both at Silver", function()
		local d = data()
		Rules.recordOperation(
			d,
			"PersonInWater",
			piw({ survey = "Gold", treatment = "Bronze" }),
			ME
		)
		t.expect(d.certLive.CasualtyCare).toBeNil()
		local r = Rules.recordOperation(
			d,
			"PersonInWater",
			piw({ survey = "Gold", treatment = "Silver" }),
			ME
		)
		t.expect(d.certLive.CasualtyCare).toBe(1)
		t.expect(r.badges[1].kind).toBe("progress")
		t.expect(r.badges[1].title).toBe("Casualty Care")
		t.expect(string.find(r.badges[1].text, "1 of 2 operations", 1, true) ~= nil).toBe(true)
		Rules.recordOperation(
			d,
			"PersonInWater",
			piw({ survey = "Silver", treatment = "Gold" }),
			ME
		)
		Rules.recordOperation(
			d,
			"PersonInWater",
			piw({ survey = "Silver", treatment = "Gold" }),
			ME
		)
		t.expect(d.certLive.CasualtyCare).toBe(2) -- capped at the count
	end)

	t.test("Rescue Swimmer needs a swimmer recovery and Casualty Care first", function()
		local d = data()
		-- a throw-bag recovery is not a swimmer recovery
		Rules.recordOperation(
			d,
			"PersonInWater",
			piw({ recovery = "Gold" }, "recover_throwbag"),
			ME
		)
		t.expect(d.certLive.RescueSwimmer).toBeNil()
		Rules.recordOperation(
			d,
			"PersonInWater",
			piw({ recovery = "Silver" }, "recover_swimmer"),
			ME
		)
		t.expect(d.certLive.RescueSwimmer).toBe(1)
		Rules.recordExercise(d, "ExerciseSwimTest", "Gold", run("ExerciseSwimTest", "Gold"), ME)
		t.expect(Rules.hasCert(d, "RescueSwimmer")).toBe(false)
		t.expect(Rules.certStatus(d, "RescueSwimmer").missing[1]).toBe("Casualty Care")
		-- earning Casualty Care earns the waiting Rescue Swimmer in the same result
		d.certLive.CasualtyCare = 2
		local r = Rules.recordExercise(
			d,
			"ExerciseCasualtyCare",
			"Silver",
			run("ExerciseCasualtyCare", "Silver"),
			ME
		)
		t.expect(#r.earned).toBe(2)
		t.expect(r.earned[1]).toBe("CasualtyCare")
		t.expect(r.earned[2]).toBe("RescueSwimmer")
		t.expect(d.certLive.RescueSwimmer).toBeNil() -- cleared once earned
	end)

	t.test("promotion waits for the rank's certification", function()
		local d = data(950)
		t.expect(Rules.rankIndexForRep(950)).toBe(3)
		t.expect(Rules.rankIndex(d)).toBe(1)
		t.expect(Rules.certHint(d)).toBe("Pass Helm to be promoted")
		t.expect((Rules.canBuyVehicle({
			cash = 99999,
			rep = 950,
			gear = {},
			vehicles = {},
			certs = {},
			certLive = {},
			exercises = {},
			flags = {},
		}, "RIB"))).toBe(false)
		d.certLive.Helm = 2
		local r = Rules.recordExercise(
			d,
			"ExerciseBoatHandling",
			"Gold",
			run("ExerciseBoatHandling", "Gold"),
			ME
		)
		t.expect(r.rankBefore).toBe(1)
		t.expect(r.rankAfter).toBe(2)
		local promoted = false
		for _, b in r.badges do
			if b.kind == "rank" and b.title == "Promoted to Lifeguard" then
				promoted = true
			end
		end
		t.expect(promoted).toBe(true)
		t.expect(Rules.certHint(d)).toBe("Pass Rescue Swimmer to be promoted")
		local s = Rules.snapshot(d)
		t.expect(s.rankIndex).toBe(2)
		t.expect(s.rankProgress).toBe(1)
		t.expect(s.certs.Helm.earned).toBe(true)
		t.expect(s.certs.CasualtyCare.live).toBe(0)
		t.expect(s.exercises.ExerciseBoatHandling).toBe("Gold")
		d.certs.CasualtyCare = true
		d.certs.RescueSwimmer = true
		t.expect(Rules.rankIndex(d)).toBe(3)
		t.expect(Rules.certHint(d)).toBeNil()
		t.expect((Rules.canBuyVehicle(d, "RIB"))).toBe(false) -- rank met, Cash missing
		d.cash = 4000
		t.expect((Rules.canBuyVehicle(d, "RIB"))).toBe(true)
	end)

	t.test("certifications survive the save; old saves are grandfathered", function()
		local d = data(500)
		d.certs.Helm = true
		d.certLive.CasualtyCare = 1
		d.exercises.ExerciseSwimTest = "Silver"
		local again = Rules.migrate(Rules.migrate(d))
		t.expect(again.certs.Helm).toBe(true)
		t.expect(again.certs.CasualtyCare).toBeNil()
		t.expect(again.certLive.CasualtyCare).toBe(1)
		t.expect(again.exercises.ExerciseSwimTest).toBe("Silver")
		-- junk is dropped
		local junk = Rules.migrate({
			rep = 10,
			certs = { Helm = "yes", Nope = true },
			certLive = { Helm = 99, CasualtyCare = -3 },
			exercises = { ExerciseSwimTest = "Fail", ExerciseCasualtyCare = 5 },
		})
		t.expect(junk.certs.Helm).toBeNil()
		t.expect(junk.certs.Nope).toBeNil()
		t.expect(junk.certLive.Helm).toBe(Config.Certifications.Helm.live.count)
		t.expect(junk.certLive.CasualtyCare).toBeNil()
		t.expect(next(junk.exercises)).toBeNil()
		-- a save from before certifications keeps its rank (prerequisites included)
		local old = Rules.migrate({ rep = 1000, cash = 5 })
		t.expect(old.certs.Helm).toBe(true)
		t.expect(old.certs.RescueSwimmer).toBe(true)
		t.expect(old.certs.CasualtyCare).toBe(true)
		t.expect(Rules.rankIndex(old)).toBe(3)
		local mid = Rules.migrate({ rep = 450 })
		t.expect(mid.certs.Helm).toBe(true)
		t.expect(mid.certs.RescueSwimmer).toBeNil()
		t.expect(next(Rules.migrate({ rep = 0 }).certs)).toBeNil()
		-- a new save with empty certs is not grandfathered
		t.expect(next(Rules.migrate({ rep = 1000, certs = {} }).certs)).toBeNil()
	end)

	t.test(
		"every rank's certification exists and every certification's needs are earlier",
		function()
			for _, rank in Config.Ranks do
				if rank.cert then
					t.expect(Config.Certifications[rank.cert]).toBeTruthy()
				end
			end
			for i, id in Config.CertOrder do
				local cert = Config.Certifications[id]
				t.expect(cert.id).toBe(id)
				t.expect(Exercises.get(cert.exercise)).toBeTruthy()
				for _, need in cert.needs do
					t.expect(table.find(Config.CertOrder, need) < i).toBe(true)
				end
			end
		end
	)
	-- RP-C1b: the exercise board's gate, the HUD's rank gate from a snapshot, the no-tow berth
	t.test(
		"starting an exercise needs the cold open, the prerequisites and no operation",
		function()
			local d = data(0)
			local ok, why = Rules.canStartExercise(d, "ExerciseBoatHandling")
			t.expect(ok).toBe(false)
			t.expect(why).toBe("Finish your first rescue first")
			d.coldOpenDone = true
			t.expect((Rules.canStartExercise(d, "ExerciseBoatHandling"))).toBe(true)
			t.expect((Rules.canStartExercise(d, "ExerciseReopeningDay"))).toBe(true)
			t.expect((Rules.canStartExercise(d, "ExerciseCasualtyCare"))).toBe(true)
			ok, why = Rules.canStartExercise(d, "ExerciseSwimTest")
			t.expect(ok).toBe(false)
			t.expect(why).toBe("Needs Casualty Care")
			d.certs.CasualtyCare = true
			t.expect((Rules.canStartExercise(d, "ExerciseSwimTest"))).toBe(true)
			ok, why = Rules.canStartExercise(d, "ExerciseSwimTest", true)
			t.expect(ok).toBe(false)
			t.expect(why).toBe("Finish the current operation first")
			t.expect((Rules.canStartExercise(d, "PersonInWater"))).toBe(false) -- live calls never start here
			-- repeats are allowed (only the first pass pays)
			d.exercises.ExerciseBoatHandling = "Gold"
			t.expect((Rules.canStartExercise(d, "ExerciseBoatHandling"))).toBe(true)
		end
	)

	t.test("the board lists every exercise with its status, requirement and gate", function()
		local d = data(0)
		d.coldOpenDone = true
		d.exercises.ExerciseCasualtyCare = "Silver"
		local rows = Exercises.board(d)
		t.expect(#rows).toBe(#Exercises.Order)
		local byId = {}
		for i, r in rows do
			t.expect(r.id).toBe(Exercises.Order[i])
			byId[r.id] = r
		end
		t.expect(byId.ExerciseReopeningDay.optional).toBe(true)
		t.expect(byId.ExerciseReopeningDay.status).toBe("Optional")
		t.expect(byId.ExerciseCasualtyCare.status).toBe("Passed: Silver")
		t.expect(byId.ExerciseBoatHandling.status).toBe("Not yet passed")
		t.expect(byId.ExerciseBoatHandling.certification).toBe("Helm")
		t.expect(string.find(byId.ExerciseBoatHandling.requirement, "2 live operations", 1, true))
			.toBeTruthy()
		t.expect(byId.ExerciseSwimTest.canStart).toBe(false)
		t.expect(byId.ExerciseSwimTest.reason).toBe("Needs Casualty Care")
		t.expect(string.find(byId.ExerciseSwimTest.requirement, "Casualty Care held", 1, true))
			.toBeTruthy()
		d.certs.Helm = true
		t.expect(Exercises.board(d)[2].requirement).toBe("Helm certified")
		for _, r in Exercises.board(d, true) do
			t.expect(r.canStart).toBe(false)
		end
	end)

	t.test("a snapshot rebuilds the data the server gates on (HUD boat desk)", function()
		local d = data(1000)
		d.certs = {} -- not grandfathered: Rep without the certifications
		d.exercises.ExerciseBoatHandling = "Gold"
		d.certLive.Helm = 1
		local back = Rules.fromSnapshot(Rules.snapshot(d))
		t.expect(back.rep).toBe(1000)
		t.expect(back.exercises.ExerciseBoatHandling).toBe("Gold")
		t.expect(back.certLive.Helm).toBe(1)
		t.expect(Rules.rankIndex(back)).toBe(Rules.rankIndex(d))
		t.expect(Rules.rankIndex(back)).toBe(1)
		t.expect((Rules.canUseVehicle(back, "RIB"))).toBe(false)
		t.expect(Rules.vehicleLock(back, "RIB")).toBe("Pass Helm")
		t.expect(Rules.vehicleLock(back, "JetSki")).toBeNil()
		d.certs.Helm = true
		back = Rules.fromSnapshot(Rules.snapshot(d))
		t.expect(back.certs.Helm).toBe(true)
		t.expect(Rules.rankIndex(back)).toBe(2)
		t.expect(Rules.vehicleLock(back, "RIB")).toBe("Pass Rescue Swimmer")
		d.certs.RescueSwimmer = true
		d.vehicles.RIB = true
		back = Rules.fromSnapshot(Rules.snapshot(d))
		t.expect(Rules.vehicleLock(back, "RIB")).toBeNil()
		t.expect((Rules.canUseVehicle(back, "RIB"))).toBe(true)
		-- short of the Rep: the rank is named, not the certification
		t.expect(Rules.vehicleLock(Rules.fromSnapshot(Rules.snapshot(data(100))), "RIB"))
			.toBe("Rank: Rescue Swimmer")
		t.expect(Rules.fromSnapshot({}).rep).toBe(0)
	end)

	t.test("the boat-handling exercise berths alone: no tow-line steps", function()
		local Procedures = t.load("src/client/Mechanics/Tow/Procedures.luau")
		local alongside
		for _, s in Exercises.get("ExerciseBoatHandling").def.steps do
			if s.mechanicId == "berth" then
				alongside = s
			end
		end
		t.expect(alongside.noTow).toBe(true)
		for _, s in Operations.Defs.DisabledVessel.steps do
			t.expect(s.noTow).toBeNil() -- the live tow keeps its release
		end
		local m = Procedures.noTowBerthMetrics(1.5, { "bow", "stern", "fwdSpring", "aftSpring" })
		t.expect(m.lineInWater).toBe(0)
		t.expect(m.lineOrderRight).toBe(1)
		t.expect(Grading.stepGrade(alongside, m)).toBe("Gold")
		local wrong = Procedures.noTowBerthMetrics(5, { "stern", "bow", "fwdSpring", "aftSpring" })
		t.expect(wrong.lineOrderRight).toBe(0)
		t.expect(Grading.stepGrade(alongside, wrong) ~= "Gold").toBe(true)
	end)
end
