--!strict
-- UnlockTree (docs/23 (q), WP-28; docs/25 K2): the pure rules of island building levels. A row's `levels` carry
-- the HQ gate (`hq`) and optional per-level `needs`; `unlockAt` says which HQ first offers the row. `levels` =
-- data.dock.levels (key -> built level), `owned` = the derived data.dockBuildings booleans. Cash buys the next
-- level only; Robux skips its Cash, never the order. Pure (tests/UnlockTree.spec.luau).
local Config = script.Parent:WaitForChild("Config")
local DockConfig = require(Config:WaitForChild("DockConfig"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))

export type Levels = { [string]: number? }
export type Owned = { [string]: boolean }

local UnlockTree = {}

local function count(n: number): number
	return math.max(0, math.floor(n))
end

function UnlockTree.levelOf(levels: Levels, key: string): number
	return count(tonumber(levels[key]) or 0)
end

function UnlockTree.maxLevel(key: string): number
	local b = DockConfig.Buildings[key]
	return if b then #b.levels else 0
end

-- The old boolean map (data.dockBuildings) derived from levels: every real key at level >= 1, plus the old
-- row keys that merged into levels, so the current build tablet, boards and worker rules keep reading it.
function UnlockTree.ownedSet(levels: Levels): Owned
	local out: Owned = {}
	for key in DockConfig.Buildings do
		if UnlockTree.levelOf(levels, key) >= 1 then
			out[key] = true
		end
	end
	local harbour = UnlockTree.levelOf(levels, "Harbour")
	if harbour >= 2 then
		out.Pontoon = true
	end
	if harbour >= 3 then
		out.Crane = true
	end
	if UnlockTree.levelOf(levels, "Boathouse") >= 2 then
		out.LifeboatSlip = true
	end
	if UnlockTree.levelOf(levels, "AirStation") >= 1 then
		out.Hangar = true
		out.Helipad = true
	end
	if UnlockTree.levelOf(levels, "HQ") >= 3 then
		out.Station = true
	end
	return out
end

-- The first row-level prerequisite of `key` not owned, or nil. (Old callers pass booleans.)
function UnlockTree.missing(key: string, owned: Owned): string?
	local b = DockConfig.Buildings[key]
	if not b then
		return nil
	end
	for _, need in b.needs do
		if owned[need] ~= true then
			return need
		end
	end
	return nil
end

-- The first prerequisite of level `n` not owned, row-level needs included.
function UnlockTree.missingLevel(key: string, n: number, levels: Levels): string?
	local b = DockConfig.Buildings[key]
	local lvl = b and b.levels[n]
	if not b or not lvl then
		return nil
	end
	for _, need in b.needs do
		if UnlockTree.levelOf(levels, need) < 1 then
			return need
		end
	end
	if lvl.needs then
		for _, need in lvl.needs do
			if UnlockTree.levelOf(levels, need) < 1 then
				return need
			end
		end
	end
	return nil
end

-- Can `key` be built/upgraded to level `n` with Cash? -> ok, reason
-- ("Unknown" | "Owned" | "Maxed" | "Order" | "HQ" | "Needs" | "Cash"), price, missing need ("HQ" for the HQ gate).
function UnlockTree.canBuild(
	key: string,
	n: number,
	levels: Levels,
	cash: number
): (boolean, string?, number?, string?)
	local b = DockConfig.Buildings[key]
	local want = count(n)
	if not b then
		return false, "Unknown", nil, nil
	end
	local price = b.levels[want] and b.levels[want].cash
	if want < 1 then
		return false, "Unknown", nil, nil
	end
	local current = UnlockTree.levelOf(levels, key)
	if want <= current then
		return false, "Owned", price, nil
	end
	if want > #b.levels then
		return false, "Maxed", nil, nil
	end
	if want > current + 1 then
		return false, "Order", price, nil
	end
	local lvl = b.levels[want]
	if UnlockTree.levelOf(levels, "HQ") < lvl.hq then
		return false, "HQ", price, "HQ"
	end
	local need = UnlockTree.missingLevel(key, want, levels)
	if need then
		return false, "Needs", price, need
	end
	if key == "HQ" and want > 1 then
		local hqNeed = UnlockTree.nextHqNeed(levels)
		if hqNeed and #hqNeed > 0 then
			return false, "Needs", price, hqNeed[1]
		end
	end
	if cash < lvl.cash then
		return false, "Cash", lvl.cash, nil
	end
	return true, nil, lvl.cash, nil
end

-- May `key` be bought to level `n` with its Robux product now? Robux skips only the Cash: the order, the HQ gate
-- and the next HQ level's needs must stand (canBuild with unlimited Cash).
function UnlockTree.canRobux(key: string, n: number, levels: Levels): boolean
	local b = DockConfig.Buildings[key]
	local lvl = b and b.levels[count(n)]
	return lvl ~= nil and lvl.product ~= nil and (UnlockTree.canBuild(key, n, levels, math.huge))
end

-- Every row the current HQ level offers (unlockAt <= HQ) with no level built yet: what the next HQ level needs.
-- nil when the HQ is already maxed.
function UnlockTree.nextHqNeed(levels: Levels): { string }?
	local hq = UnlockTree.levelOf(levels, "HQ")
	if hq >= UnlockTree.maxLevel("HQ") then
		return nil
	end
	if hq < 1 then
		return nil -- HQ Lv1 is the free first build, no prerequisites
	end
	local out = {}
	for _, key in DockConfig.BUILDINGS do
		local b = DockConfig.Buildings[key]
		if key ~= "HQ" and b.unlockAt <= hq and UnlockTree.levelOf(levels, key) < 1 then
			table.insert(out, key)
		end
	end
	return out
end

-- The Bunkhouse's people cap at its current level (the Hut's few bunks when not built).
function UnlockTree.bunkCap(levels: Levels): number
	local n = UnlockTree.levelOf(levels, "Bunkhouse")
	if n < 1 then
		return DockConfig.HutCap
	end
	return DockConfig.BunkhouseCaps[math.min(n, #DockConfig.BunkhouseCaps)] or 0
end

-- The card name of a building key; a merged-away alias (LifeboatSlip, Hangar, ...) names its row and level.
function UnlockTree.needName(key: string): string
	local b = DockConfig.Buildings[key]
	if b then
		return b.name
	end
	local to, level = UnlockTree.legacyTarget(key)
	return if to then `{DockConfig.Buildings[to].name} Lv{level}` else key
end

-- The building craft `id` needs and that is not owned yet (nil: none, or owned).
function UnlockTree.craftMissing(id: string, owned: Owned): string?
	local v = ProgressionConfig.Vehicles[id]
	local need = v and v.needs
	return if need and owned[need] ~= true then need else nil
end

-- The old Cash paid for a row (pre-K2), used to refund the merges.
-- Where a removed one-time row maps now: -> key, level.
local LEGACY_TARGET: { [string]: { key: string, level: number } } = {
	Pontoon = { key = "Harbour", level = 2 },
	Crane = { key = "Harbour", level = 3 },
	LifeboatSlip = { key = "Boathouse", level = 2 },
	Hangar = { key = "AirStation", level = 1 },
	Helipad = { key = "AirStation", level = 1 },
	Station = { key = "HQ", level = 3 },
}

function UnlockTree.legacyTarget(key: string): (string?, number?)
	if DockConfig.Buildings[key] then
		return key, 1
	end
	local t = LEGACY_TARGET[key]
	return if t then t.key else nil, if t then t.level else nil
end

local OLD_CASH = {
	Pontoon = 2500,
	Crane = 25000,
	Boathouse = 2500,
	LifeboatSlip = 8000,
	Helipad = 22000,
	Hangar = 32000,
	Station = 51000,
}

local function refundFor(levels: Levels, key: string, oldCash: number): number
	local paid = 0
	for n = 1, UnlockTree.levelOf(levels, key) do
		paid += DockConfig.Buildings[key].levels[n].cash
	end
	return math.max(0, oldCash - paid)
end

local function grant(levels: Levels, key: string, n: number)
	if DockConfig.Buildings[key] and n > UnlockTree.levelOf(levels, key) then
		levels[key] = math.min(n, UnlockTree.maxLevel(key))
	end
end

-- Old saves (one-time rows + dockLevel): map them onto levels, refund merged Cash, imply the HQ their buildings
-- need and grant a Bunkhouse for the people already hired. -> levels, refund.
function UnlockTree.migrateLegacy(
	owned: Owned,
	dockLevel: number,
	workers: number?
): (Levels, number)
	local old: Owned = {}
	for key, value in owned do
		if value == true then
			old[key] = true
		end
	end
	for n = 2, math.clamp(count(dockLevel), 1, 5) do
		for _, key in DockConfig.LEVEL_ITEMS[n] do
			old[key] = true
		end
	end
	if old.Hangar then
		old.Helipad = true
	end

	local levels: Levels = { Harbour = 1 } -- every old save has the jetty
	local refund = 0

	if old.Pontoon or old.Crane then
		local n = if old.Crane then 3 else 2
		levels.Harbour = n
		refund += refundFor(
			levels,
			"Harbour",
			(if old.Crane then OLD_CASH.Crane else OLD_CASH.Pontoon) or 0
		)
	end
	if old.Boathouse or old.LifeboatSlip then
		levels.Boathouse = if old.LifeboatSlip then 2 else 1
		local paid = (if old.Boathouse then OLD_CASH.Boathouse else 0)
			+ (if old.LifeboatSlip then OLD_CASH.LifeboatSlip else 0)
		refund += refundFor(levels, "Boathouse", paid)
	end
	if old.Hangar or old.Helipad then
		levels.AirStation = 1
		local paid = (if old.Hangar then OLD_CASH.Hangar else 0)
			+ (if old.Helipad then OLD_CASH.Helipad else 0)
		refund += refundFor(levels, "AirStation", paid)
	end
	if old.Station then
		levels.HQ = 3
		refund += refundFor(levels, "HQ", OLD_CASH.Station)
	end
	for _, key in
		{
			"Workshop",
			"FishShed",
			"Depot",
			"Bunkhouse",
			"BoatYard",
			"Clinic",
			"RescueBoathouse",
			"LookoutTower",
			"SubPen",
			"TrophyHall",
		}
	do
		if old[key] then
			grant(levels, key, 1)
		end
	end

	-- A Bunkhouse level for the people already on the island (never evicts).
	local people = count(workers or 0)
	if people > 0 then
		local n = 1
		for i, cap in DockConfig.BunkhouseCaps do
			if people <= cap then
				n = i
				break
			end
			n = i
		end
		grant(levels, "Bunkhouse", n)
	end

	-- Implied HQ: every granted level must be legal, and an old save is past the empty start.
	local hq = math.max(1, UnlockTree.levelOf(levels, "HQ"))
	for key, n in levels do
		local b = DockConfig.Buildings[key]
		if b then
			for i = 1, n or 0 do
				hq = math.max(hq, b.levels[i].hq)
			end
		end
	end
	levels.HQ = math.max(UnlockTree.levelOf(levels, "HQ"), hq)
	return levels, refund
end

return UnlockTree
