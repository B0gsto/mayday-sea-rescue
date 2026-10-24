-- Discovery: the exploration album rules (sighted, reached, stickers once each, page completion), save
-- migration, and the fog bitset (docs/21 §3, package B2).
return function(t)
	local Rules = t.require("DiscoveryRules")
	local WorldConfig = t.require("Config/WorldConfig")
	local ProgressionRules = t.require("ProgressionRules")

	local skerry = Rules.ById.SkerryIsle

	t.test("every island has a page, a stamp first and valid sticker points", function()
		t.expect(#Rules.Pages).toBe(#WorldConfig.Islands)
		for _, page in Rules.Pages do
			t.expect(page.stickers[1].kind).toBe("Stamp")
			t.expect(#page.stickers >= 2).toBe(true)
			for _, s in page.stickers do
				t.expect(typeof(s.point)).toBe("Vector3")
			end
		end
	end)

	t.test(
		"far away finds nothing; near the island sights it, from a boat it is not reached",
		function()
			local s, ev = Rules.scan({}, Vector3.new(0, 0, 400), false)
			t.expect(#ev).toBe(0)
			t.expect(next(s)).toBeNil()
			s, ev = Rules.scan(
				{},
				skerry.island.center + Vector3.new(skerry.island.radius + 100, 0, 0),
				false
			)
			t.expect(#ev).toBe(1)
			t.expect(ev[1].step).toBe("Sighted")
			t.expect(Rules.has(s, "SkerryIsle", Rules.REACHED)).toBe(false)
			s, ev = Rules.scan(s, skerry.island.landing, false)
			t.expect(Rules.has(s, "SkerryIsle", Rules.REACHED)).toBe(false)
			s, ev = Rules.scan(s, skerry.island.landing, true)
			t.expect(ev[1].step).toBe("Reached")
		end
	)

	t.test(
		"the stamp post stamps once; each sticker is granted once; the last completes the page",
		function()
			local s, ev = Rules.scan({}, skerry.island.stamp + Vector3.new(3, 0, 0), true)
			local stamped = 0
			for _, e in ev do
				if e.step == "Sticker" and e.sticker.kind == "Stamp" then
					stamped += 1
				end
			end
			t.expect(stamped).toBe(1)
			t.expect(Rules.stamps(s)).toBe(1)
			local _, again = Rules.scan(s, skerry.island.stamp, true)
			t.expect(#again).toBe(0)
			local last = nil
			for _, sticker in skerry.stickers do
				local found
				s, found = Rules.scan(s, sticker.point, true)
				for _, e in found do
					if e.step == "Sticker" then
						last = e
					end
				end
			end
			t.expect(Rules.complete(s, "SkerryIsle")).toBe(true)
			t.expect(last.page).toBe(true)
			local n, total = Rules.count(s, "SkerryIsle")
			t.expect(n).toBe(total)
			t.expect(Rules.cosmetics(s)["isle:SkerryIsle"]).toBe(true)
		end
	)

	t.test("a sticker just out of reach is not granted", function()
		local bottle = skerry.stickers[2]
		local _, ev = Rules.scan({ SkerryIsle = 3 }, bottle.point + Vector3.new(0, 0, 9), true)
		t.expect(#ev).toBe(0)
	end)

	t.test("decode keeps known islands and bits only, and survives the save sanitiser", function()
		t.expect(next(Rules.decode(nil))).toBeNil()
		t.expect(next(Rules.decode("junk"))).toBeNil()
		local s = Rules.decode({
			SkerryIsle = 2 ^ 20 + 5,
			Atlantis = 7,
			Penwyn = "x",
			PuffinIsle = 0 / 0,
		})
		t.expect(s).toEqual({ SkerryIsle = 5 })
		local raw = ProgressionRules.defaultData()
		raw.flags = { isles = Rules.encode({ SkerryIsle = 63, Penwyn = 5 }) }
		local saved = ProgressionRules.migrate(raw)
		t.expect(Rules.decode(saved.flags.isles)).toEqual({ SkerryIsle = 63, Penwyn = 5 })
	end)

	t.test("fog clears around the player and round-trips through the save", function()
		local fog = Rules.newFog()
		local here = Rules.cellOf(Vector3.new(0, 0, 0))
		t.expect(Rules.revealed(fog, here)).toBe(false)
		t.expect(Rules.reveal(fog, Vector3.new(0, 0, 0))).toBe(true)
		t.expect(Rules.reveal(fog, Vector3.new(0, 0, 0))).toBe(false)
		t.expect(Rules.revealed(fog, here)).toBe(true)
		t.expect(Rules.revealed(fog, Rules.cellOf(Vector3.new(2000, 0, 0)))).toBe(false)
		t.expect(Rules.cellOf(Vector3.new(9000, 0, 0))).toBeNil()
		Rules.reveal(fog, Vector3.new(7100, 0, 7100)) -- the far corner
		local raw = ProgressionRules.defaultData()
		raw.flags = { fog = Rules.encodeFog(fog) }
		local back = Rules.decodeFog(ProgressionRules.migrate(raw).flags.fog)
		t.expect(buffer.tostring(back)).toBe(buffer.tostring(fog))
		t.expect(buffer.tostring(Rules.decodeFog({ f1 = 42 })))
			.toBe(buffer.tostring(Rules.newFog()))
	end)
end
