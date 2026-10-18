-- Cold open lifecycle (shared/Boat/ColdOpenFlow): it starts once for a new player, never restarts
-- by itself whatever the outcome, and always hands the player over to the station.
return function(t)
	local F = t.load("src/shared/Boat/ColdOpenFlow.luau")

	t.test("a new player starts it once; a running one is never started again", function()
		local e = F.new()
		t.expect(F.decide(e, true, 0, false)).toBe("Start")
		t.expect(F.begin(e, "op-1")).toBe(true)
		t.expect(e.phase).toBe("Running")
		t.expect(e.opId).toBe("op-1")
		t.expect(F.begin(e, "op-2")).toBe(false)
		t.expect(e.opId).toBe("op-1")
	end)

	t.test("waits for the profile, then skips it for a returning player", function()
		local e = F.new()
		t.expect(F.decide(e, true, 0, nil)).toBe("Wait")
		t.expect(e.phase).toBe("NotStarted")
		t.expect(F.decide(e, true, 0, true)).toBe("Offer")
		t.expect(e.phase).toBe("Finished")
		t.expect(F.begin(e)).toBe(false)
	end)

	t.test("skipped without the jet ski or once ops are done", function()
		local a = F.new()
		t.expect(F.decide(a, false, 0, false)).toBe("Offer")
		t.expect(a.phase).toBe("Finished")
		local b = F.new()
		t.expect(F.decide(b, true, 1, false)).toBe("Offer")
		t.expect(F.begin(b)).toBe(false)
	end)

	t.test("every ending finishes it for good and never auto-restarts", function()
		for _, reason in { "Complete", "Timer", "Takeover", "Fail", "LeftCraft", "Died", "Lost" } do
			local e = F.new()
			F.decide(e, true, 0, false)
			F.begin(e, "op")
			t.expect(F.finish(e, reason)).toBe(true) -- hand over once
			t.expect(F.finish(e, reason)).toBe(false) -- never twice
			t.expect(e.phase).toBe("Finished")
			t.expect(e.reason).toBe(reason)
			-- the bug: ColdOpenDone unset (save failed) and no completed op
			for _ = 1, 5 do
				t.expect(F.decide(e, true, 0, false)).toBe("Offer")
			end
			t.expect(F.begin(e)).toBe(false)
		end
	end)

	t.test("a running cold open whose op vanished is abandoned, not replayed", function()
		local e = F.new()
		F.begin(e, "op")
		t.expect(F.decide(e, true, 0, false)).toBe("Abandon")
		t.expect(F.finish(e, "Lost")).toBe(true)
		t.expect(F.decide(e, true, 0, false)).toBe("Offer")
	end)

	t.test("watch: death ends it at once, leaving the jet ski after a grace", function()
		local e = F.new()
		F.begin(e, "op")
		t.expect(F.watch(e, 0, true, true)).toBe(nil)
		t.expect(F.watch(e, 1, true, false)).toBe(nil) -- fell off over a wave
		t.expect(F.watch(e, 1 + F.LEAVE_GRACE - 0.5, true, false)).toBe(nil)
		t.expect(F.watch(e, 1 + F.LEAVE_GRACE - 0.25, true, true)).toBe(nil) -- back aboard
		t.expect(e.offCraftSince).toBe(nil)
		t.expect(F.watch(e, 30, true, false)).toBe(nil)
		t.expect(F.watch(e, 30 + F.LEAVE_GRACE, true, false)).toBe("LeftCraft")
		t.expect(F.watch(e, 31, false, true)).toBe("Died")
		F.finish(e, "Died")
		t.expect(F.watch(e, 40, false, false)).toBe(nil) -- finished: nothing to watch
		t.expect(F.watch(F.new(), 0, false, false)).toBe(nil)
	end)

	t.test("graceful outcome: the lifeboat has the casualty and the player goes home", function()
		t.expect(F.rescued("Complete")).toBe(true)
		t.expect(F.radioFor("Complete").from).toBe("Gale Isles Coastguard")
		for _, reason in { "Timer", "Takeover", "LeftCraft", "Died", "Lost" } do
			t.expect(F.rescued(reason)).toBe(false)
			local msg = F.radioFor(reason)
			t.expect(msg.from).toBe(F.LIFEBOAT)
			t.expect(string.find(msg.text, "casualty aboard", 1, true) ~= nil).toBe(true)
			t.expect(string.find(msg.text, "Return to station", 1, true) ~= nil).toBe(true)
		end
		t.expect(F.handover(true, true)).toBe("Ride")
		t.expect(F.handover(true, false)).toBe("Station")
		t.expect(F.handover(false, true)).toBe("Respawn")
	end)

	t.test("reset is a dev replay only", function()
		local e = F.new()
		F.begin(e, "op")
		F.finish(e, "Timer")
		F.reset(e)
		t.expect(F.decide(e, true, 0, false)).toBe("Start")
		t.expect(F.begin(e, "op-2")).toBe(true)
	end)
end
