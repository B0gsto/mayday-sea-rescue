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
Snorkel.ENTER_MARGIN = 0.4 -- the root must be at least this far below the surface to start swimming
Snorkel.SWIM_SPEED = 9 -- studs/s -- tune
Snorkel.SURFACE_EYE = 0.45
Snorkel.FACE_DOWN_EYE = -0.55
Snorkel.FACE_DOWN_LOOK = -0.55 -- camera LookVector.Y
Snorkel.SPRING = 4 -- 1/s, surface float
Snorkel.MAX_VY = 8

-- Should the character swim here? surfaceY: the sea surface at the root, floorY: the seabed under it.
function Snorkel.shouldSwim(
	rootY: number,
	surfaceY: number,
	floorY: number,
	swimming: boolean
): boolean
	if surfaceY - floorY < Snorkel.WADE_DEPTH then
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

-- Vertical velocity (studs/s) of the float spring. eyeY: the head; lookY: camera LookVector.Y.
function Snorkel.verticalVelocity(eyeY: number, surfaceY: number, lookY: number): number
	local vy = (surfaceY + Snorkel.floatEye(lookY) - eyeY) * Snorkel.SPRING
	return math.clamp(vy, -Snorkel.MAX_VY, Snorkel.MAX_VY)
end

return Snorkel
