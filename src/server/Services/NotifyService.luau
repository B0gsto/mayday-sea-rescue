--!strict
-- NotifyService: writes the "come back" entry when an opted-in player leaves (G49). Nothing runs
-- while they are offline: tools/notify.py reads the entry with Open Cloud and sends at most one
-- notification per player per 24 h. Timing lives in Shared/NotifyDue (pure, tests/NotifyDue.spec).
--
-- One UpdateAsync per leaving player, only when data.flags.notifyOptIn is true and the DataStore
-- request budget allows it; failures are warned, never retried on the spot. UpdateAsync keeps the
-- `l` (last notified) the sender wrote, so a leave cannot reset the 24 h cap.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NotifyDue = require(Shared:WaitForChild("NotifyDue"))

local DataService = require(script.Parent.DataService)

local NotifyService = {}
NotifyService.Priority = 84

local store: any = nil
local profiles: { [Player]: any } = {}

local function onLeave(player: Player)
	local data = profiles[player]
	profiles[player] = nil
	if not store or not data or type(data.flags) ~= "table" or data.flags.notifyOptIn ~= true then
		return
	end
	local okBudget, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(
			Enum.DataStoreRequestType.UpdateAsync
		)
	end)
	if okBudget and budget < 1 then
		return
	end

	local now = os.time()
	local streakFlag = data.flags.streak
	local key = tostring(player.UserId)
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: any): any
				local last = if type(old) == "table" then old.l else 0
				return NotifyDue.entry(streakFlag, now, last)
			end)
		end)
		if not ok then
			warn(`[NotifyService] NotifyDue write for {key} failed: {err}`)
		end
	end)
end

function NotifyService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(NotifyDue.STORE)
	end)
	if ok then
		store = result
	else
		warn(`[NotifyService] DataStores unavailable ({result}); no come-back entries`)
	end

	-- Keep the profile table: DataService forgets the player before our PlayerRemoving listener runs.
	DataService.OnLoaded(function(player: Player, data: any)
		profiles[player] = data
	end)
	Players.PlayerRemoving:Connect(onLeave)
end

return NotifyService
