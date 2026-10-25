-- Kit Theme (WP-23b): viewport scaling, panel fit, the icon bar's columns, price text and the
-- colour-blind buy / close pairs.
return function(t)
	local Theme = t.load("src/client/UI/Kit/Theme.luau")

	t.test("scale is 1 at 1280x720, floors on phones, caps on big screens", function()
		t.expect(Theme.scaleFor(Vector2.new(1280, 720))).toBe(1)
		t.expect(Theme.scaleFor(Vector2.new(390, 844))).toBe(0.7)
		t.expect(Theme.scaleFor(Vector2.new(844, 390))).toBe(0.7)
		t.expect(Theme.scaleFor(Vector2.new(3840, 2160))).toBe(1.6)
		t.expect(Theme.scaleFor(Vector2.new(1920, 1080))).toBe(1.5)
	end)

	t.test("panels keep their design size on desktop and fit inside phones", function()
		local want = Theme.Size.panel
		t.expect(Theme.panelSize(Vector2.new(1280, 720), 1, want)).toEqual(want)
		for _, vp in { Vector2.new(390, 844), Vector2.new(844, 390) } do
			local s = Theme.scaleFor(vp)
			local px = Theme.panelSize(vp, s, want) * s
			t.expect(px.X <= vp.X * 0.94 + 0.01).toBe(true)
			t.expect(px.Y <= vp.Y * 0.9 + 0.01).toBe(true)
		end
		-- portrait grows to most of the height
		local tall = Theme.panelSize(Vector2.new(390, 844), 0.7, want)
		t.expect(tall.Y * 0.7 >= 844 * 0.78).toBe(true)
	end)

	t.test("the icon bar wraps into columns that fit the height", function()
		local cell = Theme.Size.icon + Theme.Size.iconLabel + Theme.Size.iconGap
		t.expect(Theme.iconColumns(Vector2.new(1280, 720), 1, 7)).toBe(2)
		t.expect(Theme.iconColumns(Vector2.new(390, 844), 0.7, 7)).toBe(1)
		for _, vp in { Vector2.new(1280, 720), Vector2.new(390, 844), Vector2.new(844, 390) } do
			local s = Theme.scaleFor(vp)
			local rows = math.ceil(7 / Theme.iconColumns(vp, s, 7))
			t.expect(rows * cell * s <= vp.Y * 0.86).toBe(true)
		end
	end)

	t.test("price text", function()
		t.expect(Theme.short(99)).toBe("99")
		t.expect(Theme.short(1250)).toBe("1,250")
		t.expect(Theme.short(999999 // 100)).toBe("9,999")
		t.expect(Theme.short(12500)).toBe("12.5K")
		t.expect(Theme.short(25000)).toBe("25K")
		t.expect(Theme.short(3400000)).toBe("3.4M")
	end)

	t.test(
		"red-green modes move buy / close off the red-green axis, apart in brightness",
		function()
			for _, mode in { "Default", "Deuteranopia", "Protanopia", "Tritanopia" } do
				local p = Theme.palette(mode)
				t.expect(p.buy ~= nil and p.close ~= nil).toBe(true)
				local lb, lc = Theme.luminance(p.buy.bottom), Theme.luminance(p.close.bottom)
				t.expect(math.abs(lb - lc) > 0.03).toBe(true)
			end
			local d = Theme.palette("Deuteranopia")
			t.expect(d.buy.bottom.B > d.buy.bottom.R).toBe(true)
			t.expect(Theme.palette("Default").buy).toBe(Theme.Grad.buy)
		end
	)
end
