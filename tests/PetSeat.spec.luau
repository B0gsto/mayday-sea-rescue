-- PetSeat: real-world pet scale and the per-craft riding seat (G83).
return function(t)
	local PetSeat = t.load("src/shared/PetSeat.luau")
	local Wildlife = t.load("src/shared/Config/Wildlife.luau")

	t.test("every species is sized to real life", function()
		for _, species in Wildlife.SpeciesOrder do
			local size = PetSeat.Sizes[species]
			t.expect(size).toBeTruthy()
			if size then
				local drawn = size.built * PetSeat.scaleFor(species)
				t.expect(drawn).toBeCloseTo(size.metres * PetSeat.STUDS_PER_METRE, 2)
				t.expect(PetSeat.scaleFor(species) < 1).toBe(true)
			end
		end
		t.expect(PetSeat.scaleFor("Puffin") * 2.55).toBeCloseTo(0.9, 2)
		t.expect(PetSeat.scaleFor("Otter") * 5.08).toBeCloseTo(3.0, 2)
		t.expect(PetSeat.scaleFor("Unknown")).toBe(1)
	end)

	t.test("each craft gets an out-of-the-way seat", function()
		local slots = { Vector3.new(0, 0.31, 7.4) }
		local jet = PetSeat.builderPoint("JetSki", slots)
		t.expect(jet).toBeTruthy()
		t.expect((jet :: Vector3).Z > slots[1].Z).toBe(true) -- behind the rider, on the sled
		local rib = PetSeat.builderPoint("RIB", slots) :: Vector3
		t.expect(rib.Z > 5).toBe(true) -- aft deck, behind the crew
		t.expect(rib.X > 0).toBe(true)
		local lifeboat = PetSeat.builderPoint("Lifeboat", slots) :: Vector3
		t.expect(lifeboat.Z < -10).toBe(true) -- foredeck, ahead of the wheelhouse
		t.expect(PetSeat.builderPoint("Kayak", slots)).toBeNil()
	end)

	t.test("a land vehicle carries the pet on the rear of its roof", function()
		local seat = PetSeat.landSeat(Vector3.new(6, 6, 16))
		t.expect(seat.Position.Y).toBe(3 + PetSeat.LAND_LIFT) -- clear of the rack kit
		t.expect(seat.Position.Z).toBeCloseTo(1.6, 1e-6) -- mid-roof, a little aft
		t.expect(seat.Position.X).toBe(0)
	end)

	t.test("the client prefers the built seat, then a fallback anchor", function()
		local name, offset, yaw = PetSeat.choose("RIB", function(anchor)
			return anchor == "PetSeat"
		end)
		t.expect(name).toBe("PetSeat")
		t.expect(offset).toBe(Vector3.zero)
		t.expect(yaw).toBe(0)

		name, offset, yaw = PetSeat.choose("JetSki", function(anchor)
			return anchor == "SurvivorSlot1"
		end)
		t.expect(name).toBe("SurvivorSlot1")
		t.expect(offset).toBe(PetSeat.Seats.JetSki.offset)
		t.expect(yaw).toBe(math.pi) -- looks back at the rider

		name = PetSeat.choose("Unknown", function()
			return false
		end)
		t.expect(name).toBe("BowPoint")
	end)
end
