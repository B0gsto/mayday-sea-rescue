--!strict
-- StreetLayout: the pure placement rules behind Street (I1b-3: road markings, kerbs, street furniture), unit-tested in
-- tests/Street.spec.luau. Studs, +X east, -Z north, Y up; polylines are WorldConfig.Roads points (arc length and
-- directions in XZ, Y interpolated from the baked road heights; the caller ray-casts the real ground).
--
--   StreetLayout.walk(points, step, from?, to?)   -> { { pos, dir, s } }   a point every `step` studs of arc length
--   StreetLayout.offset(sample, side, d)          -> Vector3              side +1 = right of travel, -1 = left
--   StreetLayout.dashes(points, mark, gap)        -> { { a, b } }         centre-line dashes (mark on, gap off)
--   StreetLayout.chain(points, seg, side, d)      -> { { a, b } }         a continuous line `d` off the centre, in segments
--   StreetLayout.lampYaw(toward)                  -> number               yaw (radians) that turns the lamp's bracket
--                                                                         (asset -X) to point along `toward`
--   StreetLayout.distToPolyline(p, points)        -> number               XZ distance to the polyline
--   StreetLayout.clear(p, blockers, rects?)       -> boolean              false within a blocker radius or a rect
--   StreetLayout.inRect(p, rect)                  -> boolean              rect = { x0, z0, x1, z1 }

local StreetLayout = {}

export type Sample = { pos: Vector3, dir: Vector3, s: number }
export type Seg = { a: Vector3, b: Vector3 }
export type Blocker = { pos: Vector3, r: number }
export type Rect = { number }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Samples every `step` studs of arc length between s = from and s = to (default the whole polyline).
function StreetLayout.walk(
	points: { Vector3 },
	step: number,
	from: number?,
	to: number?
): { Sample }
	local out: { Sample } = {}
	local s0 = from or 0
	local total = 0
	for i = 1, #points - 1 do
		total += (flat(points[i + 1]) - flat(points[i])).Magnitude
	end
	local s1 = math.min(to or total, total)
	local want = s0
	local acc = 0
	for i = 1, #points - 1 do
		local a, b = flat(points[i]), flat(points[i + 1])
		local len = (b - a).Magnitude
		if len > 1e-6 then
			local dir = (b - a) / len
			while want <= acc + len + 1e-9 and want <= s1 + 1e-9 do
				local t = (want - acc) / len
				table.insert(out, { pos = points[i]:Lerp(points[i + 1], t), dir = dir, s = want })
				want += step
			end
		end
		acc += len
	end
	return out
end

-- Right of travel (seen from above with -Z north): dir rotated a quarter turn clockwise.
function StreetLayout.offset(sample: Sample, side: number, d: number): Vector3
	local right = Vector3.new(-sample.dir.Z, 0, sample.dir.X)
	return sample.pos + right * side * d
end

function StreetLayout.dashes(points: { Vector3 }, mark: number, gap: number): { Seg }
	local out: { Seg } = {}
	local starts = StreetLayout.walk(points, mark + gap)
	for _, st in starts do
		local seg = StreetLayout.walk(points, mark, st.s, st.s + mark)
		if #seg == 2 then
			table.insert(out, { a = seg[1].pos, b = seg[2].pos })
		end
	end
	return out
end

function StreetLayout.chain(points: { Vector3 }, seg: number, side: number, d: number): { Seg }
	local out: { Seg } = {}
	local samples = StreetLayout.walk(points, seg)
	for i = 1, #samples - 1 do
		table.insert(out, {
			a = StreetLayout.offset(samples[i], side, d),
			b = StreetLayout.offset(samples[i + 1], side, d),
		})
	end
	return out
end

-- CFrame.Angles(0, yaw, 0) maps local +X to (cos yaw, 0, -sin yaw); the bracket is local -X, so -X = toward.
function StreetLayout.lampYaw(toward: Vector3): number
	return math.atan2(toward.Z, -toward.X)
end

function StreetLayout.distToPolyline(p: Vector3, points: { Vector3 }): number
	local q = flat(p)
	local best = math.huge
	for i = 1, #points - 1 do
		local a, b = flat(points[i]), flat(points[i + 1])
		local ab = b - a
		local len2 = ab:Dot(ab)
		local t = if len2 > 0 then math.clamp((q - a):Dot(ab) / len2, 0, 1) else 0
		best = math.min(best, (q - (a + ab * t)).Magnitude)
	end
	return best
end

function StreetLayout.inRect(p: Vector3, rect: Rect): boolean
	return p.X >= rect[1] and p.X <= rect[3] and p.Z >= rect[2] and p.Z <= rect[4]
end

function StreetLayout.clear(p: Vector3, blockers: { Blocker }, rects: { Rect }?): boolean
	local q = flat(p)
	for _, b in blockers do
		if (flat(b.pos) - q).Magnitude < b.r then
			return false
		end
	end
	local list: { Rect } = rects or {}
	for _, r in list do
		if StreetLayout.inRect(p, r) then
			return false
		end
	end
	return true
end

return StreetLayout
