--!strict
-- HudLayout: the one HUD arrangement, pure and testable (tests/HudLayout.spec.luau). Sizes are
-- design units (du): the safe area divided by `scale`. UI/Layout turns the rects into ScreenGui
-- frames; the touch arrangement is decided here, from the screen size, the insets and the device.
--
-- Desktop / gamepad (assets/ui/hud/mockup.png): one top-left group (the phone button and the
-- wallet side by side at the wallet's height, the objective strip under them), the mission card
-- pinned top right, the radio strip top centre with the notice band under it, minimap bottom
-- left, gauges bottom right. Persistent pieces sit first in a column, so a hidden region never
-- leaves a hole above them. The radio ("subtitle") never sits over the craft (bottom centre in
-- the chase camera): top centre on desktop, under the objective strip on touch.
--
-- Touch (thumbstick bottom left, jump / action buttons bottom right):
--
--   +------------------------------------------------------------------+
--   | minimap  phone  objective                              mission   |
--   | (130 px)                                               card      |
--   |          wallet   notice                               column    |
--   |                                                        goal      |
--   |          (radio under the objective strip)       goal      |
--   |            prompt (unchanged)                                     |
--   | [thumbstick]                                  [jump / actions]    |
--   +------------------------------------------------------------------+
--
-- The minimap sits top left at 130 final px (tap it for the full map, MapController; its
-- objective pill drawn inside the square's bottom edge), the phone button right of it, the
-- objective strip after that and the wallet under the phone, scaled down to end above the
-- bottom-left 40% x 45% thumbstick zone. The notice band sits right of the wallet; the mission
-- card column and the goal chip stop above the bottom-right 30% x 35% jump zone.
-- `tests/HudLayout.spec.luau` asserts this on a 16:9 phone, a 19.5:9 phone with notch insets and
-- a 4:3 tablet.
local HudLayout = {}

HudLayout.MARGIN = 24 -- du from the safe-area edge
HudLayout.GAP = 14 -- du between stacked regions
HudLayout.SUBTITLE_HEIGHT = 118 -- the prompt's clearance over the speed dock (bottom centre)
HudLayout.RADIO_HEIGHT = 52 -- the compact radio strip ("subtitle" region)
HudLayout.OBJECTIVE_HEIGHT = 132 -- step card (92) + takeover banner
HudLayout.PROMPT_HEIGHT = 230
HudLayout.NOTICE_HEIGHT = 120
HudLayout.GOAL_WIDTH = 260 -- the next-goal chip
HudLayout.GOAL_HEIGHT = 44
HudLayout.WALLET_WIDTH = 236 -- the Cash + rank card (HudController), bottom left
HudLayout.WALLET_HEIGHT = 96
HudLayout.PILL_HEIGHT = 36 -- desktop: clear space above the square (the minimap bezel overhangs it)
HudLayout.TOUCH_SIDE = 130 -- final px: the touch minimap square
HudLayout.PHONE_SIZE = 72 -- the phone button (UI/Phone), top left
HudLayout.PHONE_MIN_PX = 64 -- final px: the phone button never draws smaller

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
	| "subtitle"
	| "minimap"
	| "gauges"
	| "wallet"
	| "goal"
	| "phone"

export type Rect = {
	anchor: Vector2,
	pos: Vector2, -- offset from the anchor, du
	size: Vector2, -- du
}

export type Insets = { top: number, bottom: number, left: number, right: number }

export type Metrics = {
	scale: number,
	usable: Vector2, -- design units
	touch: boolean,
	side: number, -- minimap / gauges square
	objectiveWidth: number,
	rightWidth: number,
	centreWidth: number, -- prompt
	noticeWidth: number,
	rects: { [string]: Rect },
}

local function rect(anchor: Vector2, pos: Vector2, size: Vector2): Rect
	return { anchor = anchor, pos = pos, size = size }
end

-- Pure: the region sizes and rects for a usable area in pixels.
function HudLayout.metrics(px: Vector2, touch: boolean): Metrics
	local s = math.clamp(math.min(px.Y / REF_HEIGHT, px.X / REF_WIDTH), MIN_SCALE, MAX_SCALE)
	local u = px / s
	local m, g = HudLayout.MARGIN, HudLayout.GAP
	local side = if touch
		then math.floor(HudLayout.TOUCH_SIDE / s + 0.5)
		else math.clamp(math.floor(u.Y * 0.31), 156, 230)
	local phone = math.max(HudLayout.PHONE_SIZE, math.ceil(HudLayout.PHONE_MIN_PX / s))
	local objectiveWidth = math.clamp(math.floor(u.X * 0.3), 320, 460)
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
		noticeWidth = math.min(u.X - 2 * (outer + 2 * m), 420),
		rects = {},
	}
	-- status is empty now (the friend chip lives in the wallet): a zero-height line, so it never
	-- pushes the mission card down
	mt.rects["status"] =
		rect(Vector2.new(1, 0), Vector2.new(u.X - m, m), Vector2.new(rightWidth, 0))
	if touch then
		local stickTop = u.Y * 0.55
		local jumpTop = u.Y * 0.65
		local phoneX = m + side + g
		local objectiveX = phoneX + phone + g
		objectiveWidth = math.min(objectiveWidth, rightLeft - g - objectiveX)
		mt.objectiveWidth = objectiveWidth
		-- the wallet card scales down (by height, HudController) to end above the thumbstick zone
		local walletY = m + math.max(phone, objectiveHeight) + g
		local walletH = math.clamp(stickTop - 4 - walletY, 40, HudLayout.WALLET_HEIGHT)
		local walletW = HudLayout.WALLET_WIDTH * walletH / HudLayout.WALLET_HEIGHT
		local noticeX = phoneX + walletW + g
		local noticeBottom = bottom - HudLayout.SUBTITLE_HEIGHT - g
		if noticeX < u.X * 0.4 then
			noticeBottom = math.min(noticeBottom, stickTop - 4)
		end
		mt.noticeWidth = math.min(rightLeft - g - noticeX, 420)
		local goalY = jumpTop - 1 - HudLayout.GOAL_HEIGHT
		mt.rects["minimap"] = rect(Vector2.new(0, 0), Vector2.new(m, m), Vector2.new(side, side))
		mt.rects["phone"] =
			rect(Vector2.new(0, 0), Vector2.new(phoneX, m), Vector2.new(phone, phone))
		-- the step card's row, then the radio strip under it (inside the old objective height)
		local radioY = m + objectiveHeight - HudLayout.RADIO_HEIGHT
		mt.rects["objective"] = rect(
			Vector2.new(0, 0),
			Vector2.new(objectiveX, m),
			Vector2.new(objectiveWidth, radioY - g - m)
		)
		mt.rects["subtitle"] = rect(
			Vector2.new(0, 0),
			Vector2.new(objectiveX, radioY),
			Vector2.new(objectiveWidth, HudLayout.RADIO_HEIGHT)
		)
		mt.rects["wallet"] =
			rect(Vector2.new(0, 0), Vector2.new(phoneX, walletY), Vector2.new(walletW, walletH))
		mt.rects["notice"] = rect(
			Vector2.new(0, 0),
			Vector2.new(noticeX, walletY),
			Vector2.new(
				mt.noticeWidth,
				math.clamp(noticeBottom - walletY, 48, HudLayout.NOTICE_HEIGHT)
			)
		)
		mt.rects["right"] =
			rect(Vector2.new(1, 0), Vector2.new(u.X - m, m), Vector2.new(rightWidth, goalY - g - m))
		-- bottom of the card column, just above the jump buttons
		mt.rects["goal"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, goalY),
			Vector2.new(HudLayout.GOAL_WIDTH, HudLayout.GOAL_HEIGHT)
		)
	else
		-- one group: the phone button squared to the wallet's height, the wallet beside it
		local deskPhone = HudLayout.WALLET_HEIGHT
		local groupW = deskPhone + g + HudLayout.WALLET_WIDTH
		mt.rects["phone"] =
			rect(Vector2.new(0, 0), Vector2.new(m, m), Vector2.new(deskPhone, deskPhone))
		mt.rects["wallet"] = rect(
			Vector2.new(0, 0),
			Vector2.new(m + deskPhone + g, m),
			Vector2.new(HudLayout.WALLET_WIDTH, HudLayout.WALLET_HEIGHT)
		)
		mt.rects["objective"] = rect(
			Vector2.new(0, 0),
			Vector2.new(m, m + HudLayout.WALLET_HEIGHT + g),
			Vector2.new(objectiveWidth, objectiveHeight)
		)
		-- the top-centre band clears the group on the left and the card column on the right
		mt.noticeWidth = math.min(u.X - 2 * (math.max(outer, groupW) + 2 * m), 420)
		local noticeY = m + HudLayout.RADIO_HEIGHT + g
		mt.rects["subtitle"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new(u.X / 2, m),
			Vector2.new(mt.noticeWidth, HudLayout.RADIO_HEIGHT)
		)
		mt.rects["right"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, m),
			Vector2.new(rightWidth, math.max(bottom - side - g - m, 120))
		)
		mt.rects["notice"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new(u.X / 2, noticeY),
			Vector2.new(mt.noticeWidth, HudLayout.NOTICE_HEIGHT)
		)
		mt.rects["minimap"] =
			rect(Vector2.new(0, 1), Vector2.new(m, bottom), Vector2.new(side, side))
		mt.rects["goal"] = rect(
			Vector2.new(1, 0),
			Vector2.new(rightLeft - g, noticeY + HudLayout.NOTICE_HEIGHT + g),
			Vector2.new(HudLayout.GOAL_WIDTH, HudLayout.GOAL_HEIGHT)
		)
	end
	-- prompt and gauges keep their place on every device (the prompt clears the speed dock;
	-- gauges holds the touch action buttons at the bottom right on purpose)
	local b = bottom - HudLayout.SUBTITLE_HEIGHT - g
	mt.rects["prompt"] = rect(
		Vector2.new(0.5, 1),
		Vector2.new(u.X / 2, b),
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
