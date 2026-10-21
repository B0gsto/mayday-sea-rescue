-- RescueAlbum: the variant rarities and storm gating, and the album's stickers, set completion
-- (one payout per kind), flag encoding and view (docs/15 H2).
return function(t)
	local V = t.load("src/shared/Config/RescueVariants.luau")
	local A = t.load("src/shared/RescueAlbum.luau")
	local W = t.load("src/shared/Config/Wildlife.luau")

	local function kindIds(kind)
		local out = {}
		for _, variant in V.Kinds[kind] do
			table.insert(out, variant.id)
		end
		return out
	end

	t.test("every call kind has variants, PersonInWater has the Legendary", function()
		t.expect(#V.KindOrder).toBe(7)
		for _, kind in V.KindOrder do
			local list = V.Kinds[kind]
			t.expect(#list >= 2 and #list <= 12).toBe(true)
			for _, variant in list do
				t.expect(variant.kind).toBe(kind)
				t.expect(V.Rarity[variant.rarity] ~= nil).toBe(true)
				t.expect(V.ById(variant.id)).toBeTruthy()
			end
		end
		t.expect(#V.Kinds.PersonInWater).toBe(12)
		t.expect(V.ById("GoldenGull").rarity).toBe("Legendary")
		local legendaries = 0
		for _, variant in V.Kinds.PersonInWater do
			if variant.rarity == "Legendary" then
				legendaries += 1
			end
		end
		t.expect(legendaries).toBe(1)
		t.expect(#V.Kinds.WildlifeRescue).toBe(10)
		for _, species in W.SpeciesOrder do
			t.expect(V.get("WildlifeRescue", `Wildlife_{species}`) ~= nil).toBe(true)
			t.expect(V.get("WildlifeRescue", `Wildlife_{species}_Rare`).rarity).toBe("Rare")
		end
	end)

	t.test("Common and Uncommon always; Epic and Legendary only in the Great Storm", function()
		local first = V.choose("PersonInWater", 0, false)
		t.expect(first.id).toBe("Swimmer")
		local seenRare = 0
		for i = 0, 1999 do
			local variant = V.choose("PersonInWater", i / 2000, false)
			t.expect(variant.rarity == "Epic" or variant.rarity == "Legendary").toBe(false)
			if variant.rarity == "Rare" then
				seenRare += 1
			end
		end
		-- a tiny base rate, not zero and not a regular caller
		t.expect(seenRare > 0).toBe(true)
		t.expect(seenRare < 100).toBe(true)
		-- the storm is what can roll an Epic (yacht, pirate ship) or the one Legendary
		local function seenRarity(kind: string, rarity: string, great: boolean): boolean
			for i = 0, 999 do
				if V.choose(kind, i / 1000, great).rarity == rarity then
					return true
				end
			end
			return false
		end
		t.expect(seenRarity("PersonInWater", "Legendary", false)).toBe(false)
		t.expect(seenRarity("PersonInWater", "Legendary", true)).toBe(true)
		t.expect(seenRarity("DisabledVessel", "Epic", false)).toBe(false)
		t.expect(seenRarity("DisabledVessel", "Epic", true)).toBe(true)
	end)

	t.test("seasonal variants roll only inside their window", function()
		local seen = {}
		for i = 0, 999 do
			local variant = V.choose("PersonInWater", i / 1000, true)
			seen[variant.id] = true
			t.expect(variant.season).toBeNil()
		end
		t.expect(seen.SkeletonSwimmer).toBeNil()
		t.expect(seen.SantaSwimmer).toBeNil()
		t.expect(V.choose("PersonInWater", 0.9999, true, nil, "Halloween").id)
			.toBe("SkeletonSwimmer")
		t.expect(V.choose("PersonInWater", 0.9999, true, nil, "Winter").id).toBe("SantaSwimmer")
	end)

	t.test("a forced variant wins only inside its own kind", function()
		t.expect(V.choose("PersonInWater", 0, false, "GoldenGull").id).toBe("GoldenGull")
		t.expect(V.choose("DisabledVessel", 0, false, "GoldenGull").id).toBe("FishingBoat")
		t.expect(V.choose("PersonInWater", 0, false, "Nope").id).toBe("Swimmer")
		t.expect(V.get("PersonInWater", "GoldenGull") ~= nil).toBe(true)
		t.expect(V.get("DisabledVessel", "GoldenGull")).toBeNil()
	end)

	t.test("a rescued variant records once and completes its set once", function()
		local state = A.newState()
		local ids = kindIds("PersonInWater")
		for i, id in ids do
			local fresh, setKind = A.record(state, id)
			t.expect(fresh).toBe(true)
			if i < #ids then
				t.expect(setKind).toBeNil()
			else
				t.expect(setKind).toBe("PersonInWater")
			end
		end
		t.expect(A.has(state, "GoldenGull")).toBe(true)
		local owned, total = A.setProgress(state, "PersonInWater")
		t.expect(owned).toBe(#ids)
		t.expect(total).toBe(#ids)
		-- duplicates and a second pass pay nothing
		local fresh, setKind = A.record(state, "GoldenGull")
		t.expect(fresh).toBe(false)
		t.expect(setKind).toBeNil()
		local junkFresh, junkSet = A.record(state, "NotAVariant")
		t.expect(junkFresh).toBe(false)
		t.expect(junkSet).toBeNil()
		local none, zero = A.setProgress(state, "Nope")
		t.expect(none).toBe(0)
		t.expect(zero).toBe(0)
		-- an incomplete set does not pay
		t.expect(state.paid.DisabledVessel).toBeNil()
	end)

	t.test("the flag encoding round-trips and drops junk", function()
		local state = A.newState()
		A.record(state, "Swimmer")
		A.record(state, "GoldenGull")
		for _, id in kindIds("RipCurrent") do
			A.record(state, id)
		end
		local raw = A.flagTable(state)
		raw.junk = 1
		raw.bogus = "x"
		local again = A.fromFlagTable(raw)
		t.expect(A.has(again, "Swimmer")).toBe(true)
		t.expect(A.has(again, "GoldenGull")).toBe(true)
		t.expect(again.paid.RipCurrent).toBe(true)
		t.expect(A.has(again, "junk")).toBe(false)
		t.expect(A.fromFlagTable(nil).owned).toEqual({})
	end)

	t.test("the view has one row per call kind with the total stickers", function()
		local state = A.newState()
		A.record(state, "Swimmer")
		A.record(state, "Kayaker")
		local view = A.view(state)
		t.expect(#view.rows).toBe(7)
		t.expect(view.rows[1].kind).toBe("PersonInWater")
		t.expect(view.rows[1].owned).toBe(2)
		t.expect(view.rows[1].total).toBe(12)
		t.expect(view.owned).toBe(2)
		t.expect(view.total).toBe(41)
		t.expect(view.rows[1].variants[1].owned).toBe(true)
		t.expect(view.rows[1].variants[1].label).toBe("Swimmer")
		t.expect(view.rows[1].variants[1].rarity).toBe("Common")
		t.expect(view.rows[2].variants[1].owned).toBe(false)
	end)

	t.test("a completed set pays positive Cash, once", function()
		for _, kind in V.KindOrder do
			t.expect((V.SetCash[kind] or 0) > 0).toBe(true)
		end
	end)
end
