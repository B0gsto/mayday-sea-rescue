--!strict
-- StepTrail: where the guide footprints go along a walking route (FootTrail, the phone's spawn guide).
-- Pure (tests/StepTrail.spec.luau). steps(points, first, spacing, count, stride): a print every
-- `spacing` studs along the polyline, the first `first` studs in, at most `count`; feet alternate
-- left / right of the line by stride / 2. dir is the flat (XZ) walking direction.
export type Step = { pos: Vector3, dir: Vector3, left: boolean }

local StepTrail = {}

function StepTrail.steps(
	points: { Vector3 },
	first: number,
	spacing: number,
	count: number,
	stride: number
): { Step }
	local out: { Step } = {}
	local want = first -- distance along the route of the next print
	local walked = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = flat.Magnitude
		if len > 1e-3 then
			local dir = flat / len
			local right = Vector3.new(-dir.Z, 0, dir.X)
			while want <= walked + len and #out < count do
				local left = #out % 2 == 0
				local pos = a:Lerp(b, (want - walked) / len)
					+ right * (if left then -stride / 2 else stride / 2)
				table.insert(out, { pos = pos, dir = dir, left = left })
				want += spacing
			end
			walked += len
		end
		if #out >= count then
			break
		end
	end
	return out
end

return StepTrail
