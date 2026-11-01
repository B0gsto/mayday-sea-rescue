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
		MinimapRing = "rbxassetid://105528379718715", -- hud_minimap_ring.svg: hole 72%
		Panel = "rbxassetid://112621254236756", -- hud_panel.svg, 512x256, slice 32 px
	},
	-- World markers (CLAUDE.md "UI art", des1 2026-10-28): Claude SVG in art/source/ui, rendered by tools/ui-art.
	-- Pin: UI/Waypoint's pin per colour (tools/ui-art/pin_variants.py), its box centred on the head.
	Markers = {
		BuildArrow = "rbxassetid://84032838445846",
		EdgePointer = "rbxassetid://89045503623987",
		TrailChevron = "rbxassetid://129921853511493", -- art/source/ui/trail_chevron.svg (render --keep --size 520 338): the onboarding trail step, 2 frames
		Pin = {
			Red = "rbxassetid://116803769925060",
			Amber = "rbxassetid://80214181870053",
			Green = "rbxassetid://118481303660512",
			Craft = "rbxassetid://84346763280580",
			Quest = "rbxassetid://80754047253104",
			Beam = "rbxassetid://139056917797630",
		},
		-- the map arrow (stickers.py; tip up, spun about its box centre), the gamepad crosshair (map_cross.svg), the
		-- onboarding beacon's gem + stem and its ground ring (a Decal), the drop-off pad's pin (transport_pin.svg)
		MapPlayer = "rbxassetid://119044752411946",
		MapCross = "rbxassetid://138096397232236",
		BeaconMark = "rbxassetid://133931579547429",
		TransportPin = "rbxassetid://82312333876842",
		TapHand = "rbxassetid://133375972498905", -- art/source/ui/tap.svg: the build tablet cue on touch
	},
	-- Small kit stickers (tools/ui-art/stickers.py, uia2): level stars, pet hearts, seat studs
	Badges = {
		StarOn = "rbxassetid://101115140051784",
		StarOff = "rbxassetid://77911552150902",
		Heart = "rbxassetid://85482763409121",
		PipOn = "rbxassetid://73122438395663",
		PipFull = "rbxassetid://81287110525575",
		PipOff = "rbxassetid://97315587832140",
		-- FX2b (art/source/ui/medal.svg, rays.svg): the medal that flips into Skills, the sunburst behind a reward
		Medal = "rbxassetid://120905942484319",
		Rays = "rbxassetid://105602463419142",
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
		slow = "rbxassetid://110465667653360",
		exit = "rbxassetid://119755405737241",
		up = "rbxassetid://118791936904678",
		down = "rbxassetid://71511456291214",
	} :: { [string]: string },
	-- UI Kit (docs/23 (m), UI/Kit): art/source/ui/kit_<key>.svg (tools/ui-art/kit_icons*.py), plus Studs: the
	-- subtle stud tile on title bars and price buttons (assets/ui/kit).
	Kit = {
		Studs = "rbxassetid://108987158998866",
		album = "rbxassetid://119412457973851",
		boat_to_me = "rbxassetid://115641492846202",
		boost = "rbxassetid://94178964726027",
		build = "rbxassetid://119758686675875",
		cash = "rbxassetid://73524615050602",
		close = "rbxassetid://86609631544452",
		companion = "rbxassetid://108203298362844",
		crew = "rbxassetid://81013149158773",
		daily = "rbxassetid://97363083556182",
		finish_now = "rbxassetid://117705972506496",
		hourglass = "rbxassetid://135457151427134", -- a build waits: the tablet's busy buttons
		gift = "rbxassetid://78166338410041",
		lifebuoy = "rbxassetid://99800512753319",
		lock = "rbxassetid://91358795288547",
		map = "rbxassetid://122362134620905",
		quests = "rbxassetid://122316165984314",
		settings = "rbxassetid://80938513012348",
		sun = "rbxassetid://139121552665019", -- Golden hour event
		shop = "rbxassetid://106958726223600",
		vip = "rbxassetid://107689602334055",
		spin = "rbxassetid://112404239102332", -- the prize wheel
		chat = "rbxassetid://135687211740204", -- idle crew chatting (art/source/ui/chat.svg, tools/ui-art/stickers.py)
		wave = "rbxassetid://117647967499184", -- the wake trail prize icon
		waves = "rbxassetid://112731732682495", -- spin wheel wake prizes
	} :: { [string]: string },
	-- SettingsPanel row glyphs, keyed like its SHAPES (art/source/ui/set_<key>.svg; blur/bob/drops/horizon unused: assets/ui/settings)
	SettingsArt = {
		blur = "rbxassetid://116677182644896",
		bob = "rbxassetid://138080772723546",
		bubble = "rbxassetid://109673734891257",
		burst = "rbxassetid://96276918234299",
		drops = "rbxassetid://77876262268085",
		fov = "rbxassetid://73525466806879",
		half = "rbxassetid://110053004771040",
		horizon = "rbxassetid://77356769833875",
		horn = "rbxassetid://107455716702456",
		no = "rbxassetid://101816213126997",
		note = "rbxassetid://100612325857668",
		notes = "rbxassetid://90588794160573",
		pause = "rbxassetid://131145984081104",
		peak = "rbxassetid://92091090282779",
		plus = "rbxassetid://90107455192863",
		reset = "rbxassetid://133965911902055",
		shake = "rbxassetid://130335088190594",
		sparkle = "rbxassetid://139978053064355",
		speed = "rbxassetid://78003965913036",
		tap = "rbxassetid://126217604149319",
		wave = "rbxassetid://138475817006467",
		waves = "rbxassetid://116306600159583",
	} :: { [string]: string },
	-- album stickers (art/source/ui/stamp_<id>.svg, critter_<name>.svg): island stamps by island id, Bottle / View, rare critters
	Stickers = {
		SkerryIsle = "rbxassetid://79147895150372",
		PuffinIsle = "rbxassetid://103196387838640",
		Penwyn = "rbxassetid://138798629306650",
		WreckReef = "rbxassetid://70598441111651",
		TheArches = "rbxassetid://72501008504103",
		GannetRock = "rbxassetid://128980633701792",
		MermaidLagoon = "rbxassetid://71269328107727",
		Bottle = "rbxassetid://73594574316222",
		View = "rbxassetid://72045876466065",
		SealPup = "rbxassetid://126110196776760",
		Gull = "rbxassetid://106741220900123",
		Puffin = "rbxassetid://84318610826029",
		Otter = "rbxassetid://103992771180637",
		Turtle = "rbxassetid://76131311151723",
		Wreck = "rbxassetid://70598441111651", -- shortcut: the Wreck Reef stamp art until a wreck sticker lands
	} :: { [string]: string },
}
