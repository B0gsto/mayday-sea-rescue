--!strict
-- FriendBonus: the friends-in-server Cash bonus (docs/15 H9). Pure maths only: the server counts
-- friends (FriendService) and ProgressionService.Award multiplies the award by multiplier(count).
local FriendBonus = {}

FriendBonus.PER_FRIEND = 0.10
FriendBonus.CAP_FRIENDS = 3

-- +10% Cash per friend in the same server, at most +30%.
function FriendBonus.multiplier(count: number): number
	local n = if count > 0 then math.min(math.floor(count), FriendBonus.CAP_FRIENDS) else 0
	return 1 + n * FriendBonus.PER_FRIEND
end

-- The HUD reads a whole percent: 0, 10, 20 or 30.
function FriendBonus.percent(count: number): number
	return math.floor((FriendBonus.multiplier(count) - 1) * 100 + 0.5)
end

return FriendBonus
