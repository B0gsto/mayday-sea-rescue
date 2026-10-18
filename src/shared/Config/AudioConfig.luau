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
	Rigging_Clink_1 = rl(9114462292, 0.25, "Flagpole Hit 1 (SFX)", "halyard on a mast"),
	Rigging_Clink_2 = rl(9114462293, 0.25, "Flagpole Hit 3 (SFX)"),
	Rigging_Clink_3 = rl(9114462450, 0.25, "Flagpole Hit 4 (SFX)"),
	Rigging_Creak = rl(9114462106, 0.2, "Flagpole Creak 2 (SFX)"),
	Bell_Buoy = rl(9113420681, 0.5, "Bell Rings 3 (SFX)"),
	Gull_Call_1 = rl(9118858259, 0.35, "Seagull Squawks 3 (SFX)"),
	Gull_Call_2 = rl(9118858279, 0.35, "Seagull Squawks 1 (SFX)"),
	Gull_Flock = rl(9112870623, 0.25, "Seagulls 1 (SFX)"),

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

	-- Music (APM via Roblox). Two cues: an operation underway, and the debrief.
	Music_Operation = rl(1837463124, 0.35, "Tension Bed for One (APM, The Box)"),
	Music_Debrief = rl(
		84002131639340,
		0.4,
		"Cinematic Hopeful Gravitas Underscore Ambient Only (APM)"
	),
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
AudioConfig.BellBuoy = Vector3.new(30, 2, 450)
AudioConfig.CoastRadius = 900 -- gulls only within this of the harbour centre

-- Mix constants (tune by ear).
AudioConfig.Mix = {
	engineRange = 260, -- studs: boats and cars further than this have no engine sound
	slamMin = 4, -- telemetry.slam (studs/s) below this is not a slam
	slamCooldown = 0.35, -- s between hull impacts
	seaNearHeight = 70, -- studs above the surface where the sea bed has faded out
	gullMinGap = 6, -- s between gull calls
	gullMaxGap = 22,
	bellMinGap = 3.5, -- s between bell strokes in a calm (shorter in a storm)
	bellMaxGap = 9,
	riggingRate = 0.6, -- clinks per second at full wind
	musicFade = 3, -- s
}

return AudioConfig
