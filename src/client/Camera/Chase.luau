--!strict
-- Chase: the third-person spring-arm camera for the RIB, larger boats and cars.
-- Reads the sea well: the frame stays level with the horizon while the hull pitches and rolls
-- in it, the focus leads the boat (look-ahead along its velocity), its height is low-passed so the
-- swell visibly lifts the hull, and the camera never dips under the wave surface. The arm is a
-- sphere cast from the focus (own hull and terrain included) that snaps in on a hit and eases
-- back out. The player can orbit (right-drag, right stick, touch drag) and zoom; the arm swings
-- back behind the boat after a few seconds without input while under way.
local Workspace = game:GetService("Workspace")

local CameraMath = require(script.Parent.CameraMath)
local Comfort = require(script.Parent.Comfort)

local Chase = {}

export type Ctx = {
	model: Model,
	root: BasePart,
	topSpeed: number,
	exclude: { Instance },
	waveHeight: ((Vector3) -> number)?,
	telemetry: { slam: number }?,
}

local state = {
	heading = 0,
	yaw = 0,
	pitch = math.rad(13),
	zoom = 1,
	idle = 10,
	arm = 0,
	focusY = 0,
	focus = Vector3.zero,
	trauma = 0,
	clock = 0,
	fresh = true,
}

local baseDistance = 24
local focusHeight = 4
local restPitch = math.rad(13)

-- Sizes the arm from the hull: about 1.6 hull lengths back, focus above the deck. A small craft
-- (the jet ski and its sled) sits closer, lower and flatter: it fills less of the frame and the
-- casualty / throw target ahead stays on the horizon. The cold open sits flatter still.
function Chase.enter(model: Model, root: BasePart)
	local _, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Z)
	local small = length < 20
	if small then
		baseDistance = math.clamp(length * 1.1 + 3, 14, 28)
		focusHeight = math.clamp(size.Y * 0.55, 2.2, 4.2) + 0.9
	else
		baseDistance = math.clamp(length * 1.6 + 8, 16, 70)
		focusHeight = math.clamp(size.Y * 0.6, 2.5, 12) + 1.5
	end
	restPitch = if model:GetAttribute("ColdOpen") == true
		then math.rad(4)
		elseif small then math.rad(8)
		else math.rad(13)
	state.heading = CameraMath.heading(root.CFrame)
	state.yaw, state.pitch, state.zoom, state.idle = 0, restPitch, 1, 10
	state.arm = baseDistance
	state.focusY = root.Position.Y
	state.focus = root.Position
	state.trauma = 0
	state.fresh = true
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
end

function Chase.zoom(delta: number)
	state.zoom = math.clamp(state.zoom * (1 + delta), 0.55, 2.2)
end

function Chase.addTrauma(amount: number)
	state.trauma = math.clamp(state.trauma + amount, 0, 1)
end

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true
castParams.RespectCanCollide = true

-- One frame. `lookDelta` (yaw, pitch) radians of orbit input this frame.
function Chase.update(dt: number, ctx: Ctx, lookDelta: Vector2): CFrame
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	state.clock += dt
	local root = ctx.root
	local vel = root.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

	-- heading: the hull's, low-passed so wave yaw doesn't swing the whole frame; cars have no
	-- waves, so the camera stays tight behind them through a turn
	local land = ctx.model:GetAttribute("LandVehicle") == true
	local hullHeading = CameraMath.heading(root.CFrame)
	local headingLag = if state.fresh then 0 elseif land then 0.15 else 0.35
	state.heading = CameraMath.dampAngle(state.heading, hullHeading, headingLag, dt)

	-- orbit input, then the swing back behind the boat
	if lookDelta.Magnitude > 1e-5 then
		state.idle = 0
	else
		state.idle += dt
	end
	state.yaw = CameraMath.wrap(state.yaw + lookDelta.X)
	state.pitch = math.clamp(state.pitch - lookDelta.Y, math.rad(-5), math.rad(70))
	if state.idle > 2.5 and flatSpeed > 5 then
		state.yaw = CameraMath.dampAngle(state.yaw, 0, 0.9, dt)
		state.pitch = CameraMath.damp(state.pitch, restPitch, 1.2, dt)
	end

	-- focus: above the deck, leading the boat, its height low-passed against the swell
	local ahead = CameraMath.lookAhead(vel, 0.45, baseDistance * 0.45)
	state.focusY = if state.fresh
		then root.Position.Y
		else CameraMath.damp(state.focusY, root.Position.Y, 0.3, dt)
	local focusTarget = Vector3.new(root.Position.X, state.focusY + focusHeight, root.Position.Z)
		+ ahead
	state.focus = if state.fresh
		then focusTarget
		else CameraMath.damp(state.focus, focusTarget, 0.06, dt)
	local focus = state.focus

	-- the arm, pulled back a little more at speed
	local desired = baseDistance
		* state.zoom
		* (1 + 0.15 * math.clamp(flatSpeed / math.max(ctx.topSpeed, 1), 0, 1))
	local dir = CameraMath.chaseOffset(state.heading, state.yaw, state.pitch, 1)
	castParams.FilterDescendantsInstances = ctx.exclude
	local hit = Workspace:Spherecast(focus, 0.8, dir * desired, castParams)
	local length = CameraMath.armDistance(desired, if hit then hit.Distance else nil, 0.6, 3)
	state.arm = CameraMath.relaxArm(if state.fresh then length else state.arm, length, 0.4, dt)
	local pos = focus + dir * state.arm

	-- stay above the water surface (the ocean mesh has no collision)
	if ctx.waveHeight then
		pos = CameraMath.aboveSwell(pos, ctx.waveHeight(pos), 1.6)
	end

	-- slams give a short, small shake; the horizon otherwise stays level
	if ctx.telemetry and ctx.telemetry.slam > 3 then
		Chase.addTrauma(math.min(ctx.telemetry.slam * 0.015, 0.4))
	end
	state.trauma = math.max(state.trauma - dt * 1.6, 0)
	local s = CameraMath.shake(
		state.trauma,
		Comfort.get("shake") * 0.6 * Comfort.motionScale(),
		state.clock,
		math.noise
	)
	local cf = CFrame.lookAt(pos, focus) * CFrame.Angles(s.X, s.Y, s.Z)
	camera.CFrame = cf
	local fov = Comfort.get("fov") - 5
	if Comfort.get("speedFov") then
		fov = CameraMath.speedFov(fov, flatSpeed, ctx.topSpeed, 6)
	end
	camera.FieldOfView = CameraMath.damp(camera.FieldOfView, fov, 0.25, dt)
	state.fresh = false
	return cf
end

return Chase
