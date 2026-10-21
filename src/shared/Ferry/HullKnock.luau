--!strict
-- Hull search helpers (docs/09 section 7 step 5). Pure, Lune-tested in
-- tests/MechFerryHull.spec.luau. Used by RescueService (the ferry's AirPocket mark).
--
-- Real practice (verify: USCG / fire service capsized-vessel guidance): rescuers on an upturned
-- hull knock a clear pattern, then stay still and listen; trapped survivors answer by tapping.
-- The answer is loudest over the compartment they are in.

local HullKnock = {}

HullKnock.Compartments = {
	{ name = "Bow thruster room", short = "Bow" },
	{ name = "Forward saloon", short = "Fwd saloon" },
	{ name = "Midships car deck", short = "Midships" },
	{ name = "Aft lounge", short = "Aft lounge" },
	{ name = "Engine room", short = "Engine room" },
}

HullKnock.Count = #HullKnock.Compartments
HullKnock.KnocksInPattern = 3
HullKnock.MinGap = 0.25 -- seconds between knocks
HullKnock.MaxGap = 1.1
HullKnock.MaxUneven = 0.45 -- the two gaps may differ by at most this fraction
HullKnock.ListenSeconds = 2.5

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

-- Is a list of knock times (seconds, ascending) a clean pattern of three?
-- Returns ok, and a short hint when not.
function HullKnock.rhythm(times: { number }): (boolean, string?)
	if #times < HullKnock.KnocksInPattern then
		return false, "Knock three times"
	end
	local n = #times
	local g1 = times[n - 1] - times[n - 2]
	local g2 = times[n] - times[n - 1]
	if g1 < HullKnock.MinGap or g2 < HullKnock.MinGap then
		return false, "Too fast: give each knock a beat"
	end
	if g1 > HullKnock.MaxGap or g2 > HullKnock.MaxGap then
		return false, "Too slow: keep the three knocks together"
	end
	if math.abs(g1 - g2) / math.max(g1, g2) > HullKnock.MaxUneven then
		return false, "Keep the knocks even"
	end
	return true, nil
end

-- What the hull team hears after a clean pattern knocked over `at`, with the survivors in
-- `pocket`: loud (right compartment), faint with a direction (one away), or nothing.
export type Reply = {
	strength: number,
	kind: "Loud" | "Faint" | "None",
	towards: "forward" | "aft" | nil,
}

function HullKnock.reply(at: number, pocket: number): Reply
	local d = math.abs(at - pocket)
	if d == 0 then
		return { strength = 1, kind = "Loud", towards = nil }
	elseif d == 1 then
		return {
			strength = 0.35,
			kind = "Faint",
			towards = if pocket < at then "forward" else "aft",
		}
	end
	return { strength = 0, kind = "None", towards = nil }
end

function HullKnock.subtitle(r: Reply): string
	if r.kind == "Loud" then
		return "[Three taps answer, right under your feet]"
	elseif r.kind == "Faint" then
		return `[Faint tapping, somewhere {r.towards}]`
	end
	return "[Only the sea slapping against the hull]"
end

return HullKnock
