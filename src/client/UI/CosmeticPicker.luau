--!strict
-- CosmeticPicker (RP-M5 spine): one row that cycles a cosmetic slot through the options the local
-- player may equip:  [Slot label]  [<]  [option name]  [>]. Touch and mouse tap the arrows; gamepad
-- selects them with the D-pad and presses A. Each step calls Net.Cosmetics_Equip(slot, id)
-- (CosmeticsService checks the pass); the row shows the player's "Cos_<Slot>" attribute, so a server
-- refusal snaps back. Used by the settings panel's "Owned items" section and by owned product cards.
--
--   CosmeticPicker.new(parent, slot, opts?) -> Picker
--     opts = { label: string?, height: number? (du, default 44), labelWidth: number? (scale, 0.36),
--              layoutOrder: number? }
--   picker.frame: Frame            the row (size: full width x height)
--   picker.first: GuiObject        the first selectable button (gamepad focus)
--   picker.refresh()               re-read ownership and the equipped option
--   picker.destroy()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cosmetics"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))

local C = HudTheme.Colors
local player = Players.LocalPlayer

export type Options = {
	label: string?,
	height: number?,
	labelWidth: number?,
	layoutOrder: number?,
}
export type Picker = {
	frame: Frame,
	first: GuiObject,
	refresh: () -> (),
	destroy: () -> (),
}

local EQUIP_TIMEOUT = 8

local CosmeticPicker = {}

local function owns(passKey: string): boolean
	return player:GetAttribute("Pass_" .. passKey) == true
end

-- A readable slot name ("LightBar" -> "Light bar", "DogWear" -> "Dog wear").
function CosmeticPicker.slotLabel(slot: string): string
	local s = Cosmetics.slot(slot)
	if s and type(s.label) == "string" then
		return s.label
	end
	local spaced = string.gsub(slot, "(%l)(%u)", "%1 %2")
	return string.sub(spaced, 1, 1) .. string.lower(string.sub(spaced, 2))
end

local function equipRemote(): RemoteFunction?
	local net = ReplicatedStorage:FindFirstChild("Net")
	local remote = net and net:FindFirstChild("Cosmetics_Equip")
	return if remote and remote:IsA("RemoteFunction") then remote else nil
end

function CosmeticPicker.new(parent: Instance, slot: string, opts: Options?): Picker
	local o: Options = opts or {}
	local height = o.height or 44
	local labelW = o.labelWidth or 0.36

	local row = Instance.new("Frame")
	row.Name = "Cosmetic_" .. slot
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.LayoutOrder = o.layoutOrder or 0
	row.Parent = parent

	local label = HudTheme.label(
		"Label",
		o.label or CosmeticPicker.slotLabel(slot),
		UDim2.new(labelW, -8, 1, 0),
		HudTheme.BodyFont,
		HudTheme.TextSize.body,
		row
	)
	label.TextColor3 = C.text

	local control = Instance.new("Frame")
	control.Name = "Control"
	control.AnchorPoint = Vector2.new(1, 0)
	control.Position = UDim2.fromScale(1, 0)
	control.Size = UDim2.fromScale(1 - labelW, 1)
	control.BackgroundTransparency = 1
	control.Parent = row

	local function arrow(name: string, text: string): TextButton
		local b = HudTheme.button(name, text, UDim2.fromOffset(height, height), control)
		b.BackgroundColor3 = C.panelLight
		b.TextSize = HudTheme.TextSize.body
		return b
	end
	local prev = arrow("Prev", "<")
	local nextButton = arrow("Next", ">")
	nextButton.AnchorPoint = Vector2.new(1, 0)
	nextButton.Position = UDim2.fromScale(1, 0)

	local value = HudTheme.label(
		"Value",
		"",
		UDim2.new(1, -2 * (height + 6), 1, 0),
		HudTheme.HeaderFont,
		HudTheme.TextSize.body,
		control
	)
	value.Position = UDim2.fromOffset(height + 6, 0)
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.TextColor3 = C.text

	local pending: string? = nil
	local token = 0
	local connections: { RBXScriptConnection } = {}

	local function refresh()
		local current = pending
			or (player:GetAttribute(Cosmetics.attribute(slot)) :: string?)
			or Cosmetics.default(slot)
		local option = if current then Cosmetics.option(slot, current) else nil
		value.Text = if option then option.name else "-"
		value.TextColor3 = if pending then C.textDim else C.text
		local many = #Cosmetics.ownedOptions(slot, owns) > 1
		prev.Active = many
		nextButton.Active = many
		prev.AutoButtonColor = many
		nextButton.AutoButtonColor = many
		prev.TextColor3 = if many then C.text else C.textDim
		nextButton.TextColor3 = if many then C.text else C.textDim
	end

	local function step(dir: number)
		local current = pending
			or (player:GetAttribute(Cosmetics.attribute(slot)) :: string?)
			or Cosmetics.default(slot)
		local id = Cosmetics.cycle(slot, current, owns, dir)
		local remote = equipRemote()
		if not id or id == current or not remote then
			return
		end
		token += 1
		local mine = token
		pending = id
		refresh()
		task.spawn(function()
			pcall(function()
				remote:InvokeServer(slot, id)
			end)
			if token == mine then
				pending = nil
				refresh()
			end
		end)
		task.delay(EQUIP_TIMEOUT, function()
			if token == mine and pending then
				pending = nil
				refresh()
			end
		end)
	end

	prev.Activated:Connect(function()
		step(-1)
	end)
	nextButton.Activated:Connect(function()
		step(1)
	end)
	table.insert(
		connections,
		player:GetAttributeChangedSignal(Cosmetics.attribute(slot)):Connect(function()
			if not pending then
				refresh()
			end
		end)
	)
	for _, pass in Cosmetics.passesForSlot(slot) do
		table.insert(
			connections,
			player:GetAttributeChangedSignal("Pass_" .. pass):Connect(refresh)
		)
	end
	refresh()

	return {
		frame = row,
		first = prev,
		refresh = refresh,
		destroy = function()
			token += 1
			for _, c in connections do
				c:Disconnect()
			end
			row:Destroy()
		end,
	}
end

return CosmeticPicker
