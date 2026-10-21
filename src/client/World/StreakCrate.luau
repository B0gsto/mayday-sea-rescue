--!strict
-- StreakCrate: the wooden sea chest on the station porch (docs/15 hook H5), code-built Parts.
-- Built locally by StreakController, so each player sees only their own crate and its opening.
-- Rope handles, iron bands, a 7-pip streak strip on the lid, a gold ribbon on a day-7 crate and
-- a bigger, rope-coiled body on a welcome-back crate. No text.

local RunService = game:GetService("RunService")

local WOOD = Color3.fromRGB(122, 84, 50)
local WOOD_DARK = Color3.fromRGB(88, 58, 34)
local IRON = Color3.fromRGB(58, 62, 66)
local ROPE = Color3.fromRGB(186, 154, 104)
local GOLD = Color3.fromRGB(255, 200, 92)
local PIP_OFF = Color3.fromRGB(64, 48, 32)
local PIP_ON = Color3.fromRGB(255, 214, 110)

export type Options = { streak: number, welcome: boolean, weekly: boolean }
export type Crate = {
	model: Model,
	prompt: ProximityPrompt,
	top: Vector3,
	open: () -> (),
}

local StreakCrate = {}

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
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function StreakCrate.build(at: CFrame, opts: Options): Crate
	local model = Instance.new("Model")
	model.Name = "StreakCrate"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local scale = if opts.welcome then 1.35 else 1.0
	local w, h, d = 5.6 * scale, 3.1 * scale, 3.6 * scale
	local bodyY = h / 2
	local lidY = h

	local base = part(
		model,
		"Base",
		Vector3.new(w, h, d),
		at * CFrame.new(0, bodyY, 0),
		WOOD,
		Enum.Material.Wood
	)
	model.PrimaryPart = base

	-- iron bands down the two long faces
	for _, z in { -d / 2 - 0.02, d / 2 + 0.02 } do
		for _, x in { -w * 0.28, w * 0.28 } do
			part(
				model,
				"Band",
				Vector3.new(0.34, h + 0.05, 0.06),
				at * CFrame.new(x, bodyY, z),
				IRON,
				Enum.Material.Metal
			)
		end
	end

	-- rope handles on both short sides
	for _, x in { -w / 2 - 0.06, w / 2 + 0.06 } do
		part(
			model,
			"RopeHandle",
			Vector3.new(d * 0.62, 0.13, 0.13),
			at * CFrame.new(x, h * 0.62, 0) * CFrame.Angles(0, math.pi / 2, 0),
			ROPE,
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		for _, z in { -d * 0.31, d * 0.31 } do
			part(
				model,
				"RopeKnot",
				Vector3.new(0.3, 0.3, 0.3),
				at * CFrame.new(x, h * 0.62, z),
				ROPE,
				Enum.Material.Fabric,
				Enum.PartType.Ball
			)
		end
	end

	-- lid, hinged at its back edge; every lid part rotates about the same hinge line
	local hinge = at * CFrame.new(0, h, -d / 2)
	local lidParts: { { part: Part, rel: CFrame } } = {}
	local function lidPart(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material
	): Part
		local p = part(model, name, size, cf, color, material)
		table.insert(lidParts, { part = p, rel = hinge:Inverse() * cf })
		return p
	end

	lidPart(
		"Lid",
		Vector3.new(w + 0.4, 0.55 * scale, d + 0.35),
		at * CFrame.new(0, lidY + 0.275 * scale, 0),
		WOOD_DARK,
		Enum.Material.Wood
	)
	-- the 7-pip streak strip on the lid (icons only)
	for i = 1, 7 do
		local x = (i - 3.5) * 0.68 * scale
		lidPart(
			`Pip{i}`,
			Vector3.new(0.12, 0.46 * scale, 0.46 * scale),
			at * CFrame.new(x, lidY + 0.58 * scale, 0.2) * CFrame.Angles(0, 0, math.pi / 2),
			if i <= opts.streak then PIP_ON else PIP_OFF,
			if i <= opts.streak then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
	end

	if opts.weekly then
		-- gold ribbon and buckle for the day-7 weekly cosmetic crate
		lidPart(
			"RibbonLong",
			Vector3.new(0.55 * scale, 0.06, d + 0.4),
			at * CFrame.new(0, lidY + 0.56 * scale, 0),
			GOLD,
			Enum.Material.Neon
		)
		lidPart(
			"RibbonCross",
			Vector3.new(w + 0.4, 0.06, 0.55 * scale),
			at * CFrame.new(0, lidY + 0.57 * scale, 0),
			GOLD,
			Enum.Material.Neon
		)
		part(
			model,
			"FrontStrap",
			Vector3.new(0.55 * scale, h, 0.05),
			at * CFrame.new(0, bodyY, d / 2 + 0.03),
			GOLD,
			Enum.Material.SmoothPlastic
		)
	end

	if opts.welcome then
		-- a pair of rope coils on the lid marks the bigger welcome-back crate
		for _, x in { -w * 0.2, w * 0.2 } do
			lidPart(
				"RopeCoil",
				Vector3.new(0.36, 1.5, 1.5),
				at
					* CFrame.new(x, lidY + 0.55 * scale + 0.2, -d * 0.16)
					* CFrame.Angles(0, 0, math.pi / 2),
				ROPE,
				Enum.Material.Fabric
			)
		end
	end

	-- a lid handle on the front so the chest reads as openable
	lidPart(
		"LidHandle",
		Vector3.new(1.3 * scale, 0.26, 0.3),
		at * CFrame.new(0, lidY + 0.05, d / 2 + 0.02),
		IRON,
		Enum.Material.Metal
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StreakCratePrompt"
	prompt.ActionText = "Open"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = base

	model.Parent = workspace

	local opening = false
	local crate: Crate = {
		model = model,
		prompt = prompt,
		top = (at * CFrame.new(0, lidY + 0.9, 0)).Position,
		open = function()
			if opening then
				return
			end
			opening = true
			prompt.Enabled = false
			local t = 0
			local conn: RBXScriptConnection? = nil
			conn = RunService.Heartbeat:Connect(function(dt: number)
				t = math.min(t + dt / 0.55, 1)
				local angle = -math.rad(108) * (1 - (1 - t) ^ 3)
				for _, entry in lidParts do
					entry.part.CFrame = hinge * CFrame.Angles(angle, 0, 0) * entry.rel
				end
				if t >= 1 and conn then
					conn:Disconnect()
					conn = nil
				end
			end)
		end,
	}
	return crate
end

return StreakCrate
