-- RiderPose: the jet ski rider's lean, crouch and bump bounce.
return function(t)
	local R = t.load("src/shared/Boat/RiderPose.luau")

	local function run(s, seconds, input)
		local pose
		for _ = 1, math.floor(seconds * 60) do
			input.dt = 1 / 60
			pose = R.step(s, input)
		end
		return pose
	end
	local function base()
		return { yawRate = 0, speed = 20, topSpeed = 40, vertical = 0, scale = 1 }
	end

	t.test("leans into a left turn at speed, not while idling round", function()
		local i = base()
		i.yawRate = 0.8
		local _, _, roll = run(R.new(), 1, i).Root:ToEulerAnglesYXZ()
		t.expect(roll > math.rad(10)).toBeTruthy()
		i.speed = 0
		_, _, roll = run(R.new(), 1, i).Root:ToEulerAnglesYXZ()
		t.expect(math.abs(roll) < 0.01).toBeTruthy()
	end)

	t.test("tucks forward under acceleration more than cruising", function()
		local s = R.new()
		local i = base()
		i.speed = 0
		local pitchAccel
		for n = 1, 30 do
			i.speed = n -- +60 studs/s^2
			i.dt = 1 / 60
			pitchAccel = R.step(s, i).Waist:ToEulerAnglesYXZ()
		end
		local cruise = run(R.new(), 1, base()).Waist:ToEulerAnglesYXZ()
		t.expect(pitchAccel < cruise).toBeTruthy()
		t.expect(cruise < 0).toBeTruthy()
	end)

	t.test("a slam dips the hips then settles; reduce motion skips it", function()
		local s = R.new()
		local i = base()
		run(s, 0.5, i)
		i.vertical = 15
		local hit = run(s, 0.1, i).Root.Position.Y
		local settled = run(s, 2, i).Root.Position.Y
		t.expect(hit < settled - 0.1).toBeTruthy()
		local r = R.new()
		local j = base()
		j.scale = 0.4
		run(r, 0.5, j)
		j.vertical = 15
		run(r, 0.1, j)
		t.expect(r.y == 0).toBeTruthy()
	end)
end
