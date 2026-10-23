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
--   Nothing here changes Reputation, rank, call timers, step grades or a casualty's condition (docs/04 §7).

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
	vehicle: string?, -- vehicle passes: the VehicleConfig / LandVehicleConfig id it owns (any rank)
}

local MonetizationConfig = {
	Products = {
		-- 4.1 Cash packs (scale with the highest open zone; the card shows the exact Cash first)
		SmallBonus = {
			id = 3719524891,
			name = "Small Bonus",
			description = "Cash equal to 15 minutes of your top open zone's Cash rate. Cash only, no Reputation.",
			price = 10,
			order = 1,
			ready = true,
			cashMinutes = 15,
			valueBonus = 0,
		},
		CrewPayroll = {
			id = 3719524897,
			name = "Crew Payroll",
			description = "Cash equal to 45 minutes of your top open zone's Cash rate. Cash only, no Reputation.",
			price = 25,
			order = 2,
			ready = true,
			cashMinutes = 45,
			valueBonus = 0,
		},
		StationBudget = {
			id = 3719524917,
			name = "Station Budget",
			description = "Cash equal to 2.5 hours of your top open zone's Cash rate, plus 10%. Cash only, no Reputation.",
			price = 75,
			order = 3,
			ready = true,
			cashMinutes = 150,
			valueBonus = 0.1,
		},
		HarborFund = {
			id = 3719524924,
			name = "Harbor Fund",
			description = "Cash equal to 7 hours of your top open zone's Cash rate, plus 20%. Cash only, no Reputation.",
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
	} :: { [string]: Item },

	GamePasses = {
		DoubleCash = {
			id = 2040015521,
			name = "2x Cash",
			description = "Doubles Cash from operations, big calls and challenges. Does not change Reputation or rank.",
			price = 75,
			order = 1,
			ready = true,
			cashMultiplier = 2,
		},
		VipCrewCard = {
			id = 0,
			name = "VIP Crew Card",
			description = "Gold nameplate and radio tag, VIP Gold livery for every vehicle, the VIP deck on the station roof and one free daily challenge reroll.",
			price = 299,
			order = 2,
			ready = false,
		},
		QuickLaunch = {
			id = 2036073727,
			name = "Quick Launch",
			description = "Skip the launch cooldown and launch any owned vehicle straight into the seat from anywhere. Never affects casualties or grades.",
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
		-- Vehicle passes (2026-10-21, user): own the vehicle at any rank (ProgressionRules.vehiclePass);
		-- the premium six are Robux only (ProgressionConfig.Vehicles passOnly). Prices proposed -- tune.
		RIBPass = {
			id = 2044851404,
			name = "RIB Inflatable",
			description = "The RIB Inflatable: 3 crew, 3 casualties, fast and tough. Yours at any rank.",
			price = 49,
			order = 14,
			ready = true,
			vehicle = "RIB",
		},
		LifeboatPass = {
			id = 2046219317,
			name = "All-Weather Lifeboat",
			description = "The All-Weather Lifeboat: 8 casualties, self-righting, a strong tow. Yours at any rank.",
			price = 129,
			order = 15,
			ready = true,
			vehicle = "Lifeboat",
		},
		BeachATVPass = {
			id = 2044899375,
			name = "Beach ATV",
			description = "The Beach ATV quad bike for the sand. Yours at any rank.",
			price = 25,
			order = 16,
			ready = true,
			vehicle = "BeachATV",
		},
		CoastguardResponsePass = {
			id = 2044617374,
			name = "Coastguard Response 4x4",
			description = "The Coastguard Response 4x4 with blue lights and a boat trailer. Yours at any rank.",
			price = 49,
			order = 17,
			ready = true,
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
			description = "Tidewalker luxury catamaran: smooth in any sea, room for 6 casualties. Robux only.",
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
			ready = true,
			vehicle = "HarbourGT",
		},
		LighthouseCruiserPass = {
			id = 2046003338,
			name = "Lighthouse Cruiser",
			description = "Lighthouse Cruiser luxury SUV: 7 seats, quick and comfortable. Robux only.",
			price = 149,
			order = 23,
			ready = true,
			vehicle = "LighthouseCruiser",
		},
	} :: { [string]: Item },

	-- docs/04 section 4.1: five Cash pack purchases per account per day (tune). Enforced by the shelf (RP-M3).
	CashPackDailyLimit = 5,
	CashPacks = { "SmallBonus", "CrewPayroll", "StationBudget", "HarborFund" },

	-- docs/03 section 2.1 Cash per hour by zone; Cash packs pay minutes of the top `live` zone the
	-- player's rank has opened (docs/03 section 3). Flip `live` when a zone's operations ship.
	CashPackZones = {
		{ id = "CalmBay", rankIndex = 1, cashPerHour = 6000, live = true },
		{ id = "Skerries", rankIndex = 2, cashPerHour = 8700, live = false },
		{ id = "OpenSea", rankIndex = 4, cashPerHour = 12700, live = false },
		{ id = "StormFront", rankIndex = 6, cashPerHour = 17300, live = false },
		{ id = "IcebergNorth", rankIndex = 7, cashPerHour = 21800, live = false },
	},
}

return MonetizationConfig
