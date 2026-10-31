-- PetMotion: the following pet's procedural gait, look-at, swim and cheer on its rigid parts.
return function(t)
	local M = t.load("src/shared/PetMotion.luau")

	local function run(state, seconds, input)
		local pose
		for _ = 1, math.floor(seconds * 60) do
			input.dt = 1 / 60
			pose = M.step(state, input)
		end
		return pose
	end

	local NECK = Vector3.new(0, 1.4, -1)

	t.test("every species has a gait", function()
		for _, species in { "SealPup", "Puffin", "Otter", "Turtle", "Gull" } do
			t.expect(M.GAIT[species]).toBeTruthy()
		end
	end)

	t.test("standing still it breathes but doesn't step", function()
		local s = M.new("Puffin")
		local lo, hi = math.huge, -math.huge
		for _ = 1, 180 do
			local pose = run(s, 1 / 60, { speed = 0, mode = "walk" })
			lo, hi = math.min(lo, pose.root.Y), math.max(hi, pose.root.Y)
			t.expect(math.abs(pose.stepL) < 0.05).toBeTruthy()
		end
		t.expect(hi - lo > 0.01).toBeTruthy()
		t.expect(hi - lo < 0.1).toBeTruthy()
	end)

	t.test("walking the feet alternate and lift", function()
		local s = M.new("Gull")
		local pose = run(s, 1, { speed = 12, mode = "walk" })
		t.expect(s.gait > 0.5).toBeTruthy()
		t.expect(pose.stepL).toBeCloseTo(-pose.stepR, 3)
		local seenR, lifted = false, false
		for _ = 1, 60 do
			pose = run(s, 1 / 60, { speed = 12, mode = "walk" })
			seenR = seenR or pose.stepR > 0.3
			if pose.stepL > 0.3 then -- the left foot's swing: raised off the body's line
				local foot = M.partDelta(
					pose,
					"Foot",
					CFrame.new(-0.3, 0.1, 0),
					Vector3.new(0.4, 0.1, 0.5),
					NECK,
					1
				)
				local body = M.partDelta(pose, "Body", CFrame.new(0, 1, 0), Vector3.one, NECK, 1)
				lifted = lifted or (foot.Position - body.Position).Magnitude > 0.04
			end
		end
		t.expect(seenR and lifted).toBeTruthy()
	end)

	t.test("idle, the head turns toward the player, capped", function()
		local s = M.new("SealPup")
		local pose = run(s, 2, { speed = 0, mode = "walk", lookYaw = 0.5 })
		t.expect(pose.headYaw).toBeCloseTo(0.5, 2)
		pose = run(s, 2, { speed = 0, mode = "walk", lookYaw = 3 })
		t.expect(pose.headYaw).toBeCloseTo(M.MAX_LOOK, 2)
		-- a head part moves with the turn; a body part doesn't
		local still = M.partDelta(pose, "Body", CFrame.new(0, 1, 0), Vector3.one, NECK, 1)
		local eye = M.partDelta(pose, "Eye", CFrame.new(0.3, 1.8, -2), Vector3.one * 0.3, NECK, 1)
		t.expect((eye.Position - still.Position).Magnitude > 0.1).toBeTruthy()
	end)

	t.test("on the move it looks where it goes", function()
		local s = M.new("Otter")
		local pose = run(s, 2, { speed = 14, mode = "walk", lookYaw = 0.6 })
		t.expect(math.abs(pose.headYaw) < 0.1).toBeTruthy()
	end)

	t.test("swimming paddles and a gull floats higher", function()
		local s = M.new("Turtle")
		local spread = 0
		for _ = 1, 120 do
			local pose = run(s, 1 / 60, { speed = 0, mode = "swim" })
			spread = math.max(spread, math.abs(pose.stroke))
		end
		t.expect(spread > 0.2).toBeTruthy()
		t.expect(M.sink("Gull") < M.sink("SealPup")).toBeTruthy()
	end)

	t.test("the rescue cheer hops twice and settles", function()
		local s = M.new("SealPup")
		local top = 0
		for i = 0, 40 do
			local pose = run(s, 1 / 60, { speed = 0, mode = "walk", cheer = i / 40 })
			top = math.max(top, pose.root.Y)
		end
		t.expect(top > 0.4).toBeTruthy()
		local after = run(s, 0.5, { speed = 0, mode = "walk" })
		t.expect(after.root.Y < 0.1).toBeTruthy()
	end)

	t.test("asleep the head droops", function()
		local s = M.new("Puffin")
		local pose = run(s, 1, { speed = 0, mode = "nap" })
		t.expect(pose.headPitch < -0.2).toBeTruthy()
	end)

	t.test("a wing raises outward on both sides", function()
		local s = M.new("Puffin")
		local pose = run(s, 0.3, { speed = 0, mode = "walk", cheer = 0.5 })
		pose.flapL, pose.flapR = 0.5, 0.5
		local size = Vector3.new(0.2, 1.6, 0.9)
		local left = M.partDelta(pose, "Wing", CFrame.new(-0.9, 1.05, 0.1), size, NECK, 1)
		local right = M.partDelta(pose, "Wing", CFrame.new(0.9, 1.05, 0.1), size, NECK, 1)
		local tipL = (left * CFrame.new(-0.9, 0.3, 0.1)).X
		local tipR = (right * CFrame.new(0.9, 0.3, 0.1)).X
		local rest = M.partDelta(pose, "Body", CFrame.new(), size, NECK, 1)
		t.expect(tipL < (rest * CFrame.new(-0.9, 0.3, 0.1)).X).toBeTruthy()
		t.expect(tipR > (rest * CFrame.new(0.9, 0.3, 0.1)).X).toBeTruthy()
	end)
end
