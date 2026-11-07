--!strict
-- Boat/GoBack (docs/30 section 1): the rules of the Go back button, pure (tests/GoBack.spec.luau). The server
-- (VehicleService) validates every press with them; GoBackController shows the button by the same rule.
local ColdOpen = require(script.Parent.ColdOpen)
local UpgradeStation = require(script.Parent.Parent.UpgradeStation)

local GoBack = {}

-- The ride (owner 2026-11-07: "automatically turn the vehicle and go fast back in 5 sec ish"): the hull swings its bow
-- toward home in place (TURN), then drives itself home along a clear route (plan) in RUN, however far, and swings round
-- into the bay bow to sea. Server and the riders' clients both pose it with GoBack.pose, so the clients' view is smooth.
GoBack.TURN = 0.8 -- s: the swing toward home; a pirate ram in it still cancels -- tune
GoBack.RUN = 4 -- s: the drive home, speed scaled to the route -- tune
GoBack.ARRIVE = GoBack.TURN + GoBack.RUN -- s from the press to stopped in the bay
GoBack.LAND_HOLD = 0.3 -- s the hull stays anchored at home: the pivot reaches every client before one owns it again
GoBack.COOLDOWN = 2 -- s between presses: longer than the cancel window (TURN); a ride refuses presses itself
GoBack.APPROACH = 150 -- studs seaward of the landing: the run comes in here and swings round into the bay -- tune
GoBack.RUN_IN = 400 -- studs further out: where a boxed-in ride reappears from under the veil
GoBack.LAUNCH = 150 -- studs of seen launch before the veil when no clear route home exists
GoBack.LOOK = 60 -- studs ahead along the route the bow points at, so corners round off
local ACCEL, DECEL = 0.15, 0.35 -- shares of RUN spent speeding up and slowing down
local SWING = 0.7 -- share of the last leg the swing round to the landing's heading takes
local RINGS = { 400, 900, 1600 } -- studs from the approach point: waypoint candidates round obstacles
GoBack.BAY_RADIUS = 60 -- studs round the Upgrade Station's landing: already there, no button -- tune

-- Is `at` in the bay Go back lands in? UpgradeStation places it from the berth (`bay`: its CFrame, seaward along -Z).
local function inBay(at: Vector3, bay: any): boolean
	if typeof(bay) ~= "CFrame" then
		return false
	end
	local p = UpgradeStation.fromBerth(bay).Position
	return Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude <= GoBack.BAY_RADIUS
end

-- Home for the button, the first trip and the long pick-up reach: the drop-off zone or the bay.
function GoBack.isHome(at: Vector3, bay: any): boolean
	return ColdOpen.atDropOff(at, bay) or inBay(at, bay)
end

-- The boat level's extra pick-up studs (up to 198). Near home they don't count: from the bay they would board the
-- cove-mouth swimmers (AmbientMix.HOME_CLEAR out), and Go back would pay for them with no trip at all.
GoBack.REACH_HOME = 320 -- studs from the berth: AmbientMix.HOME_CLEAR (tests/GoBack.spec)
function GoBack.reachAt(at: Vector3, bay: any, reach: number): number
	local p = ColdOpen.dropOff(bay)
	local home = p ~= nil and Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude < GoBack.REACH_HOME
	return if home then 0 else reach
end

export type State = {
	driving: boolean, -- in the craft's DriverSeat
	coldOpenDone: boolean,
	survivors: number, -- aboard this craft
	testRide: boolean,
	at: Vector3, -- the craft
	bay: any, -- the driver's berth (player attribute BayCFrame)
	spinning: boolean?, -- the prize wheel's sequence is running (server attribute WheelSpinning)
}

-- Why this press does nothing, or nil when it goes.
function GoBack.refusal(s: State): string?
	if not s.driving then
		return "NotDriving"
	elseif s.spinning then
		return "Spinning"
	elseif s.testRide then
		return "TestRide"
	elseif not s.coldOpenDone and s.survivors <= 0 then
		return "ColdOpen" -- the first rescue comes first
	elseif not ColdOpen.dropOff(s.bay) then
		return "NoHome"
	elseif GoBack.isHome(s.at, s.bay) then
		return "Home"
	end
	return nil
end

-- The rate limit: last is the os.clock of the last press that counted, nil for none.
function GoBack.ready(last: number?, now: number): boolean
	return last == nil or now - last >= GoBack.COOLDOWN
end

export type Route = {
	start: CFrame, -- the hull's pivot at the press
	finish: CFrame, -- its pivot at rest in the bay (flat, bow to sea)
	points: { Vector3 }, -- start, waypoints, approach, landing: straight legs
	jump: number?, -- leg k (points[k] -> points[k + 1]) is crossed in an instant under the veil
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function yawOf(v: Vector3): number -- CFrame.Angles(0, yaw, 0).LookVector = v, flat
	return math.atan2(-v.X, -v.Z)
end

-- Into (-pi + 0.05, pi + 0.05]: a half turn always goes the same way, so float noise never flips the swing mid-way.
local function wrap(a: number): number
	a = (a + math.pi) % (2 * math.pi) - math.pi
	return if a < -math.pi + 0.05 then a + 2 * math.pi else a
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

function GoBack.approach(finish: CFrame): Vector3
	return finish.Position + flat(finish.LookVector).Unit * GoBack.APPROACH
end

-- The route home from `start` to `finish` (pivots). `clear(a, b)` says a hull can run straight from a to b. Straight to
-- the approach point when clear, else round the shortest clear waypoint; boxed in, a short seen launch, then the veil
-- carries it RUN_IN out to sea in front of the bay. The approach point -> landing leg is the bay's own mouth.
function GoBack.plan(start: CFrame, finish: CFrame, clear: (Vector3, Vector3) -> boolean): Route
	local s, land, a = start.Position, finish.Position, GoBack.approach(finish)
	local function route(points: { Vector3 }, jump: number?): Route
		return { start = start, finish = finish, points = points, jump = jump }
	end
	if clear(s, a) then
		return route({ s, a, land })
	end
	local tries = {}
	for i = 0, 15 do
		local d = Vector3.new(math.cos(i * math.pi / 8), 0, math.sin(i * math.pi / 8))
		for _, k in RINGS do
			local w = a + d * k
			table.insert(tries, { at = w, length = (w - s).Magnitude + k })
		end
	end
	table.sort(tries, function(x, y)
		return x.length < y.length
	end)
	for _, w in tries do
		if clear(s, w.at) and clear(w.at, a) then
			return route({ s, w.at, a, land })
		end
	end
	local out = a + flat(finish.LookVector).Unit * GoBack.RUN_IN
	local home = flat(a - s)
	local base = if home.Magnitude > 0.01 then math.atan2(home.Z, home.X) else 0
	for k = 0, 15 do -- the launch: the clear bearing nearest home
		local ang = base + math.ceil(k / 2) * (if k % 2 == 0 then 1 else -1) * math.pi / 8
		local p = s + Vector3.new(math.cos(ang), 0, math.sin(ang)) * GoBack.LAUNCH
		if clear(s, p) then
			return route({ s, p, out, a, land }, 2)
		end
	end
	return route({ s, out, a, land }, 1)
end

local function legs(r: Route): (number, number) -- seen length, and how far along it the jump is
	local seen, jumpAt = 0, math.huge
	for i = 1, #r.points - 1 do
		if i == r.jump then
			jumpAt = seen
		else
			seen += (r.points[i + 1] - r.points[i]).Magnitude
		end
	end
	return seen, jumpAt
end

-- Where the hull is `d` studs along the seen route, and the leg it is on.
local function along(r: Route, d: number): (Vector3, number)
	local n = #r.points
	for i = 1, n - 1 do
		if i ~= r.jump then
			local a, b = r.points[i], r.points[i + 1]
			local len = (b - a).Magnitude
			if d <= len or i == n - 1 then
				return a:Lerp(b, if len > 0 then math.clamp(d / len, 0, 1) else 1), i
			end
			d -= len
		end
	end
	return r.points[n], n - 1
end

-- 0..1 of the route covered at 0..1 of RUN: a hard launch, top speed, a long glide in.
function GoBack.progress(u: number): number
	u = math.clamp(u, 0, 1)
	local top = 1 / (1 - ACCEL / 2 - DECEL / 2)
	if u < ACCEL then
		return top * u * u / (2 * ACCEL)
	elseif u < 1 - DECEL then
		return top * (ACCEL / 2 + u - ACCEL)
	end
	return 1 - top * (1 - u) ^ 2 / (2 * DECEL)
end

-- The top speed of a route, studs/s (the camera widens with it).
function GoBack.topSpeed(r: Route): number
	return legs(r) / GoBack.RUN / (1 - ACCEL / 2 - DECEL / 2)
end

-- Seconds from the press to the jump under the veil, or nil when every leg is seen.
function GoBack.jumpTime(r: Route): number?
	local seen, at = legs(r)
	if not r.jump or seen <= 0 then
		return nil
	end
	local lo, hi = 0, 1
	for _ = 1, 30 do
		local mid = (lo + hi) / 2
		if GoBack.progress(mid) * seen < at then
			lo = mid
		else
			hi = mid
		end
	end
	return GoBack.TURN + hi * GoBack.RUN
end

local function yawAt(r: Route, t: number): number
	local startYaw = yawOf(r.start.LookVector)
	local seen, jumpAt = legs(r)
	local function heading(d: number): number
		local p, leg = along(r, d)
		local ahead = math.min(d + GoBack.LOOK, seen, if d < jumpAt then jumpAt else math.huge)
		local v = flat(along(r, ahead) - p)
		if v.Magnitude < 1 then
			v = flat(r.points[leg + 1] - r.points[leg])
		end
		return if v.Magnitude > 0.01 then yawOf(v) else startYaw
	end
	if t < GoBack.TURN then
		return startYaw + wrap(heading(0) - startYaw) * smooth(t / GoBack.TURN)
	end
	local d = GoBack.progress((t - GoBack.TURN) / GoBack.RUN) * seen
	local yaw = heading(d)
	local n = #r.points
	local last = (r.points[n] - r.points[n - 1]).Magnitude
	local k = if last > 0 then smooth((d - (seen - last)) / (last * SWING)) else 1
	return yaw + wrap(yawOf(r.finish.LookVector) - yaw) * k
end

-- The hull's pivot `t` s after the press: turning in place, then along the route, nose up on the launch and banked into
-- the turns. At ARRIVE and after: exactly `finish`.
function GoBack.pose(r: Route, t: number): CFrame
	if t >= GoBack.ARRIVE then
		return r.finish
	end
	local seen = legs(r)
	local u = math.clamp((t - GoBack.TURN) / GoBack.RUN, 0, 1)
	local p = if t < GoBack.TURN then r.start.Position else along(r, GoBack.progress(u) * seen)
	local yaw = yawAt(r, math.max(t, 0))
	local rate = wrap(yawAt(r, t + 0.05) - yaw) / 0.05
	local bank = math.clamp(rate * 0.05, -0.25, 0.25)
	local lift = if t < GoBack.TURN
		then 0
		else 0.1 * math.sin(math.pi * math.clamp(u / (2 * ACCEL), 0, 1))
	return CFrame.new(p) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(lift, 0, bank)
end

return GoBack
