--!strict
-- BoatCard: one craft's kit card for the dock boards: a look on your boat (docs/30: no stats here, levels live at the
-- Upgrade Station). Own it through the ladder or its pass, then launch it at your berth.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BoatBuilder = require(Shared:WaitForChild("Boat"):WaitForChild("Builder"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local MonetizationEffects = require(Shared:WaitForChild("MonetizationEffects"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))
local VehicleConfig = require(Config:WaitForChild("VehicleConfig"))

local BoatReveal = require(script.Parent:WaitForChild("BoatReveal"))
local Kit = script.Parent:WaitForChild("Kit")
local Layout = require(script.Parent:WaitForChild("Layout"))
local Panel = require(Kit:WaitForChild("Panel"))
local PriceButton = require(Kit:WaitForChild("PriceButton"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local S = Theme.Size
local QUICK = "QuickLaunch"
local BoatCard = {}

local function ownsQuick(): boolean
	local ends = player:GetAttribute("DayPass_" .. QUICK)
	return MonetizationEffects.passActive(
		player:GetAttribute("Pass_" .. QUICK) == true,
		if type(ends) == "number" then ends else nil,
		Workspace:GetServerTimeNow()
	)
end

-- The same preview the old Vehicles app showed: the published prop, else anyone's live craft, else
-- the shared builder's greybox.
local function previewModel(id: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	local source = folder and folder:FindFirstChild(id)
	if not source then
		local live = Workspace:FindFirstChild("Vehicles")
		if live then
			for _, m in live:GetChildren() do
				if m:IsA("Model") and m:GetAttribute("VehicleId") == id then
					source = m
					break
				end
			end
		end
	end
	local model: Model? = if source and source:IsA("Model") then source:Clone() else nil
	if not model then
		local spec = VehicleConfig.get(id)
		if spec then
			local ok, built = pcall(function(): Model?
				return BoatBuilder.build(spec)
			end)
			model = if ok then built else nil
		end
	end
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
	end
	return model
end

local function visibleBounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local half = d.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p = d.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
						lo, hi = lo:Min(p), hi:Max(p)
					end
				end
			end
		end
	end
	if lo.X > hi.X then
		local cf, size = model:GetBoundingBox()
		return cf.Position, size
	end
	return (lo + hi) / 2, hi - lo
end

local function passKey(id: string): string?
	return Rules.vehiclePass(id)
end

local function ownsPass(id: string): boolean
	local key = passKey(id)
	return key ~= nil and player:GetAttribute("Pass_" .. key) == true
end

-- the craft's 3D portrait in a rounded well (BoatCard hero, Panels/Board cards); size and place it
function BoatCard.preview(parent: Instance, id: string): ViewportFrame
	local art = Instance.new("ViewportFrame")
	art.Name = "Preview"
	art.BackgroundColor3 = Color3.fromRGB(214, 233, 247)
	art.BackgroundTransparency = 0.15
	art.Ambient = Color3.fromRGB(135, 145, 160)
	art.LightColor = Color3.fromRGB(255, 244, 226)
	art.LightDirection = Vector3.new(-0.6, -1, -0.5)
	Style.corner(art, S.cornerSmall)
	art.Parent = parent
	local model = previewModel(id)
	if model then
		local centre, size = visibleBounds(model)
		model.Parent = art
		local camera = Instance.new("Camera")
		camera.FieldOfView = 28
		camera.Parent = art
		art.CurrentCamera = camera
		local dist = math.max(size.X, size.Y, size.Z) * 1.7
		camera.CFrame = CFrame.lookAt(centre + Vector3.new(dist * 0.8, dist * 0.45, dist), centre)
	else
		Style.icon(art, "boat_to_me")
	end
	return art
end

function BoatCard.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Boat",
		icon = "boat_to_me",
		size = Vector2.new(760, 560),
		onClose = onClose,
	})
	local id: string? = nil
	local data: Rules.PlayerData? = nil
	local busy = false

	local refresh: () -> ()

	local function buyVehicle()
		local craft = id
		if busy or not craft then
			return
		end
		local d = data
		if not d then
			return
		end
		local ok = Rules.canBuyVehicle(d, craft, ownsPass(craft))
		if not ok then
			return
		end
		busy = true
		task.spawn(function()
			local called, done = pcall(function()
				return Net.func("BuyGear"):InvokeServer(craft)
			end)
			busy = false
			if called and done == true then
				panel.close() -- the moment: the craft builds in at its berth
				BoatReveal.play(craft)
			end
		end)
	end

	local function buyPass(craft: string)
		local key = passKey(craft)
		local item = if key then MonetizationConfig.GamePasses[key] else nil
		local d = data
		-- Robux skips the Cash, never the order (docs/23 (q)): the building comes first
		if not (item and item.ready and item.id > 0) or not d or Rules.vehicleLock(d, craft) then
			return
		end
		Telemetry.shop("BuyTapped", "BoatCard", key, "Robux")
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		end)
	end

	local function launch()
		if busy or not id then
			return
		end
		busy = true
		task.spawn(function()
			local ok, done = pcall(function()
				return Net.func("RequestVehicle"):InvokeServer(id, true)
			end)
			busy = false
			if ok and done then
				panel.close()
			end
		end)
	end

	refresh = function()
		for _, c in panel.body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local craft = id
		local spec = if craft then VehicleConfig.get(craft) else nil
		if not (craft and spec) then
			return
		end
		local d = data
		local owned = d ~= nil
			and Rules.ownsVehicle(d, craft, ownsPass(craft) or Rules.wonLook(d, craft))
		local unlock = ProgressionConfig.Vehicles[craft]
		local need = if d
				and not owned
				and not (unlock and unlock.level)
			then Rules.vehicleLock(d, craft)
			else nil
		local order = 0

		local hero = Instance.new("Frame")
		hero.LayoutOrder = order
		hero.Size = UDim2.new(1, 0, 0, 150)
		hero.BackgroundTransparency = 1
		hero.Parent = panel.body
		local _, face = Style.block(hero, Style.grad(if owned then "green" else "blue"))
		local art = BoatCard.preview(face, craft)
		art.Position = UDim2.fromOffset(14, 14)
		art.Size = UDim2.fromOffset(122, 122)
		local boatName = Style.label(face, spec.displayName, Theme.Text.title)
		boatName.Position = UDim2.fromOffset(154, 12)
		boatName.Size = UDim2.new(1, -170, 0, 56)
		boatName.TextXAlignment = Enum.TextXAlignment.Left
		local tag = Style.label(
			face,
			if owned
				then "Owned"
				elseif unlock and unlock.level then `Lv {unlock.level}`
				elseif need then `Needs: {UnlockTree.needName(need)}`
				else if unlock and unlock.price > 0
					then `{Theme.short(unlock.price)} Cash`
					else "Locked",
			Theme.Text.small
		)
		tag.Position = UDim2.fromOffset(154, 70)
		tag.Size = UDim2.new(1, -170, 0, 32)
		tag.TextXAlignment = Enum.TextXAlignment.Left
		local quickItem = MonetizationConfig.GamePasses[QUICK]
		if
			quickItem
			and quickItem.ready
			and quickItem.id > 0
			and not ownsQuick()
			and not Layout.quietHud()
		then
			local chip = Style.button(face, UDim2.fromOffset(190, 38)) :: any
			chip.Name = "QuickLaunchChip"
			chip.AnchorPoint = Vector2.new(0, 1)
			chip.Position = UDim2.new(0, 154, 1, -10)
			local _, chipFace = Style.block(chip, Style.grad("yellow"), { lip = 4 })
			local label = Style.label(chipFace, "Quick Launch", Theme.Text.small, true)
			label.TextWrapped = false
			Style.press(chip, function()
				Telemetry.shop("BuyTapped", "Chip", QUICK, "Robux")
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, quickItem.id)
				end)
			end, S.cornerSmall)
		end
		if not owned then
			local buy = PriceButton.new(face, {
				price = if unlock then unlock.price else 0,
				currency = "Cash",
				state = if need then "disabled" else nil,
				onActivate = buyVehicle,
			})
			-- docs/30: the ladder gives these hulls; only Robux still buys one early, as a look
			buy.root.Visible = not (unlock and unlock.level)
			buy.root.AnchorPoint = Vector2.new(1, 0.5)
			buy.root.Position = UDim2.new(1, -14, 0.5, -34)
			local key = passKey(craft)
			local item = if key then MonetizationConfig.GamePasses[key] else nil
			local robux = PriceButton.new(face, {
				price = 0,
				currency = "Robux",
				state = if need then "disabled" else nil,
				onActivate = function()
					buyPass(craft)
				end,
			})
			robux.root.AnchorPoint = Vector2.new(1, 0.5)
			robux.root.Position = UDim2.new(1, -14, 0.5, 38)
			robux.root.Visible = item ~= nil and item.ready == true
			if item and item.ready then
				task.spawn(function()
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(item.id, Enum.InfoType.GamePass)
					end)
					if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
						robux.setPrice(info.PriceInRobux)
					end
				end)
			end
		else
			local go = Style.button(face, UDim2.fromOffset(190, 70))
			go.AnchorPoint = Vector2.new(1, 0.5)
			go.Position = UDim2.new(1, -16, 0.5, 0)
			local _, gFace = Style.block(go, Style.grad("buy"), { studs = true })
			Style.label(gFace, "Launch", Theme.Text.button)
			Style.press(go, launch)
		end
	end

	local function onData(raw: any)
		if type(raw) == "table" then
			data = Rules.fromSnapshot(raw)
			if panel.isOpen() then
				refresh()
			end
		end
	end
	Net.event("PlayerDataChanged").OnClientEvent:Connect(onData)
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
		setId = function(value: string)
			id = value
			if panel.isOpen() then
				refresh()
			end
		end,
		open = function()
			panel.open()
			refresh()
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return BoatCard
