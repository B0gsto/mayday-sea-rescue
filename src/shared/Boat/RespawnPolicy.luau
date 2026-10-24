--!strict
-- Boat/RespawnPolicy (stream B): when VehicleService may remove (despawn, or replace with a fresh
-- build) a player's vehicle. Pure and Lune-tested (tests/BoatRespawn.spec.luau).
--
-- 1. Never with someone aboard. A vehicle with a seated rider is never removed, and neither is
--    one ridden within OCCUPIED_GRACE seconds: a seat weld can drop for a frame while the hull
--    pitches over a wave, and a player who hops off for a moment must find the craft where they
--    left it. Survivors aboard or a tow line count as aboard too.
-- 2. One record per player per vehicle class. A spawn of class X with an X already owned asks
--    planSpawn: Build (none yet), Replace (the old one may go), Reuse (scripted spawns, e.g. the
--    cold open, keep the craft the player is on instead of building a second one) or Refuse.
-- 3. Removal reasons:
--    Request   the player explicitly asked for a fresh vehicle (desk, trailer launch): allowed
--              unless someone is aboard right now.
--    Scripted  a server flow (cold open) wants this class at a spot: allowed only when nobody is
--              aboard and nobody was within OCCUPIED_GRACE; otherwise the caller reuses it.
--    Idle      the periodic sweep: unoccupied for IDLE_DESPAWN while adrift (a docked current
--              vehicle waits at its bay for good), or SUPERSEDED_IDLE once it is no longer the
--              owner's current vehicle. Both scale by idleScale (Crowding.scale: a busy server
--              clears sooner), and then a docked current vehicle goes too (bays are scarce).
--    Wrecked   sunk, out of bounds or flagged Wrecked, unoccupied past the grace and at least
--              STUCK_DISTANCE from its owner (or the owner has no character).
--    OwnerLeft the owner left the server: always.

local RespawnPolicy = {}

RespawnPolicy.OCCUPIED_GRACE = 15 -- s after the last rider left -- tune
RespawnPolicy.IDLE_DESPAWN = 600 -- s adrift and unoccupied before the current vehicle is cleared -- tune
RespawnPolicy.SUPERSEDED_IDLE = 120 -- s for a vehicle that is no longer the owner's current one -- tune
RespawnPolicy.STUCK_DISTANCE = 300 -- studs from the owner before a wreck may be cleared -- tune

export type Reason = "Request" | "Scripted" | "Idle" | "Wrecked" | "OwnerLeft"
export type Plan = "Build" | "Replace" | "Reuse" | "Refuse"

export type State = {
	occupied: boolean, -- a rider in any seat right now
	carrying: boolean?, -- survivors aboard, towing or being towed
	lastOccupiedAt: number?, -- when the last rider left (nil: never ridden)
	spawnedAt: number,
	docked: boolean?,
	current: boolean?, -- the owner's current vehicle (VehicleService.GetVehicle)
	wrecked: boolean?, -- sunk, out of bounds or flagged Wrecked
	ownerDistance: number?, -- studs to the owner's character (nil: no character)
	idleScale: number?, -- Crowding.scale(players): 1 (default) solo, smaller on a busy server
}

-- Seconds since anyone was aboard (or since the spawn, when never ridden).
function RespawnPolicy.idleFor(state: State, now: number): number
	if state.occupied then
		return 0
	end
	return math.max(0, now - (state.lastOccupiedAt or state.spawnedAt))
end

-- Aboard now, or within OCCUPIED_GRACE seconds of the last rider leaving.
function RespawnPolicy.recentlyOccupied(state: State, now: number): boolean
	if state.occupied then
		return true
	end
	local left = state.lastOccupiedAt
	return left ~= nil and now - left < RespawnPolicy.OCCUPIED_GRACE
end

-- May the vehicle be removed for `reason`? Returns (allowed, why).
function RespawnPolicy.mayRemove(reason: Reason, state: State, now: number): (boolean, string)
	if reason == "OwnerLeft" then
		return true, "OwnerLeft"
	end
	if state.occupied then
		return false, "Occupied"
	end
	if reason == "Request" then
		return true, "Request"
	end
	if state.carrying then
		return false, "Carrying"
	end
	if RespawnPolicy.recentlyOccupied(state, now) then
		return false, "RecentlyOccupied"
	end
	if reason == "Scripted" then
		return true, "Scripted"
	elseif reason == "Idle" then
		local scale = state.idleScale or 1
		local limit = if state.current == false
			then RespawnPolicy.SUPERSEDED_IDLE * scale
			elseif state.docked and scale >= 1 then math.huge
			else RespawnPolicy.IDLE_DESPAWN * scale
		if RespawnPolicy.idleFor(state, now) >= limit then
			return true, "Idle"
		end
		return false, "NotIdle"
	elseif reason == "Wrecked" then
		if not state.wrecked then
			return false, "NotWrecked"
		end
		local d = state.ownerDistance
		if d ~= nil and d < RespawnPolicy.STUCK_DISTANCE then
			return false, "OwnerNearby"
		end
		return true, "Wrecked"
	end
	return false, "UnknownReason"
end

-- What a spawn of a class should do with the owner's existing vehicle of that class (nil: none).
function RespawnPolicy.planSpawn(reason: Reason, existing: State?, now: number): (Plan, string)
	if existing == nil then
		return "Build", "None"
	end
	local ok, why = RespawnPolicy.mayRemove(reason, existing, now)
	if ok then
		return "Replace", why
	end
	if reason == "Scripted" then
		return "Reuse", why
	end
	return "Refuse", why
end

return RespawnPolicy
