--!strict
-- CliffRules: pure cliff-casualty logic (docs/09 section 8.5, docs/13 LU-2): the Haven Head site,
-- which recovery route the player is set up for, and the two-hand haul rhythm. Client + server.
-- Tested by tests/Cliff.spec.luau.

export type Haul = {
	total: number,
	done: number,
	pulls: number, -- counted pulls, so a slip never stalls the rhythm at the same count
	last: string?, -- "L" | "R"
	wrong: number,
	slips: number,
	storm: boolean,
}

local CliffRules = {}

-- The ledge at the foot of Haven Head (a placed M_Rock_Ledge waterline shelf) and the cliff-top
-- rescue point above it, by the HavenHeadTrack. Numbers read off map/generated terrain.
CliffRules.SITE = table.freeze({
	foot = Vector3.new(1740, 22, 890),
	top = Vector3.new(1740, 120, 827),
	anchor = Vector3.new(1740, 121, 820),
	ambulance = Vector3.new(1722, 118, 800),
})

CliffRules.FOOT_RADIUS = 34 -- studs: close enough to the casualty to work on them
CliffRules.TOP_RADIUS = 20 -- studs: close enough to the anchor to haul
CliffRules.BOAT_RANGE = 70 -- studs from the casualty: a boat this close is the way out
CliffRules.BOAT_SPEED = 8 -- studs/s: the boat must be slow alongside
CliffRules.HAUL_PULLS = 10 -- alternating pulls to bring them up
CliffRules.SLIP_EVERY = 4 -- in a swell, every n-th pull slips back one

function CliffRules.flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Is the casualty inside the boat's hull/deck volume (aboard), in the hull's own frame?
-- The carry only counts once they are over the deck, not merely alongside the boat.
function CliffRules.onDeck(point: Vector3, hullCFrame: CFrame, hullSize: Vector3): boolean
	local p = hullCFrame:PointToObjectSpace(point)
	local half = hullSize * 0.5
	return math.abs(p.X) <= half.X
		and math.abs(p.Z) <= half.Z
		and p.Y >= -half.Y - 2
		and p.Y <= half.Y + 2
end

function CliffRules.near(pos: Vector3, point: Vector3, radius: number): boolean
	return CliffRules.flatDistance(pos, point) <= radius
end

-- "boat" when the player is down at the casualty and their boat is alongside; else the line.
function CliffRules.routeFor(playerPos: Vector3, boatDistance: number?): string
	if
		CliffRules.near(playerPos, CliffRules.SITE.foot, CliffRules.FOOT_RADIUS)
		and boatDistance ~= nil
		and boatDistance <= CliffRules.BOAT_RANGE
	then
		return "boat"
	end
	return "line"
end

function CliffRules.newHaul(total: number?, storm: boolean?): Haul
	return {
		total = total or CliffRules.HAUL_PULLS,
		done = 0,
		pulls = 0,
		last = nil,
		wrong = 0,
		slips = 0,
		storm = storm == true,
	}
end

-- One hand pull. Alternating hands count; the same hand twice does not. In a swell every
-- SLIP_EVERY-th counted pull slides back one (the set catches the line; nobody is hurt).
function CliffRules.pull(h: Haul, side: string): boolean
	if h.done >= h.total then
		return true
	end
	if h.last == side then
		h.wrong += 1
		return false
	end
	h.last = side
	h.done += 1
	h.pulls += 1
	if h.storm and h.pulls % CliffRules.SLIP_EVERY == 0 and h.done < h.total then
		h.done -= 1
		h.slips += 1
	end
	return true
end

function CliffRules.complete(h: Haul): boolean
	return h.done >= h.total
end

function CliffRules.haulScore(h: Haul): number
	local share = if h.total > 0 then h.done / h.total else 0
	return math.clamp(share - h.wrong * 0.04 - h.slips * 0.03, 0, 1)
end

-- Carrying them to a boat alongside: quicker is better; a swell costs a quarter of the score.
function CliffRules.carryScore(seconds: number, storm: boolean?): number
	local base = math.clamp(1 - math.max(0, seconds) / 30, 0, 1)
	return if storm then base * 0.75 else base
end

return CliffRules
