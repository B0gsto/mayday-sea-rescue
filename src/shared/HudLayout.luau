--!strict
-- HudLayout: the one HUD arrangement, pure and testable (tests/HudLayout.spec.luau). Sizes are
-- design units (du): the safe area divided by `scale`. UI/Layout turns the rects into ScreenGui
-- frames; the touch arrangement is decided here, from the screen size, the insets and the device.
--
-- Every device: the menu (UI/Menu: a grid of kit icon buttons) sits at the left edge; the rest of the
-- left-hand HUD sits right of it. No radio strip, no goal chip.
--
-- Desktop / gamepad: the wallet top left (right of the menu) with the objective strip under it,
-- the minimap bottom left (right of the menu), the mission card column top right, gauges bottom
-- right. The notice band sits top centre in the gap between the wallet / objective and the card
-- column; the prompt sits bottom centre between the minimap and the gauges.
--
-- Touch (thumbstick bottom left, jump / action buttons bottom right):
--
--   +------------------------------------------------------------------+
--   | menu menu menu menu  minimap  objective                  mission |
--   | menu menu menu menu  (130 px) wallet                     card    |
--   |                      notice                              column  |
--   |       prompt (unchanged)                                         |
--   | [thumbstick]                                  [jump / actions]    |
--   +------------------------------------------------------------------+
--
-- Nothing reaches into Roblox's touch controls: the bottom-left 40% x 45% thumbstick zone (portrait: the
-- whole bottom 45%, where Roblox's dynamic stick starts) and the bottom-right 30% x 35% jump zone. The
-- menu grid takes as many rows as fit above the stick zone (4 x 2 on phones, 2 x 4 on tablets); the
-- minimap sits right of it at 130 final px (tap it for the full map, MapController), the objective strip
-- right of that (portrait: under it) and the wallet under the objective. The notice band sits beside
-- the wallet, or under it in the band between the two zones; the mission card column (TOUCH_CARD_WIDTH,
-- the pager) stops above the jump zone. The prompt keeps its place.
-- `tests/HudLayout.spec.luau` asserts this on 16:9 / 19.5:9 / small Android phones (landscape and
-- portrait) and 4:3 tablets.
local HudLayout = {}

HudLayout.MARGIN = 24 -- du from the safe-area edge
HudLayout.GAP = 14 -- du between stacked regions
HudLayout.SUBTITLE_HEIGHT = 118 -- the prompt's clearance over the speed dock (bottom centre)
HudLayout.OBJECTIVE_HEIGHT = 132 -- step card (92) + breathing room
HudLayout.PROMPT_HEIGHT = 230
HudLayout.NOTICE_HEIGHT = 120
HudLayout.NOTICE_MIN_WIDTH = 200 -- touch: narrower beside the wallet -> the centre band under it
HudLayout.WALLET_WIDTH = 236 -- the Cash card (HudController)
HudLayout.WALLET_HEIGHT = 54
HudLayout.PILL_HEIGHT = 36 -- desktop: clear space above the square (the minimap bezel overhangs it)
HudLayout.TOUCH_SIDE = 130 -- final px: the touch minimap square
HudLayout.TOUCH_CARD_WIDTH = 130 -- touch: the mission card column (the pager is 120 wide)
HudLayout.OBJECTIVE_MIN_WIDTH = 210 -- the step card is 208 wide
HudLayout.MENU_COUNT = 8 -- UI/Menu's buttons: Shop, Quests, Album, Pet, Crew, Settings, Map, Boat

-- The menu grid's cell per device (du): icon square, label row (text = label - 4), row gap, column gap.
-- Touch icons are >= 43 px at the 0.7 floor; desktop labels are bigger (kit polish).
local MENU_DESK = { icon = 72, label = 28, gap = 10, colGap = 22 }
local MENU_TOUCH = { icon = 62, label = 24, gap = 6, colGap = 16 }

-- usable px at which the HUD draws 1:1 (1080p draws 1.6x: wallet ~380x150 px, minimap ~335 px)
local REF_HEIGHT = 620
local REF_WIDTH = 1100
local MIN_SCALE = 0.7
local MAX_SCALE = 1.6

export type RegionName =
	"objective"
	| "status"
	| "right"
	| "notice"
	| "prompt"
	| "minimap"
	| "gauges"
	| "wallet"
	| "menu"

export type Rect = {
	anchor: Vector2,
	pos: Vector2, -- offset from the anchor, du
	size: Vector2, -- du
}

export type Insets = { top: number, bottom: number, left: number, right: number }

export type Menu = {
	icon: number,
	label: number,
	gap: number,
	colGap: number,
	rows: number,
	cols: number,
	width: number,
	height: number,
}

export type Metrics = {
	scale: number,
	usable: Vector2, -- design units
	touch: boolean,
	side: number, -- minimap / gauges square
	objectiveWidth: number,
	rightWidth: number,
	centreWidth: number, -- prompt
	noticeWidth: number,
	menu: Menu,
	rects: { [string]: Rect },
}

local function rect(anchor: Vector2, pos: Vector2, size: Vector2): Rect
	return { anchor = anchor, pos = pos, size = size }
end

-- As many rows as fit `height`, then balanced columns (8 buttons: 2 x 4 on every current screen).
local function menuGrid(c: typeof(MENU_DESK), height: number): Menu
	local n = HudLayout.MENU_COUNT
	local cell = c.icon + c.label + c.gap
	local rows = math.clamp(math.floor((height + c.gap) / cell), 1, n)
	local cols = math.ceil(n / rows)
	rows = math.ceil(n / cols)
	return {
		icon = c.icon,
		label = c.label,
		gap = c.gap,
		colGap = c.colGap,
		rows = rows,
		cols = cols,
		width = cols * c.icon + (cols - 1) * c.colGap,
		height = rows * cell - c.gap,
	}
end

-- Pure: the region sizes and rects for a usable area in pixels.
function HudLayout.metrics(px: Vector2, touch: boolean): Metrics
	local s = math.clamp(math.min(px.Y / REF_HEIGHT, px.X / REF_WIDTH), MIN_SCALE, MAX_SCALE)
	local u = px / s
	local m, g = HudLayout.MARGIN, HudLayout.GAP
	local side = if touch
		then math.floor(HudLayout.TOUCH_SIDE / s + 0.5)
		else math.clamp(math.floor(u.Y * 0.31), 156, 230)
	-- touch: as many rows as fit above the thumbstick zone (4 x 2 on phones, 2 x 4 on tablets)
	local menu = if touch
		then menuGrid(MENU_TOUCH, u.Y * 0.55 - 4 - m)
		else menuGrid(MENU_DESK, u.Y - 2 * m)
	local left = m + menu.width + g -- the left-hand HUD starts right of the menu
	local objectiveWidth = math.clamp(math.floor(u.X * 0.3), 300, if touch then 460 else 360)
	local rightWidth = math.clamp(math.floor(u.X * 0.24), 280, 360)
	local rightLeft = u.X - m - rightWidth
	local outer = math.max(side, rightWidth)
	local bottom = u.Y - m
	local objectiveHeight = HudLayout.OBJECTIVE_HEIGHT
	local mt: Metrics = {
		scale = s,
		usable = u,
		touch = touch,
		side = side,
		objectiveWidth = objectiveWidth,
		rightWidth = rightWidth,
		centreWidth = math.min(u.X - 2 * (outer + 2 * m), 640),
		noticeWidth = 0,
		menu = menu,
		rects = {},
	}
	-- status is empty now (the friend chip lives in the wallet): a zero-height line, so it never
	-- pushes the mission card down
	mt.rects["status"] =
		rect(Vector2.new(1, 0), Vector2.new(u.X - m, m), Vector2.new(rightWidth, 0))
	if touch then
		-- Roblox's touch controls: the dynamic thumbstick bottom left (portrait: the whole bottom), the
		-- jump / action buttons bottom right. Every region ends above them.
		local portrait = u.X < u.Y
		local stickTop = u.Y * 0.55
		local jumpTop = u.Y * 0.65
		local cardBottom = if portrait then stickTop - 1 else jumpTop - 1
		local cardLeft = u.X - m - HudLayout.TOUCH_CARD_WIDTH
		mt.rects["menu"] =
			rect(Vector2.new(0, 0), Vector2.new(m, m), Vector2.new(menu.width, menu.height))
		mt.rects["minimap"] = rect(Vector2.new(0, 0), Vector2.new(left, m), Vector2.new(side, side))
		-- the objective right of the minimap; no room there (portrait): under it
		local objectiveX, objectiveY = left + side + g, m
		if cardLeft - g - objectiveX < HudLayout.OBJECTIVE_MIN_WIDTH then
			objectiveX, objectiveY = left, m + side + g
		end
		objectiveWidth = math.min(objectiveWidth, cardLeft - g - objectiveX)
		mt.objectiveWidth = objectiveWidth
		mt.rects["objective"] = rect(
			Vector2.new(0, 0),
			Vector2.new(objectiveX, objectiveY),
			Vector2.new(objectiveWidth, objectiveHeight)
		)
		-- the wallet card under the objective, scaled down (by height, HudController) to its width and to
		-- end above the thumbstick zone
		local walletY = objectiveY + objectiveHeight + g
		local walletH = math.min(
			HudLayout.WALLET_HEIGHT,
			objectiveWidth * HudLayout.WALLET_HEIGHT / HudLayout.WALLET_WIDTH,
			if portrait or objectiveX < u.X * 0.4 then stickTop - 4 - walletY else math.huge
		)
		walletH = math.max(walletH, 40)
		local walletW = HudLayout.WALLET_WIDTH * walletH / HudLayout.WALLET_HEIGHT
		mt.rects["wallet"] =
			rect(Vector2.new(0, 0), Vector2.new(objectiveX, walletY), Vector2.new(walletW, walletH))
		-- the notice band beside the wallet; too narrow there (phones): under the wallet and the minimap,
		-- between the thumbstick and jump zones (portrait: under the wallet)
		local nx, ny = objectiveX + walletW + g, walletY
		local nw = math.min(cardLeft - g - nx, 420)
		local noticeBottom = bottom - HudLayout.SUBTITLE_HEIGHT - g
		if nw < HudLayout.NOTICE_MIN_WIDTH then
			ny = math.max(walletY + walletH, m + side) + g
			nx = if portrait then objectiveX else math.max(left, math.ceil(u.X * 0.4) + 1)
			local x1 = if portrait
				then cardLeft - g
				else math.min(cardLeft - g, math.floor(u.X * 0.7))
			nw = math.min(x1 - nx, 420)
		end
		if portrait or nx < u.X * 0.4 then
			noticeBottom = math.min(noticeBottom, stickTop - 4)
		end
		if nx + nw > u.X * 0.7 then
			noticeBottom = math.min(noticeBottom, jumpTop - 1)
		end
		mt.noticeWidth = nw
		mt.rects["notice"] = rect(
			Vector2.new(0, 0),
			Vector2.new(nx, ny),
			Vector2.new(nw, math.clamp(noticeBottom - ny, 48, HudLayout.NOTICE_HEIGHT))
		)
		mt.rects["right"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, m),
			Vector2.new(HudLayout.TOUCH_CARD_WIDTH, cardBottom - m)
		)
	else
		-- the menu strip centred on the left edge, the wallet top left beside it, the objective under
		mt.rects["menu"] =
			rect(Vector2.new(0, 0.5), Vector2.new(m, u.Y / 2), Vector2.new(menu.width, menu.height))
		mt.rects["wallet"] = rect(
			Vector2.new(0, 0),
			Vector2.new(left, m),
			Vector2.new(HudLayout.WALLET_WIDTH, HudLayout.WALLET_HEIGHT)
		)
		mt.rects["objective"] = rect(
			Vector2.new(0, 0),
			Vector2.new(left, m + HudLayout.WALLET_HEIGHT + g),
			Vector2.new(objectiveWidth, objectiveHeight)
		)
		-- the top band fills the gap between the wallet / objective and the card column
		local x0 = left + math.max(HudLayout.WALLET_WIDTH, objectiveWidth) + g
		local x1 = rightLeft - g
		mt.noticeWidth = math.min(x1 - x0, 420)
		mt.rects["notice"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new((x0 + x1) / 2, m),
			Vector2.new(mt.noticeWidth, HudLayout.NOTICE_HEIGHT)
		)
		mt.rects["right"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, m),
			Vector2.new(rightWidth, math.max(bottom - side - g - m, 120))
		)
		mt.rects["minimap"] =
			rect(Vector2.new(0, 1), Vector2.new(left, bottom), Vector2.new(side, side))
	end
	-- prompt and gauges keep their place on every device (the prompt clears the speed dock;
	-- gauges holds the touch action buttons at the bottom right on purpose). Desktop: the prompt
	-- centres between the minimap and the gauges.
	local b = bottom - HudLayout.SUBTITLE_HEIGHT - g
	local cx = u.X / 2
	if not touch then
		local p0, p1 = left + side + g, u.X - m - side - g
		cx = (p0 + p1) / 2
		mt.centreWidth = math.min(p1 - p0, 640)
	end
	mt.rects["prompt"] = rect(
		Vector2.new(0.5, 1),
		Vector2.new(cx, b),
		Vector2.new(
			mt.centreWidth,
			math.min(HudLayout.PROMPT_HEIGHT, b - (m + HudLayout.OBJECTIVE_HEIGHT + g))
		)
	)
	mt.rects["gauges"] =
		rect(Vector2.new(1, 1), Vector2.new(u.X - m, bottom), Vector2.new(side, side))
	return mt
end

-- Pure: screen size and insets in pixels -> the metrics and rects for this device.
-- device is "Touch" | "Gamepad" | "Keyboard" (UI/Layout reads it from UserInputService).
function HudLayout.compute(screen: Vector2, insets: Insets, device: string): Metrics
	local px = Vector2.new(
		math.max(screen.X - insets.left - insets.right, 1),
		math.max(screen.Y - insets.top - insets.bottom, 1)
	)
	return HudLayout.metrics(px, device == "Touch")
end

return HudLayout
