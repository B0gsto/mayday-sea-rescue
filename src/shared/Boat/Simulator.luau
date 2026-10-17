--!strict
-- Simulator: applies Buoyancy math to a boat's constraints (VectorForce per float point, a
-- DriveForce VectorForce and a DriveTorque Torque; no deprecated Body* movers). Runs wherever the
-- assembly is simulated: on the driver's client (BoatController, which owns the boat), and on the
-- server for empty drifting boats and unpiloted tows (VehicleService). Call step() once per
-- RunService.PreSimulation; the constraint values hold for the physics substeps until the next call.
--
-- Rigs are found by name on the root part (see Builder). Models that were not built by Builder
-- (for example an NPC boat being towed) get a rig from Simulator.ensureRig: 4 float points at the
-- root's bottom corners, draft from the model's "Draft" attribute or 30% of the root height.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Buoyancy = require(script.Parent.Buoyancy)
local VehicleConfig = require(script.Parent.Parent.Config.VehicleConfig)
local Waves = require(script.Parent.Parent.Waves)

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

function Simulator.waveParams(position: Vector3, now: number): Waves.WaveParams
	local w = getWeather()
	if w then
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

local function newForce(
	root: BasePart,
	name: string,
	attachment: Attachment,
	atCenter: boolean
): VectorForce
	local f = Instance.new("VectorForce")
	f.Name = name
	f.Attachment0 = attachment
	f.RelativeTo = Enum.ActuatorRelativeTo.World
	f.ApplyAtCenterOfMass = atCenter
	f.Force = Vector3.zero
	f.Parent = root
	return f
end

-- Adds float points and drive constraints to a model that has a PrimaryPart but no Builder rig.
-- Server-side so the instances replicate to whichever client simulates it.
function Simulator.ensureRig(model: Model)
	local root = model.PrimaryPart
	if not root or root:FindFirstChild("FloatForce1") then
		return
	end
	local half = root.Size / 2
	local i = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			i += 1
			local a = Instance.new("Attachment")
			a.Name = `Float{i}`
			a.Position = Vector3.new(sx * half.X * 0.8, -half.Y, sz * half.Z * 0.8)
			a.Parent = root
			newForce(root, `FloatForce{i}`, a, false)
		end
	end
	local center = Instance.new("Attachment")
	center.Name = "DriveAttachment"
	center.Parent = root
	newForce(root, "DriveForce", center, true)
	local torque = Instance.new("Torque")
	torque.Name = "DriveTorque"
	torque.Attachment0 = center
	torque.RelativeTo = Enum.ActuatorRelativeTo.World
	torque.Parent = root
	if model:GetAttribute("Draft") == nil then
		model:SetAttribute("Draft", math.max(root.Size.Y * 0.3, 0.2))
	end
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
	local speedMult = if type(mult) == "number" then math.clamp(mult, 0.5, 3) else 1
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

	local grip = Buoyancy.grip(contact)
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

-- Zeroes every force (call when this machine stops simulating the boat).
function Simulator.clear(model: Model)
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
