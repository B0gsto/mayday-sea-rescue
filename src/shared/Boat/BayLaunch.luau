--!strict
-- BayLaunch (docs/16 K3, K11, K12): the bay's one Launch prompt and the returning player's spot.
-- Pure (tests/BayLaunch.spec.luau). Offsets are in the bay part's frame: the bays face out to sea, so
-- local -X is the jetty finger beside the bay (Marina.JETTY) and local +Z the quay end.
local BayLaunch = {}

BayLaunch.FLAG = "lastVehicle" -- data.flags: the craft the player last launched
BayLaunch.STAND = CFrame.new(-12, 0, 4) -- a returning player, on the pier beside their craft -- tune

-- The craft the Launch prompt spawns: the last one launched while it may still be used at this bay,
-- else the first usable one in shop order (the jet ski). nil: nothing usable here.
function BayLaunch.pick(last: any, order: { string }, usable: (string) -> boolean): string?
	if type(last) == "string" and usable(last) then
		return last
	end
	for _, id in order do
		if usable(id) then
			return id
		end
	end
	return nil
end

return BayLaunch
