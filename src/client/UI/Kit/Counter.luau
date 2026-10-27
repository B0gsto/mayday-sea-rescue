--!strict
-- Counter: the money pill (bottom left in the references). A green studded pill, a big icon
-- hanging over its left end, the number outlined in white.
--   local c = Counter.new(parent, { kind = "cash", value = 1250 })   c.set(1500) (counts up)
--   c.root: Frame, Theme.Size.counter
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local S = Theme.Size

export type Props = { kind: string?, value: number }
export type Counter = { root: Frame, set: (number) -> () }

local Counter = {}

function Counter.new(parent: Instance?, props: Props): Counter
	local kind = props.kind or "cash"
	local root = Instance.new("Frame")
	root.Name = "Counter_" .. kind
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(S.counter.X, S.counter.Y)

	local pill = Instance.new("Frame")
	pill.BackgroundTransparency = 1
	pill.Position = UDim2.fromOffset(S.counter.Y * 0.5, 0)
	pill.Size = UDim2.new(1, -S.counter.Y * 0.5, 1, 0)
	pill.Parent = root
	local _, face =
		Style.block(pill, Style.grad("green"), { radius = S.counter.Y / 2, lip = 5, studs = true })

	local num = Style.label(face, "", Theme.Text.title - 6)
	num.TextXAlignment = Enum.TextXAlignment.Left
	num.TextWrapped = false
	num.Position = UDim2.fromOffset(S.counter.Y * 0.62, 0)
	num.Size = UDim2.new(1, -S.counter.Y * 0.62 - 12, 1, 0)

	local ic = Instance.new("Frame")
	ic.Name = "Icon"
	ic.BackgroundTransparency = 1
	ic.AnchorPoint = Vector2.new(0, 0.5)
	ic.Position = UDim2.new(0, -6, 0.5, -2)
	ic.Size = UDim2.fromOffset(S.counter.Y + 14, S.counter.Y + 14)
	ic.ZIndex = 2
	ic.Parent = root
	Style.icon(ic, kind)
	local bump = Instance.new("UIScale")
	bump.Parent = ic

	local shown = props.value
	num.Text = Theme.short(shown)
	local token = 0
	local function set(n: number)
		token += 1
		local mine, from = token, shown
		shown = n
		bump.Scale = 1.25
		Style.tween(bump, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.spawn(function()
			for i = 1, 12 do
				if token ~= mine then
					return
				end
				num.Text = Theme.short(from + (n - from) * i / 12)
				task.wait(1 / 30)
			end
		end)
	end

	root.Parent = parent
	return { root = root, set = set }
end

return Counter
