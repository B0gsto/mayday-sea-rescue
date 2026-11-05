--!strict
-- Boat/Glance (docs/30): a hit on an island at speed glances off. Never a dead stop, never a flip: the bow swings along
-- the wall and most of the speed stays. Pure; BoatController sweeps ahead with rays and applies this.
local Glance = {}

Glance.MIN_SPEED = 40 -- studs/s: slower hits stay ordinary physics (Unstick, stepping ashore) -- tune
Glance.MAX_NORMAL_Y = 0.7 -- steeper faces are walls; a ramp or a gentle beach is not
Glance.BEACH_SPEED = 120 -- studs/s: from here a beach stops a hull as dead as a wall -- tune
Glance.MAX_NORMAL_Y_FAST = 0.995 -- so only a flat seabed doesn't count
Glance.LOSS_WINDOW = 0.3 -- s after a glance when more contacts turn the hull but take no more speed: a blocky corner
-- touches several faces in a row and each one's cut stacked (695 -> 419 -> 199 in 0.1 s) -- tune
Glance.SLAM_RATIO = 0.5 -- this much of the recent speed gone: physics met land the sweep never saw
Glance.SLAM_WINDOW = 0.2 -- s the recent top speed is kept: a beach grinds over several frames (602 -> 34 in 0.2 s,
-- never half in one frame) -- tune
Glance.SLAM_MIN_LOSS = 80 -- studs/s lost inside the window: a full L50 brake (270 studs/s^2) loses 54 -- tune
Glance.KEEP_HEAD_ON = 0.55 -- of the speed, straight into a wall -- tune
Glance.KEEP_SHALLOW = 0.95 -- of the speed, skimming along one -- tune
Glance.PEEL = 0.3 -- how much the new heading leans away from the wall -- tune
Glance.COOLDOWN = 0.03 -- s between glances: 0.12 let a corner's second contact stop the hull -- tune

-- How far to sweep the hull's box this frame: two frames of travel, so no thin wall is missed.
function Glance.lookahead(speed: number, dt: number): number
	return speed * dt * 2 + 1
end

function Glance.isWall(normalY: number, speed: number): boolean
	return math.abs(normalY)
		< (if speed >= Glance.BEACH_SPEED then Glance.MAX_NORMAL_Y_FAST else Glance.MAX_NORMAL_Y)
end

-- Adds this frame's flat velocity to `history` (oldest first, trimmed to SLAM_WINDOW) and returns the fastest in it.
function Glance.remember(
	history: { { at: number, v: Vector3 } },
	now: number,
	flat: Vector3
): Vector3
	table.insert(history, { at = now, v = flat })
	while history[1].at < now - Glance.SLAM_WINDOW do
		table.remove(history, 1)
	end
	local top = flat
	for _, h in history do
		if h.v.Magnitude > top.Magnitude then
			top = h.v
		end
	end
	return top
end

-- The sweep missed and the speed died anyway (already touching, terrain, a thin edge): glance late. `recent`: the
-- top speed of the last SLAM_WINDOW.
function Glance.slammed(recent: number, speed: number): boolean
	return recent >= Glance.MIN_SPEED
		and speed < recent * Glance.SLAM_RATIO
		and recent - speed >= Glance.SLAM_MIN_LOSS
end

-- velocity and normal flat (Y = 0 is forced here). Returns the new velocity and the heading, or nil when already
-- moving away from the wall. `free`: inside LOSS_WINDOW, so the speed stays.
function Glance.deflect(
	velocity: Vector3,
	normal: Vector3,
	forward: Vector3,
	free: boolean?
): (Vector3?, Vector3?)
	local v = Vector3.new(velocity.X, 0, velocity.Z)
	local n = Vector3.new(normal.X, 0, normal.Z)
	if v.Magnitude < 1e-3 or n.Magnitude < 1e-3 then
		return nil, nil
	end
	n = n.Unit
	local into = v:Dot(n)
	if into >= 0 then
		return nil, nil
	end
	local speed = v.Magnitude
	local along = v - n * into
	if along.Magnitude < 0.02 * speed then
		-- dead on: go the way the bow already leans, else to the wall's right
		local side = n:Cross(Vector3.yAxis)
		along = side * (if forward:Dot(side) < 0 then -1 else 1)
	end
	local skim = math.clamp((v - n * into).Magnitude / speed, 0, 1)
	local keep = if free
		then 1
		else Glance.KEEP_HEAD_ON + (Glance.KEEP_SHALLOW - Glance.KEEP_HEAD_ON) * skim
	local heading = (along.Unit + n * Glance.PEEL).Unit
	return heading * speed * keep, heading
end

return Glance
