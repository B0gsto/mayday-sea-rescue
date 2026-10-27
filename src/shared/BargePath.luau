--!strict
-- BargePath (docs/25 D, K4): where the supply barge is at server time `t`, from the plot's BargeNext (the server
-- time of the next mooring) and the barge period. In the mooring frame (the moored barge's pivot, bow -Z, +X away
-- from the quay): it sails in bow first along -Z for ARRIVE s, moors STAY s, drifts DRIFT studs off the quay,
-- swings round a half circle away from it and sails back out along +Z. nil: out of sight.
local BargePath = {}

BargePath.ARRIVE = 15
BargePath.STAY = 20 -- K4: it stays 20 s
BargePath.SHOVE = 5 -- s drifting off the quay (the stern would swing into it on a straight turn)
BargePath.TURN = 10
BargePath.LEAVE = 9
BargePath.REACH = 160 -- studs out to sea where it shows / goes
BargePath.DRIFT = 10
BargePath.RADIUS = 22

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- seconds since the last mooring (nil while the next one is still far off)
local function since(t: number, nextAt: number, period: number): number
	local dt = nextAt - t
	return if dt <= 0 then -dt else period - dt
end

function BargePath.at(t: number, nextAt: number, period: number): CFrame?
	local B = BargePath
	local dt = nextAt - t
	if dt >= 0 and dt <= B.ARRIVE then
		local u = 1 - dt / B.ARRIVE
		return CFrame.new(0, 0, B.REACH * (1 - u) * (1 - u)) -- eases in to the quay
	end
	local s = since(t, nextAt, period)
	if s < 0 then
		return nil
	elseif s < B.STAY then
		return CFrame.identity
	end
	s -= B.STAY
	if s < B.SHOVE then
		return CFrame.new(B.DRIFT * smooth(s / B.SHOVE), 0, 0)
	end
	s -= B.SHOVE
	local x0, r = B.DRIFT, B.RADIUS
	if s < B.TURN then
		local a = math.pi * smooth(s / B.TURN)
		local p = Vector3.new(x0 + r - r * math.cos(a), 0, -r * math.sin(a))
		return CFrame.lookAt(p, p + Vector3.new(math.sin(a), 0, -math.cos(a)))
	end
	s -= B.TURN
	if s < B.LEAVE then
		local u = s / B.LEAVE
		local p = Vector3.new(x0 + 2 * r, 0, B.REACH * u * u)
		return CFrame.lookAt(p, p + Vector3.zAxis)
	end
	return nil
end

-- true while it lies at the quay (Haulers unload then)
function BargePath.moored(t: number, nextAt: number, period: number): boolean
	return BargePath.at(t, nextAt, period) == CFrame.identity
end

-- 0..1 through the stay (its crates go one by one), nil when not moored
function BargePath.unloaded(t: number, nextAt: number, period: number): number?
	return if BargePath.moored(t, nextAt, period)
		then since(t, nextAt, period) / BargePath.STAY
		else nil
end

-- the next mooring when the server publishes none yet (K4: every period, the same on every client)
function BargePath.fallbackNext(t: number, period: number): number
	return (math.floor(t / period) + 1) * period
end

return BargePath
