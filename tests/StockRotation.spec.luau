-- StockRotation: the shared 10-minute Chandlery restock clock (docs/15 H3): deterministic windows,
-- 6-8 unique items by rarity weight, the `7:42` clock text, and a Rare/Epic item sometimes on the shelf.
return function(t)
	local Rotation = t.load("src/shared/StockRotation.luau")
	local Config = t.load("src/shared/Config/StockConfig.luau")

	local BASE = 1790000400 -- 2026-09-21, mid-morning UTC, on a 10-minute boundary
	local PERIOD = Config.Period

	local function ids(now: number): { string }
		local out = {}
		for _, slot in Rotation.roll(now) do
			table.insert(out, slot.item.id)
		end
		return out
	end

	t.test("the window is UTC and restocks on the 10-minute boundary", function()
		t.expect(PERIOD).toBe(600)
		t.expect(Rotation.windowIndex(BASE)).toBe(math.floor(BASE / PERIOD))
		t.expect(Rotation.windowStart(BASE)).toBe(math.floor(BASE / PERIOD) * PERIOD)
		t.expect(Rotation.windowIndex(BASE + PERIOD - 1)).toBe(Rotation.windowIndex(BASE))
		t.expect(Rotation.secondsToRestock(BASE)).toBe(PERIOD - BASE % PERIOD)
		t.expect(Rotation.windowIndex(BASE + Rotation.secondsToRestock(BASE)))
			.toBe(Rotation.windowIndex(BASE) + 1)
	end)

	t.test("the clock text is `7:42` style", function()
		t.expect(Rotation.formatTime(462)).toBe("7:42")
		t.expect(Rotation.formatTime(600)).toBe("10:00")
		t.expect(Rotation.formatTime(59.2)).toBe("1:00")
		t.expect(Rotation.formatTime(1)).toBe("0:01")
		t.expect(Rotation.formatTime(0)).toBe("0:00")
		t.expect(Rotation.formatTime(-3)).toBe("0:00")
	end)

	t.test("every server rolls the same stock for the same UTC second", function()
		local a = ids(BASE)
		t.expect(ids(BASE + 599)).toEqual(a)
		t.expect(ids(BASE - 599)).toEqual(ids(BASE - PERIOD))
		t.expect(table.concat(ids(BASE + PERIOD), ",") ~= table.concat(a, ",")).toBe(true)
		t.expect(ids(BASE + PERIOD + 300)).toEqual(ids(BASE + PERIOD))
	end)

	t.test("a restock has 6-8 unique items with rarity stock counts", function()
		for w = 0, 300 do
			local slots = Rotation.roll(BASE + w * PERIOD)
			t.expect(#slots >= Config.SlotMin and #slots <= Config.SlotMax).toBe(true)
			local seen = {}
			for _, slot in slots do
				t.expect(seen[slot.item.id]).toBeNil()
				seen[slot.item.id] = true
				t.expect(slot.count).toBe(Config.CountByRarity[slot.item.rarity])
				t.expect(slot.item.price > 0).toBe(true)
				t.expect(slot.item.limit >= 1).toBe(true)
				t.expect(slot.item.gear or slot.item.cosmetic or slot.item.treat).toBeTruthy()
			end
		end
	end)

	t.test("the pool mixes gear, trims and decor", function()
		local kinds = { Gear = 0, Trim = 0, Decor = 0, Treat = 0 }
		local rarities = { Common = 0, Uncommon = 0, Rare = 0, Epic = 0 }
		local rareWindows = 0
		for w = 0, 1000 do
			local slots = Rotation.roll(BASE + w * PERIOD)
			local hasRare = false
			for _, slot in slots do
				kinds[slot.item.kind] += 1
				rarities[slot.item.rarity] += 1
				if slot.item.rarity == "Rare" or slot.item.rarity == "Epic" then
					hasRare = true
				end
			end
			if hasRare then
				rareWindows += 1
			end
		end
		for _, n in kinds do
			t.expect(n > 0).toBe(true)
		end
		t.expect(rarities.Common > rarities.Rare).toBe(true)
		t.expect(rarities.Rare > rarities.Epic).toBe(true)
		-- "sometimes": not every shelf, not never
		t.expect(rareWindows > 100).toBe(true)
		t.expect(rareWindows < 900).toBe(true)
	end)
end
