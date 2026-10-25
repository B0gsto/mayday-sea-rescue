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

local HeliFlight = require(script.Parent.Parent.Heli.Flight)
local HeliWinch = require(script.Parent.Parent.Heli.Winch)
local PlaneFlight = require(script.Parent.Parent.Plane.Flight)
local SubDive = require(script.Parent.Parent.Sub.Dive)

export type CameraMode = "FirstPerson" | "Chase"

export type VehicleSpec = {
	id: string,
	displayName: string,
	-- FirstPerson: locked first person from DriverSeat.EyePoint (a craft with no chase view);
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
	-- Premium fleet: the hand-built hull / art layout it borrows ("JetSki" | "RIB" | "Lifeboat"; nil =
	-- its own id) and the uploaded AssetIds model the spawner clones (nil = the base's art, or greybox).
	base: string?,
	model: string?,
	-- docs/23 (h): not a boat. Heli and Sub fly / dive on their own rigs (Heli/Flight, Sub/Rig); a Plane
	-- floats on the boat rig when parked and flies on Plane/Flight. Nil = a boat.
	craft: ("Heli" | "Plane" | "Sub")?,
}

local VehicleConfig = {}

VehicleConfig.KNOT = KNOT

-- Three-seat rescue PWC with a rescue sled (Yamaha FX / Sea-Doo GTX class): 3.3 m x 1.2 m,
-- 0.3 m draft, 350 kg dry + rider = 430 kg, 45 knots (sled fitted), 0 to 30 mph in about 2 s.
VehicleConfig.JetSki = {
	id = "JetSki",
	displayName = "Jet Ski",
	cameraMode = "Chase",
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
	-- 2026-10-24 balance: 35 knots on accel 7 had so little thrust over drag that a little swell held
	-- it near 30 km/h, slower than the free jet ski. Fast (74 km/h), just under the jet ski.
	topSpeed = 40 * KNOT, -- 61.7 studs/s (20.6 m/s, 74 km/h) -- tune
	accel = 15, -- 0.5 g: twin outboards, 0 to 25 knots in about 3.5 s; holds speed in a swell -- tune
	brakeDecel = 14, -- astern on both engines, "quick to stop" -- tune
	turnRate = 50, -- degrees/s cap -- tune
	turnRadiusSlow = 15, -- 5 m, about 0.6 lengths -- tune
	maxLateralG = 0.95, -- about 45 m radius at full speed -- tune
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
	survivorCapacity = 3, -- 2026-10-21 (user): jet ski 1, RIB 3, lifeboat 8
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

-- Severn-class all-weather lifeboat: 17.3 m x 5.9 m, 1.5 m draft, 41 t, 25 knots. Heavy and
-- steady: 4 crew, 8 survivors, a strong tow, self-righting (never capsizes), holds her course in
-- big seas. Slower and much heavier than the RIB; the placeholder hull is code-built (Builder).
VehicleConfig.Lifeboat = {
	id = "Lifeboat",
	displayName = "All-Weather Lifeboat",
	cameraMode = "Chase",
	eyePoint = Vector3.new(0, 2.8, -0.5), -- helm in the wheelhouse, about 1.6 m above the seat
	topSpeed = 30 * KNOT, -- 46.3 studs/s (56 km/h); docs 02 section 4: 45 studs/s
	accel = 9, -- 0.3 g: 41 t gathers way steadily and keeps it in a big sea -- tune
	brakeDecel = 8, -- big propellers astern -- tune
	turnRate = 26, -- degrees/s cap: heavier than the RIB -- tune
	turnRadiusSlow = 40, -- 13 m, about 0.75 lengths -- tune
	maxLateralG = 0.5, -- wide, steady turning circle at speed -- tune
	pivotSpeed = 3, -- twin props walk her round at a standstill -- tune
	offThrottleSteer = 0.6, -- a big rudder still bites -- tune
	humpSpeed = 0.25,
	planingSpeed = 0.5, -- displacement hull: never fully on the plane
	humpTrim = 3,
	runningTrim = 1.5,
	squatTrim = 1,
	planingLift = 0.12,
	leanFactor = 0.25, -- she heels little in a turn -- tune
	maxLean = 8,
	dampingRatio = 0.55, -- a heavy hull: little bounce, holds her course in a big sea
	idleCreep = 0, -- props in neutral
	approachSpeed = 4.5 * KNOT, -- under 5 knots
	killCord = true,
	ejectOnCapsize = false, -- self-righting (docs 02)
	seats = 4, -- 4 crew (docs 02)
	survivorCapacity = 8, -- docs 02
	hullSize = Vector3.new(17.7, 7.5, 51.9), -- 5.9 m x 2.5 m x 17.3 m
	massHint = 41000 * KG, -- 1108 RMU
	draft = 4.5, -- 1.5 m
	floatPoints = {
		Vector3.new(-5.5, -3, -20),
		Vector3.new(5.5, -3, -20),
		Vector3.new(-6.5, -3, -7),
		Vector3.new(6.5, -3, -7),
		Vector3.new(-6.5, -3, 7),
		Vector3.new(6.5, -3, 7),
		Vector3.new(-5.5, -3, 20),
		Vector3.new(5.5, -3, 20),
	},
	lateralGrip = 0.95, -- a deep keel and bilge keels: minimal leeway
	canCapsize = false,
	canTow = true, -- strong tow (docs 02)
	firePump = true, -- fire monitor (docs 02)
} :: VehicleSpec

-- Premium fleet (2026-10-21, user): Robux only (ProgressionConfig.Vehicles passOnly). Each copies a
-- base spec and retunes it. Placeholder art: `model` is the base's mesh until its own one is uploaded
-- (swap the string; the mesh must carry the base's ATT_ markers, see Boat/Builder).
local function variant(baseId: string, over: { [string]: any }): VehicleSpec
	local spec = table.clone((VehicleConfig :: any)[baseId]) :: any
	for k, v in over do
		spec[k] = v
	end
	spec.base = baseId
	return spec :: VehicleSpec
end

-- Offshore powerboat (Cigarette / Fountain class): stepped deep V, 58 knots, carves hard.
VehicleConfig.StormRunner = variant("RIB", {
	id = "StormRunner",
	displayName = "Storm Runner",
	model = "M_Veh_StormRunner", -- on the RIB frame and ATT_ markers (its own helm: no M_Veh_RIB_Helm)
	topSpeed = 58 * KNOT, -- 89.5 studs/s -- tune
	accel = 13, -- twice the RIB's punch -- tune
	brakeDecel = 16,
	turnRate = 58,
	maxLateralG = 1.05,
	planingSpeed = 0.34,
	runningTrim = 4.5,
	leanFactor = 0.4,
	maxLean = 14,
	dampingRatio = 0.5,
	lateralGrip = 0.88,
	firePump = false,
})

-- Luxury catamaran: two hulls, dead flat in a turn, soft over a swell, never capsizes; 6 casualties.
VehicleConfig.Tidewalker = variant("Lifeboat", {
	id = "Tidewalker",
	displayName = "Tidewalker",
	-- on the lifeboat frame, its own ATT_ markers (Boat/Builder buildTidewalkerAsset; pivot at HullRoot
	-- (0, -2.8, -0.01), art/source/vehicles/M_Veh_Tidewalker/frame_offset.json)
	model = "M_Veh_Tidewalker",
	topSpeed = 36 * KNOT, -- 55.5 studs/s, faster than the lifeboat -- tune
	accel = 9,
	brakeDecel = 9,
	turnRate = 34,
	turnRadiusSlow = 30,
	maxLateralG = 0.6,
	pivotSpeed = 4, -- twin engines spin a cat on the spot
	leanFactor = 0.06,
	maxLean = 3,
	dampingRatio = 0.75, -- smooth ride
	survivorCapacity = 6, -- between the RIB's 3 and the lifeboat's 8
	canTow = true,
	firePump = false,
})

-- Sport jet ski (stand-up race class): the quickest thing on the water, light and twitchy.
VehicleConfig.RiptideX = variant("JetSki", {
	id = "RiptideX",
	displayName = "Riptide X",
	model = "M_Veh_JetSki_RiptideX", -- on the jet ski frame and ATT_ markers (no close-up set)
	topSpeed = 62 * KNOT, -- 95.7 studs/s -- tune
	accel = 32,
	turnRate = 115,
	turnRadiusSlow = 6,
	maxLateralG = 1.55,
	pivotSpeed = 8,
	leanFactor = 0.65,
	maxLean = 30,
	lateralGrip = 0.74,
})

-- Gold luxe jet ski: fast, planted and smooth rather than wild.
VehicleConfig.GildedGull = variant("JetSki", {
	id = "GildedGull",
	displayName = "Gilded Gull",
	model = "M_Veh_JetSki_GildedGull", -- on the jet ski frame and ATT_ markers (no close-up set)
	topSpeed = 54 * KNOT, -- 83.3 studs/s -- tune
	accel = 27,
	turnRate = 100,
	maxLateralG = 1.4,
	leanFactor = 0.45,
	maxLean = 20,
	dampingRatio = 0.8, -- glides over chop
	lateralGrip = 0.82,
})

-- docs/23 (h), WP-10a: the hangar and sub pen craft. Handling lives in their own modules (Heli/Flight,
-- Plane/Flight, Sub/Dive); these rows carry what VehicleService, the camera and the phone read. The boat
-- fields come from the lifeboat and only matter to a parked seaplane floating on Boat/Simulator.
local function craft(kind: "Heli" | "Plane" | "Sub", over: { [string]: any }): VehicleSpec
	local spec = table.clone(VehicleConfig.Lifeboat) :: any
	for k, v in over do
		spec[k] = v
	end
	spec.craft = kind
	spec.model = nil
	spec.idleCreep = 0
	spec.killCord, spec.ejectOnCapsize, spec.canCapsize = false, false, false
	spec.canTow, spec.firePump = false, false
	return spec :: VehicleSpec
end

-- AW139-class rescue helicopter (Heli/Builder): hovers, winches, 2 survivors.
VehicleConfig.RescueHelicopter = craft("Heli", {
	id = "RescueHelicopter",
	displayName = "Rescue Helicopter",
	eyePoint = Vector3.new(0, 2.6, 0),
	topSpeed = HeliFlight.SPECS.RescueHelicopter.forwardSpeed,
	seats = 2,
	survivorCapacity = HeliWinch.SEATS,
	hullSize = Vector3.new(7, 6, 13), -- Heli/Builder HullRoot
	massHint = 6400 * KG,
	draft = 0,
	floatPoints = {},
})

-- Cessna 208 amphibian class floatplane (Plane/Flight.SPECS.Seaplane): its floats ride the boat rig.
local plane = PlaneFlight.SPECS.Seaplane
VehicleConfig.Seaplane = craft("Plane", {
	id = plane.id,
	displayName = plane.displayName,
	eyePoint = plane.eyePoint,
	topSpeed = plane.topSpeed,
	seats = plane.seats,
	survivorCapacity = plane.survivorCapacity,
	hullSize = plane.hullSize,
	massHint = plane.massHint,
	draft = plane.draft,
	floatPoints = plane.floatPoints,
})

-- Two-seat rescue submersible (Sub/Builder): floats like a slow boat, dives to the seabed.
VehicleConfig.Submarine = craft("Sub", {
	id = "Submarine",
	displayName = "Submarine",
	eyePoint = Vector3.new(0, 2, 0),
	topSpeed = SubDive.TOP_SPEED,
	seats = 2,
	survivorCapacity = SubDive.SEATS,
	hullSize = Vector3.new(5, 5, 14), -- Sub/Builder HullRoot
	massHint = 5 * 5 * 14 * 0.7, -- default-density HullRoot (Sub/Rig carries it)
	draft = SubDive.DRAFT,
	floatPoints = {},
})

-- Every boat id, in shop / bay menu order (boats only: the bay launch, the phone and the trailer read it).
VehicleConfig.Order =
	{ "JetSki", "RiptideX", "GildedGull", "RIB", "StormRunner", "Tidewalker", "Lifeboat" }
-- The docs/23 (h) craft (hangar, sub pen): bought and launched at their dock building (WP-10b).
VehicleConfig.CraftOrder = { "RescueHelicopter", "Seaplane", "Submarine" }

function VehicleConfig.get(id: string): VehicleSpec?
	local spec = (VehicleConfig :: any)[id]
	if type(spec) == "table" and spec.id == id then
		return spec :: VehicleSpec
	end
	return nil
end

-- A one-rider jet ski: the JetSki or a premium jet ski built on it.
function VehicleConfig.isJetSki(id: any): boolean
	local spec = if type(id) == "string" then VehicleConfig.get(id) else nil
	return spec ~= nil and (spec.base or spec.id) == "JetSki"
end

return VehicleConfig
