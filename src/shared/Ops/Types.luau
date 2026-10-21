--!strict
-- Ops/Types: the data shapes of an operation (docs/09-rescue-operations.md sections 2 and 13).
-- Pure types plus a few frozen lists; no services, Lune-testable.

export type Grade = "Gold" | "Silver" | "Bronze" | "Fail"
export type Role = "Helm" | "Navigator" | "Crew" | "Medic"

-- One grading criterion. The step grade is the worst grade over all its bands.
-- Lower is better unless higherIsBetter (times, counts of mistakes vs. scores, fractions right).
-- Booleans count as 1 (true) and 0 (false).
export type GradeBand = {
	metric: string,
	gold: number,
	silver: number,
	bronze: number,
	higherIsBetter: boolean?,
}

-- What the server does when a step times out or the client reports failed = true:
--   "retry"    restart the step (up to MaxAttempts, then "npc")
--   "npc"      an NPC crewmate finishes it (Silver at most, no credit to the player)
--   "skip"     the step scores Fail (0 points) and the operation moves on
--   "takeover" the Coastguard takes over the operation (docs 09 section 2.5)
--   "continue" the step completes Bronze (never worse; passage and transport always get there)
export type OnFail = "retry" | "npc" | "skip" | "takeover" | "continue"

export type StepDef = {
	id: string, -- unique inside the operation
	label: string, -- plain label shown on the step card ("Check them over")
	realTerm: string, -- the real term underneath ("Primary survey")
	role: Role,
	mechanicId: string, -- src/client/Mechanics/<mechanicId>.luau (default stub when missing)
	-- casualty state -> mechanicId override (e.g. recovery: Panicking uses recover_swimmer)
	mechanicByState: { [string]: string }?,
	gradeBands: { GradeBand },
	weight: number, -- grade points weight (docs 09 section 2.4: most 1, recovery and condition 2)
	timeoutSec: number, -- hard cap (docs 09 section 10: no step over ~45 s of the same input)
	onFail: OnFail,
	npcAllowed: boolean?, -- false: always a human's step (search, recovery choice; docs 09 4.2)
	npcSeconds: number?, -- base duration for an NPC doing it (x Rules.NpcSlowdown)
	minSeconds: number?, -- results arriving faster than this are rejected (sanity)
	serverMetrics: { string }?, -- metrics the server fills itself and the client cannot override
	allowedEvents: { [string]: number }?, -- condition events a client may report, with a max count
	when: string?, -- include only if the casualty starts in this state (e.g. "Panicking")
	perCasualty: boolean?, -- consecutive perCasualty steps loop once per casualty the track claims
	shared: boolean?, -- big calls: done once for the whole operation, not once per track
	effect: string?, -- server side effect on success (see OperationService: "board", "tow", ...)
	tip: string?, -- Chief Aggie's debrief tip when this is the weakest step
	noTow: boolean?, -- berth with nothing in tow: no lashed pair, no tow-line release (RP-C1b)
}

export type OperationDef = {
	id: string, -- "PersonInWater" | "DisabledVessel" | "CapsizedFerry"
	displayName: string,
	radioLine: string,
	weight: number, -- payout weight (docs 02 section 3)
	capSeconds: number, -- takeover when the operation runs past this (docs 09 section 2.5)
	isBig: boolean,
	casualtyKind: "Person" | "Vessel",
	steps: { StepDef },
	-- casualty state -> chance; the server rolls one per casualty
	states: { [string]: number },
	lifejacketChance: number,
	takeoverAsset: string, -- radio name of who takes over
	-- greybox scene to spawn in RescueService (legacy call kinds)
	sceneKinds: { string },
}

export type CasualtyState = {
	id: string,
	state: string, -- "Alert" | "Panicking" | "Exhausted" | "VeryCold" | "Unresponsive" | "Vessel"
	condition: number, -- 0..100
	lifejacket: boolean,
	inWater: boolean,
	panicking: boolean,
	wet: boolean,
	sheltered: boolean,
	surveyed: boolean,
	treated: boolean,
	towed: boolean, -- vessels: the tow is established, the drift clock stops
	delivered: boolean,
	aboard: boolean?, -- picked up by a crew's boat (the board effect): safe, no takeover
	takenOver: boolean,
	wrongHandled: boolean, -- the one-off wrong-handling cost was applied
	tag: string?, -- triage: "Red" | "Yellow" | "Green"
	claimedBy: string?, -- big calls: the track that picked this casualty
	driftScale: number?, -- x every decline rate (the cold open is generous: 0.5)
}

export type Metrics = { [string]: number | boolean }

-- What a client mechanic submits for a step.
export type StepResult = {
	metrics: Metrics,
	events: { [string]: number }?, -- condition events ("wash", "slam", "wrongHandling", "bump")
	grade: Grade?, -- the client's own view; the server never takes it as is
	stub: boolean?, -- the default stub mechanic produced this (Silver cap)
	failed: boolean?, -- the player failed or gave up (onFail applies)
}

local Types = {}

Types.GRADES = table.freeze({ "Gold", "Silver", "Bronze", "Fail" } :: { Grade })
Types.ROLES = table.freeze({ "Helm", "Navigator", "Crew", "Medic" } :: { Role })
Types.PERSON_STATES =
	table.freeze({ "Alert", "Panicking", "Exhausted", "VeryCold", "Unresponsive" })

-- Shared rules (tune).
Types.Rules = table.freeze({
	NpcSlowdown = 1.4, -- NPC steps take about 40% longer (docs 09 section 4.2)
	NpcGradeCap = "Silver" :: Grade,
	StubGradeCap = "Silver" :: Grade,
	MaxAttempts = 3,
	DefaultMinSeconds = 0.5,
	MaxMetrics = 24,
	MetricMax = 100000,
})

return Types
