--!strict
-- TrophyRules (docs/25 B): what stands on the Trophy Hall's plinths, in order. Pure (tests/TrophyRules.spec.luau);
-- DockService builds the line from the profile, DockPieces.trophies puts the first ones on the plinths (8 at Lv2,
-- 14 at Lv3) and the cups past them on the shelf. Quest trophies: none yet (a giver's done quests start over).
local Rarity = require(script.Parent:WaitForChild("Rarity"))
local SpinRules = require(script.Parent:WaitForChild("SpinRules"))
local WorkerRules = require(script.Parent:WaitForChild("WorkerRules"))

-- kind "survivor" (a statue), "prize" (a cup in its rarity colour) or "cup" (a gold rescue-milestone cup, rarity 0)
export type Item = { kind: string, name: string, rarity: number, category: string }

local TrophyRules = {}

local function traitRank(trait: string?): number
	return table.find(WorkerRules.TRAIT_BEST, trait or "") or #WorkerRules.TRAIT_BEST + 1
end

-- The wheel prizes the profile keeps (`flags` = data.flags): the claimed finishes and trails, and the grand boat.
function TrophyRules.wheelPrizes(flags: { [string]: any }): { SpinRules.Prize }
	local state = SpinRules.decode(flags.spin)
	local out = {}
	for _, prize in SpinRules.PRIZES do
		if
			SpinRules.owns(state, prize)
			or (prize.kind == "boat" and flags.spinBoat == prize.vehicle)
		then
			table.insert(out, prize)
		end
	end
	return out
end

-- The plinth line: the owned specials, then the other survivors from Epic up (rarest, best trait, earliest rescue),
-- then the wheel prizes (rarest first), then the cups.
function TrophyRules.items(
	workers: { WorkerRules.Worker },
	prizes: { SpinRules.Prize },
	cups: { string }
): { Item }
	local people = {}
	for i, w in workers do
		local special = (w.special or "") ~= ""
		if special or w.rarity >= WorkerRules.EPIC then
			table.insert(people, { w = w, i = i, special = special })
		end
	end
	table.sort(people, function(a, b)
		if a.special ~= b.special then
			return a.special
		elseif a.w.rarity ~= b.w.rarity then
			return a.w.rarity > b.w.rarity
		end
		local ta, tb = traitRank(a.w.trait), traitRank(b.w.trait)
		if ta ~= tb then
			return ta < tb
		end
		return a.i < b.i
	end)
	local out: { Item } = {}
	for _, p in people do
		table.insert(
			out,
			{ kind = "survivor", name = p.w.name, rarity = p.w.rarity, category = p.w.category }
		)
	end
	local ranked = {}
	for i, prize in prizes do
		table.insert(ranked, { prize = prize, i = i, r = Rarity.index(prize.rarity) or 1 })
	end
	table.sort(ranked, function(a, b)
		return if a.r ~= b.r then a.r > b.r else a.i < b.i
	end)
	for _, p in ranked do
		table.insert(out, { kind = "prize", name = p.prize.name, rarity = p.r, category = "" })
	end
	for _, name in cups do
		table.insert(out, { kind = "cup", name = name, rarity = 0, category = "" })
	end
	return out
end

return TrophyRules
