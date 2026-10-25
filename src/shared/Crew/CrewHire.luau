--!strict
-- CrewHire (docs/23 (j), WP-15): the late-game crew rules. Pure data + math, safe to load in
-- Lune (tests/CrewHire.spec.luau). Hiring unlocks with the dock Lv 5 station built AND rank
-- Coxswain or higher; the job-seeker line outside the player's station is replaced by a new
-- group every ROTATE_SECONDS of the server clock (group = floor(now / ROTATE_SECONDS); the
-- client clock on the station door counts down with the same os.time epochs). Each role has a
-- Cash hire price and a daily wage (the late-game Cash sink, docs/23 (i)): CrewHireService
-- takes the wage off data.cash at the start of each play session, never below 0. Max one per
-- role. The three effect knobs below are read by one-liners in VehicleService,
-- AmbientRescueService and OperationService; they only apply while the owner is in the server.
local ProgressionConfig = require(script.Parent.Parent.Config.ProgressionConfig)

export type Role = {
	id: string,
	glyph: string, -- client Glyph kind (src/client/UI/Glyph)
	price: number, -- Cash to hire
	wage: number, -- Cash deducted at the start of each session while hired
}

local CrewHire = {}

CrewHire.ROTATE_SECONDS = 20 * 60 -- docs/23 (j): a new group of seekers every 20 minutes

CrewHire.LINE_SIZE = 4 -- every role once, plus one repeat

CrewHire.Order = { "Mechanic", "Lifeguard", "Dispatcher" }

CrewHire.Roles = {
	Mechanic = { id = "Mechanic", glyph = "speed", price = 12000, wage = 400 }, -- tune
	Lifeguard = { id = "Lifeguard", glyph = "ring", price = 9000, wage = 300 }, -- tune
	Dispatcher = { id = "Dispatcher", glyph = "flare", price = 15000, wage = 500 }, -- tune
} :: { [string]: Role }

-- docs/23 (j): small effects, never replacing play.
CrewHire.MechanicCooldown = 0.7 -- Boat to me cooldown x0.7 (VehicleService, VehiclesApp)
CrewHire.DispatchFactor = 0.8 -- call offers 20% sooner (OperationService)
CrewHire.LifeguardSwimmers = 1 -- one extra free-roam swimmer near the owner's island

CrewHire.STATION_LEVEL = 5 -- the dock Lv 5 station (DockConfig.MAX)

CrewHire.COXSWAIN_INDEX = (function()
	for i, r in ProgressionConfig.Ranks do
		if r.id == "Coxswain" then
			return i
		end
	end
	return 4
end)()

-- Unlock: the dock Lv 5 station built and rank Coxswain or higher (tune).
function CrewHire.unlocked(dockLevel: number, rankIndex: number): boolean
	return dockLevel >= CrewHire.STATION_LEVEL and rankIndex >= CrewHire.COXSWAIN_INDEX
end

-- Which 20-minute group `now` (os.time) belongs to, and when the next one arrives.
function CrewHire.groupIndex(now: number): number
	return math.floor(now / CrewHire.ROTATE_SECONDS)
end

function CrewHire.nextGroupAt(now: number): number
	return (CrewHire.groupIndex(now) + 1) * CrewHire.ROTATE_SECONDS
end

-- A tiny deterministic LCG: the same (seed, group) always gives the same line. Multipliers stay
-- under 2^53 so the arithmetic is exact on Luau's doubles.
local function random(state: number): (number, number)
	local s = (state * 48271) % 2147483647
	return s / 2147483647, s
end

-- The seekers standing outside the station for one group: every role once, the last slot a
-- repeat, each with 1..3 skill stars. Deterministic per owner (seed = their UserId) and group.
function CrewHire.lineup(seed: number, group: number): { { role: string, stars: number } }
	local state = (math.floor(math.abs(seed)) + group * 2654435761) % 2147483647
	if state == 0 then
		state = 1
	end
	local out = {}
	for i = 1, CrewHire.LINE_SIZE do
		local r, nextState = random(state)
		state = nextState
		local role = if i <= #CrewHire.Order
			then CrewHire.Order[i]
			else CrewHire.Order[1 + math.floor(r * #CrewHire.Order) % #CrewHire.Order]
		local s, nextState2 = random(state)
		state = nextState2
		table.insert(out, { role = role, stars = 1 + math.floor(s * 3) })
	end
	return out
end

-- ok, reason: may the player hire this role? (The Cash path; Robux hire is the
-- MonetizationConfig CrewHire product with ready = false, so its grant path lands later.)
function CrewHire.canHire(
	role: string,
	hired: { [string]: boolean },
	cash: number
): (boolean, string, number)
	local def = CrewHire.Roles[role]
	if not def then
		return false, "Unknown", 0
	end
	if hired[role] then
		return false, "Hired", def.price
	end
	if cash < def.price then
		return false, "Cash", def.price
	end
	return true, "ok", def.price
end

-- The wage for the whole crew, deducted at the start of each session (never below 0).
function CrewHire.dailyWage(hired: { [string]: boolean }): number
	local total = 0
	for role, yes in hired do
		local def = CrewHire.Roles[role]
		if yes and def then
			total += def.wage
		end
	end
	return total
end

-- The three effect knobs, from the hired set (CrewHireService passes data.crew).
function CrewHire.boatToMeScale(hired: { [string]: boolean }): number
	return if hired.Mechanic then CrewHire.MechanicCooldown else 1
end

function CrewHire.offerFactor(hired: { [string]: boolean }): number
	return if hired.Dispatcher then CrewHire.DispatchFactor else 1
end

function CrewHire.extraSwimmers(hired: { [string]: boolean }): number
	return if hired.Lifeguard then CrewHire.LifeguardSwimmers else 0
end

return table.freeze(CrewHire)
