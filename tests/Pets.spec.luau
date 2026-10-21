-- Pets: the sanctuary recovery clock, adopting, the profile flag encoding and the deterministic
-- rare-variant roll (docs/15 section 2, hook H4).
return function(t)
	local Rules = t.load("src/shared/PetRules.luau")
	local Wildlife = t.load("src/shared/Config/Wildlife.luau")

	local NOW = 1790000000 -- 2026-09-21, mid-morning UTC
	local RECOVERY = Wildlife.RecoverySeconds

	t.test("10 real minutes of recovery, nothing lost while away", function()
		t.expect(RECOVERY).toBe(600)
		t.expect(Wildlife.MaxPets).toBe(6)
	end)

	t.test("a new sanctuary is empty", function()
		local state = Rules.newState()
		t.expect(#state.entries).toBe(0)
		t.expect(state.active).toBeNil()
		t.expect(#Rules.view(state, NOW).pets).toBe(0)
	end)

	t.test("one rescued animal: encode, decode and the heart meter", function()
		local state, entry = Rules.add(Rules.newState(), "SealPup", true, NOW)
		t.expect(entry).toBeTruthy()
		local added = entry :: any
		t.expect(added.id).toBe(1)
		t.expect(added.at).toBe(NOW)
		t.expect(Rules.progress(added, NOW)).toBe(0)
		t.expect(Rules.progress(added, NOW + RECOVERY / 2)).toBeCloseTo(0.5, 2)
		t.expect(Rules.ready(added, NOW + RECOVERY - 1)).toBe(false)
		t.expect(Rules.ready(added, NOW + RECOVERY)).toBe(true)
		t.expect(Rules.remaining(added, NOW + 10)).toBe(RECOVERY - 10)

		local flag = Rules.encode(state)
		for _, value in flag do
			local kind = type(value)
			t.expect(kind == "number" or kind == "string").toBe(true)
		end
		local back = Rules.decode(flag)
		t.expect(#back.entries).toBe(1)
		t.expect(back.entries[1].species).toBe("SealPup")
		t.expect(back.entries[1].rare).toBe(true)
		t.expect(back.entries[1].at).toBe(NOW)
		t.expect(Rules.view(back, NOW).pets[1].label).toBe("Golden Seal")
	end)

	t.test("the sanctuary fills to six; a seventh animal is not taken in", function()
		local state = Rules.newState()
		for i = 1, Wildlife.MaxPets do
			local species = Wildlife.SpeciesOrder[(i - 1) % #Wildlife.SpeciesOrder + 1]
			local nextState, entry = Rules.add(state, species, false, NOW + i)
			t.expect(entry).toBeTruthy()
			state = nextState
		end
		t.expect(#state.entries).toBe(Wildlife.MaxPets)
		local same, overflow = Rules.add(state, "Gull", false, NOW + 100)
		t.expect(overflow).toBeNil()
		t.expect(#same.entries).toBe(Wildlife.MaxPets)
	end)

	t.test("adopt one at a time; the others stay in the sanctuary", function()
		local state = Rules.newState()
		local first, firstEntry = Rules.add(state, "Otter", false, NOW - RECOVERY)
		t.expect(firstEntry).toBeTruthy()
		state = first
		local second, secondEntry = Rules.add(state, "Puffin", true, NOW - RECOVERY)
		t.expect(secondEntry).toBeTruthy()
		state = second

		t.expect(Rules.canEquip(state, 1, NOW)).toBe(true) -- landed a full recovery ago
		t.expect(Rules.canEquip(Rules.newState(), 1, NOW)).toBe(false)
		local equipped, ok = Rules.equip(state, 2)
		t.expect(ok).toBe(true)
		t.expect(equipped.active).toBe(2)
		t.expect(Rules.activeEntry(equipped) ~= nil).toBe(true)

		local back = Rules.decode(Rules.encode(equipped))
		t.expect(back.active).toBe(2)
		t.expect(Rules.view(back, NOW).pets[2].active).toBe(true)
		t.expect(Rules.view(back, NOW).pets[1].active).toBe(false)
	end)

	t.test("a still-recovering animal cannot be adopted", function()
		local state = Rules.add(Rules.newState(), "Turtle", false, NOW)
		local ok, reason = Rules.canEquip(state, 1, NOW + 5)
		t.expect(ok).toBe(false)
		t.expect(reason).toBe("Still recovering")
	end)

	t.test("the roll is stable per call and brings all five species", function()
		local seen = {}
		local rares = 0
		for i = 1, 4000 do
			local species, rare = Rules.roll(`O{i}`)
			seen[species] = true
			if rare then
				rares += 1
			end
		end
		for _, id in Wildlife.SpeciesOrder do
			t.expect(seen[id]).toBe(true)
		end
		t.expect(rares > 350 and rares < 650).toBe(true) -- about 1 in 8

		local a, b = Rules.roll("O42")
		local c, d = Rules.roll("O42")
		t.expect(a).toBe(c)
		t.expect(b).toBe(d)
	end)

	t.test("the rare colour variants have their own names and calls", function()
		t.expect(Wildlife.label("Puffin", true)).toBe("Albino Puffin")
		t.expect(Wildlife.label("Gull", false)).toBe("Gull")
		t.expect(Wildlife.callLine("SealPup", true))
			.toBe("Golden seal pup tangled in a net near the harbour.")
		for _, id in Wildlife.SpeciesOrder do
			local spec = Wildlife.Species[id]
			t.expect(spec.rareLabel ~= spec.label).toBe(true)
			t.expect(#spec.parts > 5).toBe(true)
			t.expect(spec.verb == "Cut" or spec.verb == "Wipe" or spec.verb == "Free").toBe(true)
		end
	end)

	t.test("corrupt flags fall back to an empty sanctuary", function()
		local state = Rules.decode({ n = "x", a = 99, p1 = "Nope|0|12", p2 = 5 })
		t.expect(#state.entries).toBe(0)
		t.expect(state.active).toBeNil()
	end)

	t.test("a fish treat fills one bond pip and a full bond unlocks the vest", function()
		local state = Rules.newState()
		state, _ = Rules.add(state, "Otter", false, NOW - RECOVERY)
		state, _ = Rules.add(state, "SealPup", false, NOW - RECOVERY)
		state = Rules.equip(state, 1)
		local _, hungry = Rules.giveTreat(state, 1)
		t.expect(hungry).toBe(false)
		state = Rules.addTreats(state, Rules.TREAT_MAX)
		for pip = 1, Rules.BOND_MAX do
			local fed, ok = Rules.giveTreat(state, 1)
			t.expect(ok).toBe(true)
			state = fed
			t.expect(Rules.get(state, 1).bond).toBe(pip)
		end
		t.expect(Rules.accessory(Rules.get(state, 1))).toBe(Rules.ACCESSORY)
		local _, full = Rules.giveTreat(state, 1)
		t.expect(full).toBe(false)
		t.expect(Rules.treats(state)).toBe(Rules.TREAT_MAX - Rules.BOND_MAX)
		t.expect(Rules.get(state, 1).adopted).toBe(true)
		t.expect(Rules.get(state, 2).bond).toBe(0)
	end)

	t.test("treats and bond survive the flag round-trip; old saves still load", function()
		local state = Rules.add(Rules.newState(), "Turtle", true, NOW)
		state = Rules.equip(state, 1)
		state = Rules.addTreats(state, 3)
		local fed = Rules.giveTreat(state, 1)
		local flag = Rules.encode(fed)
		t.expect(flag.t).toBe(2)
		local back = Rules.decode(flag)
		t.expect(back.treats).toBe(2)
		t.expect(back.entries[1].bond).toBe(1)
		t.expect(back.entries[1].adopted).toBe(true)
		t.expect(Rules.view(back, NOW).pets[1].bond).toBe(1)
		local old = Rules.decode({ n = 2, a = 1, p1 = "Gull|0|1700000000" })
		t.expect(old.entries[1].bond).toBe(0)
		t.expect(old.entries[1].adopted).toBe(false)
		t.expect(old.treats).toBe(0)
	end)

	t.test("giving needs the pet with you and a treat in the pocket", function()
		local state = Rules.add(Rules.newState(), "SealPup", false, NOW - RECOVERY)
		state = Rules.add(state, "Gull", false, NOW - RECOVERY)
		state = Rules.equip(state, 1)
		local _, ok, reason = Rules.giveTreat(state, 1)
		t.expect(ok).toBe(false)
		t.expect(reason).toBe("No treats")
		state = Rules.addTreats(state, 1)
		local _, other, otherReason = Rules.giveTreat(state, 2)
		t.expect(other).toBe(false)
		t.expect(otherReason).toBe("Not with you")
		state = Rules.addTreats(state, Rules.TREAT_MAX * 2)
		t.expect(Rules.treats(state)).toBe(Rules.TREAT_MAX) -- capped flat flag
	end)

	t.test(
		"trick triggers: rescue and crate celebrate, spawn greets, driving sits at the bow",
		function()
			t.expect(Rules.trickFor("RescueDone")).toBe("Celebrate")
			t.expect(Rules.trickFor("CrateOpen")).toBe("Celebrate")
			t.expect(Rules.trickFor("Spawn")).toBe("Greet")
			t.expect(Rules.trickFor("Drive")).toBe("Bow")
			t.expect(Rules.trickFor("Unknown")).toBeNil()
			t.expect(Rules.napDue(29, true)).toBe(false)
			t.expect(Rules.napDue(Rules.NAP_SECONDS, true)).toBe(true)
			t.expect(Rules.napDue(120, false)).toBe(false)
		end
	)
end
