--!strict
-- HudLayout: the one HUD arrangement, pure and testable (tests/HudLayout.spec.luau). Sizes are
-- design units (du): the safe area divided by `scale`. UI/Layout turns the rects into ScreenGui
-- frames; the touch arrangement is decided here, from the screen size, the insets and the device.
--
-- Every device: the menu (UI/Menu: a grid of kit icon buttons) sits at the left edge; the rest of the
-- left-hand HUD sits right of it.
--
-- Desktop / gamepad: the menu on the left edge with the wallet (a see-through Cash counter) under it,
-- the objective strip top left (right of the menu), the minimap bottom right (in the gauges square) with
-- the quest chip above it. The notice band sits top centre right of the objective; the prompt sits
-- bottom centre between the menu and the minimap. No call card: a call shows in the world (OpsHud).
--
-- Touch (thumbstick bottom left, jump / action buttons bottom right):
--
--   +------------------------------------------------------------------+
--   | menu menu menu menu  minimap  objective                          |
--   | menu menu menu menu  (130 px) wallet                             |
--   |                      notice                                      |
--   |       prompt (unchanged)                                         |
--   | [thumbstick]                                  [jump / actions]    |
--   +------------------------------------------------------------------+
--
-- Nothing reaches into Roblox's touch controls: the bottom-left 40% x 45% thumbstick zone (portrait: the
-- whole bottom 45%, where Roblox's dynamic stick starts) and the bottom-right 30% x 35% jump zone. The
-- menu grid takes as many rows as fit above the stick zone (4 x 2 on phones, 2 x 4 on tablets); the
-- minimap sits right of it at 130 final px (tap it for the full map, MapController), the objective strip
-- right of that (portrait: under it) and the wallet under the objective. The notice band sits beside
-- the wallet, or under it in the band between the two zones. The prompt keeps its place. Phone-sized screens use this arrangement on
-- every device (compute). The debrief toast takes the topmost free gap (debriefRect), shrinking to fit.
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
HudLayout.WALLET_WIDTH = 280 -- the Cash card (HudController)
HudLayout.WALLET_HEIGHT = 64
HudLayout.PILL_HEIGHT = 36 -- desktop: clear space above the square (the minimap bezel overhangs it)
HudLayout.TOUCH_SIDE = 130 -- final px: the touch minimap square
HudLayout.OBJECTIVE_MIN_WIDTH = 210 -- the step card is 208 wide
HudLayout.QUEST_WIDTH = 236 -- the quest tracker chip (UI/Menu): desktop above the minimap pill (bottom right)
HudLayout.QUEST_HEIGHT = 50
HudLayout.QUEST_TOUCH_HEIGHT = 34 -- touch: a tag over the minimap's bottom edge, ending where the objective may start
HudLayout.CHIPS_WIDTH = 420 -- docs/24 E: the tutorial goal chips / the permanent Next chip (UI/NextChip)
HudLayout.CHIPS_HEIGHT = 48 -- touch: under the 64 du step card, inside OBJECTIVE_HEIGHT (68 + 48 <= 132)
HudLayout.DEBRIEF_WIDTH = 340 -- the end-of-call toast (UI/OpsDebrief), drawn scaled to its region's width
HudLayout.DEBRIEF_HEIGHT = 96
HudLayout.DEBRIEF_MIN = 0.7 -- the smallest the toast may shrink to fit a gap
HudLayout.MENU_COUNT = 8 -- UI/Menu's buttons: Shop, Quests, Album, Pet, Crew, Settings, Map, Boat

-- The menu grid's cell per device (du): icon square, label row (text = label - 4), row gap, column gap.
-- Touch icons are >= 44 px at the 0.7 floor; desktop labels are bigger (kit polish).
local MENU_DESK = { icon = 72, label = 28, gap = 10, colGap = 22 }
local MENU_TOUCH = { icon = 64, label = 24, gap = 6, colGap = 14 }

-- usable px at which the HUD draws 1:1 (1080p draws 1.6x: wallet ~380x150 px, minimap ~335 px)
local REF_HEIGHT = 620
local REF_WIDTH = 1100
local MIN_SCALE = 0.7
local MAX_SCALE = 1.6

export type RegionName =
	"objective"
	| "status"
	| "notice"
	| "prompt"
	| "minimap"
	| "gauges"
	| "wallet"
	| "menu"
	| "quest"
	| "chips"
	| "debrief"

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
	centreWidth: number, -- prompt
	noticeWidth: number,
	menu: Menu,
	rects: { [string]: Rect },
}

local function rect(anchor: Vector2, pos: Vector2, size: Vector2): Rect
	return { anchor = anchor, pos = pos, size = size }
end

local function box(r: Rect): (number, number, number, number)
	local x = r.pos.X - r.anchor.X * r.size.X
	local y = r.pos.Y - r.anchor.Y * r.size.Y
	return x, y, x + r.size.X, y + r.size.Y
end

-- The debrief toast: the topmost band (at the toast's full height) with a free gap of at least DEBRIEF_MIN of its
-- width between the edge HUD (wallet, menu, minimap, quest, gauges) and the touch zones; the toast
-- shrinks to the gap. The objective is free: the step card hides while the debrief shows (OpsHud).
local function debriefRect(mt: Metrics, zones: { { number } }): Rect
	local u, m, g = mt.usable, HudLayout.MARGIN, HudLayout.GAP
	local W, H = HudLayout.DEBRIEF_WIDTH, HudLayout.DEBRIEF_HEIGHT
	local blocks = table.clone(zones)
	local ys = { m }
	for _, name in { "wallet", "menu", "minimap", "quest", "gauges" } do
		local x0, y0, x1, y1 = box(mt.rects[name])
		table.insert(blocks, { x0 - g, y0 - g, x1 + g, y1 + g })
		table.insert(ys, y1 + g)
	end
	table.sort(ys)
	for _, y in ys do
		local spans = {}
		for _, b in blocks do
			if b[2] < y + H and b[4] > y then
				table.insert(spans, b)
			end
		end
		table.sort(spans, function(a, b)
			return a[1] < b[1]
		end)
		local x, gapX, gapW = m, 0, 0
		for _, b in spans do
			if b[1] - x > gapW then
				gapX, gapW = x, b[1] - x
			end
			x = math.max(x, b[3])
		end
		if u.X - m - x > gapW then
			gapX, gapW = x, u.X - m - x
		end
		if gapW >= W * HudLayout.DEBRIEF_MIN and y + H <= u.Y - m then
			local w = math.min(gapW, W)
			return rect(
				Vector2.new(0.5, 0),
				Vector2.new(gapX + gapW / 2, y),
				Vector2.new(w, H * w / W)
			)
		end
	end
	return mt.rects["notice"] -- shortcut: no gap anywhere (no tested screen), share the notice band
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
		else menuGrid(MENU_DESK, u.Y - 2 * m - HudLayout.WALLET_HEIGHT - g)
	local left = m + menu.width + g -- the left-hand HUD starts right of the menu
	local objectiveWidth = math.clamp(math.floor(u.X * 0.3), 300, if touch then 460 else 360)
	local outer = math.max(side, math.clamp(math.floor(u.X * 0.24), 280, 360)) -- touch prompt clearance
	local bottom = u.Y - m
	local objectiveHeight = HudLayout.OBJECTIVE_HEIGHT
	local mt: Metrics = {
		scale = s,
		usable = u,
		touch = touch,
		side = side,
		objectiveWidth = objectiveWidth,
		centreWidth = math.min(u.X - 2 * (outer + 2 * m), 640),
		noticeWidth = 0,
		menu = menu,
		rects = {},
	}
	-- status is empty now (the friend chip lives in the wallet): a zero-height line, so it never
	-- pushes the mission card down
	mt.rects["status"] = rect(Vector2.new(1, 0), Vector2.new(u.X - m, m), Vector2.new(280, 0))
	if touch then
		-- Roblox's touch controls: the dynamic thumbstick bottom left (portrait: the whole bottom), the
		-- jump / action buttons bottom right. Every region ends above them.
		local portrait = u.X < u.Y
		local stickTop = u.Y * 0.55
		local jumpTop = u.Y * 0.65
		local cardLeft = u.X - m -- the right edge (no card column since the pager went)
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
		-- the goal chips take the objective region's bottom spare (the step card is 64 du high)
		mt.rects["chips"] = rect(
			Vector2.new(0, 0),
			Vector2.new(objectiveX, objectiveY + 68),
			Vector2.new(objectiveWidth, HudLayout.CHIPS_HEIGHT)
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
		mt.rects["quest"] = rect(
			Vector2.new(0, 0),
			Vector2.new(left, m + side + g - HudLayout.QUEST_TOUCH_HEIGHT),
			Vector2.new(side, HudLayout.QUEST_TOUCH_HEIGHT)
		)
	else
		-- the menu strip on the left edge with the wallet under it, the pair centred; the objective top left
		-- beside the menu; the minimap bottom right with the quest chip above its pill
		local menuTop = (u.Y - menu.height - HudLayout.WALLET_HEIGHT - g) / 2
		mt.rects["menu"] =
			rect(Vector2.new(0, 0), Vector2.new(m, menuTop), Vector2.new(menu.width, menu.height))
		mt.rects["wallet"] = rect(
			Vector2.new(0, 0),
			Vector2.new(m, menuTop + menu.height + g),
			Vector2.new(HudLayout.WALLET_WIDTH, HudLayout.WALLET_HEIGHT)
		)
		mt.rects["objective"] = rect(
			Vector2.new(0, 0),
			Vector2.new(left, m),
			Vector2.new(objectiveWidth, objectiveHeight)
		)
		-- the top band right of the objective: the goal chip at the very top, award pops under it
		local x0 = left + objectiveWidth + g
		local x1 = u.X - m
		local chipsW = math.min(x1 - x0, HudLayout.CHIPS_WIDTH)
		mt.rects["chips"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new((x0 + x1) / 2, m),
			Vector2.new(chipsW, HudLayout.CHIPS_HEIGHT)
		)
		mt.noticeWidth = math.min(x1 - x0, 420)
		mt.rects["notice"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new((x0 + x1) / 2, m + HudLayout.CHIPS_HEIGHT + g),
			Vector2.new(mt.noticeWidth, HudLayout.NOTICE_HEIGHT)
		)
		mt.rects["minimap"] =
			rect(Vector2.new(1, 1), Vector2.new(u.X - m, bottom), Vector2.new(side, side))
		mt.rects["quest"] = rect(
			Vector2.new(1, 1),
			Vector2.new(u.X - m, bottom - side - HudLayout.PILL_HEIGHT - g),
			Vector2.new(HudLayout.QUEST_WIDTH, HudLayout.QUEST_HEIGHT)
		)
	end
	-- prompt and gauges keep their place on every device (the prompt clears the speed dock;
	-- gauges holds the touch action buttons at the bottom right on purpose; on desktop the minimap shares
	-- its square). Desktop: the prompt centres between the menu and the minimap.
	local b = bottom - HudLayout.SUBTITLE_HEIGHT - g
	local cx = u.X / 2
	if not touch then
		local p0, p1 = left, u.X - m - side - g
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
	local stickRight = if u.X < u.Y then u.X else u.X * 0.4
	mt.rects["debrief"] = debriefRect(
		mt,
		if touch
			then { { 0, u.Y * 0.55, stickRight, u.Y }, { u.X * 0.7, u.Y * 0.65, u.X, u.Y } }
			else {}
	)
	return mt
end

-- Pure: screen size and insets in pixels -> the metrics and rects for this device.
-- device is "Touch" | "Gamepad" | "Keyboard" (UI/Layout reads it from UserInputService).
-- Phone-sized screens (portrait, or under PHONE_HEIGHT px of safe height) get the touch arrangement on every
-- device: the desktop column stack collides there (verify 2026-10-26, Studio windows at phone sizes).
HudLayout.PHONE_HEIGHT = 480
function HudLayout.compute(screen: Vector2, insets: Insets, device: string): Metrics
	local px = Vector2.new(
		math.max(screen.X - insets.left - insets.right, 1),
		math.max(screen.Y - insets.top - insets.bottom, 1)
	)
	return HudLayout.metrics(px, device == "Touch" or px.Y < HudLayout.PHONE_HEIGHT or px.X < px.Y)
end

return HudLayout
