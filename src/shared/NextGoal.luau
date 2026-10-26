--!strict
-- NextGoal: the permanent "what to build next" chip (docs/24 E/F). Pure (tests/NextGoal.spec.luau):
-- the first island building in unlock order whose prerequisites stand, or the running construction.
-- The client chip shows its icon and a Cash progress bar; at full it pulses. No services.
local Shared = script.Parent
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))

export type Site = { key: string, progress: number, rate: number? }

export type Facts = {
	cash: number,
	owned: { [string]: boolean },
	construction: Site?,
}

export type Goal = {
	kind: "Build" | "Site",
	key: string,
	name: string,
	price: number,
	cash: number,
	progress: number, -- 0..1 to the price (Build) or of the site (Site)
	timeLeft: number?, -- Site only: seconds at its crew rate
}

local NextGoal = {}

-- The building to work toward: a running site first (docs/24 B allows one at a time), else the first
-- unowned building in DockConfig.BUILDINGS order whose `needs` are all owned.
function NextGoal.next(f: Facts): Goal?
	local site = f.construction
	local built = site and (DockConfig.Buildings[site.key] or DockConfig.Decorations[site.key])
	if site and built then
		local progress = math.clamp(tonumber(site.progress) or 0, 0, 1)
		local work = if DockConfig.Buildings[site.key]
			then BuildTimer.work(built.cash)
			else BuildTimer.DECOR
		return {
			kind = "Site",
			key = site.key,
			name = built.name,
			price = built.cash,
			cash = f.cash,
			progress = progress,
			timeLeft = BuildTimer.timeLeft(progress, tonumber(site.rate) or 1, work),
		}
	end
	for _, key in DockConfig.BUILDINGS do
		local b = DockConfig.Buildings[key]
		if f.owned[key] ~= true and UnlockTree.missing(key, f.owned) == nil then
			return {
				kind = "Build",
				key = key,
				name = b.name,
				price = b.cash,
				cash = f.cash,
				progress = math.clamp(f.cash / math.max(b.cash, 1), 0, 1),
			}
		end
	end
	return nil
end

return NextGoal
