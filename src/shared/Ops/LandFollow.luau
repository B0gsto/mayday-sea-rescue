--!strict
-- LandFollow: the pure rule for a land call's survivor (docs/23 e.3). They wait inside an orange ring until
-- someone walks into it, then follow on foot; once that player sits in a craft close by, they climb aboard.
-- On foot, a follower that makes no headway for STUCK_TIME is put behind the player; while the player is
-- in a craft out of range they walk to the shore toward it ("shore") and wait there. Used by server/Ops/LandRescue;
-- tests/LandFollow.spec.luau.
local LandFollow = {}

LandFollow.RING = 8 -- studs: walk inside this and they stand up and follow
LandFollow.BOARD_RANGE = 25 -- studs from the craft they climb aboard from
LandFollow.GAP = 5 -- studs: close enough, they stop behind you
LandFollow.STUCK_TIME = 4 -- s without headway before they are put behind you
LandFollow.MIN_SPEED = 1.5 -- studs/s of headway that counts as moving

export type State = { following: boolean, stuck: number }
export type Action = "wait" | "start" | "move" | "idle" | "teleport" | "shore" | "board"

function LandFollow.new(): State
	return { following = false, stuck = 0 }
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- One tick. survivor / player: positions; seated: the player sits in a craft (`craft` its position);
-- moved: studs the survivor covered since the last tick.
function LandFollow.step(
	s: State,
	dt: number,
	survivor: Vector3,
	player: Vector3,
	seated: boolean,
	craft: Vector3?,
	moved: number
): Action
	if not s.following then
		if not seated and flat(survivor, player) <= LandFollow.RING then
			s.following = true
			return "start"
		end
		return "wait"
	end
	if seated then
		s.stuck = 0
		-- they never wade out after a craft: they wait at the water's edge until it comes in close
		return if craft and flat(survivor, craft) <= LandFollow.BOARD_RANGE
			then "board"
			else "shore"
	end
	if flat(survivor, player) <= LandFollow.GAP then
		s.stuck = 0
		return "idle"
	end
	s.stuck = if moved < LandFollow.MIN_SPEED * dt then s.stuck + dt else 0
	if s.stuck >= LandFollow.STUCK_TIME then
		s.stuck = 0
		return "teleport"
	end
	return "move"
end

return LandFollow
