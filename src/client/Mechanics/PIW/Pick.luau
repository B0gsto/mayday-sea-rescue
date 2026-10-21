--!strict
-- PIW/Pick: what the aim point is on. A chosen target stays chosen while the pointer is still, so
-- a bobbing boat cannot swap it under the cursor; a real pointer move chooses again. Every target
-- gets at least a 44 px hit area. Pure: Care.picker feeds it screen positions.
local Pick = {}

Pick.HIT = 22 -- px: radius of a target's hit area (44 px across)
Pick.CLICK_HIT = 44 -- px: a mouse click or touch tap this close to a target picks it -- tune
Pick.MOVE = 8 -- px the pointer must move before it may choose a different target

export type Target = { id: string, at: Vector2 }

local function nearest(aim: Vector2, targets: { Target }, reach: number): string?
	local best: string?, bestD = nil, reach
	for _, t in targets do
		local d = (t.at - aim).Magnitude
		if d <= bestD then
			best, bestD = t.id, d
		end
	end
	return best
end

local function has(targets: { Target }, id: string?): boolean
	for _, t in targets do
		if t.id == id then
			return true
		end
	end
	return false
end

-- aim: pointer (or screen centre). moved: the pointer moved since it chose `current`. current:
-- what is held now. reach: px a fresh pick may land in (at least Pick.HIT).
function Pick.choose(
	aim: Vector2,
	moved: boolean,
	targets: { Target },
	current: string?,
	reach: number?
): string?
	if current and not moved and has(targets, current) then
		return current
	end
	return nearest(aim, targets, math.max(reach or Pick.HIT, Pick.HIT))
end

-- The stick steps through the targets left to right across the screen (then top to bottom),
-- wrapping. current nil starts at the first step in.
function Pick.cycle(targets: { Target }, current: string?, step: number): string?
	local n = #targets
	if n == 0 then
		return nil
	end
	local sorted = table.clone(targets)
	table.sort(sorted, function(a, b)
		if math.abs(a.at.X - b.at.X) > 8 then
			return a.at.X < b.at.X
		end
		return a.at.Y < b.at.Y
	end)
	local at = 0
	for i, t in sorted do
		if t.id == current then
			at = i
			break
		end
	end
	return sorted[(at + step - 1) % n + 1].id
end

return Pick
