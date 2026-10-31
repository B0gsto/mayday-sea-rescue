--!strict
-- UiImages: uploaded UI sprites (uploaded with tools/assets.py upload). Most are Claude SVG in art/source/ui rendered by
-- tools/ui-art (UI perfect pass 2026-11-01: build/status/2026-10-31/perfect/ui/RESULT.md); the rest are assets/ui/<set>/*.png.
-- Hud: the gameplay HUD set (art/source/ui/hud_*.svg; AcceptButton, MissionPiw: assets/ui/hud). Panel is 9-slice.
return {
	Hud = {
		Coin = "rbxassetid://82797676383121",
		XpStar = "rbxassetid://116541973944865",
		PlusButton = "rbxassetid://79278684006057",
		AcceptButton = "rbxassetid://105225933033810",
		MissionPiw = "rbxassetid://93413645418060",
		ExitButton = "rbxassetid://122735301639954",
		MinimapRing = "rbxassetid://138912219092687", -- hud_minimap_ring.svg: hole 72%
		Panel = "rbxassetid://112914890862611", -- hud_panel.svg, 512x256, slice 32 px
	},
	-- World markers (CLAUDE.md "UI art", des1 2026-10-28): Claude SVG in art/source/ui, rendered by tools/ui-art.
	-- Pin: UI/Waypoint's pin per colour (tools/ui-art/pin_variants.py), its box centred on the head.
	Markers = {
		BuildArrow = "rbxassetid://84755338456979",
		EdgePointer = "rbxassetid://89045503623987",
		TrailChevron = "rbxassetid://91014157624813", -- art/source/ui/trail_chevron.svg (render --keep --size 520 338): the onboarding trail step, 2 frames
		Pin = {
			Red = "rbxassetid://116803769925060",
			Amber = "rbxassetid://73360325899740",
			Green = "rbxassetid://74724550052263",
			Craft = "rbxassetid://128049279884885",
			Quest = "rbxassetid://80368490940576",
			Beam = "rbxassetid://139237094016793",
		},
		-- the map arrow (stickers.py; tip up, spun about its box centre), the gamepad crosshair (map_cross.svg), the
		-- onboarding beacon's gem + stem and its ground ring (a Decal), the drop-off pad's pin (transport_pin.svg)
		MapPlayer = "rbxassetid://119044752411946",
		MapCross = "rbxassetid://78071341360128",
		BeaconMark = "rbxassetid://103684513850685",
		TransportPin = "rbxassetid://82312333876842",
		TapHand = "rbxassetid://133375972498905", -- art/source/ui/tap.svg: the build tablet cue on touch
	},
	-- Small kit stickers (tools/ui-art/stickers.py, uia2): level stars, pet hearts, seat studs
	Badges = {
		StarOn = "rbxassetid://101115140051784",
		StarOff = "rbxassetid://99551585299967",
		Heart = "rbxassetid://85482763409121",
		PipOn = "rbxassetid://73122438395663",
		PipFull = "rbxassetid://81287110525575",
		PipOff = "rbxassetid://97315587832140",
		-- FX2b (art/source/ui/medal.svg, rays.svg): the medal that flips into Skills, the sunburst behind a reward
		Medal = "rbxassetid://120905942484319",
		Rays = "rbxassetid://89333384278542",
	},
	-- UI/RewardPrompt's streak strip: art/source/ui/streak_pip.svg per state (tools/ui-art/pip_variants.py).
	Pip = {
		Done = "rbxassetid://126485653448134",
		Today = "rbxassetid://115508094273617",
		Next = "rbxassetid://89478111472334",
		Seven = "rbxassetid://72588805534744",
		SevenToday = "rbxassetid://73962202785527",
	},
	-- Icons requested in docs/18-ui-art-requests.md. Empty until uploaded: the UI draws its glyph
	-- placeholder instead. VehicleArt: only Check is used (art/source/ui/check.svg, stickers.py).
	VehicleArt = {
		Engine = "rbxassetid://77604707401218",
		Hull = "rbxassetid://70457841837821",
		Fit = "rbxassetid://128287933181704",
		Speed = "rbxassetid://122953764585559",
		Tough = "rbxassetid://115278891400408",
		Check = "rbxassetid://74743194057599",
	},
	-- the touch drive pad (TouchDriveController): tools/ui-art/stickers.py pad_<key> (art/source/ui/pad_*.svg)
	Pad = {
		left = "rbxassetid://101489610533671",
		right = "rbxassetid://72373386792609",
		go = "rbxassetid://107416729005565",
		brake = "rbxassetid://117362525559127",
		slow = "rbxassetid://125100341853297",
		exit = "rbxassetid://136794635182322",
		up = "rbxassetid://72000600354794",
		down = "rbxassetid://71511456291214",
	} :: { [string]: string },
	-- UI Kit (docs/23 (m), UI/Kit): art/source/ui/kit_<key>.svg (tools/ui-art/kit_icons*.py), plus Studs: the
	-- subtle stud tile on title bars and price buttons (assets/ui/kit).
	Kit = {
		Studs = "rbxassetid://108987158998866",
		album = "rbxassetid://126053618682674",
		boat_to_me = "rbxassetid://112615487234585",
		boost = "rbxassetid://94178964726027",
		build = "rbxassetid://87241010378545",
		cash = "rbxassetid://73524615050602",
		close = "rbxassetid://86609631544452",
		companion = "rbxassetid://84925234540112",
		crew = "rbxassetid://91582164780212",
		daily = "rbxassetid://117840867302945",
		finish_now = "rbxassetid://124319247058644",
		hourglass = "rbxassetid://135457151427134", -- a build waits: the tablet's busy buttons
		gift = "rbxassetid://78166338410041",
		lifebuoy = "rbxassetid://123972601311067",
		lock = "rbxassetid://91358795288547",
		map = "rbxassetid://122362134620905",
		quests = "rbxassetid://122199720759649",
		settings = "rbxassetid://80938513012348",
		sun = "rbxassetid://116227771643659", -- Golden hour event
		shop = "rbxassetid://106958726223600",
		vip = "rbxassetid://107689602334055",
		spin = "rbxassetid://110469175771456", -- the prize wheel
		chat = "rbxassetid://135687211740204", -- idle crew chatting (art/source/ui/chat.svg, tools/ui-art/stickers.py)
		wave = "rbxassetid://117647967499184", -- the wake trail prize icon
		waves = "rbxassetid://139071525797286", -- spin wheel wake prizes
	} :: { [string]: string },
	-- SettingsPanel row glyphs, keyed like its SHAPES (art/source/ui/set_<key>.svg; blur/bob/drops/horizon unused: assets/ui/settings)
	SettingsArt = {
		blur = "rbxassetid://116677182644896",
		bob = "rbxassetid://138080772723546",
		bubble = "rbxassetid://109673734891257",
		burst = "rbxassetid://112315226986302",
		drops = "rbxassetid://77876262268085",
		fov = "rbxassetid://137880678387815",
		half = "rbxassetid://87049366731344",
		horizon = "rbxassetid://77356769833875",
		horn = "rbxassetid://83659695592905",
		no = "rbxassetid://121476609266313",
		note = "rbxassetid://92792439591939",
		notes = "rbxassetid://90588794160573",
		pause = "rbxassetid://98535081821095",
		peak = "rbxassetid://98960751308730",
		plus = "rbxassetid://127649540256951",
		reset = "rbxassetid://126684807582300",
		shake = "rbxassetid://103149091272672",
		sparkle = "rbxassetid://139978053064355",
		speed = "rbxassetid://107949437349828",
		tap = "rbxassetid://93560884791045",
		wave = "rbxassetid://129876151603660",
		waves = "rbxassetid://101386583534628",
	} :: { [string]: string },
	-- album stickers (art/source/ui/stamp_<id>.svg, critter_<name>.svg): island stamps by island id, Bottle / View, rare critters
	Stickers = {
		SkerryIsle = "rbxassetid://79147895150372",
		PuffinIsle = "rbxassetid://103196387838640",
		Penwyn = "rbxassetid://132874654253278",
		WreckReef = "rbxassetid://110485685013401",
		TheArches = "rbxassetid://124445719416194",
		GannetRock = "rbxassetid://107245522856222",
		MermaidLagoon = "rbxassetid://84069087535517",
		Bottle = "rbxassetid://73594574316222",
		View = "rbxassetid://76100132606085",
		SealPup = "rbxassetid://126110196776760",
		Gull = "rbxassetid://137610897367727",
		Puffin = "rbxassetid://73610566777086",
		Otter = "rbxassetid://70851405202756",
		Turtle = "rbxassetid://76131311151723",
		Wreck = "rbxassetid://110485685013401", -- shortcut: the Wreck Reef stamp art until a wreck sticker lands
	} :: { [string]: string },
}
