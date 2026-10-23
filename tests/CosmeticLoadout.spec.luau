-- G28 earned cosmetic loadout (shared/CosmeticLoadout): profile flags -> earned keys, the newest
-- earned option per slot (auto-equip) and the bay decor list, plus the "CosOwned" wire format.
return function(t)
	local Loadout = t.load("src/shared/CosmeticLoadout.luau")
	local Cosmetics = t.load("src/shared/Cosmetics.luau")
	local Season = t.load("src/shared/Config/Season.luau")

	local function claimed(...)
		local bits = 0
		for _, tier in { ... } do
			bits = bit32.bor(bits, bit32.lshift(1, tier - 1))
		end
		return bits
	end

	t.test("no flags: nothing owned, nothing shown", function()
		for _, flags in { nil, {}, { stock = 7, season = "x", halloween = {} } } do
			local owned = Loadout.owned(flags)
			t.expect(next(owned)).toBeNil()
			local show = Loadout.show(flags)
			t.expect(next(show.newest)).toBeNil()
			t.expect(#show.decor).toBe(0)
		end
	end)

	t.test("Chandlery trims map to their earned keys", function()
		local owned = Loadout.owned({
			stock = {
				paint_red = true,
				paint_gold = true,
				wake_turquoise = true,
				lightbar_amber = true,
				decor_lantern = true,
				decor_signals = true,
				not_a_stock_key = true,
			},
		})
		t.expect(owned["stock:paint_red"]).toBe(true)
		t.expect(owned["stock:paint_gold"]).toBe(true)
		t.expect(owned["stock:wake_turquoise"]).toBe(true)
		t.expect(owned["stock:lightbar_amber"]).toBe(true)
		t.expect(owned["stock:decor_lantern"]).toBe(true)
		t.expect(owned["stock:decor_signals"]).toBe(true)
		t.expect(owned["stock:not_a_stock_key"]).toBe(true) -- harmless: no option uses it
		t.expect(owned["stock:paint_teal"]).toBeNil()
	end)

	t.test("season rewards come from the claimed-tier bitfield", function()
		local flags = { season = { s = "S1", xp = 4000, c = claimed(3, 8, 12, 30), v = 0 } }
		local owned = Loadout.owned(flags)
		t.expect(owned["season:Decal_Season1"]).toBe(true)
		t.expect(owned["season:Wake_Season1"]).toBe(true)
		t.expect(owned["season:Title_Season1"]).toBe(true)
		t.expect(owned["season:Livery_Season1"]).toBe(true)
		local show = Loadout.show(flags)
		t.expect(show.newest.Decal.id).toBe("Season1")
		t.expect(show.newest.Wake.id).toBe("Season1")
		t.expect(show.newest.Title.id).toBe("Season1")
		t.expect(show.newest.Livery.id).toBe("Season1")
		t.expect(#show.decor).toBe(0)
	end)

	t.test("unclaimed tiers earn nothing", function()
		local owned = Loadout.owned({ season = { c = claimed(2, 7) } })
		t.expect(next(owned)).toBeNil()
	end)

	t.test("the monthly livery is an earned key; a saved event flag (cut) earns nothing", function()
		local flags =
			{ monthlyLivery = "2026-10", halloween = { candy = 10, livery = true, decor = true } }
		local owned = Loadout.owned(flags)
		t.expect(owned["monthly:2026-10"]).toBe(true)
		t.expect(owned["halloween:livery"]).toBeNil()
		local show = Loadout.show(flags)
		t.expect(show.newest.Livery.id).toBe("Month2026-10")
		t.expect(#show.decor).toBe(0)
		local config = Cosmetics.option("Livery", "Month2026-10")
		t.expect(config ~= nil).toBe(true)
		t.expect(config.earn).toBe("monthly:2026-10")
	end)

	t.test("the newest earn wins per slot and decor keeps the fixed slot order", function()
		local flags = {
			stock = {
				decor_flag = true,
				decor_lantern = true,
				paint_red = true,
				paint_teal = true,
				wake_turquoise = true,
				wake_gold = true,
			},
			monthlyLivery = "2026-11",
		}
		local show = Loadout.show(flags)
		t.expect(show.newest.Livery.id).toBe("Month2026-11")
		t.expect(show.newest.Wake.id).toBe("StockGold")
		t.expect(show.decor[1]).toBe("stock:decor_lantern")
		t.expect(show.decor[2]).toBe("stock:decor_flag")
		t.expect(show.newest.Decal).toBeNil()
		t.expect(show.newest.Title).toBeNil()
	end)

	t.test("every real earned option names a flag key and uses that key's slot", function()
		local slots = 0
		for _, slot in Cosmetics.slots() do
			local options = Cosmetics.slot(slot).options
			for _, option in options do
				if option.earn then
					slots += 1
					t.expect(type(option.earn)).toBe("string")
					local flags = {}
					if string.sub(option.earn, 1, 6) == "stock:" then
						flags.stock = { [string.sub(option.earn, 7)] = true }
					elseif string.sub(option.earn, 1, 7) == "season:" then
						for _, tier in Season.tiers do
							if tier.cosmetic and "season:" .. tier.cosmetic == option.earn then
								flags.season = { c = claimed(tier.tier) }
							end
						end
					elseif string.sub(option.earn, 1, 8) == "monthly:" then
						flags.monthlyLivery = string.sub(option.earn, 9)
					end
					local show = Loadout.show(flags)
					t.expect(show.newest[slot] ~= nil).toBe(true)
					t.expect(show.newest[slot].id).toBe(option.id)
				end
			end
		end
		t.expect(slots >= 21).toBe(true) -- 13 stock + 4 season + 12 monthly + event livery / decor
	end)

	t.test("the Crew group flag owns the bay pennant", function()
		local owned = Loadout.owned({ group = { c = true, m = false, g = 123 } })
		t.expect(owned["group:crew"]).toBe(true)
		local show = Loadout.show({ group = { c = true, m = false, g = 123 } })
		t.expect(show.decor[#show.decor]).toBe("group:crew")
		t.expect(next(Loadout.owned({ group = { c = false, m = true, g = 123 } }))).toBeNil()
	end)

	t.test("CosOwned encodes and decodes a stable newline list", function()
		local set = { ["stock:paint_red"] = true, ["season:Title_Season1"] = true, ["no"] = false }
		local raw = Loadout.encode(set)
		t.expect(raw).toBe("season:Title_Season1\nstock:paint_red")
		local back = Loadout.decode(raw)
		t.expect(back["stock:paint_red"]).toBe(true)
		t.expect(back["season:Title_Season1"]).toBe(true)
		t.expect(next(Loadout.decode(nil))).toBeNil()
		t.expect(next(Loadout.decode(""))).toBeNil()
	end)
end
