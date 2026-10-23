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
		CrewPay = "rbxassetid://90764462212641",
		PayRise = "rbxassetid://84213752900110",
		Logbook = "rbxassetid://103647314836433",
		Crew = "rbxassetid://123697054940337",
		Settings = "rbxassetid://85411600136649",
		Vehicles = "rbxassetid://140273799789221",
		Store = "rbxassetid://138403733104125",
		Wallpaper = "rbxassetid://71603902912480", -- 1170x2532, assets/ui/phone_v2/wallpaper.png
	},
}
