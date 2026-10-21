--!strict
-- HudLayout: the one HUD arrangement, pure and testable (tests/HudLayout.spec.luau). Sizes are
-- design units (du): the safe area divided by `scale`. UI/Layout turns the rects into ScreenGui
-- frames; the touch arrangement is decided here, from the screen size, the insets and the device.
--
-- Desktop / gamepad: objective top left with the phone button under it, status and the pager
-- column top right, notice top centre, minimap bottom left, gauges bottom right, radio bottom centre.
-- Touch: the phone button sits right of the minimap.
--
-- Touch (thumbstick bottom left, jump / action buttons bottom right):
--
--   +------------------------------------------------------------------+
--   | minimap   objective          notice (under the objective)  status |
--   | (110 px)                                                  --------|
--   | icon                                                      pager   |
--   |                                                           column  |
--   |                                                                   |
--   |            radio / prompt (unchanged)                             |
--   | [thumbstick]                                  [jump / actions]    |
--   +------------------------------------------------------------------+
--
-- The minimap moves to the top left at 110 final px (tap it for the full map, MapController)
-- (its objective pill drawn inside the square's bottom edge, MapController)
-- and the challenge tracker collapses to a 44 px icon under it, so the bottom-left 40% x 45%
-- stays empty for the thumbstick. The objective strip moves to the top centre (between the
-- minimap and the status strip) and the notice band sits under it; the pager column stops above
-- the bottom-right 30% x 35% jump zone. `tests/HudLayout.spec.luau` asserts this on a 16:9
-- phone, a 19.5:9 phone with notch insets and a 4:3 tablet.
local HudLayout = {}

HudLayout.MARGIN = 12 -- du from the safe-area edge
HudLayout.GAP = 8 -- du between stacked regions
HudLayout.SUBTITLE_HEIGHT = 118 -- the VHF set
HudLayout.STATUS_HEIGHT = 100 -- status strip (52) + crew row (40)
HudLayout.OBJECTIVE_HEIGHT = 132 -- step card (92) + takeover banner
HudLayout.PROMPT_HEIGHT = 230
HudLayout.NOTICE_HEIGHT = 120
HudLayout.GOAL_WIDTH = 260 -- the next-goal chip, under the status strip
HudLayout.GOAL_HEIGHT = 44
HudLayout.CHALLENGE_WIDTH = 214 -- the desktop tracker card
HudLayout.CHALLENGE_HEIGHT = 128
HudLayout.PILL_HEIGHT = 36 -- desktop: the minimap's objective pill (30 + 6) above the square
HudLayout.TOUCH_SIDE = 110 -- final px: the touch minimap square
HudLayout.TOUCH_ICON = 44 -- final px: the touch challenge icon (a minimum touch target)
HudLayout.PHONE_SIZE = 72 -- the phone button (UI/Phone), left side

local REF_HEIGHT = 720 -- usable px at which the HUD draws 1:1
local REF_WIDTH = 1200
local MIN_SCALE = 0.7

export type RegionName =
	"objective"
	| "status"
	| "right"
	| "notice"
	| "prompt"
	| "subtitle"
	| "minimap"
	| "gauges"
	| "challenge"
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
	subtitleWidth: number,
	noticeWidth: number,
	rects: { [string]: Rect },
}

local function rect(anchor: Vector2, pos: Vector2, size: Vector2): Rect
	return { anchor = anchor, pos = pos, size = size }
end

-- Pure: the region sizes and rects for a usable area in pixels.
function HudLayout.metrics(px: Vector2, touch: boolean): Metrics
	local s = math.clamp(math.min(px.Y / REF_HEIGHT, px.X / REF_WIDTH), MIN_SCALE, 1)
	local u = px / s
	local m, g = HudLayout.MARGIN, HudLayout.GAP
	local side = if touch
		then math.floor(HudLayout.TOUCH_SIDE / s + 0.5)
		else math.clamp(math.floor(u.Y * 0.3), 156, 230)
	local objectiveWidth = math.clamp(math.floor(u.X * 0.3), 320, 460)
	local rightWidth = math.clamp(math.floor(u.X * 0.24), 280, 360)
	if touch then
		-- keep the objective strip clear of the top-right status strip
		objectiveWidth = math.min(objectiveWidth, math.floor(u.X - 2 * m - 2 * rightWidth - 2 * g))
	end
	local outer = math.max(side, rightWidth)
	local noticeWidth = math.min(
		if touch
			then u.X - 2 * (math.max(objectiveWidth, rightWidth) + 2 * m)
			else u.X - 2 * (outer + 2 * m),
		420
	)
	local mt: Metrics = {
		scale = s,
		usable = u,
		touch = touch,
		side = side,
		objectiveWidth = objectiveWidth,
		rightWidth = rightWidth,
		centreWidth = math.min(u.X - 2 * (outer + 2 * m), 640),
		subtitleWidth = math.min(u.X - 2 * (side + 2 * m), 620),
		noticeWidth = noticeWidth,
		rects = {},
	}
	local bottom = u.Y - m
	local objectiveHeight = HudLayout.OBJECTIVE_HEIGHT
	if touch then
		local stickTop = u.Y * 0.55
		local icon = math.floor(HudLayout.TOUCH_ICON / s + 0.5)
		local under = m + side + g + icon <= stickTop - 4
		local noticeY = m + objectiveHeight + g
		local noticeH = math.clamp(stickTop - 4 - noticeY, 48, HudLayout.NOTICE_HEIGHT)
		local rightTop = m + HudLayout.STATUS_HEIGHT + g
		mt.rects["objective"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new(u.X / 2, m),
			Vector2.new(objectiveWidth, objectiveHeight)
		)
		mt.rects["status"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, m),
			Vector2.new(rightWidth, HudLayout.STATUS_HEIGHT)
		)
		mt.rects["right"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, rightTop),
			Vector2.new(rightWidth, math.max(u.Y * 0.65 - g - rightTop, 120))
		)
		mt.rects["notice"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new(u.X / 2, noticeY),
			Vector2.new(noticeWidth, noticeH)
		)
		mt.rects["minimap"] = rect(Vector2.new(0, 0), Vector2.new(m, m), Vector2.new(side, side))
		mt.rects["challenge"] = rect(
			Vector2.new(0, 0),
			if under then Vector2.new(m, m + side + g) else Vector2.new(m + side + g, m),
			Vector2.new(icon, icon)
		)
		-- the phone button: top left, right of the minimap (and of the icon when it sits there)
		mt.rects["phone"] = rect(
			Vector2.new(0, 0),
			Vector2.new(m + side + g + (if under then 0 else icon + g), m),
			Vector2.new(HudLayout.PHONE_SIZE, HudLayout.PHONE_SIZE)
		)
		-- clear of the thumbstick (left 40%), the jump buttons (right 30%) and the VHF set
		local goalX =
			math.min(u.X - m - rightWidth - g, math.floor(u.X * 0.7) - g - HudLayout.GOAL_WIDTH)
		local goalY = math.min(
			m + objectiveHeight + g + HudLayout.NOTICE_HEIGHT + g,
			bottom - HudLayout.SUBTITLE_HEIGHT - g - HudLayout.GOAL_HEIGHT
		)
		mt.rects["goal"] = rect(
			Vector2.new(1, 0),
			Vector2.new(goalX + HudLayout.GOAL_WIDTH, goalY),
			Vector2.new(HudLayout.GOAL_WIDTH, HudLayout.GOAL_HEIGHT)
		)
	else
		mt.rects["objective"] =
			rect(Vector2.new(0, 0), Vector2.new(m, m), Vector2.new(objectiveWidth, objectiveHeight))
		mt.rects["status"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, m),
			Vector2.new(rightWidth, HudLayout.STATUS_HEIGHT)
		)
		local rightTop = m + HudLayout.STATUS_HEIGHT + g
		mt.rects["right"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m, rightTop),
			Vector2.new(rightWidth, math.max(bottom - side - g - rightTop, 120))
		)
		mt.rects["notice"] = rect(
			Vector2.new(0.5, 0),
			Vector2.new(u.X / 2, m),
			Vector2.new(noticeWidth, HudLayout.NOTICE_HEIGHT)
		)
		mt.rects["minimap"] =
			rect(Vector2.new(0, 1), Vector2.new(m, bottom), Vector2.new(side, side))
		mt.rects["challenge"] = rect(
			Vector2.new(0, 0),
			Vector2.new(m, bottom - side - HudLayout.PILL_HEIGHT - g - HudLayout.CHALLENGE_HEIGHT),
			Vector2.new(HudLayout.CHALLENGE_WIDTH, HudLayout.CHALLENGE_HEIGHT)
		)
		-- the phone button: left edge, under the objective
		mt.rects["phone"] = rect(
			Vector2.new(0, 0),
			Vector2.new(m, m + objectiveHeight + g),
			Vector2.new(HudLayout.PHONE_SIZE, HudLayout.PHONE_SIZE)
		)
		mt.rects["goal"] = rect(
			Vector2.new(1, 0),
			Vector2.new(u.X - m - rightWidth - g, m + HudLayout.NOTICE_HEIGHT + g),
			Vector2.new(HudLayout.GOAL_WIDTH, HudLayout.GOAL_HEIGHT)
		)
	end
	-- prompt, radio and gauges keep their place on every device (touch prompts are panels above
	-- the radio; gauges holds the touch action buttons at the bottom right on purpose)
	local b = bottom - HudLayout.SUBTITLE_HEIGHT - g
	mt.rects["prompt"] = rect(
		Vector2.new(0.5, 1),
		Vector2.new(u.X / 2, b),
		Vector2.new(
			mt.centreWidth,
			math.min(HudLayout.PROMPT_HEIGHT, b - (m + HudLayout.OBJECTIVE_HEIGHT + g))
		)
	)
	mt.rects["subtitle"] = rect(
		Vector2.new(0.5, 1),
		Vector2.new(u.X / 2, bottom),
		Vector2.new(mt.subtitleWidth, HudLayout.SUBTITLE_HEIGHT)
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
