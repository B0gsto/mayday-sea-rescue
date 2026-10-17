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
}

-- Handling for towed / unknown hulls: no engine, moderate keel.
local GENERIC_HANDLING: Buoyancy.Handling =
	{ topSpeed = 20, accel = 6, brakeDecel = 6, turnRate = 30, lateralGrip = 0.5 }

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
	}
	rigs[model] = rig
	return rig
end

-- One simulation step. throttle and steer are -1..1 (0 for an empty or towed boat).
function Simulator.step(model: Model, throttle: number, steer: number, now: number?)
	local rig = Simulator.getRig(model)
	if not rig then
		return
	end
	local root = rig.root
	if root.Anchored then
		return
	end
	local t = now or Workspace:GetServerTimeNow()
	local cf = root.CFrame
	local params = Simulator.waveParams(cf.Position, t)
	local mass = root.AssemblyMass
	local gravity = Workspace.Gravity
	local n = #rig.points
	local contact = 0
	for i, a in rig.points do
		local p = a.WorldPosition
		local depth = Waves.heightAt(p.X, p.Z, t, params) - p.Y
		local vy = root:GetVelocityAtPosition(p).Y
		local fy, wet = Buoyancy.pointForce(depth, vy, rig.draft, mass, gravity, n)
		rig.forces[i].Force = Vector3.new(0, fy, 0)
		contact += wet / n
	end

	local mult = model:GetAttribute("SpeedMultiplier")
	local speedMult = if type(mult) == "number" then math.clamp(mult, 0.5, 3) else 1
	local velocity = root.AssemblyLinearVelocity
	local forward = Buoyancy.flatForward(cf.LookVector)
	local forwardSpeed = velocity:Dot(forward)
	local h = rig.handling
	local thrust = Buoyancy.thrust(throttle, forwardSpeed, mass, h, contact, speedMult)
	local drag = Buoyancy.drag(velocity, forward, mass, h, contact, speedMult)
	rig.drive.Force = drag + forward * thrust

	local omega = root.AssemblyAngularVelocity
	local inertia = rig.inertia * mass
	local yaw = Buoyancy.steerTorque(steer, forwardSpeed, omega.Y, inertia.Y, h, contact, speedMult)
	local upright = Buoyancy.uprightTorque(cf.UpVector, omega, math.max(inertia.X, inertia.Z))
	rig.torque.Torque = upright + Vector3.new(0, yaw, 0)
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
