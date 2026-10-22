--!strict
-- AudioConfig: every sound id the game plays outside the voice lines (those live in
-- VoiceManifest), the five volume categories and the mix constants. Docs 12 section 4.
--
-- Licences (each id was checked; log new ones in assets/audio/candidates.csv):
--   RL = Roblox licensed library (Pro Sound Effects / APM, public on the marketplace;
--        `tools/audio-search.py verify <id>` returns OK). In-experience use only, not the trailer.
--   FS = Freesound CC0 (licence checked on the clip page), uploaded by us through
--        tools/assets.py (assets/audio/fs/*.mp3, manifest.json). New uploads sit in moderation
--        for a while; `fallback` (RL) plays until the upload is approved.
-- Every clip here is a stand-in until our own recordings (RC) exist; docs 12 section 4.
--
-- Categories (SoundGroups in SoundService, made by AudioController): Master holds Music, SFX,
-- Ambience and Radio. The settings panel sets their Volume (AudioController.setVolume).

export type Clip = {
	id: string, -- rbxassetid://...
	fallback: string?, -- plays while `id` fails to load (an upload still in moderation)
	volume: number, -- base volume before the mix
	source: "RL" | "FS",
	title: string,
	note: string?,
}

export type Category = "Master" | "Music" | "SFX" | "Ambience" | "Radio"

local function rl(id: number, volume: number, title: string, note: string?): Clip
	return { id = `rbxassetid://{id}`, volume = volume, source = "RL", title = title, note = note }
end

local function fs(id: number, fallback: number, volume: number, title: string, note: string?): Clip
	return {
		id = `rbxassetid://{id}`,
		fallback = `rbxassetid://{fallback}`,
		volume = volume,
		source = "FS",
		title = title,
		note = note,
	}
end

local AudioConfig = {}

local CATEGORIES: { Category } = { "Master", "Music", "SFX", "Ambience", "Radio" }
AudioConfig.Categories = CATEGORIES

-- Default category volumes (0..1). Music sits low: the sea is the score.
AudioConfig.DefaultVolumes = {
	Master = 1,
	Music = 0.55,
	SFX = 1,
	Ambience = 0.9,
	Radio = 1,
} :: { [string]: number }

AudioConfig.Clips = {
	-- Engines. Jet ski: two PSE onboard recordings crossfaded by RPM.
	Eng_JetSki_Low = rl(9112798559, 0.55, "Jet Skis Some Chop 1 (SFX)", "cruise / low RPM layer"),
	Eng_JetSki_High = rl(9112798882, 0.7, "Jet Skis Surges 1 (SFX)", "high RPM layer"),
	-- RIB: CC0 outboard recordings by kyles (freesound 637742 idle, 637744 onboard at speed).
	Eng_RIB_Idle = fs(
		91517159436369,
		9112780932,
		0.6,
		"outboard motor boat idle or slow rattly3 (kyles, CC0)"
	),
	Eng_RIB_Plane = fs(
		137085856844255,
		9112780932,
		0.7,
		"outboard motor boat onboard high speed (kyles, CC0)"
	),
	-- Pickup / response car (diesel stand-ins).
	Eng_Car_Idle = rl(9112988114, 0.5, "1988 Chevy Pickup Truck Idle 1 (SFX)"),
	Eng_Car_Load = rl(9112736090, 0.55, "1988 Gmc Suburban 2 (SFX)", "driving layer"),
	Car_Horn = rl(9113014312, 0.6, "1998 Ford Expedition V8 Suv Horn Honks 6 (SFX)"),
	Tyre_Asphalt = rl(9112886237, 0.45, "Tire Constant 1 (SFX)"),
	Tyre_Cobble = rl(9112886780, 0.45, "Tires Cobblestones 2 (SFX)"),
	Tyre_Gravel = rl(9126157444, 0.45, "Vehicle Gravel Tires Crunch Constant (SFX)"),

	-- Hull and water.
	Hull_Lap = rl(9112737677, 0.5, "Active Water Lap 1 (SFX)", "slow or stopped hull"),
	Hull_BowWash = rl(9112750448, 0.5, "Bow Wash Slow Trolling Speed 1 (SFX)"),
	Hull_Wake = rl(9120610020, 0.55, "Water Wake Constant 1 (SFX)", "planing hull rush"),
	Hull_Slap = rl(9119479417, 0.6, "Splashes Large Objects Thrown In Water 6 (SFX)"),
	Hull_Slam = rl(9120611452, 0.75, "Wave Crashes Single Large Impacts 6 (SFX)"),
	Hull_SprayHiss = rl(9120502958, 0.4, "Water Burst Boom Blast Hissing Spray 1 (SFX)"),
	-- SwimController: the entry splash and the stroke loop while swimming.
	Splash_Entry = rl(9120585252, 0.6, "Water Splash Big Water Splash Dive In 1 (SFX)"),
	Swim_Stroke = rl(9120589166, 0.35, "Water Splashing Swimming Stroke 2 (SFX)", "looped"),

	-- Sea beds.
	Wave_Harbour = rl(9113665479, 0.45, "Calm Water Lap 1 (SFX)"),
	Wave_OpenSwell = rl(9117143192, 0.4, "Ocean Surf 1 (SFX)"),
	Wave_Storm = rl(9126201576, 0.55, "Waves Long Rolling In Constantly Heavy Surf (SFX)"),

	-- Wind, rising with the storm (Weather.getIntensity) and with apparent wind speed.
	Wind_Light = rl(9113286969, 0.35, "Barstow Wind Light Blustery Low Howl 2 (SFX)"),
	Wind_Strong = fs(102165262654580, 9114057128, 0.55, "Howling Wind Ambience (DBlover, CC0)"),
	Wind_Gale = fs(101650660993799, 9113732046, 0.7, "Gale Wind (LanDub, CC0)"),

	-- Rain and thunder (the main rain loop and the thunder are played by WeatherController).
	Rain_Heavy = rl(9112853287, 0.6, "Rain Heavy 1 (SFX)"),
	Rain_OnWater = rl(9112854469, 0.5, "Rain On Water 1 (SFX)"),
	Thunder_Near = rl(9120016241, 1, "Thunder Cracks Big Rumbling Blasts Booming 4 (SFX)"),
	Thunder_Roll = rl(9120021237, 0.8, "Thunder Rumbling 1 (SFX)"),

	-- Harbour and coast.
	Amb_Harbour = rl(9112829678, 0.5, "Marina Ambience 5 (SFX)"),
	Amb_Town = rl(
		9116203080,
		0.22,
		"Korean Walla Single Male Female Voice 2 (SFX)",
		"distant murmur"
	),
	Rigging_Clink_1 = rl(9114462292, 0.25, "Flagpole Hit 1 (SFX)", "halyard on a mast"),
	Rigging_Clink_2 = rl(9114462293, 0.25, "Flagpole Hit 3 (SFX)"),
	Rigging_Clink_3 = rl(9114462450, 0.25, "Flagpole Hit 4 (SFX)"),
	Rigging_Creak = rl(9114462106, 0.2, "Flagpole Creak 2 (SFX)"),
	Bell_Buoy = rl(9113420681, 0.5, "Bell Rings 3 (SFX)"),
	Gull_Call_1 = rl(9118858259, 0.35, "Seagull Squawks 3 (SFX)"),
	Gull_Call_2 = rl(9118858279, 0.35, "Seagull Squawks 1 (SFX)"),
	Gull_Flock = rl(9112870623, 0.25, "Seagulls 1 (SFX)"),
	-- Bosun's point bark (DogController).
	Dog_Bark = rl(
		9113956178,
		0.55,
		"Coyotes Gruff Barking 14 (SFX)",
		"stand-in for a Newfoundland"
	),

	-- Underwater (camera below the surface).
	Under_Ambience = rl(9112889917, 0.6, "Underwater Ambience 1 (SFX)"),

	-- VHF radio (VoiceManifest.Sfx points here; the radio chain band-passes them).
	Radio_SquelchOpen = rl(9118026328, 0.6, "Radio Squelches 12 (SFX)"),
	Radio_SquelchClose = rl(9118021986, 0.6, "Radio Squelches 32 (SFX)"),
	Radio_Static = rl(9118026602, 0.5, "Radio Static 1 (SFX)", "looped under open squelch"),
	Radio_Key = rl(9120456241, 0.5, "Walkie Talkie 1 (SFX)", "press-to-talk"),

	-- Interface: one soft switch click, quiet.
	UI_Click = rl(9119717529, 0.18, "Switch Click On Or Off Toggle Button 1 (SFX)"),
	UI_Back = rl(9119717523, 0.16, "Switch Click On Or Off Toggle Button 2 (SFX)"),
	UI_Prompt = rl(9118138365, 0.12, "Relay Clicks 9 (SFX)", "world prompt tick"),
	UI_Pickup = rl(9116729826, 0.2, "Metallic Beeps Quick Tones 2 (SFX)", "Cash / Rep pickup"),
	UI_Step = rl(9116729822, 0.22, "Metallic Beeps Quick Tones 1 (SFX)", "step complete"),
	UI_Success = rl(9113399926, 0.3, "Beeps Simple Multiple Variations 5 (SFX)"),
	UI_Fail = rl(9113085665, 0.26, "Alarm Buzzer 3 (SFX)"),

	-- RP-M5 stream E2 (Captain's Locker whistle emote): verified public (audio-search.py verify),
	-- candidates.csv SFX_Casualty_Whistle. 3D at the player's head, rolled off by 140 studs.
	Emote_Whistle = rl(9117258228, 0.9, "Pealess Whistle Referee Fox 40 2 (SFX)"),
	-- end RP-M5 stream E2

	-- G43: rewards, shops, the album, pets and the seasonal events.
	Crate_Lid = rl(9120881884, 0.55, "Wood Groan Creak Opening Wood Chest Coffin 8 (SFX)"),
	Cash_Coins = rl(9113704200, 0.4, "Candy Machine Coin Drops Insert Vending 5 (SFX)"),
	Chandlery_Bell = rl(9125485591, 0.45, "Desk Bell Counter Service Single Ringing Din (SFX)"),
	Chandlery_Till = rl(9113728648, 0.55, "Cash Register 4 (SFX)"),
	Logbook_Page = rl(9118835414, 0.4, "Scrapbook Open And Turn Pages 2 (SFX)"),
	Logbook_Chime = rl(9116394545, 0.35, "Magic Glows Soft Clusters Of Chiming Hits 1 (SFX)"),
	Album_Sticker = rl(9113263851, 0.45, "Balloon Pops Slap Clap Smack 1 (SFX)", "sticker slap"),
	Album_Sparkle = rl(9126073001, 0.35, "Synth Sparkle Tone High Pitch Bell Tone Ding (SFX)"),
	Pet_Seal = rl(9125919816, 0.45, "Seal Bark Human Like Grunt Heaving Rhythmic (SFX)"),
	Pet_Puffin = rl(9117236763, 0.35, "Parakeet Chirps 3 (SFX)", "stand-in puffin call"),
	Pet_Otter = rl(
		9125994570,
		0.3,
		"Squeeze Toy Squeaky Rubber With Noisemaker H (SFX)",
		"stand-in otter squeak"
	),
	Pet_Gull = rl(9118858259, 0.3, "Seagull Squawks 3 (SFX)", "reused from Gull_Call_1"),
	Pet_Turtle = rl(
		9120585252,
		0.4,
		"Water Splash Big Water Splash Dive In 1 (SFX)",
		"reused from Splash_Entry"
	),
	Halloween_Sting = rl(
		9125641284,
		0.4,
		"Magic Synth Stinger Glassine Multi Tone Burs (SFX)",
		"playful, not scary"
	),
	GhostShip_Call = rl(9119464660, 0.5, "Spirit Fly Bys Spooky Windy Airy Pass Bys 7 (SFX)"),
	Rank_Cheer = rl(9113137529, 0.45, "Applause Nightclub 1 (SFX)"),
	UI_FriendPop = rl(9112752910, 0.22, "Bubble Wobble Comic Bloops Slight Rhythm 4 (SFX)"),

	-- Music (APM via Roblox). Two cues: an operation underway, and the debrief.
	Music_CrateFanfare = rl(1837762472, 0.5, "Victory Dance (sting a) (APM)", "day-7 crate"),
	Music_Legendary = rl(85130118995016, 0.5, "Arc Of Triumph (Sting) (APM)", "Legendary call"),
	Music_Operation = rl(1837463124, 0.35, "Tension Bed for One (APM, The Box)"),
	Music_Debrief = rl(
		84002131639340,
		0.4,
		"Cinematic Hopeful Gravitas Underscore Ambient Only (APM)"
	),
	-- RP-M5 stream A (Horn Pack / Siren Pack): real marine horns and siren tones, PSE via the
	-- Roblox licensed library, each verified public (audio-search.py verify). Played by
	-- src/client/Cosmetics/Horns and Sirens (options in Config/Cosmetics/Horn.luau, Siren.luau).
	Horn_Ship = rl(9119077417, 0.9, "Ship Horn Uss Constellation 1 (SFX)", "aircraft carrier horn"),
	Horn_Ferry = rl(9114406660, 0.85, "Ferry Boat Horn Medium Cu Clean Twice 1 (SFX)"),
	Horn_Tug = rl(9120287542, 0.85, "Tugboat Horn 1 (SFX)"),
	Horn_Cutter = rl(9113467357, 0.8, "Boat Horn Short Long Blasts 1 (SFX)", "coast guard cutter"),
	Horn_Whistle = rl(9113467739, 0.8, "Boat Whistle Airy Tail 1 (SFX)"),
	Horn_WhistleHigh = rl(9113467743, 0.75, "Boat Whistle High Pitch Airy Tail 1 (SFX)"),
	Siren_Wail = rl(9119165131, 0.75, "Siren Wail 1 (SFX)", "looped on its steady part"),
	Siren_Yelp = rl(9119165420, 0.75, "Siren Yelp 1 (SFX)", "looped on its steady part"),
	Siren_HiLo = rl(9119163723, 0.75, "Siren Start And Away 1 (SFX)", "high and low tones"),
	Siren_Phaser = rl(9118848118, 0.7, "Scream Siren Very Rapid High Low Buzzy 2 (SFX)"),
	-- end RP-M5 stream A
} :: { [string]: Clip }

-- Which category each clip plays in (by name prefix).
local PREFIX_CATEGORY: { { string | Category } } = {
	{ "Music_", "Music" },
	{ "Radio_", "Radio" },
	{ "Wave_", "Ambience" },
	{ "Wind_", "Ambience" },
	{ "Rain_", "Ambience" },
	{ "Thunder_", "Ambience" },
	{ "Amb_", "Ambience" },
	{ "Rigging_", "Ambience" },
	{ "Bell_", "Ambience" },
	{ "Gull_", "Ambience" },
	{ "Under_", "Ambience" },
}

function AudioConfig.categoryOf(clipName: string): Category
	for _, row in PREFIX_CATEGORY do
		local prefix = row[1] :: string
		if string.sub(clipName, 1, #prefix) == prefix then
			return row[2] :: Category
		end
	end
	return "SFX"
end

function AudioConfig.id(clipName: string): string
	local c = AudioConfig.Clips[clipName]
	return if c then c.id else ""
end

-- Places (studs). Harbour centre for the marina bed, rigging and gulls; the bell buoy off the
-- harbour mouth (MapConfig.Places "Harbour Mouth").
AudioConfig.HarbourCentre = Vector3.new(0, 4, -150)
AudioConfig.HarbourRadius = 320 -- the marina bed and rigging fade out past this
AudioConfig.TownCentre = Vector3.new(0, 4, -250) -- MapConfig "PORT HAVEN"
AudioConfig.TownRadius = 260 -- the town murmur fades out past this
AudioConfig.BellBuoy = Vector3.new(-60, 5.25, 880) -- SeamarkRules No2Bell, ATT_Bell height
AudioConfig.CoastRadius = 900 -- gulls only within this of the harbour centre

-- Mix constants (tune by ear).
AudioConfig.Mix = {
	engineRange = 260, -- studs: boats and cars further than this have no engine sound
	slamMin = 4, -- telemetry.slam (studs/s) below this is not a slam
	slamCooldown = 0.35, -- s between hull impacts
	seaNearHeight = 70, -- studs above the surface where the sea bed has faded out
	gullMinGap = 6, -- s between gull calls
	gullMaxGap = 22,
	petVoiceMinGap = 18, -- s between a following pet's calls
	petVoiceMaxGap = 32,
	bellMinGap = 3.5, -- s between bell strokes in a calm (shorter in a storm)
	bellMaxGap = 9,
	riggingRate = 0.6, -- clinks per second at full wind
	musicFade = 3, -- s
}

-- RP-M5 stream C (Sea Shanty Radio): the radio's tracks are station data in
-- src/shared/Config/Cosmetics/Radio.luau (RL, APM; verified public, logged in candidates.csv as
-- MUS_Radio_*). They play as 3D Sounds on the vehicle in this category, through its RadioDuck group
-- (ducked under VHF lines) and further under Music_Operation (src/shared/ShantyRadio.luau).
AudioConfig.ShantyRadioCategory = "Music" :: Category
-- end RP-M5 stream C

return AudioConfig
