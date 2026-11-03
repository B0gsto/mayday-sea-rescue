-- PirateRules (docs/29 D, docs/30 section 5): who is hunted, fair at any speed, and what shakes a pirate.
return function(t)
	local R = t.load("src/shared/PirateRules.luau")
	local RingLayout = t.load("src/shared/Config/RingLayout.luau")
	local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")

	local who = {
		survivors = 2,
		zone = 3,
		calls = 5,
		coldOpenDone = true,
		coldOpenActive = false,
		testRide = false,
		surfaceBoat = true,
	}
	local function with(k: string, v: any)
		local w = table.clone(who)
		w[k] = v
		return w
	end

	-- Open water: find a point in the far sea with a clear run ahead, away from any land.
	local function openSea(top: number): (Vector3, Vector3)
		for bearing = 0, 350, 10 do
			local dir = Vector3.new(math.cos(math.rad(bearing)), 0, math.sin(math.rad(bearing)))
			local boat = Vector3.new(RingLayout.Center.X, 0, RingLayout.Center.Z) + dir * 9000
			local forward = Vector3.new(-dir.Z, 0, dir.X)
			local run = 12 * top
			if
				not R.sightBlocked(boat, boat + forward * run)
				and R.spawnPoint(boat, forward, top, false)
			then
				return boat, forward
			end
		end
		error("no open sea")
	end

	-- Drives the boat at vel(t) with a fixed step until the chase ends: why, seconds taken.
	local function run(
		top: number,
		ping: number,
		velAt: (number, Vector3) -> Vector3,
		from: Vector3?,
		dir: Vector3?
	): (string?, number)
		local boat, forward = openSea(top)
		boat, forward = from or boat, dir or forward
		local start = R.spawnPoint(boat, forward, top, false)
		assert(start, "no spawn")
		local c = R.newChase(start, boat, velAt(0, forward), top)
		local dt, now = 1 / 30, 0
		while now < 60 do
			local vel = velAt(now, forward)
			boat += vel * dt
			now += dt
			local why = R.step(c, { boat = boat, vel = vel, top = top, ping = ping, dt = dt })
			if why then
				return why, now
			end
		end
		return nil, now
	end

	t.test(
		"only with survivors aboard, in zone 2+, after 5 calls, never in the tutorial",
		function()
			t.expect(R.eligible(who)).toBe(true)
			t.expect(R.eligible(with("survivors", 0))).toBe(false)
			t.expect(R.eligible(with("zone", 1))).toBe(false)
			t.expect(R.eligible(with("calls", 4))).toBe(false)
			t.expect(R.eligible(with("coldOpenDone", false))).toBe(false)
			t.expect(R.eligible(with("coldOpenActive", true))).toBe(false)
			t.expect(R.eligible(with("testRide", true))).toBe(false)
			t.expect(R.eligible(with("surfaceBoat", false))).toBe(false)
		end
	)

	t.test("chance rises with zone and load", function()
		t.expect(R.chance(1, 4, 4)).toBe(0)
		for zone = 2, 4 do
			t.expect(R.chance(zone + 1, 2, 4) > R.chance(zone, 2, 4)).toBe(true)
		end
		t.expect(R.chance(3, 4, 4) > R.chance(3, 1, 4)).toBe(true)
		t.expect(R.chance(3, 40, 4)).toBe(R.chance(3, 4, 4)) -- past the seats survivors just count
	end)

	t.test("spawn distance and reach scale with speed", function()
		t.expect(R.spawnDistance(30)).toBe(300)
		t.expect(R.spawnDistance(1100)).toBe(5500)
		t.expect(R.reach(1100) > R.reach(60)).toBe(true)
		-- a head-on pass at both top speeds can't step through the reach at 30 Hz
		t.expect(R.reach(1100) > (1100 * 1.92) / 30 / 2).toBe(true)
	end)

	t.test("spawns off to the side, in the open, clear of the Shallows", function()
		for _, top in { 60, 1100 } do
			local boat, forward = openSea(top)
			for _, flip in { false, true } do
				local p = R.spawnPoint(boat, forward, top, flip)
				t.expect(p ~= nil).toBe(true)
				local off = p - boat
				t.expect(math.abs(off.Magnitude - R.spawnDistance(top)) < 1).toBe(true)
				t.expect(math.abs(off.Unit:Dot(forward)) < 0.9).toBe(true) -- not dead ahead or astern
				t.expect(R.blocked(p)).toBe(false)
			end
		end
	end)

	t.test("no spawn when the whole far side is the Shallows", function()
		local at = Vector3.new(RingLayout.Center.X, 0, RingLayout.Center.Z)
		t.expect(R.spawnPoint(at, Vector3.new(1, 0, 0), 60, false)).toBe(nil)
	end)

	t.test("aimPoint meets a boat holding its course", function()
		local boat, vel = Vector3.new(0, 0, 0), Vector3.new(100, 0, 0)
		local from = Vector3.new(300, 0, 400)
		local aim = R.aimPoint(from, boat, vel, 92)
		local t1 = aim.X / 100
		t.expect(math.abs((aim - from).Magnitude - 92 * t1) < 1).toBe(true)
	end)

	t.test("cuts off a boat holding its course, in about the same warning at any speed", function()
		for _, top in { 60, 300, 1100 } do
			local why, took = run(top, 0, function(_, f)
				return f * top
			end)
			t.expect(why).toBe("Hit")
			t.expect(took > 3).toBe(true)
			t.expect(took < 20).toBe(true)
		end
	end)

	t.test("a stopped boat gets hit", function()
		local why = run(1100, 0, function()
			return Vector3.zero
		end)
		t.expect(why).toBe("Hit")
	end)

	t.test("lag: a laggier client gets longer on the boat, and a stalled one no hit", function()
		t.expect(R.hold(0.3) > R.hold(0.05)).toBe(true)
		t.expect(R.hold(5)).toBe(R.HOLD_MAX)
		t.expect(R.mayHit(10, R.LAG_PAUSE)).toBe(false)
		t.expect(R.mayHit(0.5, 0)).toBe(false) -- not the moment it appears
		local c = R.newChase(Vector3.new(9000, 0, 0), Vector3.new(9000, 0, 0), Vector3.zero, 100)
		local input = {
			boat = Vector3.new(9000, 0, 0),
			vel = Vector3.zero,
			top = 100,
			ping = 1,
			dt = 0.5,
		}
		for _ = 1, 10 do
			t.expect(R.step(c, input)).toBe(nil)
		end
	end)

	t.test("a boost shakes it", function()
		for _, top in { 60, 1100 } do
			local boat, forward = openSea(top)
			local boosted = 1.25 * top
			-- turn straight away from it and boost: its wake-thrown speed falls far behind
			local start = R.spawnPoint(boat, forward, top, false)
			local away = (boat - start).Unit
			local why, took = run(top, 0, function()
				return away * boosted
			end, boat, forward)
			t.expect(why).toBe("Shaken")
			t.expect(took < 8).toBe(true)
		end
	end)

	t.test("an island between you shakes it", function()
		local island = WorldConfig.Islands[1]
		local c = Vector3.new(island.center.X, 0, island.center.Z)
		local out = (c - Vector3.new(RingLayout.Center.X, 0, RingLayout.Center.Z)).Unit
		local boat = c + out * (island.radius + 100)
		local pirate = R.newChase(c - out * (island.radius + 200), boat, Vector3.zero, 100)
		pirate.age = 5
		local why = nil
		for _ = 1, 90 do
			why = R.step(pirate, {
				boat = boat,
				vel = Vector3.zero,
				top = 100,
				ping = 0,
				dt = 1 / 30,
			})
			if why then
				break
			end
		end
		t.expect(why).toBe("Shaken")
		t.expect(R.blocked(pirate.pos)).toBe(false) -- round it, never through it
	end)

	t.test("gives up after 40 s, and at the Shallows line", function()
		local boat, forward = openSea(100)
		local c = R.newChase(boat + forward * 500, boat, Vector3.zero, 100)
		c.age = R.CHASE_SECONDS
		t.expect(R.step(c, { boat = boat, vel = Vector3.zero, top = 100, ping = 0, dt = 0.03 }))
			.toBe("Timeout")
		local home = Vector3.new(RingLayout.Center.X + 100, 0, RingLayout.Center.Z)
		c.age = 2
		t.expect(R.step(c, { boat = home, vel = Vector3.zero, top = 100, ping = 0, dt = 0.03 }))
			.toBe("Shallows")
	end)

	t.test("never steers past the Shallows line", function()
		local center = Vector3.new(RingLayout.Center.X, 0, RingLayout.Center.Z)
		local c = R.newChase(center + Vector3.new(1700, 0, 0), center, Vector3.zero, 100)
		c.heading = Vector3.new(-1, 0, 0)
		for _ = 1, 300 do
			R.stepSailOff(c, center + Vector3.new(5000, 0, 0), 100, 1 / 30)
			t.expect(R.blocked(c.pos)).toBe(false)
		end
	end)

	t.test("sails off, then it is gone", function()
		local boat = openSea(100)
		local c = R.newChase(boat + Vector3.new(50, 0, 0), boat, Vector3.zero, 100)
		local before = (c.pos - boat).Magnitude
		t.expect(R.stepSailOff(c, boat, 100, 1)).toBe(false)
		t.expect((c.pos - boat).Magnitude > before).toBe(true)
		t.expect(R.stepSailOff(c, boat, 100, R.SAIL_OFF_SECONDS)).toBe(true)
	end)

	t.test("the Go back bonus pays +25% only while its stamp runs", function()
		t.expect(R.payMult(nil, 10)).toBe(1)
		t.expect(R.payMult(11, 10)).toBe(1.25)
		t.expect(R.payMult(10, 10)).toBe(1)
	end)
end
