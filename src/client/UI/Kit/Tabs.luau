--!strict
-- Tabs: a row of chunky pill tabs (icon + 1 word); the selected one is yellow and raised.
-- Gamepad: shoulder buttons step the tabs while `root` is visible.
--   local t = Tabs.new(panel.top, { { name = "Boats", icon = "shop" }, ... }, function(i) end)
--   t.select(2)  t.selected()
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local S = Theme.Size

export type Tab = { name: string, icon: string? }
export type Tabs = {
	root: Frame,
	select: (number) -> (),
	selected: () -> number,
}

local Tabs = {}

function Tabs.new(parent: Instance, tabs: { Tab }, onSelect: ((number) -> ())?): Tabs
	local root = Instance.new("Frame")
	root.Name = "Tabs"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, S.tab)
	local list = Style.list(root, true, 10)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom

	local current = 1
	local items: { { root: ImageButton, holder: Frame } } = {}
	local function paint()
		for i, it in items do
			local on = i == current
			Style.recolor(it.holder, Style.grad(if on then "yellow" else "blue"))
			it.root.Size =
				UDim2.new(1 / #tabs, -10 + 10 / #tabs, 0, if on then S.tab else S.tab - 6)
		end
	end
	local function pick(i: number)
		current = math.clamp(i, 1, #tabs)
		paint()
		if onSelect then
			onSelect(current)
		end
	end

	for i, tab in tabs do
		local b = Style.button(root, UDim2.new())
		b.Name = "Tab_" .. tab.name
		b.LayoutOrder = i
		local holder, face = Style.block(b, Theme.Grad.blue, { lip = 5, radius = S.cornerSmall })
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 1)
		row.Parent = face
		local l = Style.list(row, true, 6)
		l.HorizontalAlignment = Enum.HorizontalAlignment.Center
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		if tab.icon then
			local ic = Instance.new("Frame")
			ic.BackgroundTransparency = 1
			ic.Size = UDim2.fromOffset(32, 32)
			ic.Parent = row
			Style.icon(ic, tab.icon)
		end
		local t = Style.label(row, tab.name, Theme.Text.body)
		t.TextWrapped = false
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromScale(0, 1)
		t.LayoutOrder = 1
		Style.press(b, function()
			pick(i)
		end, S.cornerSmall)
		table.insert(items, { root = b, holder = holder })
	end
	paint()

	local conn = UserInputService.InputBegan:Connect(function(input)
		local host: Instance? = root
		while host and host:IsA("GuiObject") do
			if not host.Visible then
				return
			end
			host = host.Parent
		end
		if input.KeyCode == Enum.KeyCode.ButtonL1 then
			pick(current - 1)
		elseif input.KeyCode == Enum.KeyCode.ButtonR1 then
			pick(current + 1)
		end
	end)
	root.Destroying:Connect(function()
		conn:Disconnect()
	end)

	root.Parent = parent
	return {
		root = root,
		select = pick,
		selected = function()
			return current
		end,
	}
end

return Tabs
