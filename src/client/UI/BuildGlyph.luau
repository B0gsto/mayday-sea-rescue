--!strict
-- BuildGlyph: an island item's Lego line drawing (DockBlueprints.GLYPHS) inside a square frame `parent`. Card
-- art: white bricks with an ink edge, holes in ink. With `line` (px): white outlines only (the paper
-- blueprints). Used by the build tablet (DockController) and the boat boards' "Needs" chips.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DockBlueprints =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DockBlueprints"))
local Theme = require(script.Parent:WaitForChild("Kit"):WaitForChild("Theme"))

return function(parent: GuiObject, item: DockBlueprints.Item, line: number?)
	for _, box in DockBlueprints.glyph(item) do
		local f = Instance.new("Frame")
		f.Name = "Brick"
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(box.x, box.y)
		f.Size = UDim2.fromScale(box.w, box.h)
		f.BackgroundColor3 = if box.hole then Theme.Colors.ink else Color3.new(1, 1, 1)
		f.BackgroundTransparency = if line then 1 else 0
		f.ZIndex = if box.hole then 3 else 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if box.round
			then UDim.new(0.5, 0)
			else UDim.new(0, if line then 2 else 4)
		corner.Parent = f
		local stroke = Instance.new("UIStroke")
		stroke.Color = if line then Color3.new(1, 1, 1) else Theme.Colors.ink
		stroke.Thickness = line or 2.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
		f.Parent = parent
	end
end
