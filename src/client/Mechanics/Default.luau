--!strict
-- Default stub mechanic: used by OpsController for any step whose
-- src/client/Mechanics/<mechanicId>.luau is missing. Shows "Step: <name> [Complete]" and returns
-- a stub result; the server grades stubs Silver at most (on its own metrics only).
-- Interface (CONTRACT.md "Operations v2"): start(ctx, finish) -> cleanup?
local Players = game:GetService("Players")

local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))

local Default = {}

function Default.start(
	ctx: { [string]: any },
	finish: (result: { [string]: any }) -> ()
): (() -> ())?
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "OpsStubMechanic"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -110)
	frame.Size = UDim2.fromOffset(420, 120)
	frame.BackgroundColor3 = HudTheme.Colors.panel
	frame.BackgroundTransparency = HudTheme.PanelTransparency
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, HudTheme.Corner)
	corner.Parent = frame
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 8)
	title.Size = UDim2.new(1, -32, 0, 30)
	title.Font = HudTheme.HeaderFont
	title.TextColor3 = HudTheme.Colors.text
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = `Step: {ctx.step.label}`
	title.Parent = frame
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(16, 38)
	sub.Size = UDim2.new(1, -32, 0, 18)
	sub.Font = HudTheme.BodyFont
	sub.TextColor3 = HudTheme.Colors.textDim
	sub.TextSize = 15
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = `{ctx.step.realTerm} · {ctx.role} · {ctx.step.mechanicId} (stub)`
	sub.Parent = frame
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -14, 1, -10)
	button.Size = UDim2.fromOffset(160, HudTheme.MinButtonHeight)
	button.BackgroundColor3 = HudTheme.Colors.accent
	button.Font = HudTheme.BoldFont
	button.TextColor3 = HudTheme.Colors.text
	button.TextSize = 20
	button.Text = "Complete"
	button.Parent = frame
	local bcorner = Instance.new("UICorner")
	bcorner.CornerRadius = UDim.new(0, HudTheme.Corner)
	bcorner.Parent = button

	local done = false
	local function complete()
		if done then
			return
		end
		done = true
		gui:Destroy()
		finish({ metrics = {}, stub = true, grade = "Silver" })
	end
	button.Activated:Connect(complete)
	gui.Parent = player:WaitForChild("PlayerGui")
	-- smoke runs (tools/studio/smoke.py ops) set this attribute so the stub completes by itself
	if player:GetAttribute("OpsAutoStub") == true then
		task.delay(1, complete)
	end
	return function()
		done = true
		gui:Destroy()
	end
end

return Default
