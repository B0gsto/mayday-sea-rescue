--!strict
-- Fuel (docs/31 C): the tank's pure rules. Pure, Lune-tested (tests/Fuel.spec.luau, tests/Pacing.spec.luau).
-- Fuel is counted in seconds of full throttle and belongs to the player: the boat, helicopter and sub all use the boat
-- level's tank and rating (owner). Zones are SeaZones indices (1 Shallows .. 5 Wreck Abyss, `SeaZones.zoneAt`).
--
-- API (FuelService and the HUD build on this):
--   Fuel.tank(level) -> number         full tank, s of full throttle (BoatLevels row `tank`: 24 at L1 .. 43.6 at L50)
--   Fuel.rating(level) -> number       farthest zone burning x1: L1-10 Kelp 2, L11-20 Coral 3, L21-30 Storm 4, L31+ 5
--   Fuel.factor(zone, level) -> number 0 in the Shallows, 1 up to the rating, 5 one zone past, 25 two or more
--   Fuel.burn(dt, speedFrac, zone, level) -> number   fuel used in dt s; speedFrac = speed / level top speed, capped
--                                      to 0..1 so the pick-up boost and Nitro cost no extra and idling costs nothing
--   Fuel.reach(level, fromR) -> number studs from RingLayout.Center a full tank reaches, driving straight out from fromR
--   Fuel.LIMP_SPEED, Fuel.LIMP_S       empty tank: coast at this share of top speed for this long, then auto Go back
--   Fuel.step(fuel, max, s) -> (number, boolean)   one FuelService tick: full at home, burns only while s.driving;
--                                      the boolean is true on the tick the tank runs dry
-- Refuel is full and free at home (FuelService). Fuel per stud is factor / top speed at any throttle, so reach does not
-- depend on how hard you drive.
local BoatLevels = require(script.Parent.Parent.BoatLevels)
local SeaZones = require(script.Parent.Parent.Calls.SeaZones)

local Fuel = {}

Fuel.LIMP_SPEED = 0.15 -- tune
Fuel.LIMP_S = 3 -- tune
local PAST = { 5, 25 } -- one zone past the rating, two or more -- tune

function Fuel.tank(level: any): number
	return BoatLevels.row(level).tank
end

function Fuel.rating(level: any): number
	return math.min(BoatLevels.row(level).stage + 1, #SeaZones.Zones) -- each new hull rates one zone further
end

function Fuel.factor(zone: number, level: any): number
	if zone <= 1 then
		return 0
	end
	local past = zone - Fuel.rating(level)
	return if past <= 0 then 1 else PAST[math.min(past, #PAST)]
end

function Fuel.burn(dt: number, speedFrac: number, zone: number, level: any): number
	return dt * math.clamp(speedFrac, 0, 1) * Fuel.factor(zone, level)
end

export type Tick = {
	home: boolean,
	driving: boolean,
	dt: number,
	speedFrac: number,
	zone: number,
	level: any,
}

function Fuel.step(fuel: number, max: number, s: Tick): (number, boolean)
	if s.home then
		return max, false
	end
	local now = math.min(fuel, max)
	if not s.driving then
		return now, false
	end
	local left = math.max(now - Fuel.burn(s.dt, s.speedFrac, s.zone, s.level), 0)
	return left, left <= 0 and now > 0
end

function Fuel.reach(level: any, fromR: number): number
	local speed, left, r = BoatLevels.row(level).speed, Fuel.tank(level), fromR
	for zone, z in SeaZones.Zones do
		if r < z.outer then
			local f = Fuel.factor(zone, level)
			local cost = (z.outer - r) * f / speed -- the last zone is endless, so it always ends here
			if cost >= left then
				return r + left * speed / f
			end
			left -= cost
			r = z.outer
		end
	end
	return r
end

return Fuel
