--!strict
-- OpsStepCard: the running operation as a slim objective strip (Layout "objective" region, top
-- left): a Glyph disc and one or two words (docs/16 K4). Every op runs radio_ack -> launch ->
-- auto_board -> transport (shared/Ops/Definitions/SimpleSteps), so there are three looks:
--   flare + "Go"      answer and get aboard (tasking, launch)
--   ring  + "1/3"     pick them up: survivors picked up / survivors in the call
--   home  + "Home"    bring them home
-- An NPC takeover turns the disc red with the NPC boat. The icon pops on every change. Under the
-- word, the distance to the objective (UI/Waypoint feeds distance()).
local TweenService = game:GetService("TweenService")

local Glyph = require(script.Parent.Glyph)
local HudTheme = require(script.Parent.HudTheme)

export type StepCard = {
	update: (s: { [string]: any }) -> (),
	hide: () -> (),
	distance: (text: string?) -> (),
}

local RED = Color3.fromHex("E8332A")
local GREEN = Color3.fromHex("2FA866")

-- step id -> glyph, disc colour, text ("count" = picked up / total)
local LOOK: { [string]: { glyph: string, color: Color3, text: string } } = {
	tasking = { glyph = "flare", color = RED, text = "Go" },
	launch = { glyph = "flare", color = RED, text = "Go" },
	recovery = { glyph = "ring", color = HudTheme.Colors.accent, text = "count" },
	transport = { glyph = "home", color = GREEN, text = "Home" },
}
-- the ferry's own step ids
LOOK.relay, LOOK.pickup, LOOK.movement = LOOK.tasking, LOOK.recovery, LOOK.transport
local TAKEOVER = { glyph = "boat", color = RED, text = "Too slow" }

-- Text-only twins for mechanic panels (Mechanics/PIW/Step headers).
local ICON_TEXT: { [string]: string } = {
	tasking = "🚨",
	launch = "🚤",
	recovery = "🙋",
	transport = "🏠",
}

local OpsStepCard = {}

function OpsStepCard.iconFor(id: string?): string
	return ICON_TEXT[id or ""] or "•"
end

-- At most two words of the step's label (the definitions keep them that short).
function OpsStepCard.shortFor(id: string?, label: string?): string
	local words = {}
	for w in string.gmatch(label or id or "", "%S+") do
		table.insert(words, w)
		if #words == 2 then
			break
		end
	end
	return table.concat(words, " ")
end

-- Survivors picked up so far (one recovery result each) out of the call's total.
local function count(s: { [string]: any }): string
	local n = 0
	for _, r in s.results or {} do
		if (r.stepId == "recovery" or r.stepId == "pickup") and r.grade ~= "Fail" then
			n += 1
		end
	end
	return `{n}/{math.max(s.total or 1, 1)}`
end

function OpsStepCard.new(gui: GuiBase2d): StepCard
	local H, DISC = 64, 50
	local body = Instance.new("Frame")
	body.Name = "StepCard"
	body.Size = UDim2.fromOffset(208, H)
	body.BackgroundTransparency = 1
	body.Visible = false
	body.Parent = gui
	HudTheme.skin(body)
	local pop = Instance.new("UIScale")
	pop.Parent = body

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, 8, 0.5, 0)
	disc.Size = UDim2.fromOffset(DISC, DISC)
	disc.BorderSizePixel = 0
	disc.Parent = body
	HudTheme.corner(disc, DISC // 2)
	HudTheme.stroke(disc, Color3.new(1, 1, 1), 2.5)
	local discPop = Instance.new("UIScale")
	discPop.Parent = disc
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.64, 0.64)
	icon.BackgroundTransparency = 1
	icon.Parent = disc

	local word =
		HudTheme.label("Step", "", UDim2.new(1, -(DISC + 26), 1, 0), HudTheme.NumberFont, 30, body)
	word.Position = UDim2.fromOffset(DISC + 18, 0)
	HudTheme.outline(word)
	local range = HudTheme.label(
		"Range",
		"",
		UDim2.new(1, -(DISC + 26), 0, 22),
		HudTheme.NumberFont,
		18,
		body
	)
	range.Position = UDim2.new(0, DISC + 18, 1, -26)
	range.Visible = false
	HudTheme.outline(range)

	local shown = { glyph = "", text = "" }
	local function popIn(target: Instance, from: number)
		local s = target:FindFirstChildOfClass("UIScale")
		if s then
			s.Scale = from
			TweenService:Create(
				s,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end

	local card: StepCard
	card = {
		update = function(s: { [string]: any })
			local mine: { [string]: any }? = nil
			for _, c in s.current or {} do
				if c.trackId == s.myTrack then
					mine = c
				end
			end
			local look = if s.takeover then TAKEOVER elseif mine then LOOK[mine.id] else nil
			if not look then
				return -- between steps (or an unknown step): keep the last look
			end
			local text = if look.text == "count" then count(s) else look.text
			if not body.Visible then
				body.Visible = true
				popIn(body, 0.7)
			end
			if look.glyph ~= shown.glyph then
				Glyph.draw(look.glyph, icon, Color3.new(1, 1, 1))
				disc.BackgroundColor3 = look.color
				popIn(disc, 1.35)
			elseif text ~= shown.text then
				popIn(disc, 1.2) -- someone climbed aboard
			end
			word.Text = text
			shown.glyph, shown.text = look.glyph, text
		end,
		hide = function()
			body.Visible = false
			shown.glyph, shown.text = "", ""
		end,
		distance = function(text: string?)
			local has = text ~= nil
			if range.Visible ~= has then
				range.Visible = has
				-- the word moves up to make room
				word.Size = UDim2.new(1, -(DISC + 26), if has then 0 else 1, if has then 38 else 0)
			end
			range.Text = text or ""
		end,
	}
	return card
end

return OpsStepCard
