--!strict
-- Boat/Glance (docs/30): a hit on an island at speed glances off. Never a dead stop, never a flip: the bow swings along
-- the wall and most of the speed stays. Pure; BoatController sweeps ahead with rays and applies this.
local Glance = {}

Glance.MIN_SPEED = 40 -- studs/s: slower hits stay ordinary physics (Unstick, stepping ashore) -- tune
Glance.MAX_NORMAL_Y = 0.7 -- steeper faces are walls; a ramp or a gentle beach is not
Glance.KEEP_HEAD_ON = 0.55 -- of the speed, straight into a wall -- tune
Glance.KEEP_SHALLOW = 0.95 -- of the speed, skimming along one -- tune
Glance.PEEL = 0.3 -- how much the new heading leans away from the wall -- tune
Glance.COOLDOWN = 0.12 -- s between glances

-- How far ahead to sweep this frame: covers the bow and two frames of travel, so no thin wall is missed.
function Glance.lookahead(speed: number, dt: number, hullLength: number): number
	return speed * dt * 2 + hullLength / 2 + 1
end

-- velocity and normal flat (Y = 0 is forced here). Returns the new velocity and the heading, or nil when already
-- moving away from the wall.
function Glance.deflect(velocity: Vector3, normal: Vector3, forward: Vector3): (Vector3?, Vector3?)
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
	local keep = Glance.KEEP_HEAD_ON + (Glance.KEEP_SHALLOW - Glance.KEEP_HEAD_ON) * skim
	local heading = (along.Unit + n * Glance.PEEL).Unit
	return heading * speed * keep, heading
end

return Glance
