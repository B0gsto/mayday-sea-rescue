-- CasualtyRig (docs/14 section 4): every pose samples joint CFrames on the R15 motor keys, and the cycles move.
return function(t)
	local Rig = t.load("src/shared/Casualty/CasualtyRig.luau")

	t.test(
		"every pose but Bind drives the Root motor and the arms, and animates over time",
		function()
			for _, name in Rig.POSES do
				if name == "Bind" then
					continue
				end
				local a, b = Rig.sample(name, 0.1), Rig.sample(name, 0.6)
				t.expect(typeof(a.Root)).toBe("CFrame")
				t.expect(typeof(a.LeftUpperArm)).toBe("CFrame")
				t.expect(typeof(a.RightUpperArm)).toBe("CFrame")
				local moved = false
				for k, cf in a do
					moved = moved or cf ~= b[k]
				end
				t.expect(moved).toBe(true)
			end
		end
	)

	t.test("Hold brings both hands up in front (arms pitched forward past 60 degrees)", function()
		local p = Rig.sample("Hold", 0)
		for _, k in { "LeftUpperArm", "RightUpperArm" } do
			local down = p[k]:VectorToWorldSpace(Vector3.new(0, -1, 0)) -- the limb's hanging direction
			t.expect(down.Z < -0.8).toBe(true) -- pointing forward (-Z)
		end
	end)
end
