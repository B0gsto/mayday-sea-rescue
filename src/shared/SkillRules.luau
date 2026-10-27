--!strict
-- SkillRules (docs/25 F, K3): the radial player + survivor skill tree's data and pure rules.
-- Four sectors spread from the centre (Captain 315, Rescue 45, Crew 135, Industry 225; 0 = up,
-- clockwise) plus four grey bridges at 0/90/180/270 on ring 2.75. Each keystone carries its minor
-- path (`minor = { kind, amount, count }`); nodes() expands the dots as `<keystone>_m<i>`, chained
-- from the keystone's first need out to the keystone. Medals only (docs/25 I.1); the old Cash tree
-- is kept in LEGACY so ProgressionRules can refund it once.
-- Effects are summed as deltas (owned -> effects): multipliers read `1 + delta` (speedMult, swimMult,
-- gatherMult, payBonus, buildRate, tripPayMult) or `1 - delta` (boatScale, tripScale); everything
-- else is added. extraSlots is per K1 category (the building that gets the place).
local SkillRules = {}

export type Effect = { kind: string, amount: number }
export type Minor = { kind: string, amount: number, count: number }
export type Node = {
	id: string,
	sector: string,
	ring: number, -- 1..4, 5 for the rim; bridges 2.75
	angle: number, -- degrees, absolute (0 = up, clockwise)
	name: string,
	icon: string, -- a UiImages.Kit key, "" for no art
	medals: number,
	needs: { string }, -- any one owned; a keystone's first need is its own last dot
	effect: Effect,
	focus: string, -- "Captain" | a K1 Category | "Any" (the camera's tap-to-focus target)
	keystone: boolean,
	soon: boolean, -- an update's rim node: shown, never buyable
	minor: Minor?, -- keystones only: the generated dots on the way here
}

SkillRules.SECTORS = { "Captain", "Rescue", "Crew", "Industry", "Bridge" }
SkillRules.SECTOR_ANGLE = { Captain = 315, Rescue = 45, Crew = 135, Industry = 225 }
-- Slots are published per K1 category (SkillService's `SkillSlots<category>` attributes).
SkillRules.FOCUS_CATEGORIES = { "Builder", "Hauler", "Gatherer", "Mechanic", "Medic", "Rescuer" }
SkillRules.MINOR_MEDALS = 1
SkillRules.KEYSTONE_MEDALS = { 3, 3, 5, 5 } -- by ring 1..4
SkillRules.BRIDGE_MEDALS = 4
SkillRules.GOLD_MEDALS = 1
SkillRules.QUEST_MEDALS = 3
SkillRules.HQ_MEDALS = 5

type Row = {
	id: string,
	ring: number,
	offset: number, -- -1..1 across the sector; angle = sector centre + offset * 36
	name: string,
	icon: string,
	needs: { string },
	kind: string,
	amount: number,
	minorKind: string,
	minorAmount: number,
	focus: string,
	soon: boolean?,
}

local function node(
	id: string,
	ring: number,
	offset: number,
	icon: string,
	needs: { string },
	kind: string,
	amount: number,
	minorKind: string,
	minorAmount: number,
	focus: string,
	soon: boolean?
): Row
	return {
		id = id,
		ring = ring,
		offset = offset,
		name = id,
		icon = icon,
		needs = needs,
		kind = kind,
		amount = amount,
		minorKind = minorKind,
		minorAmount = minorAmount,
		focus = focus,
		soon = soon,
	}
end

-- The 1-3 word labels from docs/25 F (the ids stay PascalCase for saves and the K3 contract).
local NAMES = {
	LongReach = "Long Reach",
	BoatCall = "Boat Call",
	GoldenEye = "Golden Eye",
	TuneUp = "Tune-up",
	FirstAid = "First Aid",
	FastLaunch = "Fast Launch",
	SpareParts = "Spare Parts",
	BigBoat = "Big Boat",
	AirPatrol = "Air Patrol",
	GlowUp = "Glow Up",
	DeepDivers = "Deep Divers",
	LuckyFlare = "Lucky Flare",
	TeamSpirit = "Team Spirit",
	BigFamily = "Big Family",
	GoldenMayday = "Golden Mayday",
	StrongBacks = "Strong Backs",
	FreshCatch = "Fresh Catch",
	HardHats = "Hard Hats",
	HandCarts = "Hand Carts",
	MarketDay = "Market Day",
	DoubleSite = "Double Site",
	NightShift = "Night Shift",
	GoldenBricks = "Golden Bricks",
	WelcomeHome = "Welcome Home",
	StormRider = "Storm Rider",
	Celebrity = "Celebrity Visits",
}

local SECTOR_NODES = {
	{
		sector = "Captain",
		nodes = {
			node("Throttle", 1, -0.5, "bolt", {}, "speedMult", 0.04, "speedMult", 0.02, "Captain"),
			node("Fins", 1, 0.5, "drop", {}, "swimMult", 0.2, "swimMult", 0.03, "Captain"),
			node("LongReach", 2, -0.6, "buoy", { "Throttle" }, "reach", 3, "reach", 1, "Captain"),
			node(
				"Grip",
				2,
				0.15,
				"chev",
				{ "Throttle", "Fins" },
				"grip",
				0.25,
				"grip",
				0.05,
				"Captain"
			),
			node(
				"Nitro",
				3,
				-0.3,
				"bolt",
				{ "LongReach", "Grip" },
				"nitro",
				1,
				"speedMult",
				0.01,
				"Captain"
			), -- TODO reader
			node(
				"BoatCall",
				3,
				0.55,
				"boat",
				{ "Grip" },
				"boatScale",
				0.2,
				"boatScale",
				0.02,
				"Captain"
			),
			node(
				"Bounty",
				4,
				-0.6,
				"coin",
				{ "Nitro" },
				"payBonus",
				0.1,
				"payBonus",
				0.02,
				"Captain"
			),
			node(
				"GoldenEye",
				4,
				0.2,
				"eye",
				{ "Nitro", "BoatCall" },
				"goldenEye",
				1,
				"reach",
				1,
				"Captain"
			), -- TODO reader
			node(
				"StormRider",
				5,
				-0.25,
				"q",
				{ "Bounty", "GoldenEye" },
				"stormRider",
				1,
				"speedMult",
				0.03,
				"Captain",
				true
			),
		},
	},
	{
		sector = "Rescue",
		nodes = {
			node(
				"TuneUp",
				1,
				-0.5,
				"gear",
				{},
				"speedCapAdd",
				0.05,
				"speedCapAdd",
				0.01,
				"Mechanic"
			),
			node("FirstAid", 1, 0.5, "cross", {}, "medicCapAdd", 0.1, "medicCapAdd", 0.02, "Medic"),
			node(
				"FastLaunch",
				2,
				-0.55,
				"boat",
				{ "TuneUp" },
				"tripScale",
				0.15,
				"tripScale",
				0.02,
				"Rescuer"
			),
			node(
				"SpareParts",
				2,
				0.2,
				"gear",
				{ "TuneUp", "FirstAid" },
				"boatCapAdd",
				0.1,
				"boatCapAdd",
				0.02,
				"Mechanic"
			),
			node(
				"BigBoat",
				3,
				-0.3,
				"boat",
				{ "FastLaunch" },
				"boatSeats",
				2,
				"tripScale",
				0.02,
				"Rescuer"
			), -- TODO reader
			node(
				"Recruiter",
				3,
				0.55,
				"star",
				{ "SpareParts" },
				"recruitChance",
				0.05,
				"recruitChance",
				0.01,
				"Rescuer"
			),
			node(
				"AirPatrol",
				4,
				-0.5,
				"plane",
				{ "BigBoat" },
				"pilots",
				1,
				"tripScale",
				0.03,
				"Rescuer"
			), -- TODO reader
			node(
				"GlowUp",
				4,
				0.3,
				"cross",
				{ "BigBoat", "Recruiter" },
				"rarityUp",
				1,
				"recruitChance",
				0.01,
				"Medic"
			),
			node(
				"DeepDivers",
				5,
				0,
				"q",
				{ "AirPatrol", "GlowUp" },
				"deepDivers",
				1,
				"tripScale",
				0.03,
				"Rescuer",
				true
			),
		},
	},
	{
		sector = "Crew",
		nodes = {
			node("Bunks", 1, -0.5, "house", {}, "workerCapAdd", 5, "workerCapAdd", 1, "Any"),
			node(
				"LuckyFlare",
				1,
				0.5,
				"clover",
				{},
				"rareChanceAdd",
				0.1,
				"rareChanceAdd",
				0.02,
				"Any"
			),
			node(
				"TeamSpirit",
				2,
				-0.5,
				"heart",
				{ "Bunks" },
				"teamSpirit",
				0.05,
				"teamSpirit",
				0.01,
				"Any"
			),
			node(
				"Homecoming",
				2,
				0.3,
				"house",
				{ "Bunks", "LuckyFlare" },
				"offlineCapAdd",
				7200,
				"offlineRate",
				0.02,
				"Any"
			),
			node(
				"Clover",
				3,
				0.45,
				"clover",
				{ "Homecoming" },
				"traitReroll",
				1,
				"rareChanceAdd",
				0.02,
				"Any"
			),
			node(
				"Mentor",
				3,
				-0.35,
				"star",
				{ "TeamSpirit", "Homecoming" },
				"mentor",
				1,
				"workerCapAdd",
				1,
				"Any"
			),
			node(
				"BigFamily",
				4,
				-0.5,
				"house",
				{ "Mentor" },
				"workerCapAdd",
				10,
				"workerCapAdd",
				1,
				"Any"
			),
			node(
				"GoldenMayday",
				4,
				0.3,
				"sun",
				{ "Clover", "Mentor" },
				"goldenCalls",
				2,
				"rareChanceAdd",
				0.02,
				"Any"
			), -- TODO reader
			node(
				"Celebrity",
				5,
				0.1,
				"q",
				{ "GoldenMayday" },
				"celebrity",
				1,
				"rareChanceAdd",
				0.03,
				"Any",
				true
			), -- TODO reader
		},
	},
	{
		sector = "Industry",
		nodes = {
			node(
				"StrongBacks",
				1,
				0.5,
				"brick",
				{},
				"buildersCarry",
				2,
				"buildRate",
				0.01,
				"Builder"
			),
			node(
				"FreshCatch",
				1,
				-0.5,
				"fish",
				{},
				"gatherMult",
				0.15,
				"gatherMult",
				0.02,
				"Gatherer"
			),
			node(
				"HardHats",
				2,
				0.55,
				"hat",
				{ "StrongBacks" },
				"baseCrew",
				1,
				"buildRate",
				0.01,
				"Builder"
			),
			node(
				"HandCarts",
				2,
				-0.2,
				"cart",
				{ "StrongBacks", "FreshCatch" },
				"depotRefill",
				0.5,
				"depotRefill",
				0.05,
				"Hauler"
			),
			node(
				"MarketDay",
				3,
				-0.55,
				"fish",
				{ "HandCarts" },
				"extraSlots",
				1,
				"gatherMult",
				0.02,
				"Gatherer"
			),
			node(
				"DoubleSite",
				3,
				0.3,
				"brick",
				{ "HardHats", "HandCarts" },
				"doubleBuild",
				1,
				"buildRate",
				0.01,
				"Builder"
			), -- TODO reader
			node(
				"NightShift",
				4,
				-0.35,
				"moon",
				{ "MarketDay", "DoubleSite" },
				"offlineRate",
				0.1,
				"offlineRate",
				0.02,
				"Gatherer"
			),
			node(
				"GoldenBricks",
				4,
				0.45,
				"brick",
				{ "DoubleSite" },
				"buildRate",
				0.2,
				"buildRate",
				0.02,
				"Builder"
			),
			node(
				"Lumberjacks",
				5,
				0.45,
				"q",
				{ "GoldenBricks" },
				"lumberjacks",
				1,
				"gatherMult",
				0.03,
				"Gatherer",
				true
			), -- TODO reader
			node(
				"Miners",
				5,
				-0.1,
				"q",
				{ "NightShift" },
				"miners",
				1,
				"gatherMult",
				0.03,
				"Gatherer",
				true
			), -- TODO reader
		},
	},
} :: { { sector: string, nodes: { Row } } }

-- The four bridges join neighbouring sectors; `offset` is the absolute angle here.
local BRIDGES: { Row } = {
	node(
		"Lifeguard",
		2.75,
		0,
		"buoy",
		{ "BoatCall", "FastLaunch" },
		"boatSeats",
		1,
		"tripScale",
		0.02,
		"Captain"
	), -- TODO reader
	node(
		"WelcomeHome",
		2.75,
		90,
		"heart",
		{ "Recruiter", "TeamSpirit" },
		"arrivalPay",
		5,
		"payBonus",
		0.01,
		"Rescuer"
	),
	node(
		"Foreman",
		2.75,
		180,
		"hat",
		{ "Clover", "MarketDay" },
		"foreman",
		0.01,
		"buildRate",
		0.01,
		"Builder"
	), -- TODO reader
	node(
		"Salvage",
		2.75,
		270,
		"cart",
		{ "HardHats", "LongReach" },
		"salvage",
		1,
		"reach",
		1,
		"Hauler"
	), -- TODO reader
}

-- The old Cash tree (docs/24 G): ProgressionRules refunds every owned id here once, then drops it.
SkillRules.LEGACY = {
	CaptSpeed1 = 1000,
	CaptSpeed2 = 1500,
	CaptSpeed3 = 2500,
	CaptGrip = 1600,
	CaptReach = 1800,
	CaptPay1 = 2800,
	CaptBoatCall = 3000,
	CaptPay2 = 6000,
	CaptSwim = 8000,
	Build1 = 1200,
	Build2 = 1700,
	Build3 = 2800,
	BuildCrew = 4500,
	BuildBase = 6000,
	Gather1 = 1300,
	Gather2 = 1800,
	Gather3 = 3000,
	GatherNight = 3500,
	GatherStall = 5000,
	Rescue1 = 1500,
	Rescue2 = 2500,
	Rescue3 = 6000,
	Mech1 = 2500,
	Mech2 = 7000,
	Medic1 = 3000,
	Medic2 = 6000,
	Crew1 = 1400,
	Crew2 = 2400,
	Crew3 = 3500,
	CrewRare1 = 3500,
	CrewRare2 = 40000,
} :: { [string]: number }

SkillRules.KINDS = {
	"speedMult",
	"grip",
	"reach",
	"boatScale",
	"payBonus",
	"swimMult",
	"buildRate",
	"extraBuilders",
	"baseCrew",
	"gatherMult",
	"offlineRate",
	"tripScale",
	"recruitChance",
	"tripPayMult",
	"speedCapAdd",
	"boatCapAdd",
	"medicCapAdd",
	"medicPerUnit",
	"workerCapAdd",
	"rareChanceAdd",
	-- docs/25 F abilities (a node still marked TODO reader has no reader yet)
	"nitro",
	"goldenEye",
	"boatSeats",
	"traitReroll",
	"mentor",
	"goldenCalls",
	"salvage",
	"arrivalPay",
	"foreman",
	"offlineCapAdd",
	"teamSpirit",
	"doubleBuild",
	"depotRefill",
	"buildersCarry",
	"rarityUp",
	"pilots",
	"stormRider",
	"celebrity",
	"lumberjacks",
	"miners",
}

local function medalsFor(ring: number, keystone: boolean, bridge: boolean): number
	if not keystone then
		return SkillRules.MINOR_MEDALS
	end
	if bridge then
		return SkillRules.BRIDGE_MEDALS
	end
	return SkillRules.KEYSTONE_MEDALS[math.clamp(math.ceil(ring), 1, 4)]
end

-- The dots in a keystone's path: 2 near the centre, 4 on the outer rings.
local function minorCount(ring: number): number
	return math.clamp(math.ceil(ring), 2, 4)
end

-- Shortest way round the compass from a to b.
local function angleToward(a: number, b: number, t: number): number
	local d = (b - a + 540) % 360 - 180
	return (a + d * t) % 360
end

local function expand(): { Node }
	local out: { Node } = {}
	local keys: { [string]: Node } = {}

	local function add(n: Node)
		keys[n.id] = n
		table.insert(out, n)
	end

	for _, def in SECTOR_NODES do
		local centre = SkillRules.SECTOR_ANGLE[def.sector]
		for _, r in def.nodes do
			add({
				id = r.id,
				sector = def.sector,
				ring = r.ring,
				angle = (centre + r.offset * 36) % 360,
				name = NAMES[r.id] or r.id,
				icon = r.icon,
				medals = medalsFor(r.ring, true, false),
				needs = r.needs,
				effect = { kind = r.kind, amount = r.amount },
				focus = r.focus,
				keystone = true,
				soon = r.soon == true,
				minor = {
					kind = r.minorKind,
					amount = r.minorAmount,
					count = minorCount(r.ring),
				},
			})
		end
	end
	for _, r in BRIDGES do
		add({
			id = r.id,
			sector = "Bridge",
			ring = 2.75,
			angle = r.offset,
			name = NAMES[r.id] or r.id,
			icon = r.icon,
			medals = medalsFor(r.ring, true, true),
			needs = r.needs,
			effect = { kind = r.kind, amount = r.amount },
			focus = r.focus,
			keystone = true,
			soon = false,
			minor = {
				kind = r.minorKind,
				amount = r.minorAmount,
				count = minorCount(r.ring),
			},
		})
	end

	-- The minor dots sit between the keystone and its first need (the centre for a ring-1 node).
	for _, k in table.clone(out) do
		local minor = k.minor :: Minor
		local from = if #k.needs > 0 then keys[k.needs[1]] else nil
		local fromRing = if from then from.ring else 0
		local fromAngle = if from then from.angle else k.angle
		local previous = if from then from.id else nil
		for i = 1, minor.count do
			local t = i / (minor.count + 1)
			local id = `{k.id}_m{i}`
			local n: Node = {
				id = id,
				sector = k.sector,
				ring = fromRing + (k.ring - fromRing) * t,
				angle = angleToward(fromAngle, k.angle, t),
				name = k.name,
				icon = k.icon,
				medals = SkillRules.MINOR_MEDALS,
				needs = if previous then { previous } else {},
				effect = { kind = minor.kind, amount = minor.amount },
				focus = k.focus,
				keystone = false,
				soon = k.soon,
			}
			add(n)
			previous = id
		end
		-- the keystone is reached through its own dots (its other needs stay direct links)
		if previous and minor.count > 0 then
			k.needs = { previous :: string, table.unpack(k.needs, 2) }
		end
	end
	return out
end

SkillRules.NODES = expand()
SkillRules.byId = {}
for _, n in SkillRules.NODES do
	SkillRules.byId[n.id] = n
end

function SkillRules.nodes(): { Node }
	return SkillRules.NODES
end

-- Every effect kind summed over the owned nodes (extraSlots per K1 category), zero for the rest.
function SkillRules.effects(owned: { [string]: boolean }): { [string]: any }
	local out: { [string]: any } = {}
	for _, kind in SkillRules.KINDS do
		out[kind] = 0
	end
	out.extraSlots = {}
	for id in owned do
		local n = SkillRules.byId[id]
		if n then
			local kind = n.effect.kind
			if kind == "extraSlots" then
				out.extraSlots[n.focus] = (out.extraSlots[n.focus] or 0) + n.effect.amount
			elseif out[kind] ~= nil then
				out[kind] += n.effect.amount
			end
		end
	end
	return out
end

-- May `id` be bought? -> ok, reason: "Owned" | "Soon" | "Needs" | "Medals" | "Unknown" (nil when ok).
function SkillRules.canBuy(
	owned: { [string]: boolean },
	id: string,
	medals: number
): (boolean, string?)
	local n = if type(id) == "string" then SkillRules.byId[id] else nil
	if not n then
		return false, "Unknown"
	end
	if n.soon then
		return false, "Soon"
	end
	if owned[id] == true then
		return false, "Owned"
	end
	local ready = #n.needs == 0
	for _, need in n.needs do
		if owned[need] == true then
			ready = true
			break
		end
	end
	if not ready then
		return false, "Needs"
	end
	if (tonumber(medals) or 0) < n.medals then
		return false, "Medals"
	end
	return true, nil
end

-- Medals back for a free reset: the sum of every owned node's medal price.
function SkillRules.refund(owned: { [string]: boolean }): number
	local total = 0
	for id, on in owned do
		local n = if on == true then SkillRules.byId[id] else nil
		if n then
			total += n.medals
		end
	end
	return total
end

-- People rescued -> Medals: 1 per 2 people, counted on the running total so odd deliveries add up.
function SkillRules.rescueMedals(before: number, after: number): number
	local a = math.max(0, math.floor(tonumber(before) or 0))
	local b = math.max(a, math.floor(tonumber(after) or 0))
	return math.floor(b / 2) - math.floor(a / 2)
end

-- The daily chest's 1-3 Medals, cycling with the streak.
function SkillRules.chestMedals(streak: number): number
	local s = math.max(1, math.floor(tonumber(streak) or 1))
	return 1 + (s - 1) % 3
end

return SkillRules
