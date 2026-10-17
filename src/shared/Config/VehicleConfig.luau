--!strict
-- VehicleConfig: per-vehicle handling and capacity. Pure data.
-- Seats and capacities from docs 02 section 4; handling notes from docs 06 section 3.2.
-- Real-world dimensions, masses and speeds (sources in each block); handling numbers -- tune.
--
-- floatPoints are offsets from the hull's root part in its local frame (-Z is forward, Y up),
-- one buoyancy attachment each: depth = Waves.heightAt(point) - point.Y,
-- lift = clamp(depth / draft, 0, 1) * buoyancyPerPoint (docs 06 section 3.2).

-- Scale (docs 05 section 4.1): 1 m = 3 studs. 1 knot = 0.514 m/s = 1.543 studs/s.
-- Mass: 1 RMU = 1 stud^3 of water = 37 kg, so a hull floats at its real displacement. Seated
-- players are massless (VehicleService), so massHint includes the crew. Gravity 29.43 studs/s^2.
local KNOT = 1.543 -- studs/s
local KG = 1 / 37 -- RMU per kg

export type CameraMode = "FirstPerson" | "Chase"

export type VehicleSpec = {
	id: string,
	displayName: string,
	-- FirstPerson: locked first person from DriverSeat.EyePoint (on foot and on the jet ski);
	-- Chase: third-person chase camera, with an optional helm view at EyePoint. A camera stream
	-- implements both (CONTRACT: not built by stream B).
	cameraMode: CameraMode,
	eyePoint: Vector3, -- driver's eye, offset from the DriverSeat centre (studs)
	topSpeed: number, -- studs/s
	accel: number, -- studs/s^2 of thrust at full throttle from rest
	brakeDecel: number, -- studs/s^2 of reverse thrust (reverse bucket / astern gear)
	turnRate: number, -- degrees/s cap on the yaw rate
	turnRadiusSlow: number, -- studs, tightest turn at low speed
	maxLateralG: number, -- g in a hard turn at speed (sets the turning circle)
	pivotSpeed: number, -- studs/s of steering "flow" the jet / prop gives at a standstill
	offThrottleSteer: number, -- 0..1 steering with the throttle closed
	humpSpeed: number, -- fraction of topSpeed: peak bow rise (resistance hump)
	planingSpeed: number, -- fraction of topSpeed: fully on the plane
	humpTrim: number, -- degrees bow up at the hump
	runningTrim: number, -- degrees bow up on the plane
	squatTrim: number, -- degrees extra stern squat at full throttle off the plane
	planingLift: number, -- 0..1 of the weight carried by dynamic lift on the plane
	leanFactor: number, -- 0..1 of the coordinated bank angle in a turn
	maxLean: number, -- degrees
	dampingRatio: number, -- heave damping, fraction of critical (low = bouncy)
	idleCreep: number, -- studs/s an idling engine pushes (jet drive); 0 = neutral gear
	approachSpeed: number, -- studs/s cap in approach mode (under 5 knots)
	killCord: boolean, -- the engine stops when the driver leaves the helm
	ejectOnCapsize: boolean, -- the rider falls off past the capsize angle (sit-on PWC)
	seats: number, -- player seats including the driver
	survivorCapacity: number,
	hullSize: Vector3, -- greybox collision hull (studs): beam, depth keel to gunwale, length
	massHint: number, -- assembly mass (RMU) including crew; Builder sets the hull density to hit it
	draft: number, -- studs of hull below the waterline at rest
	floatPoints: { Vector3 },
	lateralGrip: number, -- 0..1, sideways drag vs forward drag (keel / grip force)
	canCapsize: boolean,
	canTow: boolean,
	firePump: boolean,
}

local VehicleConfig = {}

VehicleConfig.KNOT = KNOT

-- Three-seat rescue PWC with a rescue sled (Yamaha FX / Sea-Doo GTX class): 3.3 m x 1.2 m,
-- 0.3 m draft, 350 kg dry + rider = 430 kg, 45 knots (sled fitted), 0 to 30 mph in about 2 s.
VehicleConfig.JetSki = {
	id = "JetSki",
	displayName = "Jet Ski",
	cameraMode = "FirstPerson",
	eyePoint = Vector3.new(0, 4.0, -0.4), -- 1.6 m above the footwell deck (rider half standing)
	topSpeed = 45 * KNOT, -- 69.4 studs/s (23.1 m/s)
	accel = 24, -- 0.82 g off the line -- tune
	brakeDecel = 16, -- reverse bucket brake, about 0.55 g -- tune
	turnRate = 95, -- degrees/s cap -- tune
	turnRadiusSlow = 7.5, -- 2.5 m: spins in about 1.5 lengths -- tune
	maxLateralG = 1.3, -- hard carve: about 38 m radius at full speed -- tune
	pivotSpeed = 7, -- jet thrust steers at a standstill -- tune
	offThrottleSteer = 0.2, -- jets barely steer with the throttle closed -- tune
	humpSpeed = 0.2, -- 14 studs/s, about 9 knots -- tune
	planingSpeed = 0.36, -- on the plane at about 16 knots -- tune
	humpTrim = 7,
	runningTrim = 3,
	squatTrim = 2.5,
	planingLift = 0.55,
	leanFactor = 0.55, -- rider and hull bank into the carve -- tune
	maxLean = 24,
	dampingRatio = 0.6,
	idleCreep = 2.5 * KNOT, -- an idling jet creeps at about 2.5 knots -- tune
	approachSpeed = 4.5 * KNOT, -- 6.9 studs/s, under 5 knots
	killCord = true,
	ejectOnCapsize = true,
	seats = 1, -- 1 rider (docs 02)
	survivorCapacity = 1, -- on the rescue sled (docs 02)
	hullSize = Vector3.new(3.6, 2.1, 9.9), -- 1.2 m x 0.7 m x 3.3 m
	massHint = 430 * KG, -- 11.6 RMU
	draft = 0.9, -- 0.3 m
	floatPoints = {
		Vector3.new(-0.8, -1.05, -3.6),
		Vector3.new(0.8, -1.05, -3.6),
		Vector3.new(-1.4, -1.05, 0),
		Vector3.new(1.4, -1.05, 0),
		Vector3.new(-1.5, -1.05, 3.6),
		Vector3.new(1.5, -1.05, 3.6),
	},
	lateralGrip = 0.7, -- slides on turns (docs 02)
	canCapsize = true,
	canTow = false,
	firePump = false,
} :: VehicleSpec

-- RNLI Atlantic 85-class inshore lifeboat: 8.44 m x 2.85 m, 0.53 m draft, 1.8 t + crew = 2.1 t,
-- twin 115 hp outboards, 35 knots, deep-V hull inside an air-tube collar.
VehicleConfig.RIB = {
	id = "RIB",
	displayName = "RIB Inflatable",
	cameraMode = "Chase",
	eyePoint = Vector3.new(0, 2.7, -0.5), -- helm on the jockey seat: 1.65 m above the deck
	topSpeed = 35 * KNOT, -- 54.0 studs/s (18 m/s)
	accel = 7, -- 0.24 g off the line, 230 hp on 2.1 t: 0 to 25 knots in about 8 s -- tune
	brakeDecel = 14, -- astern on both engines, "quick to stop" -- tune
	turnRate = 50, -- degrees/s cap -- tune
	turnRadiusSlow = 15, -- 5 m, about 0.6 lengths -- tune
	maxLateralG = 0.85, -- about 39 m radius at full speed -- tune
	pivotSpeed = 5, -- twin outboards turned hard over -- tune
	offThrottleSteer = 0.5, -- the outboard legs still act as rudders -- tune
	humpSpeed = 0.22, -- 12 studs/s, about 8 knots -- tune
	planingSpeed = 0.42, -- on the plane at about 15 knots -- tune
	humpTrim = 9,
	runningTrim = 4,
	squatTrim = 3,
	planingLift = 0.45,
	leanFactor = 0.3, -- deep V heels into the turn -- tune
	maxLean = 10,
	dampingRatio = 0.4, -- air tubes: bounces hard in swell (docs 02)
	idleCreep = 0, -- outboards in neutral
	approachSpeed = 4.5 * KNOT, -- 6.9 studs/s, under 5 knots
	killCord = true, -- the helm wears one too
	ejectOnCapsize = false, -- crew in jockey seats hold on; the RIB self-rights (docs 02)
	seats = 3, -- 3 crew (docs 02)
	survivorCapacity = 2, -- docs 02
	hullSize = Vector3.new(8.55, 3.3, 25.3), -- 2.85 m x 1.1 m x 8.44 m
	massHint = 2100 * KG, -- 56.8 RMU
	draft = 1.6, -- 0.53 m
	floatPoints = {
		Vector3.new(-2.2, -1.65, -9),
		Vector3.new(2.2, -1.65, -9),
		Vector3.new(-3.4, -1.65, -3),
		Vector3.new(3.4, -1.65, -3),
		Vector3.new(-3.6, -1.65, 3),
		Vector3.new(3.6, -1.65, 3),
		Vector3.new(-3.6, -1.65, 9),
		Vector3.new(3.6, -1.65, 9),
	},
	lateralGrip = 0.85,
	canCapsize = true,
	canTow = true, -- tows light boats (docs 02)
	firePump = true, -- small fire pump (docs 02)
} :: VehicleSpec

-- Every vehicle id, in shop / bay menu order.
VehicleConfig.Order = { "JetSki", "RIB" }

function VehicleConfig.get(id: string): VehicleSpec?
	local spec = (VehicleConfig :: any)[id]
	if type(spec) == "table" and spec.id == id then
		return spec :: VehicleSpec
	end
	return nil
end

return VehicleConfig
