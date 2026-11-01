--!strict
-- PurchaseFxController (mon REVIEW #3): the payoff when a Robux purchase lands (MonetizationService fires
-- Monetization_Purchased {kind, key, name} after a pass purchase or a committed product grant). Job: spectacle
-- (reward), ~2 s:
--   anticipation  the item's card (its store icon on a white-rimmed sticker tile + its name) spins in mid-screen over
--                 a gold sunburst; a pop
--   impact        a Lego coin / brick burst round you (VFX fx1_purchase: ka-ching, coins, chime) and a fanfare; a
--                 pass gets its "ON" stamp slammed onto the card (shown this once, at the purchase)
--   settle        the card arcs into where the item lives: the wallet (Cash, 2x Cash, boosts), the Boat button
--                 (Quick Launch), the Crew button (Crew Boost), or the boat's model on your board (a boat pass,
--                 else the Boat button); the target squashes with a ding and stars
-- Not here: island buildings (the Lego build plays), spins (the wheel), Finish now (the build), crew hire.
-- Reduce motion: no spin-in, rays, stars or camera punch; the card holds and fades.
-- It waits for Roblox's purchase dialog to close (in-game AD 2026-11-01: it played under the dialog); a purchase's
-- Cash stays off the wallet (HudController) until the card lands (PurchaseLanded).
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local RewardPop = require(UI:WaitForChild("RewardPop"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local PurchaseFxController = {}

local player = Players.LocalPlayer
local CARD = 0.48 -- the card's height as a share of the screen (AD 2026-11-01: 0.24 read small)
local DIALOG_WAIT = 15 -- s at most for Roblox's purchase dialog to close (a receipt granted on join has none)
local INK = Color3.fromHex("14121C")
local GOLD = Color3.fromHex("FFD86A")
local NAVY = Color3.fromHex("1D3B78")

-- the item's store icon into `art` (a kit icon stands in until it loads, or if it has none)
local function fillIcon(art: Frame, kind: string, item: any, corner: number)
	local stand = Style.icon(art, "shop")
	stand.ZIndex = 3
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(
				item.id,
				if kind == "GamePasses" then Enum.InfoType.GamePass else Enum.InfoType.Product
			)
		end)
		local id = if ok and type(info) == "table" then info.IconImageAssetId else nil
		if type(id) == "number" and id > 0 and art.Parent then
			stand:Destroy()
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = `rbxassetid://{id}`
			img.ScaleType = Enum.ScaleType.Fit
			img.ZIndex = 3
			Style.corner(img, corner)
			img.Parent = art
		end
	end)
end

local function shown(g: Instance?): GuiObject?
	return if g and g:IsA("GuiObject") and g.AbsoluteSize.X > 0 and g.Visible then g else nil
end

local function menuButton(playerGui: Instance, name: string): GuiObject?
	local menu = playerGui:FindFirstChild("Menu")
	local b = menu and menu:FindFirstChild("Menu_" .. name, true)
	return shown(b and (b:FindFirstChild("Tile") or b))
end

-- where the item lives: a screen point, and the GuiObject to squash there (nil: a world spot)
local function targetFor(playerGui: Instance, key: string, item: any): (Vector2?, GuiObject?)
	local boat = menuButton(playerGui, "Boat")
	if item.vehicle then
		local camera = Workspace.CurrentCamera
		for _, rack in CollectionService:GetTagged("BoatBoard") do
			if rack:GetAttribute("Owner") == player.UserId and camera then
				for _, pad in rack:GetChildren() do
					if pad:IsA("BasePart") and pad:GetAttribute("VehicleId") == item.vehicle then
						local p, on =
							camera:WorldToViewportPoint(pad.Position + Vector3.new(0, 1.5, 0))
						if on then
							return Vector2.new(p.X, p.Y), nil
						end
					end
				end
			end
		end
	end
	local target = if item.vehicle
			or key == "QuickLaunch"
			or item.dayPassFor == "QuickLaunch"
		then boat
		elseif key == "CrewBoost" then menuButton(playerGui, "Crew")
		else nil
	if not target then
		local hud = playerGui:FindFirstChild("Hud")
		local wallet = hud and hud:FindFirstChild("Wallet", true)
		target = shown(wallet and (wallet:FindFirstChild("Coin", true) or wallet))
	end
	return if target then target.AbsolutePosition + target.AbsoluteSize / 2 else nil, target
end

-- the sticker card: a white rim, a hard dark outline, a navy-to-blue face, the icon and a 1-3 word name
local function card(parent: Instance, size: number, kind: string, item: any): (Frame, UIScale)
	local holder = Instance.new("Frame")
	holder.Name = "PurchaseCard"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size * 0.86, size)
	holder.BackgroundColor3 = Color3.new(1, 1, 1) -- the rim
	holder.ZIndex = 2
	Style.corner(holder, math.floor(size * 0.12))
	local edge = Instance.new("UIStroke")
	edge.Thickness = math.max(3, size * 0.022)
	edge.Color = INK
	edge.Parent = holder
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.new(1, -size * 0.07, 1, -size * 0.07)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.ZIndex = 2
	Style.corner(face, math.floor(size * 0.09))
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromHex("3F7FE0"), NAVY)
	grad.Rotation = 90
	grad.Parent = face
	face.Parent = holder
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.fromScale(0.5, 0.06)
	art.Size = UDim2.fromScale(0.8, 0.66)
	art.ZIndex = 3
	art.Parent = face
	Instance.new("UIAspectRatioConstraint").Parent = art
	fillIcon(art, kind, item, math.floor(size * 0.06))
	local name = Style.label(face, item.name, math.floor(size * 0.11))
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.97)
	name.Size = UDim2.fromScale(0.92, 0.22)
	name.TextScaled = true
	name.ZIndex = 4
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	holder.Parent = parent
	return holder, scale
end

-- a pass switches on: a gold "ON" stamp slams onto the card's corner, tilted, with a thud
local function stamp(holder: Frame, size: number, reduced: boolean)
	local s = Instance.new("TextLabel")
	s.Name = "OnStamp"
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.Position = UDim2.fromScale(0.82, 0.14)
	s.Size = UDim2.fromOffset(size * 0.46, size * 0.26)
	s.BackgroundColor3 = GOLD
	s.Text = "ON"
	s.TextScaled = true
	s.TextColor3 = INK
	s.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	s.Rotation = -12
	s.ZIndex = 6
	Style.corner(s, math.floor(size * 0.07))
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Thickness = math.max(3, size * 0.02)
	rim.Color = Color3.new(1, 1, 1)
	rim.Parent = s
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
	pad.Parent = s
	local sc = Instance.new("UIScale")
	sc.Scale = if reduced then 1 else 2.4
	sc.Parent = s
	s.Parent = holder
	AudioController.play("FX_Thud", nil, 0.8, 1.3)
	AudioController.play("FX_Snap", nil, 0.9, 1)
	if not reduced then
		TweenService:Create(
			sc,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 1 }
		):Play()
	end
end

-- the Cash a purchase paid rolls onto the wallet now (HudController holds it until then)
local function landed()
	player:SetAttribute("PurchaseLanded", os.clock())
end

local function play(kind: string, key: string, item: any)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local camera = Workspace.CurrentCamera
	if not (playerGui and camera) then
		return
	end
	local reduced = Comfort.reducedMotion()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PurchaseFx"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45 -- over the open Shop / board panel the purchase came from
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	task.delay(5, gui.Destroy, gui) -- failsafe: never a card parked on screen
	local size = math.floor(camera.ViewportSize.Y * CARD)
	local start = camera.ViewportSize * Vector2.new(0.5, 0.42)
	local holder, grow = card(gui, size, kind, item)
	holder.Position = UDim2.fromOffset(start.X, start.Y)

	-- anticipation: a sunburst swells, the card spins in with an overshoot
	AudioController.play("FX_Pop", nil, 1, 1.05)
	AudioController.play("Music_CrateFanfare", nil, 0.9)
	if not reduced then
		RewardPop.rays(gui, start, size * 3, 1.3)
		grow.Scale = 0.2
		holder.Rotation = -20
		TweenService:Create(grow, TweenInfo.new(0.34, Enum.EasingStyle.Back), { Scale = 1.2 })
			:Play()
		TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Rotation = 0 })
			:Play()
		task.delay(0.36, function()
			if holder.Parent then
				TweenService
					:Create(grow, TweenInfo.new(0.4, Enum.EasingStyle.Sine), { Scale = 1.1 })
					:Play()
			end
		end)
	end
	-- impact: the Lego burst round you (ka-ching inside the preset) and, for a pass, the ON stamp
	task.delay(0.3, function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			VFXKit.play("fx1_purchase", CFrame.new(root.Position), { radius = 3, height = 3 })
		else
			AudioController.play("Shop_Till", nil, 1)
		end
		if not reduced then
			RewardPop.stars(gui, start, size * 0.9, 9)
		end
		if kind == "GamePasses" and holder.Parent then
			task.delay(0.15, stamp, holder, size, reduced)
		end
	end)

	-- settle: the card arcs into where the item lives and that spot squashes
	task.delay(1.35, function()
		local goal, target = targetFor(playerGui, key, item)
		if reduced or not goal then
			landed()
			local fade = TweenService:Create(grow, TweenInfo.new(0.3), { Scale = 0.01 })
			fade.Completed:Once(function()
				gui:Destroy()
			end)
			fade:Play()
			return
		end
		local to = goal :: Vector2
		local lift = start + Vector2.new((to.X - start.X) * 0.35, -size * 0.9)
		local t = Instance.new("NumberValue")
		local scale0 = grow.Scale
		local landing = if target then target.AbsoluteSize.Y / size else 0.15
		t.Changed:Connect(function(k: number)
			local p = start:Lerp(lift, k):Lerp(lift:Lerp(to, k), k)
			holder.Position = UDim2.fromOffset(p.X, p.Y)
			grow.Scale = scale0 + (landing - scale0) * k
			holder.Rotation = 18 * k
		end)
		local fly = TweenService:Create(
			t,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Value = 1 }
		)
		fly.Completed:Once(function()
			holder:Destroy()
			landed()
			AudioController.play("FX_Ding", nil, 0.9, 1.4)
			if target then
				local pop = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
				pop.Parent = target
				pop.Scale = 1.35
				TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 })
					:Play()
			end
			local w = if target then target.AbsoluteSize.X else size * 0.3
			RewardPop.rays(gui, to, w * 3.2, 0.6)
			RewardPop.stars(gui, to, w * 1.4, 8)
			task.delay(0.9, gui.Destroy, gui)
		end)
		fly:Play()
	end)
end

-- bought here, with its own payoff elsewhere: the Lego build, the wheel, the build sign, the crew
local function ownPayoff(key: string, item: any): boolean
	return item.dockBuilding ~= nil
		or item.spins ~= nil
		or item.crewHire == true
		or string.sub(key, 1, 9) == "FinishNow"
end

local queue: { () -> () } = {}
local running = false

-- product / pass id -> os.clock() its Roblox purchase dialog closed
local closedAt: { [number]: number } = {}
local function dialogClosed(_: any, id: number)
	closedAt[id] = os.clock()
end

-- yields until Roblox's dialog for `id` has closed (since `since`, or just before), at most DIALOG_WAIT s
local function awaitDialog(id: any, since: number)
	local deadline = os.clock() + DIALOG_WAIT
	while
		type(id) == "number"
		and not ((closedAt[id] or -math.huge) > since - 5)
		and os.clock() < deadline
	do
		task.wait(0.1)
	end
	task.wait(0.25) -- the dialog's own fade
end

local function onPurchased(payload: any)
	if
		type(payload) ~= "table"
		or type(payload.kind) ~= "string"
		or type(payload.key) ~= "string"
	then
		return
	end
	local kind, key = payload.kind, payload.key
	local list = (MonetizationConfig :: any)[kind]
	local item = if type(list) == "table" then list[key] else nil
	if not item or ownPayoff(key, item) then
		return
	end
	-- one card at a time: a second purchase waits for the first to land
	local at = os.clock()
	table.insert(queue, function()
		awaitDialog(item.id, at)
		play(kind, key, item)
	end)
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local next = table.remove(queue, 1) :: () -> ()
		next()
		task.wait(2.1)
	end
	running = false
end

function PurchaseFxController.Init() end

function PurchaseFxController.Start()
	MarketplaceService.PromptProductPurchaseFinished:Connect(dialogClosed)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(dialogClosed)
	task.spawn(function()
		local remote = Net.init():WaitForChild("Monetization_Purchased", 30)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(onPurchased)
		end
	end)
end

return PurchaseFxController
