--!strict
-- RoadHeading: which way a parked land vehicle should face (pure, Lune-safe). A spawn faces along
-- the tangent of the nearest road (WorldConfig.Roads polylines), choosing the direction that heads
-- toward a target (town, the next stop) so "drive forward" follows the road instead of the sea.
-- Slipways (any point below sea level) are only used when no ordinary road is near, and then the
-- vehicle faces up the ramp, away from the water. With no target the inland side (-Z) wins.

local RoadHeading = {}

export type Road = { id: string, points: { Vector3 } }
export type Hit = {
	roadId: string,
	point: Vector3, -- nearest point on the road centreline
	tangent: Vector3, -- unit, flat, in the polyline's point order
	rise: number, -- Y change along the tangent over that segment (studs)
	distance: number, -- flat distance from the query position
	slipway: boolean,
}
export type Options = {
	seaLevel: number?, -- default 0
	maxDistance: number?, -- ordinary roads further than this fall back to slipways (default 60)
}

RoadHeading.MAX_DISTANCE = 60
RoadHeading.INLAND = Vector3.new(0, 0, -1) -- +Z is out to sea on the Gale Isles

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function RoadHeading.isSlipway(road: Road, seaLevel: number?): boolean
	local sea = seaLevel or 0
	for _, p in road.points do
		if p.Y < sea then
			return true
		end
	end
	return false
end

-- The nearest point on any road (flat distance). `slipways` false skips ramps into the sea.
function RoadHeading.nearest(
	roads: { Road },
	position: Vector3,
	slipways: boolean,
	seaLevel: number?
): Hit?
	local at = flat(position)
	local best: Hit? = nil
	for _, road in roads do
		local isSlip = RoadHeading.isSlipway(road, seaLevel)
		if isSlip and not slipways then
			continue
		end
		local pts = road.points
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local ab = flat(b - a)
			local len2 = ab:Dot(ab)
			if len2 < 1e-6 then
				continue
			end
			local t = math.clamp((at - flat(a)):Dot(ab) / len2, 0, 1)
			local q = flat(a) + ab * t
			local d = (at - q).Magnitude
			if not best or d < best.distance then
				local hit: Hit = {
					roadId = road.id,
					point = a:Lerp(b, t),
					tangent = ab.Unit,
					rise = b.Y - a.Y,
					distance = d,
					slipway = isSlip,
				}
				best = hit
			end
		end
	end
	return best
end

-- The facing (unit, flat) for a vehicle parked at `position`, and the road it follows.
function RoadHeading.heading(
	roads: { Road },
	position: Vector3,
	toward: Vector3?,
	options: Options?
): (Vector3, Hit?)
	local opts: Options = options or {}
	local maxDistance = opts.maxDistance or RoadHeading.MAX_DISTANCE
	local hit = RoadHeading.nearest(roads, position, false, opts.seaLevel)
	if not hit or hit.distance > maxDistance then
		local ramp = RoadHeading.nearest(roads, position, true, opts.seaLevel)
		if ramp and (not hit or ramp.distance < hit.distance) then
			hit = ramp
		end
	end
	local want = if toward then flat(toward - position) else RoadHeading.INLAND
	if want.Magnitude < 1e-6 then
		want = RoadHeading.INLAND
	end
	if not hit then
		return want.Unit, nil
	end
	local t = hit.tangent
	local sign
	if hit.slipway then
		sign = if hit.rise >= 0 then 1 else -1 -- up the ramp, out of the water
	else
		local d = t:Dot(want.Unit)
		if math.abs(d) < 0.05 then
			d = t:Dot(RoadHeading.INLAND) -- road square to the target: take the inland side
		end
		sign = if d >= 0 then 1 else -1
	end
	return t * sign, hit
end

-- A spawn CFrame at `position` facing along the road.
function RoadHeading.spawnCFrame(
	roads: { Road },
	position: Vector3,
	toward: Vector3?,
	options: Options?
): (CFrame, Hit?)
	local look, hit = RoadHeading.heading(roads, position, toward, options)
	return CFrame.lookAt(position, position + look), hit
end

return RoadHeading
