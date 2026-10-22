--!strict
-- InputGlyph: the one device helper for HUD panels (docs 14 section 2, RP-UX1).
--   device()          "Keyboard" | "Gamepad" | "Touch" from UserInputService.PreferredInput
--   onDevice(fn)      fn(device) now and on every change
--   text(kb, pad)     the short key label for the device in use ("E", "X", "LB"; "" on touch)
--   chip(parent, kb, pad)  a small key chip that tracks the device (gamepad: the platform's
--                     button image; hidden on touch, where the button itself is the target)
--   modal(name, onClose)   while open: B closes, a gamepad player starts on `first`
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local HudTheme = require(script.Parent.HudTheme)

export type Device = "Keyboard" | "Gamepad" | "Touch"
export type Modal = { open: (first: GuiObject?) -> (), close: () -> () }

local InputGlyph = {}

function InputGlyph.device(): Device
	local p = UserInputService.PreferredInput
	if p == Enum.PreferredInput.Touch then
		return "Touch"
	elseif p == Enum.PreferredInput.Gamepad or p == Enum.PreferredInput.MicroGamepad then
		return "Gamepad"
	end
	return "Keyboard"
end

function InputGlyph.onDevice(fn: (Device) -> ()): RBXScriptConnection
	local c = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		fn(InputGlyph.device())
	end)
	task.spawn(fn, InputGlyph.device())
	return c
end

local PAD: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonL1] = "LB",
	[Enum.KeyCode.ButtonR1] = "RB",
	[Enum.KeyCode.ButtonL2] = "LT",
	[Enum.KeyCode.ButtonR2] = "RT",
	[Enum.KeyCode.ButtonStart] = "Menu",
	[Enum.KeyCode.DPadUp] = "Up",
	[Enum.KeyCode.DPadDown] = "Down",
	[Enum.KeyCode.DPadLeft] = "Left",
	[Enum.KeyCode.DPadRight] = "Right",
}
local KEY: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Return] = "Enter",
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.Escape] = "Esc",
	[Enum.KeyCode.Backquote] = "`",
	[Enum.KeyCode.Backspace] = "Bksp",
}

function InputGlyph.text(kb: Enum.KeyCode?, pad: Enum.KeyCode?): string
	local d = InputGlyph.device()
	if d == "Gamepad" and pad then
		return PAD[pad] or pad.Name
	elseif d == "Keyboard" and kb then
		return KEY[kb] or kb.Name
	end
	return ""
end

function InputGlyph.chip(parent: Instance, kb: Enum.KeyCode?, pad: Enum.KeyCode?): Frame
	local f = Instance.new("Frame")
	f.Name = "KeyChip"
	f.Size = UDim2.fromOffset(28, 28)
	f.AnchorPoint = Vector2.new(1, 0)
	f.Position = UDim2.new(1, -4, 0, 4)
	f.BackgroundColor3 = HudTheme.Colors.panel
	f.BackgroundTransparency = 0.2
	f.ZIndex = 5
	HudTheme.corner(f, 4)
	HudTheme.stroke(f)
	local t = HudTheme.label("Key", "", UDim2.fromScale(1, 1), HudTheme.HeaderFont, 14, f)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.ZIndex = 5
	local img = Instance.new("ImageLabel")
	img.Name = "Pad"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.ZIndex = 5
	img.Parent = f
	f.Parent = parent
	InputGlyph.onDevice(function(d: Device)
		local image = if d == "Gamepad" and pad
			then UserInputService:GetImageForKeyCode(pad)
			else ""
		img.Image = image
		t.Text = if image == "" then InputGlyph.text(kb, pad) else ""
		f.Visible = t.Text ~= "" or image ~= ""
		f.Size = UDim2.fromOffset(math.max(28, 10 + 9 * #t.Text), 28)
	end)
	return f
end

-- B (gamepad back) calls onClose while the modal is open; open(first) puts gamepad focus on
-- `first`, close() releases B and any focus inside the panel.
function InputGlyph.modal(name: string, onClose: () -> ()): Modal
	local root: GuiObject? = nil
	local action = `Modal_{name}`
	return {
		open = function(first: GuiObject?)
			ContextActionService:BindActionAtPriority(action, function(_, state)
				if state == Enum.UserInputState.Begin then
					onClose()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value + 5, Enum.KeyCode.ButtonB)
			root = first
			if first and first:IsA("GuiButton") then
				-- free the mouse in first person so the panel is clickable
				first.Modal = true
			end
			if first and UserInputService.GamepadEnabled then
				GuiService.SelectedObject = first
			end
		end,
		close = function()
			ContextActionService:UnbindAction(action)
			local sel, r = GuiService.SelectedObject, root
			local gui = r and r:FindFirstAncestorOfClass("ScreenGui")
			if sel and gui and sel:IsDescendantOf(gui) then
				GuiService.SelectedObject = nil
			end
			root = nil
		end,
	}
end

return InputGlyph
