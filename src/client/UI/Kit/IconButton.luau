--!strict
-- IconButton: a coloured square with an icon and a short label under it (the left button bar).
--   local b = IconButton.new(parent, { icon = "shop", label = "Shop", color = "yellow", onActivate = fn })
--   b.setBadge(3) / b.setBadge(true) (dot) / b.setBadge(nil)   b.root: ImageButton, Theme.Size.icon wide
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local S = Theme.Size

export type Props = {
	icon: string,
	label: string,
	color: string?,
	size: number?, -- square side in du (default Theme.Size.icon)
	onActivate: (() -> ())?,
}
export type IconButton = {
	root: ImageButton,
	setBadge: ((number | boolean)?) -> (),
}

local IconButton = {}

function IconButton.new(parent: Instance?, props: Props): IconButton
	local side = props.size or S.icon
	local root = Style.button(parent, UDim2.fromOffset(side, side + S.iconLabel))
	root.Name = "IconButton_" .. props.icon

	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.BackgroundTransparency = 1
	tile.Size = UDim2.fromOffset(side, side)
	tile.Parent = root
	local _, face = Style.block(tile, Style.grad(props.color or "blue"), { radius = S.corner + 4 })
	local art = Instance.new("Frame")
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.86, 0.86)
	art.Parent = face
	Style.icon(art, props.icon)

	local label = Style.label(root, props.label, Theme.Text.small)
	label.Name = "Label"
	label.TextWrapped = false
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, 2)
	label.Size = UDim2.new(1, 24, 0, S.iconLabel)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BackgroundColor3 = Theme.Colors.badge
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.new(1, -6, 0, 6)
	badge.Size = UDim2.fromOffset(30, 30)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.Visible = false
	badge.ZIndex = 3
	Style.corner(badge, 15)
	Style.stroke(badge, 3, true).Color = Color3.new(1, 1, 1)
	local count = Style.label(badge, "", Theme.Text.small)
	count.TextWrapped = false
	count.AutomaticSize = Enum.AutomaticSize.X
	count.Size = UDim2.fromScale(0, 1)
	count.ZIndex = 3
	Style.pad(badge, 0)
	local pads = badge:FindFirstChildOfClass("UIPadding") :: UIPadding
	pads.PaddingLeft = UDim.new(0, 8)
	pads.PaddingRight = UDim.new(0, 8)
	badge.Parent = root

	Style.press(root, props.onActivate, S.corner + 4)

	return {
		root = root,
		setBadge = function(v: (number | boolean)?)
			badge.Visible = v ~= nil and v ~= false and v ~= 0
			local n = if type(v) == "number" then v else nil
			count.Text = if n then (if n > 9 then "9+" else tostring(n)) else ""
			badge.Size = if n then UDim2.fromOffset(14, 30) else UDim2.fromOffset(24, 24)
			pads.PaddingLeft = UDim.new(0, if n then 8 else 0)
			pads.PaddingRight = UDim.new(0, if n then 8 else 0)
		end,
	}
end

return IconButton
