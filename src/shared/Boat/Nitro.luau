--!strict
-- Nitro (docs/25 F, Captain ring 3): double-tap the throttle (W twice, the trigger twice, the stick forward
-- twice) for a short speed burst. Pure; BoatController feeds it the seat's ThrottleFloat every frame and hands
-- the result to Simulator.setBoost.
local Nitro = {}

Nitro.TAP_WINDOW = 0.35 -- s between the two presses
Nitro.BURST = 4 -- s: long enough to reach the boosted top speed (2.5 s showed only +9%) -- tune
Nitro.COOLDOWN = 8 -- s from one burst's start to the next -- tune
Nitro.MULT = 1.3 -- top speed and thrust during the burst -- tune

export type State = { down: boolean, tapAt: number, burstAt: number }

function Nitro.new(): State
	return { down = false, tapAt = -math.huge, burstAt = -math.huge }
end

-- One frame (owned: the Nitro skill) -> the speed multiplier now (1 outside a burst).
function Nitro.step(st: State, throttle: number, now: number, owned: boolean): number
	local down = throttle > 0.5
	if down and not st.down then
		if owned and now - st.tapAt <= Nitro.TAP_WINDOW and now - st.burstAt >= Nitro.COOLDOWN then
			st.burstAt, st.tapAt = now, -math.huge
		else
			st.tapAt = now
		end
	end
	st.down = down
	return if now - st.burstAt < Nitro.BURST then Nitro.MULT else 1
end

return Nitro
