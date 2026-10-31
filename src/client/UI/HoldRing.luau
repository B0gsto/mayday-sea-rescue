--!strict
-- HoldRing: a round progress ring that fills clockwise from 12 o'clock (the prompt cue's hold timer).
-- Two clipped halves of a stroked circle, each masked by a hard-edged UIGradient that turns with the progress.
--   HoldRing.rotations(p) -> (right, left)  the two gradients' Rotation for progress p (0..1); pure, tested
--   HoldRing.new(parent, thickness, color) -> set(p)
local HoldRing = {}

function HoldRing.rotations(p: number): (number, number)
	local deg = math.clamp(p, 0, 1) * 360
	return math.min(deg, 180), 180 + math.clamp(deg - 180, 0, 180)
end

function HoldRing.new(parent: GuiObject, thickness: number, color: Color3): (number) -> ()
	local grads: { UIGradient } = {}
	for i, left in { false, true } do
		local clip = Instance.new("Frame")
		clip.Name = if left then "RingL" else "RingR"
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.5, 1)
		clip.Position = UDim2.fromScale(if left then 0 else 0.5, 0)
		clip.Parent = parent
		local circle = Instance.new("Frame")
		circle.BackgroundTransparency = 1
		circle.Size = UDim2.new(2, -thickness, 1, -thickness)
		circle.Position = UDim2.new(if left then 0 else -1, thickness / 2, 0, thickness / 2)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = thickness
		stroke.Color = color
		stroke.Parent = circle
		local g = Instance.new("UIGradient") -- opaque on one side, a hard edge through the centre
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.501, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = stroke
		circle.Parent = clip
		grads[i] = g
	end
	local function set(p: number)
		local r, l = HoldRing.rotations(p)
		grads[1].Rotation = r
		grads[2].Rotation = l
		for _, g in grads do -- the gradient's parent is the stroke, its parent the circle
			((g.Parent :: Instance).Parent :: Frame).Visible = p > 0
		end
	end
	set(0)
	return set
end

return HoldRing
