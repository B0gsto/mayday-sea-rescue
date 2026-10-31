--!strict
-- Board panel: a craft board's list (server/Dock/BoatBoard; opened by its one BoardOpen prompt through
-- BoatBoardController -> Menu.openBoard). A card per craft on that rack: its 3D portrait, name and state.
--   owned        green card, "Owned" (or "Equipped": the craft Launch and Boat to me bring), green Launch
--                button: Net BoardLaunch (the crane beat, then you in its seat); the panel closes
--   needs X      grey card, padlock, "Needs: <building>" line, buttons greyed (Robux never skips the order)
--   buyable      Cash price (grey when short) and the Robux pass price
-- Tapping a portrait opens that craft's BoatCard (stats, upgrades).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BayLaunch = require(Shared:WaitForChild("Boat"):WaitForChild("BayLaunch"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))
local VehicleConfig = require(Config:WaitForChild("VehicleConfig"))

local UI = script.Parent.Parent
local BoatCard = require(UI:WaitForChild("BoatCard"))
local Kit = UI:WaitForChild("Kit")
local Card = require(Kit:WaitForChild("Card"))
local Panel = require(Kit:WaitForChild("Panel"))
local PriceButton = require(Kit:WaitForChild("PriceButton"))
local Style = require(Kit:WaitForChild("Style"))
local Telemetry = require(UI.Parent:WaitForChild("Telemetry"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local S = Theme.Size
local prices: { [number]: number } = {} -- pass id -> Robux
local STACK = 0.58 -- price button scale when Cash and Robux stack (two fit a compact 96 card)

local Board = {}

local function passItem(id: string): any
	local key = Rules.vehiclePass(id)
	local item = if key then MonetizationConfig.GamePasses[key] else nil
	return if item and item.ready and item.id > 0 then item else nil
end

local function ownsPass(id: string): boolean
	local key = Rules.vehiclePass(id)
	return key ~= nil and player:GetAttribute("Pass_" .. key) == true
end

-- boardName: the rack's name (BoatBoard / HangarBoard / SubBoard); openBoat: Menu.openBoat
function Board.new(
	canvas: Frame,
	onClose: () -> (),
	boardName: string,
	title: string,
	openBoat: (string) -> ()
)
	local panel = Panel.new(canvas, {
		title = title,
		icon = "boat_to_me",
		size = Vector2.new(760, 560),
		onClose = onClose,
	})
	local rack: Instance? = nil
	local data: Rules.PlayerData? = nil
	local last: any = nil -- flags.lastVehicle: the craft the berth's Launch brings (VehicleService bayCraft)
	local busy = false
	local refresh: () -> ()

	local function launch(id: string)
		Net.event("BoardLaunch"):FireServer(boardName, id)
		panel.close()
	end

	local function buyCash(id: string)
		local d = data
		if busy or not (d and Rules.canBuyVehicle(d, id, ownsPass(id))) then
			return
		end
		busy = true
		Telemetry.shop("BuyTapped", "Board", id, "Cash")
		task.spawn(function()
			pcall(function()
				return Net.func("BuyGear"):InvokeServer(id)
			end)
			busy = false
			refresh()
		end)
	end

	local function card(id: string, order: number)
		local spec = VehicleConfig.get(id)
		if not spec then
			return -- not built yet: only its grey shape on the rack
		end
		local d = data
		local unlock = ProgressionConfig.Vehicles[id]
		local have = d ~= nil and (Rules.canUseVehicle(d, id, ownsPass(id)))
		local need = if d and not have then Rules.vehicleLock(d, id) else nil
		local cashOk = d ~= nil and not have and (Rules.canBuyVehicle(d, id, ownsPass(id)))
		local equipped = have
			and d ~= nil
			and BayLaunch.pick(last, VehicleConfig.Order, function(v)
					return (Rules.canUseVehicle(d, v, ownsPass(v)))
				end)
				== id
		local c = Card.new(panel.body, {
			art = "boat_to_me",
			title = spec.displayName,
			line = if equipped then "Equipped" elseif have then "Owned" else nil,
			color = if equipped then "yellow" elseif have then "green" else "blue",
			price = if unlock then unlock.price else 0,
			currency = "Cash",
			state = if have or cashOk then "buy" elseif need then "locked" else "disabled",
			onBuy = function()
				if have then
					launch(id)
				else
					buyCash(id)
				end
			end,
		})
		c.root.Name = "Board_" .. id
		c.root.LayoutOrder = order
		if have then
			c.price.setText("Launch")
			local coin = c.price.root:FindFirstChild("Glyph", true) :: GuiObject?
			if coin then
				coin.Visible = false -- Launch costs nothing
			end
		elseif need then
			c.setLine(`Needs: {UnlockTree.needName(need)}`)
		end
		c.price.root.Visible = have or not (unlock and unlock.passOnly)
		if not (have or c.price.root.Visible or passItem(id)) then
			c.setState("locked") -- a prize-only craft (pass off sale): padlock, never a card with no button
		end

		-- the portrait over the icon; tap: the craft's own card
		for _, ch in c.art:GetChildren() do
			if ch.Name ~= "Lock" and not ch:IsA("UICorner") then
				ch:Destroy()
			end
		end
		BoatCard.preview(c.art, id).Size = UDim2.fromScale(1, 1)
		-- after the price button in the face, so a gamepad lands on Launch / Buy first
		local more = Style.button(c.price.root.Parent, c.art.Size)
		more.Name = "Details"
		more.AnchorPoint, more.Position = c.art.AnchorPoint, c.art.Position
		more.ZIndex = 3
		Style.press(more, function()
			openBoat(id)
		end, S.cornerSmall)

		local item = if have then nil else passItem(id)
		if item then
			local robux = PriceButton.new(c.price.root.Parent, {
				price = prices[item.id] or 0,
				currency = "Robux",
				state = if need then "disabled" else nil,
				onActivate = function()
					local dd = data
					if dd and not Rules.vehicleLock(dd, id) then
						pcall(function()
							MarketplaceService:PromptGamePassPurchase(player, item.id)
						end)
					end
				end,
			})
			robux.root.AnchorPoint = Vector2.new(1, 0.5)
			robux.root.Position = UDim2.new(1, -12, 0.5, 0)
			if c.price.root.Visible then
				-- Cash over Robux, both smaller: side by side they squeezed the name ("All-Weath er", playtest 2026-10-26)
				for i, btn in { c.price.root, robux.root } do
					-- a holder takes the UIScale: the button's own is its hover / press bounce (one UIScale counts)
					local box = Instance.new("Frame")
					box.Name = "PriceSlot"
					box.BackgroundTransparency = 1
					box.Size = UDim2.fromOffset(S.price.X, S.price.Y)
					box.AnchorPoint = Vector2.new(1, if i == 1 then 1 else 0)
					box.Position = UDim2.new(1, -12, 0.5, if i == 1 then -2 else 2)
					local scale = Instance.new("UIScale")
					scale.Scale = STACK
					scale.Parent = box
					box.Parent = btn.Parent
					btn.AnchorPoint, btn.Position = Vector2.zero, UDim2.new()
					btn.Parent = box
				end
				local words = c.root:FindFirstChild("Words", true) :: Frame?
				if words then
					words.Size += UDim2.fromOffset(S.price.X * (1 - STACK), 0)
				end
			end
			if not prices[item.id] then
				task.spawn(function()
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(item.id, Enum.InfoType.GamePass)
					end)
					if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
						prices[item.id] = info.PriceInRobux
						robux.setPrice(info.PriceInRobux)
					end
				end)
			end
		end
	end

	refresh = function()
		for _, ch in panel.body:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local list = rack and rack:GetAttribute("Vehicles")
		if type(list) ~= "string" then
			return
		end
		for i, id in string.split(list, ",") do
			card(id, i)
		end
	end

	local function onData(raw: any)
		if type(raw) == "table" then
			data = Rules.fromSnapshot(raw)
			last = if type(raw.flags) == "table" then raw.flags[BayLaunch.FLAG] else nil
			if panel.isOpen() then
				refresh()
			end
		end
	end
	Net.event("PlayerDataChanged").OnClientEvent:Connect(onData)
	player.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 5) == "Pass_" and panel.isOpen() then
			refresh()
		end
	end)
	task.spawn(function()
		local remote = Net.init():WaitForChild("Progression_GetData", 10)
		if remote and remote:IsA("RemoteFunction") then
			local ok, raw = pcall(function()
				return remote:InvokeServer()
			end)
			if ok then
				onData(raw)
			end
		end
	end)

	return {
		setRack = function(value: Instance)
			rack = value
		end,
		open = function()
			panel.body.CanvasPosition = Vector2.zero
			panel.open()
			refresh()
			Telemetry.shop("PanelOpened", "Board")
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Board
