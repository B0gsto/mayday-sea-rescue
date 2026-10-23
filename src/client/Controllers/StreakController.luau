--!strict
-- StreakController: the client side of the daily streak crate (docs/15 hook H5).
-- Builds this player's crate and its day-pip sign (World/StreakCrate, World/StreakSign) at their launch
-- bay (player attribute BayCFrame, BayLaunch offsets; the station porch until it is set) from
-- Streak_State / Streak_Get, opens the crate through Streak_Open and plays the reward burst
-- (UI/StreakReward: lid, confetti, Cash roll, the day-7 star). Only the local player sees their
-- own crate, so the patio never shows another player's chest.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BayLaunch = require(Shared:WaitForChild("Boat"):WaitForChild("BayLaunch"))
local StreakConfig = require(Shared:WaitForChild("Config"):WaitForChild("StreakConfig"))

local World = script.Parent.Parent:WaitForChild("World")
local StreakCrate = require(World:WaitForChild("StreakCrate"))
local StreakReward = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("StreakReward"))
local StreakSign = require(World:WaitForChild("StreakSign"))

local StreakController = {}
StreakController.Priority = 88

type Preview = { day: number, streak: number, cash: number, welcome: boolean, calm: boolean }
type View = {
	day: number,
	streak: number,
	available: boolean,
	secondsToDay: number,
	preview: Preview?,
}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local crate: StreakCrate.Crate? = nil
local crateKey: string? = nil
local bursting: StreakCrate.Crate? = nil
local sign: StreakSign.Sign? = nil
local lastView: any = nil
local opening = false
local openRemote: RemoteFunction? = nil

-- `at` dropped onto whatever is below it (the pier); `fallbackY` before the ground streams in.
local function grounded(at: CFrame, fallbackY: number): CFrame
	local p = at.Position
	local filter = {}
	if player.Character then
		table.insert(filter, player.Character)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(filter, other.Character)
		end
	end
	if crate then
		table.insert(filter, crate.model)
	end
	if sign then
		table.insert(filter, sign.model)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 50, p.Z), Vector3.new(0, -100, 0), params)
	return at.Rotation + Vector3.new(p.X, if hit then hit.Position.Y else fallbackY, p.Z)
end

-- K12: the crate (and its sign) on the player's spawn path at their bay
local function spot(offset: CFrame, porchOffset: CFrame): CFrame
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) == "CFrame" then
		return grounded(bay * offset, 4) -- the quay / pier top
	end
	local porch = StreakConfig.PorchPosition
	return grounded(CFrame.new(porch) * porchOffset, porch.Y)
end

local function ensureSign()
	if not sign then
		sign = StreakSign.build(spot(BayLaunch.SIGN, CFrame.new(5.9, 0, 0.2)))
	end
end

local function clearCrate()
	if crate then
		crate.model:Destroy()
		crate = nil
	end
	crateKey = nil
end

local function requestOpen()
	if opening or not crate or not openRemote then
		return
	end
	opening = true
	local thisCrate = crate
	bursting = thisCrate -- the claim's state push lands before the reply; keep the crate for the burst
	thisCrate.prompt.Enabled = false
	task.spawn(function()
		local ok, result = pcall(function()
			return (openRemote :: RemoteFunction):InvokeServer()
		end)
		if ok and type(result) == "table" and result.ok then
			thisCrate.open()
			StreakReward.play(playerGui, {
				cash = tonumber(result.cash) or 0,
				cashAfter = tonumber(result.cashAfter) or 0,
				weekly = result.cosmetic == true,
				at = thisCrate.top,
			})
			task.delay(3.5, function()
				if crate == thisCrate then
					clearCrate()
				end
				if bursting == thisCrate then
					bursting = nil
				end
			end)
		else
			if bursting == thisCrate then
				bursting = nil
			end
			if crate == thisCrate then
				thisCrate.prompt.Enabled = true
			end
		end
		opening = false
	end)
end

local function ensureCrate(view: View)
	if not view.available or not view.preview then
		if crate and crate == bursting then
			return -- the open burst removes it when it finishes
		end
		clearCrate()
		return
	end
	local preview = view.preview
	local key = `{preview.streak}:{preview.welcome and 1 or 0}`
	if crate and crateKey == key then
		return
	end
	clearCrate()
	local built = StreakCrate.build(spot(BayLaunch.CRATE, CFrame.new()), {
		streak = preview.streak,
		welcome = preview.welcome,
		weekly = preview.streak == StreakConfig.WeekDays,
	})
	crate = built
	crateKey = key
	built.prompt.Triggered:Connect(requestOpen)
end

local function apply(view: any)
	if type(view) ~= "table" then
		return
	end
	lastView = view
	ensureSign()
	local v = view :: View
	local claimed = if v.available and v.preview then v.preview.streak - 1 else v.streak
	if sign then
		sign.setDays(tonumber(claimed) or 0, v.available == true)
	end
	ensureCrate(v)
end

function StreakController.Start()
	local netFolder = ReplicatedStorage:WaitForChild("Net", 30)
	if not netFolder then
		return
	end
	local state = netFolder:WaitForChild("Streak_State", 30)
	local get = netFolder:WaitForChild("Streak_Get", 30)
	local open = netFolder:WaitForChild("Streak_Open", 30)
	if not state or not state:IsA("RemoteEvent") or not get or not get:IsA("RemoteFunction") then
		return
	end
	if open and open:IsA("RemoteFunction") then
		openRemote = open
	end
	state.OnClientEvent:Connect(apply)
	local ok, view = pcall(function()
		return (get :: RemoteFunction):InvokeServer()
	end)
	if ok then
		apply(view)
	end
	-- the bay is assigned after the first build: move both there
	player:GetAttributeChangedSignal("BayCFrame"):Connect(function()
		if sign then
			sign.model:Destroy()
			sign = nil
		end
		if crate ~= bursting then
			clearCrate()
		end
		apply(lastView)
	end)
end

return StreakController
