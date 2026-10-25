--!strict
-- A11yPalette: the colour-blind-safe palette and one glyph per state (docs 14 section 2). Every
-- state in a group has its own symbol, and the group's colours are spaced in luminance, so nothing
-- depends on colour alone. SettingsPanel picks the palette ("Off" uses Default); OpsDebrief,
-- OpsStepCard and the map markers read it. Pure, Lune-tested in tests/A11yPalette.spec.
--
--   A11yPalette.setMode("Off" | "Deuteranopia" | "Protanopia" | "Tritanopia")
--   A11yPalette.colour(group, state) / A11yPalette.symbol(group, state)
--   A11yPalette.triageShape(tag): Enum.PartType (the vest tags also differ in shape)

local A11yPalette = {}

export type PaletteMode = "Default" | "Deuteranopia" | "Protanopia" | "Tritanopia"
export type State = { colour: Color3, symbol: string }

local MODES: { PaletteMode } = { "Default", "Deuteranopia", "Protanopia", "Tritanopia" }
A11yPalette.Modes = table.freeze(MODES)

A11yPalette.States = table.freeze({
	Rarity = { "Common", "Uncommon", "Rare", "Epic", "Legendary" },
	Grade = { "Gold", "Silver", "Bronze", "Fail", "Takeover" },
	Triage = { "Red", "Yellow", "Green", "Black" },
	Mark = { "Pass", "Fail", "Pending" },
})

-- The non-colour cue for every state. Marker names are the map blips (MapConfig).
local SYMBOLS: { [string]: { [string]: string } } = {
	Rarity = {
		Common = "●",
		Uncommon = "▲",
		Rare = "◆",
		Epic = "★",
		Legendary = "♛",
	},
	Grade = { Gold = "★", Silver = "◈", Bronze = "◆", Fail = "✕", Takeover = "↔" },
	Triage = { Red = "✚", Yellow = "▲", Green = "●", Black = "■" },
	Mark = { Pass = "✓", Fail = "✕", Pending = "○" },
	Marker = {
		Casualty = "!",
		Vessel = "▲",
		DropOff = "D",
		Waypoint = "W",
		Vehicle = "V",
		Home = "⌂",
		Crew = "C",
		Racer = "✚",
		Storm = "◉",
		SeamarkPort = "◀",
		SeamarkStarboard = "▶",
		SeamarkCardinal = "✦",
		SeamarkSafe = "●",
		SeamarkDanger = "✕",
	},
}

local PALETTES: { [string]: { [string]: { [string]: Color3 } } } = {
	Default = {
		Rarity = {
			Common = Color3.fromHex("364148"),
			Uncommon = Color3.fromHex("2D7B31"),
			Rare = Color3.fromHex("6397E0"),
			Epic = Color3.fromHex("C8B1EC"),
			Legendary = Color3.fromHex("F7E6C3"),
		},
		Grade = {
			Gold = Color3.fromHex("FFE3B8"),
			Silver = Color3.fromHex("8F969B"),
			Bronze = Color3.fromHex("936037"),
			Fail = Color3.fromHex("5E3333"),
			Takeover = Color3.fromHex("EBAF90"),
		},
		Triage = {
			Red = Color3.fromHex("D83B3B"),
			Yellow = Color3.fromHex("F5D142"),
			Green = Color3.fromHex("62B772"),
			Black = Color3.fromHex("272727"),
		},
		Mark = {
			Pass = Color3.fromHex("92EDB4"),
			Fail = Color3.fromHex("B13528"),
			Pending = Color3.fromHex("98A1A7"),
		},
	},
	Deuteranopia = {
		Rarity = {
			Common = Color3.fromHex("364148"),
			Uncommon = Color3.fromHex("186FBA"),
			Rare = Color3.fromHex("C58A00"),
			Epic = Color3.fromHex("C5B3E4"),
			Legendary = Color3.fromHex("EBE6DD"),
		},
		Grade = {
			Gold = Color3.fromHex("FFE59F"),
			Silver = Color3.fromHex("799B9F"),
			Bronze = Color3.fromHex("9A5E2D"),
			Fail = Color3.fromHex("613131"),
			Takeover = Color3.fromHex("EBAF90"),
		},
		Triage = {
			Red = Color3.fromHex("3176C8"),
			Yellow = Color3.fromHex("F8CE6C"),
			Green = Color3.fromHex("87ACB1"),
			Black = Color3.fromHex("272727"),
		},
		Mark = {
			Pass = Color3.fromHex("92EDB4"),
			Fail = Color3.fromHex("945000"),
			Pending = Color3.fromHex("98A1A7"),
		},
	},
	Protanopia = {
		Rarity = {
			Common = Color3.fromHex("364148"),
			Uncommon = Color3.fromHex("007979"),
			Rare = Color3.fromHex("EA7411"),
			Epic = Color3.fromHex("D7ADEA"),
			Legendary = Color3.fromHex("F1E6D4"),
		},
		Grade = {
			Gold = Color3.fromHex("FFE59F"),
			Silver = Color3.fromHex("8B97A3"),
			Bronze = Color3.fromHex("936229"),
			Fail = Color3.fromHex("613131"),
			Takeover = Color3.fromHex("F2AD72"),
		},
		Triage = {
			Red = Color3.fromHex("3178C6"),
			Yellow = Color3.fromHex("FFCB59"),
			Green = Color3.fromHex("64B2B2"),
			Black = Color3.fromHex("252729"),
		},
		Mark = {
			Pass = Color3.fromHex("92EDB4"),
			Fail = Color3.fromHex("945000"),
			Pending = Color3.fromHex("98A1A7"),
		},
	},
	Tritanopia = {
		Rarity = {
			Common = Color3.fromHex("463B4F"),
			Uncommon = Color3.fromHex("C72C6A"),
			Rare = Color3.fromHex("6AA26C"),
			Epic = Color3.fromHex("C9B1ED"),
			Legendary = Color3.fromHex("F2E4EB"),
		},
		Grade = {
			Gold = Color3.fromHex("FFE0E5"),
			Silver = Color3.fromHex("8F969B"),
			Bronze = Color3.fromHex("AD4F4F"),
			Fail = Color3.fromHex("613131"),
			Takeover = Color3.fromHex("A1C4A3"),
		},
		Triage = {
			Red = Color3.fromHex("CD4078"),
			Yellow = Color3.fromHex("F9C5D7"),
			Green = Color3.fromHex("82B285"),
			Black = Color3.fromHex("252729"),
		},
		Mark = {
			Pass = Color3.fromHex("92EDB4"),
			Fail = Color3.fromHex("B13528"),
			Pending = Color3.fromHex("98A1A7"),
		},
	},
}

local current: PaletteMode = "Default"
local listeners: { () -> () } = {}

-- "Off" is the default palette; SettingsPanel passes the saved value straight through.
function A11yPalette.setMode(name: string)
	local want: PaletteMode = if name == "Deuteranopia"
			or name == "Protanopia"
			or name == "Tritanopia"
		then name
		else "Default"
	if want == current then
		return
	end
	current = want
	for _, fn in listeners do
		fn()
	end
end

-- Redraw a UI that paints itself from the palette (fires once now, then on every change).
function A11yPalette.onChanged(fn: () -> ())
	table.insert(listeners, fn)
	fn()
end

function A11yPalette.mode(): PaletteMode
	return current
end

function A11yPalette.state(group: string, name: string): State
	local colours = (PALETTES[current] :: any)[group]
	local symbol = (SYMBOLS[group] or {})[name]
	return {
		colour = if colours and colours[name] then colours[name] else Color3.fromRGB(120, 120, 120),
		symbol = symbol or "?",
	}
end

function A11yPalette.colour(group: string, name: string): Color3
	return A11yPalette.state(group, name).colour
end

function A11yPalette.symbol(group: string, name: string): string
	return A11yPalette.state(group, name).symbol
end

-- The triage band also changes shape: a colour-blind player can tell the tags apart by touch.
local TRIAGE_SHAPE = {
	Red = Enum.PartType.Block,
	Yellow = Enum.PartType.Wedge,
	Green = Enum.PartType.Cylinder,
	Black = Enum.PartType.Ball,
}

function A11yPalette.triageShape(tag: string): Enum.PartType
	return (TRIAGE_SHAPE :: any)[tag] or Enum.PartType.Block
end

return table.freeze(A11yPalette)
