--!strict
-- MonetizationConfig: the Robux catalogue (docs/04 sections 3 and 4). Prices follow docs/04.
--
-- Shape read by ~/RobloxProjects/tools/dump-monetization.luau, make-item-icons.py and deploy.py:
--   Products / GamePasses = { [Key] = Item }, and `id` MUST stay the first field of every item
--   (deploy.py --steps config rewrites `id = <n>,` in place).
--
-- * `id = 0` means not for sale: MonetizationService ignores the item, the shelves hide it and no prompt
--   opens for it. RP-M4 creates the items on the universe and deploy.py writes the real ids here.
-- * `ready = false` means its effect is not built yet: never for sale even with an id, and deploy.py does
--   not create it. RP-M2 flips `ready` as each effect lands.
-- * `price` is the docs/04 price used when the item is created. UI always shows the price Roblox returns
--   (regional pricing, docs/04 section 8), never this number.
-- * `paidRandom` marks a random-outcome item (none at launch; docs/04 section 8). Such items are hidden
--   wherever PolicyService restricts paid random items, or when the policy check failed.
-- * Developer Products are consumables (bought again and again); Game Passes are owned forever.
--   Nothing here changes call timers, step grades or a casualty's condition (docs/04 §7).

export type Item = {
	id: number,
	name: string,
	description: string,
	price: number,
	order: number,
	ready: boolean?,
	paidRandom: boolean?,
	-- effect data read by the effect owners (RP-M2); all optional
	cashMultiplier: number?, -- 2x Cash pass, Cash Boost, Crew Boost (crew-wide)
	cashOnce: number?, -- Starter Kit: Cash granted once
	cashMinutes: number?, -- Cash packs: minutes of the top zone's Cash rate
	valueBonus: number?, -- Cash packs: extra value on top (0.1 = +10%)
	boostMinutes: number?, -- timed boosts: minutes of playtime
	dailyLimit: number?, -- per account per day (Cash packs share one limit, see CashPackDailyLimit)
	stormTier: string?, -- Storm Summons: "Storm" or "GreatStorm" (docs/04 section 5)
	dayPassFor: string?, -- day passes: the GamePasses key whose effect this product lends
	dayPassHours: number?, -- day passes: hours of real time (the clock runs while away; buying again adds)
	vehicle: string?, -- vehicle passes: the VehicleConfig id it owns (offered once its building stands)
	spins: number?, -- spin-wheel products: free spins granted (docs/24 D)
	dockBuilding: string?, -- island buildings and decor (DockConfig.Buildings / Decorations key); sold at the
	-- build tablet only, once the building's prerequisites stand (Robux skips the Cash, never the order: docs/23 (q))
	crewHire: boolean?, -- crew hire (docs/23 (j), WP-15): Robux skips the Cash
}

local MonetizationConfig = {
	Products = {
		-- 4.1 Cash packs (scale with the highest open zone; the card shows the exact Cash first)
		SmallBonus = {
			id = 3719524891,
			name = "Small Bonus",
			description = "Cash equal to 15 minutes of your top open zone's Cash rate. Cash only.",
			price = 10,
			order = 1,
			ready = true,
			cashMinutes = 15,
			valueBonus = 0,
		},
		CrewPayroll = {
			id = 3719524897,
			name = "Crew Payroll",
			description = "Cash equal to 45 minutes of your top open zone's Cash rate. Cash only.",
			price = 25,
			order = 2,
			ready = true,
			cashMinutes = 45,
			valueBonus = 0,
		},
		StationBudget = {
			id = 3719524917,
			name = "Station Budget",
			description = "Cash equal to 2.5 hours of your top open zone's Cash rate, plus 10%. Cash only.",
			price = 75,
			order = 3,
			ready = true,
			cashMinutes = 150,
			valueBonus = 0.1,
		},
		HarborFund = {
			id = 3719524924,
			name = "Harbor Fund",
			description = "Cash equal to 7 hours of your top open zone's Cash rate, plus 20%. Cash only.",
			price = 149,
			order = 4,
			ready = true,
			cashMinutes = 420,
			valueBonus = 0.2,
		},
		-- 4.2 Other products
		CashBoost = {
			id = 3719524939,
			name = "Cash Boost",
			description = "2x Cash for 30 minutes of playtime. The timer pauses while you are away. Does not stack with the 2x Cash pass.",
			price = 15,
			order = 5,
			ready = true,
			cashMultiplier = 2,
			boostMinutes = 30,
		},
		CrewBoost = {
			id = 3719524950,
			name = "Crew Boost",
			description = "+50% Cash for you and everyone in your crew for 20 minutes of playtime. One active per crew. Cash only.",
			price = 15,
			order = 6,
			ready = true,
			cashMultiplier = 1.5,
			boostMinutes = 20,
		},
		-- Finish now (owner 2026-10-26, docs/24 B): the tier is picked by the running site's time left; the
		-- owner creates the products on Roblox and flips `ready`.
		FinishNow1 = {
			id = 3722675352,
			name = "Finish Now 1",
			description = "Finishes your running build at once. For a build with up to 1 minute left.",
			price = 9,
			order = 21,
			ready = true,
		},
		FinishNow2 = {
			id = 3722675361,
			name = "Finish Now 2",
			description = "Finishes your running build at once. For a build with up to 5 minutes left.",
			price = 25,
			order = 22,
			ready = true,
		},
		FinishNow3 = {
			id = 3722675370,
			name = "Finish Now 3",
			description = "Finishes your running build at once. For a longer-running build.",
			price = 49,
			order = 23,
			ready = true,
		},
		CallTheStorm = {
			id = 3719524960,
			name = "Call the Storm",
			description = "Brings a server-wide storm to the Gale Isles for everyone in the server. Joins the server's storm queue.",
			price = 49,
			order = 8,
			ready = false, -- weather is always sunny (StormService.ALWAYS_SUNNY)
			stormTier = "Storm",
		},
		CallTheGreatStorm = {
			id = 3719525027,
			name = "Call the Great Storm",
			description = "Brings a bigger server-wide storm with a guaranteed big call for everyone in the server. Joins the server's storm queue.",
			price = 149,
			order = 9,
			ready = false, -- weather is always sunny (StormService.ALWAYS_SUNNY)
			stormTier = "GreatStorm",
		},
		-- Day passes (proposed prices, not in docs/04 yet): a game pass's effect for 24 hours of real
		-- time. MonetizationService.OwnsPass accepts a running one. No Day VIP until VipCrewCard is ready.
		DayDoubleCash = {
			id = 3721024854,
			name = "Day 2x Cash",
			description = "The 2x Cash pass for 24 hours of real time. The clock keeps running while you are away. Buy again to add a day.",
			price = 15,
			order = 11,
			ready = true,
			dayPassFor = "DoubleCash",
			dayPassHours = 24,
		},
		DayQuickLaunch = {
			id = 3721024872,
			name = "Day Quick Launch",
			description = "The Quick Launch pass for 24 hours of real time. The clock keeps running while you are away. Buy again to add a day.",
			price = 10,
			order = 12,
			ready = true,
			dayPassFor = "QuickLaunch",
			dayPassHours = 24,
		},
		-- docs/23 WP-4, WP-28: island buildings of the unlock tree (DockConfig.Buildings `product`), sold at the build
		-- tablet, granted by DockService once their prerequisites stand. The keys and ids are the old dock levels'.
		-- Prices: docs/23 (i) economy check (never a better Cash deal than the Cash packs).
		DockLevel2 = {
			id = 3722223190,
			name = "Pontoon",
			description = "Builds the pontoon on your island now, no Cash needed: a second berth, lamp posts, your flag and a rescue board.",
			price = 35,
			order = 31,
			ready = true,
			dockBuilding = "Pontoon",
		},
		DockLevel3 = {
			id = 3722223199,
			name = "Boathouse",
			description = "Builds the boathouse on your island now, no Cash needed (needs the workshop): pick and paint boats.",
			price = 35,
			order = 32,
			ready = true,
			dockBuilding = "Boathouse",
		},
		DockLevel4 = {
			id = 3722223208,
			name = "Lookout Tower",
			description = "Builds the lookout tower on your island now, no Cash needed (needs the pontoon).",
			price = 75,
			order = 33,
			ready = true,
			dockBuilding = "LookoutTower",
		},
		DockLevel5 = {
			id = 3722223223,
			name = "Station",
			description = "Builds the lit station and its beacon now, no Cash needed (needs the boathouse and the lookout tower).",
			price = 199,
			order = 34,
			ready = true,
			dockBuilding = "Station",
		},
		DockGarage = {
			id = 3722223237,
			name = "Car Garage",
			description = "Builds your garage now, no Cash needed: pick a car at its board and drive it out.",
			price = 75,
			order = 35,
			ready = false, -- cut 2026-10-25 (pre-hub-cut)
			dockBuilding = "Garage",
		},
		DockHangar = {
			id = 3722223246,
			name = "Hangar",
			description = "Builds the hangar on your island now, no Cash needed (needs the helipad).",
			price = 149,
			order = 36,
			ready = true,
			dockBuilding = "Hangar",
		},
		DockSubPen = {
			id = 3722223257,
			name = "Sub Pen",
			description = "Builds a sub pen beside your berth now, no Cash needed (needs the crane).",
			price = 149,
			order = 37,
			ready = true,
			dockBuilding = "SubPen",
		},
		-- WP-28 (2026-10-26): the rest of the tree and the decorations (DockConfig `product`); prices docs/23 (i).
		DockWorkshop = {
			id = 3722386053,
			name = "Workshop",
			description = "Builds the workshop on your island now, no Cash needed: Builders work here.",
			price = 15,
			order = 39,
			ready = true,
			dockBuilding = "Workshop",
		},
		DockFishShed = {
			id = 3722386064,
			name = "Fish Shed",
			description = "Builds the fish shed on your island now, no Cash needed: Gatherers work here.",
			price = 35,
			order = 40,
			ready = true,
			dockBuilding = "FishShed",
		},
		DockBoatYard = {
			id = 3722386073,
			name = "Boat Yard",
			description = "Builds the boat yard on your island now, no Cash needed (needs the workshop): Mechanics work here.",
			price = 75,
			order = 41,
			ready = true,
			dockBuilding = "BoatYard",
		},
		DockLifeboatSlip = {
			id = 3722386079,
			name = "Lifeboat Slip",
			description = "Builds the lifeboat slip on your island now, no Cash needed (needs the boathouse).",
			price = 99,
			order = 42,
			ready = true,
			dockBuilding = "LifeboatSlip",
		},
		DockCrane = {
			id = 3722386091,
			name = "Crane",
			description = "Builds the slipway crane on your island now, no Cash needed (needs the boathouse).",
			price = 99,
			order = 43,
			ready = true,
			dockBuilding = "Crane",
		},
		DockHelipad = {
			id = 3722386100,
			name = "Helipad",
			description = "Builds the helipad on your island now, no Cash needed (needs the lookout tower).",
			price = 99,
			order = 44,
			ready = true,
			dockBuilding = "Helipad",
		},
		DockRescueBoathouse = {
			id = 3722386108,
			name = "Rescue Boathouse",
			description = "Builds the rescue boathouse on your island now, no Cash needed (needs the lookout tower): Rescuers work here.",
			price = 99,
			order = 45,
			ready = true,
			dockBuilding = "RescueBoathouse",
		},
		DockTrophyHall = {
			id = 3722386118,
			name = "Trophy Hall",
			description = "Builds the trophy hall on your station now, no Cash needed (needs the station).",
			price = 149,
			order = 46,
			ready = true,
			dockBuilding = "TrophyHall",
		},
		DockClinic = {
			id = 3722386124,
			name = "Clinic",
			description = "Builds the clinic on your island now, no Cash needed (needs the station): Medics work here.",
			price = 199,
			order = 47,
			ready = true,
			dockBuilding = "Clinic",
		},
		DecorFlowerBed = {
			id = 3722386134,
			name = "Flower Bed",
			description = "Places a bright Lego flower bed by your spawn, no Cash needed. Decoration.",
			price = 35,
			order = 48,
			ready = true,
			dockBuilding = "FlowerBed",
		},
		DecorPicnicTable = {
			id = 3722386143,
			name = "Picnic Table",
			description = "Places a picnic table by your spawn, no Cash needed. Decoration.",
			price = 49,
			order = 49,
			ready = true,
			dockBuilding = "PicnicTable",
		},
		DecorLampRow = {
			id = 3722386151,
			name = "Lamp Row",
			description = "Places a row of lamps that glow at night, no Cash needed. Decoration.",
			price = 75,
			order = 50,
			ready = true,
			dockBuilding = "LampRow",
		},
		DecorFlagPole = {
			id = 3722386157,
			name = "Flag Pole",
			description = "Places a tall flag pole flying your colours, no Cash needed. Decoration.",
			price = 99,
			order = 51,
			ready = true,
			dockBuilding = "FlagPole",
		},
		DecorStatue = {
			id = 3722386162,
			name = "Statue",
			description = "Places a hero statue on your island, no Cash needed. Decoration.",
			price = 199,
			order = 52,
			ready = true,
			dockBuilding = "Statue",
		},
		DecorFountain = {
			id = 3722386169,
			name = "Fountain",
			description = "Places a splashing fountain in your square, no Cash needed. Decoration.",
			price = 199,
			order = 53,
			ready = true,
			dockBuilding = "Fountain",
		},
		-- Retired (WP-26): the job-seeker line is gone, rescued people are the workers now. Kept, never sold.
		CrewHire = {
			id = 0,
			name = "Crew Hire",
			description = "Hire the job seeker you are standing beside for Robux, without the Cash price.",
			price = 99,
			order = 38,
			ready = false, -- WP-26: retired with the crew lineup; never flip
			crewHire = true,
		},
		-- Spin wheel (docs/24 D): paid random items, so they carry `paidRandom` and the wheel shows the
		-- odds. ready = false until the owner creates the products; the id stays 0 until then.
		Spin1 = {
			id = 3722675390,
			name = "One Spin",
			description = "One spin of the prize wheel. Odds and pity are shown on the wheel.",
			price = 49,
			order = 54,
			ready = true,
			paidRandom = true,
			spins = 1,
		},
		Spin5 = {
			id = 3722675407,
			name = "Five Spins",
			description = "Five spins of the prize wheel. Odds and pity are shown on the wheel.",
			price = 199,
			order = 55,
			ready = true,
			paidRandom = true,
			spins = 5,
		},
		Spin15 = {
			id = 3722675411,
			name = "Fifteen Spins",
			description = "Fifteen spins of the prize wheel. Odds and pity are shown on the wheel.",
			price = 499,
			order = 56,
			ready = true,
			paidRandom = true,
			spins = 15,
		},
	} :: { [string]: Item },

	GamePasses = {
		DoubleCash = {
			id = 2040015521,
			name = "2x Cash",
			description = "Doubles Cash from every rescue.",
			price = 75,
			order = 1,
			ready = true,
			cashMultiplier = 2,
		},
		VipCrewCard = {
			id = 0,
			name = "VIP Crew Card",
			description = "Gold nameplate, VIP Gold livery for every vehicle.",
			price = 299,
			order = 2,
			ready = false,
		},
		QuickLaunch = {
			id = 2036073727,
			name = "Quick Launch",
			description = "Skip the launch cooldown and launch any owned vehicle straight into the seat from anywhere. Never affects survivors or grades.",
			price = 49,
			order = 3,
			ready = true, -- server path RP-M2, BoatDesk use card RP-A1
		},
		StarterKit = {
			id = 2036091711,
			name = "Starter Kit",
			description = "3,000 Cash, paid once. Owners also get the Station Orange livery and a Bosun bandana when they arrive in a later update.",
			price = 25,
			order = 4,
			ready = true,
			cashOnce = 3000,
		},
		BosunsWardrobe = {
			id = 0,
			name = "Bosun's Wardrobe",
			description = "Three Newfoundland coat colours, six bandanas, a dog life jacket and a tiny captain's hat for Bosun. Cosmetic.",
			price = 129,
			order = 5,
			ready = false,
		},
		WaterDogFriends = {
			id = 0,
			name = "Water Dog Friends",
			description = "A Labrador and a Portuguese Water Dog to swap with Bosun. Same abilities as Bosun. Cosmetic.",
			price = 199,
			order = 6,
			ready = false,
		},
		StormChaserLiveries = {
			id = 0,
			name = "Storm Chaser Liveries",
			description = "Animated lightning-stripe liveries for every vehicle, new ones included, plus a storm-blue uniform. Cosmetic.",
			price = 249,
			order = 7,
			ready = false,
		},
		CaptainsLocker = {
			id = 0,
			name = "Captain's Locker",
			description = "A bright wetsuit, a foul-weather coat, three caps and a whistle emote. Cosmetic.",
			price = 99,
			order = 8,
			ready = false,
		},
		SeaShantyRadio = {
			id = 0,
			name = "Sea Shanty Radio",
			description = "An in-vehicle radio playing the game's own music. Other players can mute it.",
			price = 79,
			order = 9,
			ready = false,
		},
		-- 3.2 Vehicle cosmetics
		HornPack = {
			id = 0,
			name = "Horn Pack",
			description = "Six horns for every owned vehicle on a tap button. Other players can mute horns. Cosmetic.",
			price = 79,
			order = 10,
			ready = false,
		},
		SirenPack = {
			id = 0,
			name = "Siren Pack",
			description = "Four siren tones with matching light patterns for every owned vehicle. Other players can mute sirens. Cosmetic.",
			price = 99,
			order = 11,
			ready = false,
		},
		LightBars = {
			id = 0,
			name = "Light Bars",
			description = "Six light bar colour sets for every owned vehicle. Cosmetic.",
			price = 129,
			order = 12,
			ready = false,
		},
		WakeTrails = {
			id = 0,
			name = "Wake Trails",
			description = "Five wake trails for every owned vehicle: sparkle foam, rainbow, bubbles, petals and glow. Cosmetic.",
			price = 149,
			order = 13,
			ready = false,
		},
		-- Vehicle passes (2026-10-21, user): own the vehicle (ProgressionRules.vehiclePass); offered once its building stands;
		-- the premium six are Robux only (ProgressionConfig.Vehicles passOnly). Prices proposed -- tune.
		RIBPass = {
			id = 2044851404,
			name = "RIB Inflatable",
			description = "The RIB Inflatable: 3 crew, room for 3 survivors, fast and tough.",
			price = 49,
			order = 14,
			ready = true,
			vehicle = "RIB",
		},
		LifeboatPass = {
			id = 2046219317,
			name = "All-Weather Lifeboat",
			description = "The All-Weather Lifeboat: room for 8 survivors, steady and self-righting.",
			price = 129,
			order = 15,
			ready = true,
			vehicle = "Lifeboat",
		},
		BeachATVPass = {
			id = 2044899375,
			name = "Beach ATV",
			description = "The Beach ATV quad bike for the sand.",
			price = 25,
			order = 16,
			ready = false, -- cut 2026-10-25 (pre-hub-cut)
			vehicle = "BeachATV",
		},
		CoastguardResponsePass = {
			id = 2044617374,
			name = "Coastguard Response 4x4",
			description = "The Coastguard Response 4x4 with blue lights and a boat trailer.",
			price = 49,
			order = 17,
			ready = false, -- cut 2026-10-25 (pre-hub-cut)
			vehicle = "CoastguardResponse",
		},
		StormRunnerPass = {
			id = 2047928682,
			name = "Storm Runner",
			description = "Storm Runner offshore powerboat: the fastest boat on the water. Robux only.",
			price = 199,
			order = 18,
			ready = true,
			vehicle = "StormRunner",
		},
		TidewalkerPass = {
			id = 2044581381,
			name = "Tidewalker",
			description = "Tidewalker luxury catamaran: smooth in any sea, room for 6 survivors. Robux only.",
			price = 249,
			order = 19,
			ready = true,
			vehicle = "Tidewalker",
		},
		RiptideXPass = {
			id = 2047802677,
			name = "Riptide X",
			description = "Riptide X sport jet ski: the quickest jet ski there is. Robux only.",
			price = 129,
			order = 20,
			ready = true,
			vehicle = "RiptideX",
		},
		GildedGullPass = {
			id = 2044329361,
			name = "Gilded Gull",
			description = "Gilded Gull gold luxe jet ski: fast, steady and shining. Robux only.",
			price = 199,
			order = 21,
			ready = true,
			vehicle = "GildedGull",
		},
		HarbourGTPass = {
			id = 2045541334,
			name = "Harbour GT",
			description = "Harbour GT sports coupe: the fastest car on the island. Robux only.",
			price = 179,
			order = 22,
			ready = false, -- cut 2026-10-25 (pre-hub-cut)
			vehicle = "HarbourGT",
		},
		LighthouseCruiserPass = {
			id = 2046003338,
			name = "Lighthouse Cruiser",
			description = "Lighthouse Cruiser luxury SUV: 7 seats, quick and comfortable. Robux only.",
			price = 149,
			order = 23,
			ready = false, -- cut 2026-10-25 (pre-hub-cut)
			vehicle = "LighthouseCruiser",
		},
		-- docs/23 (h): the hangar and sub pen craft. deploy.py creates them (id 0 until then).
		RescueHelicopterPass = {
			id = 2053992047,
			name = "Rescue Helicopter",
			description = "The Rescue Helicopter: hover over anyone in the sea and winch them up.",
			price = 399,
			order = 24,
			ready = true,
			vehicle = "RescueHelicopter",
		},
		SeaplanePass = {
			id = 2055467922,
			name = "Seaplane",
			description = "The Seaplane: the fastest way to far islands, lands on the water for 4 survivors.",
			price = 299,
			order = 25,
			ready = false, -- cut 2026-10-25 (pre-hub-cut)
			vehicle = "Seaplane",
		},
		SubmarinePass = {
			id = 2052480096,
			name = "Submarine",
			description = "The Submarine: dive to the seabed and the wrecks, bring divers home.",
			price = 249,
			order = 26,
			ready = true,
			vehicle = "Submarine",
		},
	} :: { [string]: Item },

	-- docs/04 section 4.1: five Cash pack purchases per account per day (tune). Enforced by the shelf (RP-M3).
	CashPackDailyLimit = 5,
	CashPacks = { "SmallBonus", "CrewPayroll", "StationBudget", "HarborFund" },

	-- docs/03 section 2.1 Cash per hour by zone; Cash packs pay minutes of the best `live` zone
	-- (WP-28: no ranks gate it). Flip `live` when a zone's operations ship.
	CashPackZones = {
		{ id = "CalmBay", cashPerHour = 6000, live = true },
		{ id = "Skerries", cashPerHour = 8700, live = false },
		{ id = "OpenSea", cashPerHour = 12700, live = false },
		{ id = "StormFront", cashPerHour = 17300, live = false },
		{ id = "IcebergNorth", cashPerHour = 21800, live = false },
	},
}

return MonetizationConfig
