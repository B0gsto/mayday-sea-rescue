--!strict
-- Triage sieve for the Capsized Ferry (docs/09 section 7 step 4). Pure: Lune-tested in
-- tests/MechFerryTriage.spec.luau, used by src/client/Mechanics/triage.luau and the server.
--
-- The real UK sieve (verify: NARU / NHS major incident guidance) in the order a medic runs it:
--   1. Can they walk?                      yes -> P3 (Green, "can wait")
--   2. Breathing? (open the airway first)  every casualty in the game is breathing (all ages)
--   3. Responsive? (voice, shoulder tap)   no  -> P1 (Red, "immediate")
--   4. Breathing rate (breaths a minute)   under 10 or 30 and over -> P1
--   5. Circulation: capillary refill       over 2 seconds -> P1
--   otherwise                              -> P2 (Yellow, "urgent")
-- The tag strings sent to the server stay "Red"/"Yellow"/"Green" (CONTRACT.md); the player sees
-- "P1 Immediate", "P2 Urgent", "P3 Can wait". There is no black / expectant tag anywhere.
-- Observations are generated so the sieve always agrees with Operations.triageTag(state), which
-- is what the server checks.

local Triage = {}

export type Tag = "Red" | "Yellow" | "Green"
export type Avpu = "Alert" | "Voice" | "Pain" | "Unresponsive"

export type Observation = {
	walks: boolean,
	breathing: boolean, -- always true in game; kept so the sieve reads like the real one
	airwayOpened: boolean, -- needs the head tilt / chin lift before breathing is seen
	avpu: Avpu,
	rate: number, -- breaths a minute
	refill: number, -- capillary refill seconds
	cue: string, -- body language / speech line (docs 09 section 2.3)
}

Triage.Tags = { "Red", "Yellow", "Green" } :: { Tag }

Triage.Display = {
	Red = {
		code = "P1",
		name = "P1 Immediate",
		short = "Immediate",
		colour = Color3.fromRGB(214, 48, 49),
	},
	Yellow = {
		code = "P2",
		name = "P2 Urgent",
		short = "Urgent",
		colour = Color3.fromRGB(242, 196, 15),
	},
	Green = {
		code = "P3",
		name = "P3 Can wait",
		short = "Can wait",
		colour = Color3.fromRGB(46, 160, 67),
	},
}

Triage.RateLow = 10 -- under 10 a minute is P1
Triage.RateHigh = 30 -- 30 a minute and over is P1
Triage.RefillLimit = 2 -- seconds

-- Deterministic 0..1 noise from an integer seed (no math.random so tests stay stable).
local function noise(seed: number, salt: number): number
	local x = math.sin(seed * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- The cues a casualty in this state shows the medic. `seed` varies the numbers per casualty.
function Triage.observe(state: string, seed: number): Observation
	local r1, r2, r3 = noise(seed, 1), noise(seed, 2), noise(seed, 3)
	if state == "Alert" then
		return {
			walks = true,
			breathing = true,
			airwayOpened = true,
			avpu = "Alert",
			rate = math.floor(lerp(14, 22, r1)),
			refill = lerp(0.8, 1.6, r2),
			cue = 'Shivering, talking fast: "I\'m fine, I can walk, help the others."',
		}
	elseif state == "Exhausted" or state == "Panicking" then
		return {
			walks = false,
			breathing = true,
			airwayOpened = true,
			avpu = if r3 < 0.5 then "Alert" else "Voice",
			rate = math.floor(lerp(18, 27, r1)),
			refill = lerp(1.0, 1.8, r2),
			cue = 'Slumped on the deck, arms heavy: "My legs won\'t hold me."',
		}
	elseif state == "VeryCold" then
		-- moderate hypothermia: slow breathing or poor circulation, still answers to voice
		local slow = r3 < 0.5
		return {
			walks = false,
			breathing = true,
			airwayOpened = true,
			avpu = "Voice",
			rate = if slow then math.floor(lerp(6, 9, r1)) else math.floor(lerp(12, 18, r1)),
			refill = if slow then lerp(1.4, 1.9, r2) else lerp(2.6, 3.8, r2),
			cue = 'Not shivering any more, pale lips, slurred: "m-m-my hands..."',
		}
	end
	-- Unresponsive (and anything unknown): face up in the lifejacket, eyes closed
	return {
		walks = false,
		breathing = true,
		airwayOpened = false,
		avpu = if r3 < 0.5 then "Pain" else "Unresponsive",
		rate = math.floor(lerp(10, 16, r1)),
		refill = lerp(1.8, 2.8, r2),
		cue = "Eyes closed in the lifejacket, no answer when you call.",
	}
end

-- The sieve: the tag these observations call for.
function Triage.sieve(o: Observation): Tag
	if o.walks then
		return "Green"
	end
	if o.avpu == "Pain" or o.avpu == "Unresponsive" then
		return "Red"
	end
	if o.rate < Triage.RateLow or o.rate >= Triage.RateHigh then
		return "Red"
	end
	if o.refill > Triage.RefillLimit then
		return "Red"
	end
	return "Yellow"
end

-- The real sieve order. A medic may stop as soon as a check decides the tag.
Triage.Checks = { "walk", "airway", "responsive", "rate", "refill" }

-- The checks the sieve needs before the tag is decided (for grading the order and for hints).
function Triage.checksNeeded(o: Observation): { string }
	if o.walks then
		return { "walk" }
	end
	local out = { "walk", "airway" }
	if o.avpu == "Pain" or o.avpu == "Unresponsive" then
		table.insert(out, "responsive")
		return out
	end
	table.insert(out, "responsive")
	table.insert(out, "rate")
	if o.rate < Triage.RateLow or o.rate >= Triage.RateHigh then
		return out
	end
	table.insert(out, "refill")
	return out
end

-- True when every check done follows the sieve order (skipping ahead is fine once decided).
function Triage.orderFollowed(done: { string }): boolean
	local last = 0
	for _, c in done do
		local i = table.find(Triage.Checks, c)
		if not i or i < last then
			return false
		end
		last = i
	end
	return true
end

-- Breath counting: the medic counts over 15 s and multiplies by 4. The game runs the 15 s at
-- `speed` x. Returns the rises the player should see and the estimate from the taps.
function Triage.risesIn15(rate: number): number
	return math.max(1, math.floor(rate / 4 + 0.5))
end

function Triage.estimateRate(taps: number): number
	return taps * 4
end

-- How far off a counted rate is, as a fraction of the true rate (0 = exact).
function Triage.countError(trueRate: number, counted: number): number
	if trueRate <= 0 then
		return 0
	end
	return math.abs(counted - trueRate) / trueRate
end

-- Condition drift factor while a casualty waits for transport, given the tag they wear and the
-- tag they need (server proposal, CONTRACT.md "Ferry"): an under-triaged casualty is moved late
-- and declines faster; over-triage costs nothing for them (it delays someone else instead).
function Triage.driftFactor(worn: string?, needed: string): number
	if worn == nil then
		return 1
	end
	local rank = { Red = 1, Yellow = 2, Green = 3 }
	local w, n = rank[worn] or 3, rank[needed] or 3
	if w > n then
		return 1 + 0.35 * (w - n) -- one band too low x1.35, two bands x1.7
	end
	return 1
end

-- Evacuation order: Red, then Yellow, then Green; ties by lower condition first.
function Triage.evacuationOrder(
	list: { { tag: string?, condition: number, index: number } }
): { number }
	local rank = { Red = 1, Yellow = 2, Green = 3 }
	local copy = table.clone(list)
	table.sort(copy, function(a, b)
		local ra, rb = rank[a.tag or "Green"] or 4, rank[b.tag or "Green"] or 4
		if ra ~= rb then
			return ra < rb
		end
		if a.condition ~= b.condition then
			return a.condition < b.condition
		end
		return a.index < b.index
	end)
	local out = {}
	for _, c in copy do
		table.insert(out, c.index)
	end
	return out
end

return Triage
