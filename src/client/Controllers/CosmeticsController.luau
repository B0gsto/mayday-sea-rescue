--!strict
-- CosmeticsController (RP-M5 spine): the client side of cosmetics. Loads every ModuleScript in
-- src/client/Cosmetics/ (StarterPlayerScripts.Client.Cosmetics) and calls its `Start(ctx)` in its own
-- thread (optional `Priority`, lower first, then by name). Add files there; no other wiring needed.
--
-- ctx (CosmeticsController.ctx, also passed to Start):
--   ctx.player                                    the local player
--   ctx.Cosmetics                                 the shared registry (src/shared/Cosmetics)
--   ctx.fire(action, ...)                         Cosmetics_Action to the server (rate limited there)
--   ctx.onEvent(name, fn(...)) -> disconnect()    Cosmetics_Event from the server, by name
--   ctx.equipped(player, slot): string            that player's "Cos_<Slot>" (default when unset)
--   ctx.onEquipped(player, slot, fn(id)) -> RBXScriptConnection   fires on change (not now)
--   ctx.owns(key): boolean                        the local player's "Pass_<Key>" or earned
--                                                 "CosOwned" flag key (src/shared/CosmeticLoadout)
--   ctx.muted(kind): boolean                      kind "Horns" | "Sirens" | "Radios": the local
--                                                 player muted OTHER players' sounds of that kind
--   ctx.currentVehicle(): (Model?, kind?)         the vehicle the local player is seated in;
--                                                 kind "Boat" | "JetSki"
--   ctx.kindOf(model): kind?
--   ctx.bindVehicleAction{ name, label, key?, gamepad?, callback(), visible?() -> boolean }
--       -> unbind()   While the local player is seated in a vehicle and visible() is true: binds
--       key + gamepad through ContextActionService and, on touch screens, shows a small HudTheme
--       tap button stacked left of the "gauges" region (touch: of the drive pad). callback runs on press (Begin).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local CosmeticLoadout = require(Shared:WaitForChild("CosmeticLoadout"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Layout = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Layout"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local player = Players.LocalPlayer

export type VehicleAction = {
	name: string,
	label: string,
	key: Enum.KeyCode?,
	gamepad: Enum.KeyCode?,
	callback: () -> (),
	visible: (() -> boolean)?,
}

local CosmeticsController = {}
CosmeticsController.Priority = 110 -- after the vehicle and audio controllers

local MUTE_KEYS = { Horns = "muteHorns", Sirens = "muteSirens", Radios = "muteRadios" }
local BUTTON = 52 -- du (HudTheme.MinButtonHeight)
local POLL = 0.25

local actionRemote: RemoteEvent? = nil
local listeners: { [string]: { (...any) -> () } } = {}

type Binding = { spec: VehicleAction, bound: boolean, button: TextButton? }
local bindings: { Binding } = {}
local stack: Frame? = nil

local function kindOf(model: Instance?): string?
	if not model or not model:IsA("Model") then
		return nil
	end
	local id = model:GetAttribute("VehicleId")
	if VehicleConfig.isJetSki(id) then
		return "JetSki"
	elseif type(id) == "string" then
		return "Boat"
	end
	return nil
end

local function currentVehicle(): (Model?, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local node: Instance? = humanoid and humanoid.SeatPart
	while node and node ~= workspace do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node, kindOf(node)
		end
		node = node.Parent
	end
	return nil, nil
end

---------------------------------------------------------------- vehicle action buttons

local function ensureStack(): Frame
	if stack then
		return stack
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CosmeticActions"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	-- driving on touch the drive pad fills the bottom-right corner: stack left of it instead
	local region = Layout.region(gui, if Layout.device() == "Touch" then "drive" else "gauges")
	local f = Instance.new("Frame")
	f.Name = "Stack"
	f.AnchorPoint = Vector2.new(1, 1)
	f.Position = UDim2.new(0, -Layout.GAP, 1, 0)
	f.Size = UDim2.new(0, BUTTON, 1, 0)
	f.BackgroundTransparency = 1
	f.Parent = region
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = f
	Layout.onColdOpen(function(active: boolean)
		f.Visible = not active
	end)
	stack = f
	return f
end

local function actionName(spec: VehicleAction): string
	return "Cosmetic_" .. spec.name
end

local function setBound(b: Binding, on: boolean)
	if b.bound == on then
		return
	end
	b.bound = on
	local spec = b.spec
	if on then
		local keys = {}
		if spec.key then
			table.insert(keys, spec.key)
		end
		if spec.gamepad then
			table.insert(keys, spec.gamepad)
		end
		if #keys > 0 then
			ContextActionService:BindAction(
				actionName(spec),
				function(_: string, state: Enum.UserInputState): Enum.ContextActionResult
					if state == Enum.UserInputState.Begin then
						task.spawn(spec.callback)
					end
					return Enum.ContextActionResult.Sink
				end,
				false,
				table.unpack(keys)
			)
		end
	else
		ContextActionService:UnbindAction(actionName(spec))
	end
	if UserInputService.TouchEnabled then
		if on and not b.button then
			local button = HudTheme.button(
				actionName(spec),
				spec.label,
				UDim2.fromOffset(BUTTON, BUTTON),
				ensureStack()
			)
			button.BackgroundColor3 = HudTheme.Colors.panel
			button.BackgroundTransparency = HudTheme.PanelTransparency
			button.TextSize = HudTheme.TextSize.small
			button.TextWrapped = true
			button.Selectable = false
			button.LayoutOrder = table.find(bindings, b) or 0
			button.Activated:Connect(function()
				task.spawn(spec.callback)
			end)
			b.button = button
		end
		if b.button then
			b.button.Visible = on
		end
	end
end

local function evaluate()
	local seated = currentVehicle() ~= nil
	for _, b in bindings do
		local want = seated
		if want and b.spec.visible then
			local ok, v = pcall(b.spec.visible)
			want = ok and v == true
		end
		setBound(b, want)
	end
end

local function bindVehicleAction(spec: VehicleAction): () -> ()
	assert(type(spec.name) == "string" and type(spec.callback) == "function", "bindVehicleAction")
	local b: Binding = { spec = spec, bound = false, button = nil }
	table.insert(bindings, b)
	evaluate()
	return function()
		setBound(b, false)
		if b.button then
			b.button:Destroy()
			b.button = nil
		end
		local i = table.find(bindings, b)
		if i then
			table.remove(bindings, i)
		end
	end
end

---------------------------------------------------------------- ctx

local ctx = {
	player = player,
	Cosmetics = Cosmetics,
	kindOf = kindOf,
	currentVehicle = currentVehicle,
	bindVehicleAction = bindVehicleAction,
}

function ctx.fire(action: string, ...: any)
	if actionRemote then
		actionRemote:FireServer(action, ...)
	end
end

function ctx.onEvent(name: string, fn: (...any) -> ()): () -> ()
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, fn)
	return function()
		local l = listeners[name]
		local i = l and table.find(l, fn)
		if l and i then
			table.remove(l, i)
		end
	end
end

function ctx.equipped(who: Player, slot: string): string
	local v = who:GetAttribute(Cosmetics.attribute(slot))
	if type(v) == "string" then
		return v
	end
	return Cosmetics.default(slot) or ""
end

function ctx.onEquipped(who: Player, slot: string, fn: (string) -> ()): RBXScriptConnection
	return who:GetAttributeChangedSignal(Cosmetics.attribute(slot)):Connect(function()
		fn(ctx.equipped(who, slot))
	end)
end

local ownedRaw = ""
local ownedSet: { [string]: boolean } = {}

function ctx.owns(key: string): boolean
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

function ctx.muted(kind: string): boolean
	local key = MUTE_KEYS[kind]
	return key ~= nil and Comfort.get(key) == true
end

CosmeticsController.ctx = ctx

---------------------------------------------------------------- lifecycle

function CosmeticsController.Init() end

function CosmeticsController.Start()
	local net = ReplicatedStorage:WaitForChild("Net")
	actionRemote = net:WaitForChild("Cosmetics_Action", 30) :: RemoteEvent?
	local eventRemote = net:WaitForChild("Cosmetics_Event", 30) :: RemoteEvent?
	if eventRemote then
		eventRemote.OnClientEvent:Connect(function(name: any, ...: any)
			local list = if type(name) == "string" then listeners[name] else nil
			if list then
				for _, fn in table.clone(list) do
					task.spawn(fn, ...)
				end
			end
		end)
	else
		warn("[CosmeticsController] Cosmetics remotes missing (CosmeticsService not running?)")
	end

	local folder = script.Parent.Parent:FindFirstChild("Cosmetics")
	local features: { { name: string, module: any, priority: number } } = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("ModuleScript") then
				local ok, module = pcall(require :: any, child)
				if ok and type(module) == "table" then
					table.insert(
						features,
						{ name = child.Name, module = module, priority = module.Priority or 100 }
					)
				else
					warn(`[CosmeticsController] {child.Name} failed to load: {module}`)
				end
			end
		end
	end
	table.sort(features, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.name < b.name
	end)
	for _, f in features do
		if f.module.Start then
			task.spawn(function()
				local ok, err = xpcall(f.module.Start, debug.traceback, ctx)
				if not ok then
					warn(`[CosmeticsController] {f.name}.Start failed: {err}`)
				end
			end)
		end
	end

	while true do
		evaluate()
		task.wait(POLL)
	end
end

return CosmeticsController
