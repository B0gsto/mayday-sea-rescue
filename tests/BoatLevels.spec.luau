-- BoatLevels: the ladder's shape, the save floors, and the physical limit: the real Buoyancy forces, stepped the way
-- Boat/Simulator steps them (forces held per 60 Hz frame, 240 Hz integration), on every level's hull.
return function(t)
	local L = t.load("src/shared/BoatLevels.luau")
	local Buoyancy = t.load("src/shared/Boat/Buoyancy.luau")
	local Waves = t.load("src/shared/Waves.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local G = 29.43
	local T0 = 1760000000.25

	-- A rigid hull at full throttle, optionally on a hard turn. Returns how it held up.
	local function drive(spec, storm: number, steer: number, seconds: number, steerFrom: number?)
		local params = Waves.paramsFor(storm, 0, 0)
		local mass = spec.massHint
		local ix, iy, iz = Buoyancy.boxInertia(mass, spec.hullSize)
		local n = #spec.floatPoints
		local cf = CFrame.new(0, 0, 0)
		local vel, omega = Vector3.zero, Vector3.zero
		local wakeSpeed, force, torque = 0, Vector3.zero, Vector3.zero
		local out = {
			t95 = nil,
			top = 0,
			air = 0,
			frames = 0,
			maxTilt = 0,
			maxRise = 0,
			meanContact = 0,
			radius = nil,
			nan = false,
		}
		local yawSum, speedSum, turnFrames = 0, 0, 0
		local frameDt = 1 / 60
		for frame = 1, math.floor(seconds * 60) do
			local now = T0 + frame * frameDt
			local forward = Buoyancy.flatForward(cf.LookVector)
			local forwardSpeed = vel:Dot(forward)
			wakeSpeed += (forwardSpeed - wakeSpeed) * math.min(1, frameDt / Buoyancy.WAKE_LAG)
			local catchUp, wakePush = Buoyancy.wakeCatchUp(wakeSpeed, forwardSpeed, spec)
			local trim = Buoyancy.trimTarget(forwardSpeed, 1, spec, 1, catchUp)
			local lean = Buoyancy.leanTarget(forwardSpeed, omega.Y, spec, G)
			local planeLift = spec.planingLift * Buoyancy.planingFraction(forwardSpeed, spec, 1)
			local contact, slam = 0, 0
			local lift, liftTorque = Vector3.zero, Vector3.zero
			for _, p in spec.floatPoints do
				local world = cf:PointToWorldSpace(p)
				local arm = world - cf.Position
				local depth = Waves.heightAt(world.X, world.Z, now, params) - world.Y
				local vy = (vel + omega:Cross(arm)).Y
				local offset = Buoyancy.liftOffset(p, spec.draft, planeLift, trim, lean)
				local fy, wet, hit = Buoyancy.pointForce(
					depth,
					vy,
					spec.draft,
					mass,
					G,
					n,
					offset,
					spec.dampingRatio
				)
				lift += Vector3.new(0, fy, 0)
				liftTorque += arm:Cross(Vector3.new(0, fy, 0))
				contact += wet / n
				slam += hit / n
			end
			local grip = Buoyancy.grip(contact, 1)
			local pitchRate = omega:Dot(cf.RightVector)
			local added = Buoyancy.addedResistance(pitchRate, slam)
			local thrust = Buoyancy.thrust(1, forwardSpeed, mass, spec, grip, 1, false, true)
			local drag = Buoyancy.drag(vel, forward, mass, spec, grip, 1, added)
			force = lift + drag + forward * (thrust + mass * wakePush * grip)
			local yaw = Buoyancy.steerTorque(
				if frame * frameDt >= (steerFrom or 0) then steer else 0,
				forwardSpeed,
				omega.Y,
				iy,
				spec,
				grip,
				1,
				1,
				G
			)
			local right = Buoyancy.rightOf(forward)
			local flat = CFrame.fromMatrix(Vector3.zero, right, Vector3.yAxis, -forward)
			local up = (flat * CFrame.Angles(trim, 0, -lean)).UpVector
			torque = liftTorque
				+ Buoyancy.uprightTorque(cf.UpVector, omega, math.max(ix, iz), up, grip)
				+ Vector3.new(0, yaw, 0)
			for _ = 1, 4 do
				local dt = frameDt / 4
				vel += (force / mass + Vector3.new(0, -G, 0)) * dt
				local local_ = cf:VectorToObjectSpace(torque)
				omega += cf:VectorToWorldSpace(
					Vector3.new(local_.X / ix, local_.Y / iy, local_.Z / iz)
				) * dt
				local angle = omega.Magnitude * dt
				local rot = if angle > 1e-9
					then CFrame.fromAxisAngle(omega.Unit, angle)
					else CFrame.identity
				cf = (rot * cf.Rotation) + cf.Position + vel * dt
			end
			local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
			out.top = math.max(out.top, speed)
			if not out.t95 and speed >= spec.topSpeed * 0.95 then
				out.t95 = frame * frameDt
			end
			out.frames += 1
			out.meanContact += contact
			if contact <= 0 then
				out.air += 1
			end
			out.maxTilt =
				math.max(out.maxTilt, math.deg(math.acos(math.clamp(cf.UpVector.Y, -1, 1))))
			out.maxRise = math.max(out.maxRise, cf.Position.Y)
			if frame * frameDt > seconds - 3 and speed > 0 then
				yawSum += math.abs(omega.Y)
				speedSum += speed
				turnFrames += 1
			end
			if cf.Position ~= cf.Position or vel ~= vel then
				out.nan = true
				break
			end
		end
		out.meanContact /= math.max(out.frames, 1)
		out.airShare = out.air / math.max(out.frames, 1)
		out.radius = if yawSum > 0 then (speedSum / turnFrames) / (yawSum / turnFrames) else nil
		out.turnSpeed = if turnFrames > 0 then speedSum / turnFrames else 0
		return out
	end

	local function hullFor(row)
		return VehicleConfig.get(row.hull)
	end

	-- docs/30: every level's hull, calm and storm. Held = it reaches its top, stays on the water in a calm sea, never
	-- tips past a boat's lean, and stays turnable from flat out. This is what set SPEED_LIMIT.
	t.test("the physics holds the whole table", function()
		print(
			"\nBoatLevels: lvl speed | calm t95 top air% tilt | storm top air% tilt | hard turn R, speed held"
		)
		for _, level in { 1, 5, 10, 20, 30, 40, 50 } do
			local row = L.row(level)
			local spec = L.apply(hullFor(row), level)
			local calm = drive(spec, 0, 0, 14)
			local storm = drive(spec, 1, 0, 14)
			local turn = drive(spec, 0, 1, 14, 9) -- flat out for 9 s, then hard over
			print(
				string.format(
					"  L%-2d %4d | %4.1fs %5.0f %3.0f%% %3.0f | %5.0f %3.0f%% %3.0f | %4.0f %4.0f",
					level,
					row.speed,
					calm.t95 or -1,
					calm.top,
					calm.airShare * 100,
					calm.maxTilt,
					storm.top,
					storm.airShare * 100,
					storm.maxTilt,
					turn.radius or -1,
					turn.turnSpeed
				)
			)
			t.expect(calm.nan or storm.nan or turn.nan).toBe(false)
			t.expect(calm.top >= row.speed * 0.95).toBe(true)
			t.expect(storm.top >= row.speed * 0.9).toBe(true)
			t.expect((calm.t95 or 99) <= 9).toBe(true)
			t.expect(calm.maxTilt <= 25).toBe(true)
			t.expect(storm.maxTilt <= 40).toBe(true)
			t.expect(turn.radius <= row.turnRadius * 1.1).toBe(true)
		end
		t.expect(L.row(50).speed <= L.SPEED_LIMIT).toBe(true)
	end)

	-- docs/29 C: the pick-up boost goes past the level's top, L50 included (Simulator applies it past capMultiplier)
	t.test("the physics holds a pick-up boost on the top level", function()
		local Run = t.load("src/shared/RescueRun.luau")
		local spec = table.clone(L.apply(hullFor(L.row(50)), 50))
		spec.topSpeed *= Run.BOOST_MULT
		local calm, storm = drive(spec, 0, 0, 14), drive(spec, 1, 0, 14)
		t.expect(calm.nan or storm.nan).toBe(false)
		t.expect(calm.maxTilt <= 25).toBe(true)
		t.expect(storm.maxTilt <= 40).toBe(true)
		t.expect(L.row(50).speed * Run.BOOST_MULT > L.SPEED_LIMIT).toBe(true)
	end)

	t.test("playable: inside the sight range a boat can always swing onto a survivor", function()
		local Ambient = t.load("src/shared/Calls/AmbientMix.luau")
		for _, row in L.Rows do
			local seconds = Ambient.SIGHT / row.speed
			local swing = (row.speed * seconds) ^ 2 / (2 * row.turnRadius) -- a circle's sideways travel
			t.expect(math.min(swing, 2 * row.turnRadius) + row.reach >= Ambient.SIGHT * 0.35)
				.toBe(true)
			-- a 0.25 s scan never steps over the reach, even passing off-centre
			t.expect(row.reach * 1.7 >= row.speed * 0.25 or row.level == 1).toBe(true)
		end
	end)

	t.test("the ladder has docs/30's shape", function()
		t.expect(#L.Rows).toBe(50)
		t.expect(L.row(1).speed).toBe(80)
		t.expect(L.row(5).speed).toBe(285)
		t.expect(L.row(10).speed).toBe(430)
		t.expect(L.row(20).speed).toBe(620)
		t.expect(L.row(30).speed).toBe(800)
		t.expect(L.row(40).speed).toBe(950)
		t.expect(L.row(50).speed).toBe(1100)
		local roomAt = {
			[1] = 1,
			[3] = 2,
			[6] = 3,
			[11] = 4,
			[16] = 5,
			[21] = 8,
			[26] = 9,
			[31] = 10,
			[41] = 12,
			[50] = 14,
		}
		for level, room in roomAt do
			t.expect(L.row(level).room).toBe(room)
		end
		t.expect(L.row(1).scale).toBe(1)
		t.expect(L.row(50).scale).toBe(2.5)
		for level, row in L.Rows do
			t.expect(row.level).toBe(level)
			t.expect(row.piece ~= "").toBe(true)
			if level > 1 then
				local below = L.Rows[level - 1]
				t.expect(row.speed > below.speed).toBe(true)
				t.expect(row.price > below.price).toBe(true)
				t.expect(row.room >= below.room).toBe(true)
				t.expect(row.scale > below.scale).toBe(true)
				t.expect(#L.pieceParts(level, Vector3.new(4, 2, 10)) >= 1).toBe(true)
			end
		end
		for _, stage in L.Stages do
			t.expect(VehicleConfig.get(stage.hull) ~= nil).toBe(true)
			t.expect(L.row(stage.first).hull).toBe(stage.hull)
			t.expect(L.row(stage.last).hull).toBe(stage.hull)
		end
		t.expect(L.level("x")).toBe(1)
		t.expect(L.level(99)).toBe(50)
		t.expect(L.nextRow(50)).toBeNil()
	end)

	t.test("L1 is today's jet ski: the tutorial's boat does not change", function()
		local base = VehicleConfig.JetSki
		local one = L.apply(base, 1)
		t.expect(math.abs(one.topSpeed - base.topSpeed) < 0.5).toBe(true)
		t.expect(math.abs(one.accel - base.accel) < 0.1).toBe(true)
		t.expect(one.survivorCapacity).toBe(1)
		t.expect(one.hullSize).toBe(base.hullSize)
		t.expect(one.draft).toBe(base.draft)
		t.expect(math.abs(one.maxLateralG - base.maxLateralG) < 0.1).toBe(true)
	end)

	t.test("a look has no stats: the level decides, a heli and sub ignore it", function()
		for _, id in { "JetSki", "RiptideX", "StormRunner", "Tidewalker", "Lifeboat" } do
			local spec = L.apply(VehicleConfig.get(id), 7)
			t.expect(spec.topSpeed).toBe(L.row(7).speed)
			t.expect(spec.survivorCapacity).toBe(L.row(7).room)
		end
		t.expect(L.apply(VehicleConfig.Submarine, 50)).toBe(VehicleConfig.Submarine)
		t.expect(L.apply(VehicleConfig.JetSki, nil)).toBe(VehicleConfig.JetSki)
		t.expect(L.apply(VehicleConfig.Lifeboat, 50).hullSize.Z <= L.MAX_LENGTH + 0.01).toBe(true)
	end)

	t.test("buying is Cash only and one level at a time", function()
		t.expect(select(1, L.canBuy(1, 499))).toBe(false)
		t.expect(select(2, L.canBuy(1, 499))).toBe("Need Cash")
		t.expect(select(1, L.canBuy(1, 500))).toBe(true)
		t.expect(select(3, L.canBuy(1, 500))).toBe(500)
		t.expect(select(2, L.canBuy(50, 1e9))).toBe("Max")
	end)

	t.test("old saves never go down", function()
		local Rules = t.load("src/shared/ProgressionRules.luau")
		local U = t.load("src/shared/VehicleUpgrades.luau")
		-- a fresh profile, and a new player's save, stay at L1 with no floors
		t.expect(Rules.defaultData().boatLevel).toBe(1)
		local saved = Rules.defaultData()
		saved.coldOpenDone = true
		local again = Rules.migrate(saved)
		t.expect(again.boatLevel).toBe(1)
		t.expect(again.boatPassFloor).toBeNil()
		-- old owners
		t.expect(Rules.migrate({ coldOpenDone = true, vehicles = { RIB = true } }).boatLevel >= 11)
			.toBe(true)
		t.expect(
			Rules.migrate({ coldOpenDone = true, vehicles = { Lifeboat = true } }).boatLevel >= 21
		)
			.toBe(true)
		-- a lifeboat with the extra seat held 9: L26 holds 9
		local nine = Rules.migrate({
			vehicles = { Lifeboat = true },
			vehicleUpgrades = { Lifeboat = U.bit("Fit") },
		})
		t.expect(nine.boatLevel >= 26).toBe(true)
		t.expect(nine.vehicleUpgrades.Lifeboat).toBe(U.bit("Fit")) -- old masks stay readable
		-- an old jet ski with the Engine went 92: L2 goes 120
		local tuned = Rules.migrate({ vehicleUpgrades = { JetSki = U.bit("Engine") } })
		t.expect(tuned.boatLevel >= 2).toBe(true)
		-- a pre-ladder player: the pass floor waits for the join's pass check; the boat follows their level
		local old = Rules.migrate({
			coldOpenDone = true,
			vehicles = { RIB = true },
			flags = { lastVehicle = "JetSki" },
		})
		t.expect(old.boatPassFloor).toBe(true)
		t.expect(Rules.migrate(old).boatPassFloor).toBe(true) -- until the join's pass check clears it
		t.expect(old.flags.lastVehicle).toBe("RIB")
		-- a paid look stays on
		t.expect(
			Rules.migrate({ vehicles = { RIB = true }, flags = { lastVehicle = "StormRunner" } }).flags.lastVehicle
		).toBe("StormRunner")
		-- a higher level is kept, and a corrupt one is safe
		t.expect(Rules.migrate({ boatLevel = 37, vehicles = { RIB = true } }).boatLevel).toBe(37)
		t.expect(Rules.migrate({ boatLevel = "x" }).boatLevel).toBe(1)
		-- a level survives the round trip and the client's rebuilt copy
		local data = Rules.migrate({ boatLevel = 12 })
		t.expect(Rules.fromSnapshot(Rules.snapshot(data)).boatLevel).toBe(12)
		-- levels hand out the stage hulls, a pass still owns its look, and nothing else does
		t.expect(Rules.ownsVehicle(Rules.migrate({ boatLevel = 11 }), "RIB")).toBe(true)
		t.expect(Rules.ownsVehicle(Rules.migrate({ boatLevel = 10 }), "RIB")).toBe(false)
		t.expect(Rules.ownsVehicle(Rules.migrate({ boatLevel = 10 }), "RIB", true)).toBe(true)
		t.expect(Rules.ownsVehicle(Rules.migrate({ boatLevel = 30 }), "Hydrofoil")).toBe(false)
		t.expect(Rules.ownsVehicle(Rules.migrate({ boatLevel = 31 }), "Hydrofoil")).toBe(true)
		t.expect(Rules.ownsVehicle(Rules.migrate({ boatLevel = 50 }), "StormRunner")).toBe(false)
	end)

	t.test("a wall glances you off at any angle, keeping most of the speed", function()
		local Glance = t.load("src/shared/Boat/Glance.luau")
		local n = Vector3.new(0, 0, 1) -- the wall faces +Z
		for _, speed in { 80, 430, 1100 } do
			for _, angle in { 5, 30, 60, 89, 90 } do
				local a = math.rad(angle)
				local v = Vector3.new(math.cos(a), 0, -math.sin(a)) * speed
				local out, heading = Glance.deflect(v, n, v.Unit)
				t.expect(out ~= nil and heading ~= nil).toBe(true)
				t.expect((out :: any).Magnitude >= speed * Glance.KEEP_HEAD_ON - 0.01).toBe(true)
				t.expect((out :: any).Magnitude <= speed).toBe(true)
				t.expect((out :: any):Dot(n) > 0).toBe(true) -- away from the wall
			end
		end
		-- already leaving: nothing to do
		t.expect((Glance.deflect(Vector3.new(50, 0, 10), n, Vector3.xAxis))).toBeNil()
		-- the sweep covers two frames of travel at the top speed
		t.expect(Glance.lookahead(1100, 1 / 60, 10) > 1100 / 60 * 2).toBe(true)
	end)

	t.test("the station: a bay on every island, clear of the lane and the plates", function()
		local Station = t.load("src/shared/UpgradeStation.luau")
		local Ring = t.load("src/shared/Config/RingLayout.luau")
		for index, island in Ring.Islands do
			local landing = Station.landing(index)
			-- bow to the open sea
			t.expect(landing.LookVector:Dot(island.facing) > 0.99).toBe(true)
			local inFrame = island.frame:PointToObjectSpace(landing.Position)
			t.expect(math.abs(inFrame.X - Station.LANDING_RIGHT) < 0.01).toBe(true)
			t.expect(math.abs(-inFrame.Z - Station.LANDING_FWD) < 0.01).toBe(true)
			for _, part in Station.parts(index) do
				local p = island.frame:PointToObjectSpace(part.cframe.Position)
				local r, f = p.X, -p.Z
				local hx, hz = part.size.X / 2, part.size.Z / 2
				for _, lane in Ring.EXIT_LANE do
					local clear = r + hx <= lane[1]
						or r - hx >= lane[2]
						or f + hz <= lane[3]
						or f - hz >= lane[4]
					t.expect(clear).toBe(true)
				end
				for _, keep in Ring.SEA_KEEP_OUT do
					local clear = r + hx <= keep[1]
						or r - hx >= keep[2]
						or f + hz <= keep[3]
						or f - hz >= keep[4]
					t.expect(clear).toBe(true)
				end
			end
			-- the whole bay is in range of the button
			local button
			for _, part in Station.parts(index) do
				if part.name == "Button" then
					button = part
				end
			end
			t.expect((button.cframe.Position - landing.Position).Magnitude < Station.USE_RANGE)
				.toBe(true)
		end
		-- out of range arguments still give a real island
		t.expect(typeof(Station.landing(99))).toBe("CFrame")
		-- a landing clears a craft docked at the berth or pontoon, the biggest of each: a hull longer than the bay
		-- slides seaward until its stern meets the quay, so its bow is at most one hull length out from the berth
		for _, id in VehicleConfig.Order do
			local spec = VehicleConfig.get(id)
			if spec and not spec.craft then
				local length = L.apply(spec, 50).hullSize.Z
				t.expect(length <= L.MAX_LENGTH + 0.01).toBe(true)
				t.expect(Station.LANDING_OUT - L.MAX_LENGTH / 2 > length).toBe(true)
			end
		end
	end)

	t.test(
		"the level-up moment: under 3 s, lifts, spins, lands, reduced motion stays small",
		function()
			local Station = t.load("src/shared/UpgradeStation.luau")
			t.expect(Station.MOMENT < 3).toBe(true)
			t.expect(Station.BLAST_AT < Station.SLAM_AT).toBe(true)
			t.expect((Station.pose(0))).toBe(0)
			t.expect((Station.pose(0.7))).toBe(1)
			local _, spin = Station.pose(1.2)
			t.expect(math.abs(spin - 2 * math.pi) < 0.01).toBe(true)
			local end_, endSpin, endTilt = Station.pose(Station.MOMENT)
			t.expect(end_).toBe(0)
			t.expect(endSpin).toBe(0)
			t.expect(math.abs(endTilt) < 0.001).toBe(true)
			local small, noSpin, noTilt = Station.pose(0.7, true)
			t.expect(small <= 0.25).toBe(true)
			t.expect(noSpin).toBe(0)
			t.expect(noTilt).toBe(0)
		end
	)
end
