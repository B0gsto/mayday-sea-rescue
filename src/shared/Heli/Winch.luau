--!strict
-- Heli/Winch (docs/23 h, WP-6): the helicopter's pick-up, the same hold-steady rule as boats
-- (Ops/Board): hover inside the ring, in the height band, slow and level, for HOLD s -> the winch
-- lifts the survivor. Pure, Lune-tested in tests/Heli.spec.luau. The caller (WP-9/10) owns the timer.
local Board = require(script.Parent.Parent.Ops.Board)

local Winch = {}

Winch.RING = 12 -- studs, flat distance from the survivor (docs/23: the ~12-stud pick-up ring)
Winch.MAX_HEIGHT = 45 -- studs from the survivor up to HeliRoot; the floor keeps it ~12.5 over the sea
Winch.HOLD = Board.HOLD
Winch.SEATS = 2 -- survivors aboard

-- Hovering right for a lift now? gap = flat distance, height = root Y - survivor Y.
function Winch.ready(
	gap: number,
	height: number,
	speed: number,
	tiltDeg: number,
	room: boolean
): boolean
	return gap <= Winch.RING
		and height >= 0
		and height <= Winch.MAX_HEIGHT
		and Board.ready(0, speed, tiltDeg, room)
end

-- The steady timer: returns the new held time and true once it reaches HOLD (then reset it).
function Winch.hold(held: number, ready: boolean, dt: number): (number, boolean)
	if not ready then
		return 0, false
	end
	held += dt
	return held, held >= Winch.HOLD
end

return Winch
