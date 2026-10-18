-- Badges: BadgeConfig is well formed and BadgeRules turns an operation debrief into badge progress.
return function(t)
	local BadgeConfig = t.require("Config/BadgeConfig")
	local BadgeRules = t.require("BadgeRules")
	local ProgressionConfig = t.require("Config/ProgressionConfig")

	local ME, OTHER = 101, 202
	local function snap(over)
		local s = {
			kind = "PersonInWater",
			isBig = false,
			grade = "Silver",
			reason = "Complete",
			storm = false,
			saved = 1,
			towParted = false,
			steps = {
				{ id = "approach", grade = "Gold", userId = ME },
				{ id = "recover_swimmer", grade = "Silver", userId = ME },
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

	t.test("a finished op gives First Rescue and a Gold approach towards Downwind", function()
		local p = BadgeRules.opProgress(snap(), ME, true)
		t.expect(p.FirstRescue).toBe(1)
		t.expect(p.Downwind).toBe(1)
		t.expect(p.StormChaser).toBeNil()
		t.expect(p.TowTruck).toBeNil()
	end)

	t.test("only the player's own step grades count; non-helpers get nothing", function()
		t.expect(BadgeRules.opProgress(snap(), OTHER, true).Downwind).toBeNil()
		t.expect(BadgeRules.opProgress(snap(), OTHER, true).FirstRescue).toBe(1)
		t.expect(next(BadgeRules.opProgress(snap(), ME, false))).toBeNil()
	end)

	t.test(
		"failed, timed-out and taken-over ops keep step credit but not completion badges",
		function()
			for _, over in
				{
					{ reason = "Timer" },
					{ reason = "Takeover", grade = "Takeover" },
					{ grade = "Fail" },
				}
			do
				local p = BadgeRules.opProgress(snap(over), ME, true)
				t.expect(p.FirstRescue).toBeNil()
				t.expect(p.Downwind).toBe(1)
			end
		end
	)

	t.test("storm, tow and ferry badges", function()
		t.expect(BadgeRules.opProgress(snap({ storm = true }), ME, true).StormChaser).toBe(1)
		t.expect(BadgeRules.opProgress(snap({ kind = "DisabledVessel" }), ME, true).TowTruck)
			.toBe(1)
		t.expect(
			BadgeRules.opProgress(snap({ kind = "DisabledVessel", towParted = true }), ME, true).TowTruck
		).toBeNil()
		local ferry = snap({
			kind = "CapsizedFerry",
			isBig = true,
			steps = { { id = "air_pocket", grade = "Bronze", userId = ME } },
		})
		local p = BadgeRules.opProgress(ferry, ME, true)
		t.expect(p.FerryHero).toBe(1)
		t.expect(p.AirPocket).toBe(1)
		t.expect(
			BadgeRules.opProgress(
				snap({ kind = "CapsizedFerry", isBig = true, saved = 0 }),
				ME,
				true
			).FerryHero
		).toBeNil()
		local failedPocket =
			snap({ steps = { { id = "air_pocket", grade = "Fail", userId = ME } } })
		t.expect(BadgeRules.opProgress(failedPocket, ME, true).AirPocket).toBeNil()
	end)

	t.test("apply counts up and reports badges at or past their threshold", function()
		local counters = {}
		t.expect(#BadgeRules.apply(counters, { Downwind = 9 })).toBe(0)
		t.expect(counters.Downwind).toBe(9)
		t.expect(BadgeRules.apply(counters, { Downwind = 1 })).toEqual({ "Downwind" })
		-- still due after the threshold (a badge switched on later is awarded then)
		t.expect(BadgeRules.apply(counters, { Downwind = 1, FirstRescue = 1 }))
			.toEqual({ "FirstRescue", "Downwind" })
		t.expect(counters.Downwind).toBe(11)
		t.expect(#BadgeRules.apply(counters, { Unknown = 3 })).toBe(0)
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
