-- Season: the Season Logbook XP, 30-tier track, claim rules (nothing lost before the season end)
-- and the profile flag encoding (docs/15 H8, docs/04 section 3.1).
return function(t)
	local Rules = t.load("src/shared/SeasonRules.luau")
	local Config = t.load("src/shared/Config/Season.luau")

	local START = Config.startUtc
	local END = Config.endUtc
	local MID = START + 10 * 86400

	t.test("Season 1 runs 2026-10-24 00:00 UTC to 2026-12-05 23:59:59 UTC", function()
		t.expect(START).toBe(1792800000)
		t.expect(END).toBe(1796515199)
		t.expect(Rules.live(START - 1)).toBe(false)
		t.expect(Rules.live(START)).toBe(true)
		t.expect(Rules.live(END)).toBe(true)
		t.expect(Rules.live(END + 1)).toBe(false)
	end)

	t.test("the clock counts whole days left", function()
		t.expect(Rules.daysLeft(START)).toBe(43)
		t.expect(Rules.daysLeft(END)).toBe(1)
		t.expect(Rules.daysLeft(END + 1)).toBe(0)
	end)

	t.test("30 tiers whose XP requirements rise", function()
		t.expect(#Config.tiers).toBe(30)
		for i = 2, #Config.tiers do
			t.expect(Config.tiers[i].xp > Config.tiers[i - 1].xp).toBe(true)
		end
		t.expect(Config.tiers[1].xp).toBe(100)
		t.expect(Config.tiers[30].xp).toBe(20400)
	end)

	t.test("tier from XP uses the cumulative thresholds", function()
		t.expect(Rules.tierForXp(0)).toBe(0)
		t.expect(Rules.tierForXp(99)).toBe(0)
		t.expect(Rules.tierForXp(100)).toBe(1)
		t.expect(Rules.tierForXp(1919)).toBe(7)
		t.expect(Rules.tierForXp(1920)).toBe(8)
		t.expect(Rules.tierForXp(999999)).toBe(30)
	end)

	t.test("a rescue pays by grade, plus big, storm and event bonuses", function()
		t.expect(Rules.xpForOperation({ grade = "Gold" })).toBe(120)
		t.expect(Rules.xpForOperation({ grade = "Silver" })).toBe(95)
		t.expect(Rules.xpForOperation({ grade = "Bronze" })).toBe(70)
		t.expect(Rules.xpForOperation({ grade = "Fail" })).toBe(0)
		t.expect(Rules.xpForOperation({ grade = "Takeover" })).toBe(0)
		local big = { grade = "Gold", isBig = true, storm = true, variant = "GhostShip" }
		t.expect(Rules.xpForOperation(big)).toBe(260)
		t.expect(Rules.xpForOperation({ grade = "Gold", variant = "Swimmer" })).toBe(120)
	end)

	t.test("an album sticker pays once per variant", function()
		local s = Rules.newState()
		t.expect(Rules.stickerXp(s, "Swimmer")).toBe(40)
		t.expect(Rules.stickerXp(s, "Swimmer")).toBe(0)
		t.expect(Rules.stickerXp(s, "Kayaker")).toBe(40)
		t.expect(Rules.stickerXp(s, "NotAVariant")).toBe(0)
	end)

	t.test("a claim needs the tier reached, unclaimed and the season live", function()
		local s = Rules.newState()
		s.xp = 100
		t.expect(Rules.claim(s, 2, MID)).toBeNil()
		local reward = Rules.claim(s, 1, MID)
		t.expect(reward.tier).toBe(1)
		t.expect(reward.cash).toBe(150)
		t.expect(Rules.claimed(s, 1)).toBe(true)
		local again, why = Rules.claim(s, 1, MID)
		t.expect(again).toBeNil()
		t.expect(why).toBe("Claimed")
		local late, reason = Rules.claim(s, 1, END + 1)
		t.expect(late).toBeNil()
		t.expect(reason).toBe("Closed")
	end)

	t.test("unclaimed reached tiers stay claimable until the season ends", function()
		local s = Rules.newState()
		s.xp = 5000
		local first = Rules.claim(s, 1, END)
		t.expect(first.tier).toBe(1)
		local mid = Rules.claim(s, 5, END)
		t.expect(mid.tier).toBe(5)
		t.expect(mid.surprise).toBe("Lantern")
		t.expect(Rules.claimed(s, 2)).toBe(false)
	end)

	t.test("tier rewards carry Cash, Rep and the cosmetic flags", function()
		local defs = {}
		for _, def in Config.tiers do
			if def.cosmetic then
				defs[def.cosmetic] = def.tier
			end
		end
		t.expect(defs.Decal_Season1).toBe(3)
		t.expect(defs.Wake_Season1).toBe(8)
		t.expect(defs.Title_Season1).toBe(12)
		t.expect(defs.Livery_Season1).toBe(30)
		t.expect(Config.tiers[30].cash > 0).toBe(true)
	end)

	t.test("the view reports the bar, the ticks, days left and every tier", function()
		local s = Rules.newState()
		s.xp = 2000
		Rules.claim(s, 1, MID)
		local view = Rules.view(s, MID)
		t.expect(view.id).toBe("S1")
		t.expect(view.tier).toBe(8)
		t.expect(view.xp).toBe(2000)
		t.expect(view.xpInto).toBe(2000 - Config.tiers[8].xp)
		t.expect(view.xpSpan).toBe(Config.tiers[9].xp - Config.tiers[8].xp)
		t.expect(view.claimed).toBe(1)
		t.expect(#view.tiers).toBe(30)
		t.expect(view.tiers[8].reached).toBe(true)
		t.expect(view.tiers[9].reached).toBe(false)
		t.expect(view.live).toBe(true)
		t.expect(view.daysLeft > 0).toBe(true)
		t.expect(Rules.view(Rules.newState(), END + 1).live).toBe(false)
	end)

	t.test("the profile flag round-trips, and a new season id starts fresh", function()
		local s = Rules.newState()
		s.xp = 1234
		s.claimed = 5
		s.seen = 9
		local back = Rules.fromFlag(Rules.flagTable(s))
		t.expect(back.id).toBe("S1")
		t.expect(back.xp).toBe(1234)
		t.expect(back.claimed).toBe(5)
		t.expect(back.seen).toBe(9)
		t.expect(Rules.fromFlag({ s = "S0", xp = 999 }).xp).toBe(0)
		t.expect(Rules.fromFlag(nil).xp).toBe(0)
	end)

	t.test("the paid track is data only (id 0, ready false, in MonetizationConfig)", function()
		local Monetization = t.load("src/shared/Config/MonetizationConfig.luau")
		local item = Monetization.Products[Config.paid.product]
		t.expect(item ~= nil).toBe(true)
		t.expect(item.id).toBe(0)
		t.expect(item.ready).toBe(false)
		t.expect(item.price).toBe(Config.paid.price)
	end)
end
