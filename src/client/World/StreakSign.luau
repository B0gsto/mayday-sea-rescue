--!strict
-- StreakSign: the small sign beside the daily crate at the player's bay (docs/16 K12): seven day pips,
-- no text. Claimed days glow gold, today's crate (when it waits) glows white. Built locally by
-- StreakController; the board reads from the `at` frame's +Z side.

local WOOD = Color3.fromRGB(96, 66, 42)
local FACE = Color3.fromRGB(34, 42, 50)
local PIP_OFF = Color3.fromRGB(64, 48, 32)
local PIP_ON = Color3.fromRGB(255, 214, 110)
local PIP_TODAY = Color3.fromRGB(242, 236, 218)
local DAYS = 7

export type Sign = {
	model: Model,
	setDays: (claimed: number, today: boolean) -> (),
}

local StreakSign = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
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
	part(
		model,
		"Board",
		Vector3.new(3.6, 1.1, 0.18),
		at * CFrame.new(0, 4.5, 0),
		WOOD,
		Enum.Material.Wood
	)
	part(
		model,
		"Face",
		Vector3.new(3.36, 0.86, 0.04),
		at * CFrame.new(0, 4.5, 0.1),
		FACE,
		Enum.Material.SmoothPlastic
	)
	part(
		model,
		"Cap",
		Vector3.new(3.9, 0.16, 0.5),
		at * CFrame.new(0, 5.13, 0),
		WOOD,
		Enum.Material.Wood
	)

	local pips: { Part } = {}
	for i = 1, DAYS do
		pips[i] = part(
			model,
			`Pip{i}`,
			Vector3.new(0.36, 0.36, 0.36),
			at * CFrame.new((i - (DAYS + 1) / 2) * 0.46, 4.5, 0.14),
			PIP_OFF,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
	end

	model.Parent = workspace

	return {
		model = model,
		setDays = function(claimed: number, today: boolean)
			for i, pip in pips do
				local on = i <= claimed
				local now = today and i == claimed + 1
				pip.Color = if on then PIP_ON elseif now then PIP_TODAY else PIP_OFF
				pip.Material = if on or now then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end,
	}
end

return StreakSign
