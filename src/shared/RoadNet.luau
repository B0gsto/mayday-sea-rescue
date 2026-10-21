--!strict
-- RoadNet: the pure road network rules (junctions, stop lines, traffic light phases) over WorldConfig.Roads-style
-- polylines. Shared so the server (Street: markings, stop lines, signal heads) and the client (AmbientController:
-- traffic stops at red) agree. Studs, +X east, -Z north; traffic drives on the LEFT (docs/10, section Roads).
-- Unit-tested in tests/RoadNet.spec.luau. Safe in Lune (no requires).
--
--   RoadNet.junctions(roads)              -> { Junction }   every node where 3+ road arms meet: a road's end on another
--                                                           road (T), two roads crossing (X), 3+ road ends together
--   RoadNet.clear(junctions, p)           -> boolean        false inside a junction box (where lane lines stop)
--   RoadNet.light(j, group, t)            -> "green" | "amber" | "red"   for arm group `group` at server time t
--   RoadNet.stopFor(junctions, road, pos, dir, t, look?) -> number?      distance to a stop line ahead that a car on
--                                                           `road` heading `dir` must stop at (red, or amber with room)
--   RoadNet.incoming(arm)                 -> (Vector3, Vector3)   the stop line's centre-line end and its unit
--                                                           direction across the incoming (left-hand) lane

local RoadNet = {}

RoadNet.MERGE = 14 -- studs: touches closer than this are one junction
RoadNet.STOP_BACK = 3 -- studs from the crossing road's edge back to the stop line
RoadNet.CYCLE = { green = 12, amber = 3, red = 2 } -- seconds per group: green, amber, then all red
RoadNet.SIGNAL_SURFACES = { Asphalt = true } -- junctions where every road is one of these get traffic lights

export type Road = { id: string, surface: string, width: number, points: { Vector3 } }
export type Arm = {
	road: string,
	dir: Vector3, -- unit, flat, pointing away from the junction along the road
	width: number,
	stop: number, -- studs from the junction centre to the stop line
	group: number, -- signal phase group (opposite arms share one)
	pos: Vector3, -- junction centre
}
export type Junction = {
	id: string,
	pos: Vector3,
	radius: number, -- lane lines stop inside this
	arms: { Arm },
	signals: boolean,
	groups: number,
	offset: number, -- seconds, so neighbouring junctions are not in lockstep
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- nearest point on the polyline: XZ distance, arc length, point (Y lerped), unit flat tangent
local function project(p: Vector3, points: { Vector3 }): (number, number, Vector3, Vector3)
	local q = flat(p)
	local best, bestS, bestP, bestT = math.huge, 0, points[1], Vector3.xAxis
	local acc = 0
	for i = 1, #points - 1 do
		local a, b = flat(points[i]), flat(points[i + 1])
		local ab = b - a
		local len = ab.Magnitude
		if len > 1e-6 then
			local t = math.clamp((q - a):Dot(ab) / (len * len), 0, 1)
			local d = (q - (a + ab * t)).Magnitude
			if d < best then
				best, bestS, bestP, bestT =
					d, acc + len * t, points[i]:Lerp(points[i + 1], t), ab / len
			end
		end
		acc += len
	end
	return best, bestS, bestP, bestT
end

local function length(points: { Vector3 }): number
	local n = 0
	for i = 1, #points - 1 do
		n += (flat(points[i + 1]) - flat(points[i])).Magnitude
	end
	return n
end

-- XZ crossing of segments ab and cd strictly inside both, else nil
local function cross(a: Vector3, b: Vector3, c: Vector3, d: Vector3): Vector3?
	local r, s = flat(b - a), flat(d - c)
	local den = r.X * s.Z - r.Z * s.X
	if math.abs(den) < 1e-9 then
		return nil
	end
	local w = flat(c - a)
	local t = (w.X * s.Z - w.Z * s.X) / den
	local u = (w.X * r.Z - w.Z * r.X) / den
	if t > 1e-6 and t < 1 - 1e-6 and u > 1e-6 and u < 1 - 1e-6 then
		return a:Lerp(b, t)
	end
	return nil
end

function RoadNet.junctions(
	roads: { any }
): { Junction } -- { Road } (extra fields like `name` are fine)
	local touches: { Vector3 } = {}
	for i, ra in roads do
		for _, e in { ra.points[1], ra.points[#ra.points] } do
			table.insert(touches, e)
			for j, rb in roads do
				local d, _, p = project(e, rb.points)
				if j ~= i and d <= rb.width / 2 + 2 then
					table.insert(touches, p)
				end
			end
		end
		for j = i + 1, #roads do
			local pb = roads[j].points
			for k = 1, #ra.points - 1 do
				for m = 1, #pb - 1 do
					local x = cross(ra.points[k], ra.points[k + 1], pb[m], pb[m + 1])
					if x then
						table.insert(touches, x)
					end
				end
			end
		end
	end
	-- cluster
	local clusters: { { sum: Vector3, n: number } } = {}
	for _, p in touches do
		local hit = nil
		for _, c in clusters do
			if (flat(c.sum / c.n) - flat(p)).Magnitude < RoadNet.MERGE then
				hit = c
				break
			end
		end
		if hit then
			hit.sum += p
			hit.n += 1
		else
			table.insert(clusters, { sum = p, n = 1 })
		end
	end
	local out: { Junction } = {}
	for _, c in clusters do
		local pos = c.sum / c.n
		local arms: { Arm } = {}
		local ids, signals, maxHalf = {}, true, 0
		for _, r in roads do
			local d, s, _, tan = project(pos, r.points)
			if d <= r.width / 2 + 2 then
				local len = length(r.points)
				local function arm(dir: Vector3)
					table.insert(
						arms,
						{ road = r.id, dir = dir, width = r.width, stop = 0, group = 0, pos = pos }
					)
				end
				if s > 2 then
					arm(-tan)
				end
				if s < len - 2 then
					arm(tan)
				end
				table.insert(ids, r.id)
				signals = signals and RoadNet.SIGNAL_SURFACES[r.surface] == true
				maxHalf = math.max(maxHalf, r.width / 2)
			end
		end
		if #arms >= 3 then
			-- opposite arms share a phase group
			local groups = 0
			for _, a in arms do
				if a.group == 0 then
					groups += 1
					a.group = groups
					local best, bestDot = nil, -0.7
					for _, b in arms do
						if b.group == 0 and a.dir:Dot(b.dir) < bestDot then
							best, bestDot = b, a.dir:Dot(b.dir)
						end
					end
					if best then
						best.group = groups
					end
				end
			end
			local radius = 0
			for _, a in arms do
				local other = 0
				for _, b in arms do
					if b.road ~= a.road then
						other = math.max(other, b.width / 2)
					end
				end
				a.stop = other + RoadNet.STOP_BACK
				radius = math.max(radius, a.stop)
			end
			table.sort(ids)
			table.insert(out, {
				id = table.concat(ids, "+") .. `@{math.round(pos.X)},{math.round(pos.Z)}`,
				pos = pos,
				radius = math.max(radius, maxHalf),
				arms = arms,
				signals = signals,
				groups = groups,
				offset = (math.abs(math.round(pos.X) * 7 + math.round(pos.Z) * 13)) % 17,
			})
		end
	end
	return out
end

function RoadNet.clear(junctions: { Junction }, p: Vector3): boolean
	for _, j in junctions do
		if (flat(j.pos) - flat(p)).Magnitude < j.radius then
			return false
		end
	end
	return true
end

function RoadNet.light(j: Junction, group: number, t: number): string
	local c = RoadNet.CYCLE
	local slot = c.green + c.amber + c.red
	local u = (t + j.offset) % (slot * j.groups)
	if math.floor(u / slot) + 1 ~= group then
		return "red"
	end
	local w = u % slot
	return if w < c.green then "green" elseif w < c.green + c.amber then "amber" else "red"
end

-- left of travel toward the junction (travel = -arm.dir): the incoming lane under left-hand traffic
function RoadNet.incoming(arm: Arm): (Vector3, Vector3)
	local t = -arm.dir
	return arm.pos + arm.dir * arm.stop, Vector3.new(t.Z, 0, -t.X)
end

function RoadNet.stopFor(
	junctions: { Junction },
	road: string,
	pos: Vector3,
	dir: Vector3,
	t: number,
	look: number?
): number?
	local far = look or 40
	local best: number? = nil
	for _, j in junctions do
		if j.signals then
			for _, a in j.arms do
				if a.road == road and a.dir:Dot(dir) < -0.7 then
					local rel = flat(pos - j.pos)
					local along = rel:Dot(a.dir) -- distance from the centre out along the arm
					local side = (rel - a.dir * along).Magnitude
					local dist = along - a.stop
					if dist >= 0 and dist <= far and side < a.width then
						local state = RoadNet.light(j, a.group, t)
						-- amber: stop if there is room (> 4 studs), else carry on through
						if state == "red" or (state == "amber" and dist > 4) then
							best = math.min(best or math.huge, dist)
						end
					end
				end
			end
		end
	end
	return best
end

return RoadNet
