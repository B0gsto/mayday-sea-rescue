--!strict
-- CosmeticPicker: one kit row that cycles a cosmetic slot through the options the player may
-- equip. Used by Settings (owned items) and the dock's boat booth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticLoadout =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticLoadout"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Cosmetics"))

local Kit = script.Parent:WaitForChild("Kit")
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local S = Theme.Size
local player = Players.LocalPlayer
local EQUIP_TIMEOUT = 8

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

local CosmeticPicker = {}

local ownedRaw = ""
local ownedSet: { [string]: boolean } = {}

local function owns(key: string): boolean
	if player:GetAttribute("Pass_" .. key) == true then
		return true
	end
	local raw = player:GetAttribute("CosOwned")
	if type(raw) ~= "string" then
		return false
	end
	if raw ~= ownedRaw then
		ownedRaw = raw
		ownedSet = CosmeticLoadout.decode(raw)
	end
	return ownedSet[key] == true
end

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
	local height = o.height or 76
	local labelW = o.labelWidth or 0.42

	local row = Instance.new("Frame")
	row.Name = "Cosmetic_" .. slot
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.LayoutOrder = o.layoutOrder or 0
	row.Parent = parent
	local holder, face = Style.block(row, Style.grad("body"), { lip = 5, radius = S.cornerSmall })
	holder.Name = "Row"

	local label =
		Style.label(face, o.label or CosmeticPicker.slotLabel(slot), Theme.Text.body, true)
	label.Position = UDim2.fromOffset(14, 0)
	label.Size = UDim2.new(labelW, -18, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd

	local prev = Style.button(face, UDim2.fromOffset(64, height - 14))
	prev.AnchorPoint = Vector2.new(0, 0.5)
	prev.Position = UDim2.fromScale(labelW, 0.5)
	local _, lFace = Style.block(prev, Style.grad("blue"), { lip = 4, radius = S.cornerSmall })
	Style.label(lFace, "<", Theme.Text.button)
	local nextButton = Style.button(face, UDim2.fromOffset(64, height - 14))
	nextButton.AnchorPoint = Vector2.new(1, 0.5)
	nextButton.Position = UDim2.new(1, -10, 0.5, 0)
	local _, rFace =
		Style.block(nextButton, Style.grad("blue"), { lip = 4, radius = S.cornerSmall })
	Style.label(rFace, ">", Theme.Text.button)
	local value = Style.label(face, "", Theme.Text.small, true)
	value.Position = UDim2.new(labelW, 70, 0, 0)
	value.Size = UDim2.new(1 - labelW, -150, 1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Center
	value.TextWrapped = false
	value.TextTruncate = Enum.TextTruncate.AtEnd

	local pending: string? = nil
	local token = 0
	local connections: { RBXScriptConnection } = {}

	local function refresh()
		local current = pending
			or (player:GetAttribute(Cosmetics.attribute(slot)) :: string?)
			or Cosmetics.default(slot)
		local option = if current then Cosmetics.option(slot, current) else nil
		value.Text = if option then option.name else "-"
		value.TextColor3 = if pending then Theme.Colors.textDark else Theme.Colors.textDark
		local many = #Cosmetics.ownedOptions(slot, owns) > 1
		prev.Active = many
		nextButton.Active = many
		prev.ImageTransparency = if many then 0 else 0.4
		nextButton.ImageTransparency = if many then 0 else 0.4
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

	Style.press(prev, function()
		step(-1)
	end, S.cornerSmall)
	Style.press(nextButton, function()
		step(1)
	end, S.cornerSmall)
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
	table.insert(connections, player:GetAttributeChangedSignal("CosOwned"):Connect(refresh))
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
