-- Onboarding (docs/16 section 4): the tutorial call is the only goal, the fail-safe calls and the
-- stripped HUD.
return function(t)
	local O = t.load("src/shared/Onboarding.luau")
	local CallTypes = t.load("src/shared/Calls/CallTypes.luau")

	local function facts(over)
		local f = { coldOpenDone = true, callsCompleted = 0, offerReady = false }
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("nothing to show before the cold open ends", function()
		t.expect(O.goal(facts({ coldOpenDone = false, offerReady = true }))).toBe(nil)
	end)

	t.test("each tutorial call's offer is the goal; no station or board walk (B2)", function()
		t.expect(O.goal(facts())).toBe(nil) -- between calls: nothing to chase
		for done = 0, O.TUTORIAL_CALLS - 1 do
			t.expect(O.goal(facts({ callsCompleted = done, offerReady = true }))).toBe("Rescue")
		end
	end)

	t.test("after the last tutorial call the normal mix runs (B9)", function()
		t.expect(O.TUTORIAL_CALLS).toBe(#CallTypes.TutorialChain - 1)
		local after = facts({ callsCompleted = O.TUTORIAL_CALLS, offerReady = true })
		t.expect(O.goal(after)).toBe(nil)
	end)

	t.test("nothing holds offers back any more (B2, B7)", function()
		t.expect(O.holdsOffers).toBe(nil)
		t.expect(O.certDone).toBe(nil)
	end)

	t.test(
		"the tutorial chain: drifting craft with 1, then 2, then the seal pup (B3, B4, B9)",
		function()
			local chain = CallTypes.TutorialChain
			t.expect(chain[2].kind).toBe("DriftingCraft")
			t.expect(chain[2].victims).toBe(1)
			t.expect(chain[3].kind).toBe("DriftingCraft")
			t.expect(chain[3].victims).toBe(2)
			t.expect(chain[5].kind).toBe("WildlifeRescue")
		end
	)

	t.test("the cold open and three calls are fail-safe; later calls are not", function()
		for completed = 0, O.FAILSAFE_CALLS do
			t.expect(O.failsafeCall(completed)).toBe(true)
			local cas = { { condition = 4 }, { condition = 55 } }
			t.expect(O.protect(cas, completed)).toBe(true)
			t.expect(cas[1].condition).toBe(O.FAILSAFE_FLOOR)
			t.expect(cas[2].condition).toBe(55)
		end
		t.expect(O.failsafeCall(O.FAILSAFE_CALLS + 1)).toBe(false)
		local cas = { { condition = 4 } }
		t.expect(O.protect(cas, O.FAILSAFE_CALLS + 1)).toBe(false)
		t.expect(cas[1].condition).toBe(4)
	end)

	t.test("the HUD stays stripped through the cold open and three calls", function()
		t.expect(O.newPlayerHud(false, nil)).toBe(true)
		for done = 0, O.FAILSAFE_CALLS do
			t.expect(O.newPlayerHud(true, done)).toBe(true)
		end
		t.expect(O.newPlayerHud(true, O.FAILSAFE_CALLS + 1)).toBe(false)
		t.expect(O.newPlayerHud(true, 40)).toBe(false)
	end)

	t.test("only a rescued cold open gets the reward burst", function()
		t.expect(O.rewarded("Complete")).toBe(true)
		for _, reason in { "Timer", "Takeover", "LeftCraft", "Died", "Lost", nil } do
			t.expect(O.rewarded(reason)).toBe(false)
		end
	end)

	local function beat(over)
		local f = {
			coldOpenDone = false,
			totalRescues = 0,
			step = nil,
			owned = { Harbour = true, HQ = true }, -- the start set: the jetty and the free Hut
			constructionKey = nil,
			boatLevel = 1,
		}
		for k, v in over or {} do
			f[k] = v
		end
		return f
	end

	t.test("tutorial beats: cold open, rescue, upgrade, out again, spin, done (docs/30)", function()
		t.expect(O.beat(beat())).toBe("ColdOpen")
		t.expect(O.beat(beat({ coldOpenDone = true }))).toBe("Rescue")
		t.expect(O.beat(beat({ coldOpenDone = true, totalRescues = 1 }))).toBe("Upgrade")
		t.expect(O.beat(beat({ coldOpenDone = true, totalRescues = 1, boatLevel = 2 })))
			.toBe("OutAgain")
		t.expect(O.beat(beat({
			coldOpenDone = true,
			totalRescues = 2,
			boatLevel = 2,
			step = O.STEP_SPIN,
		}))).toBe("Spin")
		t.expect(O.beat(beat({ coldOpenDone = true, boatLevel = 2, step = O.STEP_DONE })))
			.toBe("Done")
	end)

	t.test("a trip counts from the helm away from home until any way home", function()
		local function trip(out, driving, home)
			return { O.trip(out, driving, home) }
		end
		t.expect(trip(false, false, true)).toEqual({ false, false }) -- in the bay
		t.expect(trip(false, false, false)).toEqual({ false, false }) -- swimming off: no trip
		t.expect(trip(false, true, false)).toEqual({ true, false })
		t.expect(trip(true, false, false)).toEqual({ true, false }) -- stepped off at sea: still out
		t.expect(trip(true, true, true)).toEqual({ false, true })
		-- a cancelled Go back or a ram leaves you out at sea: the trip holds and the next way home still ends it
		t.expect(trip(true, true, false)).toEqual({ true, false })
		t.expect(trip(true, false, true)).toEqual({ false, true })
		t.expect(trip(true, false, true)).toEqual({ false, true }) -- swam home
	end)

	-- every old tutorial state walks on with no Workshop beat: nothing here waits for a building or a held craft
	t.test("old saves on the Workshop beat continue, and the step never goes back", function()
		local order = { ColdOpen = 1, Rescue = 2, Upgrade = 3, OutAgain = 4, Spin = 5, Done = 6 }
		local shapes = {
			{ owned = { Harbour = true, HQ = true } },
			{ owned = { Harbour = true, HQ = true }, constructionKey = "Workshop" },
			{ owned = { Harbour = true, HQ = true, Workshop = true } },
			{ owned = { Harbour = true, HQ = true, Workshop = true }, constructionKey = "Depot" },
		}
		for _, shape in shapes do
			for _, step in { O.STEP_RESCUE, O.STEP_SITE } do
				local function at(level)
					return O.beat(beat({
						coldOpenDone = true,
						totalRescues = 1,
						step = step,
						owned = shape.owned,
						constructionKey = shape.constructionKey,
						boatLevel = level,
					}))
				end
				t.expect(at(1)).toBe("Upgrade")
				t.expect(at(2)).toBe("OutAgain")
				t.expect(at(11)).toBe("OutAgain") -- a pass floor already past L2
			end
			local last = 0
			for _, step in { O.STEP_RESCUE, O.STEP_SITE, O.STEP_SPIN, O.STEP_DONE } do
				local b = O.beat(beat({
					coldOpenDone = true,
					totalRescues = 1,
					step = step,
					owned = shape.owned,
					constructionKey = shape.constructionKey,
					boatLevel = 2,
				}))
				t.expect(order[b] >= last).toBe(true)
				last = order[b]
			end
			t.expect(last).toBe(order.Done)
		end
		-- no step, but a Workshop or 5 rescues: an established save, straight to the chip
		t.expect(O.beat(beat({ coldOpenDone = true, owned = { HQ = true, Workshop = true } })))
			.toBe("Done")
		-- a step wins: a new player's first building does not skip the rest
		t.expect(O.beat(beat({
			coldOpenDone = true,
			totalRescues = 1,
			step = O.STEP_RESCUE,
			owned = { HQ = true, Workshop = true },
		}))).toBe("Upgrade")
	end)

	t.test("factsOf reads a save or a snapshot", function()
		local f = O.factsOf({
			coldOpenDone = true,
			totalRescues = 3,
			tutorialStep = 2,
			dockBuildings = { HQ = true },
			construction = { key = "Depot" },
			boatLevel = 4,
		})
		t.expect(f.coldOpenDone).toBe(true)
		t.expect(f.totalRescues).toBe(3)
		t.expect(f.step).toBe(2)
		t.expect(f.owned.HQ).toBe(true)
		t.expect(f.constructionKey).toBe("Depot")
		t.expect(f.boatLevel).toBe(4)
		t.expect(O.factsOf({}, "HQ").constructionKey).toBe("HQ")
		t.expect(O.factsOf({}).totalRescues).toBe(0)
	end)

	t.test(
		"boat first: a fresh save starts on the cold open, never at the tablet or the Hut site",
		function()
			t.expect(O.beat(beat({ owned = {} }))).toBe("ColdOpen")
			t.expect(O.beat(beat({ owned = { Harbour = true } }))).toBe("ColdOpen")
			-- an old save that stood at the Hut site (the server grants the Hut on load) goes on the jet ski too
			t.expect(O.beat(beat({ owned = { Harbour = true }, constructionKey = "HQ" })))
				.toBe("ColdOpen")
			t.expect(O.beat(beat())).toBe("ColdOpen")
			t.expect(O.skip(beat({ owned = { Harbour = true } }))).toBe(false)
			-- the full order after it
			t.expect(O.beat(beat({ coldOpenDone = true, totalRescues = 1 }))).toBe("Upgrade")
			t.expect(O.beat(beat({ coldOpenDone = true, totalRescues = 1, boatLevel = 2 })))
				.toBe("OutAgain")
			t.expect(O.beat(beat({ coldOpenDone = true, step = O.STEP_SPIN }))).toBe("Spin")
			t.expect(O.beat(beat({ coldOpenDone = true, step = O.STEP_DONE }))).toBe("Done")
		end
	)

	t.test("a saved step never repeats an earlier beat", function()
		t.expect(O.beat(beat({ coldOpenDone = true, step = O.STEP_RESCUE }))).toBe("Upgrade")
		t.expect(O.beat(beat({
			coldOpenDone = true,
			step = O.STEP_SPIN,
			owned = { HQ = true, Workshop = true },
		}))).toBe("Spin")
	end)

	t.test("established starts at the Workshop: the jetty and the free Hut do not count", function()
		t.expect(O.established(nil)).toBe(false)
		t.expect(O.established({ Harbour = true, HQ = true })).toBe(false)
		t.expect(O.established({ Harbour = true, HQ = true, Workshop = false })).toBe(false)
		t.expect(O.established({ Harbour = true, HQ = true, Workshop = true })).toBe(true)
	end)

	t.test("an established save skips the tutorial; a started one does not", function()
		t.expect(O.skip(beat({ coldOpenDone = true, totalRescues = 5 }))).toBe(true)
		t.expect(O.skip(beat({ coldOpenDone = true, owned = { Pontoon = true } }))).toBe(true)
		t.expect(O.skip(beat({ coldOpenDone = true, step = O.STEP_SITE }))).toBe(false)
		t.expect(
			O.beat(beat({ coldOpenDone = true, totalRescues = 9, owned = { Pontoon = true } }))
		)
			.toBe("Done")
		t.expect(O.beat(beat({
			coldOpenDone = true,
			step = O.STEP_SITE,
			owned = { HQ = true, Pontoon = true },
			constructionKey = "Workshop",
		}))).toBe("Upgrade")
	end)

	t.test("Robux Finish-now waits for the Spin beat and never sells a free build", function()
		local hut = beat({ owned = { Harbour = true }, constructionKey = "HQ" })
		t.expect(O.finishNow(hut, 0)).toBe(false)
		t.expect(O.finishNow(hut, 3300)).toBe(false)
		local site = beat({
			coldOpenDone = true,
			totalRescues = 1,
			step = O.STEP_SITE,
			constructionKey = "Workshop",
		})
		t.expect(O.finishNow(site, 1000)).toBe(false)
		local spin = beat({
			coldOpenDone = true,
			step = O.STEP_SPIN,
			owned = { HQ = true, Workshop = true },
		})
		t.expect(O.finishNow(spin, 1000)).toBe(true)
		t.expect(O.finishNow(beat({ coldOpenDone = true, step = O.STEP_DONE }), 3300)).toBe(true)
		t.expect(O.finishNow(beat({ coldOpenDone = true, step = O.STEP_DONE }), 0)).toBe(false)
		-- an established save skips the tutorial
		t.expect(
			O.finishNow(
				beat({ coldOpenDone = true, totalRescues = 9, owned = { Pontoon = true } }),
				500
			)
		).toBe(true)
	end)

	t.test("the first survivor is a Builder until someone is home", function()
		t.expect(O.buildersFirst(0, nil, {})).toBe(true)
		t.expect(O.buildersFirst(0, nil, { Harbour = true, HQ = true })).toBe(true)
		t.expect(O.buildersFirst(0, nil, { Pontoon = true })).toBe(false)
		t.expect(O.buildersFirst(1, nil, {})).toBe(false)
		t.expect(O.buildersFirst(0, O.STEP_SITE, {})).toBe(false)
	end)
end
