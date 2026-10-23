-- Lifeboat: the all-weather lifeboat's spec and the rank gate.
return function(t)
	local Buoyancy = t.load("src/shared/Boat/Buoyancy.luau")
	local Config = t.load("src/shared/Config/VehicleConfig.luau")
	local Progression = t.load("src/shared/Config/ProgressionConfig.luau")

	local G = 29.43
	local KNOT = 1.543

	-- Vertical heave only, as tests/Boat.spec.luau does: mean float-point depth at rest.
	local function settle(spec, waterAt, seconds)
		local mass = spec.massHint
		local n = #spec.floatPoints
		local y, vy = 5, 0
		local dt = 1 / 240
		local sum, count = 0, 0
		for step = 1, math.floor(seconds / dt) do
			local force = -mass * G
			local mean = 0
			for _, p in spec.floatPoints do
				force += Buoyancy.pointForce(
					waterAt(step * dt) - (y + p.Y),
					vy,
					spec.draft,
					mass,
					G,
					n,
					0,
					spec.dampingRatio
				)
				mean += (waterAt(step * dt) - (y + p.Y)) / n
			end
			vy += force / mass * dt
			y += vy * dt
			if step * dt > seconds - 2 then
				sum += mean
				count += 1
			end
		end
		return sum / count
	end

	t.test("the lifeboat is a real 17 m all-weather boat, not the RIB", function()
		local boat = Config.get("Lifeboat")
		t.expect(boat).toBeTruthy()
		t.expect(Config.Order[#Config.Order]).toBe("Lifeboat")
		t.expect(boat.hullSize.Z / 3).toBeCloseTo(17.3, 0.9)
		t.expect(boat.hullSize.X / 3).toBeCloseTo(5.9, 0.4)
		t.expect(boat.massHint * 37).toBeCloseTo(41000, 2000)
		t.expect(boat.topSpeed < Config.RIB.topSpeed).toBeTruthy() -- slower than the RIB
		t.expect(boat.massHint > Config.RIB.massHint * 10).toBeTruthy() -- 41 t against 2.1 t
		t.expect(boat.seats).toBe(4)
		t.expect(boat.survivorCapacity).toBe(8)
		t.expect(boat.canCapsize).toBe(false) -- self-righting
		t.expect(boat.ejectOnCapsize).toBe(false)
		t.expect(boat.canTow).toBe(true)
		t.expect(boat.draft).toBeCloseTo(4.5, 0.01) -- 1.5 m
		t.expect(boat.topSpeed / KNOT > 20 and boat.topSpeed / KNOT < 32).toBeTruthy()
		-- the hull floats at its displacement (block coefficient of the collision box)
		local cb = boat.massHint / (boat.hullSize.X * boat.hullSize.Z * boat.draft)
		t.expect(cb > 0.12 and cb < 0.75).toBeTruthy()
	end)

	t.test("she floats at her draft in calm and holds her course in a storm", function()
		local boat = Config.get("Lifeboat")
		local calm = settle(boat, function()
			return 0
		end, 8)
		t.expect(calm).toBeCloseTo(boat.draft, 0.05)
		local Waves = t.load("src/shared/Waves.luau")
		local storm = Waves.paramsFor(1, 0, 0.7)
		local rough = settle(boat, function(time)
			return Waves.heightAt(10, 20, time, storm)
		end, 10)
		t.expect(rough > 0).toBeTruthy()
		t.expect(rough < boat.draft * Buoyancy.DEPTH_RANGE).toBeTruthy()
		-- steadier than the RIB: more keel grip, heavier damping, less lean
		t.expect(boat.lateralGrip > Config.RIB.lateralGrip).toBeTruthy()
		t.expect(boat.dampingRatio > Config.RIB.dampingRatio).toBeTruthy()
		t.expect(boat.leanFactor < Config.RIB.leanFactor).toBeTruthy()
	end)

	t.test("the lifeboat is rank-gated", function()
		local cert = Progression.Certifications.Coxswain
		t.expect(cert).toBeTruthy()
		t.expect(cert.exercise).toBe("ExerciseCoxswain")
		t.expect(table.find(Progression.CertOrder, "Coxswain")).toBeTruthy()
		-- the lifeboat is rank-gated data: Coxswain, 12,000 Cash
		local unlock = Progression.Vehicles.Lifeboat
		t.expect(unlock.rankIndex).toBe(4)
		t.expect(unlock.price).toBe(12000)
		t.expect(Progression.isLandVehicle("Lifeboat")).toBe(false)
	end)
end
