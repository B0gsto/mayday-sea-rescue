-- RP-M5 Wake Trails: the Wake cosmetic styles (src/shared/Config/Cosmetics/Wake.luau) resolved by
-- Boat/Wake.visual. The standard option is the old wake exactly; the paid looks stay realistic and
-- within the mobile particle budget; Night glow only shows at night.
return function(t)
	local Wake = t.load("src/shared/Boat/Wake.luau")
	local Slot = t.load("src/shared/Config/Cosmetics/Wake.luau")
	local Cos = t.load("src/shared/Cosmetics.luau")

	local function option(id: string)
		for _, o in Slot.options do
			if o.id == id then
				return o
			end
		end
		error("no option " .. id)
	end

	t.test("the slot validates: free default, five WakeTrails looks", function()
		local reg = Cos.build({ Slot })
		t.expect(#reg.validate()).toBe(0)
		t.expect(Slot.default).toBe("Standard")
		t.expect(option("Standard").pass).toBe(nil)
		local paid = 0
		for _, o in Slot.options do
			if o.pass then
				t.expect(o.pass).toBe("WakeTrails")
				t.expect(o.stub).toBe(nil)
				paid += 1
			end
		end
		t.expect(paid).toBe(5)
	end)

	t.test("standard (and nil) style is the original wake", function()
		for _, v in { Wake.visual(nil, 0), Wake.visual(option("Standard").style, 1) } do
			t.expect(v.lifetime).toBe(3.5)
			t.expect(v.width).toBe(1)
			t.expect(v.spread).toBe(2.6)
			t.expect(v.widthStart).toBe(1)
			t.expect(math.abs(v.transparency[1] - 0.15) < 1e-9).toBe(true)
			t.expect(math.abs(v.transparency[2] - 0.55) < 1e-9).toBe(true)
			t.expect(v.transparency[3]).toBe(1)
			t.expect(v.hold).toBe(0.4)
			t.expect(v.color:ToHex():upper()).toBe("E8EEEC")
			t.expect(v.lightEmission).toBe(0)
			t.expect(v.lightInfluence).toBe(1)
			t.expect(v.bowRate).toBe(60)
			t.expect(math.abs(v.bowTransparency - 0.35) < 1e-9).toBe(true)
			t.expect(v.bowSize[1]).toBe(0.8)
			t.expect(v.bowSpread[1]).toBe(70)
		end
	end)

	t.test("each paid look changes what it says", function()
		local std = Wake.visual(nil, 0)
		local long = Wake.visual(option("LongWhite").style, 0)
		t.expect(long.lifetime > std.lifetime * 1.5).toBe(true)
		t.expect(long.transparency[1] < std.transparency[1]).toBe(true)
		local fan = Wake.visual(option("WideFan").style, 0)
		t.expect(fan.width > 1.3 and fan.spread > std.spread).toBe(true)
		local churn = Wake.visual(option("DeepChurn").style, 0)
		t.expect(churn.transparency[2] < std.transparency[2] and churn.hold > std.hold).toBe(true)
		local spray = Wake.visual(option("Spray").style, 0)
		t.expect(spray.bowRate > std.bowRate * 1.5 and spray.bowSize[2] < std.bowSize[2]).toBe(true)
	end)

	t.test("night glow: identical by day, faint blue-green emission at night", function()
		local style = option("NightGlow").style
		local day = Wake.visual(style, 0)
		t.expect(day.color:ToHex():upper()).toBe("E8EEEC")
		t.expect(day.lightEmission).toBe(0)
		local night = Wake.visual(style, 1)
		t.expect(night.lightEmission > 0 and night.lightEmission <= 0.5).toBe(true)
		t.expect(night.color.B > night.color.R).toBe(true)
		t.expect(Wake.nightFactor(0.5)).toBe(0)
		t.expect(Wake.nightFactor(-0.3)).toBe(1)
	end)

	t.test("mobile budget: no look keeps over 1.3x the standard spray particles alive", function()
		local budget = Wake.liveParticles(Wake.visual(nil, 0)) * 1.3
		for _, o in Slot.options do
			t.expect(Wake.liveParticles(Wake.visual(o.style, 1)) <= budget).toBe(true)
		end
	end)

	t.test("no reserved signal colours, no saturated tints", function()
		local reserved = { "#FF6600", "#DFFF00", "#FF5A1F", "#FF2A1A", "#3EE07A" }
		for _, o in Slot.options do
			for _, key in { "tint", "glow" } do
				local hex = o.style and o.style[key]
				if hex then
					local c = Color3.fromHex(hex)
					for _, r in reserved do
						local rc = Color3.fromHex(r)
						local d = math.abs(c.R - rc.R) + math.abs(c.G - rc.G) + math.abs(c.B - rc.B)
						t.expect(d > 0.3).toBe(true)
					end
					local _, s = c:ToHSV()
					t.expect(s < 0.7).toBe(true)
				end
			end
		end
	end)

	t.test("bad style values are clamped, not trusted", function()
		local v = Wake.visual({ length = 100, opacity = -5, bowRate = 50, tint = "nope" }, 0)
		t.expect(v.lifetime <= 3.5 * 2.5).toBe(true)
		t.expect(v.transparency[1] < 1).toBe(true)
		t.expect(v.bowRate <= 60 * 2.5).toBe(true)
		t.expect(v.color:ToHex():upper()).toBe("E8EEEC")
	end)
end
