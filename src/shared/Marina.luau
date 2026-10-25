--!strict
-- Marina (docs/23 d.1, WP-1): the 16 player plots, one per player. Pure (tests/Marina.spec.luau).
-- Port Haven's basin has no free 400-stud shoreline (pier, slipways, pontoons, moorings), so the marina sits
-- on the beach just west of the west breakwater: a pontoon spine runs out to sea (+Z) from the beach at
-- x SPINE_X, odd plots east of it (bow +X), even plots west (bow -X), 8 per row, each WIDTH along the spine.
-- A plot = a shore strip (DECK, the deck beside the spine) + a water berth (BERTH) in front of it.
-- Berth frame (what VehicleService and BayLaunch read): LookVector = out to sea, local +X = the jetty finger
-- beside the craft, local +Z = the deck / spine end. The plot spans local x -21..29.
local Marina = {}

Marina.COUNT = 16 -- server size (docs/01)
Marina.SPINE_X = -500
Marina.SPINE_W = 8
Marina.ROOT_Z = 4 -- the spine starts on the beach
Marina.Z0 = 80 -- first plots' shore-side edge (the rocks west of the spine end at z ~74)
Marina.WIDTH = 50 -- along the spine
Marina.DECK = 25 -- shore strip, spine to the berth
Marina.BERTH = 55 -- water, deck edge out (a lifeboat is 52 long)
Marina.DECK_TOP = 3
Marina.JETTY = { x0 = 10, x1 = 18, out = -20 } -- berth frame: the finger the player stands on (BayLaunch.STAND)
Marina.PLOT_X = { -21, 29 } -- berth frame: the plot's sides

local OFFSET = (Marina.PLOT_X[1] + Marina.PLOT_X[2]) / 2 -- berth centre sits this far from the plot centre

-- The berth CFrame of plot i (1..COUNT), at sea level.
function Marina.berth(i: number): CFrame
	local k = (i - 1) // 2
	local side = if i % 2 == 1 then 1 else -1
	local look = Vector3.new(side, 0, 0)
	local x = Marina.SPINE_X + side * (Marina.SPINE_W / 2 + Marina.DECK + Marina.BERTH / 2)
	local right = look:Cross(Vector3.yAxis)
	local pos = Vector3.new(x, 0, Marina.Z0 + Marina.WIDTH * (k + 0.5)) - right * OFFSET
	return CFrame.lookAt(pos, pos + look)
end

-- Car garages (docs/23 h, WP-10b): the beach strip at the spine root is ~18 studs deep (cars are ~28 long), so
-- the row of 16 bays stands on the open grass along Penhallow Road's west kerb (WorldConfig PortHaven_Av1),
-- across Harbour Road from the walkway root: bay i's door opens east onto the road, bay 1 nearest the
-- harbour. A bay is WIDTH across (along the kerb) and DEPTH deep (west, away from the road); floor top at Y.
Marina.GARAGE = { X = -562, Z0 = -46, WIDTH = 14, DEPTH = 30, Y = 6.1 }

-- Garage i's frame: the door's centre at floor level, LookVector out of the door onto the road (+X),
-- local +Z = into the bay, local +X = along the kerb (south, toward the harbour).
function Marina.garage(i: number): CFrame
	local g = Marina.GARAGE
	local pos = Vector3.new(g.X, g.Y, g.Z0 - g.WIDTH * (i - 0.5))
	return CFrame.lookAt(pos, pos + Vector3.xAxis)
end

-- The far end of the spine (past the last pair of plots).
function Marina.spineEndZ(): number
	return Marina.Z0 + Marina.WIDTH * math.ceil(Marina.COUNT / 2)
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
