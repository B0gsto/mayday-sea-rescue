--!strict
-- SeasonRules: the Season Logbook maths (docs/15 hook H8), pure and tested in tests/Season.spec.luau.
-- XP comes from every rescue (grade scaled, plus big calls, storms and event rescues), challenges,
-- streak crates and new album stickers. Tiers are cumulative XP; a claim needs the tier reached,
-- unclaimed and the season still live. Unclaimed tiers are never lost before the season ends.
--
-- The state lives in data.flags.season as a flat table of scalars (ProgressionRules sanitizeFlag):
--   s = season id (a new id starts fresh), xp = Season XP,
--   c = claimed-tier bitfield, v = variants already seen (album sticker XP once per variant).

local Config = require(script.Parent.Config.Season)
local EventClock = require(script.Parent.EventClock)
local RescueVariants = require(script.Parent.Config.RescueVariants)

export type State = { id: string, xp: number, claimed: number, seen: number }

export type Reward = {
	tier: number,
	cash: number,
	rep: number,
	cosmetic: string?,
	surprise: string?,
}

export type TierView = {
	tier: number,
	xp: number,
	cash: number,
	rep: number,
	cosmetic: string?,
	surprise: string?,
	claimed: boolean,
	reached: boolean,
}

export type View = {
	id: string,
	name: string,
	xp: number,
	tier: number,
	xpInto: number,
	xpSpan: number,
	maxed: boolean,
	claimed: number,
	total: number,
	live: boolean,
	daysLeft: number,
	tiers: { TierView },
}

local MAX_XP = 1e6
local MAX_BITS = 2 ^ Config.maxTier

-- Stable bit index per rare-call variant (album sticker XP is paid once per variant).
local variantBit: { [string]: number } = {}
do
	local n = 0
	for _, list in RescueVariants.Kinds do
		for _, variant in list do
			n += 1
			variantBit[variant.id] = n
		end
	end
end

local SeasonRules = {}

SeasonRules.MAX_XP = MAX_XP

function SeasonRules.newState(): State
	return { id = Config.id, xp = 0, claimed = 0, seen = 0 }
end

function SeasonRules.fromFlag(raw: any): State
	if type(raw) ~= "table" or raw.s ~= Config.id then
		return SeasonRules.newState()
	end
	return {
		id = Config.id,
		xp = math.clamp(math.floor(tonumber(raw.xp) or 0), 0, MAX_XP),
		-- c is saved as a string: tiers 20-30 need bits above the profile flag number clamp (1e6)
		claimed = math.floor(tonumber(raw.c) or 0) % MAX_BITS,
		seen = math.max(0, math.floor(tonumber(raw.v) or 0)),
	}
end

function SeasonRules.flagTable(state: State): { [string]: any }
	-- c as a string: ProgressionRules clamps flag numbers to 1e6, which would drop tiers 20-30
	return { s = Config.id, xp = math.floor(state.xp), c = tostring(state.claimed), v = state.seen }
end

function SeasonRules.live(now: number): boolean
	return EventClock.inSeason(
		{ id = Config.id, startAt = Config.startUtc, endsAt = Config.endUtc },
		now
	)
end

-- Whole days shown by the clock: 43 on the first day, 1 on the last, 0 once it is over.
function SeasonRules.daysLeft(now: number): number
	if now > Config.endUtc then
		return 0
	end
	return math.max(1, math.ceil((Config.endUtc - now) / 86400))
end

function SeasonRules.tierForXp(xp: number): number
	local tier = 0
	for i, def in Config.tiers do
		if xp >= def.xp then
			tier = i
		else
			break
		end
	end
	return tier
end

function SeasonRules.tierXp(tier: number): number
	if tier <= 0 then
		return 0
	end
	return Config.tiers[math.min(tier, Config.maxTier)].xp
end

function SeasonRules.claimed(state: State, tier: number): boolean
	if tier < 1 or tier > Config.maxTier then
		return false
	end
	return bit32.band(state.claimed, bit32.lshift(1, tier - 1)) ~= 0
end

function SeasonRules.claimable(state: State, tier: number, now: number): boolean
	return SeasonRules.live(now)
		and tier >= 1
		and tier <= Config.maxTier
		and state.xp >= SeasonRules.tierXp(tier)
		and not SeasonRules.claimed(state, tier)
end

-- Claims one tier (mutates state). Returns the reward, or nil and why not.
function SeasonRules.claim(state: State, tier: number, now: number): (Reward?, string?)
	if not SeasonRules.live(now) then
		return nil, "Closed"
	end
	local def = Config.tiers[tier]
	if not def then
		return nil, "Unknown"
	end
	if state.xp < def.xp then
		return nil, "Locked"
	end
	if SeasonRules.claimed(state, tier) then
		return nil, "Claimed"
	end
	state.claimed = bit32.bor(state.claimed, bit32.lshift(1, tier - 1))
	return {
		tier = tier,
		cash = def.cash,
		rep = def.rep,
		cosmetic = def.cosmetic,
		surprise = def.surprise,
	}
end

-- A finished rescue's XP for one helper: grade base plus big, storm and event bonuses.
function SeasonRules.xpForOperation(snap: any): number
	if type(snap) ~= "table" then
		return 0
	end
	local grade = snap.grade
	if grade == "Fail" or grade == "Takeover" then
		return 0
	end
	local xp = Config.xp.operation[grade] or 0
	if xp <= 0 then
		return 0
	end
	if snap.isBig == true then
		xp += Config.xp.big
	end
	if snap.storm == true then
		xp += Config.xp.storm
	end
	if type(snap.variant) == "string" and Config.eventVariants[snap.variant] then
		xp += Config.xp.event
	end
	return xp
end

-- Album sticker XP: the first time this player sees a rare variant (mutates state).
function SeasonRules.stickerXp(state: State, variantId: any): number
	local bit = if type(variantId) == "string" then variantBit[variantId] else nil
	if not bit then
		return 0
	end
	local flag = bit32.lshift(1, bit - 1)
	if bit32.band(state.seen, flag) ~= 0 then
		return 0
	end
	state.seen = bit32.bor(state.seen, flag)
	return Config.xp.sticker
end

function SeasonRules.view(state: State, now: number): View
	local xp = math.max(0, math.floor(state.xp))
	local tier = SeasonRules.tierForXp(xp)
	local from = SeasonRules.tierXp(tier)
	local to = SeasonRules.tierXp(tier + 1)
	local claimed = 0
	local tiers: { TierView } = {}
	for i, def in Config.tiers do
		local isClaimed = SeasonRules.claimed(state, i)
		if isClaimed then
			claimed += 1
		end
		tiers[i] = {
			tier = i,
			xp = def.xp,
			cash = def.cash,
			rep = def.rep,
			cosmetic = def.cosmetic,
			surprise = def.surprise,
			claimed = isClaimed,
			reached = xp >= def.xp,
		}
	end
	return {
		id = Config.id,
		name = Config.name,
		xp = xp,
		tier = tier,
		xpInto = xp - from,
		xpSpan = math.max(0, to - from),
		maxed = tier >= Config.maxTier,
		claimed = claimed,
		total = Config.maxTier,
		live = SeasonRules.live(now),
		daysLeft = SeasonRules.daysLeft(now),
		tiers = tiers,
	}
end

return SeasonRules
