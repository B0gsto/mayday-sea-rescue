--!strict
-- RescueRunService (docs/29 C): each player's rescue run (rules: shared/RescueRun) and the pick-up boost.
--   Multiplier(player) -> number        what delivery pay is worth right now (Ambient onDelivered, OperationService finish)
--   OnPickup(player, vehicle)           RescueService: a survivor came aboard
--   OnDelivered(player, people)         RescueService: survivors reached home, after their pay
--   End(player)                         ends the run at once (the pirates' hit, docs/29 D)
--   SetEscapeBonus(player, untilTime)   PirateService: Go back after a chase with no hit, +25% on that delivery's pay
-- Attributes: player RunMult + RunEndsAt (UI/RunChip; server time, stale once past), PickupBoostUntil on the craft
-- (the craft handling) and the player (PickupBoostController). A new player's HUD is stripped (Onboarding.newPlayerHud)
-- so no run counts yet, and the cold open gets no boost: the tutorial's pay and timing stay as they are.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local PirateRules = require(Shared:WaitForChild("PirateRules"))
local RescueRun = require(Shared:WaitForChild("RescueRun"))

local RescueRunService = {}

local runs: { [Player]: RescueRun.State } = {}
local escapeUntil: { [Player]: number } = {}

local function counting(player: Player): boolean
	local total = player:GetAttribute("OpsCompletedTotal")
	return not Onboarding.newPlayerHud(
		player:GetAttribute("ColdOpenDone") == true,
		if type(total) == "number" then total else nil
	)
end

local function runOf(player: Player): RescueRun.State
	local st = runs[player] or RescueRun.new()
	runs[player] = st
	return st
end

local function push(player: Player, st: RescueRun.State)
	local mult = RescueRun.current(st, Workspace:GetServerTimeNow())
	player:SetAttribute("RunMult", if mult > 1 then mult else nil)
	player:SetAttribute("RunEndsAt", if mult > 1 then st.endsAt else nil)
end

function RescueRunService.Multiplier(player: Player): number
	local st = runs[player]
	local now = Workspace:GetServerTimeNow()
	return (if st then RescueRun.current(st, now) else 1)
		* PirateRules.payMult(escapeUntil[player], now)
end

function RescueRunService.SetEscapeBonus(player: Player, untilTime: number)
	escapeUntil[player] = untilTime
end

function RescueRunService.OnPickup(player: Player, vehicle: Model)
	if player:GetAttribute("ColdOpenDone") ~= true then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local boostUntil = now + RescueRun.BOOST_SECONDS
	vehicle:SetAttribute("PickupBoostUntil", boostUntil)
	player:SetAttribute("PickupBoostUntil", boostUntil)
	if counting(player) then
		local st = runOf(player)
		RescueRun.pickup(st, now)
		push(player, st)
	end
end

function RescueRunService.OnDelivered(player: Player, people: number)
	if counting(player) then
		local st = runOf(player)
		RescueRun.delivered(st, people, Workspace:GetServerTimeNow())
		push(player, st)
	end
end

function RescueRunService.End(player: Player)
	local st = runs[player]
	if st then
		RescueRun.finish(st)
		push(player, st)
	end
end

function RescueRunService.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		runs[player] = nil
		escapeUntil[player] = nil
	end)
end

function RescueRunService.Start() end

return RescueRunService
