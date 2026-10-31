--!strict
-- Heli/Winch (docs/23 h, WP-6): the helicopter's pick-up: hover inside the ring, in the height band,
-- slow and level, for HOLD s -> the winch lifts the survivor. Boats have no such rule (docs/24 A).
-- Pure, Lune-tested in tests/Heli.spec.luau. The caller (WP-9/10) owns the timer.
local Board = require(script.Parent.Parent.Ops.Board)

local Winch = {}

Winch.RING = 12 -- studs, flat distance from the survivor (docs/23: the ~12-stud pick-up ring)
Winch.MAX_HEIGHT = 45 -- studs from the survivor up to HeliRoot; the floor keeps it ~12.5 over the sea
Winch.HOLD = Board.HOLD
Winch.SEATS = 2 -- survivors aboard
Winch.ASSIST = Winch.RING * 2 -- studs, flat: hands off inside this, the heli eases over them and down
Winch.ASSIST_HEIGHT = 30 -- studs over them it eases down to (inside MAX_HEIGHT)
Winch.ASSIST_PULL = 0.8 -- 1/s: flat studs/s toward them per stud off (under Board.STEADY_SPEED inside RING)
Winch.ASSIST_SINK = 0.4 -- share of the climb speed it eases down at

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
		and room
		and speed <= Board.STEADY_SPEED
		and tiltDeg <= Board.STEADY_TILT
end

-- The steady timer: returns the new held time and true once it reaches HOLD (then reset it).
function Winch.hold(held: number, ready: boolean, dt: number): (number, boolean)
	if not ready then
		return 0, false
	end
	held += dt
	return held, held >= Winch.HOLD
end

-- Hands-off help over a survivor (the boats' helm nudge, for the winch): the pilot's idle axes ease the heli
-- over them and down into the band. offset = survivor - heli root; heading as Heli/Flight's. Returns forward,
-- strafe and lift inputs (-1..1); all 0 outside ASSIST. The caller keeps any axis the pilot is using.
function Winch.assist(
	offset: Vector3,
	heading: number,
	spec: { forwardSpeed: number, strafeSpeed: number }
): (number, number, number)
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > Winch.ASSIST then
		return 0, 0, 0
	end
	local v = flat * Winch.ASSIST_PULL
	local look = Vector3.new(-math.sin(heading), 0, -math.cos(heading))
	local right = Vector3.new(math.cos(heading), 0, -math.sin(heading))
	local lift = if -offset.Y > Winch.ASSIST_HEIGHT then -Winch.ASSIST_SINK else 0
	return math.clamp(v:Dot(look) / spec.forwardSpeed, -1, 1),
		math.clamp(v:Dot(right) / spec.strafeSpeed, -1, 1),
		lift
end

return Winch
