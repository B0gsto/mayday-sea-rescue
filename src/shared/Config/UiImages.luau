--!strict
-- UiImages: uploaded UI sprites (assets/ui/<set>/*.png, uploaded with tools/assets.py upload).
-- Hud: the gameplay HUD set (assets/ui/hud, mockup.png). Panel is 9-slice.
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
	},
	-- Icons requested in docs/18-ui-art-requests.md. Empty until uploaded: the UI draws its glyph
	-- placeholder instead. VehicleArt: UI/BoatCard (upgrades by id, the stat rows, the tick).
	VehicleArt = {
		Engine = "rbxassetid://77604707401218",
		Hull = "rbxassetid://70457841837821",
		Fit = "rbxassetid://128287933181704",
		Speed = "rbxassetid://122953764585559",
		Tough = "rbxassetid://115278891400408",
		Check = "rbxassetid://101458713833337",
	},
	-- UI Kit (docs/23 (m), UI/Kit): Antigravity icons (assets/ui/kit, from marketing/ui/icons) keyed by
	-- file stem, plus Studs: the subtle stud tile on title bars and price buttons.
	Kit = {
		Studs = "rbxassetid://108987158998866",
		album = "rbxassetid://117602974111890",
		boat_to_me = "rbxassetid://126497151202647",
		boost = "rbxassetid://89719184224286",
		build = "rbxassetid://85748124089400",
		cash = "rbxassetid://96161188991448",
		close = "rbxassetid://117801141592310",
		companion = "rbxassetid://82752596877543",
		crew = "rbxassetid://83085542846827",
		daily = "rbxassetid://79958924558323",
		gift = "rbxassetid://72702946079049",
		lifebuoy = "rbxassetid://76945613397404",
		lock = "rbxassetid://135893459775435",
		map = "rbxassetid://111196679015076",
		quests = "rbxassetid://123511018979555",
		settings = "rbxassetid://124561251642705",
		shop = "rbxassetid://133652722448118",
		vip = "rbxassetid://89629681853633",
	} :: { [string]: string },
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
