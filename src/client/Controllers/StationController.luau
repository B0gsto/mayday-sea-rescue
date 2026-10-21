--!strict
-- StationController: the station crew's pot and workshop (docs/15 hook H6), now the phone's
-- Crew Pay and Pay Rise apps (UI/CrewPay; the forecourt strongbox and counter are gone). Keeps
-- the server view, interpolates the pot between pushes so the meter and clock tick every frame
-- while the app is up, pays out through Station_Collect (coins fly from the Collect button to the
-- Cash counter, UI/CashBurst) and buys the next workshop level through Station_Upgrade.
--   StationController.mountPay(page) / mountRise(page) -> cleanup   (the Phone calls these)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("StationConfig"))

local AudioController = require(script.Parent:WaitForChild("AudioController"))
local UI = script.Parent.Parent:WaitForChild("UI")
local CashBurst = require(UI:WaitForChild("CashBurst"))
local CrewPay = require(UI:WaitForChild("CrewPay"))

local StationController = {}
StationController.Priority = 86

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local pot: CrewPay.Pot? = nil
local rise: CrewPay.Rise? = nil
local getFn: RemoteFunction? = nil
local collectFn: RemoteFunction? = nil
local upgradeFn: RemoteFunction? = nil
local busy = false

local baseCash = 0
local rate = 0
local capCash = 0
local anchoredAt = 0
local level = 0
local radio = 0
local cost = 0
local maxed = false

local function current(): number
	local cash = baseCash + rate * math.max(0, os.clock() - anchoredAt) / 3600
	return math.clamp(cash, 0, capCash)
end

local function tick()
	local p = pot
	if not p then
		return
	end
	local cash = current()
	local full = capCash > 0 and cash >= capCash - 1e-6
	local seconds = if rate > 0 and cash < capCash then (capCash - cash) / rate * 3600 else 0
	p.update(cash, capCash, rate, seconds, full)
end

local function drawRise()
	local r = rise
	if r then
		local next = Config.Crew[math.min(level + 2, #Config.Crew)]
		r.update(level, cost, maxed, next.rate * (1 + radio * Config.RadioRateBonus))
	end
end

local function apply(view: any)
	if type(view) ~= "table" then
		return
	end
	baseCash = tonumber(view.cash) or 0
	rate = math.max(0, tonumber(view.rate) or 0)
	capCash = math.max(0, tonumber(view.capCash) or 0)
	anchoredAt = os.clock()
	level = tonumber(view.level) or 0
	radio = tonumber(view.radio) or 0
	cost = tonumber(view.cost) or 0
	maxed = view.maxed == true
	drawRise()
	tick()
end

local function centre(gui: GuiObject): Vector2
	return gui.AbsolutePosition + gui.AbsoluteSize / 2
end

local function collect()
	local p = pot
	if busy or not collectFn or not p or current() < 1 then
		return
	end
	busy = true
	local from = centre(p.button)
	local ok, result = pcall(function()
		return (collectFn :: RemoteFunction):InvokeServer()
	end)
	if ok and type(result) == "table" then
		apply(result.view)
		if result.ok then
			CashBurst.playAt(playerGui, from, tonumber(result.cash) or 0, true)
			AudioController.play("Cash_Coins", nil, 1, 1)
		end
	end
	busy = false
end

local function upgrade()
	if busy or not upgradeFn or maxed then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return (upgradeFn :: RemoteFunction):InvokeServer()
	end)
	local bought = ok and type(result) == "table" and result.ok == true
	if ok and type(result) == "table" then
		apply(result.view)
	end
	local r = rise
	if r then
		r.flash(not bought)
	end
	AudioController.play(if bought then "UI_Pickup" else "UI_Fail")
	busy = false
end

local function refresh()
	local get = getFn
	if not get then
		return
	end
	task.spawn(function()
		local ok, view = pcall(function()
			return get:InvokeServer()
		end)
		if ok then
			apply(view)
		end
	end)
end

function StationController.mountPay(page: Frame): () -> ()
	local p = CrewPay.pot(page)
	pot = p
	p.button.Activated:Connect(function()
		task.spawn(collect)
	end)
	tick()
	refresh()
	return function()
		if pot == p then
			pot = nil
		end
	end
end

function StationController.mountRise(page: Frame): () -> ()
	local r = CrewPay.rise(page)
	rise = r
	r.button.Activated:Connect(function()
		task.spawn(upgrade)
	end)
	drawRise()
	refresh()
	return function()
		if rise == r then
			rise = nil
		end
	end
end

function StationController.Start()
	local netFolder = ReplicatedStorage:WaitForChild("Net", 30)
	if not netFolder then
		return
	end
	local state = netFolder:WaitForChild("Station_State", 30)
	local get = netFolder:WaitForChild("Station_Get", 30)
	local collectRemote = netFolder:WaitForChild("Station_Collect", 30)
	local upgradeRemote = netFolder:WaitForChild("Station_Upgrade", 30)
	if not state or not state:IsA("RemoteEvent") or not get or not get:IsA("RemoteFunction") then
		return
	end
	getFn = get
	if collectRemote and collectRemote:IsA("RemoteFunction") then
		collectFn = collectRemote
	end
	if upgradeRemote and upgradeRemote:IsA("RemoteFunction") then
		upgradeFn = upgradeRemote
	end
	state.OnClientEvent:Connect(apply)
	refresh()
	RunService.Heartbeat:Connect(tick)
end

return StationController
