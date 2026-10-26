--!strict
-- Card: a gradient shop row. Art left, title (+ an optional 2-5 word line), PriceButton right.
-- States: "buy", "disabled" (can't afford), "owned" (the price button reads Owned), "locked"
-- (grey card, padlock over the art, price greyed).
--   local c = Card.new(parent, { art = "vip", title = "VIP", line = "Double cash forever",
--       color = "purple", price = 399, currency = "Robux", onBuy = fn })
--   c.setState("owned")  c.setLine("Active 2h")   c.root: Frame, full width x Theme.Size.card (compact: cardCompact)
local PriceButton = require(script.Parent:WaitForChild("PriceButton"))
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local S = Theme.Size

export type State = "buy" | "disabled" | "owned" | "locked"
export type Props = {
	art: string, -- a UiImages.Kit icon name, or an rbxassetid:// image
	title: string,
	line: string?,
	color: string?,
	price: number,
	currency: ("Robux" | "Cash")?,
	state: State?,
	onBuy: (() -> ())?,
}
export type Card = {
	root: Frame,
	art: Frame, -- the art well (overlay a product image on it)
	price: PriceButton.PriceButton,
	setState: (State) -> (),
	setLine: (string?) -> (),
}

local Card = {}

function Card.new(parent: Instance?, props: Props): Card
	local root = Instance.new("Frame")
	root.Name = "Card"
	root.BackgroundTransparency = 1
	-- shortcut: compact is read once, at creation (panels rebuild their cards on open); live re-fit if needed
	local vp, scale = Style.metrics(parent or root)
	local height = if Theme.compact(vp, scale) then S.cardCompact else S.card
	root.Size = UDim2.new(1, 0, 0, height)
	local holder, face = Style.block(root, Style.grad(props.color or "yellow"))

	local artSide = height - S.lip - 22
	local well = Instance.new("Frame")
	well.Name = "Art"
	well.BackgroundColor3 = Color3.new(1, 1, 1)
	well.BackgroundTransparency = 0.6
	well.AnchorPoint = Vector2.new(0, 0.5)
	well.Position = UDim2.new(0, 11, 0.5, 0)
	well.Size = UDim2.fromOffset(artSide, artSide)
	Style.corner(well, S.cornerSmall)
	well.Parent = face
	if string.find(props.art, "://", 1, true) then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = props.art
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = well
	else
		Style.icon(well, props.art)
	end
	local lock = Instance.new("Frame")
	lock.Name = "Lock"
	lock.BackgroundTransparency = 1
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.5)
	lock.Size = UDim2.fromScale(0.7, 0.7)
	lock.ZIndex = 2
	lock.Parent = well
	Style.icon(lock, "lock").ZIndex = 2

	local priceW = S.price.X + 14
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(artSide + 24, 8)
	words.Size = UDim2.new(1, -(artSide + 24 + priceW), 1, -16)
	words.Parent = face
	local list = Style.list(words, false, 2)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = Style.label(words, props.title, Theme.Text.heading)
	title.Size = UDim2.new(1, 0, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	-- narrow cards (portrait phones): the name wraps to 2 lines and shrinks to fit instead of cutting off
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = Theme.Text.heading
	cap.MinTextSize = 16
	cap.Parent = title
	words:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local du = root.AbsoluteSize.Y / height -- px per du, whatever scales sit above
		local narrow = du > 0 and words.AbsoluteSize.X / du < 200
		title.TextWrapped = narrow
		title.TextScaled = narrow
		title.Size = UDim2.new(1, 0, 0, if narrow then 60 else 34)
	end)
	-- the 2-5 word line: a size up from small with the full-weight outline, readable on every gradient
	local line = Style.label(words, props.line or "", Theme.Text.small + 2)
	line.Name = "Line"
	line.Size = UDim2.new(1, 0, 0, 28)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextTruncate = Enum.TextTruncate.AtEnd
	line.LayoutOrder = 1
	line.Visible = props.line ~= nil
	local ls = line:FindFirstChildOfClass("UIStroke")
	if ls then
		ls.Thickness = Theme.Size.textStroke
	end

	local pb = PriceButton.new(
		face,
		{ price = props.price, currency = props.currency, onActivate = props.onBuy }
	)
	pb.root.AnchorPoint = Vector2.new(1, 0.5)
	pb.root.Position = UDim2.new(1, -12, 0.5, 0)

	local function setState(s: State)
		lock.Visible = s == "locked"
		Style.recolor(
			holder,
			Style.grad(if s == "locked" then "locked" else props.color or "yellow")
		)
		pb.setState(if s == "locked" then "disabled" else s)
	end
	setState(props.state or "buy")
	root.Parent = parent
	return {
		root = root,
		art = well,
		price = pb,
		setState = setState,
		setLine = function(text: string?)
			line.Text = text or ""
			line.Visible = text ~= nil and text ~= ""
		end,
	}
end

return Card
