--!strict
-- PushButton: a physical Lego push button in the world (owner 2026-10-26: clickable buttons, not UI).
-- Server only: `onPress` runs on the server and returns false to ignore the press (not the owner, no
-- tokens, product hidden). A press sinks the cap, plays one click and pops back, for everyone.
-- Mouse clicks and touch taps go through the ClickDetector; gamepad (and keyboard) through the
-- ProximityPrompt on the same cap. Return `prompt` so the caller can retitle or disable it.
local TweenService = game:GetService("TweenService")

local AudioConfig = require(script.Parent:WaitForChild("Config"):WaitForChild("AudioConfig"))

local PushButton = {}

export type Options = {
	text: string, -- the cap's label (1-3 words)
	objectText: string?, -- the prompt's line (free spins, the R$ price)
	color: Color3?, -- the cap's plastic
	width: number?, -- the mounting plate / cap diameter
	onPress: (Player) -> boolean?,
}

export type Button = {
	cap: BasePart,
	base: BasePart,
	prompt: ProximityPrompt,
	label: GuiObject?,
	onPress: ((Player) -> boolean?)?,
}

local CLICK = AudioConfig.Clips.UI_Prompt

function PushButton.build(parent: Instance, name: string, cf: CFrame, opts: Options): Button
	local width = opts.width or 3
	local base = Instance.new("Part")
	base.Name = name .. "Base"
	base.Size = Vector3.new(width, width, 0.5)
	base.CFrame = cf * CFrame.new(0, 0, 0.25)
	base.Color = Color3.fromRGB(242, 240, 232)
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = true
	base.TopSurface, base.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	base.Parent = parent

	local cap = Instance.new("Part")
	cap.Name = name
	cap.Shape = Enum.PartType.Cylinder
	cap.Size = Vector3.new(0.85, width * 0.82, width * 0.82)
	cap.CFrame = cf * CFrame.new(0, 0, -0.4) * CFrame.Angles(0, math.pi / 2, 0)
	cap.Color = opts.color or Color3.fromRGB(224, 56, 40)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Anchored = true
	cap.TopSurface, cap.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	cap.Parent = parent
	local rest = cap.CFrame

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- the cylinder's flat face, turned to the front by the rotation
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.5
	gui.Parent = cap
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = opts.text
	label.Parent = gui

	local sound = Instance.new("Sound")
	sound.Name = "Click"
	sound.SoundId = CLICK.id
	sound.Volume = CLICK.volume
	sound.RollOffMaxDistance = 60 -- a button click, not heard across the island
	sound.Parent = base

	local pressing = false
	local function press()
		if pressing or not cap.Parent then
			return
		end
		pressing = true
		sound:Play()
		local down = TweenService:Create(
			cap,
			TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = rest * CFrame.new(0, 0, 0.3) }
		)
		down:Play()
		down.Completed:Once(function()
			task.wait(0.08)
			TweenService:Create(
				cap,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = rest }
			):Play()
			task.wait(0.16)
			pressing = false
		end)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Press"
	prompt.ActionText = opts.text
	prompt.ObjectText = opts.objectText or ""
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12 -- at 24 the plaza wheel took E from the build stand's tablet
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.RequiresLineOfSight = false
	prompt.Parent = cap

	local button: Button = { cap = cap, base = base, prompt = prompt, label = label }
	button.onPress = opts.onPress

	local function activate(player: Player)
		local fn = button.onPress
		if fn and fn(player) == false then
			return
		end
		press()
	end

	local detector = Instance.new("ClickDetector")
	detector.Name = "Click"
	detector.MaxActivationDistance = 24
	detector.Parent = cap
	detector.MouseClick:Connect(activate)
	prompt.Triggered:Connect(activate)

	return button
end

return PushButton
