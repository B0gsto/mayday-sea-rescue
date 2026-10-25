--!strict
-- Marina (docs/23 (k), WP-19b): the six player islands are the plots, one per player (server size 6). Pure
-- (tests/Marina.spec.luau). Plot i = HubLayout.Islands[i] (Plot1..Plot6): its boat berth in the cove, its lots.
-- Berth frame (what VehicleService, BayLaunch and DockPieces read): the island's boat berth at sea level,
-- LookVector = out of the cove, local -X = the jetty (the finger beside the craft), local +Z = the quay.
-- Every island is the same shape turned round the hub, so a lot sits at the same place in its berth frame:
-- Marina.LOTS[name] = { cf = the lot's CFrame in the berth frame (on the plateau), size = Vector2 }.
local HubLayout = require(script.Parent:WaitForChild("Config"):WaitForChild("HubLayout"))

local Marina = {}

Marina.COUNT = #HubLayout.Islands -- server size (docs/23 (k))
Marina.BERTH = 55 -- the berth's length (a lifeboat is 52 long)
Marina.DECK_TOP = HubLayout.PlateauY -- the jetty and the quay
Marina.JETTY = { x0 = -17, x1 = -9, out = -20, z1 = 30 } -- berth frame: the finger the player stands on (BayLaunch.STAND)

local ISLE = HubLayout.Islands[1]
local B0 = ISLE.berths.Boat
Marina.LOTS = {} :: { [string]: { cf: CFrame, size: Vector2 } }
for name, lot in ISLE.lots do
	Marina.LOTS[name] = { cf = B0:ToObjectSpace(lot.cframe), size = lot.size }
end
Marina.SUB = B0:ToObjectSpace(ISLE.berths.Sub) -- the sub berth (in the sub pen), at sea level
Marina.ISLAND = B0:ToObjectSpace(ISLE.frame) -- the island's centre on the plateau, LookVector = out from the hub

-- The berth CFrame of plot i (1..COUNT), at sea level.
function Marina.berth(i: number): CFrame
	return HubLayout.Islands[i].berths.Boat
end

-- Where plot i's owner spawns and respawns (on their island, off the bridge, facing the station).
function Marina.spawn(i: number): CFrame
	return HubLayout.Islands[i].spawn
end

-- The lowest free plot (taken[i] truthy = in use), nil when all are taken.
function Marina.assign(taken: { [number]: any }): number?
	for i = 1, Marina.COUNT do
		if not taken[i] then
			return i
		end
	end
	return nil
end

-- The Harbour Master: the most people rescued among islands with a Station (docs/23 (q)); a tie keeps
-- `current`, else the first listed.
export type Candidate = { key: any, rescued: number, station: boolean }
function Marina.harbourMaster(candidates: { Candidate }, current: any?): any?
	local best: Candidate? = nil
	for _, c in candidates do
		if
			c.station
			and (
				not best
				or c.rescued > best.rescued
				or (c.rescued == best.rescued and c.key == current)
			)
		then
			best = c
		end
	end
	return if best then best.key else nil
end

-- Per-berth spawn lock (docs/23 c.1): true and taken when free; false while another spawn holds it.
function Marina.lock(locks: { [any]: boolean }, key: any): boolean
	if locks[key] then
		return false
	end
	locks[key] = true
	return true
end

-- A flag colour per player (stable across sessions): golden-ratio hues, bright and saturated.
function Marina.flagColor(userId: number): Color3
	return Color3.fromHSV((math.abs(userId) * 0.618034) % 1, 0.75, 0.95)
end

return Marina
