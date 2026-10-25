--!strict
-- BuildSeq (docs/23 (j), WP-14c): the Lego build beat's ordering and timing, pure
-- (tests/BuildSeq.spec.luau). plan(ys) turns the parts' final heights into a drop plan: bottom to
-- top, each step delayed by a small stagger (with a little deterministic jitter), each part dropping
-- from DROP_MIN..DROP_MAX studs up. The client (DockController) plays the plan with tweens; the
-- server keeps every part at its final CFrame, so a missed event or a late join just sees the
-- finished building. The stagger shrinks as the piece count grows, so the whole drop stays under
-- TARGET seconds (plus the last drop and squash: ~3-6 s for any dock piece).
local BuildSeq = {}

BuildSeq.DROP_MIN = 6
BuildSeq.DROP_MAX = 10
BuildSeq.TARGET = 4.2 -- the stagger span, s (plus the last drop and squash: ~3-6 s total)
BuildSeq.MIN_STAG = 0.02
BuildSeq.MAX_STAG = 0.3
BuildSeq.JITTER = 0.12

export type Step = { i: number, delay: number, drop: number }

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

return BuildSeq
