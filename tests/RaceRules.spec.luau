-- K15 racer balance: the head start leaves a straight-driving player with base craft ahead, the
-- racer is slower than every base craft, and both take the water route through the harbour mouth.
return function(t)
	local R = t.load("src/shared/Calls/RaceRules.luau")
	local VehicleConfig = t.load("src/shared/Config/VehicleConfig.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")

	-- racer arrival vs a player who drives straight at `cruise` of their top speed
	local function margin(
		from: Vector3,
		spot: Vector3,
		top: number,
		onFoot: boolean,
		cruise: number
	)
		local route = R.route(R.START, spot)
		local racerLen = R.length(R.START, route)
		local water = if onFoot then R.START else from
		local playerLen = R.length(water, R.route(water, spot))
		local walk = if onFoot then (from - CallTypes.STATION).Magnitude else 0
		local est = R.playerSeconds(playerLen, top, onFoot, walk)
		local racer = R.delay(est, racerLen) + racerLen / R.SPEED
		local player = R.BOARD
			+ playerLen / (top * cruise)
			+ (if onFoot then R.LAUNCH + walk / R.WALK else 0)
		return racer, player, est
	end

	t.test("the racer is slower than every base craft", function()
		for _, id in { "JetSki", "RIB", "Lifeboat" } do
			t.expect(R.SPEED < VehicleConfig[id].topSpeed).toBeTruthy()
		end
	end)

	t.test(
		"a straight run in a base craft beats the racer, near or far, afloat or on foot",
		function()
			local spots = {
				Vector3.new(-60, 0, 160), -- close in the basin
				Vector3.new(250, 0, 300), -- far corner of the basin
				Vector3.new(0, 0, 420), -- just outside the mouth
				Vector3.new(-700, 0, 900), -- open water, west
				Vector3.new(900, 0, 1300), -- open water, far east
			}
			local starts = {
				{ R.START, false }, -- afloat off the bays
				{ CallTypes.STATION, true }, -- on foot at the bays
				{ Vector3.new(-300, 0, -200), true }, -- on foot up in town
				{ Vector3.new(500, 0, 800), false }, -- afloat outside
			}
			for _, id in { "JetSki", "RIB" } do
				local top = VehicleConfig[id].topSpeed
				for _, spot in spots do
					for _, s in starts do
						local racer, player, est = margin(s[1], spot, top, s[2], R.CRUISE)
						t.expect(player <= racer * R.FAIR + 1e-6).toBeTruthy()
						t.expect(est / racer <= R.FAIR + 1e-6).toBeTruthy()
						-- even a much slower run (40% of top) is not a wall: still level or ahead
						local _, slow = margin(s[1], spot, top, s[2], 0.4)
						t.expect(slow <= racer + 1e-6).toBeTruthy()
					end
				end
			end
		end
	)

	t.test("the racer always waits a visible beat at the bays", function()
		t.expect(R.delay(0, 5000)).toBe(R.MIN_DELAY)
		t.expect(R.delay(70, 400)).toBeCloseTo(70 / R.FAIR - 400 / R.SPEED, 1e-9)
	end)

	t.test(
		"in or out of the basin goes through the harbour mouth, never across the breakwater",
		function()
			local inside, outside = Vector3.new(-200, 0, 200), Vector3.new(-600, 0, 700)
			t.expect(R.inside(inside)).toBeTruthy()
			t.expect(R.inside(outside)).toBeFalsy()
			t.expect(R.route(inside, Vector3.new(100, 0, 150)))
				.toEqual({ Vector3.new(100, 0, 150) })
			t.expect(R.route(inside, outside)).toEqual({ R.INNER_MOUTH, R.OUTER_MOUTH, outside })
			t.expect(R.route(outside, inside)).toEqual({ R.OUTER_MOUTH, R.INNER_MOUTH, inside })
			-- the mouth waypoints sit either side of the breakwater heads (z 352..368), inside the gap
			t.expect(R.inside(R.INNER_MOUTH) and not R.inside(R.OUTER_MOUTH)).toBeTruthy()
			t.expect(math.abs(R.INNER_MOUTH.X) < 30 and math.abs(R.OUTER_MOUTH.X) < 30).toBeTruthy()
			t.expect(R.length(inside, R.route(inside, outside)) > (outside - inside).Magnitude)
				.toBeTruthy()
		end
	)

	t.test(
		"craft identity: jet ski fastest, RIB fast, lifeboat slowest; engine adds 15%",
		function()
			local U = t.load("src/shared/VehicleUpgrades.luau")
			local ski, rib, boat = VehicleConfig.JetSki, VehicleConfig.RIB, VehicleConfig.Lifeboat
			t.expect(ski.topSpeed > rib.topSpeed and rib.topSpeed > boat.topSpeed).toBeTruthy()
			t.expect(ski.survivorCapacity < rib.survivorCapacity).toBeTruthy()
			t.expect(rib.survivorCapacity < boat.survivorCapacity).toBeTruthy()
			-- an engine-tuned RIB catches the base jet ski: the upgrade is worth buying
			t.expect(U.apply(rib, U.bit("Engine")).topSpeed > ski.topSpeed).toBeTruthy()
		end
	)

	t.test("along: walks the route legs and clamps at the end", function()
		local route = { Vector3.new(0, 0, 100), Vector3.new(100, 0, 100) }
		t.expect((R.along(Vector3.zero, route, 50) - Vector3.new(0, 0, 50)).Magnitude < 1e-3)
			.toBeTruthy()
		t.expect((R.along(Vector3.zero, route, 150) - Vector3.new(50, 0, 100)).Magnitude < 1e-3)
			.toBeTruthy()
		t.expect((R.along(Vector3.zero, route, 999) - Vector3.new(100, 0, 100)).Magnitude < 1e-3)
			.toBeTruthy()
		t.expect(R.UNDERWAY).toBe(12.5) -- 15 km/h at 3 / 3.6 studs/s per km/h
	end)
end
