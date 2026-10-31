--!strict
-- RewardController: the one reward prompt on join (owner, 2026-10-28: no chest; "if we get stuff while offline,
-- just prompt that"). Once the loading screen, its flyover and a new player's cold open are done, and there is
-- anything to collect (today's streak reward with its welcome-back bonus, from Streak_State / Streak_Get; the
-- crew's offline earnings, player attribute WorkerOffline), UI/RewardPrompt shows it. Collect claims the
-- streak through Streak_Collect (the server grants it only then; left uncollected it stays available on the
-- next join) and plays UI/CoinShower. Offline pay is granted on join by WorkerService, so the wallet holds it
-- back (CashHeld, HudController) until the coins land: never paid twice, never lost.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = script.Parent.Parent:WaitForChild("UI")
local CoinShower = require(UI:WaitForChild("CoinShower"))
local RewardPrompt = require(UI:WaitForChild("RewardPrompt"))

local RewardController = {}
RewardController.Priority = 88

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local view: any = nil -- the last Streak_State view
local offline = 0 -- offline pay granted and not yet collected
local lastOffline: any = nil
local failedDay: number? = nil -- a refused claim: don't prompt that day's streak again this session
local open = false
local collectRemote: RemoteFunction? = nil

local function hold(delta: number)
	local held = math.max(0, (tonumber(player:GetAttribute("CashHeld")) or 0) + delta)
	player:SetAttribute("CashHeld", if held > 0 then held else nil)
end

local function streakPreview(): any
	local p = type(view) == "table" and view.available and view.preview
	if type(p) ~= "table" or p.day == failedDay then
		return nil
	end
	return p
end

local function busy(): boolean
	return player:GetAttribute("LoadingScreenActive") == true
		or player:GetAttribute("CinematicPlaying") == true
		or player:GetAttribute("ColdOpenActive") == true
		or player:GetAttribute("Establishing") == true -- OnboardingController's first-spawn shot comes first
		-- Studio: Workspace attribute RewardHold keeps the prompt shut while a test sets up its state
		or (RunService:IsStudio() and Workspace:GetAttribute("RewardHold") == true)
end

local function maybeShow()
	local p = streakPreview()
	local streak = if p then (tonumber(p.cash) or 0) + (tonumber(p.bonus) or 0) else 0
	if open or busy() or streak + offline <= 0 then
		return
	end
	open = true
	local crew = offline
	RewardPrompt.show(playerGui, {
		cash = streak + crew,
		day = if p then tonumber(p.streak) else nil,
		welcome = p and p.welcome == true,
		crew = if crew > 0 then crew else nil,
	}, function(from: Vector2)
		offline -= crew
		local total = crew
		if p and collectRemote then
			hold(streak) -- the claim's Cash push lands before the reply
			local ok, result = pcall(function()
				return (collectRemote :: RemoteFunction):InvokeServer()
			end)
			local paid = if ok
					and type(result) == "table"
					and result.ok
				then tonumber(result.cash) or 0
				else 0
			if paid == 0 then
				failedDay = p.day
			end
			hold(paid - streak)
			total += paid
		end
		CoinShower.play(playerGui, total, from)
		open = false
		maybeShow() -- anything that arrived meanwhile
	end)
end

local function onOffline()
	local pay = player:GetAttribute("WorkerOffline")
	if type(pay) == "number" and pay > 0 and pay ~= lastOffline then
		lastOffline = pay
		offline += pay
		hold(pay)
	end
	maybeShow()
end

local function apply(v: any)
	if type(v) == "table" then
		view = v
		maybeShow()
	end
end

function RewardController.Start()
	-- under the loading screen already: hold the offline pay off the wallet before the HUD shows it
	onOffline()
	for _, name in
		{
			"WorkerOffline",
			"LoadingScreenActive",
			"CinematicPlaying",
			"ColdOpenActive",
			"Establishing",
		}
	do
		player
			:GetAttributeChangedSignal(name)
			:Connect(if name == "WorkerOffline" then onOffline else maybeShow)
	end
	Workspace:GetAttributeChangedSignal("RewardHold"):Connect(maybeShow)
	local net = ReplicatedStorage:WaitForChild("Net", 30)
	if not net then
		return
	end
	local state = net:WaitForChild("Streak_State", 30)
	local get = net:WaitForChild("Streak_Get", 30)
	local collect = net:WaitForChild("Streak_Collect", 30)
	if collect and collect:IsA("RemoteFunction") then
		collectRemote = collect
	end
	if state and state:IsA("RemoteEvent") then
		state.OnClientEvent:Connect(apply)
	end
	if get and get:IsA("RemoteFunction") then
		local ok, v = pcall(function()
			return (get :: RemoteFunction):InvokeServer()
		end)
		if ok then
			apply(v)
		end
	end
end

return RewardController
