--!strict
-- VehicleService's docs/23 (h) craft (WP-10a): builds them, places a launched helicopter, and runs the
-- server's half for an empty one (the pilot's client flies them: Heli/SubController).
--   Heli   lands itself: hands-off Heli/Flight sinking at AUTO_LAND to its floor (the ground under the
--          skids, or hovering Flight.WATER_CLEARANCE over the sea), then holds there.
--   Sub    holds on Sub/Rig with no input (the sea has no Terrain water: without it, it sinks).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeliBuilder = require(Shared:WaitForChild("Heli"):WaitForChild("Builder"))
local HeliFlight = require(Shared:WaitForChild("Heli"):WaitForChild("Flight"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))
local SubBuilder = require(Shared:WaitForChild("Sub"):WaitForChild("Builder"))
local SubRig = require(Shared:WaitForChild("Sub"):WaitForChild("Rig"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local Craft = {}

Craft.AUTO_LAND = 0.3 -- share of the climb speed an empty heli sinks at (9 studs/s) -- tune
Craft.LAUNCH_HOVER = 4 -- studs over its floor (the berth's water, or a roof over it) a heli launches at -- tune
local RAY_TOP = 120 -- studs above the berth the launch ray starts (over any boathouse roof)
local RAY_DEPTH = 600

local heliStates: { [Model]: HeliFlight.State } = setmetatable({}, { __mode = "k" }) :: any

-- The new model, its root anchored like Boat/Builder's (docked until a driver sits).
function Craft.build(spec: VehicleConfig.VehicleSpec): Model
	local model = if spec.craft == "Heli"
		then HeliBuilder.build(spec.id)
		else SubBuilder.build(spec.id)
	model.Name = spec.id;
	(model.PrimaryPart :: BasePart).Anchored = true
	return model
end

-- The first solid thing straight down from `from` (not the heli, not people), else nil.
local function groundBelow(from: Vector3, model: Model): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { model }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local hit = Workspace:Raycast(from, Vector3.new(0, -RAY_DEPTH, 0), params)
	return hit and hit.Position.Y
end

local function heliFloor(model: Model, at: Vector3, spec: HeliFlight.Spec): number
	return HeliFlight.floor(
		groundBelow(at, model),
		Simulator.waterHeight(at.X, at.Z, Workspace:GetServerTimeNow()),
		spec
	)
end

-- Where a launched heli starts: just over the berth at (at.X, at.Z), facing at's heading.
function Craft.heliLaunch(model: Model, at: CFrame): CFrame
	local spec = HeliFlight.spec(model:GetAttribute("VehicleId")) :: HeliFlight.Spec
	local top = Vector3.new(at.X, at.Y + RAY_TOP, at.Z)
	local pos = Vector3.new(at.X, heliFloor(model, top, spec) + Craft.LAUNCH_HOVER, at.Z)
	local look = Vector3.new(at.LookVector.X, 0, at.LookVector.Z)
	return CFrame.lookAt(pos, pos + (if look.Magnitude > 1e-3 then look else Vector3.zAxis))
end

-- One server step for an empty, server-owned craft. False: not ours.
function Craft.idle(model: Model, spec: VehicleConfig.VehicleSpec, dt: number): boolean
	local root = model.PrimaryPart
	if spec.craft == "Sub" then
		SubRig.step(model, 0, 0, 0, dt)
		return true
	elseif spec.craft ~= "Heli" then
		return false
	end
	if not root or root.Anchored then
		return true
	end
	local fspec = HeliFlight.spec(spec.id) :: HeliFlight.Spec
	local s = heliStates[model]
	if not s then
		s = HeliFlight.new(
			HeliFlight.headingOf(root.CFrame.LookVector),
			root.AssemblyLinearVelocity
		)
		heliStates[model] = s
	end
	local state = s :: HeliFlight.State
	local idle = { forward = 0, strafe = 0, yaw = 0, lift = -Craft.AUTO_LAND }
	HeliFlight.step(
		state,
		idle,
		fspec,
		root.Position.Y,
		heliFloor(model, root.Position, fspec),
		Vector3.zero,
		dt
	)
	local lift = root:FindFirstChild("Lift") :: LinearVelocity?
	local attitude = root:FindFirstChild("Attitude") :: AlignOrientation?
	if lift and attitude then
		lift.Enabled, attitude.Enabled = true, true
		lift.MaxForce = root.AssemblyMass * (Workspace.Gravity + fspec.accel * 2)
		lift.VectorVelocity = state.velocity
		attitude.CFrame = HeliFlight.attitude(state, fspec)
	end
	return true
end

-- A pilot took over: the next idle spell starts from the craft's pose then, not a stale one.
function Craft.clear(model: Model)
	heliStates[model] = nil
	SubRig.clear(model)
end

return Craft
