--!strict
-- GroupReward (pure, shared): the Roblox group ("Crew") reward (docs/15 fair rules, G68).
-- Membership is checked on the server with Player:IsInGroupAsync (pcall) when the profile loads and
-- again when the player walks to the harbour noticeboard. State lives in one profile flag:
--
--   flags.group = { c = crew cosmetic earned, m = member right now, g = the group id checked }
--
-- The Crew bay pennant is earned once and kept (nothing is lost, docs/15 section 1); the daily
-- crate bonus needs current membership. GroupId 0 turns everything off.
--
--   GroupReward.enabled(groupId)
--   GroupReward.decode(raw) / encode(state)
--   GroupReward.update(state, isInGroup, groupId)   cache one check result
--   GroupReward.isMember(state, groupId)             current member of this exact group
--   GroupReward.earned(state)                        the Crew cosmetic is owned
--   GroupReward.bonus(state, cash, percent, groupId) flat award, 0 for non-members
--
-- Lune-tested in tests/GroupReward.spec.luau; no services.

export type State = {
	crew: boolean,
	member: boolean,
	groupId: number,
}

local GroupReward = {}

function GroupReward.enabled(groupId: any): boolean
	return type(groupId) == "number"
		and groupId > 0
		and groupId == math.floor(groupId)
		and groupId < math.huge
end

function GroupReward.decode(raw: any): State
	if type(raw) ~= "table" then
		return { crew = false, member = false, groupId = 0 }
	end
	local groupId = tonumber(raw.g) or 0
	return {
		crew = raw.c == true,
		member = raw.m == true,
		groupId = if groupId > 0 then math.floor(groupId) else 0,
	}
end

function GroupReward.encode(state: State): { [string]: any }
	return {
		c = state.crew == true,
		m = state.member == true and state.groupId > 0,
		g = math.max(0, math.floor(state.groupId)),
	}
end

-- One membership result (join, or a recheck at the noticeboard). Joining earns the cosmetic;
-- leaving revokes the daily bonus but keeps the pennant.
function GroupReward.update(state: State, isInGroup: boolean, groupId: number): State
	if not GroupReward.enabled(groupId) then
		return { crew = state.crew, member = false, groupId = 0 }
	end
	local member = isInGroup == true
	return {
		crew = state.crew or member,
		member = member,
		groupId = math.floor(groupId),
	}
end

function GroupReward.isMember(state: State, groupId: number): boolean
	return GroupReward.enabled(groupId)
		and state.member == true
		and state.groupId == math.floor(groupId)
end

function GroupReward.earned(state: State): boolean
	return state.crew == true
end

-- Flat Cash added to the daily crate, never multiplied. 0 for non-members and with the group off.
function GroupReward.bonus(state: State, cash: number, percent: number, groupId: number): number
	if not GroupReward.isMember(state, groupId) or cash <= 0 or percent <= 0 then
		return 0
	end
	return math.max(0, math.floor(cash * percent + 1e-9))
end

return GroupReward
