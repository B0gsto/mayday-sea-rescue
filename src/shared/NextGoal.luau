--!strict
-- NextGoal: the permanent "what to build next" chip (docs/24 E/F, docs/25 A). Pure (tests/NextGoal.spec.luau):
-- the running construction, else the first level you can build right now (allowed and affordable, card order),
-- else what you save toward: what the next HQ level needs, then the HQ itself, then any allowed level.
-- The client chip shows its icon and a Cash progress bar; at full it pulses. No services.
local Shared = script.Parent
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))

export type Site = { key: string, level: number?, progress: number, rate: number? }

export type Facts = {
	cash: number,
	levels: { [string]: number }, -- data.dock.levels
	construction: Site?,
}

export type Goal = {
	kind: "Build" | "Site",
	key: string,
	level: number, -- the level being built / to build
	name: string,
	price: number,
	cash: number,
	progress: number, -- 0..1 to the price (Build) or of the site (Site)
	timeLeft: number?, -- Site only: seconds at its crew rate
}

local NextGoal = {}

local function build(key: string, n: number, cash: number): Goal
	local b = DockConfig.Buildings[key]
	local price = b.levels[n].cash
	return {
		kind = "Build",
		key = key,
		level = n,
		name = DockConfig.levelName(key, n),
		price = price,
		cash = cash,
		progress = if price <= 0 then 1 else math.clamp(cash / price, 0, 1),
	}
end

function NextGoal.next(f: Facts): Goal?
	local site = f.construction
	local row = site and DockConfig.Buildings[site.key]
	local entry: any = row or (site and DockConfig.Decorations[site.key])
	if site and entry then
		local progress = math.clamp(tonumber(site.progress) or 0, 0, 1)
		local level = if row
			then math.clamp(
				site.level or UnlockTree.levelOf(f.levels, site.key) + 1,
				1,
				#row.levels
			)
			else 1
		local price = if row then row.levels[level].cash else entry.cash
		local work = if row then BuildTimer.work(price) else BuildTimer.DECOR
		return {
			kind = "Site",
			key = site.key,
			level = level,
			name = if row then DockConfig.levelName(site.key, level) else entry.name,
			price = price,
			cash = f.cash,
			progress = progress,
			timeLeft = BuildTimer.timeLeft(progress, tonumber(site.rate) or 1, work),
		}
	end
	for _, key in DockConfig.BUILDINGS do
		local n = UnlockTree.levelOf(f.levels, key) + 1
		if UnlockTree.canBuild(key, n, f.levels, f.cash) then
			return build(key, n, f.cash)
		end
	end
	local order = table.clone(UnlockTree.nextHqNeed(f.levels) or {})
	table.insert(order, "HQ")
	table.move(DockConfig.BUILDINGS, 1, #DockConfig.BUILDINGS, #order + 1, order)
	for _, key in order do
		local n = UnlockTree.levelOf(f.levels, key) + 1
		if UnlockTree.canBuild(key, n, f.levels, math.huge) then -- allowed, only the Cash is short
			return build(key, n, f.cash)
		end
	end
	return nil
end

return NextGoal
