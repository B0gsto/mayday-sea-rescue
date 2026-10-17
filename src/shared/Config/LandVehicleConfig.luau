--!strict
-- LandVehicleConfig: the land fleet (docs 10 section 3, speeds from docs 02 section 4.3). Pure data.
--
-- Dimensions, masses, engines and gearing are real-world (metres, kg, N m, rpm) for generic
-- vehicles of each class (no brands); Car/Chassis converts them to game units (1 m = 3 studs,
-- 37 kg per RMU, gravity 29.43 studs/s^2). Speeds are studs/s. Handling numbers -- tune.
-- Traffic drives on the left, so road vehicles are right-hand drive (driver on the right, +X).
local Drivetrain = require(script.Parent.Parent.Car.Drivetrain)

local KMH = 3 / 3.6 -- studs/s per km/h

export type VehicleClass = "Pickup" | "Response" | "ATV" | "Trailer" | "Ambulance"
export type DriveLayout = "4WD" | "RWD" | "FWD" | "None"

export type Spec = {
	id: string,
	displayName: string,
	class: VehicleClass,
	driveable: boolean, -- false: parked NPC vehicle in the MVP (the ambulance)
	-- Chase: third-person chase camera, plus an optional cockpit view from DriverSeat.EyePoint
	-- (the camera stream builds both, as for the boats).
	cameraMode: "Chase",
	cockpitView: boolean,
	eyePoint: Vector3, -- driver's eye from the DriverSeat centre (studs)
	unlockRank: number, -- ProgressionConfig rank index (1 Recruit, 2 Lifeguard, 3 Rescue Swimmer)
	seats: number, -- including the driver
	roles: { string },
	topSpeed: number, -- studs/s, governed (docs 02 section 4.3)
	topSpeedTowing: number?, -- studs/s with a trailer
	reverseSpeed: number, -- studs/s
	-- body and geometry (m)
	mass: number, -- kg, kerb + crew and kit
	length: number,
	width: number, -- body, without mirrors
	height: number,
	wheelbase: number, -- a trailer: spread between its tandem axles
	track: number,
	wheelRadius: number,
	wheelWidth: number,
	groundClearance: number,
	cgHeight: number, -- centre of mass above the ground at ride height
	frontWeight: number, -- fraction of the weight on the front axle (trailer: unused)
	frontOverhang: number, -- bumper to front axle (trailer: hitch ball to the axles' centre)
	-- suspension
	travel: number, -- m of wheel travel (spring free length in the model)
	frequencyFront: number, -- Hz ride frequency
	frequencyRear: number,
	dampingRatio: number, -- fraction of critical (docs 10: 0.3 to 0.5)
	antiRollFront: number, -- bar rate as a fraction of the corner spring rate
	antiRollRear: number,
	-- tyres
	tyreMu: number, -- peak friction on dry asphalt
	longB: number,
	longC: number,
	latB: number, -- per radian of slip angle
	latC: number,
	-- drivetrain (nil for trailers)
	engine: Drivetrain.Engine?,
	gearbox: Drivetrain.Gearbox?,
	drive: DriveLayout,
	-- brakes and steering
	brakeG: number, -- g the brakes can ask for (tyres limit what you get)
	brakeFrontBias: number,
	handbrakeG: number, -- rear axle only
	steerLock: number, -- degrees, road wheel angle at a standstill
	steerLockHigh: number, -- degrees, at speed (speed-sensitive lock)
	steerFadeSpeed: number, -- studs/s where the lock has faded halfway
	steerRate: number, -- degrees/s the road wheels turn
	cdA: number, -- m^2 drag area
	-- equipment
	canTow: boolean,
	lightBar: string?, -- LightBar pattern, nil for none
	lightBarColors: { Color3 }?, -- per lamp, left to right
	bodyColor: Color3,
	stripeColor: Color3,
	stripeColor2: Color3,
}

local LandVehicleConfig = {}

LandVehicleConfig.KMH = KMH

local BLUE = Color3.fromRGB(40, 90, 255)
local AMBER = Color3.fromRGB(255, 150, 20)

-- Lifeguard and beach patrol double-cab pickup (Toyota Hilux / Ford Ranger class, generic):
-- 5.33 m x 1.855 m x 1.815 m, 3.085 m wheelbase, 1.54 m track, 265/65 R17 tyres (0.39 m radius),
-- 2.8 L diesel 150 kW, 500 N m from 1,600 to 2,800 rpm, six-speed automatic, part-time 4WD with a
-- 2.57 low range. About 2,100 kg kerb + crew = 2,200 kg (docs 10 section 3.3).
LandVehicleConfig.LifeguardPickup = {
	id = "LifeguardPickup",
	displayName = "Lifeguard 4x4",
	class = "Pickup",
	driveable = true,
	cameraMode = "Chase",
	cockpitView = true,
	eyePoint = Vector3.new(0, 2.25, -0.3), -- eyes 0.75 m above the seat cushion
	unlockRank = 1, -- Recruit, free
	seats = 5, -- 2 front + 3 rear
	roles = { "BeachKit", "PersonInWaterFromShore", "Explore", "TowJetSkiTrailer" },
	topSpeed = 75, -- 90 km/h (docs 02 section 4.3)
	reverseSpeed = 20 * KMH,
	mass = 2200,
	length = 5.33,
	width = 1.855,
	height = 1.815,
	wheelbase = 3.085,
	track = 1.54,
	wheelRadius = 0.39,
	wheelWidth = 0.265,
	groundClearance = 0.29,
	cgHeight = 0.8,
	frontWeight = 0.57, -- an empty pickup is nose-heavy
	frontOverhang = 0.92,
	travel = 0.24,
	frequencyFront = 1.35,
	frequencyRear = 1.7, -- leaf springs, stiffer for payload
	dampingRatio = 0.38,
	antiRollFront = 0.35,
	antiRollRear = 0.08,
	tyreMu = 1.0, -- all-terrain tyres
	longB = 11,
	longC = 1.65,
	latB = 13,
	latC = 1.35,
	engine = {
		idleRpm = 750,
		stallRpm = 2200,
		redlineRpm = 3800,
		torqueCurve = {
			{ 750, 250 },
			{ 1200, 380 },
			{ 1600, 500 },
			{ 2800, 500 },
			{ 3400, 420 },
			{ 3800, 330 },
		},
		engineBrakeNm = 110,
		converterGain = 1.7,
	},
	gearbox = {
		ratios = { 3.6, 2.09, 1.49, 1.2, 1.0, 0.79 },
		reverse = 3.28,
		finalDrive = 3.909,
		lowRange = 2.566,
		efficiency = 0.88,
		shiftUpLight = 1900,
		shiftUpFull = 3500,
		shiftDown = 1150,
		shiftTime = 0.3,
	},
	drive = "4WD",
	brakeG = 0.95,
	brakeFrontBias = 0.65,
	handbrakeG = 0.35,
	steerLock = 32, -- 12.6 m kerb-to-kerb turning circle
	steerLockHigh = 3.5,
	steerFadeSpeed = 18,
	steerRate = 110,
	cdA = 1.35, -- Cd 0.45 x 3.0 m^2
	canTow = true,
	lightBar = "Rotator", -- amber beacons on a beach patrol truck (verify)
	lightBarColors = { AMBER, AMBER, AMBER, AMBER },
	bodyColor = Color3.fromRGB(235, 235, 228),
	stripeColor = Color3.fromRGB(205, 30, 36), -- lifeguard red and yellow
	stripeColor2 = Color3.fromRGB(250, 205, 20),
} :: Spec

-- Coastguard rescue team 4x4 (Land Rover Defender 110 / Toyota Land Cruiser class station
-- wagon, generic): 4.64 m x 1.79 m x 2.05 m with roof rack, 2.794 m wheelbase, 1.486 m track,
-- coil springs all round, permanent 4WD with a 2.93 low range, 2.2 L diesel 360 N m. Loaded with
-- cliff rope kit, mud rescue kit and floodlights: about 2,700 kg (verify: HM Coastguard vehicles).
LandVehicleConfig.CoastguardResponse = {
	id = "CoastguardResponse",
	displayName = "Coastguard Response 4x4",
	class = "Response",
	driveable = true,
	cameraMode = "Chase",
	cockpitView = true,
	eyePoint = Vector3.new(0, 2.4, -0.2),
	unlockRank = 3, -- Rescue Swimmer (docs 10: Rescue Swimmer and Helm)
	seats = 5, -- 2 + 3
	roles = { "ShoreTeam", "CliffRescue", "SlipwayLaunch", "MudRescue" },
	topSpeed = 70, -- 84 km/h
	topSpeedTowing = 50, -- 60 km/h with the boat trailer
	reverseSpeed = 18 * KMH,
	mass = 2700,
	length = 4.64,
	width = 1.79,
	height = 2.05,
	wheelbase = 2.794,
	track = 1.486,
	wheelRadius = 0.39,
	wheelWidth = 0.235,
	groundClearance = 0.25,
	cgHeight = 0.88,
	frontWeight = 0.5,
	frontOverhang = 0.75,
	travel = 0.28, -- long-travel coils
	frequencyFront = 1.3,
	frequencyRear = 1.45,
	dampingRatio = 0.4,
	antiRollFront = 0.3,
	antiRollRear = 0.15,
	tyreMu = 0.98,
	longB = 11,
	longC = 1.65,
	latB = 12,
	latC = 1.35,
	engine = {
		idleRpm = 750,
		stallRpm = 2300,
		redlineRpm = 4000,
		torqueCurve = {
			{ 750, 200 },
			{ 1500, 360 },
			{ 2000, 360 },
			{ 3000, 330 },
			{ 3500, 280 },
			{ 4000, 200 },
		},
		engineBrakeNm = 100,
		converterGain = 1.8,
	},
	gearbox = {
		ratios = { 4.17, 2.34, 1.52, 1.14, 0.87, 0.69 },
		reverse = 3.4,
		finalDrive = 3.54,
		lowRange = 2.93,
		efficiency = 0.86,
		shiftUpLight = 1900,
		shiftUpFull = 3700,
		shiftDown = 1150,
		shiftTime = 0.3,
	},
	drive = "4WD",
	brakeG = 0.9,
	brakeFrontBias = 0.62,
	handbrakeG = 0.3,
	steerLock = 33,
	steerLockHigh = 3.5,
	steerFadeSpeed = 17,
	steerRate = 100,
	cdA = 1.75, -- a brick: Cd 0.55 x 3.2 m^2
	canTow = true,
	lightBar = "DoubleFlash", -- blue lights
	lightBarColors = { BLUE, BLUE, BLUE, BLUE },
	bodyColor = Color3.fromRGB(240, 240, 236),
	stripeColor = Color3.fromRGB(20, 50, 140), -- coastguard blue and yellow (invented livery)
	stripeColor2 = Color3.fromRGB(250, 210, 20),
} :: Spec

-- Lifeguard utility quad bike (420 cc class): 2.1 m x 1.2 m x 1.2 m, 1.29 m wheelbase, 0.95 m
-- track, 25-inch tyres (0.32 m radius), about 290 kg + rider + board = 390 kg; automatic (CVT
-- modelled as five close steps) with a low range. Not road-legal: beaches, tracks, car parks.
LandVehicleConfig.BeachATV = {
	id = "BeachATV",
	displayName = "Beach ATV",
	class = "ATV",
	driveable = true,
	cameraMode = "Chase",
	cockpitView = true,
	eyePoint = Vector3.new(0, 2.6, 0.3), -- rider sits up high
	unlockRank = 2, -- Lifeguard
	seats = 1,
	roles = { "RipRescue", "BeachSearch", "CasualtySled" },
	topSpeed = 45, -- 54 km/h
	reverseSpeed = 10 * KMH,
	mass = 390,
	length = 2.1,
	width = 1.2,
	height = 1.2,
	wheelbase = 1.29,
	track = 0.95,
	wheelRadius = 0.32,
	wheelWidth = 0.25,
	groundClearance = 0.25,
	cgHeight = 0.66, -- rider included
	frontWeight = 0.45,
	frontOverhang = 0.42,
	travel = 0.19,
	frequencyFront = 1.8,
	frequencyRear = 2.0,
	dampingRatio = 0.42,
	antiRollFront = 0.15,
	antiRollRear = 0.0,
	tyreMu = 0.95, -- knobbly tyres: a little less on tarmac, digs in on sand
	longB = 9,
	longC = 1.6,
	latB = 10,
	latC = 1.35,
	engine = {
		idleRpm = 1400,
		stallRpm = 3500,
		redlineRpm = 7000,
		torqueCurve = {
			{ 1400, 18 },
			{ 3000, 28 },
			{ 5000, 33 },
			{ 6500, 30 },
			{ 7000, 26 },
		},
		engineBrakeNm = 9,
		converterGain = 1.6, -- centrifugal clutch and CVT
	},
	gearbox = {
		ratios = { 2.6, 1.7, 1.25, 0.98, 0.8 },
		reverse = 3.0,
		finalDrive = 17.0,
		lowRange = 1.6,
		efficiency = 0.85,
		shiftUpLight = 4000,
		shiftUpFull = 6600,
		shiftDown = 2600,
		shiftTime = 0.15,
	},
	drive = "4WD",
	brakeG = 0.85,
	brakeFrontBias = 0.6,
	handbrakeG = 0.4,
	steerLock = 38,
	steerLockHigh = 8,
	steerFadeSpeed = 14,
	steerRate = 160,
	cdA = 0.9, -- rider sitting up
	canTow = false,
	lightBar = "Rotator", -- a single amber beacon on the rack mast
	lightBarColors = { AMBER, AMBER },
	bodyColor = Color3.fromRGB(205, 30, 36),
	stripeColor = Color3.fromRGB(250, 205, 20),
	stripeColor2 = Color3.fromRGB(30, 30, 32),
} :: Spec

-- Braked tandem-axle boat trailer for a RIB or jet ski: 9.6 m from the hitch ball to the rear
-- rollers, 2.45 m wide, 0.95 m between axles, 1.9 m track, 13-inch wheels (0.33 m radius),
-- 650 kg unladen. The boat's mass is added at spawn. Overrun brakes follow the tow car's brakes.
LandVehicleConfig.BoatTrailer = {
	id = "BoatTrailer",
	displayName = "Boat trailer",
	class = "Trailer",
	driveable = false,
	cameraMode = "Chase",
	cockpitView = false,
	eyePoint = Vector3.zero,
	unlockRank = 3,
	seats = 0,
	roles = { "SlipwayLaunch" },
	topSpeed = 50,
	reverseSpeed = 20 * KMH,
	mass = 650,
	length = 9.6,
	width = 2.45,
	height = 1.0,
	wheelbase = 0.95,
	track = 1.9,
	wheelRadius = 0.33,
	wheelWidth = 0.175,
	groundClearance = 0.3,
	cgHeight = 0.85,
	frontWeight = 0, -- unused
	frontOverhang = 5.4, -- hitch ball to the middle of the axles (nose weight about 7 %)
	travel = 0.12, -- rubber torsion axles
	frequencyFront = 2.2,
	frequencyRear = 2.2,
	dampingRatio = 0.3,
	antiRollFront = 0,
	antiRollRear = 0,
	tyreMu = 0.95,
	longB = 11,
	longC = 1.65,
	latB = 12,
	latC = 1.35,
	engine = nil,
	gearbox = nil,
	drive = "None",
	brakeG = 0.6,
	brakeFrontBias = 0.5,
	handbrakeG = 0.3,
	steerLock = 0,
	steerLockHigh = 0,
	steerFadeSpeed = 1,
	steerRate = 0,
	cdA = 1.2,
	canTow = false,
	lightBar = nil,
	lightBarColors = nil,
	bodyColor = Color3.fromRGB(150, 155, 160), -- galvanised steel
	stripeColor = Color3.fromRGB(200, 40, 30),
	stripeColor2 = Color3.fromRGB(30, 30, 32),
} :: Spec

-- Paramedic box-body ambulance (Mercedes Sprinter / Fiat Ducato conversion class, generic):
-- 7.0 m x 2.1 m x 2.9 m, 4.33 m wheelbase, 4,100 kg. MVP: a parked NPC handover point (docs 10
-- section 3.1); the numbers are ready for [L] driving.
LandVehicleConfig.Ambulance = {
	id = "Ambulance",
	displayName = "Ambulance",
	class = "Ambulance",
	driveable = false,
	cameraMode = "Chase",
	cockpitView = true,
	eyePoint = Vector3.new(0, 2.4, -0.2),
	unlockRank = 3,
	seats = 3,
	roles = { "Handover" },
	topSpeed = 75,
	reverseSpeed = 15 * KMH,
	mass = 4100,
	length = 7.0,
	width = 2.1,
	height = 2.9,
	wheelbase = 4.33,
	track = 1.71,
	wheelRadius = 0.36,
	wheelWidth = 0.215,
	groundClearance = 0.2,
	cgHeight = 1.1,
	frontWeight = 0.45,
	frontOverhang = 1.0,
	travel = 0.18,
	frequencyFront = 1.4,
	frequencyRear = 1.6,
	dampingRatio = 0.4,
	antiRollFront = 0.4,
	antiRollRear = 0.3,
	tyreMu = 1.0,
	longB = 11,
	longC = 1.65,
	latB = 12,
	latC = 1.35,
	engine = nil, -- [L]
	gearbox = nil,
	drive = "RWD",
	brakeG = 0.85,
	brakeFrontBias = 0.6,
	handbrakeG = 0.25,
	steerLock = 34,
	steerLockHigh = 3,
	steerFadeSpeed = 16,
	steerRate = 90,
	cdA = 2.6,
	canTow = false,
	lightBar = "QuadFlash",
	lightBarColors = { BLUE, BLUE, BLUE, BLUE },
	bodyColor = Color3.fromRGB(250, 220, 30), -- high-visibility yellow (invented Gale Isles livery)
	stripeColor = Color3.fromRGB(30, 140, 60),
	stripeColor2 = Color3.fromRGB(30, 60, 160),
} :: Spec

-- Driveable vehicles, in menu order.
LandVehicleConfig.Order = { "LifeguardPickup", "BeachATV", "CoastguardResponse" }

-- Which boat a trailer carries: the first the player may use (VehicleConfig ids).
LandVehicleConfig.TrailerBoats = { "RIB", "JetSki" }

-- Trailer launch (docs 10 section 3.2): the boat floats off once the cradle is this deep, the
-- rig has stopped, and the driver releases the winch strap.
LandVehicleConfig.LaunchDepth = 1.6 -- studs of water over the trailer bed (0.53 m, the RIB's draft)
LandVehicleConfig.LaunchMaxSpeed = 2 -- studs/s

-- Spawn points (docs 10 section 3.2). TODO(WorldConfig): placeholders on the greybox map until
-- src/shared/Config/WorldConfig.luau provides LandVehicleSpawns; LandVehicleService prefers that.
-- `cframe` is the first bay at ground level facing out (LookVector); further bays step along
-- `step` (studs, in the point's local frame).
export type SpawnPoint = {
	id: string,
	displayName: string,
	cframe: CFrame,
	step: Vector3,
	bays: number,
	vehicles: { string },
	trailers: boolean, -- trailers can be hitched here
}

LandVehicleConfig.SpawnPoints = {
	{
		id = "StationYard",
		displayName = "Station yard",
		-- TODO(WorldConfig): west of the station building, facing the gate onto Harbour Road
		cframe = CFrame.lookAt(Vector3.new(-196, 4, -74), Vector3.new(-196, 4, 0)),
		step = Vector3.new(-10, 0, 0),
		bays = 4,
		vehicles = { "LifeguardPickup", "CoastguardResponse" },
		trailers = false,
	},
	{
		id = "Boatyard",
		displayName = "Boatyard",
		-- TODO(WorldConfig): on the quay east of the dock, facing east toward Haven Sands slipway
		cframe = CFrame.lookAt(Vector3.new(-20, 4, -8), Vector3.new(100, 4, -8)),
		step = Vector3.new(0, 0, 0),
		bays = 1,
		vehicles = { "CoastguardResponse" },
		trailers = true,
	},
	{
		id = "HavenSandsCarPark",
		displayName = "Haven Sands car park",
		-- TODO(WorldConfig): behind the beach, facing the sand
		cframe = CFrame.lookAt(Vector3.new(200, 4, -90), Vector3.new(200, 4, 0)),
		step = Vector3.new(-10, 0, 0),
		bays = 3,
		vehicles = { "LifeguardPickup" },
		trailers = false,
	},
	{
		id = "HavenSandsTower",
		displayName = "Lifeguard tower",
		-- TODO(WorldConfig): beside the lifeguard hut
		cframe = CFrame.lookAt(Vector3.new(252, 4, -48), Vector3.new(252, 4, 0)),
		step = Vector3.new(6, 0, 0),
		bays = 2,
		vehicles = { "BeachATV" },
		trailers = false,
	},
} :: { SpawnPoint }

-- The parked ambulance handover point (docs 10 section 3.1, MVP).
LandVehicleConfig.AmbulancePoints = {
	{
		id = "HavenSands",
		-- TODO(WorldConfig): Haven Sands car park, rear doors toward the beach
		cframe = CFrame.lookAt(Vector3.new(176, 4, -70), Vector3.new(176, 4, -200)),
	},
}

LandVehicleConfig.Despawn = {
	emptySeconds = 120, -- an empty vehicle goes after this long ...
	distance = 300, -- ... with its owner further than this (studs)
}

function LandVehicleConfig.get(id: string): Spec?
	local spec = (LandVehicleConfig :: any)[id]
	if type(spec) == "table" and spec.id == id then
		return spec :: Spec
	end
	return nil
end

return LandVehicleConfig
