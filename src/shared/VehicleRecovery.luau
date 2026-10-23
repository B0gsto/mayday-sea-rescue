--!strict
-- VehicleRecovery: when a player vehicle (car, boat, jet ski) is "weird" the server puts it back
-- upright. Pure timers (Lune-tested in tests/VehicleRecovery.spec.luau) plus the lift-and-settle
-- path both LandVehicleService and VehicleService glide the model along.
--   Flipped  on its side or roof (up vector past ~65 degrees) for FLIP_TIME while touching down
--   Stuck    the driver holds throttle but the vehicle barely moves for STUCK_TIME while touching down
--   Sunk     the caller's "off" flag (in terrain, beached, under water) for OFF_TIME
-- Airborne samples pause the flip and stuck timers (a legit jump or barrel roll never resets), and
-- after a reset nothing fires for COOLDOWN seconds (no reset loops).
local VehicleRecovery = {}

VehicleRecovery.UP_MIN = math.cos(math.rad(65)) -- UpVector.Y under this counts as flipped -- tune
VehicleRecovery.FLIP_TIME = 2 -- tune
VehicleRecovery.STUCK_TIME = 2 -- under the 3 s a player holds W in bursts (3.5 never fired: pinned for good) -- tune
VehicleRecovery.STUCK_SPEED = 1.5 -- studs/s -- tune
VehicleRecovery.THROTTLE_MIN = 0.5 -- tune
VehicleRecovery.OFF_TIME = 2.5 -- tune
VehicleRecovery.COOLDOWN = 6 -- tune
VehicleRecovery.GLIDE_TIME = 0.7 -- s of lift-and-settle -- tune
VehicleRecovery.GLIDE_LIFT = 4 -- studs at the top of the arc -- tune

export type Reason = "Flipped" | "Stuck" | "Sunk"
export type State = { flip: number, stuck: number, off: number, lastAt: number? }
export type Sample = {
	up: number, -- root UpVector.Y
	speed: number, -- studs/s
	throttle: number, -- -1..1 (0 with nobody at the wheel)
	grounded: boolean, -- touching ground or water (false mid-air)
	off: boolean?, -- in terrain, beached or under water
}

function VehicleRecovery.new(): State
	return { flip = 0, stuck = 0, off = 0 }
end

-- Advances the timers by dt; returns the reason once one runs out (then the timers restart).
function VehicleRecovery.step(s: State, dt: number, now: number, sample: Sample): Reason?
	if s.lastAt and now - s.lastAt < VehicleRecovery.COOLDOWN then
		s.flip, s.stuck, s.off = 0, 0, 0
		return nil
	end
	if sample.up >= VehicleRecovery.UP_MIN then
		s.flip = 0
	elseif sample.grounded then
		s.flip += dt
	end
	if
		math.abs(sample.throttle) < VehicleRecovery.THROTTLE_MIN
		or sample.speed >= VehicleRecovery.STUCK_SPEED
	then
		s.stuck = 0
	elseif sample.grounded then
		s.stuck += dt
	end
	s.off = if sample.off then s.off + dt else 0
	local reason: Reason? = if s.flip >= VehicleRecovery.FLIP_TIME
		then "Flipped"
		elseif s.off >= VehicleRecovery.OFF_TIME then "Sunk"
		elseif s.stuck >= VehicleRecovery.STUCK_TIME then "Stuck"
		else nil
	if reason then
		s.flip, s.stuck, s.off = 0, 0, 0
		s.lastAt = now
	end
	return reason
end

-- The glide at a (0..1): eased from `from` to `to`, arcing GLIDE_LIFT studs up on the way.
function VehicleRecovery.path(from: CFrame, to: CFrame, a: number): CFrame
	local e = a * a * (3 - 2 * a)
	local cf = from:Lerp(to, e)
	return cf + Vector3.new(0, VehicleRecovery.GLIDE_LIFT * math.sin(math.pi * a), 0)
end

-- Runs the glide on Heartbeat: place(cf) each frame (the caller anchors first), then done().
function VehicleRecovery.glide(from: CFrame, to: CFrame, place: (CFrame) -> (), done: () -> ())
	local RunService = game:GetService("RunService")
	task.spawn(function()
		local t = 0
		while t < VehicleRecovery.GLIDE_TIME do
			t += RunService.Heartbeat:Wait()
			place(VehicleRecovery.path(from, to, math.min(t / VehicleRecovery.GLIDE_TIME, 1)))
		end
		done()
	end)
end

return VehicleRecovery
