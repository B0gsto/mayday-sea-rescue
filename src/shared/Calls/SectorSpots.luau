--!strict
-- SectorSpots (docs/31 B.2): one far destination in each 60-deg sector round the ring that had none (the -Z half), so a
-- player there has somewhere to head. Pure data, no requires (Lune-safe). CallTypes makes each a spawn zone (a ring of
-- open water round it), CallLogic.isWater keeps spawns out of its dressing, AmbientMix sends FAR survivors there, and
-- server/World/SectorSpots dresses it with finished M_Prop_HubKit pieces (SeamarkRules adds a lit danger mark).
--   bearing: deg round RingLayout.Center, atan2(z, x) like RingLayout's plot bearings; radius: the dressing's extent.
local SectorSpots = {}

export type Spot = {
	id: string,
	name: string,
	zone: string,
	bearing: number,
	center: Vector3,
	radius: number,
}

SectorSpots.Spots = {
	-- bearing 212, r 2,200: a cluster of sea stacks (212, not 210: clear of SeaLife flotsam at (-2000, -1000))
	{
		id = "GullStacks",
		name = "Gull Stacks",
		zone = "KelpBanks",
		bearing = 212,
		center = Vector3.new(-1866, 0, -1166),
		radius = 150,
	},
	-- bearing 270, r 3,400: a big wreck run aground between rocks
	{
		id = "WreckShoal",
		name = "Wreck Shoal",
		zone = "CoralDrift",
		bearing = 270,
		center = Vector3.new(0, 0, -3400),
		radius = 150,
	},
	-- bearing 330, r 4,600: a lighthouse rock (the hub's atoll and beacon), the tallest thing out there
	{
		id = "StormLight",
		name = "Storm Light",
		zone = "StormReach",
		bearing = 330,
		center = Vector3.new(3984, 0, -2300),
		radius = 150,
	},
} :: { Spot }

return SectorSpots
