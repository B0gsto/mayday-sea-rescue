--!strict
-- RipCurrent (pure): the rip current of the beach rescues (docs/09 section 8.4, docs/13 LU-2).
-- A rip is the seaward return flow in a channel between the breaking waves: everything floating
-- in the channel is carried out. Swimming straight back against it barely moves; swimming
-- parallel to the beach crosses the channel and escapes it (USLA lifeguard guidance).
--
-- One field, three users: casualties drift with velocityAt (RescueService), swimmers swim plus
-- velocityAt (SwimController), floating kit drifts with velocityAt (client Mechanics/Rip/View).
-- Lune-tested: tests/RipCurrent.spec.luau.
export type Field = {
	origin: Vector3, -- flat: the shore end of the channel (the flow starts here)
	direction: Vector3, -- flat unit: seaward, the way the water runs
	strength: number, -- studs/s at the centre line (about 2 knots: a strong rip)
	width: number, -- studs across the channel; the flow is zero at and past the edges
	length: number, -- studs out: the flow fades away by here
}

local RipCurrent = {}

-- The Haven Sands rip: off the slipway, out past the lifeguard tower's flag line. Seaward here is
-- the beach normal (the shoreline runs north-east to south-west), so the flow runs out and away
-- from the sand: the casualty starts about 120 studs down the channel and is carried toward `length`.
RipCurrent.HavenSands = table.freeze({
	origin = Vector3.new(960, 0, 330),
	direction = Vector3.new(-0.6, 0, 0.8),
	strength = 6.5,
	width = 70,
	length = 240,
} :: Field)

-- Where the beach rescue ends: the Haven Sands waterline, and the dry sand where the lifeguard /
-- passer-by takes over (the same points as BoatColdOpen.SHORE.Sands; update both if the beach
-- moves).
RipCurrent.Shore = table.freeze({
	water = Vector3.new(1000, 0, 282),
	dry = Vector3.new(970, 0, 250),
})

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- The seaward unit direction of the channel.
function RipCurrent.unit(field: Field): Vector3
	local d = flat(field.direction)
	return if d.Magnitude > 1e-3 then d.Unit else Vector3.zAxis
end

-- The along-shore direction (parallel to the beach): across the channel, the way out of it.
function RipCurrent.shoreParallel(field: Field): Vector3
	local d = RipCurrent.unit(field)
	return Vector3.new(-d.Z, 0, d.X)
end

-- A point of the channel: `t` studs out along the flow, `s` studs across it (0 = centre line).
function RipCurrent.point(field: Field, t: number, s: number): Vector3
	return field.origin + RipCurrent.unit(field) * t + RipCurrent.shoreParallel(field) * s
end

-- The current at a flat position, studs/s, zero outside the channel. Cosine profile across the
-- channel (full on the centre line, nothing at the edges), ramped in from the shore and faded
-- out at sea so the flow has a visible end.
function RipCurrent.velocityAt(field: Field, pos: Vector3): Vector3
	local d = RipCurrent.unit(field)
	local rel = flat(pos - field.origin)
	local t = rel:Dot(d)
	if t <= 0 or t >= field.length then
		return Vector3.zero
	end
	local s = rel:Dot(RipCurrent.shoreParallel(field))
	local half = math.max(field.width / 2, 1)
	if math.abs(s) >= half then
		return Vector3.zero
	end
	local across = math.cos(math.abs(s) / half * math.pi / 2)
	local along = math.min(t / (field.length * 0.25), 1)
		* (1 - math.clamp((t - field.length * 0.7) / (field.length * 0.3), 0, 1))
	return d * (field.strength * across * along)
end

-- The ground velocity a swimmer makes: their own stroke through the water plus the current.
-- Against the flow this is barely any way on; across it they leave the channel at full speed.
function RipCurrent.swimVelocity(
	field: Field,
	pos: Vector3,
	heading: Vector3,
	speed: number
): Vector3
	local h = flat(heading)
	local swim = if h.Magnitude > 1e-3 then h.Unit * speed else Vector3.zero
	return swim + RipCurrent.velocityAt(field, pos)
end

return RipCurrent
