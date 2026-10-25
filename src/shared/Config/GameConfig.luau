--!strict
-- GameConfig: world layout and storm timings. Pure data (no services), safe to load in Lune
-- (tests and map/Build.luau read it, so the greybox map and the game agree on zone shapes).
--
-- World frame: sea level is Y = 0. Port Haven town is on land to the north (-Z); the harbour opens
-- south (+Z). Calm Bay sits inside the breakwater; the gap in the breakwater is Harbour Mouth;
-- beyond it is open sea. Numbers without a doc source are marked -- tune.

export type Zone = {
	id: string,
	displayName: string,
	center: Vector3, -- at sea level
	radius: number, -- studs, horizontal (XZ) distance
	shelter: number, -- 0 = open sea, 1 = fully sheltered; feeds Waves.paramsFor
	priority: number, -- where zones overlap, the highest priority wins
}

local GameConfig = {
	SeaLevel = 0,
	OceanFloorY = -40,
	LandTopY = 4, -- quay and town ground height
	MapRadius = 7000, -- playable radius from the origin (matches WorldConfig.MapRadius; docs/21 archipelago) -- tune

	-- Ordered from most specific to least.
	Zones = {
		{
			id = "HarbourMouth",
			displayName = "Harbour Mouth",
			center = Vector3.new(0, 0, 368),
			radius = 60, -- tune
			shelter = 0.4, -- tune
			priority = 3,
		},
		{
			id = "PortHaven",
			displayName = "Port Haven",
			center = Vector3.new(0, 0, -60),
			radius = 200, -- tune
			shelter = 0.9, -- tune
			priority = 2,
		},
		{
			id = "CalmBay",
			displayName = "Calm Bay",
			center = Vector3.new(0, 0, 190),
			radius = 300, -- tune
			shelter = 0.8, -- docs 02 section 8: small waves even in a storm -- tune
			priority = 1,
		},
		{
			id = "MermaidLagoon", -- docs/21: the ring of isles shelters the lagoon (WorldConfig.Islands)
			displayName = "Mermaid Lagoon",
			center = Vector3.new(300, 0, 5600),
			radius = 600, -- tune
			shelter = 0.8, -- tune
			priority = 1,
		},
	} :: { Zone },

	OpenSea = { id = "OpenSea", displayName = "Open Sea", shelter = 0 },

	-- Storm cycle, docs 02 section 8 and docs 06 section 3.4 (full cycle 15 min).
	Storm = {
		CalmSeconds = 600, -- tune
		WarningSeconds = 60, -- tune
		StormSeconds = 180, -- tune
		ClearingSeconds = 60, -- tune
		GreatStormSeconds = 240, -- summoned Great Storm phase (docs 04 section 5)
		WaveHeightMultiplier = 2.5, -- storm waves x2.5 height (Waves.STORM is built to match)
		CallRateMultiplier = 3,
		PayoutMultiplier = 1.5,
	},
}

return GameConfig
