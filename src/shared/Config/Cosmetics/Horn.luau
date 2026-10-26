--!strict
-- Cosmetics slot "Horn" (RP-M5 Horn Pack). Six real marine horn recordings (Pro Sound Effects via
-- the Roblox licensed library, each id checked with `audio-search.py verify` and logged in
-- assets/audio/candidates.csv; clips in AudioConfig "Horn_*").
--
-- Played on a tap from the boat or jet ski the player is driving: keyboard H, gamepad L3, or a tap
-- button on touch screens.
-- The server (src/server/Cosmetics/Horns) checks driver + pass + cooldown, then FireNear "Horn" to
-- clients within `range`; the client (src/client/Cosmetics/Horns) plays a 3D Sound on the vehicle
-- in the SFX group. Other players can mute horns (Settings: horns); your own is always audible.
--
-- "Standard" (free) is no horn (boats have none), so the tap button only shows while a Horn Pack
-- horn is equipped.
--
-- Option fields (VehicleSounds reads them):
--   clip    AudioConfig clip name (nil = no pack horn)
--   range   studs: RollOffMaxDistance of the Sound and the FireNear radius
--   length  s: the horn is cut (with a short fade) after this; also its cooldown
--   label   short text for the touch button
--   source  the recording, as titled in the licensed library
-- Shape: { slot, options = { { id, name, pass = <GamePass key, nil for free>, ...free-form } }, default }.
type Option = { id: string, name: string, pass: string?, [string]: any }

local options: { Option } = {
	{ id = "Standard", name = "Standard horn", pass = nil },
	{
		id = "ShipHorn",
		name = "Ship's horn",
		pass = "HornPack",
		clip = "Horn_Ship",
		range = 700,
		length = 5,
		label = "Ship horn",
		source = "Ship Horn, Aircraft Carrier, USS Constellation (PSE)",
	},
	{
		id = "FerryHorn",
		name = "Ferry horn",
		pass = "HornPack",
		clip = "Horn_Ferry",
		range = 650,
		length = 7,
		label = "Ferry horn",
		source = "Ferry Boat Horn, Medium CU, Clean, Twice (PSE)",
	},
	{
		id = "TugHorn",
		name = "Tug air horn",
		pass = "HornPack",
		clip = "Horn_Tug",
		range = 550,
		length = 4,
		label = "Tug horn",
		source = "Tugboat Horn, Single and Double Bursts (PSE)",
	},
	{
		id = "CutterHorn",
		name = "Coast guard cutter horn",
		pass = "HornPack",
		clip = "Horn_Cutter",
		range = 500,
		length = 3,
		label = "Cutter horn",
		source = "Boat Horn, On Coast Guard Cutter, Short and Long Blast of Hailer Horn (PSE)",
	},
	{
		id = "ShipWhistle",
		name = "Ship's whistle",
		pass = "HornPack",
		clip = "Horn_Whistle",
		range = 550,
		length = 6,
		label = "Whistle",
		source = "Boat Whistle, Airy, Tail (PSE)",
	},
	{
		id = "HighWhistle",
		name = "High-pitch boat whistle",
		pass = "HornPack",
		clip = "Horn_WhistleHigh",
		range = 500,
		length = 5,
		label = "High whistle",
		source = "Boat Whistle, High Pitch, Airy, Tail (PSE)",
	},
}

return {
	slot = "Horn",
	options = options,
	default = "Standard",
}
