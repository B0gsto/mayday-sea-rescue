--!strict
-- Snorkel: swimming, face-down floating and breath-hold duck dives (docs 10 section 4.5). Pure, safe
-- in Lune (tests/Explore.spec.luau); SwimController applies it to the local character.
--
-- The sea has no Terrain water (tools/world/README.md: the mesh ocean covers a dry seabed), so the
-- character would walk along the bottom. Where the water is deeper than WADE_DEPTH the controller
-- puts the Humanoid in Swimming and drives the root with a LinearVelocity whose vertical part comes
-- from here:
--   surface  the eye floats SURFACE_EYE above the surface; looking down past FACE_DOWN_LOOK puts
--            the mask in the water (FACE_DOWN_EYE) so the player sees the seabed below
--   dive     breath-hold, to MAX_DIVE_DEPTH below the surface for BREATH seconds (tune); forward
--            input follows the camera pitch, no input drifts slowly up; at 0 breath it surfaces
-- Breath refills at the surface REFILL times faster than it drains.
local Snorkel = {}

Snorkel.STUDS_PER_M = 3
Snorkel.WADE_DEPTH = 3.8 -- studs of water before the player swims: an R15 eye stands ~4.6 above the floor, so 4.6 left the head and camera under water on the bed (slipway walk-in) -- tune
Snorkel.ENTER_MARGIN = 0.4 -- the root must be at least this far below the surface to start swimming
Snorkel.BREATH = 25 -- s -- tune
Snorkel.REFILL = 2.5
Snorkel.MAX_DIVE_DEPTH = 5 * 3 -- studs below the surface (5 m) -- tune
Snorkel.FLOOR_CLEARANCE = 2.2 -- eye above the seabed
Snorkel.SWIM_SPEED = 9 -- studs/s at the surface -- tune
Snorkel.DIVE_SPEED = 7.5
Snorkel.RISE_SPEED = 1.2 -- idle drift up while diving
Snorkel.PUSH_TIME = 0.9 -- s of head-first push at the start of a duck dive
Snorkel.ASCENT_SPEED = 6 -- out of breath or surfacing on purpose
Snorkel.SURFACE_EYE = 0.45
Snorkel.FACE_DOWN_EYE = -0.55
Snorkel.FACE_DOWN_LOOK = -0.55 -- camera LookVector.Y
Snorkel.SPRING = 4 -- 1/s, surface float
Snorkel.MAX_VY = 8
Snorkel.FINS_SPEED_BONUS = 0.25 -- with Fins gear

export type Mode = "surface" | "dive" | "ascend"

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

-- Breath after dt: drains while under (eye below the surface in a dive), refills otherwise.
function Snorkel.stepBreath(breath: number, under: boolean, dt: number): number
	if under then
		return math.max(0, breath - dt)
	end
	return math.min(Snorkel.BREATH, breath + dt * Snorkel.REFILL)
end

-- The next mode. diveHeld: the dive input was pressed this frame; surfaceHeld: jump / surface input.
function Snorkel.nextMode(
	mode: Mode,
	eyeDepth: number,
	breath: number,
	divePressed: boolean,
	surfacePressed: boolean
): Mode
	if mode == "surface" then
		if divePressed and breath > Snorkel.BREATH * 0.2 then
			return "dive"
		end
		return "surface"
	elseif mode == "dive" then
		if breath <= 0 or surfacePressed then
			return "ascend"
		end
		return "dive"
	else
		if eyeDepth <= 0.2 then
			return "surface"
		end
		return "ascend"
	end
end

-- Vertical velocity (studs/s). eyeY: the head; lookY: camera LookVector.Y; forward: 0..1 of the move
-- input pointing where the camera looks; diveTime: seconds since the dive began.
function Snorkel.verticalVelocity(
	mode: Mode,
	eyeY: number,
	surfaceY: number,
	floorY: number,
	lookY: number,
	forward: number,
	diveTime: number?
): number
	local vy: number
	if mode == "surface" then
		vy = (surfaceY + Snorkel.floatEye(lookY) - eyeY) * Snorkel.SPRING
	elseif mode == "dive" then
		if forward > 0.1 then
			vy = lookY * Snorkel.DIVE_SPEED * forward
		else
			vy = Snorkel.RISE_SPEED
		end
		-- the duck dive itself: the first push goes down even when looking level
		if (diveTime or math.huge) < Snorkel.PUSH_TIME then
			vy = math.min(vy, -Snorkel.DIVE_SPEED)
		end
		local minEye = math.max(surfaceY - Snorkel.MAX_DIVE_DEPTH, floorY + Snorkel.FLOOR_CLEARANCE)
		if eyeY < minEye then
			vy = math.max(vy, (minEye - eyeY) * 2)
		end
		if eyeY > surfaceY - 0.6 and (diveTime or math.huge) >= Snorkel.PUSH_TIME then
			vy = math.min(vy, 0)
		end
	else
		vy = Snorkel.ASCENT_SPEED
		local above = surfaceY + Snorkel.SURFACE_EYE - eyeY
		vy = math.min(vy, above * Snorkel.SPRING + 0.5)
	end
	return math.clamp(vy, -Snorkel.MAX_VY, Snorkel.MAX_VY)
end

-- Horizontal swim speed (studs/s) for the mode and the Fins gear level (0 = none).
function Snorkel.speed(mode: Mode, finsLevel: number): number
	local base = if mode == "dive" then Snorkel.DIVE_SPEED else Snorkel.SWIM_SPEED
	return base * (1 + if finsLevel > 0 then Snorkel.FINS_SPEED_BONUS else 0)
end

return Snorkel
