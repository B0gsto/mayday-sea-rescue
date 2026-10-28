--!strict
-- CoinShower: the Collect moment (owner, 2026-10-28). The wallet's coins pop in at random spots across the
-- screen (0-0.35 s, overshoot + tilt), bob for a beat, then fly on curves into the wallet's coin one after
-- another, speeding up; each landing ticks (pitch stepping up), pops the wallet coin and rolls the counter.
-- The last one rings the till with one soft gold ring at the wallet. About 2 s. Job: spectacle (reward).
--   CoinShower.play(playerGui, amount, fromPoint?)  fromPoint: screen px the coins spring out of
-- CashHeld (player attribute, read by HudController): Cash already paid but held off the wallet. Each coin
-- releases its share of `amount`, so a caller that held the amount back sees the counter roll in step.
-- Pooled: coin sprites, tick Sounds and the ring live for the session; one Heartbeat drives a shower.
-- Reduce motion: at most 8 coins, no spin or bob, straight flights.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local AudioConfig = require(Config:WaitForChild("AudioConfig"))
local UiImages = require(Config:WaitForChild("UiImages")) :: any

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local OceanQuality =
	require(script.Parent.Parent:WaitForChild("Ocean"):WaitForChild("OceanQuality"))

local CoinShower = {}

local GOLD = Color3.fromHex("FFD86A")
local INK = Color3.fromHex("14121C")
local TICK = "UI_Pickup"
local TICKS = 6 -- pooled tick Sounds, round robin
local CAP = { Low = 12, Medium = 18, High = 24 }
local BURST, HANG, FLIGHT = 0.35, 0.3, 0.38

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local pool: { Frame } = {}
local ticks: { Sound } = {}
local ring: Frame? = nil
local tickAt = 0
local finishNow: (() -> ())? = nil

type Coin = {
	img: Frame,
	spot: Vector2,
	born: number,
	flyAt: number,
	ctrl: Vector2,
	tilt: number,
	spin: number,
	phase: number,
	landed: boolean,
}

local function backOut(t: number): number
	local c = 1.9
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

local function release(cash: number)
	player:SetAttribute("CoinShowerTick", os.clock()) -- HudController: this landing owns the ticks and the pop
	local held = tonumber(player:GetAttribute("CashHeld")) or 0
	if held > 0 and cash > 0 then
		local left = math.max(0, held - cash)
		player:SetAttribute("CashHeld", if left > 0 then left else nil)
	end
end

local function host(playerGui: Instance): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local g = Instance.new("ScreenGui")
	g.Name = "CoinShower"
	g.ResetOnSpawn = false
	g.DisplayOrder = 45
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- the ring's gold layer draws over its dark edge
	-- the same screen space as the HUD, so the wallet coin's AbsolutePosition is ours too
	local hud = playerGui:FindFirstChild("Hud")
	if hud and hud:IsA("ScreenGui") then
		g.IgnoreGuiInset = hud.IgnoreGuiInset
		g.ScreenInsets = hud.ScreenInsets
	end
	g.Parent = playerGui
	gui = g
	for i = 1, TICKS do
		local s = AudioController.newSound(TICK, SoundService, false)
		s.Name = `CoinTick{i}`
		ticks[i] = s
	end
	-- the end ring: a gold stroke over a wider dark one (a sticker edge), no fill
	local r = Instance.new("Frame")
	r.Name = "Ring"
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.BackgroundTransparency = 1
	r.Visible = false
	r.ZIndex = 2
	local function edge(layer: Frame, color: Color3, thickness: number)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = layer
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = thickness
		stroke.Parent = layer
	end
	edge(r, INK, 10)
	local gold = Instance.new("Frame")
	gold.BackgroundTransparency = 1
	gold.Size = UDim2.fromScale(1, 1)
	gold.Parent = r
	edge(gold, GOLD, 5)
	r.Parent = g
	ring = r
	return g
end

-- A wallet coin as a sticker: the coin sprite on a white disc with a dark outline, so it pops off grass and sea.
local function coinSprite(g: ScreenGui, i: number): Frame
	local disc = pool[i] or Instance.new("Frame")
	if not pool[i] then
		disc.Name = "Coin"
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.BackgroundColor3 = Color3.new(1, 1, 1)
		disc.ZIndex = 3
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = disc
		local edge = Instance.new("UIStroke")
		edge.Color = INK
		edge.Thickness = 2
		edge.Parent = disc
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.9, 0.9)
		img.BackgroundTransparency = 1
		img.Image = UiImages.Hud.Coin
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 3
		img.Parent = disc
		disc.Parent = g
		pool[i] = disc
	end
	disc.Visible = false
	return disc
end

local function tick(k: number)
	tickAt = tickAt % TICKS + 1
	local s = ticks[tickAt]
	if s then
		local clip = AudioConfig.Clips[TICK]
		s.Volume = (if clip then clip.volume else 0.2) * 0.9
		s.PlaybackSpeed = 0.95 + math.min(k * 0.03, 0.6)
		s.TimePosition = 0
		s:Play()
	end
end

-- The finish: one soft gold ring held a beat at the wallet, and the wallet coin's own pop (its HUD UIScale).
local function landRing(at: Vector2, size: number, reduced: boolean, slot: GuiObject?)
	local r = ring
	if not r then
		return
	end
	r.Position = UDim2.fromOffset(at.X, at.Y)
	r.Size = UDim2.fromOffset(size * 1.1, size * 1.1)
	r.Visible = true
	local grow = if reduced then 1.3 else 1.7
	TweenService:Create(r, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(size * grow, size * grow),
	}):Play()
	-- held a beat, then faded (both strokes)
	local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35)
	for _, stroke in r:GetDescendants() do
		if stroke:IsA("UIStroke") then
			stroke.Transparency = 0
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
	end
	local pop = slot and slot:FindFirstChildOfClass("UIScale")
	if pop and not reduced then
		pop.Scale = 1.45
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- The wallet coin's centre and size in the shower's screen space (fallback: the wallet's top-left corner).
local function walletCoin(playerGui: Instance): (Vector2, number, GuiObject?)
	local hud = playerGui:FindFirstChild("Hud")
	local wallet = hud and hud:FindFirstChild("Wallet", true)
	local slot = wallet and wallet:FindFirstChild("Coin", true)
	if slot and slot:IsA("GuiObject") and slot.AbsoluteSize.X > 0 then
		return slot.AbsolutePosition + slot.AbsoluteSize / 2, slot.AbsoluteSize.X, slot
	end
	return Vector2.new(70, 60), 48, nil
end

function CoinShower.count(amount: number, tier: string, reduced: boolean): number
	local n = math.clamp(math.floor(12 + 7 * math.log10(math.max(amount, 100) / 100) + 0.5), 12, 26)
	n = math.min(n, CAP[tier] or 22)
	return if reduced then math.min(n, 8) else n
end

function CoinShower.play(playerGui: Instance, amount: number, fromPoint: Vector2?)
	if finishNow then
		finishNow() -- one shower at a time: the last one lands at once
	end
	if amount <= 0 then
		return
	end
	local g = host(playerGui)
	local reduced = Comfort.reducedMotion()
	local n = CoinShower.count(amount, OceanQuality.current().name, reduced)
	-- Studio: HudViewport previews a phone in the top-left corner, so the shower keeps to it as well
	local forced = RunService:IsStudio() and Workspace:GetAttribute("HudViewport")
	local area = if typeof(forced) == "Vector2" then forced else g.AbsoluteSize
	local base = math.clamp(math.min(area.X, area.Y) * 0.108, 40, 86)
	local target, targetSize, slot = walletCoin(playerGui)
	local rng = Random.new()

	-- random spots off the HUD edges, spread out (a few tries each to keep a coin's width apart)
	local coins: { Coin } = {}
	local spots: { Vector2 } = {}
	for _ = 1, n do
		local best, bestGap = Vector2.zero, -1
		for _ = 1, 8 do
			local p = Vector2.new(
				rng:NextNumber(0.34, 0.76) * area.X,
				rng:NextNumber(0.32, 0.74) * area.Y
			)
			local gap = math.huge
			for _, q in spots do
				gap = math.min(gap, (p - q).Magnitude)
			end
			if gap > bestGap then
				best, bestGap = p, gap
			end
			if gap > base * 1.4 then
				break
			end
		end
		table.insert(spots, best)
	end
	-- nearest to the wallet flies first: a stream into the wallet rather than a crossing swarm
	table.sort(spots, function(a, b)
		return (a - target).Magnitude < (b - target).Magnitude
	end)
	local stagger = math.clamp(0.6 / n, 0.03, 0.045)
	for k, spot in spots do
		local mid = (spot + target) / 2
		local d = target - spot
		-- the bow points down the screen (away from the top bar's chips), its size random
		local side = Vector2.new(-d.Y, d.X).Unit
		if side.Y < 0 then
			side = -side
		end
		table.insert(coins, {
			img = coinSprite(g, k),
			spot = spot,
			born = rng:NextNumber(0, BURST - 0.12),
			flyAt = BURST + HANG + (k - 1) * stagger,
			ctrl = if reduced then mid else mid + side * d.Magnitude * rng:NextNumber(0.14, 0.28),
			tilt = if reduced then 0 else rng:NextNumber(-28, 28),
			spin = if reduced then 0 else rng:NextNumber(-40, 40),
			phase = rng:NextNumber(0, math.pi * 2),
			landed = false,
		})
	end
	for i = n + 1, #pool do
		pool[i].Visible = false
	end

	AudioController.play("Cash_Coins", nil, 0.7, 1.05)
	local share = math.floor(amount / n)
	local landedCount, released = 0, 0
	local t = 0
	local conn: RBXScriptConnection? = nil
	local function finish()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		finishNow = nil
		for _, c in coins do
			c.img.Visible = false
		end
		release(amount - released) -- the last coin carries the remainder; an interrupted shower lands it all
	end
	finishNow = finish
	local studio = RunService:IsStudio()
	conn = RunService.Heartbeat:Connect(function(dt: number)
		-- Studio: Workspace attribute CoinShowerAt (seconds) holds the clock there, for frame captures
		local at = studio and tonumber(Workspace:GetAttribute("CoinShowerAt"))
		t = if at then at else t + dt
		for _, c in coins do
			if c.landed or t < c.born then
				continue
			end
			local img = c.img
			img.Visible = true
			local u = math.clamp((t - c.flyAt) / FLIGHT, 0, 1)
			if t < c.flyAt then
				-- burst (pop with overshoot, springing out of fromPoint) then hang (a gentle bob)
				local s = math.clamp((t - c.born) / 0.24, 0, 1)
				local pop = if reduced then s else backOut(s)
				local pos = if fromPoint then fromPoint:Lerp(c.spot, 1 - (1 - s) ^ 3) else c.spot
				local bob = if reduced
					then 0
					else math.sin((t - c.born) * 6 + c.phase) * base * 0.06
				img.Position = UDim2.fromOffset(pos.X, pos.Y + bob)
				img.Size = UDim2.fromOffset(base * pop, base * pop)
				img.Rotation = c.tilt * (1 - s * 0.6) + c.spin * (t - c.born) * 0.15
			else
				-- collect: a curve that speeds up into the wallet, shrinking to the wallet coin's size
				local e = u * u
				local a = c.spot:Lerp(c.ctrl, e)
				local b = c.ctrl:Lerp(target, e)
				local pos = a:Lerp(b, e)
				local size = base + (targetSize * 0.9 - base) * e
				img.Position = UDim2.fromOffset(pos.X, pos.Y)
				img.Size = UDim2.fromOffset(size, size)
				img.Rotation = (c.tilt * 0.4 + c.spin * (c.flyAt - c.born) * 0.15) * (1 - e)
				if u >= 1 then
					c.landed = true
					img.Visible = false
					landedCount += 1
					tick(landedCount)
					if landedCount == n then
						-- the last coin: the till and one soft ring at the wallet
						AudioController.play("Shop_Till", nil, 0.8, 1.05)
						task.delay(0.08, function()
							AudioController.play("Album_Sparkle", nil, 0.6, 1)
						end)
						landRing(target, targetSize, reduced, slot)
						finish()
						return
					end
					release(share)
					released += share
				end
			end
		end
	end)
end

return CoinShower
