--!strict
-- SeasonalEvents: the limited-time seasonal windows (docs/15 hook H7) as pure data, safe in Lune.
-- Halloween "Ghost Ship": 2026-10-24 00:00 UTC to 2026-11-02 23:59:59 UTC. Every reward is earned
-- with Candy Lanterns from rescues; nothing here is ever sold for Robux (docs/15 section 1).
-- Winter "Frost Fleet": 2026-12-12 00:00 UTC to 2027-01-04 23:59:59 UTC, paid in Snowflakes; snow,
-- roof frost, quay/station string lights and a decorated tree are the dressing in Config below.
-- Studio: Workspace.SeasonalEventForce = true runs the event outside its dates.

export type Item = {
	id: string,
	name: string, -- stall prompt, 1-3 words
	price: number, -- the event currency
	flag: string, -- data.flags.<event> key, also the cosmetic check
}

export type LightRun = {
	from: Vector3,
	to: Vector3,
	height: number?, -- studs above the run points
	spacing: number?, -- studs between bulbs
}

export type Event = {
	id: string,
	name: string,
	startUtc: number,
	endUtc: number, -- inclusive
	currency: string?, -- stall label ("Candy Lanterns", "Snowflakes")
	currencyFlag: string?, -- the profile flag table ("halloween", "winter")
	candyEventRescue: number, -- the event big call
	candyAnyRescue: number, -- any other rescue while the event is on
	callCooldown: number, -- seconds between event calls when none is running
	callVariant: string?, -- the big-call variant tagged on the Capsized Ferry flow
	stallPosition: Vector3,
	stallFacing: number, -- yaw; the counter opens toward the harbour
	stallRange: number, -- studs, the server's purchase sanity check
	pumpkins: { Vector3 }?, -- quay and station lantern spots (ground)
	ferry: { center: Vector3, radius: number, speed: number }?, -- slow loop, rad/s
	night: { witchingMinute: number, witchingMinutes: number }?, -- the nightly fog window (UTC)
	tree: Vector3?, -- the decorated tree (ground)
	lightRuns: { LightRun }?, -- string lights along the quay / station front
	snow: boolean?, -- snow all day (the client keeps it off for new players)
	items: { Item },
}

local Halloween: Event = {
	id = "Halloween",
	name = "Ghost Ship",
	startUtc = 1792800000, -- 2026-10-24 00:00:00 UTC
	endUtc = 1793663999, -- 2026-11-02 23:59:59 UTC
	currency = "Candy Lanterns",
	currencyFlag = "halloween",
	callVariant = "GhostShip",
	candyEventRescue = 5,
	candyAnyRescue = 1,
	callCooldown = 20 * 60,
	stallPosition = Vector3.new(24, 4, -12),
	stallFacing = 0, -- opens toward +Z, the water
	stallRange = 24,
	pumpkins = {
		-- quay edge (z just inside the harbour front)
		Vector3.new(-170, 4, 2),
		Vector3.new(-140, 4, 2),
		Vector3.new(-110, 4, 2),
		Vector3.new(-80, 4, 2),
		Vector3.new(-50, 4, 2),
		Vector3.new(-20, 4, 2),
		Vector3.new(10, 4, 2),
		Vector3.new(40, 4, 2),
		Vector3.new(70, 4, 2),
		Vector3.new(100, 4, 2),
		Vector3.new(130, 4, 2),
		Vector3.new(160, 4, 2),
		-- station front (the door faces the quay)
		Vector3.new(-136, 4, -39),
		Vector3.new(-124, 4, -39),
		Vector3.new(-112, 4, -39),
		Vector3.new(-100, 4, -39),
		Vector3.new(-88, 4, -39),
	},
	ferry = { center = Vector3.new(0, 0, 190), radius = 120, speed = 0.018 },
	-- Night and fog run only while a Ghost Ship call is up and during the 15-minute witching hour at
	-- :45 each hour. The rest of the event is daylight (the pumpkins stay, lit dimly).
	night = { witchingMinute = 45, witchingMinutes = 15 },
	items = {
		{ id = "Livery", name = "Lantern livery", price = 18, flag = "livery" },
		{ id = "Collar", name = "Ghost collar", price = 12, flag = "collar" },
		{ id = "Decor", name = "Bay pumpkin", price = 10, flag = "decor" },
	},
}

-- Winter "Frost Fleet": a parade of lit boats iced in off the harbour mouth. The big call runs on the
-- Capsized Ferry join flow tagged "FrostFleet"; the client builds the boats, the ice floes and the
-- hold-to-break prompts around the call's casualties. The tree and the light runs are on the quay
-- (z just inside the harbour front) as in the Halloween pumpkin spots.
local Winter: Event = {
	id = "Winter",
	name = "Frost Fleet",
	startUtc = 1797033600, -- 2026-12-12 00:00:00 UTC
	endUtc = 1799107199, -- 2027-01-04 23:59:59 UTC
	currency = "Snowflakes",
	currencyFlag = "winter",
	callVariant = "FrostFleet",
	candyEventRescue = 5,
	candyAnyRescue = 1,
	callCooldown = 20 * 60,
	stallPosition = Vector3.new(24, 4, -12),
	stallFacing = 0, -- opens toward +Z, the water
	stallRange = 24,
	tree = Vector3.new(64, 4, -8),
	lightRuns = {
		{ from = Vector3.new(-160, 4, 6), to = Vector3.new(160, 4, 6), height = 9, spacing = 20 },
		{
			from = Vector3.new(-136, 4, -36),
			to = Vector3.new(-88, 4, -36),
			height = 7,
			spacing = 16,
		},
	},
	snow = true,
	items = {
		{ id = "Livery", name = "Festive livery", price = 18, flag = "livery" },
		{ id = "Scarf", name = "Bosun scarf", price = 12, flag = "scarf" },
		{ id = "Decor", name = "Snowman", price = 10, flag = "decor" },
	},
}

local SeasonalEvents = {}

SeasonalEvents.Halloween = Halloween
SeasonalEvents.Winter = Winter
SeasonalEvents.List = { Halloween, Winter } :: { Event }
SeasonalEvents.DevAttribute = "SeasonalEventForce"

function SeasonalEvents.get(id: string): Event?
	for _, event in SeasonalEvents.List do
		if event.id == id then
			return event
		end
	end
	return nil
end

return SeasonalEvents
