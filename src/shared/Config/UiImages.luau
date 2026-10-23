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
		Radio = "rbxassetid://133273002736919",
		Camera = "rbxassetid://102410072009100",
		Events = "rbxassetid://72738707163546",
		Season = "rbxassetid://80586118394028",
		Logbook = "rbxassetid://103647314836433",
		Crew = "rbxassetid://123697054940337",
		Settings = "rbxassetid://85411600136649",
		Vehicles = "rbxassetid://140273799789221",
		Store = "rbxassetid://138403733104125",
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
}
