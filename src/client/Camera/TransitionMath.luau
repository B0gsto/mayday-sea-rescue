--!strict
-- TransitionMath: the pure maths of the close-work camera dolly (third person <-> the eye
-- point), Lune-tested in tests/CameraTransition.spec.luau. No services.
--
--   ease(k)                       ease-in-out cubic over 0..1 (the dolly curve)
--   point(a, b, k, lift)          a slight lifted arc from a to b
--   fov(from, to, k, dip)         the lens narrowing a little at the midpoint
--   pulse(k)                      the effects envelope (0 at both ends, 1 at the middle)
--   bodyAlpha(distance, near, far) 1 while the camera is at the head, 0 when clear of it
--   cutAlpha(k)                   the reduced-motion fade-to-black envelope
--   aimPoint(eye, focus, near, far)  the care-area point the dolly ends looking at
--   aim(eye, focus, near, far)    the end frame for close work (looks at the care area)
--   pullIn(eye, point, hit, pad)  keeps the path clear of geometry
--   aboveWater(point, height, clearance)
--   duration(reduced)             the dolly time, or the short fade cut
local TransitionMath = {}

TransitionMath.DURATION = 0.72 -- s, the eased dolly each way -- tune
TransitionMath.CUT = 0.2 -- s, the reduced-motion fade cut -- tune
TransitionMath.ARC = 0.35 -- studs the path rises at its midpoint -- tune
TransitionMath.FOV_DIP = 4 -- degrees the lens narrows at the midpoint -- tune
TransitionMath.FADE_NEAR = 1.1 -- studs from the head where the body is fully hidden
TransitionMath.FADE_FAR = 3.4 -- studs from the head where the body is fully shown
TransitionMath.WATER_CLEARANCE = 0.9 -- studs above the swell -- tune
TransitionMath.WALL_PAD = 0.35 -- studs short of a hit -- tune
TransitionMath.AIM_NEAR = 1.5 -- studs from the eye to the care area looked at -- tune
TransitionMath.AIM_FAR = 2.5 -- studs: keeps the body filling the view, parts spread apart -- tune

-- Ease-in-out cubic: slow, quick through the middle, slow again.
function TransitionMath.ease(k: number): number
	local t = math.clamp(k, 0, 1)
	if t < 0.5 then
		return 4 * t * t * t
	end
	local u = -2 * t + 2
	return 1 - u * u * u / 2
end

-- A straight dolly with a small lift at the middle, so the move reads as a camera move.
function TransitionMath.point(a: Vector3, b: Vector3, k: number, lift: number?): Vector3
	local t = math.clamp(k, 0, 1)
	local up = (lift or TransitionMath.ARC) * math.sin(math.pi * t)
	return a + (b - a) * t + Vector3.new(0, up, 0)
end

-- The lens from `from` to `to`, narrowed by `dip` at the midpoint, then settled.
function TransitionMath.fov(from: number, to: number, k: number, dip: number?): number
	local t = math.clamp(k, 0, 1)
	return from + (to - from) * t - (dip or TransitionMath.FOV_DIP) * math.sin(math.pi * t)
end

-- Effects envelope: 0 at both ends, 1 at the middle.
function TransitionMath.pulse(k: number): number
	return math.sin(math.pi * math.clamp(k, 0, 1))
end

-- The body fades out as the camera passes through the head: 1 at the head, 0 clear of it.
function TransitionMath.bodyAlpha(distance: number, near: number?, far: number?): number
	local n = near or TransitionMath.FADE_NEAR
	local f = far or TransitionMath.FADE_FAR
	if f <= n then
		return if distance <= n then 1 else 0
	end
	local x = math.clamp((distance - n) / (f - n), 0, 1)
	return 1 - x * x * (3 - 2 * x)
end

-- The reduced-motion cut: black rises to full at the midpoint, then clears.
function TransitionMath.cutAlpha(k: number): number
	local t = math.clamp(k, 0, 1)
	local x = if t < 0.5 then t * 2 else (1 - t) * 2
	return x * x * (3 - 2 * x)
end

-- The care-area point the close-work view looks at: along the eye -> focus line, held at a
-- comfortable 1.5..2.5 studs (the direction never changes, so the cluster lands near the centre).
function TransitionMath.aimPoint(eye: Vector3, focus: Vector3, near: number?, far: number?): Vector3
	local delta = focus - eye
	local d = delta.Magnitude
	if d < 1e-4 then
		return eye
	end
	local n = near or TransitionMath.AIM_NEAR
	local f = math.max(far or TransitionMath.AIM_FAR, n)
	return eye + delta.Unit * math.clamp(d, n, f)
end

-- The end frame of the close-work dolly: at the eye, looking at the casualty's care area.
function TransitionMath.aim(eye: Vector3, focus: Vector3, near: number?, far: number?): CFrame
	return CFrame.lookAt(eye, TransitionMath.aimPoint(eye, focus, near, far))
end

-- The path point, pulled to just short of the first obstruction between the eye and the point.
function TransitionMath.pullIn(
	eye: Vector3,
	point: Vector3,
	hitDistance: number?,
	padding: number?
): Vector3
	local delta = point - eye
	local length = delta.Magnitude
	if hitDistance == nil or hitDistance >= length or length < 1e-4 then
		return point
	end
	local pad = padding or TransitionMath.WALL_PAD
	return eye + delta.Unit * math.max(0, hitDistance - pad)
end

function TransitionMath.aboveWater(point: Vector3, waveHeight: number, clearance: number?): Vector3
	local floor = waveHeight + (clearance or TransitionMath.WATER_CLEARANCE)
	if point.Y >= floor then
		return point
	end
	return Vector3.new(point.X, floor, point.Z)
end

function TransitionMath.duration(reduced: boolean): number
	return if reduced then TransitionMath.CUT else TransitionMath.DURATION
end

return TransitionMath
