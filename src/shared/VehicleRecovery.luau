--!strict
-- VehicleRecovery: when a player vehicle (car, boat, jet ski) is "weird" the server puts it back
-- upright. Pure timers (Lune-tested in tests/VehicleRecovery.spec.luau) plus the lift-and-settle
-- path VehicleService glides the model along.
--   Flipped  on its side or roof (up vector past ~65 degrees) for FLIP_TIME while touching down
--   Stuck    the driver holds throttle but the vehicle barely moves for STUCK_TIME while touching down
--   Sunk     the caller's "off" flag (in terrain, beached, under water) for OFF_TIME
-- Airborne samples pause the flip and stuck timers (a legit jump or barrel roll never resets), and
-- after a reset nothing fires for COOLDOWN seconds (no reset loops).
-- Misplaced (docs/20 WP-C addendum): a boat on land or a car in deep water for MISPLACED_TIME goes
-- (the caller despawns it with poof()): at once when nobody is aboard, else only once a recovery
-- has already been tried during that spell and failed.
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
VehicleRecovery.MISPLACED_TIME = 6 -- s on land (boat) / in deep water (car) before it goes -- tune

export type Reason = "Flipped" | "Stuck" | "Sunk"
export type State = { flip: number, stuck: number, off: number, wrong: number, lastAt: number? }
export type Sample = {
	up: number, -- root UpVector.Y
	speed: number, -- studs/s
	throttle: number, -- -1..1 (0 with nobody at the wheel)
	grounded: boolean, -- touching ground or water (false mid-air)
	off: boolean?, -- in terrain, beached or under water
}

function VehicleRecovery.new(): State
	return { flip = 0, stuck = 0, off = 0, wrong = 0 }
end

-- Advances the misplaced timer by dt; true when the vehicle should go now.
function VehicleRecovery.misplaced(
	s: State,
	dt: number,
	now: number,
	wrong: boolean,
	occupied: boolean
): boolean
	if not wrong then
		s.wrong = 0
		return false
	end
	s.wrong += dt
	local tried = s.lastAt ~= nil and now - s.lastAt <= s.wrong -- a recovery ran during this spell
	return s.wrong >= VehicleRecovery.MISPLACED_TIME and (not occupied or tried)
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

-- A splash (water) or dust poof (land) where a misplaced vehicle vanished; server-made, so everyone
-- sees it.
function VehicleRecovery.poof(position: Vector3, water: boolean)
	local Clips = require(script.Parent:WaitForChild("Config"):WaitForChild("AudioConfig")).Clips
	local part = Instance.new("Part")
	part.Name = "VehiclePoof"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(
		if water then Color3.fromRGB(225, 240, 250) else Color3.fromRGB(230, 222, 205)
	)
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 10) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.9, 1.5)
	e.Speed = NumberRange.new(10, 22)
	e.SpreadAngle = Vector2.new(70, 70)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, if water then -30 else -4, 0)
	e.Drag = 2
	e.Enabled = false
	e.Parent = part
	local sound = Instance.new("Sound")
	sound.SoundId = Clips.Splash_Entry.id
	sound.Volume = Clips.Splash_Entry.volume
	sound.RollOffMaxDistance = 250
	sound.Parent = part
	part.Parent = workspace
	e:Emit(45)
	sound:Play()
	game:GetService("Debris"):AddItem(part, 3)
end

return VehicleRecovery
