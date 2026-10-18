--!strict
-- Cosmetics slot "Radio" (RP-M5 stream C). Sea Shanty Radio: the station the owner's boat or jet
-- ski radio plays (on/off and next track while aboard; src/client/Cosmetics/ShantyRadio.luau,
-- src/server/Cosmetics/ShantyRadio.luau, playlist logic in src/shared/ShantyRadio.luau). Others
-- can mute it (Settings: other players' radios).
-- Pass: SeaShantyRadio.
--
-- Tracks: Roblox licensed APM production music, public by licence (in-experience use only, not the
-- trailer). Every id returned OK from `tools/audio-search.py verify <id>` (2026-10-18) and is logged
-- in assets/audio/candidates.csv. `length` (s) is the catalogue duration; the server advances to
-- the next track when it has played out.
type Track = { id: number, title: string, artist: string, length: number }
type Option = { id: string, name: string, pass: string?, [string]: any }

local SHANTIES: { Track } = {
	{ id = 1836603892, title = "Deep Blue Sea Shanty 1", artist = "Murray Burns", length = 203 },
	{
		id = 1835239358,
		title = "Celtic Shanty Main",
		artist = "Bradley James Farmer",
		length = 162,
	},
	{ id = 1845759207, title = "Rolling Home", artist = "Otto Sieben", length = 189 },
	{ id = 1840238749, title = "Half O'Shanty", artist = "Ron Aspery", length = 93 },
	{
		id = 1840677765,
		title = "Dark Eyed Sailor (A)",
		artist = "Robin James Rutherford Jeffrey",
		length = 142,
	},
	{
		id = 1845885834,
		title = "When The Shantyboy Comes Down",
		artist = "David Charles Woodhead",
		length = 68,
	},
	{
		id = 1845957761,
		title = "Portsmouth Hornpipe A",
		artist = "Guy Edward Fletcher",
		length = 186,
	},
	{ id = 1836603945, title = "Deep Blue Sea Shanty 3", artist = "Murray Burns", length = 203 },
}

local FOLK: { Track } = {
	{ id = 1842715471, title = "The Session", artist = "Daniel Richard Price", length = 139 },
	{ id = 1842698288, title = "Three Sails", artist = "Daniel Richard Price", length = 136 },
	{ id = 1837231493, title = "Sligo Hornpipes", artist = "Ian Smith", length = 192 },
	{ id = 1845868836, title = "Sailor's Waltz", artist = "Heinz Matschurat", length = 118 },
	{ id = 1842715368, title = "Holkey Folkey", artist = "Daniel Richard Price", length = 156 },
	{ id = 1845759329, title = "A Sailor's Prayer", artist = "Otto Sieben", length = 191 },
	{ id = 1842698359, title = "Happy Jig", artist = "Hans Hummer", length = 171 },
	{ id = 1842715412, title = "Home And Dry", artist = "Daniel Richard Price", length = 142 },
}

local options: { Option } = {
	{ id = "Off", name = "Radio off", pass = nil, tracks = {} },
	{ id = "Shanties", name = "Shanties", pass = "SeaShantyRadio", tracks = SHANTIES },
	{ id = "Folk", name = "Maritime folk", pass = "SeaShantyRadio", tracks = FOLK },
}

return {
	slot = "Radio",
	options = options,
	default = "Off",
}
