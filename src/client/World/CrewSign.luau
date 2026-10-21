--!strict
-- CrewSign: the "Join crew" sign beside the harbour noticeboard (docs/15 H9, G68). Code-built,
-- local to each player, shown only when Shared/Config/SocialConfig.GroupId > 0. It draws the Crew
-- pennant, a two-word label and the reward preview (no external link, no popup): the prompt asks
-- Roblox's own GroupService:PromptJoinAsync, and where that is unavailable the sign just informs.
local INK = Color3.fromRGB(238, 240, 236)
local DIM = Color3.fromRGB(158, 174, 182)
local GOLD = Color3.fromRGB(232, 198, 128)
local PAPER = Color3.fromRGB(24, 36, 46)
local WOOD = Color3.fromRGB(96, 66, 42)
local CREW_BLUE = Color3.fromRGB(48, 88, 146)

export type Sign = {
	model: Model,
	prompt: ProximityPrompt,
	setMember: (member: boolean) -> (),
}

local CrewSign = {}

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

local function box(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number
): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- A small pennant: pole, blue field, brass hoop and ball.
local function pennant(parent: Instance, size: number): Frame
	local f = Instance.new("Frame")
	f.Name = "CrewPennant"
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundTransparency = 1
	f.Parent = parent
	box(f, DIM, 0.24, 0.5, 0.06, 0.72)
	box(f, CREW_BLUE, 0.58, 0.34, 0.62, 0.4)
	box(f, GOLD, 0.27, 0.34, 0.06, 0.4)
	box(f, GOLD, 0.58, 0.34, 0.16, 0.16)
	box(f, GOLD, 0.24, 0.12, 0.12, 0.12)
	return f
end

function CrewSign.build(at: CFrame): Sign
	local model = Instance.new("Model")
	model.Name = "CrewSign"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	for _, x in { -1.45, 1.45 } do
		part(
			model,
			"Post",
			Vector3.new(0.24, 6.4, 0.24),
			at * CFrame.new(x, 3.2, -0.15),
			WOOD,
			Enum.Material.Wood
		)
	end
	local board = part(
		model,
		"Board",
		Vector3.new(3.8, 4.4, 0.2),
		at * CFrame.new(0, 4.3, 0),
		WOOD,
		Enum.Material.Wood
	)
	model.PrimaryPart = board
	local face = part(
		model,
		"Face",
		Vector3.new(3.72, 4.32, 0.08),
		at * CFrame.new(0, 4.3, 0.15),
		PAPER,
		Enum.Material.SmoothPlastic
	)
	part(
		model,
		"Cap",
		Vector3.new(4.2, 0.2, 0.6),
		at * CFrame.new(0, 6.6, 0),
		WOOD,
		Enum.Material.Wood
	)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "CrewPrint"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.LightInfluence = 0.2
	gui.MaxDistance = 90
	gui.ClipsDescendants = true
	gui.Parent = face

	local root = Instance.new("Frame")
	root.Name = "Rows"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 8)
	title.Size = UDim2.new(1, 0, 0, 32)
	title.Font = Enum.Font.BuilderSansBold
	title.Text = "CREW"
	title.TextSize = 28
	title.TextColor3 = GOLD
	title.Parent = root

	local icon = pennant(root, 96)
	icon.Position = UDim2.new(0.5, -48, 0, 46)

	local join = Instance.new("TextLabel")
	join.Name = "Join"
	join.BackgroundTransparency = 1
	join.Position = UDim2.fromOffset(0, 148)
	join.Size = UDim2.new(1, 0, 0, 44)
	join.Font = Enum.Font.BuilderSansBold
	join.Text = "Join crew"
	join.TextSize = 34
	join.TextColor3 = INK
	join.Parent = root

	local coin = Instance.new("Frame")
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.new(0.5, -54, 0, 208)
	coin.Size = UDim2.fromOffset(22, 22)
	coin.BackgroundColor3 = GOLD
	coin.BorderSizePixel = 0
	coin.Parent = root
	local coinCorner = Instance.new("UICorner")
	coinCorner.CornerRadius = UDim.new(1, 0)
	coinCorner.Parent = coin

	local bonus = Instance.new("TextLabel")
	bonus.BackgroundTransparency = 1
	bonus.Position = UDim2.new(0.5, -34, 0, 194)
	bonus.Size = UDim2.fromOffset(120, 30)
	bonus.Font = Enum.Font.BuilderSansBold
	bonus.Text = "+10% Cash"
	bonus.TextSize = 24
	bonus.TextColor3 = INK
	bonus.TextXAlignment = Enum.TextXAlignment.Left
	bonus.Parent = root

	local flagIcon = pennant(root, 26)
	flagIcon.Position = UDim2.new(0.5, -62, 0, 232)
	local flagLabel = Instance.new("TextLabel")
	flagLabel.BackgroundTransparency = 1
	flagLabel.Position = UDim2.new(0.5, -34, 0, 230)
	flagLabel.Size = UDim2.fromOffset(140, 30)
	flagLabel.Font = Enum.Font.BuilderSansMedium
	flagLabel.Text = "Crew flag"
	flagLabel.TextSize = 20
	flagLabel.TextColor3 = DIM
	flagLabel.TextXAlignment = Enum.TextXAlignment.Left
	flagLabel.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JoinCrew"
	prompt.ActionText = "Join crew"
	prompt.ObjectText = "Crew"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = board

	local function setMember(member: boolean)
		join.Text = if member then "Crew ✓" else "Join crew"
		join.TextColor3 = if member then Color3.fromRGB(111, 191, 142) else INK
		prompt.Enabled = not member
	end

	model.Parent = workspace

	return { model = model, prompt = prompt, setMember = setMember }
end

return CrewSign
