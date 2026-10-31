--!strict
-- TalkPose: the procedural joint turns that keep a quest giver alive (TalkController applies them on top of the
-- stock Idle). Pure: joint name -> turn in degrees (x = pitch, positive up / forward; y = yaw, positive left;
-- z = roll, positive swings a right arm out). No clips: everything is a Transform offset.
local TalkPose = {}

export type Turns = { [string]: Vector3 }
type Gesture = { beats: number, dur: number, turns: Turns }

-- One per line the NPC says, in turn: nod, shrug, point out, arms wide.
TalkPose.GESTURES = {
	{ beats = 2, dur = 0.9, turns = { Neck = Vector3.new(-14, 0, 0) } },
	{
		beats = 1,
		dur = 1.1,
		turns = {
			RightShoulder = Vector3.new(15, 0, 22),
			LeftShoulder = Vector3.new(15, 0, -22),
			RightElbow = Vector3.new(60, 0, 0),
			LeftElbow = Vector3.new(60, 0, 0),
			Neck = Vector3.new(0, 0, 9),
		},
	},
	{
		beats = 1,
		dur = 1.4,
		turns = {
			RightShoulder = Vector3.new(80, 0, 35),
			RightElbow = Vector3.new(8, 0, 0),
			Neck = Vector3.new(0, -18, 0),
		},
	},
	{
		beats = 1,
		dur = 1.3,
		turns = {
			RightShoulder = Vector3.new(15, 0, 55),
			LeftShoulder = Vector3.new(15, 0, -55),
			RightElbow = Vector3.new(20, 0, 0),
			LeftElbow = Vector3.new(20, 0, 0),
			Neck = Vector3.new(8, 0, 0),
		},
	},
} :: { Gesture }

local MAX_YAW, MAX_PITCH = 65, 25 -- degrees the head + waist turn at most
local BEHIND = 110 -- degrees: a target further round than this is behind them, so they don't look

-- Head yaw / pitch (degrees) toward `d`, the direction to the target in the NPC root's space; nil when behind.
function TalkPose.look(d: Vector3): (number?, number?)
	local flat = Vector2.new(d.X, d.Z).Magnitude
	if flat < 1e-3 then
		return nil
	end
	local yaw = math.deg(math.atan2(-d.X, -d.Z))
	if math.abs(yaw) > BEHIND then
		return nil
	end
	local pitch = math.deg(math.atan2(d.Y, flat))
	return math.clamp(yaw, -MAX_YAW, MAX_YAW), math.clamp(pitch, -MAX_PITCH, MAX_PITCH)
end

-- Gesture `i`'s turns `age` seconds in (empty once it ends): rises, holds briefly and settles.
function TalkPose.gesture(i: number, age: number): Turns
	local g = TalkPose.GESTURES[(i - 1) % #TalkPose.GESTURES + 1]
	local u = age / g.dur
	local out: Turns = {}
	if u <= 0 or u >= 1 then
		return out
	end
	local w = math.abs(math.sin(math.pi * u * g.beats)) ^ 0.6
	for joint, v in g.turns do
		out[joint] = v * w
	end
	return out
end

-- Everything for one frame: the head look (yaw / pitch, split 70/30 neck / waist), a talk bob while `speaking`
-- and gesture `gi` at `age`. `t` is the clock.
function TalkPose.turns(
	yaw: number,
	pitch: number,
	t: number,
	speaking: boolean,
	gi: number?,
	age: number
): Turns
	local out: Turns = if gi then TalkPose.gesture(gi, age) else {}
	local bob = if speaking then -3 * math.sin(t * 11) else 0
	out.Neck = (out.Neck or Vector3.zero) + Vector3.new(pitch + bob, yaw * 0.7, 0)
	out.Waist = (out.Waist or Vector3.zero)
		+ Vector3.new(0, yaw * 0.3 + (if speaking then 2 * math.sin(t * 3.3) else 0), 0)
	return out
end

return TalkPose
