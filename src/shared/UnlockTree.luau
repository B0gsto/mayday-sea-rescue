--!strict
-- UnlockTree (docs/23 (q), WP-28): the pure rules of your island's unlock tree. Buildings list what they need in
-- DockConfig.Buildings (`needs`), craft the one building they need in ProgressionConfig.Vehicles (`needs`).
-- `owned` = data.dockBuildings (key -> true). No ranks: Cash buys anything whose prerequisites you own; Robux
-- skips the Cash, never the order. Pure (tests/UnlockTree.spec.luau); the server and the build tablet agree.
local Config = script.Parent:WaitForChild("Config")
local DockConfig = require(Config:WaitForChild("DockConfig"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))

local UnlockTree = {}

-- The first prerequisite of building `key` not owned yet, or nil when every one is there.
function UnlockTree.missing(key: string, owned: { [string]: boolean }): string?
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

-- A Cash buy of building `key` -> ok, reason ("Owned" | "Needs" | "Cash"), price, the missing prerequisite.
function UnlockTree.canBuy(
	key: string,
	owned: { [string]: boolean },
	cash: number
): (boolean, string?, number?, string?)
	local b = DockConfig.Buildings[key]
	if not b or owned[key] == true then
		return false, "Owned", nil, nil
	end
	local price = b.cash
	local need = UnlockTree.missing(key, owned)
	if need then
		return false, "Needs", price, need
	end
	if cash < price then
		return false, "Cash", price, nil
	end
	return true, nil, price, nil
end

-- May building `key` be bought (and granted) with its Robux product now? Its prerequisites must be owned.
function UnlockTree.canRobux(key: string, owned: { [string]: boolean }): boolean
	local b = DockConfig.Buildings[key]
	return b ~= nil
		and b.product ~= nil
		and owned[key] ~= true
		and UnlockTree.missing(key, owned) == nil
end

-- Prepaid Robux buildings (a receipt for one whose prerequisites were missing): moves every prepaid key whose
-- prerequisites now stand from `prepaid` into `owned`, chains included, never out of order. Returns the keys
-- built, in build order (mutates both tables).
function UnlockTree.settle(owned: { [string]: boolean }, prepaid: { [string]: boolean }): { string }
	local built = {}
	local again = true
	while again do
		again = false
		for key in prepaid do
			if owned[key] == true then
				prepaid[key] = nil
			elseif DockConfig.Buildings[key] and UnlockTree.missing(key, owned) == nil then
				owned[key], prepaid[key] = true, nil
				table.insert(built, key)
				again = true
			end
		end
	end
	return built
end

-- The building craft `id` needs and that is not owned yet (nil: none, or owned).
function UnlockTree.craftMissing(id: string, owned: { [string]: boolean }): string?
	local v = ProgressionConfig.Vehicles[id]
	local need = v and v.needs
	return if need and owned[need] ~= true then need else nil
end

-- Old saves (the dock-level ladder): adds the tree items an old dock level stood for to `owned`. The old hangar
-- came with its pad, so a hangar owner also owns the helipad. Idempotent.
function UnlockTree.migrate(level: number, owned: { [string]: boolean })
	for n = 2, math.clamp(math.floor(level), 1, 5) do
		for _, key in DockConfig.LEVEL_ITEMS[n] do
			owned[key] = true
		end
	end
	if owned.Hangar then
		owned.Helipad = true
	end
end

return UnlockTree
