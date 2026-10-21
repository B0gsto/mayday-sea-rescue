-- Car art layout (I2b): which uploaded land-vehicle body belongs to which vehicle and where its
-- authored pivot sits on the Builder chassis root (wheel hubs must land on the raycast wheel centres).
return function(t)
	local P = t.load("src/shared/Car/ArtLayout.luau")
	local Config = t.load("src/shared/Config/LandVehicleConfig.luau")

	t.test("vehicle id -> uploaded asset, trailers picked by boat", function()
		t.expect(P.assetFor("LifeguardPickup")).toBe("M_Veh_LifeguardPickup")
		t.expect(P.assetFor("CoastguardResponse")).toBe("M_Veh_Coastguard4x4")
		t.expect(P.assetFor("BeachATV")).toBe("M_Veh_ATV")
		t.expect(P.assetFor("Ambulance")).toBe("M_Veh_Ambulance")
		t.expect(P.assetFor("BoatTrailer", "RIB")).toBe("M_Veh_BoatTrailer_RIB")
		t.expect(P.assetFor("BoatTrailer", "JetSki")).toBe("M_Veh_BoatTrailer_JetSki")
		t.expect(P.assetFor("BoatTrailer")).toBe("M_Veh_BoatTrailer_RIB")
		t.expect(P.assetFor("RIB")).toBeNil()
	end)

	t.test("art wheel token -> Builder wheel part", function()
		t.expect(P.wheelPart("FL", false)).toBe("FL")
		t.expect(P.wheelPart("RR", false)).toBe("RR")
		t.expect(P.wheelPart("FL", true)).toBe("T1L")
		t.expect(P.wheelPart("L1", true)).toBe("T1L")
		t.expect(P.wheelPart("R2", true)).toBe("T2R")
		t.expect(P.wheelPart("Console", false)).toBeNil()
	end)

	t.test("origin puts the art wheel hubs on the raycast wheel centres", function()
		local pickup = P.origin(Config.LifeguardPickup, {
			ATT_Wheel_FL = Vector3.new(-2.31, 1.1622, -5.51),
		})
		t.expect(pickup.X).toBeCloseTo(0, 1e-6)
		t.expect(pickup.Y).toBeCloseTo(-2.3922, 1e-4)
		t.expect(pickup.Z).toBeCloseTo(1.53035, 1e-4)

		local response = P.origin(Config.CoastguardResponse, {
			ATT_Wheel_FL = Vector3.new(-2.229, 1.17, -4.91),
		})
		t.expect(response.Y).toBeCloseTo(-2.64, 1e-4)
		t.expect(response.Z).toBeCloseTo(0.719, 1e-4)

		local atv = P.origin(Config.BeachATV, {
			ATT_Wheel_FL = Vector3.new(-1.42, 0.995, -5.8481),
		})
		t.expect(atv.Y).toBeCloseTo(-2.015, 1e-4)
		t.expect(atv.Z).toBeCloseTo(3.7196, 1e-4)

		local trailer = P.origin(Config.BoatTrailer, {
			ATT_Wheel_FL = Vector3.new(-2.85, 0.975, 0.3775),
		})
		t.expect(trailer.Y).toBeCloseTo(-2.535, 1e-4)
		t.expect(trailer.Z).toBeCloseTo(-0.6685, 1e-4)
	end)

	t.test("no wheel marker falls back to the drive attachment", function()
		local at = P.origin(Config.LifeguardPickup, {
			ATT_DriveAttachment = Vector3.new(0, 2.3922, -1.5303),
		})
		t.expect(at.Y).toBeCloseTo(-2.3922, 1e-4)
		t.expect(at.Z).toBeCloseTo(1.5303, 1e-4)
		t.expect(P.origin(Config.LifeguardPickup, {}).Magnitude).toBe(0)
	end)
end
