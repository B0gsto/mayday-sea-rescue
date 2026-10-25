--!strict
-- Kit Theme: the "Roblox simulator" look (docs/23 (m)) as pure data and math, no services, so
-- tests/KitTheme.spec.luau loads it under Lune. Kit/Style turns it into instances.
--
-- Sizes are design units (du). Style.canvas puts a UIScale of Theme.scaleFor(viewport) over a
-- frame of viewport / scale du, so 1 du = 1 px on a 1280x720 desktop, 0.7 px on a phone (floor)
-- and up to 1.6 px on a big screen. Strokes and corners are du too (UIScale scales them).
local Theme = {}

-- Chunky rounded display font that ships with Roblox (content/fonts/families/FredokaOne.json).
Theme.FONT = "rbxasset://fonts/families/FredokaOne.json"
Theme.ROBUX = "rbxasset://textures/ui/common/robux@3x.png" -- Roblox's built-in white Robux glyph

local hex = Color3.fromHex

export type Grad = { top: Color3, bottom: Color3 }
local function g(top: string, bottom: string): Grad
	return { top = hex(top), bottom = hex(bottom) }
end

-- Vertical gradients (top lighter). Accent names are what components take as `color`.
Theme.Grad = {
	title = g("5FE3FF", "1E86F0"), -- cyan to blue title bars
	body = g("EAF6FF", "B7D6F5"), -- panel body
	buy = g("8DF25E", "1FAE3A"), -- green price buttons
	close = g("FF7A66", "D9202A"), -- red square X
	disabled = g("D7DBE1", "8D949E"),
	owned = g("9FE7FF", "3B9BD6"),
	locked = g("9AA0B4", "5A6076"),
	yellow = g("FFEA6B", "FFB21E"),
	orange = g("FFC266", "FF7419"),
	purple = g("CDA4FF", "8445F5"),
	pink = g("FFA6DA", "F2459C"),
	blue = g("8EE0FF", "2C8EF0"),
	green = g("A4F57A", "33BE4D"),
	red = g("FF8A7A", "E2333A"),
	teal = g("8FF5E2", "1DB59B"),
	ink = g("3A3F55", "1A1D2B"), -- dark pills (counters, number badges)
}

Theme.Colors = {
	ink = hex("14121C"), -- near-black outline, borders, text stroke
	text = hex("FFFFFF"),
	textDark = hex("23283D"), -- text on the light panel body
	badge = hex("FF3B3B"),
	ring = hex("FFE74A"), -- gamepad selection ring
	shadow = hex("000000"),
	backdrop = hex("0B1A2E"),
}

-- Colour-blind modes (A11yPalette mode names): green buy vs red close collapse for red-green
-- vision, so they swap to the Okabe-Ito blue / vermillion pair; every pair also differs by shape
-- (Robux glyph + number vs X) so colour is never the only cue.
local CVD: { [string]: { [string]: Grad } } = {
	Deuteranopia = { buy = g("6CC6FF", "0072B2"), close = g("FFB060", "D55E00") },
	Protanopia = { buy = g("6CC6FF", "0072B2"), close = g("FFB060", "D55E00") },
}

-- The gradient set for a palette mode ("Default" | "Deuteranopia" | "Protanopia" | "Tritanopia").
function Theme.palette(mode: string?): { [string]: Grad }
	local over = CVD[mode or "Default"]
	if not over then
		return Theme.Grad
	end
	local out = table.clone(Theme.Grad)
	for k, v in over do
		out[k] = v
	end
	return out
end

-- The 3D "lip" under a block: the bottom colour darkened.
function Theme.shade(c: Color3, k: number?): Color3
	local f = 1 - (k or 0.35)
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- Relative luminance (sRGB, WCAG), used by the spec to keep pairs apart.
function Theme.luminance(c: Color3): number
	local function lin(v: number): number
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end

Theme.Size = {
	corner = 14,
	cornerSmall = 10,
	border = 4, -- thick dark border
	lip = 6, -- 3D bottom edge of buttons and cards
	shadow = 8, -- panel drop shadow offset
	textStroke = 3.5,
	textStrokeSmall = 2,
	margin = 20,
	pad = 14,
	icon = 84, -- IconButton square
	iconLabel = 28, -- label row under it
	iconGap = 10,
	panel = Vector2.new(700, 560),
	titleBar = 74,
	close = 66,
	tab = 68, -- touch targets: >= 68 du = 48 px at the phone floor
	card = 132,
	price = Vector2.new(184, 70),
	counter = Vector2.new(230, 62),
	toast = 72,
	reply = 70,
	dialogWidth = 640,
	studTile = 22, -- the stud texture's tile size
}

Theme.Text = {
	title = 46,
	heading = 32,
	body = 26,
	button = 32,
	small = 22, -- 15 px at the phone floor: never smaller
}

-- Subtle stud texture on title bars and price buttons (owner, 2026-10-25). Off = flat.
Theme.STUDS = true
Theme.STUD_TRANSPARENCY = 0.68

local REF = Vector2.new(1280, 720)
Theme.MIN_SCALE = 0.7
Theme.MAX_SCALE = 1.6

-- UIScale for a viewport in px: 1 at 1280x720, the short side wins, clamped to [0.7, 1.6].
function Theme.scaleFor(viewport: Vector2): number
	local s = math.min(viewport.X / REF.X, viewport.Y / REF.Y)
	return math.clamp(s, Theme.MIN_SCALE, Theme.MAX_SCALE)
end

-- A centred panel's du size: its design size, shrunk to 92% x 86% of the viewport; on a portrait
-- screen it grows to 80% of the height (no dead space under a short panel).
function Theme.panelSize(viewport: Vector2, scale: number, want: Vector2): Vector2
	local h = if viewport.Y > viewport.X then math.max(want.Y, viewport.Y * 0.8 / scale) else want.Y
	return Vector2.new(
		math.floor(math.min(want.X, viewport.X * 0.92 / scale)),
		math.floor(math.min(h, viewport.Y * 0.86 / scale))
	)
end

-- Columns for the left icon-button bar: as many rows as fit in 86% of the height (at least 1).
function Theme.iconColumns(viewport: Vector2, scale: number, count: number): number
	local cell = Theme.Size.icon + Theme.Size.iconLabel + Theme.Size.iconGap
	local rows = math.max(1, math.floor(viewport.Y * 0.86 / scale / cell))
	return math.ceil(count / rows)
end

-- Price / counter text: 950, 1,250, 12.5K, 3.4M.
function Theme.short(n: number): string
	n = math.floor(n)
	if n >= 1e6 then
		return (string.format("%.1fM", math.floor(n / 1e5) / 10):gsub("%.0M", "M"))
	elseif n >= 1e4 then
		return (string.format("%.1fK", math.floor(n / 100) / 10):gsub("%.0K", "K"))
	end
	local s = tostring(n)
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

return table.freeze(Theme)
