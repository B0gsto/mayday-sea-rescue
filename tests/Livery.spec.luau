-- RP-M5 E1 vehicle liveries (shared/LiveryPaint + Config/Cosmetics/Livery): the real options and
-- their passes, part-name -> paint role mapping for the uploaded RIB / jet ski meshes, the greybox
-- "Paint" attribute roles, the signal-colour clearance (docs/05 3.2) and the wet darkening.
return function(t)
	local P = t.load("src/shared/LiveryPaint.luau")
	local Pattern = t.load("src/shared/LiveryPattern.luau")
	local config = t.load("src/shared/Config/Cosmetics/Livery.luau")
	local Cos = t.load("src/shared/Cosmetics.luau")

	local function opt(id: string)
		for _, o in config.options do
			if o.id == id then
				return o
			end
		end
		return nil
	end

	t.test("options: stock default plus three paid liveries on the right passes", function()
		t.expect(config.default).toBe("Standard")
		t.expect(opt("Standard").pass).toBeNil()
		t.expect(P.paints(opt("Standard"))).toBe(false)
		t.expect(opt("VipGold").pass).toBe("VipCrewCard")
		t.expect(opt("StormChaser").pass).toBe("StormChaserLiveries")
		t.expect(opt("StationOrange").pass).toBe("StarterKit")
		for _, o in config.options do
			t.expect(o.stub).toBeNil()
		end
		t.expect(#Cos.validate()).toBe(0)
	end)

	t.test(
		"every livery colour is clear of the reserved signal colours and in albedo range",
		function()
			local problems = P.validate(config)
			t.expect(#problems).toBe(0)
			t.expect(P.signalClash(Color3.fromRGB(255, 102, 0))).toBe("HullOrange")
			t.expect(P.signalClash(Color3.fromRGB(214, 217, 220))).toBe("RetroSilver")
			local bad = P.validate({
				options = {
					{
						id = "Bad",
						primary = Color3.fromRGB(250, 95, 20),
						secondary = Color3.fromRGB(5, 5, 5),
						stripe = Color3.fromRGB(26, 38, 72),
					},
				},
			})
			t.expect(#bad >= 2).toBe(true)
		end
	)

	t.test("mesh names map to texture sets and roles", function()
		local r = P.meshRule("M_Veh_RIB_Tubes_LOD0")
		t.expect(r and r.role).toBe("primary")
		t.expect(P.setKey("M_Veh_RIB_Tubes_LOD0")).toBe("M_Veh_RIB/Hull")
		t.expect(P.meshRule("M_Veh_RIB_Hull").role).toBe("secondary")
		t.expect(P.setKey("M_Veh_RIB_Decals_LOD0")).toBe("M_Veh_RIB/Decals")
		t.expect(P.meshRule("M_Veh_RIB_Engines_LOD0")).toBeNil()
		t.expect(P.meshRule("M_Veh_JetSki_Hull_LOD0").role).toBe("primary")
		t.expect(P.setKey("M_Veh_JetSki_Decals_LOD0")).toBe("M_Veh_JetSki/Hull")
		t.expect(P.meshRule("M_Veh_JetSki_Seat_LOD0")).toBeNil()
		t.expect(P.meshRule("Bonnet")).toBeNil()
		t.expect(P.meshRule("M_Veh_RIB_AFrame_LOD0").role).toBe("trim")
		t.expect(P.setKey("M_Veh_RIB_Helm_Console_LOD0")).toBe("M_Veh_RIB_Helm/Console")
		t.expect(P.meshRule("M_Veh_RIB_Helm_Seats_LOD0")).toBeNil()
		t.expect(P.setKey("M_Veh_JetSki_Sled_LOD0")).toBe("M_Veh_JetSki/Sled")
		t.expect(P.meshRule("M_Veh_JetSki_CloseUp_Console_LOD0")).toBeNil()
		t.expect(P.meshRule("M_Veh_LifeguardPickup_Body_LOD0").role).toBe("primary")
		t.expect(P.setKey("M_Veh_LifeguardPickup_BodyDetail_LOD0"))
			.toBe("M_Veh_LifeguardPickup/Body")
		t.expect(P.meshRule("M_Veh_LifeguardPickup_Wheel_FL_LOD0")).toBeNil()
		t.expect(P.meshRule("M_Veh_Coastguard4x4_Body_LOD0").role).toBe("primary")
		t.expect(P.setKey("M_Veh_Coastguard4x4_BodyDetail_LOD0")).toBe("M_Veh_Coastguard4x4/Body")
		t.expect(P.meshRule("M_Veh_ATV_Fenders_LOD0").role).toBe("primary")
		t.expect(P.meshRule("M_Veh_ATV_Sled_LOD0")).toBeNil()
		t.expect(P.colorFor(opt("StationOrange"), "trim")).toBeNil()
	end)

	t.test("greybox Paint attributes and colour fallbacks", function()
		t.expect(P.attrRole("Body")).toBe("primary")
		t.expect(P.attrRole("Stripe1")).toBe("stripe")
		t.expect(P.attrRole("Stripe2")).toBe("stripe2")
		t.expect(P.attrRole(nil)).toBeNil()
		t.expect(P.attrRole(3)).toBeNil()
		local o =
			{ id = "X", primary = Color3.new(0.5, 0.5, 0.5), secondary = Color3.new(0.2, 0.2, 0.2) }
		t.expect(P.colorFor(o, "stripe2")).toBe(o.secondary)
		t.expect(P.colorFor(nil, "primary")).toBeNil()
		t.expect(P.colorFor(opt("VipGold"), "primary")).toBe(opt("VipGold").primary)
	end)

	t.test("G38: every painting livery names a known trim pattern", function()
		for _, o in config.options do
			if P.paints(o) then
				t.expect(Pattern.known(o.pattern)).toBe(true)
			end
		end
		t.expect(opt("Season1").pattern).toBe("chevron")
		t.expect(opt("Month2026-10").pattern).toBe("stripes")
		t.expect(opt("Halloween").pattern).toBe("glow")
		t.expect(opt("Halloween").earn).toBe("halloween:livery")
	end)

	t.test("G38: two-tone contrast is strong (primary vs secondary vs stripe)", function()
		for _, o in config.options do
			if P.paints(o) then
				local function dist(a: Color3, b: Color3): number
					return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B)
				end
				t.expect(dist(o.primary, o.secondary) > 0.35).toBe(true)
				t.expect(dist(o.stripe, o.primary) > 0.25).toBe(true)
			end
		end
	end)

	t.test("wet paint is darker by the wet factor; skipped vehicles", function()
		local c = P.wet(Color3.new(1, 0.5, 0))
		t.expect(math.abs(c.R - P.WET_FACTOR) < 1e-6).toBe(true)
		t.expect(math.abs(c.G - 0.5 * P.WET_FACTOR) < 1e-6).toBe(true)
		t.expect(P.SKIP_VEHICLES.BoatTrailer).toBe(true)
		t.expect(P.SKIP_VEHICLES.LifeguardPickup).toBeNil()
	end)
end
