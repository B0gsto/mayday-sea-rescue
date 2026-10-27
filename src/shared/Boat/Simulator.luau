--!strict
-- Simulator: applies Buoyancy math to a boat's constraints (VectorForce per float point, a
-- DriveForce VectorForce and a DriveTorque Torque; no deprecated Body* movers). Runs wherever the
-- assembly is simulated: on the driver's client (BoatController, which owns the boat), and on the
-- server for empty drifting boats (VehicleService). Call step() once per
-- RunService.PreSimulation; the constraint values hold for the physics substeps until the next call.
--
-- Rigs are found by name on the root part (see Builder).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Buoyancy = require(script.Parent.Buoyancy)
local VehicleConfig = require(script.Parent.Parent.Config.VehicleConfig)
local VehicleUpgrades = require(script.Parent.Parent.VehicleUpgrades)
local Waves = require(script.Parent.Parent.Waves)
local WeatherMath = require(script.Parent.Parent.WeatherMath)

export type Rig = {
	root: BasePart,
	points: { Attachment },
	forces: { VectorForce },
	drive: VectorForce,
	torque: Torque,
	draft: number,
	handling: Buoyancy.Handling,
	inertia: Vector3, -- box moments about local X, Y, Z per unit mass; scaled by real mass per step
	wakeSpeed: number, -- the stern wave's speed, lagging the hull's (Buoyancy.wakeCatchUp)
	lastTime: number,
}

-- Per-step telemetry (read by BoatController for the HUD, VFX and the rider kill cord).
export type Telemetry = {
	speed: number, -- forward, studs/s
	contact: number, -- 0..1 mean float point wetness
	slam: number, -- summed slam strength this step (studs/s)
	trim: number, -- target trim, radians
	pitch: number, -- actual pitch, radians bow up
	roll: number, -- actual roll, radians starboard down
	planing: number, -- 0..1
}

-- Handling for towed / unknown hulls: no engine, moderate keel.
local GENERIC_HANDLING: Buoyancy.Handling = {
	topSpeed = 15,
	accel = 3,
	brakeDecel = 3,
	turnRate = 20,
	lateralGrip = 0.5,
	turnRadiusSlow = 20,
	maxLateralG = 0.3,
	pivotSpeed = 0,
	offThrottleSteer = 1,
	humpSpeed = 0.5,
	planingSpeed = 1,
	humpTrim = 0,
	runningTrim = 0,
	squatTrim = 0,
	planingLift = 0,
	leanFactor = 0,
	maxLean = 0,
	dampingRatio = 0.5,
	idleCreep = 0,
	approachSpeed = 5,
}

local Simulator = {}

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any
-- the driver's SkillGrip bonus (BoatController; 1 = no change), local to the simulating machine
local gripBoost: { [Model]: number? } = setmetatable({}, { __mode = "k" }) :: any
local speedBoost: { [Model]: number? } = setmetatable({}, { __mode = "k" }) :: any

-- CONTRACT: Weather (stream D) at ReplicatedStorage.Shared.Weather with getWaveParams(position, now).
-- Loaded lazily and dynamically so this module still works before Weather.luau lands.
local weather: any = nil
local weatherTried = false
local fallbackParams: Waves.WaveParams? = nil

local function getWeather(): any
	if not weatherTried then
		weatherTried = true
		local shared = ReplicatedStorage:FindFirstChild("Shared")
		local module = shared and shared:FindFirstChild("Weather")
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require :: any, module)
			if ok and type(result) == "table" and type(result.getWaveParams) == "function" then
				weather = result
			else
				warn(`[Simulator] Weather failed to load, using calm waves: {result}`)
			end
		end
	end
	return weather
end

-- The client's held sea (WeatherController's LocalStormIntensity: the cold open, then a 5 s
-- blend back). Absent on the server, so the shared weather is used exactly there.
local localCache: { [string]: { q: number, wind: number, params: Waves.WaveParams } } = {}

local function localWaveParams(w: any, position: Vector3): Waves.WaveParams?
	local intensity = Lighting:GetAttribute("LocalStormIntensity")
	if
		type(intensity) ~= "number"
		or type(w.getZoneAt) ~= "function"
		or type(w.getWindDirection) ~= "function"
	then
		return nil
	end
	local zone = w.getZoneAt(position)
	local q = WeatherMath.quantize(math.clamp(intensity, 0, 1))
	local wind = w.getWindDirection()
	local entry = localCache[zone.id]
	if entry and entry.q == q and entry.wind == wind then
		return entry.params
	end
	local params = Waves.paramsFor(q, zone.shelter, wind)
	localCache[zone.id] = { q = q, wind = wind, params = params }
	return params
end

function Simulator.waveParams(position: Vector3, now: number): Waves.WaveParams
	local w = getWeather()
	if w then
		local held = localWaveParams(w, position)
		if held then
			return held
		end
		return w.getWaveParams(position, now)
	end
	if not fallbackParams then
		fallbackParams = Waves.paramsFor(0, 0, 0)
	end
	return fallbackParams :: Waves.WaveParams
end

-- Storm intensity 0..1 from Weather (0 before Weather loads).
function Simulator.stormIntensity(now: number?): number
	local w = getWeather()
	if w and type(w.getIntensity) == "function" then
		local ok, value = pcall(w.getIntensity, now)
		if ok and type(value) == "number" then
			return value
		end
	end
	return 0
end

function Simulator.waterHeight(x: number, z: number, now: number): number
	return Waves.heightAt(x, z, now, Simulator.waveParams(Vector3.new(x, 0, z), now))
end

function Simulator.getRig(model: Model): Rig?
	local cached = rigs[model]
	if cached and cached.root.Parent == model then
		return cached
	end
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local points, forces = {}, {}
	local i = 1
	while true do
		local a = root:FindFirstChild(`Float{i}`)
		local f = root:FindFirstChild(`FloatForce{i}`)
		if not (a and a:IsA("Attachment") and f and f:IsA("VectorForce")) then
			break
		end
		table.insert(points, a)
		table.insert(forces, f)
		i += 1
	end
	local drive = root:FindFirstChild("DriveForce")
	local torque = root:FindFirstChild("DriveTorque")
	if
		#points == 0 or not (drive and drive:IsA("VectorForce") and torque and torque:IsA("Torque"))
	then
		return nil
	end
	local vehicleId = model:GetAttribute("VehicleId")
	local spec = if type(vehicleId) == "string" then VehicleConfig.get(vehicleId) else nil
	-- G66: fitted boatyard upgrades change the handling this hull simulates
	spec = if spec then VehicleUpgrades.apply(spec, model:GetAttribute("VehicleUpgrades")) else nil
	local draft = model:GetAttribute("Draft")
	local size = if spec then spec.hullSize else root.Size
	local ix, iy, iz = Buoyancy.boxInertia(1, size)
	local rig: Rig = {
		root = root,
		points = points,
		forces = forces,
		drive = drive,
		torque = torque,
		draft = if type(draft) == "number" then draft elseif spec then spec.draft else 0.5,
		handling = if spec then spec else GENERIC_HANDLING,
		inertia = Vector3.new(ix, iy, iz),
		wakeSpeed = 0,
		lastTime = 0,
	}
	rigs[model] = rig
	return rig
end

-- One simulation step. throttle and steer are -1..1 (0 for an empty or towed boat).
-- Model attributes read here: SpeedMultiplier (gear bonus), ApproachMode (bool, slow-speed governor),
-- EngineRunning (false = kill cord pulled: no thrust, no idle creep).
function Simulator.step(model: Model, throttle: number, steer: number, now: number?): Telemetry?
	local rig = Simulator.getRig(model)
	if not rig then
		return nil
	end
	local root = rig.root
	if root.Anchored then
		return nil
	end
	local t = now or Workspace:GetServerTimeNow()
	local dt = math.clamp(t - rig.lastTime, 0, 0.1)
	rig.lastTime = t
	local cf = root.CFrame
	local params = Simulator.waveParams(cf.Position, t)
	local mass = root.AssemblyMass
	local gravity = Workspace.Gravity
	local h = rig.handling
	local mult = model:GetAttribute("SpeedMultiplier")
	local speedMult =
		math.clamp((if type(mult) == "number" then mult else 1) * (speedBoost[model] or 1), 0.5, 3)
	local approach = model:GetAttribute("ApproachMode") == true
	local engine = model:GetAttribute("EngineRunning") ~= false

	local velocity = root.AssemblyLinearVelocity
	local omega = root.AssemblyAngularVelocity
	local forward = Buoyancy.flatForward(cf.LookVector)
	local forwardSpeed = velocity:Dot(forward)

	-- Hydrodynamic targets: planing lift, trim (hump, squat, own wake) and lean into the turn.
	rig.wakeSpeed += (forwardSpeed - rig.wakeSpeed) * math.min(1, dt / Buoyancy.WAKE_LAG)
	local catchUp, wakePush = Buoyancy.wakeCatchUp(rig.wakeSpeed, forwardSpeed, h)
	local effThrottle = if engine then throttle else 0
	local planing = Buoyancy.planingFraction(forwardSpeed, h, speedMult)
	local trim = Buoyancy.trimTarget(forwardSpeed, effThrottle, h, speedMult, catchUp)
	local lean = Buoyancy.leanTarget(forwardSpeed, omega.Y, h, gravity)
	local planeLift = h.planingLift * planing

	local n = #rig.points
	local contact, slam = 0, 0
	for i, a in rig.points do
		local p = a.WorldPosition
		local depth = Waves.heightAt(p.X, p.Z, t, params) - p.Y
		local vy = root:GetVelocityAtPosition(p).Y
		local offset = Buoyancy.liftOffset(a.Position, rig.draft, planeLift, trim, lean)
		local fy, wet, hit =
			Buoyancy.pointForce(depth, vy, rig.draft, mass, gravity, n, offset, h.dampingRatio)
		rig.forces[i].Force = Vector3.new(0, fy, 0)
		contact += wet / n
		slam += hit / n
	end

	local grip = Buoyancy.grip(contact, gripBoost[model] or 1)
	local pitchRate = omega:Dot(cf.RightVector)
	local added = Buoyancy.addedResistance(pitchRate, slam)
	local thrust =
		Buoyancy.thrust(effThrottle, forwardSpeed, mass, h, grip, speedMult, approach, engine)
	local drag = Buoyancy.drag(velocity, forward, mass, h, grip, speedMult, added)
	rig.drive.Force = drag + forward * (thrust + mass * wakePush * grip)

	local inertia = rig.inertia * mass
	local yaw = Buoyancy.steerTorque(
		steer,
		forwardSpeed,
		omega.Y,
		inertia.Y,
		h,
		grip,
		speedMult,
		if approach then math.max(math.abs(effThrottle), 0.6) else effThrottle,
		gravity
	)
	-- Self-righting toward the trimmed and banked attitude, not dead level.
	local right = Buoyancy.rightOf(forward)
	local flat = CFrame.fromMatrix(Vector3.zero, right, Vector3.yAxis, -forward)
	local targetUp = (flat * CFrame.Angles(trim, 0, -lean)).UpVector
	local upright =
		Buoyancy.uprightTorque(cf.UpVector, omega, math.max(inertia.X, inertia.Z), targetUp, grip)
	rig.torque.Torque = upright + Vector3.new(0, yaw, 0)

	return {
		speed = forwardSpeed,
		contact = contact,
		slam = slam,
		trim = trim,
		pitch = math.asin(math.clamp(cf.LookVector.Y, -1, 1)),
		roll = math.asin(math.clamp(-cf.RightVector.Y, -1, 1)),
		planing = planing,
	}
end

-- The skill's grip multiplier for this hull (SkillGrip: 0.25 = +25% bite); nil resets to 1.
function Simulator.setGrip(model: Model, boost: number?)
	local b = 1
	if boost ~= nil then
		b = math.max(boost, 0)
	end
	gripBoost[model] = if b ~= 1 then b else nil
end

-- A short speed multiplier on top of SpeedMultiplier (the Nitro burst); nil or 1 resets it.
function Simulator.setBoost(model: Model, boost: number?)
	speedBoost[model] = if boost and boost ~= 1 then boost else nil
end

-- Zeroes every force (call when this machine stops simulating the boat).
function Simulator.clear(model: Model)
	gripBoost[model] = nil
	speedBoost[model] = nil
	local rig = Simulator.getRig(model)
	if not rig then
		return
	end
	for _, f in rig.forces do
		f.Force = Vector3.zero
	end
	rig.drive.Force = Vector3.zero
	rig.torque.Torque = Vector3.zero
end

-- World CFrame for a hull floating level at rest at (x, z), facing `look` (flattened).
function Simulator.restCFrame(
	model: Model,
	x: number,
	z: number,
	look: Vector3,
	now: number?
): CFrame
	local rig = Simulator.getRig(model)
	local t = now or Workspace:GetServerTimeNow()
	local waterY = Simulator.waterHeight(x, z, t)
	local floatY = if rig then rig.points[1].Position.Y else 0
	local draft = if rig then rig.draft else 0.5
	local pos = Vector3.new(x, Buoyancy.restRootY(waterY, draft, floatY), z)
	return CFrame.lookAt(pos, pos + Buoyancy.flatForward(look))
end

return Simulator
