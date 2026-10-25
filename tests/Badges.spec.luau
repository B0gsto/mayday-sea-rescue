-- Badges: BadgeConfig is well formed and BadgeRules turns an operation debrief into badge progress.
return function(t)
	local BadgeConfig = t.require("Config/BadgeConfig")
	local BadgeRules = t.require("BadgeRules")
	local ProgressionConfig = t.require("Config/ProgressionConfig")
	local Wildlife = t.load("src/shared/Config/Wildlife.luau")

	local ME, OTHER = 101, 202
	local function snap(over)
		local s = {
			kind = "PersonInWater",
			grade = "Silver",
			reason = "Complete",
			steps = {
				{ id = "recovery", grade = "Silver", userId = ME },
				{ id = "transport", grade = "Gold", userId = ME },
			},
		}
		for k, v in over or {} do
			s[k] = v
		end
		return s
	end

	t.test("every badge in Order exists, has text and an integer id (0 = off)", function()
		local seen = {}
		for _, key in BadgeConfig.Order do
			local b = BadgeConfig.Badges[key]
			t.expect(b ~= nil).toBe(true)
			t.expect(seen[key]).toBeNil()
			seen[key] = true
			t.expect(math.floor(b.id) == b.id and b.id >= 0).toBe(true)
			t.expect(#b.name > 0 and #b.description > 0).toBe(true)
			t.expect(#b.name <= 50 and #b.description <= 1000).toBe(true)
		end
		for key in BadgeConfig.Badges do
			t.expect(seen[key]).toBe(true)
		end
		t.expect(BadgeConfig.enabled("FirstRescue")).toBe(BadgeConfig.Badges.FirstRescue.id > 0)
		t.expect(BadgeConfig.enabled("Nope")).toBe(false)
	end)

	t.test("rank badges name real ProgressionConfig ranks", function()
		local ids = {}
		for _, r in ProgressionConfig.Ranks do
			ids[r.id] = true
		end
		for _, key in BadgeConfig.Order do
			local rank = BadgeConfig.Badges[key].rank
			if rank then
				t.expect(ids[rank]).toBe(true)
			end
		end
	end)

	t.test(
		"a finished op gives First Rescue, Hundred Rescues and Smooth Ride on a Gold ride home",
		function()
			local p = BadgeRules.opProgress(snap(), ME, true)
			t.expect(p.FirstRescue).toBe(1)
			t.expect(p.Rescue100).toBe(1)
			t.expect(p.SmoothRide).toBe(1)
			local rough = snap({
				steps = {
					{ id = "transport", grade = "Gold", userId = ME },
					{ id = "transport", grade = "Silver", userId = ME },
				},
			})
			t.expect(BadgeRules.opProgress(rough, ME, true).SmoothRide).toBeNil()
		end
	)

	t.test("only the player's own rides count; non-helpers get nothing", function()
		t.expect(BadgeRules.opProgress(snap(), OTHER, true).SmoothRide).toBeNil()
		t.expect(BadgeRules.opProgress(snap(), OTHER, true).FirstRescue).toBe(1)
		t.expect(next(BadgeRules.opProgress(snap(), ME, false))).toBeNil()
	end)

	t.test("ferry badge", function()
		local p = BadgeRules.opProgress(snap(), ME, true)
		t.expect(p.FerryHero).toBeNil()
		local ferry = snap({ kind = "CapsizedFerry", isBig = true, saved = 3 })
		t.expect(BadgeRules.opProgress(ferry, ME, true).FerryHero).toBe(1)
		ferry.saved = 0
		t.expect(BadgeRules.opProgress(ferry, ME, true).FerryHero).toBeNil()
	end)

	t.test("failed, timed-out and taken-over ops give nothing", function()
		for _, over in
			{
				{ reason = "Timer" },
				{ reason = "Takeover", grade = "Takeover" },
				{ grade = "Fail" },
			}
		do
			t.expect(next(BadgeRules.opProgress(snap(over), ME, true))).toBeNil()
		end
	end)

	t.test("apply counts up and reports badges at or past their threshold", function()
		local counters = {}
		t.expect(#BadgeRules.apply(counters, { SmoothRide = 9 })).toBe(0)
		t.expect(counters.SmoothRide).toBe(9)
		t.expect(BadgeRules.apply(counters, { SmoothRide = 1 })).toEqual({ "SmoothRide" })
		-- still due after the threshold (a badge switched on later is awarded then)
		t.expect(BadgeRules.apply(counters, { SmoothRide = 1, FirstRescue = 1 }))
			.toEqual({ "FirstRescue", "SmoothRide" })
		t.expect(counters.SmoothRide).toBe(11)
		t.expect(#BadgeRules.apply(counters, { Unknown = 3 })).toBe(0)
		t.expect(counters.Unknown).toBe(3) -- seen tokens persist, they are just not badges
	end)

	t.test("once counts each token only the first time", function()
		local counters = {}
		for i, species in Wildlife.SpeciesOrder do
			local due = BadgeRules.once(counters, "AllWildlife", species)
			t.expect(due.AllWildlife).toBe(1)
			t.expect(due[`seen:AllWildlife:{species}`]).toBe(1)
			BadgeRules.apply(counters, due)
			t.expect(counters.AllWildlife).toBe(i)
		end
		t.expect(counters.AllWildlife).toBe(5)
		t.expect(BadgeConfig.Badges.AllWildlife.count).toBe(#Wildlife.SpeciesOrder)
		t.expect(BadgeRules.once(counters, "AllWildlife", "Gull")).toEqual({})
	end)

	t.test("Every Call lists every operation kind once", function()
		local seen = {}
		for _, kind in BadgeConfig.OpKinds do
			t.expect(seen[kind]).toBeNil()
			seen[kind] = true
		end
		t.expect(BadgeConfig.Badges.EveryCall.count).toBe(#BadgeConfig.OpKinds)
	end)

	t.test("completed only for a finished, not failed or taken-over op", function()
		t.expect(BadgeRules.completed(snap())).toBe(true)
		t.expect(BadgeRules.completed(snap({ reason = "Timer" }))).toBe(false)
		t.expect(BadgeRules.completed(snap({ grade = "Takeover" }))).toBe(false)
		t.expect(BadgeRules.completed(snap({ grade = "Fail" }))).toBe(false)
	end)

	t.test("new badges are well formed and Admiral is a rank", function()
		for _, key in
			{
				"SmoothRide",
				"Rescue100",
				"FirstWildlife",
				"AllWildlife",
				"FirstPet",
				"Streak7",
				"Streak30",
				"EveryCall",
				"LifeboatBought",
				"RankCoxswain",
				"RankCaptain",
				"RankAdmiral",
				"FriendCrew",
				"FerryHero",
			}
		do
			local b = BadgeConfig.Badges[key]
			t.expect(b).toBeTruthy()
			t.expect(#(b :: any).icon > 0).toBe(true)
		end
		t.expect(BadgeConfig.Badges.RankAdmiral.rank).toBe("Admiral")
	end)

	t.test("rank badges at or below the current rank", function()
		local ids = {}
		for _, r in ProgressionConfig.Ranks do
			table.insert(ids, r.id)
		end
		t.expect(#BadgeRules.rankBadges(1, ids)).toBe(0)
		t.expect(BadgeRules.rankBadges(2, ids)).toEqual({ "RankLifeguard" })
		t.expect(BadgeRules.rankBadges(3, ids)).toEqual({ "RankLifeguard", "RankRescueSwimmer" })
	end)
end
