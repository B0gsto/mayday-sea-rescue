--!strict
-- PhotoMath: the pure maths and data behind photo mode (src/client/UI/PhotoMode,
-- tests/PhotoMode.spec.luau). No services, no Roblox instances.
--
--   REACH / PITCH_MAX / TILT_MAX / FOV_MIN / FOV_MAX   the shot limits (docs/10 5.4: about 40 studs)
--   clampReach(focus, pos, reach?)                     pull a free-camera point inside the reach sphere
--   clampShot(pitch, tilt, fov)                        clamp the three numeric shot values
--   lookCFrame(pos, yaw, pitch, tilt)                  the free camera's CFrame (roll about the lens)
--   Grades / gradeAt(i) / nextGrade(i)                 the colour grade presets (ColorCorrectionEffect)
export type Grade = {
	name: string,
	brightness: number,
	contrast: number,
	saturation: number,
	tint: Color3?,
}

local PhotoMath = {}

PhotoMath.REACH = 40 -- studs the camera may stray from the player -- tune
PhotoMath.PITCH_MAX = math.rad(85)
PhotoMath.TILT_MAX = math.rad(45)
PhotoMath.FOV_MIN = 20
PhotoMath.FOV_MAX = 120

-- Keeps the free camera within `reach` studs of the focus (direction preserved when pulled in).
function PhotoMath.clampReach(focus: Vector3, pos: Vector3, reach: number?): Vector3
	local r = reach or PhotoMath.REACH
	local offset = pos - focus
	local d = offset.Magnitude
	if d <= r or d == 0 then
		return pos
	end
	return focus + offset * (r / d)
end

function PhotoMath.clampShot(pitch: number, tilt: number, fov: number): (number, number, number)
	return math.clamp(pitch, -PhotoMath.PITCH_MAX, PhotoMath.PITCH_MAX),
		math.clamp(tilt, -PhotoMath.TILT_MAX, PhotoMath.TILT_MAX),
		math.clamp(fov, PhotoMath.FOV_MIN, PhotoMath.FOV_MAX)
end

-- Yaw about the world up, then pitch, then tilt about the lens' own axis: positive pitch looks up,
-- positive tilt rolls the horizon clockwise.
function PhotoMath.lookCFrame(pos: Vector3, yaw: number, pitch: number, tilt: number): CFrame
	local p = math.clamp(pitch, -PhotoMath.PITCH_MAX, PhotoMath.PITCH_MAX)
	local t = math.clamp(tilt, -PhotoMath.TILT_MAX, PhotoMath.TILT_MAX)
	return CFrame.new(pos)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(p, 0, 0)
		* CFrame.Angles(0, 0, t)
end

-- A few grades for the lens. Values stay inside ColorCorrectionEffect's ranges.
PhotoMath.Grades = {
	{ name = "NONE", brightness = 0, contrast = 0, saturation = 0 },
	{
		name = "WARM",
		brightness = 0.02,
		contrast = 0.05,
		saturation = 0.08,
		tint = Color3.fromHex("FFE8D0"),
	},
	{
		name = "COOL",
		brightness = 0,
		contrast = 0.04,
		saturation = -0.04,
		tint = Color3.fromHex("D6E6FF"),
	},
	{ name = "VIVID", brightness = 0, contrast = 0.12, saturation = 0.35 },
	{ name = "MONO", brightness = -0.02, contrast = 0.1, saturation = -1 },
} :: { Grade }

function PhotoMath.gradeAt(index: number): Grade
	return PhotoMath.Grades[math.clamp(index, 1, #PhotoMath.Grades)]
end

function PhotoMath.nextGrade(index: number): number
	return index % #PhotoMath.Grades + 1
end

return PhotoMath
