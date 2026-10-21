--!strict
-- TitleTag (G28, a CosmeticsController feature): the earned 1-2 word title under the name tag.
-- Local only: every other player's "Cos_Title" gets a BillboardGui below their default name tag
-- (G38: a readable 5 x 0.85 stud plate at chase distance, MaxDistance 120); "None" removes it.
-- No plate, no glow: pale text with a dark stroke so it reads against sky and hull.
local Players = game:GetService("Players")

local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))

local TitleTag = {}
TitleTag.Priority = 90

local NAME = "TitleTag"

local function attach(model: Model, option: any): BillboardGui?
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = NAME
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Size = UDim2.fromScale(5, 0.85)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.42, 0)
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = HudTheme.HeaderFont
	label.TextScaled = true
	label.Text = option.text
	label.TextColor3 = Color3.fromRGB(242, 228, 186)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(16, 20, 24)
	label.Parent = gui
	gui.Parent = head
	return gui
end

function TitleTag.Start(ctx: any)
	local tags: { [Player]: BillboardGui } = {}

	local function refresh(player: Player)
		local old = tags[player]
		if old then
			old:Destroy()
			tags[player] = nil
		end
		local character = player.Character
		local id = ctx.equipped(player, "Title")
		local option = ctx.Cosmetics.option("Title", id)
		if not character or not option or type(option.text) ~= "string" then
			return
		end
		local tag = attach(character, option)
		if tag then
			tags[player] = tag
		end
	end

	local function track(player: Player)
		ctx.onEquipped(player, "Title", function()
			refresh(player)
		end)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Head", 10)
			refresh(player)
		end)
		task.spawn(refresh, player)
	end

	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player: Player)
		local old = tags[player]
		if old then
			old:Destroy()
		end
		tags[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return TitleTag
