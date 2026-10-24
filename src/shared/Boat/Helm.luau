--!strict
-- Boat/Helm (docs/20 WP-C): keyboard-friendly steering. Pure, Lune-tested in tests/BoatHelm.spec.luau.
-- A held key ramps the helm to full over RAMP s (a tap no longer spins a jet ski past every
-- heading), letting go centres it within RELEASE s, and the lock eases off with speed (AT_SPEED of
-- full lock at top speed). A gamepad stick or touch thumbstick goes through the same ramp.
local Helm = {}

Helm.RAMP = 0.4 -- s from centre to full lock -- tune
Helm.RELEASE = 0.15 -- s from full lock back to centre -- tune
Helm.AT_SPEED = 0.65 -- share of full lock left at top speed -- tune

-- The helm after dt: `current` and `input` are -1..1, speedFrac is speed / top speed.
function Helm.step(current: number, input: number, speedFrac: number, dt: number): number
	local lock = 1 - (1 - Helm.AT_SPEED) * math.clamp(speedFrac, 0, 1)
	local target = math.clamp(input, -1, 1) * lock
	-- outward (same side, further out) ramps; back toward centre or across it releases
	local outward = math.abs(target) > math.abs(current) and target * current >= 0
	local rate = if outward then 1 / Helm.RAMP else 1 / Helm.RELEASE
	return current + math.clamp(target - current, -rate * dt, rate * dt)
end

return Helm
