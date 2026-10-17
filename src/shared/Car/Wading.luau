--!strict
-- Wading: how deep a land vehicle may drive into water (pure, Lune-safe). Depth is the water
-- height over the tyre contact patch (studs, 1 m = 3 studs). Real 4x4s quote a wading depth
-- (a pickup about 0.8 m); past half of it the driver is warned to turn back, at the rated depth the
-- air intake swallows water and the engine floods: throttle cut, the car stops, and after a short
-- wait it either restarts (rolled back to shallow water) or is recovered to the last dry spot.
-- LandVehicleService runs the state (one event per flood); CarController shows the notices.

local Wading = {}

Wading.STUDS_PER_METRE = 3
-- Rated wading depth per vehicle (metres). Unlisted vehicles use DEFAULT_RATED.
Wading.RatedDepth = {
	LifeguardPickup = 0.8,
	CoastguardResponse = 0.9, -- snorkel-height response 4x4 (also backs trailers down slipways)
	BeachATV = 0.45,
} :: { [string]: number }
Wading.DEFAULT_RATED = 0.7
Wading.WARN_FRACTION = 0.5 -- warn the driver past this share of the rated depth
Wading.FLOOD_SECONDS = 4 -- stalled this long before the restart / recovery

export type Level = "Dry" | "Wading" | "Deep" | "Flood"
export type Action = "Flood" | "Restart" | "Rescue"
export type State = { flooded: boolean, recoverAt: number }

-- Water over the tyres: water surface minus the ground under the chassis (root Y - ride height).
function Wading.depth(waterY: number, rootY: number, rideHeight: number): number
	return waterY - (rootY - rideHeight)
end

-- (warn, flood) depths in studs for a vehicle id.
function Wading.thresholds(vehicleId: string?): (number, number)
	local rated = (vehicleId and Wading.RatedDepth[vehicleId]) or Wading.DEFAULT_RATED
	local flood = rated * Wading.STUDS_PER_METRE
	return flood * Wading.WARN_FRACTION, flood
end

function Wading.level(depth: number, vehicleId: string?): Level
	local warnAt, floodAt = Wading.thresholds(vehicleId)
	if depth <= 0 then
		return "Dry" :: Level
	elseif depth < warnAt then
		return "Wading" :: Level
	elseif depth < floodAt then
		return "Deep" :: Level
	end
	return "Flood" :: Level
end

function Wading.newState(): State
	return { flooded = false, recoverAt = 0 }
end

-- Advance the flood state with a depth sample. Returns an action at most once per event:
-- "Flood" on entering the flood depth, then after FLOOD_SECONDS "Restart" (back in shallow water)
-- or "Rescue" (still deep: recover to dry land). nil otherwise.
function Wading.step(state: State, depth: number, vehicleId: string?, now: number): Action?
	local warnAt, floodAt = Wading.thresholds(vehicleId)
	if not state.flooded then
		if depth >= floodAt then
			state.flooded = true
			state.recoverAt = now + Wading.FLOOD_SECONDS
			return "Flood"
		end
		return nil
	end
	if now < state.recoverAt then
		return nil
	end
	state.flooded = false
	return if depth < warnAt then "Restart" else "Rescue"
end

-- The driver's notice line ("" when nothing to say). secondsLeft: until the recovery, if known.
function Wading.notice(level: string, flooded: boolean, secondsLeft: number?): string
	if flooded or level == "Flood" then
		if secondsLeft and secondsLeft > 0 then
			return `Engine flooded - recovering in {math.ceil(secondsLeft)}s`
		end
		return "Engine flooded"
	elseif level == "Deep" then
		return "Water too deep - turn back"
	end
	return ""
end

return Wading
