-- Camera settings and the cold-open flag survive a save/load round trip (ProgressionRules).
return function(t)
	local Rules = t.load("src/shared/ProgressionRules.luau")

	t.test("coldOpenDone and flags persist through migrate", function()
		local d = Rules.defaultData()
		t.expect(d.coldOpenDone).toBe(false)
		d.coldOpenDone = true
		d.flags.cameraSettings =
			{ fov = 80, horizonStab = 0.4, motionBlur = false, seen_arrival = true }
		local again = Rules.migrate(Rules.migrate(d))
		t.expect(again.coldOpenDone).toBe(true)
		t.expect(again.flags.cameraSettings.fov).toBe(80)
		t.expect(again.flags.cameraSettings.seen_arrival).toBe(true)
		local snap = Rules.snapshot(again)
		t.expect(snap.coldOpenDone).toBe(true)
		t.expect(snap.flags.cameraSettings.horizonStab).toBe(0.4)
	end)

	t.test("flags are sanitised", function()
		local d = Rules.migrate({
			flags = {
				cameraSettings = { fov = 0 / 0, nested = { x = 1 }, ok = true },
				[5] = true,
				bad = function() end,
			},
		})
		t.expect(d.flags.cameraSettings.fov).toBeNil()
		t.expect(d.flags.cameraSettings.nested).toBeNil()
		t.expect(d.flags.cameraSettings.ok).toBe(true)
		t.expect(d.flags.bad).toBeNil()
		t.expect(Rules.migrate({ coldOpenDone = "yes" }).coldOpenDone).toBe(false)
	end)
end
