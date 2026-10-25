--!strict
-- PriceButton: the big green buy button. Robux glyph (Roblox's built-in) or the Cash icon + the
-- number. States: "buy" (green, pressable), "disabled" (grey: can't afford), "owned" ("Owned").
--   local b = PriceButton.new(parent, { price = 399, currency = "Robux", onActivate = fn })
--   b.setState("owned") / b.setPrice(n)   b.root is the ImageButton (size Theme.Size.price)
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local UiImages = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("UiImages")
)

local S = Theme.Size

export type State = "buy" | "disabled" | "owned"
export type Props = {
	price: number,
	currency: ("Robux" | "Cash")?,
	state: State?,
	onActivate: (() -> ())?,
}
export type PriceButton = {
	root: ImageButton,
	setState: (State) -> (),
	setPrice: (number) -> (),
	setText: (string?) -> (),
}

local PriceButton = {}

local function glyph(parent: Instance, currency: string): GuiObject
	local box = Instance.new("Frame")
	box.Name = "Glyph"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(42, 42)
	box.LayoutOrder = 1
	if currency == "Robux" then
		-- the white glyph over a dark copy nudged down-right reads as the outlined font
		for i, off in { Vector2.new(2, 3), Vector2.zero } do
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = Theme.ROBUX
			img.ImageColor3 = if i == 1 then Theme.Colors.ink else Color3.new(1, 1, 1)
			img.Size = UDim2.fromScale(1, 1)
			img.Position = UDim2.fromOffset(off.X, off.Y)
			img.Parent = box
		end
	else
		Style.icon(box, "cash")
	end
	local check = Instance.new("ImageLabel")
	check.Name = "Check"
	check.BackgroundTransparency = 1
	check.Image = UiImages.VehicleArt.Check
	check.Size = UDim2.fromScale(1, 1)
	check.Visible = false
	check.Parent = box
	box.Parent = parent
	return box
end

function PriceButton.new(parent: Instance?, props: Props): PriceButton
	local root = Style.button(parent, UDim2.fromOffset(S.price.X, S.price.Y))
	root.Name = "PriceButton"
	local holder, face = Style.block(root, Style.grad("buy"), { studs = true })
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = face
	local list = Style.list(row, true, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local g = glyph(row, props.currency or "Robux")
	local num = Style.label(row, "", Theme.Text.button)
	num.AutomaticSize = Enum.AutomaticSize.X
	num.Size = UDim2.fromScale(0, 1)
	num.TextWrapped = false
	num.LayoutOrder = 2

	local price = props.price
	local state: State = props.state or "buy"
	local override: string? = nil
	local function paint()
		Style.recolor(holder, Style.grad(if state == "buy" then "buy" else "disabled"))
		root.Active = state == "buy"
		-- owned: grey + a tick, so it never reads as a buy button
		for _, c in g:GetChildren() do
			if c:IsA("GuiObject") then
				c.Visible = (c.Name == "Check") == (state == "owned")
			end
		end
		num.Text = override or (if state == "owned" then "Owned" else Theme.short(price))
	end
	paint()
	Style.press(root, props.onActivate)

	return {
		root = root,
		setState = function(s: State)
			state = s
			paint()
		end,
		setPrice = function(n: number)
			price = n
			paint()
		end,
		setText = function(text: string?)
			override = text
			paint()
		end,
	}
end

return PriceButton
