-- Boat respawn rules (shared/Boat/RespawnPolicy): a vehicle with a rider, or one ridden moments
-- ago, is never respawned or despawned; one record per player per class; idle, superseded and
-- wrecked craft are cleared only once nobody is aboard.
return function(t)
	local P = t.load("src/shared/Boat/RespawnPolicy.luau")
	local GRACE = P.OCCUPIED_GRACE

	local function state(overrides: { [string]: any }?): any
		local s: { [string]: any } = {
			occupied = false,
			carrying = false,
			lastOccupiedAt = nil,
			spawnedAt = 0,
			docked = false,
			current = true,
			wrecked = false,
		}
		for k, v in overrides or {} do
			s[k] = v
		end
		return s
	end

	t.test("an occupied vehicle is never removed except when its owner leaves", function()
		local riding = state({ occupied = true, lastOccupiedAt = 0 })
		for _, reason in { "Request", "Scripted", "Idle", "Wrecked" } do
			local ok, why = P.mayRemove(reason, riding, 10000)
			t.expect(ok).toBe(false)
			t.expect(why).toBe("Occupied")
		end
		t.expect((P.mayRemove("OwnerLeft", riding, 0))).toBe(true)
		-- even wrecked, out of sight and long idle on paper
		local wreck = state({ occupied = true, wrecked = true, ownerDistance = nil })
		t.expect((P.mayRemove("Wrecked", wreck, 1e6))).toBe(false)
	end)

	t.test(
		"a seat weld drop over a wave does not free the jet ski for a scripted respawn",
		function()
			-- the rider's seat reads empty for a moment at t = 100
			local dropped = state({ lastOccupiedAt = 100, spawnedAt = 0 })
			t.expect(P.recentlyOccupied(dropped, 100.1)).toBe(true)
			local ok, why = P.mayRemove("Scripted", dropped, 100.1)
			t.expect(ok).toBe(false)
			t.expect(why).toBe("RecentlyOccupied")
			t.expect((P.mayRemove("Scripted", dropped, 100 + GRACE - 0.01))).toBe(false)
			t.expect((P.mayRemove("Scripted", dropped, 100 + GRACE + 0.01))).toBe(true)
		end
	)

	t.test(
		"the cold open reuses the jet ski the player is riding instead of building another",
		function()
			t.expect((P.planSpawn("Scripted", nil, 0))).toBe("Build")
			t.expect((P.planSpawn("Scripted", state({ occupied = true }), 50))).toBe("Reuse")
			t.expect((P.planSpawn("Scripted", state({ lastOccupiedAt = 45 }), 50))).toBe("Reuse")
			-- an abandoned one nobody touched for a while may be rebuilt at the new spot
			t.expect((P.planSpawn("Scripted", state({ lastOccupiedAt = 0 }), 500))).toBe("Replace")
		end
	)

	t.test("an explicit request replaces an empty vehicle but refuses an occupied one", function()
		-- the player just walked off it to the desk: their request is honoured
		t.expect((P.planSpawn("Request", state({ lastOccupiedAt = 99 }), 100))).toBe("Replace")
		local plan, why = P.planSpawn("Request", state({ occupied = true }), 100)
		t.expect(plan).toBe("Refuse")
		t.expect(why).toBe("Occupied")
	end)

	t.test("idle despawn waits long, spares a docked current vehicle and cargo", function()
		local adrift = state({ lastOccupiedAt = 0 })
		t.expect((P.mayRemove("Idle", adrift, P.IDLE_DESPAWN - 1))).toBe(false)
		t.expect((P.mayRemove("Idle", adrift, P.IDLE_DESPAWN + 1))).toBe(true)
		local docked = state({ lastOccupiedAt = 0, docked = true })
		t.expect((P.mayRemove("Idle", docked, 1e6))).toBe(false)
		local superseded = state({ lastOccupiedAt = 0, docked = true, current = false })
		t.expect((P.mayRemove("Idle", superseded, P.SUPERSEDED_IDLE - 1))).toBe(false)
		t.expect((P.mayRemove("Idle", superseded, P.SUPERSEDED_IDLE + 1))).toBe(true)
		-- never ridden: idle counts from the spawn
		t.expect((P.mayRemove("Idle", state({ spawnedAt = 100 }), 100 + P.IDLE_DESPAWN - 1)))
			.toBe(false)
		-- survivors aboard or a tow line keep it
		local loaded = state({ lastOccupiedAt = 0, carrying = true, current = false })
		local ok, why = P.mayRemove("Idle", loaded, 1e6)
		t.expect(ok).toBe(false)
		t.expect(why).toBe("Carrying")
	end)

	t.test("a wreck is cleared only when empty, past the grace and far from its owner", function()
		local now = 1000
		local near = state({ wrecked = true, lastOccupiedAt = 0, ownerDistance = 40 })
		t.expect((P.mayRemove("Wrecked", near, now))).toBe(false)
		local far =
			state({ wrecked = true, lastOccupiedAt = 0, ownerDistance = P.STUCK_DISTANCE + 1 })
		t.expect((P.mayRemove("Wrecked", far, now))).toBe(true)
		local gone = state({ wrecked = true, lastOccupiedAt = 0, ownerDistance = nil })
		t.expect((P.mayRemove("Wrecked", gone, now))).toBe(true)
		local justLeft = state({ wrecked = true, lastOccupiedAt = now - 1, ownerDistance = nil })
		t.expect((P.mayRemove("Wrecked", justLeft, now))).toBe(false)
		t.expect((P.mayRemove("Wrecked", state({ lastOccupiedAt = 0, ownerDistance = nil }), now)))
			.toBe(false)
	end)

	t.test("a busy server clears idle craft sooner, docked ones too", function()
		local idle = P.IDLE_DESPAWN
		local adrift = state({ spawnedAt = 0, idleScale = 0.25 })
		t.expect((P.mayRemove("Idle", adrift, idle * 0.25 + 1))).toBe(true)
		t.expect((P.mayRemove("Idle", state({ spawnedAt = 0 }), idle * 0.25 + 1))).toBe(false)
		local docked = state({ spawnedAt = 0, docked = true, idleScale = 0.5 })
		t.expect((P.mayRemove("Idle", docked, idle * 0.5 + 1))).toBe(true)
		t.expect((P.mayRemove("Idle", state({ spawnedAt = 0, docked = true }), 1e7))).toBe(false)
		local old = state({ spawnedAt = 0, current = false, idleScale = 0.5 })
		t.expect((P.mayRemove("Idle", old, P.SUPERSEDED_IDLE * 0.5 + 1))).toBe(true)
	end)
end
