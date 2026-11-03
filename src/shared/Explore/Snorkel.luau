--!strict
-- Snorkel: surface swimming and face-down floating (docs 10 section 4.5; the duck dive was cut,
-- docs/16 C20). Pure, safe in Lune (tests/Explore.spec.luau); SwimController applies it to the
-- local character.
--
-- The sea has no Terrain water (tools/world/README.md: the mesh ocean covers a dry seabed), so the
-- character would walk along the bottom. Where the water is deeper than WADE_DEPTH the controller
-- puts the Humanoid in Swimming and drives the root with a LinearVelocity whose vertical part comes
-- from here: the eye floats SURFACE_EYE above the surface; looking down past FACE_DOWN_LOOK puts the
-- mask in the water (FACE_DOWN_EYE) so the player sees the seabed below.
local Snorkel = {}

Snorkel.WADE_DEPTH = 3.8 -- studs of water before the player swims: an R15 eye stands ~4.6 above the floor, so 4.6 left the head and camera under water on the bed (slipway walk-in) -- tune
Snorkel.WADE_HYSTERESIS = 0.4 -- start swimming only this much deeper than WADE_DEPTH, so waves at the line never flicker swim / wade
Snorkel.ENTER_MARGIN = 0.4 -- the root must be at least this far below the surface to start swimming
Snorkel.SWIM_SPEED = 9 -- studs/s -- tune
Snorkel.SURFACE_EYE = 0.45
Snorkel.FACE_DOWN_EYE = -0.55
Snorkel.FACE_DOWN_LOOK = -0.55 -- camera LookVector.Y
Snorkel.SPRING = 4 -- 1/s, surface float
Snorkel.MAX_VY = 8
Snorkel.STROKE_RATE = 0.9 -- strokes/s at SWIM_SPEED -- tune
Snorkel.TREAD_RATE = 0.45 -- idle treading bob cycles/s
Snorkel.STROKE_SURGE = 0.25 -- each pull surges the speed +-25% (averages SWIM_SPEED)
Snorkel.BOB = 0.25 -- studs of head lift on each pull (the float spring softens it to about half)
Snorkel.SPRINT_SWIM = 1.4 -- sprinting (SprintController) swims and strokes this much faster
Snorkel.WATER_DRAG = 4 -- 1/s, how fast the swim speed follows the stick

-- Should the character swim here? surfaceY: the sea surface at the root, floorY: the seabed under it.
function Snorkel.shouldSwim(
	rootY: number,
	surfaceY: number,
	floorY: number,
	swimming: boolean
): boolean
	local wade = if swimming
		then Snorkel.WADE_DEPTH
		else Snorkel.WADE_DEPTH + Snorkel.WADE_HYSTERESIS
	if surfaceY - floorY < wade then
		return false
	end
	local margin = if swimming then -1.5 else Snorkel.ENTER_MARGIN
	return rootY < surfaceY - margin
end

function Snorkel.floatEye(lookY: number): number
	if lookY <= Snorkel.FACE_DOWN_LOOK then
		return Snorkel.FACE_DOWN_EYE
	end
	-- ease between the two over 0.25 of look pitch so the mask does not pop
	local t = math.clamp((lookY - Snorkel.FACE_DOWN_LOOK) / 0.25, 0, 1)
	return Snorkel.FACE_DOWN_EYE + (Snorkel.SURFACE_EYE - Snorkel.FACE_DOWN_EYE) * t
end

-- Speed factor and head lift through one stroke cycle (phase 0..1): a surge on the pull, a glide after.
function Snorkel.stroke(phase: number): (number, number)
	local c = math.cos(2 * math.pi * phase)
	return 1 + Snorkel.STROKE_SURGE * c, Snorkel.BOB * c
end

-- The move a swimmer's Humanoid gets: same stick strength, level. Straight down has no heading, so no move.
function Snorkel.flatMove(move: Vector3): Vector3
	local flat = Vector3.new(move.X, 0, move.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit * move.Magnitude else Vector3.zero
end

-- Vertical velocity (studs/s) of the float spring. eyeY: the head; lookY: camera LookVector.Y;
-- bob: extra eye height from Snorkel.stroke.
function Snorkel.verticalVelocity(
	eyeY: number,
	surfaceY: number,
	lookY: number,
	bob: number?
): number
	local vy = (surfaceY + Snorkel.floatEye(lookY) + (bob or 0) - eyeY) * Snorkel.SPRING
	return math.clamp(vy, -Snorkel.MAX_VY, Snorkel.MAX_VY)
end

return Snorkel
