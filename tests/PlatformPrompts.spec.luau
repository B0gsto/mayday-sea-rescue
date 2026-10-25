-- PlatformPrompts: when Roblox's own re-engagement prompts may be offered (docs/15 fair rules):
-- after the first crate / island building / crew op, never on an op, never in the first 3 minutes, never
-- twice in 10 minutes, and a declined notification opt-in comes back after a week at most.
return function(t)
	local Rules = t.load("src/shared/PlatformPrompts.luau")

	local NOW = 1790000000
	local MIN = Rules.MIN_SESSION
	local GAP = Rules.GAP
	local WEEK = Rules.NOTIFY_RETRY

	local function fresh()
		return Rules.decode(nil)
	end

	t.test("a fresh session is not prompted in its first 3 minutes or on an operation", function()
		local s = fresh()
		for _, kind in Rules.KINDS do
			t.expect(Rules.allowed(kind, s, NOW, 0, false)).toBe(false)
			t.expect(Rules.allowed(kind, s, NOW, MIN - 1, false)).toBe(false)
			t.expect(Rules.allowed(kind, s, NOW, MIN, false)).toBe(true)
			t.expect(Rules.allowed(kind, s, NOW, MIN + 600, true)).toBe(false)
		end
	end)

	t.test("two prompts never land within 10 minutes of each other", function()
		local s = Rules.record(fresh(), "favorite", NOW)
		t.expect(Rules.allowed("invite", s, NOW + GAP - 1, 6000, false)).toBe(false)
		t.expect(Rules.allowed("invite", s, NOW + GAP, 6000, false)).toBe(true)
	end)

	t.test("favourite and invite are offered once ever", function()
		local s = Rules.record(fresh(), "favorite", NOW)
		t.expect(Rules.allowed("favorite", s, NOW + GAP, 6000, false)).toBe(false)
		s = Rules.record(s, "invite", NOW + GAP)
		t.expect(Rules.allowed("invite", s, NOW + 10 * WEEK, 6000, false)).toBe(false)
	end)

	t.test("a declined notification opt-in is re-offered after a week, not before", function()
		local s = Rules.record(fresh(), "notify", NOW)
		t.expect(Rules.allowed("notify", s, NOW + WEEK - 1, 6000, false)).toBe(false)
		t.expect(Rules.allowed("notify", s, NOW + WEEK, 6000, false)).toBe(true)
	end)

	t.test("the profile flag round-trips through the save sanitiser", function()
		local Progression = t.load("src/shared/ProgressionRules.luau")
		local s = Rules.record(Rules.record(fresh(), "notify", NOW), "invite", NOW + GAP)
		local raw = Progression.defaultData()
		raw.flags = { platformPrompts = Rules.encode(s) }
		local saved = Progression.migrate(raw)
		t.expect(saved.flags.platformPrompts).toEqual(Rules.encode(s))
		t.expect(Rules.decode(saved.flags.platformPrompts)).toEqual(s)
	end)

	t.test("junk timestamps and unknown kinds are ignored", function()
		local Day = math.floor(NOW / 86400)
		local s = Rules.decode({ nd = Day, ns = 0, fd = -5, id = 0 / 0, ld = Day, ls = 60.9 })
		t.expect(s).toEqual({
			notify = Day * 86400,
			favorite = nil,
			invite = nil,
			last = Day * 86400 + 60,
		})
		t.expect(Rules.isKind("favorite")).toBe(true)
		t.expect(Rules.isKind("spam")).toBe(false)
	end)
end
