-- RankCeremony: the promotion beat's pure presentation data (rank colour, stripes, unlock icon
-- kinds, camera skip rule, beat length).
return function(t)
	local Ceremony = t.load("src/shared/RankCeremony.luau")
	local Config = t.load("src/shared/Config/ProgressionConfig.luau")

	t.test("every rank has a colour and at most 8 insignia stripes", function()
		for i, rank in Config.Ranks do
			local colour = Ceremony.colour(i)
			t.expect(colour.R + colour.G + colour.B > 0).toBe(true)
			t.expect(Ceremony.stripes(i)).toBe(i)
			local _, spaces = rank.displayName:gsub(" ", "")
			t.expect(spaces <= 1).toBe(true)
		end
		t.expect(Ceremony.stripes(12)).toBe(8)
		t.expect(Ceremony.stripes(0)).toBe(1)
	end)

	t.test("unlock icons come from the rank's config rows", function()
		t.expect(Ceremony.unlockKind("Jet Ski")).toBe("boat")
		t.expect(Ceremony.unlockKind("Lifeboat")).toBe("boat")
		t.expect(Ceremony.unlockKind("Gear level 3")).toBe("gear")
		t.expect(Ceremony.unlockKind("Gold livery")).toBe("gear")
		t.expect(Ceremony.unlockKind("Open Sea")).toBe("mission")
		t.expect(Ceremony.unlockKind("Helm")).toBe("medal")
		t.expect(Ceremony.unlockIcons(1)).toEqual({ "boat", "medal", "mission" })
		t.expect(Ceremony.unlockIcons(4)).toEqual({ "boat", "mission", "gear", "medal" })
	end)

	t.test("a fast boat skips the camera orbit", function()
		t.expect(Ceremony.orbitNeeded(0)).toBe(true)
		t.expect(Ceremony.orbitNeeded(23.9)).toBe(true)
		t.expect(Ceremony.orbitNeeded(Ceremony.FastSpeed)).toBe(false)
		t.expect(Ceremony.orbitNeeded(40)).toBe(false)
		t.expect(Ceremony.seconds("rank")).toBe(8.2)
		t.expect(Ceremony.seconds("star")).toBe(4.6)
	end)
end
