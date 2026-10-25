--!strict
-- CosmeticLoadout (pure, shared): what a player has actually earned, read from the profile flags
-- that used to be data only (docs/15 H3 stock trims, H8 season rewards, the monthly livery) and the
-- people rescued. Earned cosmetic options carry an
-- `earn` key in their slot config
-- (src/shared/Config/Cosmetics/*); this module turns data.flags into the set of those keys and
-- picks the latest earned option per slot so the player notices it once (Earned service feature).
--
--   CosmeticLoadout.owned(flags, rescued?): { [earnKey]: true }
--   CosmeticLoadout.show(flags, rescued?): { owned, newest = { [slot]: { id, earn } }, decor = { earnKey } }
--   CosmeticLoadout.encode(set) / decode(raw)   the "CosOwned" player attribute (newline list)
--
-- `show` needs the real cosmetics registry (options name their `earn` key), so this is not a
-- no-Roblox pure module; it stays service-free and Lune-tested in tests/CosmeticLoadout.spec.luau.

local Cosmetics = require(script.Parent.Cosmetics)

local CosmeticLoadout = {}

-- The Chandlery stock and the Season Logbook are cut (docs/16 C6, C11); saves that bought or
-- claimed these keep them. Season tiers index the claimed-tier bitfield.
local STOCK = {
	"paint_red",
	"paint_teal",
	"paint_gold",
	"lightbar_amber",
	"lightbar_blue",
	"wake_turquoise",
	"wake_gold",
	"decor_lantern",
	"decor_bell",
	"decor_wreath",
	"decor_flag",
	"decor_shelf",
	"decor_signals",
}
local SEASON = {
	{ tier = 3, cosmetic = "Decal_Season1" },
	{ tier = 8, cosmetic = "Wake_Season1" },
	{ tier = 12, cosmetic = "Title_Season1" },
	{ tier = 30, cosmetic = "Livery_Season1" },
}
-- The monthly liveries came from weekly challenges (cut, docs/16 C12), then Commodore rank (cut, WP-28): 500
-- people rescued unlocks them now (data.totalRescues; about where Commodore was). -- tune
CosmeticLoadout.MONTHLY_RESCUED = 500

-- Stock keys then season tiers, then monthly liveries, then the group reward.
-- Flags carry no earn time, so this fixed order is the "latest" order.
local ORDER: { string } = {}
local RANK: { [string]: number } = {}
local function remember(key: string)
	if RANK[key] then
		return
	end
	table.insert(ORDER, key)
	RANK[key] = #ORDER
end
for _, key in STOCK do
	remember("stock:" .. key)
end
for _, tier in SEASON do
	remember("season:" .. tier.cosmetic)
end
for month = 1, 12 do
	remember("monthly:" .. string.format("2026-%02d", month))
end
remember("group:crew")

-- Earned keys that place something in the player's bay (fixed slots, server-built parts).
CosmeticLoadout.DECOR = {
	["stock:decor_lantern"] = true,
	["stock:decor_bell"] = true,
	["stock:decor_wreath"] = true,
	["stock:decor_flag"] = true,
	["stock:decor_shelf"] = true,
	["stock:decor_signals"] = true,
	["group:crew"] = true,
}

local function flagMap(value: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(value) ~= "table" then
		return out
	end
	for key, held in value do
		if type(key) == "string" and held == true then
			out[key] = true
		end
	end
	return out
end

function CosmeticLoadout.owned(flags: any, rescued: number?): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if (tonumber(rescued) or 0) >= CosmeticLoadout.MONTHLY_RESCUED then
		for month = 1, 12 do
			set["monthly:" .. string.format("2026-%02d", month)] = true
		end
	end
	if type(flags) ~= "table" then
		return set
	end
	for key in flagMap(flags.stock) do
		set["stock:" .. key] = true
	end
	local season = flags.season
	if type(season) == "table" then
		local claimed = math.floor(tonumber(season.c) or 0)
		for _, tier in SEASON do
			if bit32.band(claimed, bit32.lshift(1, tier.tier - 1)) ~= 0 then
				set["season:" .. tier.cosmetic] = true
			end
		end
	end
	local monthly = flags.monthlyLivery
	if type(monthly) == "string" then
		set["monthly:" .. monthly] = true
	end
	local group = flags.group
	if type(group) == "table" and group.c == true then
		set["group:crew"] = true
	end
	return set
end

export type Newest = { [string]: { id: string, earn: string } }
export type Loadout = {
	owned: { [string]: boolean },
	newest: Newest,
	decor: { string },
}

function CosmeticLoadout.show(flags: any, rescued: number?): Loadout
	local owned = CosmeticLoadout.owned(flags, rescued)
	local newest: Newest = {}
	for _, slot in Cosmetics.slots() do
		local entry = Cosmetics.slot(slot)
		if entry then
			local best = 0
			for _, option in entry.options do
				local earn = option.earn
				if type(earn) == "string" and owned[earn] then
					local rank = RANK[earn] or math.huge
					if rank >= best then
						best = rank
						newest[slot] = { id = option.id, earn = earn }
					end
				end
			end
		end
	end
	local decor: { string } = {}
	for _, key in ORDER do
		if owned[key] and CosmeticLoadout.DECOR[key] then
			table.insert(decor, key)
		end
	end
	return { owned = owned, newest = newest, decor = decor }
end

function CosmeticLoadout.encode(set: { [string]: boolean }): string
	local keys = {}
	for key, held in set do
		if held then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return table.concat(keys, "\n")
end

function CosmeticLoadout.decode(raw: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(raw) ~= "string" then
		return set
	end
	for key in string.gmatch(raw, "[^\n]+") do
		set[key] = true
	end
	return set
end

return CosmeticLoadout
