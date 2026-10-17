--!strict
-- TowMotion (stream b): the server half of the physical tow, so the scripted tow in RescueService
-- can move the casualty with the same TowLine spring-damper the towing client runs (shared/Tow).
-- Not wired yet (RescueService is not ours). To wire it, in RescueService.stepTow replace the
-- "keep" leash with:
--   boat.motion = boat.motion or TowMotion.new(boat.floater, hitch, towLength(tower), boat.hull.Size.Z)
--   TowMotion.step(boat.motion, boat.floater, hitch, hitchVelocity, dt, env)
--   if TowMotion.parted(boat.motion) then -- release the tow, OnTowLost (the crew re-passes)
-- and set the length from a client request (a new `Ops_TowLength` remote: (opId, studs), clamped
-- 30..150) with TowMotion.setLength. CONTRACT.md "Operations v2" has the note.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowLine =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tow"):WaitForChild("TowLine"))

local TowMotion = {}

export type Floater = { x: number, z: number, yaw: number }
export type Motion = { line: TowLine.Line }

-- RescueService floaters face -Z at yaw 0 (bow at -Z); TowLine heading has forward (sin, cos).
local function headingOf(yaw: number): number
	return yaw + math.pi
end

function TowMotion.new(f: Floater, hitch: Vector3, lengthStuds: number, lwlStuds: number?): Motion
	local line = TowLine.new({
		lengthStuds = lengthStuds,
		lwlStuds = lwlStuds or 14,
		bridle = true,
		x = f.x,
		z = f.z,
		heading = headingOf(f.yaw),
	})
	local bx, bz = TowLine.bowPosition(line)
	local gap = Vector3.new(hitch.X - bx, 0, hitch.Z - bz).Magnitude
	TowLine.setLength(line, math.max(lengthStuds, gap + 1))
	return { line = line }
end

function TowMotion.setLength(m: Motion, lengthStuds: number)
	TowLine.setLength(m.line, math.clamp(lengthStuds, 30, 150))
end

-- Advances the tow and writes the casualty floater's x, z and yaw.
function TowMotion.step(
	m: Motion,
	f: Floater,
	hitch: Vector3,
	hitchVelocity: Vector3,
	dt: number,
	env: TowLine.Env?
)
	TowLine.step(m.line, hitch.X, hitch.Z, hitchVelocity.X, hitchVelocity.Z, dt, env)
	f.x, f.z = TowLine.hullPosition(m.line)
	f.yaw = m.line.heading - math.pi
end

function TowMotion.parted(m: Motion): boolean
	return m.line.parted
end

function TowMotion.tension(m: Motion): number
	return m.line.tension
end

return TowMotion
