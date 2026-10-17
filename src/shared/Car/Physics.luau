--!strict
-- Car physics in Roblox (docs 10 section 3.3): one rigid body (the "Chassis" root part, its centre
-- is the centre of mass) and a raycast per wheel. Each frame: cast every wheel's ray down the
-- body's -Y, read the surface (material, height above the sea, rain), hand the contacts to
-- Chassis.step, and apply the summed wheel forces and their moments about the centre of mass with
-- a world-space VectorForce and Torque. Gravity is Roblox's (Workspace.Gravity 29.43). Visual
-- wheels are welds whose C0 is set each frame (updateVisuals), on every client for nearby cars.
-- Runs where the assembly is owned: the driver's client, or the server for a coasting empty car.
local Workspace = game:GetService("Workspace")

local Chassis = require(script.Parent.Chassis)
local LandVehicleConfig = require(script.Parent.Parent.Config.LandVehicleConfig)
local Tyre = require(script.Parent.Tyre)
local Weather = require(script.Parent.Parent.Weather)

local Physics = {}

export type Sim = {
	model: Model,
	root: BasePart,
	derived: Chassis.Derived,
	state: Chassis.State,
	force: VectorForce?,
	torque: Torque?,
	params: RaycastParams,
	welds: { Weld? },
	spin: { number },
	compression: { number },
	contacts: { Chassis.Contact },
	results: { Chassis.WheelResult },
	telemetry: Chassis.Telemetry?,
	surfaces: { string },
	submerged: number, -- studs of water over the root (0 when dry)
}

local SEA_LEVEL = 0
local wetCache, wetAt = 0, -math.huge

local function wetness(): number
	local now = os.clock()
	if now - wetAt > 1 then
		wetAt = now
		local ok, intensity = pcall(Weather.getIntensity)
		wetCache = if ok and type(intensity) == "number" then Tyre.wetness(intensity) else 0
	end
	return wetCache
end

local function waterAt(position: Vector3): number
	local ok, h = pcall(Weather.heightAt, position)
	return if ok and type(h) == "number" then h else SEA_LEVEL
end

-- Rays skip other land vehicles through the collision group (they pass through each other,
-- docs 02 section 10) and this model; characters are filtered by the caller via `exclude`.
function Physics.new(model: Model, spec: LandVehicleConfig.Spec, extraMassKg: number?): Sim
	local root = model.PrimaryPart :: BasePart
	local derived = Chassis.prepare(spec, extraMassKg)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.IgnoreWater = true
	params.CollisionGroup = "LandVehicle"
	local welds: { Weld? } = {}
	for i, w in derived.wheels do
		local wheel = model:FindFirstChild("Wheel_" .. w.name)
		local weld = wheel and wheel:FindFirstChild("WheelWeld")
		welds[i] = if weld and weld:IsA("Weld") then weld else nil
	end
	local forceAt = root:FindFirstChild("CarForce")
	local torque = root:FindFirstChild("CarTorque")
	return {
		model = model,
		root = root,
		derived = derived,
		state = Chassis.newState(),
		force = if forceAt and forceAt:IsA("VectorForce") then forceAt else nil,
		torque = if torque and torque:IsA("Torque") then torque else nil,
		params = params,
		welds = welds,
		spin = table.create(#derived.wheels, 0),
		compression = table.create(#derived.wheels, 0),
		contacts = {},
		results = {},
		telemetry = nil,
		surfaces = {},
		submerged = 0,
	}
end

function Physics.setExclude(sim: Sim, extra: { Instance })
	local list: { Instance } = { sim.model }
	for _, inst in extra do
		table.insert(list, inst)
	end
	sim.params.FilterDescendantsInstances = list
end

-- Casts the rays and fills sim.contacts (and the frames each wheel's forces act in).
type Frame = { point: Vector3, fwd: Vector3, right: Vector3, up: Vector3 }

local function sense(sim: Sim): { Frame }
	local root = sim.root
	local cf = root.CFrame
	local up = cf.UpVector
	local wet = wetness()
	local frames: { Frame } = {}
	for i, w in sim.derived.wheels do
		local origin = cf:PointToWorldSpace(w.mount)
		local hit = Workspace:Raycast(origin, -up * w.rayLength, sim.params)
		local steer = if sim.results[i] then sim.results[i].steer else 0
		local look = (cf * CFrame.Angles(0, -steer, 0)).LookVector
		if hit then
			local n = hit.Normal
			local fwd = look - n * look:Dot(n)
			fwd = if fwd.Magnitude > 1e-3 then fwd.Unit else look
			local right = fwd:Cross(n)
			local compression = math.clamp(w.travel - (hit.Distance - w.radius), 0, w.travel)
			local pointVel = root:GetVelocityAtPosition(hit.Position)
			local surface = Tyre.surfaceFor(hit.Material.Name, hit.Position.Y - SEA_LEVEL)
			local wheelWet = wet
			if hit.Position.Y < waterAt(hit.Position) then
				wheelWet = 1
			end
			sim.compression[i] = compression
			sim.surfaces[i] = surface.id
			sim.contacts[i] = {
				contact = true,
				compression = compression,
				compressionSpeed = -root:GetVelocityAtPosition(origin):Dot(up),
				vLong = pointVel:Dot(fwd),
				vLat = pointVel:Dot(right),
				grip = Tyre.grip(surface, wheelWet),
				rolling = surface.rolling,
			}
			frames[i] = { point = hit.Position, fwd = fwd, right = right, up = up }
		else
			sim.compression[i] = 0
			sim.surfaces[i] = "Air"
			sim.contacts[i] = {
				contact = false,
				compression = 0,
				compressionSpeed = 0,
				vLong = 0,
				vLat = 0,
				grip = 0,
				rolling = 0,
			}
			frames[i] = { point = origin, fwd = look, right = cf.RightVector, up = up }
		end
	end
	return frames
end

-- One physics step: senses, runs the chassis, sets the VectorForce and Torque.
function Physics.step(sim: Sim, controls: Chassis.Controls, dt: number): Chassis.Telemetry
	dt = math.clamp(dt, 1 / 240, 1 / 20)
	local root = sim.root
	local frames = sense(sim)
	local vel = root.AssemblyLinearVelocity
	local speed = vel:Dot(root.CFrame.LookVector)
	local results, telemetry =
		Chassis.step(sim.derived, sim.state, controls, sim.contacts, speed, dt)
	sim.results = results
	sim.telemetry = telemetry
	local com = root.AssemblyCenterOfMass
	local force = Vector3.zero
	local torque = Vector3.zero
	for i, r in results do
		local f = frames[i]
		if sim.contacts[i].contact then
			local wf = f.up * r.fz + f.fwd * r.fx + f.right * r.fy
			force += wf
			torque += (f.point - com):Cross(wf)
		end
	end
	local v = vel.Magnitude
	if v > 0.1 then
		force -= vel.Unit * Chassis.drag(sim.derived, v)
	end
	-- wading: water drag on the body (a slipway launch is slow and heavy)
	local water = waterAt(com)
	sim.submerged = math.max(0, water - (com.Y - sim.derived.spec.cgHeight * 3))
	if sim.submerged > 0 and v > 0.1 then
		force -= vel * math.min(sim.submerged, 4) * sim.derived.mass * 0.15
	end
	if sim.force then
		sim.force.Force = force
	end
	if sim.torque then
		sim.torque.Torque = torque
	end
	return telemetry
end

-- Turns the force off (parked, anchored or handed to another machine).
function Physics.idle(sim: Sim)
	if sim.force then
		sim.force.Force = Vector3.zero
	end
	if sim.torque then
		sim.torque.Torque = Vector3.zero
	end
end

-- Places the visual wheels. With the physics running here it uses this frame's results;
-- otherwise (someone else's car) it casts its own rays and steers from the seat's SteerFloat.
function Physics.updateVisuals(sim: Sim, dt: number, simulated: boolean, steerInput: number?)
	if not simulated then
		sense(sim)
		local speed = sim.root.AssemblyLinearVelocity:Dot(sim.root.CFrame.LookVector)
		Chassis.updateSteer(sim.derived, sim.state, steerInput or 0, speed, dt)
	end
	for i, w in sim.derived.wheels do
		local weld = sim.welds[i]
		if not weld then
			continue
		end
		local r = sim.results[i]
		local steer, tread
		if simulated and r then
			steer, tread = r.steer, r.spinSpeed
		else
			steer = Chassis.wheelSteer(sim.derived, sim.state, w)
			tread = if sim.contacts[i] then sim.contacts[i].vLong else 0
		end
		sim.spin[i] = (sim.spin[i] - tread / w.radius * dt) % (2 * math.pi)
		local length = w.travel - (sim.compression[i] or 0)
		local centre = w.mount - Vector3.new(0, length, 0)
		weld.C0 = CFrame.new(centre)
			* CFrame.Angles(0, -steer, 0)
			* CFrame.Angles(sim.spin[i], 0, 0)
	end
end

return Physics
