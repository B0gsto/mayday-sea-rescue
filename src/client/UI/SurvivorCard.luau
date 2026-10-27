--!strict
-- SurvivorCard (docs/25 J): the small info card opened by tapping a survivor. Info only, no choices:
-- name, rarity, type, trait, work value, workplace, effect, and the special's badge. In the water a
-- survivor says only name, rarity and type. Built from the Kit (Style block / label / icon / press, the
-- Panel's red X and dim backdrop); closes with the X, a tap outside, B or Escape.
--   local card = SurvivorCard.new(Style.canvas(gui))
--   card.open(SurvivorTag.info(model), inWater)  (water = name, rarity, type only)
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Rarity =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Rarity"))
local Style = require(script.Parent:WaitForChild("Kit"):WaitForChild("Style"))
local SurvivorTag = require(script.Parent:WaitForChild("SurvivorTag"))
local Theme = require(script.Parent:WaitForChild("Kit"):WaitForChild("Theme"))
local WorkerBadge = require(script.Parent:WaitForChild("WorkerBadge"))

local SurvivorCard = {}

local ACTION = "SurvivorCardClose"
local WIDTH = 372
local PAD = 16
local ICON = 32
local ROW_H = 36
local HEADER = 86
local CHIP_H = 38
local CHIP_GAP = 8
local GOLD = Color3.fromRGB(255, 214, 60)

export type Card = {
	open: (info: SurvivorTag.Info, water: boolean) -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

type Row = {
	icon: string,
	category: boolean?,
	value: string,
	color: Color3?,
}

local function words(id: string): string
	return (id:gsub("(%l)(%u)", "%1 %2"))
end

local function rowLabel(parent: Instance, value: string, color: Color3?)
	local label = Style.label(parent, value, Theme.Text.body)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = false
	label.TextScaled = true
	if color then
		label.TextColor3 = color
	end
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = Theme.Text.body
	cap.MinTextSize = 14
	cap.Parent = label
	return label
end

function SurvivorCard.new(canvas: Instance): Card
	local hit = Style.button(canvas, UDim2.fromScale(1, 1))
	hit.Name = "SurvivorCardHit"
	hit.BackgroundColor3 = Theme.Colors.shadow
	hit.BackgroundTransparency = 0.5
	hit.Selectable = false
	hit.ZIndex = 1
	hit.Visible = false

	local root = Instance.new("Frame")
	root.Name = "SurvivorCard"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(WIDTH, HEADER + PAD)
	root.Visible = false
	root.ZIndex = 2
	root.Parent = canvas

	local generation = 0
	local closeButton: ImageButton? = nil

	local function close()
		if not root.Visible then
			return
		end
		generation += 1
		local token = generation
		hit.Visible = false
		ContextActionService:UnbindAction(ACTION)
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(root) then
			GuiService.SelectedObject = nil
		end
		local scale = root:FindFirstChild("PopScale")
		if scale and scale:IsA("UIScale") then
			Style.tween(scale, 0.14, { Scale = 0.6 })
			task.delay(0.14, function()
				if token == generation then
					root.Visible = false
				end
			end)
		else
			root.Visible = false
		end
	end

	hit.Activated:Connect(close)

	local function open(info: SurvivorTag.Info, water: boolean)
		generation += 1
		for _, child in root:GetChildren() do
			if not child:IsA("UIScale") then
				child:Destroy()
			end
		end

		local rows: { Row } = {}
		if info.typeName ~= "" then
			table.insert(rows, { icon = info.category, category = true, value = info.typeName })
		end
		if not water then
			if info.traitName ~= "" then
				table.insert(rows, { icon = info.trait, value = info.traitName })
			end
			table.insert(rows, {
				icon = "cash",
				value = `Work x{string.format("%g", info.work)}`,
				color = GOLD,
			})
			table.insert(rows, { icon = "map", value = info.workplaceName })
			if info.effect ~= "" then
				table.insert(rows, { icon = "boost", value = info.effect })
			end
		end
		local special = if water then "" else words(info.special)
		local height = HEADER + #rows * ROW_H + PAD
		if special ~= "" then
			height += CHIP_GAP + CHIP_H
		end
		root.Size = UDim2.fromOffset(WIDTH, height)

		local _, face = Style.block(root, Style.grad("ink"), { shadow = true })

		local name = Style.label(face, info.name, Theme.Text.heading)
		name.Name = "Name"
		name.Position = UDim2.fromOffset(PAD, 10)
		name.Size = UDim2.new(1, -(PAD * 2 + 58), 0, 42)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextYAlignment = Enum.TextYAlignment.Center
		name.TextWrapped = false
		name.TextScaled = true
		name.TextColor3 = info.color
		local nameCap = Instance.new("UITextSizeConstraint")
		nameCap.MaxTextSize = Theme.Text.heading
		nameCap.MinTextSize = 12
		nameCap.Parent = name

		local rarity = Style.label(face, info.rarityName, Theme.Text.small)
		rarity.Name = "Rarity"
		rarity.Position = UDim2.fromOffset(PAD + 2, 52)
		rarity.Size = UDim2.new(1, -(PAD * 2), 0, 26)
		rarity.TextXAlignment = Enum.TextXAlignment.Left
		rarity.TextWrapped = false
		rarity.TextColor3 = Rarity.TIERS[info.rarity].color

		local x = Style.button(face, UDim2.fromOffset(48, 52))
		x.Name = "Close"
		x.AnchorPoint = Vector2.new(1, 0)
		x.Position = UDim2.new(1, -12, 0, 10)
		x.ZIndex = 3
		local _, xFace = Style.block(x, Style.grad("close"), { radius = Theme.Size.cornerSmall })
		local xLabel = Style.label(xFace, "X", Theme.Text.title)
		xLabel.TextScaled = false
		Style.press(x, close, Theme.Size.cornerSmall)
		closeButton = x

		for i, row in rows do
			local line = Instance.new("Frame")
			line.Name = "Row"
			line.BackgroundTransparency = 1
			line.Position = UDim2.fromOffset(PAD, HEADER + (i - 1) * ROW_H)
			line.Size = UDim2.new(1, -PAD * 2, 0, ROW_H)
			line.Parent = face

			local box = Instance.new("Frame")
			box.BackgroundTransparency = 1
			box.AnchorPoint = Vector2.new(0, 0.5)
			box.Position = UDim2.fromScale(0, 0.5)
			box.Size = UDim2.fromOffset(ICON, ICON)
			box.Parent = line
			if row.category then
				WorkerBadge.icon(box, row.icon)
			else
				Style.icon(box, row.icon)
			end

			local label = rowLabel(line, row.value, row.color)
			label.Position = UDim2.fromOffset(ICON + 10, 0)
			label.Size = UDim2.new(1, -(ICON + 10), 1, 0)
		end

		if special ~= "" then
			local chip = Instance.new("Frame")
			chip.Name = "Special"
			chip.BackgroundTransparency = 1
			chip.Position = UDim2.fromOffset(PAD, height - PAD - CHIP_H)
			chip.Size = UDim2.new(1, -PAD * 2, 0, CHIP_H)
			chip.Parent = face
			local _, chipFace = Style.block(chip, Style.grad("yellow"), { radius = 9, lip = 4 })
			local box = Instance.new("Frame")
			box.BackgroundTransparency = 1
			box.AnchorPoint = Vector2.new(0, 0.5)
			box.Position = UDim2.new(0, 8, 0.5, 0)
			box.Size = UDim2.fromOffset(24, 24)
			box.Parent = chipFace
			Style.icon(box, "vip")
			local label = Style.label(chipFace, special, Theme.Text.body, true)
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextWrapped = false
			label.TextScaled = true
			label.Position = UDim2.fromOffset(38, 0)
			label.Size = UDim2.new(1, -44, 1, 0)
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = Theme.Text.body
			cap.MinTextSize = 12
			cap.Parent = label
		end

		hit.Visible = true
		Style.pop(root, true)
		ContextActionService:UnbindAction(ACTION)
		ContextActionService:BindAction(ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				close()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.B, Enum.KeyCode.ButtonB, Enum.KeyCode.Escape)
		if UserInputService.GamepadEnabled and closeButton then
			GuiService.SelectedObject = closeButton
		end
	end

	return {
		open = open,
		close = close,
		isOpen = function()
			return root.Visible
		end,
	}
end

return SurvivorCard
