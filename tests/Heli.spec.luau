-- Heli (docs/23 h, WP-6): arcade flight (hands off = hover, floor and ceiling) and the winch rule.
return function(t)
	local Flight = t.load("src/shared/Heli/Flight.luau")
	local Winch = t.load("src/shared/Heli/Winch.luau")
	local Board = t.load("src/shared/Ops/Board.luau")
	local spec = Flight.SPECS.RescueHelicopter
	local IDLE = { forward = 0, strafe = 0, yaw = 0, lift = 0 }

	-- runs n seconds at 60 Hz, integrating y; returns the state and final y
	local function fly(s, input, y, floor, seconds, wind)
		for _ = 1, seconds * 60 do
			Flight.step(s, input, spec, y, floor, wind or Vector3.zero, 1 / 60)
			y += s.velocity.Y / 60
		end
		return s, y
	end

	t.test("hands off: a moving heli settles into a level hover", function()
		local s = fly(Flight.new(0, Vector3.new(40, 10, -30)), IDLE, 100, 0, 5)
		t.expect(s.velocity.Magnitude).toBeCloseTo(0, 0.01)
		local up = Flight.attitude(s, spec).UpVector
		t.expect(up.Y).toBeCloseTo(1, 1e-6) -- auto-level
	end)

	t.test("forward flies along the heading, nose down; yaw turns right on +input", function()
		local s = fly(Flight.new(0), { forward = 1, strafe = 0, yaw = 0, lift = 0 }, 100, 0, 5)
		t.expect(-s.velocity.Z).toBeCloseTo(spec.forwardSpeed, 0.01)
		t.expect(Flight.attitude(s, spec).LookVector.Y < 0).toBe(true)
		local turn = fly(Flight.new(0), { forward = 0, strafe = 0, yaw = 1, lift = 0 }, 100, 0, 0.5)
		t.expect(turn.heading < 0).toBe(true)
		local right = CFrame.Angles(0, turn.heading, 0).LookVector
		t.expect(right.X > 0).toBe(true) -- looking a bit to +X: turned right
		t.expect(Flight.headingOf(right)).toBeCloseTo(turn.heading, 1e-6)
	end)

	t.test("it never sinks under the floor or climbs past the ceiling", function()
		local _, low =
			fly(Flight.new(0), { forward = 0, strafe = 0, yaw = 0, lift = -1 }, 50, 20, 8)
		t.expect(low).toBeCloseTo(20, 0.5)
		local _, high =
			fly(Flight.new(0), { forward = 0, strafe = 0, yaw = 0, lift = 1 }, 280, 0, 8)
		t.expect(high).toBeCloseTo(spec.ceiling, 0.5)
		local _, lifted = fly(Flight.new(0), IDLE, 10, 30, 5) -- under the floor (a rising wave): pushed up
		t.expect(lifted).toBeCloseTo(30, 0.5)
	end)

	t.test("floor: skids on land and decks, clear of the open sea", function()
		t.expect(Flight.floor(12, 0, spec)).toBe(12 + spec.skid)
		t.expect(Flight.floor(-40, 0, spec)).toBe(Flight.WATER_CLEARANCE + spec.skid) -- seabed
		t.expect(Flight.floor(nil, 2, spec)).toBe(2 + Flight.WATER_CLEARANCE + spec.skid)
	end)

	t.test("storm wind drifts a hover, but slower than the steady limit", function()
		local wind = Flight.wind(0, 1)
		t.expect(wind.X).toBeCloseTo(Flight.WIND, 1e-6)
		local s = fly(Flight.new(0), IDLE, 100, 0, 5, wind)
		t.expect(s.velocity.Magnitude <= Board.STEADY_SPEED).toBe(true)
		t.expect(Flight.wind(1, 0).Magnitude).toBe(0)
	end)

	t.test("winch: steady in the ring and band for HOLD s lifts; drifting off resets", function()
		t.expect(Winch.ready(5, 20, 2, 5, true)).toBe(true)
		t.expect(Winch.ready(Winch.RING + 1, 20, 2, 5, true)).toBe(false)
		t.expect(Winch.ready(5, Winch.MAX_HEIGHT + 1, 2, 5, true)).toBe(false)
		t.expect(Winch.ready(5, -2, 2, 5, true)).toBe(false) -- below them
		t.expect(Winch.ready(5, 20, Board.STEADY_SPEED + 1, 5, true)).toBe(false)
		t.expect(Winch.ready(5, 20, 2, Board.STEADY_TILT + 1, true)).toBe(false)
		t.expect(Winch.ready(5, 20, 2, 5, false)).toBe(false) -- full
		local held, lift = Winch.hold(0, true, Winch.HOLD / 2)
		t.expect(lift).toBe(false)
		held, lift = Winch.hold(held, true, Winch.HOLD / 2 + 0.01)
		t.expect(lift).toBe(true)
		t.expect((Winch.hold(held, false, 0.1))).toBe(0)
	end)
end
