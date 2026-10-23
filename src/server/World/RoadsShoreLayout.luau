--!strict
-- RoadsShoreLayout: the pure placement rules behind RoadsShore (I2c: road furniture, field hedges, rock pools,
-- intertidal wrack and eelgrass). Unit-tested in tests/RoadsShore.spec.luau. Studs, +X east, -Z north, Y up.
--
--   walk(points, step)                  -> { { pos, dir, s } }        StreetLayout's arc-length samples
--   length(points)                      -> number
--   yawAlong(dir)                       -> number                     turns a piece's local -X along `dir`
--   faceYaw(face)                       -> number                     turns a sign's local -Z toward `face`
--   run(points, from, to, side, off, piece) -> { Spot }               tiles a modular run on one side of the road
--   spot(points, s, side, off)          -> Spot?                      one piece at arc length s
--   barriers(points, opts)              -> { Spot }                   outside of sharp bends, deduped by gap
--   fieldLines(points, from, to, side, off, depth, every, piece) -> { { Spot } }  field boundaries off a road
--   scatter(center, radius, count, seed, inner) -> { Vector3 }        deterministic, even disk scatter (XZ)

local StreetLayout = require(script.Parent.StreetLayout)

local RoadsShoreLayout = {}

export type Sample = { pos: Vector3, dir: Vector3, s: number }
export type Spot = { pos: Vector3, yaw: number, s: number }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function RoadsShoreLayout.length(points: { Vector3 }): number
	local n = 0
	for i = 1, #points - 1 do
		n += (flat(points[i + 1]) - flat(points[i])).Magnitude
	end
	return n
end

-- CFrame.Angles(0, yaw, 0) maps local -X to (-cos yaw, 0, sin yaw).
function RoadsShoreLayout.yawAlong(dir: Vector3): number
	local d = flat(dir).Unit
	return math.atan2(d.Z, -d.X)
end

-- CFrame.Angles(0, yaw, 0) maps local -Z to (-sin yaw, 0, -cos yaw).
function RoadsShoreLayout.faceYaw(face: Vector3): number
	local f = flat(face).Unit
	return math.atan2(-f.X, -f.Z)
end

function RoadsShoreLayout.run(
	points: { Vector3 },
	from: number,
	to: number,
	side: number,
	offset: number,
	piece: number
): { Spot }
	local out: { Spot } = {}
	local stop = math.min(to, RoadsShoreLayout.length(points))
	for _, sm in StreetLayout.walk(points, piece, math.max(from, 0), stop) do
		local pos = StreetLayout.offset(sm, side, offset)
		table.insert(out, { pos = pos, yaw = RoadsShoreLayout.yawAlong(sm.dir), s = sm.s })
	end
	return out
end

function RoadsShoreLayout.spot(points: { Vector3 }, s: number, side: number, offset: number): Spot?
	local total = RoadsShoreLayout.length(points)
	local want = if s < 0 then total + s else s
	if want < 0 or want > total then
		return nil
	end
	local sm = StreetLayout.walk(points, total + 1, want, want)[1]
	if not sm then
		return nil
	end
	return {
		pos = StreetLayout.offset(sm, side, offset),
		yaw = RoadsShoreLayout.yawAlong(sm.dir),
		s = want,
	}
end

-- Places a short run on the outside of each sharp bend. `look` is the arc length over which the heading change is
-- measured; a right-hand bend puts the barrier on its left (the outside), and vice versa.
function RoadsShoreLayout.barriers(
	points: { Vector3 },
	opts: {
		step: number?,
		look: number?,
		minTurn: number?,
		piece: number?,
		run: number?,
		offset: number?,
		gap: number?,
	}
): { Spot }
	local step = opts.step or 6
	local look = math.max(1, math.round((opts.look or 24) / step))
	local minTurn = opts.minTurn or math.rad(32)
	local piece = opts.piece or 12
	local count = opts.run or 3
	local offset = opts.offset or 11
	local gap = opts.gap or 45
	local samples = StreetLayout.walk(points, step)
	local out: { Spot } = {}
	local lastS = -math.huge
	for i = look + 1, #samples - look do
		local a, b = samples[i - look].dir, samples[i + look].dir
		local cross = a.X * b.Z - a.Z * b.X
		local dot = a.X * b.X + a.Z * b.Z
		local turn = math.atan2(cross, dot)
		if math.abs(turn) >= minTurn and samples[i].s - lastS >= gap then
			local side = if turn > 0 then -1 else 1
			local half = (count - 1) * piece / 2
			local run = RoadsShoreLayout.run(
				points,
				samples[i].s - half,
				samples[i].s + half + 1e-3,
				side,
				offset,
				piece
			)
			for _, p in run do
				table.insert(out, p)
			end
			lastS = samples[i].s
		end
	end
	return out
end

-- Field boundaries off one side of a road: a straight hedge line running away from the road every `every` studs of
-- arc length (from `offset` out to `offset + depth`), each a list of `piece`-stud spots; the caller adds the back
-- hedge (run() at offset + depth) and stops a line where the ground is not field.
function RoadsShoreLayout.fieldLines(
	points: { Vector3 },
	from: number,
	to: number,
	side: number,
	offset: number,
	depth: number,
	every: number,
	piece: number
): { { Spot } }
	local out: { { Spot } } = {}
	local stop = math.min(to, RoadsShoreLayout.length(points))
	for _, sm in StreetLayout.walk(points, every, math.max(from, 0) + every / 2, stop) do
		local base = StreetLayout.offset(sm, side, offset)
		local out_ = (base - StreetLayout.offset(sm, side, 0)).Unit
		local line: { Spot } = {}
		for k = 1, math.floor(depth / piece) do
			table.insert(line, {
				pos = base + out_ * (piece * (k - 0.5)),
				yaw = RoadsShoreLayout.yawAlong(out_),
				s = sm.s,
			})
		end
		table.insert(out, line)
	end
	return out
end

-- Deterministic even disk scatter (golden-angle spiral with a little jitter from a fixed seed).
function RoadsShoreLayout.scatter(
	center: Vector3,
	radius: number,
	count: number,
	seed: number,
	inner: number?
): { Vector3 }
	local lo = inner or 0
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function rand(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	local out: { Vector3 } = {}
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 1, count do
		local t = (i - 0.5) / count
		local r = math.min(radius, lo + (radius - lo) * math.sqrt(t) * (0.9 + rand() * 0.1))
		local a = i * golden + (rand() - 0.5) * 0.35
		table.insert(
			out,
			Vector3.new(center.X + math.cos(a) * r, center.Y, center.Z + math.sin(a) * r)
		)
	end
	return out
end

return RoadsShoreLayout
