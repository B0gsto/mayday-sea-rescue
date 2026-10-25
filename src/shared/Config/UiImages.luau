--!strict
-- UiImages: uploaded UI sprites (assets/ui/<set>/*.png, uploaded with tools/assets.py upload).
-- Phone: assets/ui/phone_v2 app icons (full squircle tiles with alpha, keyed by app name) and the HUD phone button.
-- Hud: the gameplay HUD set (assets/ui/hud, mockup.png). Panel / SpeedPanel / Bar* are 9-slice.
return {
	Hud = {
		Coin = "rbxassetid://73244576620050",
		XpStar = "rbxassetid://95688680030871",
		PlusButton = "rbxassetid://87726120620000",
		AcceptButton = "rbxassetid://105225933033810",
		MissionPiw = "rbxassetid://93413645418060",
		ExitButton = "rbxassetid://129655332194316",
		MinimapRing = "rbxassetid://130518444307744", -- minimap_ring_thin.png: hole 72%
		Panel = "rbxassetid://89769136629803", -- 512x256, slice 32 px
		SpeedPanel = "rbxassetid://91006902656634", -- 512x128, slice 24 px
		BarFill = "rbxassetid://101134848001000", -- 512x64, slice 32 px each end
		BarTrack = "rbxassetid://82053370414902", -- 512x64, slice 32 px each end
	},
	Phone = {
		Button = "rbxassetid://97328188378860",
		Map = "rbxassetid://90931029466891",
		Camera = "rbxassetid://102410072009100",
		Crew = "rbxassetid://123697054940337",
		Settings = "rbxassetid://85411600136649",
		Vehicles = "rbxassetid://140273799789221",
		Store = "rbxassetid://138403733104125",
		Pets = "rbxassetid://87898331265122",
		Album = "rbxassetid://80999164138068",
		Wallpaper = "rbxassetid://71603902912480", -- 1170x2532, assets/ui/phone_v2/wallpaper.png
	},
	-- Icons requested in docs/18-ui-art-requests.md. Empty until uploaded: the UI draws its glyph
	-- placeholder instead. VehicleArt: the Vehicles app (upgrades by id, the three stat rows, the tick).
	VehicleArt = {
		Engine = "rbxassetid://77604707401218",
		Hull = "rbxassetid://70457841837821",
		Fit = "rbxassetid://128287933181704",
		Speed = "rbxassetid://122953764585559",
		People = "rbxassetid://118927461824321",
		Tough = "rbxassetid://115278891400408",
		Check = "rbxassetid://101458713833337",
	},
	-- SettingsPanel row glyphs, keyed like its SHAPES (assets/ui/settings/<key>.png)
	SettingsArt = {
		blur = "rbxassetid://116677182644896",
		bob = "rbxassetid://138080772723546",
		bubble = "rbxassetid://88159160837923",
		burst = "rbxassetid://116272753477731",
		drops = "rbxassetid://77876262268085",
		fov = "rbxassetid://95344988024726",
		half = "rbxassetid://79842788477064",
		horizon = "rbxassetid://77356769833875",
		horn = "rbxassetid://106758330951235",
		no = "rbxassetid://125203313497212",
		note = "rbxassetid://101727006079954",
		notes = "rbxassetid://112015345291447",
		pause = "rbxassetid://99864879095765",
		peak = "rbxassetid://96945124314989",
		plus = "rbxassetid://126688767476030",
		reset = "rbxassetid://111913353326936",
		shake = "rbxassetid://122564997063933",
		sparkle = "rbxassetid://130789759216108",
		speed = "rbxassetid://113978550247533",
		tap = "rbxassetid://127544457178491",
		wave = "rbxassetid://78956573306618",
		waves = "rbxassetid://113642256494966",
	} :: { [string]: string },
	-- album stickers (assets/ui/album): island stamps by island id, Bottle / View, rare critters by species
	Stickers = {
		SkerryIsle = "rbxassetid://79234382316384",
		PuffinIsle = "rbxassetid://87680328740912",
		Penwyn = "rbxassetid://104689252207258",
		WreckReef = "rbxassetid://89209684718926",
		TheArches = "rbxassetid://83402071804743",
		GannetRock = "rbxassetid://113860834663369",
		MermaidLagoon = "rbxassetid://83142034540217",
		Bottle = "rbxassetid://78232456333007",
		View = "rbxassetid://81771345531261",
		SealPup = "rbxassetid://132804906695444",
		Gull = "rbxassetid://80027175736095",
		Puffin = "rbxassetid://95011471355027",
		Otter = "rbxassetid://78618476254127",
		Turtle = "rbxassetid://99122489390773",
		Wreck = "rbxassetid://89209684718926", -- shortcut: the Wreck Reef stamp art until a wreck sticker lands
	} :: { [string]: string },
}
