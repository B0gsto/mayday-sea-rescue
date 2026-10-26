--!strict
-- Toggle: a chunky on/off switch for settings rows. Green with the knob right when on, grey with
-- the knob left when off (colour + knob position, never colour alone).
--   local t = Toggle.new(parent, { on = true, onChange = function(on) end })   t.set(false)
local Style = require(script.Parent:WaitForChild("Style"))
local Theme = require(script.Parent:WaitForChild("Theme"))

export type Toggle = { root: ImageButton, set: (boolean) -> (), get: () -> boolean }

local Toggle = {}

local W, H = 124, 64 -- >= 44 px at the phone floor

function Toggle.new(parent: Instance?, props: { on: boolean, onChange: ((boolean) -> ())? }): Toggle
	local on = props.on
	local root = Style.button(parent, UDim2.fromOffset(W, H))
	root.Name = "Toggle"
	local holder, face = Style.block(root, Theme.Grad.buy, { radius = H / 2, lip = 5 })
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(H - 14, H - 14)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	Style.corner(knob, H)
	Style.stroke(knob, 3, true)
	knob.Parent = face

	local function paint(animate: boolean)
		Style.recolor(holder, Style.grad(if on then "buy" else "disabled"))
		local pos = UDim2.new(if on then 1 else 0, if on then -(H - 14) - 6 else 6, 0.5, -2)
		if animate then
			Style.tween(knob, 0.18, { Position = pos }, Enum.EasingStyle.Back)
		else
			knob.Position = pos
		end
	end
	paint(false)
	Style.press(root, function()
		on = not on
		paint(true)
		if props.onChange then
			props.onChange(on)
		end
	end, H / 2)

	return {
		root = root,
		set = function(v: boolean)
			on = v
			paint(true)
		end,
		get = function()
			return on
		end,
	}
end

return Toggle
