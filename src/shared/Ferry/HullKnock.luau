--!strict
-- The capsized ferry's compartments and which one holds the air pocket. Pure, Lune-tested in
-- tests/MechFerryHull.spec.luau. Used by RescueService (the ferry's AirPocket mark).

local HullKnock = {}

HullKnock.Compartments = {
	{ name = "Bow thruster room", short = "Bow" },
	{ name = "Forward saloon", short = "Fwd saloon" },
	{ name = "Midships car deck", short = "Midships" },
	{ name = "Aft lounge", short = "Aft lounge" },
	{ name = "Engine room", short = "Engine room" },
}

HullKnock.Count = #HullKnock.Compartments

-- The compartment holding the air pocket, from the operation id (deterministic, the server can
-- recompute it). Never the bow or the engine room: the pocket forms where the open decks are.
function HullKnock.pocketCompartment(opId: string): number
	local h = 0
	for i = 1, #opId do
		h = (h * 31 + string.byte(opId, i)) % 2147483647
	end
	return 2 + (h % 3) -- 2, 3 or 4
end

-- Offset of compartment i along the hull's length (local Z), for a hull `length` studs long;
-- compartment 1 is at the bow (-Z).
function HullKnock.offsetAlong(i: number, length: number): number
	local n = HullKnock.Count
	return -length / 2 + (i - 0.5) * (length / n)
end

-- Which compartment a point `along` studs from the hull centre is over.
function HullKnock.compartmentAt(along: number, length: number): number
	local n = HullKnock.Count
	local i = math.floor((along + length / 2) / (length / n)) + 1
	return math.clamp(i, 1, n)
end

return HullKnock
