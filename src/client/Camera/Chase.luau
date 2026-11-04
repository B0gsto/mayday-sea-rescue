--!strict
-- Chase: the third-person spring-arm camera for the RIB and larger boats.
-- Reads the sea well: the frame stays level with the horizon while the hull pitches and rolls
-- in it, the focus leads the boat (look-ahead along its nose), its height is low-passed so the
-- swell visibly lifts the hull, and the camera never dips under the wave surface. The arm is a
-- sphere cast from the hull (own craft and characters excluded) that snaps in on a hit and eases
-- back out. The player can orbit (right-drag, right stick, touch drag) and zoom; the arm swings
-- back behind the craft within about a second of steering, or a few seconds without input.
-- Cold open: when the casualty climbs aboard, the arm swings round once to frame home (your berth) past the
-- rider, holds, then swings back (live 2026-11-01: phone riders boarded at speed bow-out, home dead astern,
-- and drove on away from it). A cut under Reduce motion.
-- Landing (docs/30): a boat lands bow to the open sea with the Upgrade board behind it, so the camera eases to a shot of
-- both (Chase.frameStation). It takes no control and ends at the first throttle, steer or look. A cut under Reduce motion.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UpgradeStation = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UpgradeStation")
)

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
	aboard = false,
	lookUntil = 0, -- state.clock until which the arm frames home
	frameIsland = nil :: number?, -- the station framed since landing, until the player acts
	frameShown = 1, -- the island of the last frame, for the ease out
	frameWeight = 0,
}
local FRAME_EASE = 0.35 -- s -- tune
local FRAME_SPEED = 6 -- studs/s: a boat on the throttle (the idle creep is about 4); touch drives no seat floats
local FRAME_LEFT = 100 -- studs from the landing: it left some other way

local baseDistance = 24
local focusHeight = 4
local restPitch = math.rad(13)
-- studs over the hull root the open-seat focus sits: a seated rider's head top is ~5.4 on the jet ski
Chase.RIDER_FOCUS = 6.5
-- a passenger sits behind the rider, between them and the camera (verify 2026-10-26): with one aboard the
-- pivot rises and the arm looks down a little more, so they drop to the frame's lower edge
local PASSENGER_LIFT, PASSENGER_PITCH = 2, math.rad(7)
local LOOK_HOME = 2.2 -- s the arm frames home after the cold-open pickup (swing ~0.7 s, then hold) -- tune
local rider = false
local phone = false

-- Sizes the arm from the hull: about 1.6 hull lengths back, focus above the deck. A small craft
-- (the jet ski and its sled) sits closer and flatter: it fills less of the frame and the casualty / throw
-- target ahead stays near the horizon. Its rider sits in the line of sight, so the pivot rides over their
-- head and the arm looks down past them (playtest v46: the call pin and survivor hid behind the head).
-- The cold open sits flatter still. The sub (small, closed cockpit) keeps the low deck focus.
-- On a phone (`touch`) the arm sits a little closer: the craft reads on the small screen.
function Chase.enter(model: Model, root: BasePart, touch: boolean?)
	phone = touch == true
	local _, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Z)
	local small = length < 20
	rider = small and model:GetAttribute("Sub") ~= true
	if rider then
		baseDistance = math.clamp(length * 1.1 + 3, 14, 28)
		focusHeight = Chase.RIDER_FOCUS
	elseif small then
		baseDistance = math.clamp(length * 1.1 + 3, 14, 28)
		focusHeight = math.clamp(size.Y * 0.55, 2.2, 4.2) + 0.9
	else
		baseDistance = math.clamp(length * 1.6 + 8, 16, 70)
		focusHeight = math.clamp(size.Y * 0.6, 2.5, 12) + 1.5
	end
	restPitch = if model:GetAttribute("ColdOpen") == true
		then math.rad(5)
		elseif rider then math.rad(10)
		elseif small then math.rad(8)
		else math.rad(13)
	baseDistance *= tonumber(model:GetAttribute("ChasePull")) or 1 -- a tall level's pieces stay in frame
	if phone then
		baseDistance *= 0.88
	end
	state.heading = CameraMath.heading(root.CFrame)
	state.yaw, state.pitch, state.zoom, state.idle = 0, restPitch, 1, 10
	state.arm = baseDistance
	state.focusY = root.Position.Y
	state.focus = root.Position
	state.trauma = 0
	state.fresh = true
	state.aboard, state.lookUntil = false, 0
	Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
end

-- Just landed in this island's bay: ease to the boat and the board.
function Chase.frameStation(island: number)
	state.frameIsland, state.frameShown = island, island
	if Comfort.reducedMotion() then
		state.frameWeight = 1
	end
end

-- The hull jumped (Go back): behind it at once, no swing across the map.
function Chase.snap()
	state.yaw, state.idle, state.fresh = 0, 10, true
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

-- A sphere cast that skips what cannot hide the view (CameraMath.occludes) and characters, so the arm
-- pulls in under dock roofs and building meshes that do not collide. `params` gains the skipped parts.
function Chase.cast(
	origin: Vector3,
	radius: number,
	dir: Vector3,
	params: RaycastParams
): RaycastResult?
	for _ = 1, 6 do
		local hit = Workspace:Spherecast(origin, radius, dir, params)
		if not hit then
			return nil
		end
		local part = hit.Instance
		local who = part:FindFirstAncestorOfClass("Model")
		local person = who ~= nil and who:FindFirstChildOfClass("Humanoid") ~= nil
		if not person and CameraMath.occludes(part.CanCollide, part.Transparency, part.Size) then
			return hit
		end
		params:AddToFilter(part)
	end
	return nil
end

-- One frame. `lookDelta` (yaw, pitch) radians of orbit input this frame.
function Chase.update(dt: number, ctx: Ctx, lookDelta: Vector2): CFrame
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	state.clock += dt
	local root = ctx.root
	local vel = root.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local aboard = rider and (tonumber(ctx.model:GetAttribute("SurvivorCount")) or 0) > 0
	local rest = restPitch + (if aboard then PASSENGER_PITCH else 0)
	if aboard and not state.aboard and ctx.model:GetAttribute("ColdOpen") == true then
		state.lookUntil = state.clock + LOOK_HOME
	end
	state.aboard = aboard

	-- heading: the hull's, with a short lag so a turn reads but the nose never leaves the frame
	-- (0.35 s lost the view in hard A/D turns, real-client playtest)
	local hullHeading = CameraMath.heading(root.CFrame)
	local headingLag = if state.fresh then 0 else 0.11
	state.heading = CameraMath.dampAngle(state.heading, hullHeading, headingLag, dt)

	-- orbit input, then the swing back behind the boat
	if lookDelta.Magnitude > 1e-5 then
		state.idle, state.lookUntil = 0, 0 -- the player's own look ends the home shot
	else
		state.idle += dt
	end
	state.yaw = CameraMath.wrap(state.yaw + lookDelta.X)
	state.pitch = math.clamp(state.pitch - lookDelta.Y, math.rad(-5), math.rad(70))
	-- steering swings the arm back behind the craft within about a second; idle under way, slower
	local steering = math.abs(root.AssemblyAngularVelocity.Y) > 0.25
	local bay = Players.LocalPlayer:GetAttribute("BayCFrame")
	if state.clock < state.lookUntil and typeof(bay) == "CFrame" then
		local want = CameraMath.yawToward(state.heading, root.Position, bay.Position)
		state.yaw = if Comfort.reducedMotion()
			then want
			else CameraMath.dampAngle(state.yaw, want, 0.18, dt)
	elseif state.idle > 0.3 and steering then
		state.yaw = CameraMath.dampAngle(state.yaw, 0, 0.22, dt)
		state.pitch = CameraMath.damp(state.pitch, rest, 0.3, dt)
	elseif state.idle > 2.5 and flatSpeed > 5 then
		state.yaw = CameraMath.dampAngle(state.yaw, 0, 0.9, dt)
		state.pitch = CameraMath.damp(state.pitch, rest, 1.2, dt)
	end

	-- focus: above the deck, leading along the nose (a drifting hull's velocity swung it sideways),
	-- its height low-passed against the swell
	local nose = CameraMath.chaseOffset(state.heading, math.pi, 0, 1)
	local ahead = nose * math.clamp(vel:Dot(nose) * 0.4, 0, baseDistance * 0.4)
	state.focusY = if state.fresh
		then root.Position.Y
		else CameraMath.damp(state.focusY, root.Position.Y, 0.3, dt)
	local lift = focusHeight + (if aboard then PASSENGER_LIFT else 0)
	local focusTarget = Vector3.new(root.Position.X, state.focusY + lift, root.Position.Z) + ahead
	state.focus = if state.fresh
		then focusTarget
		else CameraMath.damp(state.focus, focusTarget, 0.06, dt)
	local focus = state.focus
	castParams.FilterDescendantsInstances = ctx.exclude
	-- the lead must not push the focus through a quay wall, or the arm cast starts inside it
	local hull = Vector3.new(root.Position.X, state.focusY + lift, root.Position.Z)
	local lead = focus - hull
	if lead.Magnitude > 0.5 then
		local block = Chase.cast(hull, 0.8, lead, castParams)
		if block then
			focus = hull + lead.Unit * math.max(block.Distance - 0.6, 0)
		end
	end

	-- the arm, pulled back a little more at speed
	local desired = baseDistance
		* state.zoom
		* (1 + 0.15 * math.clamp(flatSpeed / math.max(ctx.topSpeed, 1), 0, 1))
	local dir = CameraMath.chaseOffset(state.heading, state.yaw, state.pitch, 1)
	local hit = Chase.cast(focus, 0.8, dir * desired, castParams)
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
	local cf = CFrame.lookAt(pos, focus)

	-- the landing shot over the arm: any input hands the view straight back
	local island = state.frameIsland
	if island then
		local seat = ctx.model:FindFirstChild("DriverSeat")
		local landing = UpgradeStation.landing(island).Position
		if lookDelta.Magnitude > 1e-5 then
			state.frameIsland = nil
			local _, board = UpgradeStation.shot(island, 0)
			state.yaw = CameraMath.yawToward(state.heading, root.Position, board) -- the orbit carries on from this side
		elseif
			flatSpeed > FRAME_SPEED
			or steering
			or (seat and seat:IsA("VehicleSeat") and (seat.ThrottleFloat ~= 0 or seat.SteerFloat ~= 0))
			or (root.Position - landing).Magnitude > FRAME_LEFT
		then
			state.frameIsland = nil
		end
	end
	local reduced = Comfort.reducedMotion()
	local wanted = if state.frameIsland then 1 else 0
	state.frameWeight = if reduced then wanted else CameraMath.damp(state.frameWeight, wanted, FRAME_EASE, dt)
	if state.frameWeight > 0.002 then
		local _, size = ctx.model:GetBoundingBox()
		local shotAt, shotFocus = UpgradeStation.shot(state.frameShown, math.max(size.X, size.Z))
		cf = cf:Lerp(CFrame.lookAt(shotAt, shotFocus), state.frameWeight)
	end

	cf *= CFrame.Angles(s.X, s.Y, s.Z)
	camera.CFrame = cf
	local fov = Comfort.get("fov") - 5
	if Comfort.get("speedFov") and not Comfort.reducedMotion() then
		-- a smaller kick on a phone: the same swing reads stronger on a small screen
		-- docs/30: the kick grows with the boat's level
		local kick = (if phone then 4 else 6) + math.clamp((ctx.topSpeed - 80) / 100, 0, 8)
		fov = CameraMath.speedFov(fov, flatSpeed, ctx.topSpeed, kick)
	end
	camera.FieldOfView = CameraMath.damp(camera.FieldOfView, fov, 0.25, dt)
	state.fresh = false
	return cf
end

return Chase
