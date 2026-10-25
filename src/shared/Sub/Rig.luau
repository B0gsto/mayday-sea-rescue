--!strict
-- Sub/Rig: applies Sub/Dive to a submarine model (PrimaryPart = HullRoot). Run it wherever the
-- assembly is simulated, once per RunService.PreSimulation: the driver's client (SubController) and
-- the server for an empty sub (zero input: it floats, or holds its depth). The sea has no Terrain
-- water, so nothing else holds it up: a LinearVelocity carries all of it (gravity included) and an
-- AlignOrientation keeps it level. Both have finite force, so it still bumps off rocks.
-- Writes the model attribute Submerged (bool) for the camera and lights.
local Workspace = game:GetService("Workspace")

local Dive = require(script.Parent.Dive)
local Simulator = require(script.Parent.Parent.Boat.Simulator)
local WorldConfig = require(script.Parent.Parent.Config.WorldConfig)

local Rig = {}

local states: { [Model]: Dive.State } = setmetatable({}, { __mode = "k" }) :: any
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }

local function movers(root: BasePart): (LinearVelocity, AlignOrientation)
	local lv = root:FindFirstChild("SubVelocity") :: LinearVelocity?
	local ao = root:FindFirstChild("SubAlign") :: AlignOrientation?
	if lv and ao then
		return lv, ao
	end
	local a = Instance.new("Attachment")
	a.Name = "SubAttach"
	a.Parent = root
	local newLv = Instance.new("LinearVelocity")
	newLv.Name = "SubVelocity"
	newLv.Attachment0 = a
	newLv.RelativeTo = Enum.ActuatorRelativeTo.World
	newLv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	newLv.Parent = root
	local newAo = Instance.new("AlignOrientation")
	newAo.Name = "SubAlign"
	newAo.Attachment0 = a
	newAo.Mode = Enum.OrientationAlignmentMode.OneAttachment
	newAo.Responsiveness = 8
	newAo.MaxTorque = 1e7
	newAo.Parent = root
	return newLv, newAo
end

-- The seabed under a point (Terrain), else the generated floor.
function Rig.floorAt(pos: Vector3): number
	local hit = Workspace:Raycast(pos, Vector3.new(0, -400, 0), params)
	return if hit then hit.Position.Y else WorldConfig.Terrain.seabedFloorY
end

-- throttle, steer, dive: -1..1 (dive +1 = rise). surfaceY: the water at the sub (the client passes
-- the drawn ocean height); defaults to the shared wave field.
function Rig.step(
	model: Model,
	throttle: number,
	steer: number,
	dive: number,
	dt: number,
	surfaceY: number?
): Dive.State?
	local root = model.PrimaryPart
	if not root or root.Anchored then
		return nil
	end
	local pos = root.Position
	local s = states[model]
	if not s then
		local look = root.CFrame.LookVector
		s = Dive.new(math.atan2(-look.X, -look.Z))
		states[model] = s
	end
	local sea = surfaceY or Simulator.waterHeight(pos.X, pos.Z, Workspace:GetServerTimeNow())
	Dive.step(s, throttle, steer, dive, pos.Y, sea, Rig.floorAt(pos), dt)
	local lv, ao = movers(root)
	lv.MaxForce = root.AssemblyMass * (Workspace.Gravity + 30)
	lv.VectorVelocity = Vector3.new(-math.sin(s.yaw) * s.speed, s.vy, -math.cos(s.yaw) * s.speed)
	ao.CFrame = CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(s.pitch, 0, s.roll)
	if model:GetAttribute("Submerged") ~= s.submerged then
		model:SetAttribute("Submerged", s.submerged)
	end
	return s
end

-- Forget the cached heading (call when another machine takes over the simulation).
function Rig.clear(model: Model)
	states[model] = nil
end

return Rig
