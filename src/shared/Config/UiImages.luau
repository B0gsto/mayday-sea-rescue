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
	-- World markers (CLAUDE.md "UI art", des1 2026-10-28): Claude SVG in art/source/ui, rendered by tools/ui-art.
	-- Pin: UI/Waypoint's pin per colour (tools/ui-art/pin_variants.py), its box centred on the head.
	Markers = {
		BuildArrow = "rbxassetid://74018470016385",
		EdgePointer = "rbxassetid://115902828261976",
		TrailChevron = "rbxassetid://95343043756882", -- art/source/ui/trail_chevron.svg (render --keep): the onboarding trail step, 2 frames
		Pin = {
			Red = "rbxassetid://126485934783621",
			Amber = "rbxassetid://102982529774636",
			Green = "rbxassetid://116119847629958",
			Craft = "rbxassetid://77504682990987",
			Quest = "rbxassetid://85241927129052",
			Beam = "rbxassetid://96011335512407",
		},
		-- tools/ui-art/stickers.py (uia2): the map arrow (tip up, spun about its box centre), the gamepad
		-- crosshair, the onboarding beacon's gem + stem and its ground ring (a Decal), the drop-off pad's pin
		MapPlayer = "rbxassetid://94128666441990",
		MapCross = "rbxassetid://91359051719681",
		BeaconMark = "rbxassetid://95202461577085",
		TransportPin = "rbxassetid://82312333876842",
	},
	-- Small kit stickers (tools/ui-art/stickers.py, uia2): level stars, pet hearts, seat studs
	Badges = {
		StarOn = "rbxassetid://101115140051784",
		StarOff = "rbxassetid://121280061755920",
		Heart = "rbxassetid://103429639699544",
		PipOn = "rbxassetid://79278766459351",
		PipFull = "rbxassetid://103484297206636",
		PipOff = "rbxassetid://119111756457195",
		-- FX2b (art/source/ui/medal.svg, rays.svg): the medal that flips into Skills, the sunburst behind a reward
		Medal = "rbxassetid://130413529136226",
		Rays = "rbxassetid://121915121871589",
	},
	-- UI/RewardPrompt's streak strip: art/source/ui/streak_pip.svg per state (tools/ui-art/pip_variants.py).
	Pip = {
		Done = "rbxassetid://126485653448134",
		Today = "rbxassetid://83307421569966",
		Next = "rbxassetid://104141248958070",
		Seven = "rbxassetid://74455877198415",
		SevenToday = "rbxassetid://122421984805832",
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
		finish_now = "rbxassetid://128824303756965",
		hourglass = "rbxassetid://107259087936450", -- a build waits: the tablet's busy buttons
		gift = "rbxassetid://72702946079049",
		lifebuoy = "rbxassetid://76945613397404",
		lock = "rbxassetid://135893459775435",
		map = "rbxassetid://111196679015076",
		quests = "rbxassetid://123511018979555",
		settings = "rbxassetid://124561251642705",
		sun = "rbxassetid://110983311998307", -- Golden hour event
		shop = "rbxassetid://133652722448118",
		vip = "rbxassetid://89629681853633",
		spin = "rbxassetid://133365909591902", -- the prize wheel
		wave = "rbxassetid://78956573306618", -- the wake trail prize icon (Settings' wave art)
		waves = "rbxassetid://103642240410321", -- spin wheel wake prizes
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
