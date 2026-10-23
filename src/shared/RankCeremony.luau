--!strict
-- RankCeremony: pure presentation data for the promotion beat (docs 03 section 3, docs 04 the
-- unveil). The rank's colour, its insignia stripe count, the icons for its unlocks and the rule
-- that a fast boat skips the camera move. No UI here; RankBadge and RankFx draw it.

local ProgressionConfig = require(script.Parent.Config:WaitForChild("ProgressionConfig"))

local RankCeremony = {}

-- One signal-ish colour per rank, readable on the slate HUD without breaking the world palette.
local COLOURS = {
	Color3.fromHex("8C9BA6"), -- Recruit, steel
	Color3.fromHex("3F9C6E"), -- Lifeguard, sea green
	Color3.fromHex("2F8FA6"), -- Rescue Swimmer, teal
	Color3.fromHex("C9762F"), -- Coxswain, copper
	Color3.fromHex("4E86C9"), -- Rescue Pilot, sky
	Color3.fromHex("D6CFC0"), -- Captain, ivory
	Color3.fromHex("7C6BB3"), -- Commodore, violet
	Color3.fromHex("E3C88F"), -- Admiral, brass
}
local STAR_COLOUR = Color3.fromHex("E3C88F")

-- A camera orbit that starts while the player is running a fast boat makes people seasick and
-- steals the helm view; past this speed the beat keeps its UI and world FX only.
RankCeremony.FastSpeed = 24 -- studs/s

function RankCeremony.colour(rankIndex: number): Color3
	return COLOURS[math.clamp(rankIndex, 1, #COLOURS)]
end

function RankCeremony.starColour(): Color3
	return STAR_COLOUR
end

-- Insignia stripes: one per rank, capped so the disc never turns into a barcode.
function RankCeremony.stripes(rankIndex: number): number
	return math.clamp(rankIndex, 1, 8)
end

function RankCeremony.rankIndex(rankIndex: number): number
	return math.clamp(rankIndex, 1, #ProgressionConfig.Ranks)
end

-- "Jet Ski" -> boat, "Captain's cap" -> gear, "Open Sea" -> mission, anything else -> medal.
function RankCeremony.unlockKind(text: string): string
	local t = string.lower(text)
	if
		t:find("4x4")
		or t:find("boat")
		or t:find("helicopter")
		or t:find("rib")
		or t:find("jet")
		or t:find("ski")
		or t:find("helipad")
	then
		return "boat"
	elseif t:find("gear") or t:find("livery") or t:find("coat") or t:find("cap") then
		return "gear"
	elseif
		t:find("sea")
		or t:find("storm")
		or t:find("point")
		or t:find("north")
		or t:find("winch")
		or t:find("front")
		or t:find("bay")
	then
		return "mission"
	end
	return "medal"
end

-- The icons shown under the badge: the rank's unlocks.
function RankCeremony.unlockIcons(rankIndex: number): { string }
	local rank = ProgressionConfig.Ranks[RankCeremony.rankIndex(rankIndex)]
	local kinds = {}
	for _, text in rank.unlocks do
		table.insert(kinds, RankCeremony.unlockKind(text))
	end
	return kinds
end

function RankCeremony.orbitNeeded(speed: number): boolean
	return speed < RankCeremony.FastSpeed
end

-- Seconds the beat runs before the next queued one may start.
function RankCeremony.seconds(kind: string): number
	return if kind == "star" then 4.6 else 8.2
end

return RankCeremony
