--!strict
-- QuickLaunchCard (RP-A1 extra): the owner's side of the BoatDesk Quick Launch card (docs/04 section 3).
-- Non-owners see the RP-M3 product card (ProductShelves); a Quick Launch owner sees one page per boat
-- they may take out, each with a "Launch now" button that calls Vehicle_QuickLaunch (VehicleService,
-- RP-M2): seated at the helm at their bay, no walk and no launch cooldown. Rank and certification still
-- gate every boat (the server re-checks). Pure: no services, no requires (tests/QuickLaunch.spec.luau).

export type Ctx = {
	boats: { string }, -- launchable boat ids, in VehicleConfig.Order
	busy: string?, -- a launch request in flight for this boat id
	coldOpenDone: boolean,
	failure: string?, -- the server's last refusal for this boat (VehicleService reason code)
}

export type State = {
	canLaunch: boolean,
	buttonText: string,
	note: string?,
}

local QuickLaunchCard = {}

QuickLaunchCard.SHELF = "BoatDeskQuickLaunch"
QuickLaunchCard.PASS = "QuickLaunch"
QuickLaunchCard.EFFECT =
	"Quick Launch: straight to the helm at your bay. No walk down the slipway and no launch cooldown. Rank and certifications still apply."

-- The boats an owner may quick-launch: usable now (rank, certification, bought) and not a land vehicle.
function QuickLaunchCard.boats(
	order: { string },
	usable: (id: string) -> boolean,
	isLand: (id: string) -> boolean
): { string }
	local out: { string } = {}
	for _, id in order do
		if not isLand(id) and usable(id) then
			table.insert(out, id)
		end
	end
	return out
end

-- VehicleService refusals (spawnVehicle, MonetizationEffects.quickLaunchAllowed) -> card copy
local REASONS: { [string]: string } = {
	NotOwned = "Quick Launch is not on this account yet.",
	ColdOpen = "Finish your first rescue before Quick Launch.",
	Locked = "Your rank or certifications do not cover this boat yet.",
	NoBay = "No launch bay free at the moment. Try again shortly.",
	BayNotAllowed = "That bay cannot launch this boat.",
	BayBusy = "Your bay is busy. Try again in a moment.",
	Occupied = "Someone is aboard your boat. Wait for them to step off.",
	UnknownVehicle = "That boat is not in service.",
	Offline = "The launch bay is not answering. Try again.",
}

function QuickLaunchCard.reasonText(reason: string?): string
	return if reason and REASONS[reason] then REASONS[reason] else "Can't launch right now."
end

-- What the owner's page for `boat` shows. No boats at all: the card says why and offers nothing.
function QuickLaunchCard.state(ctx: Ctx, boat: string?): State
	if not ctx.coldOpenDone then
		return {
			canLaunch = false,
			buttonText = "Launch now",
			note = QuickLaunchCard.reasonText("ColdOpen"),
		}
	end
	if not boat or not table.find(ctx.boats, boat) then
		return {
			canLaunch = false,
			buttonText = "Launch now",
			note = "No boat to launch yet. Rank up or buy one at this desk.",
		}
	end
	if ctx.busy ~= nil then
		return { canLaunch = false, buttonText = "Launching...", note = nil }
	end
	return {
		canLaunch = true,
		buttonText = "Launch now",
		note = if ctx.failure then QuickLaunchCard.reasonText(ctx.failure) else nil,
	}
end

-- The shelf prompt shows for owners even before the priced shelves open (rule 6 is about prices; an
-- owner's use button is not a price), whenever the pass is listed at all.
function QuickLaunchCard.promptVisible(
	listed: boolean,
	owned: boolean,
	pricedVisible: boolean
): boolean
	return pricedVisible or (listed and owned)
end

return QuickLaunchCard
