-- Drop-off zone (ColdOpen.atDropOff): survivors climb off any of your craft anywhere in your cove (round your
-- berth), moving or docked (RescueService.checkDeliveries, OperationService isHome, client transport).
return function(t)
	local ColdOpen = t.load("src/shared/Boat/ColdOpen.luau")
	local HubLayout = t.load("src/shared/Config/HubLayout.luau")
	local R = ColdOpen.DROP_RADIUS

	t.test(
		"your whole cove counts: the berth, the craft kept beside it, the jetty, the quay",
		function()
			for i, island in HubLayout.Islands do
				local bay = island.berths.Boat -- player attribute BayCFrame
				local function cove(right: number, fwd: number): Vector3
					return (island.frame * CFrame.new(right, 0, -fwd)).Position
				end
				t.expect(ColdOpen.atDropOff(bay.Position, bay)).toBe(true) -- docked in the berth
				t.expect(ColdOpen.atDropOff((bay * CFrame.new(10.5, 0, 0)).Position, bay))
					.toBe(true) -- second craft, pontoon
				t.expect(ColdOpen.atDropOff(cove(0, 68), bay)).toBe(true) -- alongside the jetty
				t.expect(ColdOpen.atDropOff(cove(0, 32), bay)).toBe(true) -- at the quay
				t.expect(ColdOpen.atDropOff(cove(0, 150), bay)).toBe(true) -- coming in at the cove mouth
				t.expect(ColdOpen.atDropOff(bay.Position, bay.Position)).toBe(true) -- a Vector3 bay works too
				-- outside: past the zone's edge, with no berth, or at someone else's berth
				t.expect(ColdOpen.atDropOff(bay.Position + bay.LookVector * (R + 1), bay))
					.toBe(false)
				t.expect(ColdOpen.atDropOff(bay.Position, nil)).toBe(false)
				local other = HubLayout.Islands[i % #HubLayout.Islands + 1].berths.Boat
				t.expect(ColdOpen.atDropOff(other.Position, bay)).toBe(false)
			end
		end
	)

	t.test("only your berth: the lagoon is no drop-off (docs/23 (p))", function()
		t.expect(
			ColdOpen.atDropOff(
				HubLayout.Center * Vector3.new(1, 0, 1),
				HubLayout.Islands[1].berths.Boat
			)
		).toBe(false)
		t.expect(ColdOpen.dropOff(nil)).toBe(nil)
	end)
end
