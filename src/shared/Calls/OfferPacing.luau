--!strict
-- OfferPacing: when the next tasking may arrive (G69). Pure, Lune-tested in
-- tests/OfferPacing.spec.luau. No services and no Roblox types.
--
-- A rescue ends, the debrief pays out and the player gets a breather (walk the quay, open a crate,
-- look at the board) before the pager sounds again. A Great Storm or a live event quickens it; a
-- big call (Capsized Ferry) gives the longest one. An ignored or lost
-- offer also waits before the next. A player who has accepted nothing for two minutes and is on
-- foot by the station gets an easy call, so the board always shows a next thing.
local OfferPacing = {}

OfferPacing.AfterOp = 26 -- s after an ordinary rescue -- tune
OfferPacing.AfterBig = 40 -- s after a big call, whoever ran it -- tune
OfferPacing.AfterDecline = 15 -- s after an offer expires unanswered -- tune
OfferPacing.Rush = 0.5 -- multiplier while a Great Storm or live event runs -- tune
OfferPacing.IdleAfter = 120 -- s without an accepted call before the easy nudge -- tune
OfferPacing.NudgeRadius = 40 -- studs (flat) from the station for the nudge -- tune

-- Seconds from an operation's close to the next offer. The debrief sits on the first 10 s of
-- this; OpsHud closes it when the offer arrives (never holds the pager more than 10 s).
function OfferPacing.afterOp(isBig: boolean, weatherState: string?, liveEvent: boolean?): number
	local base = if isBig then OfferPacing.AfterBig else OfferPacing.AfterOp
	return if weatherState == "Storm" or liveEvent then base * OfferPacing.Rush else base
end

-- Seconds from an expired or replaced offer to the next one.
function OfferPacing.afterDecline(weatherState: string?, liveEvent: boolean?): number
	return if weatherState == "Storm" or liveEvent
		then OfferPacing.AfterDecline * OfferPacing.Rush
		else OfferPacing.AfterDecline
end

-- The idle nudge: nothing accepted for a while, standing on foot, near the station's call board.
function OfferPacing.nudgesIdle(
	secondsSinceAccepted: number,
	onFoot: boolean,
	stationDistance: number
): boolean
	return secondsSinceAccepted >= OfferPacing.IdleAfter
		and onFoot
		and stationDistance <= OfferPacing.NudgeRadius
end

return OfferPacing
