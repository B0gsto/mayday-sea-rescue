--!strict
-- Cosmetics slot "Siren" (RP-M5 Siren Pack). Four real siren recordings (Pro Sound Effects via the
-- Roblox licensed library, ids checked with `audio-search.py verify`, logged in
-- assets/audio/candidates.csv; clips in AudioConfig "Siren_*"), each with a light pattern.
--
-- Toggle from the boat or jet ski the player is driving: keyboard G, gamepad DPadDown, or a tap
-- button on touch screens. A siren sounds only while the driver is on a tasking (docs 10 section 3.3) and stops when the operation ends.
-- Looped 3D Sound on the vehicle (SFX group, RollOffMaxDistance = `range`); other players can mute
-- sirens (Settings: sirens); your own is always audible.
--
-- ATTRIBUTE CONTRACT (server src/server/Cosmetics/Sirens sets these on the vehicle Model):
--   SirenTone    string  the sounding tone's option id ("Wail" | "Yelp" | "HiLo" | "Phaser"),
--                        "" when the siren is off
--   SirenPattern string  that tone's light pattern id (the option's `pattern`), "" when off
--   SirenBy      number  UserId of the player who switched it on (0 when off)
--   and the CollectionService tag "CosmeticSiren" while it sounds
-- Light bars (stream B) read SirenPattern and flash in the matching pattern:
--   "Wail"    slow alternate (left / right halves swap about once a second)
--   "Yelp"    fast alternate (left / right swap about four times a second)
--   "HiLo"    alternate halves (each half double-flashes, then the other half)
--   "Phaser"  quad flash (four quick flashes per side, alternating)
-- Patterns use the light bar's own colour set; they never pick a colour themselves.
--
-- Option fields (VehicleSounds reads them):
--   clip               AudioConfig clip name (nil = no pack tone)
--   pattern            light pattern id (see the contract above)
--   range              studs: RollOffMaxDistance of the looped Sound
--   loopStart/loopEnd  s: the steady part of the recording that loops (LoopRegion; tune by ear)
--   label              short text for the touch button
--   source             the recording, as titled in the licensed library
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard siren", pass = nil },
	{
		id = "Wail",
		name = "Wail",
		pass = "SirenPack",
		clip = "Siren_Wail",
		pattern = "Wail",
		range = 600,
		loopStart = 1.5,
		loopEnd = 9,
		label = "Wail",
		source = "Siren Wail, Emergency, Ambulance (PSE)",
	},
	{
		id = "Yelp",
		name = "Yelp",
		pass = "SirenPack",
		clip = "Siren_Yelp",
		pattern = "Yelp",
		range = 600,
		loopStart = 1.5,
		loopEnd = 9,
		label = "Yelp",
		source = "Siren Yelp, Emergency, Ambulance (PSE)",
	},
	{
		id = "HiLo",
		name = "Hi-lo two-tone",
		pass = "SirenPack",
		clip = "Siren_HiLo",
		pattern = "HiLo",
		range = 600,
		loopStart = 1.5,
		loopEnd = 9,
		label = "Hi-lo",
		source = "Siren, High and Low Tones, Emergency, Ambulance (PSE)",
	},
	{
		id = "Phaser",
		name = "Phaser (rapid high-low)",
		pass = "SirenPack",
		clip = "Siren_Phaser",
		pattern = "Phaser",
		range = 550,
		loopStart = 0.3,
		loopEnd = 5,
		label = "Phaser",
		source = "Scream Siren, Very Rapid High Low, Buzzy, Stationary Bursts (PSE)",
	},
}

return {
	slot = "Siren",
	options = options,
	default = "Standard",
}
