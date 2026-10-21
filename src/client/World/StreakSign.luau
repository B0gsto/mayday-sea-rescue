--!strict
-- StreakSign: the small porch sign beside the daily crate (docs/15 section 1): a clock icon and
-- the time to the next crate in `12:04` style. Built locally by StreakController.

local WOOD = Color3.fromRGB(96, 66, 42)
local FACE = Color3.fromRGB(34, 42, 50)
local INK = Color3.fromRGB(242, 236, 218)

export type Sign = {
	model: Model,
	setTime: (seconds: number) -> (),
}

local StreakSign = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function frame(parent: Instance, name: string, pos: UDim2, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = INK
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

function StreakSign.build(at: CFrame): Sign
	local model = Instance.new("Model")
	model.Name = "StreakSign"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local post = part(
		model,
		"Post",
		Vector3.new(0.32, 5.2, 0.32),
		at * CFrame.new(0, 2.6, -0.2),
		WOOD,
		Enum.Material.Wood
	)
	model.PrimaryPart = post
	local board = part(
		model,
		"Board",
		Vector3.new(3.6, 1.5, 0.18),
		at * CFrame.new(0, 4.5, 0),
		WOOD,
		Enum.Material.Wood
	)
	part(
		model,
		"Cap",
		Vector3.new(3.9, 0.16, 0.5),
		at * CFrame.new(0, 5.3, 0),
		WOOD,
		Enum.Material.Wood
	)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Time"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0.4
	gui.Parent = board

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = FACE
	panel.BorderSizePixel = 0
	panel.Parent = gui

	-- clock icon: a face with two hands, no numerals
	local clock = Instance.new("Frame")
	clock.Name = "Clock"
	clock.AnchorPoint = Vector2.new(0, 0.5)
	clock.Position = UDim2.fromOffset(16, 48)
	clock.Size = UDim2.fromOffset(48, 48)
	clock.BackgroundColor3 = FACE
	clock.BorderSizePixel = 0
	clock.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = clock
	local ring = Instance.new("UIStroke")
	ring.Color = INK
	ring.Thickness = 2
	ring.Parent = clock

	for i, spec in { { 13, 20 }, { 9, 110 } } do
		local hand =
			frame(clock, `Hand{i}`, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(2, spec[1]))
		hand.AnchorPoint = Vector2.new(0.5, 1)
		hand.Rotation = spec[2]
	end
	local pin = frame(clock, "Pin", UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(5, 5))
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.BackgroundColor3 = INK

	local label = Instance.new("TextLabel")
	label.Name = "Time"
	label.Position = UDim2.fromOffset(74, 0)
	label.Size = UDim2.new(1, -80, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansMedium
	label.TextSize = 34
	label.TextColor3 = INK
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "24:00"
	label.Parent = panel

	model.Parent = workspace

	return {
		model = model,
		setTime = function(seconds: number)
			local total = math.max(0, math.floor(seconds))
			label.Text =
				string.format("%d:%02d", math.floor(total / 3600), math.floor(total % 3600 / 60))
		end,
	}
end

return StreakSign
