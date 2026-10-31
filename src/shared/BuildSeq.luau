--!strict
-- BuildSeq (docs/23 (j), WP-14c): the Lego build beat's ordering and timing, pure
-- (tests/BuildSeq.spec.luau). plan(ys) turns the parts' final heights into a drop plan: bottom to
-- top, each step delayed by a small stagger (with a little deterministic jitter), each part dropping
-- from DROP_MIN..DROP_MAX studs up. The client (DockController) plays the plan with tweens; the
-- server keeps every part at its final CFrame, so a missed event or a late join just sees the
-- finished building. The stagger shrinks as the piece count grows, so the whole drop stays under
-- TARGET seconds (plus the last drop and squash: ~3-6 s for any dock piece). The squash (docs/28 feel 5): each brick
-- falls FALL s to SINK studs under its rest, then Back-Outs up into it over SETTLE s; clicks() times one plastic
-- click per course.
local BuildSeq = {}

BuildSeq.DROP_MIN = 6
BuildSeq.DROP_MAX = 10
BuildSeq.TARGET = 4.2 -- the stagger span, s (plus the last drop and squash: ~3-6 s total)
BuildSeq.MIN_STAG = 0.02
BuildSeq.MAX_STAG = 0.3
BuildSeq.JITTER = 0.12
BuildSeq.FALL = 0.45 -- s: a brick's drop (Quad In)
BuildSeq.SINK = 0.1 -- studs: it lands this far under its rest...
BuildSeq.SETTLE = 0.12 -- s: ...then Back-Outs up into it
BuildSeq.CLICK_GAP = 1 / 3 -- s: course clicks at most ~3 a second
BuildSeq.PITCH_LO, BuildSeq.PITCH_HI = 0.9, 1.35 -- the bottom course's click .. the top's

export type Step = { i: number, delay: number, drop: number }
export type Click = { t: number, pitch: number }

local function frac(x: number): number
	return x - math.floor(x)
end

-- Steps for `ys` (the parts' final Ys, index = part order): sorted bottom to top, delays that never
-- overtake, drop heights in [DROP_MIN, DROP_MAX]. `seed` makes the jitter deterministic (tests).
function BuildSeq.plan(ys: { number }, seed: number?): { Step }
	local order = {}
	for i = 1, #ys do
		table.insert(order, i)
	end
	local s = seed or 0
	table.sort(order, function(a: number, b: number): boolean
		if ys[a] == ys[b] then
			return a < b
		end
		return ys[a] < ys[b]
	end)
	local stagger =
		math.clamp(BuildSeq.TARGET / math.max(#ys - 1, 1), BuildSeq.MIN_STAG, BuildSeq.MAX_STAG)
	local out: { Step } = {}
	for k, i in order do
		local jitter = if k > 1 then frac(s * 17.3 + k) * math.min(BuildSeq.JITTER, stagger) else 0
		out[k] = {
			i = i,
			delay = (k - 1) * stagger + jitter,
			drop = BuildSeq.DROP_MIN
				+ frac(s * 7.9 + k * 13.7) * (BuildSeq.DROP_MAX - BuildSeq.DROP_MIN),
		}
	end
	return out
end

-- The latest step delay plan() can give `n` parts: the stagger span plus its jitter (the watch camera holds for it).
function BuildSeq.span(n: number): number
	if n <= 1 then
		return 0
	end
	local stagger = math.clamp(BuildSeq.TARGET / (n - 1), BuildSeq.MIN_STAG, BuildSeq.MAX_STAG)
	return (n - 1) * stagger + math.min(BuildSeq.JITTER, stagger)
end

-- One click per course as it lands (a course: a higher rise key than the last click's), from the plan's start, never
-- closer than CLICK_GAP, its pitch rising with the course's height.
function BuildSeq.clicks(plan: { Step }, ys: { number }): { Click }
	local lo, hi = math.huge, -math.huge
	for _, y in ys do
		lo, hi = math.min(lo, y), math.max(hi, y)
	end
	local out: { Click } = {}
	local lastT, lastY = -math.huge, -math.huge
	for _, step in plan do
		local y, t = ys[step.i], step.delay + BuildSeq.FALL
		if y > lastY and t - lastT >= BuildSeq.CLICK_GAP - 1e-9 then
			local f = if hi > lo then (y - lo) / (hi - lo) else 0
			table.insert(
				out,
				{ t = t, pitch = BuildSeq.PITCH_LO + f * (BuildSeq.PITCH_HI - BuildSeq.PITCH_LO) }
			)
			lastT, lastY = t, y
		end
	end
	return out
end

-- Where a finished level's unlock icon flies (docs/28 feel 6): "Boat" (it opens a craft), "Quests" (it opens a
-- system), "Crew" (a worker building, or more beds / slots), else "Next" (the next build). `def` is the
-- DockConfig.Buildings row, `vehicles` ProgressionConfig.Vehicles, `unlocks` DockConfig.Unlocks.
function BuildSeq.unlockTarget(
	key: string,
	level: number,
	def: any,
	vehicles: { [string]: any },
	unlocks: { [string]: any }
): string
	local row = def and def.levels and def.levels[level]
	local effect: string? = row and row.effect
	for name, v in vehicles do
		if
			not v.passOnly
			and (
				(level == 1 and v.needs == key)
				or (effect and (v.needs == effect or string.find(name, effect, 1, true)))
			)
		then
			return "Boat"
		end
	end
	for _, u in unlocks do
		if u.key == key and u.level == level then
			return "Quests"
		end
	end
	if
		(def and def.worker)
		or (effect and (string.find(effect, "Slots", 1, true) or string.match(effect, "^People")))
	then
		return "Crew"
	end
	return "Next"
end

return BuildSeq
