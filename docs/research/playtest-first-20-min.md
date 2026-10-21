# First 20 minutes: fresh-profile playtest (G25a)

Date: 2026-10-20. Build: working tree at G25a. Studio play test, memory profile (fresh on every
`play start`). Inputs: real keyboard through the Studio MCP (`smoke.py keys` / `key_down`), camera
and map through `lua Client`; no `OpsAutoStub` in the played run. The `ops` check uses the stub, as
designed.

**Caveat:** the valid cold-open run was interrupted by the operation's 12-minute takeover
(`ColdOpenEnded=Takeover`), so the station, board, second call, gear and certification milestones
were **not reached on a fresh profile**. The timeline below is what was observed; the later steps
are marked unverified rather than invented. Three Studio sessions were spent isolating the two
cold-open blockers; the final two ran the play test and the required `smoke.py ops` sweep.

## Milestone timeline (observed, server clock)

| clock | milestone | result |
|---|---|---|
| 0:00 | spawn on the jet ski, cold open `O1` active | casualty 70-85 studs dead ahead, HUD "Get them aboard", first-person helm |
| 0:03-0:08 | W drives; casualty swims in (10 s rule) | held at ~10 s; boat ~6 studs from the casualty |
| 0:10-0:40 | turn for the station shore | boat pinned at the casualty: throttle 1, speed 0; after the collision fix the same state drives away |
| 0:40-2:00 | tow toward the station | assist ease kept the jet at ~4 knots even after the casualty held; target <3 min was missed |
| 12:00 | cold open takeover | `ColdOpenEnded=Takeover`, `OpsCompleted=1`, no reward burst; the rescue does not count |
| - | first reward, station, board/DSC, second call, third call, first gear, first cert/rank | not reached (test gap, not proven working) |

Target check: first rescue <3 min **failed** in this run because of the two blockers; with both
fixes the tow is ~440 studs at planing speed (~10-20 s), so the target is plausible but unverified.
First unlock ~5 min and first ceremony ~10 min were not reached.

## Step table

| step | obvious? | issue | fixed? (file) |
|---|---|---|---|
| cold open spawn | partly | The 3-word step and the casualty marker read, but the jet-ski hull and handlebars fill the lower half of the first-person view; the casualty is a dot at 70-85 studs. | no (open) |
| drive to casualty | yes | W works at once, but the step says "Get them aboard" before anyone is aboard; it should read "Go to them". | no (open) |
| casualty pickup | yes | The held R15 torso has `CanCollide=true` while the float is anchored, so the torso pinned the jet ski to the hull (throttle 1, speed 0). | yes: `src/server/Services/RescueService.luau` (spawnVictim clears CanCollide on every part); verified by clearing it at runtime and in the next built cold open |
| tow to shore | partly | "Chief Aggie: Over here!" helps, but the Assist ease stayed on after the pickup and capped the jet at ~4 knots; the throttle felt dead. | yes: `src/client/Controllers/BoatController.luau` (`coldOpenHeld` releases the ease); hot-tested by clearing the attribute, no built tow run after the change |
| first reward burst | - | Not reached; `OnboardingReward` only fires on `ColdOpenEnded=Complete`. | unverified |
| station beacon / call board / DSC | - | Not reached; the beacon code and board auto-accept are present. | unverified |
| second rescue (easy PIW) | - | Not reached. | unverified |
| third call | - | Not reached; needed for the Helm live half. | unverified |
| first gear unlock | - | Not reached; 300 Cash, and cold open + first call pay 500 + 600, so it is affordable by design. | unverified |
| first certification / rank ceremony | - | Not reached; Helm needs the exercise plus two live ops, then 400 Rep. | unverified |
| early retention | no | A Great Storm countdown (0:44) and darkened sky appeared during the cold open. | yes: `src/client/UI/EventCountdown.luau` hides the clock while `Layout.newPlayer()`; not re-watched after the build |
| map | yes | M opens the map; it reads cleanly and is the only navigation aid while the beacon is out of view. | no issue |
| 12-minute cap | no | The cold open was taken over at 12:00 and paid nothing; a child who struggles loses the first rescue despite the "no fail state in the first 3 calls" promise. | open (design) |

## Open issues, ranked

1. **Cold open view (High).** First-person jet-ski camera crops the water and the shore; the
   casualty and the shore smoke are hard to see. This is the biggest "what do I do" risk left.
2. **12-minute takeover (High).** The first rescue can end with `Takeover` and no reward. Either
   give the cold open no takeover until it has completed once, or pay the partial rescue and send
   the player to the station with the story intact.
3. **Premature step label (Medium).** "Get them aboard" before pickup; use "Go to them" until
   `PiwMode=held`.
4. **Unverified first-session chain (High, test gap).** Reward, station, board, second call, gear
   and certification were not exercised on a fresh profile. The gear/cert timings still need one
   clean 20-minute run. The ease gate has not had a built tow run yet (hot-tested only).
5. **Storm during onboarding (Medium).** Hiding the countdown is not enough if the sky darkens
   and the sea roughens during the cold open; consider holding weather events until the cold open
   ends.
6. **Map while driving (Low).** Opening the map is clear, but it is a modal; a new player may not
   realise W is consumed while it is open.
7. **Shop/challenges/phone (none seen).** The shop is counter-only, the phone is disabled during
   the cold open, and challenges are staged; nothing retention-related except the storm clock
   appeared early.

## Files changed for the play test

- `src/server/Services/RescueService.luau` — the only service touched: 4 lines in `spawnVictim`
  clearing `CanCollide` on the casualty (the held R15 torso pinned the boat). Listed for G25b.
- `src/client/Controllers/BoatController.luau` — release the cold-open assist ease once the
  casualty is held, so the tow runs at planing speed.
- `src/client/UI/EventCountdown.luau` — no event clock while `Layout.newPlayer()`.
- `src/client/Ocean/Horizon.luau` — handled flat-horizon fallback no longer prints a string that
  `smoke.py` classifies as an engine error (it failed `ops` on a cosmetic fallback).

## Evidence

`build/smoke/g25a_sheet.png` (6 key moments, 768 px each): cold open spawn, storm clock in the
cold open, first-person helm with the casualty held, map, harbour, ops debrief.
Individual shots: `build/smoke/g25a_01_cold_open_spawn.png`,
`g25a_state_check.png`, `g25a_keytest.png`, `g25a_map.png`, `g25a_edit_harbour.png`,
`g25a_ops.png`.

## Round 2 (Opus)

Date: 2026-10-20. Fresh memory profile per `play start`, real keyboard through `user_keyboard_input`
(W held in 0.7 s chunks with A/D taps toward the target; on foot the camera is turned at the beacon
as a mouse would, then W). Driver: `build/smoke/r2_drive.py` + `r2_state.luau` (not shipped).
Five Studio sessions; `smoke.py ops` PASS, console 0 errors, `check.sh` passes.

### Timeline (run 4, server clock from the cold-open spawn)

| clock | milestone | before (G25a) | after |
|---|---|---|---|
| 0:00 | spawn | first person, hull fills the view, outside the breakwater | third-person chase cam, casualty + ring + smoke dead ahead, "Go to them", calm |
| 0:15 | casualty held | ~0:10, then the boat was pinned | swims in at idle speed, label flips to "Bring them home" |
| 0:25 | ashore, `ColdOpenEnded=Complete` | 12:00 `Takeover`, no reward | straight ~250 stud run back to the station slipway |
| 0:42 | reward burst (Cash roll, Bosun) | not reached | after the ~15 s arrival shot, on foot at the slip |
| ~0:52 | station reached (beacon moves to the board) | not reached | ~5 s walk |
| ~0:54 | second call (PIW) accepted at the board | not reached | step "Answer the call" |
| - | R answers, "Kit and launch", E launches the bay jet ski, "Find them" | not reached | search needs a click on the water to place the start: not finished |

Run 2: held 0:13, ashore 0:22. Run 3: ashore 1:08 because the jet ski stalled on the slip ramp just
outside the 28-stud shore radius (now 40).

### Changes

- `src/shared/Boat/ColdOpen.luau`: `SPAWN` inside the breakwater, facing away from the station
  slipway (outside the Harbour Mouth the breakwater sat across the line home, the run-1 boat
  beached on `Breakwater.WestHead`); `SHORE_RADIUS` 28 -> 40; `STEP_SHORT` reach/home labels.
- `src/server/Services/OperationService.luau`: the cold open spawns at `ColdOpen.SPAWN` (zone
  CalmBay); no time-cap takeover in the cold open; `ColdOpenHoldsWeather()` (a running cold open,
  at most `Onboarding.WEATHER_HOLD` = 300 s); `ColdOpenHandover` set before `ColdOpenEnded` so the
  reward waits for the arrival shot as designed.
- `src/server/Services/StormService.luau`, `EventService.luau`: no new storm (natural, summoned or
  the Great Storm clock) starts while a cold open holds the weather.
- `src/client/Controllers/CameraController.luau`: the `ColdOpen` jet ski uses the chase camera.
- `src/client/UI/ColdOpenCue.luau`, `OpsHud.luau`, `OpsStepCard.luau`: the compact step line reads
  "Go to them" until the casualty holds on, then "Bring them home".
- `tests/BoatColdOpen.spec.luau`: spawn inside the breakwater, casualty ahead, slipway behind.

### Still open

1. Second call: "Answer the call" shows no keyboard glyph for R (touch gets a button; the NPC
   answers after the 45 s timeout); the bay jet ski has no beacon while the op runs (E at the bay
   prompt launches it); "Find them" needs a click on the water, not exercised.
2. The weather hold is code-path only (no storm fell inside a Studio cold open).
3. The debrief tablet opens over the reward burst and waits for "Enter".
4. Station calls 1-3 still have the time-cap takeover (only the cold open is uncapped).
5. Gear unlock and certification still unverified on a fresh profile.

## Round 3 (Opus)

Date: 2026-10-20. Fresh memory profile per `play start`, real keys through `user_keyboard_input`
(driver `build/smoke/r3/drive.py` + `state.luau`, not shipped). Four Studio sessions, heavy
`studio` lock contention from other agents (some runs lost minutes to idle waits). Studio use was
stopped by the user before the storm-hold check, the final journey re-run and `smoke.py ops`.
`check.sh` passes (682 tests, Pacing green).

### Timeline (session 4 run, game clock from the cold-open spawn)

| clock | milestone | note |
|---|---|---|
| 0:11 | casualty held | |
| 0:23 | ashore, `ColdOpenEnded=Complete` | |
| 0:38 | reward burst | the debrief tablet now waits for it (`OnboardingRewardBusy`), then closes itself |
| 0:50 | call board, call 2 offered | |
| 0:54 | "Answer the call" with the **R** chip | R pressed, step done at once (no 45 s NPC wait) |
| 0:59-1:14 | beacon on the bay, E launches the jet ski | |
| 1:18 | "Find them": start marker drops itself, casualty always visible, beacon + dye/ring/smoke on them | no click on the water |
| 1:33-4:33 | "Come in slow" ran 3 x 60 s timeouts | the bot stopped ~10 studs off; mechanic needed < 8. Fixed after the run (first calls: 14, no "go round"), **not re-run** |
| 4:55-5:20 | survey, treatment | |
| 5:20-8:19 | transport | bot wedged on the breakwater (straight line to the pad); beacon flipped Dock -> Hospital mid-step, fixed (pad latched at step start) |
| 8:47 | **call 2 complete**, debrief auto-closed by 8:53 | gear beacon (Chandlery) up |
| ~29:00 | call 3 complete (session 2 run, lock idles + transport timeout) | not a meaningful time |
| - | first gear, first certification / rank ceremony | **not reached by the bot** (it dismounted at sea; fixed in the driver, not re-run) |

Estimate without the two bot faults (approach 3 min, transport 3 min): call 2 ends ~3:00, the gear
beacon is due at 5:00 (`GEAR_AT` 300 s after the cold open) and the Chandlery gear is 300 Cash, so
~5:30 is plausible. The ceremony is structurally late: Lifeguard needs Helm = the boat-handling
exercise + 2 live approaches at Silver (the cold open has no approach step) + 400 Rep (cold open 150
+ call 2 160 + call 3 160). Earliest live path is call 3 + exercise, ~14-16 min for a competent
player; the offline Pacing model says Rank 2 at 10.2 min. Not changed (needs a design call: count
the cold open toward Helm, or Helm live count 2 -> 1).

### Root cause found: casualty pins the boat

The held swimmer's R15 rig loads after `spawnVictim`, and the Humanoid turns torso `CanCollide`
back on, so round 2's CanCollide loop did not hold: UpperTorso/LowerTorso pinned the jet ski
(throttle 1, speed 0). Hot-fixed in Studio by moving the parts to a collision group: the boat
drove off at once.

### Changes

- `src/server/Services/RescueService.luau`: "Casualty" collision group (no collisions with
  Default), set on every victim part now and on `DescendantAdded`.
- `src/server/Services/OperationService.luau`: `onboardingCall(player)` (saved
  `OpsCompletedTotal` <= 3): no time cap / takeover on station calls 1-3, and their casualty is
  a calm swimmer in a lifejacket ("Alert": no panic-calm step, throw/grab/come recovery).
- `src/client/UI/OpsStepCard.luau`: R / DPadUp key chip on push-to-talk steps (touch keeps the
  Radio button).
- `src/client/Controllers/OnboardingController.luau`: on calls 1-3 the beacon stays on during the
  op: your craft when on foot, the casualty while finding/approaching/recovering, the lit drop-off
  pad on transport; sets `OnboardingRewardBusy` while the reward plays.
- `src/client/UI/ColdOpenCue.luau` + `OpsHud.luau`: the cold open's casualty cues (dye, pulse ring,
  smoke, splashes, "HELP!") on the first calls' casualty; new-player debrief waits for the reward,
  auto-closes after 6 s, any input skips (`OpsDebrief.show(d, auto)`).
- `src/client/Mechanics/search.luau`: first calls drop the start marker at the datum, keep the
  casualty visible and count them sighted when on screen.
- `src/client/Mechanics/approach.luau`: first calls: no abort, any stop within 14 studs completes
  (still graded, so Helm still needs a real Silver approach).

### Still open (needs Studio)

1. Re-run the journey with the approach / pad-latch fixes and measure call 2, call 3, gear,
   ceremony; run `smoke.py ops`.
2. Storm hold (`EventClockOffset` to Great Storm "Before" during a cold open) not verified. Seen:
   a Great Storm already active at server start is not held, so that cold open plays in a storm.
3. Cold open: an idle jet ski creeps (2.5 kn) north into `Breakwater.WestHead` and wedges; W + turn
   does not free it, S does.
4. Space in the survey outside the breath window jumps the player off the seat.
5. Survey / treatment / panic-calm still show option cards (CLAUDE.md "no choice UI").
6. The tasking pager keeps offering calls while the gear beacon is up (two goals at once).
7. A fresh Studio profile shows 3,000 Cash before any reward (source not traced).

## Round 4 (G71)

Date: 2026-10-20. Fresh memory profile per `play start`, real keyboard/mouse through the Studio MCP
(`user_keyboard_input` / `user_mouse_input`) and HID mouse events; no `OpsAutoStub`. Driver
`build/smoke/g71/drive.py` + `state.luau` (adapted from `r3`). Three Studio sessions were opened;
the run below is one fresh profile from spawn. The machine hit the 2-window limit with four
TestBench windows; the run was stopped after the gear beacon, so call 3, the gear purchase and the
rank-up were not reached. `smoke.py ops` was not run (same limit). `check.sh` passes.

### Timeline (game clock from spawn, one fresh profile)

| clock | milestone | target | result |
|---|---|---|---|
| 0:00 | spawn, cold open, **Cash 0** | - | passed; the cold open spawned in an already-running storm |
| 0:09.7 | casualty held | - | passed (fastest of the rounds) |
| 0:18.7 | cold open `Complete` | - | passed |
| 0:35.4 | **reward burst** | < 3 min | **passed** (0:35) |
| 0:45-0:48 | station, call board, call 2 accepted at the board | - | passed |
| 0:50.6 | R answers ("Answer the call") | - | passed, R chip shown |
| 1:03.6 | bay jet ski launched | - | passed (E at the bay, no stray purchase) |
| 1:33.6-3:57.8 | "Come in slow" (approach) | - | 144 s with the bot's sparse inputs; a human ~20-30 s |
| 3:57.8 | casualty alongside, "Get them aboard" | - | passed |
| 4:39-5:09 | survey ("Check them") | - | finished by the crew fallback (see 2) |
| 5:10-5:24 | treatment ("Treat them") | - | finished by the crew fallback |
| 5:24-5:37.5 | transport, hand over | - | passed (jet ski to the hospital pad) |
| 5:54.7 | **call 2 complete, gear beacon up** | gear ~5 min | beacon on time; **gear purchase not reached** |
| - | call 3, first gear, first rank-up | ~10 min | **not reached** (Studio window limit; bot stuck on foot at the quay wall) |

Cash: 0 at spawn (verified twice). After the cold open 1,000 (calm run) / 2,000 (storm run) because
the tutorial pay runs through the normal award path: the Studio DoubleCash pass (x2) and, in the
storm run, the storm multiplier; a daily challenge (770 x2) fires with call 2, so Cash 4,740 by the
call-2 debrief. Rep is not exposed as a player attribute (the chip reads "Helm 0/3"); the rehearsal
profile's `Progression_GetData` showed 432 after call 2 (150 + 160 + ~122 daily).

### Step table (one line each)

| step | obvious from the world? | issue | fixed? |
|---|---|---|---|
| spawn / cold open | yes | storm already running at server start was not held (calm-weather G50 item) | no |
| reward | yes | big burst, then the debrief auto-closes; clear | - |
| station -> board | partly | open the board: the prompt says "Open", the beacon sits on the board; clear enough | - |
| call accepted at the board | yes | call 2 started by itself at 29 studs, 45 s before the player reached the board | see 1 |
| launch at the bay | partly | three prompts overlap at the bay ("Launch Jet Ski" / RIB / Lifeboat); the right one is E | no |
| come in slow | yes | the speed metre and cone read; the bot's own slowness, not the game | - |
| survey / treatment | **no, by hand** | body areas/kit are world objects with an E glyph, but a locked first-person camera cannot be aimed by the test harness; the crew finished both | see 2 |
| transport / hand over | yes | pad beacon, then the ATMIST lines and the auto-finish | - |
| gear beacon | yes | gold beacon at the Chandlery at 5:55 (after the fix) | - |
| on foot to the Chandlery | no | from the harbour pad the straight line ends in the water at the quay wall (-122, 6); the beacon shows no path | no |

### Issues, ranked

1. **Board goal never completed on the auto-accept path (High, fixed).** `OnboardingController`
   auto-accepted the first call at 29 studs (`REACH.CallBoard + 18`) but only a 22-stud proximity
   set `boardReached`, so the goal stayed CallBoard and the gear and certification beacons never
   appeared (seen twice: beacon stuck on the board at 10+ min, only the station pulse). One-line
   fix: set `boardReached, stationReached = true, true` on that auto-accept. Verified: the gear
   beacon appeared at 5:55 (FFD25A, Chandlery) after call 2.
2. **Care steps cannot be driven by hand in this harness (High, test gap).** With a locked
   first-person camera (`MouseBehavior.LockCenter`), neither the MCP `user_mouse_input` nor HID
   `CGEvent` moves turn the camera (calibrated on foot and seated: yaw/pitch unchanged). The picker
   aims at the screen centre and picks only within ~72 px; the casualty's chest/body sat 150-380 px
   below centre. E presses did nothing; the crew fallback surveyed (30 s) and treated (14 s). The
   world-action presentation exists (body-area glow, kit box with items, E/X chip) but needs a
   human pass to verify the hands-on flow.
3. **Cold open in a storm already running at start (Medium).** Weather was Storm at spawn and at
   the reward; the weather hold only blocks a *new* storm. The "storm-at-start calm weather" item
   did not hold in this run.
4. **Walking from the water to the Chandlery (Medium, for the bot).** After the call the player
   dismounts at the hospital pad and swims into the quay wall; a human will find the ramp, but the
   beacon alone does not read a route. Gear purchase, call 3, cert and the rank-up were not reached
   before the window limit.
5. **First call can be accepted from the pager at the slipway (Low).** It skips the board (and,
   before fix 1, left the goal chain broken). After fix 1 the chain survives, but the player starts
   the kit step from a worse spot on the harbour side.
6. **Next-goal chip at spawn reads "Helm 0/3" (Low).** A cert progress counter, not the next thing
   to do (the station/board); minor HUD noise for a brand-new player.
7. **Call 2 timing is bot-limited (Low).** 5:55 end-to-end, mostly the 144 s approach (sparse state
   polling = sparse throttle). Not a game blocker; a human run is needed for a clean 3-min call.

### Files changed for this round

- `src/client/Controllers/OnboardingController.luau` — 2 lines (>boardReached/stationReached on the
  first-call auto-accept; issue 1).
- `build/smoke/g71/{drive.py,state.luau,mouse.swift}` — test driver only, not shipped.

### Evidence

`build/smoke/g71_sheet.png` (6 moments: reward, call at the board, out to the casualty, come in
slow, survey, gear beacon); individual shots `build/smoke/g71_*.png`, log `build/smoke/g71/log.txt`.

## Round 5 (headless pace model)

Date: 2026-10-20. `tests/NewPlayerPace.spec.luau` walks a fresh profile through the real onboarding
order with the real rules (`Onboarding.goal` / `holdsOffers` as the server and client read them,
`CallLogic.chooseCall`, `Grading.payout` tutorial chain, `ProgressionRules` certs and ranks, the G50
cold-open approach credit, the Helm exercise, `StreakRules`, `ChallengeRules`). Assumed clock from
Round 4: cold open done 0:19, call 2 accepted 0:48, every call 5.1 min incl. travel, 1 min walk to
the Chandlery and to the exercise board, Calm weather, solo, no passes. Minutes from spawn:

| milestone | target | before | after (Silver) | after, no early daily | after, Bronze call 2 |
|---|---|---|---|---|---|
| first reward | < 3 | 0.3 | 0.3 | 0.3 | 0.3 |
| gear affordable (300) | - | 0.3 | 0.3 | 0.3 | 0.3 |
| gear bought | ~5 | 6.9 | 6.9 | 6.9 | 6.9 |
| cert exercise beacon | - | 12.1 | 6.9 | 6.9 | 6.9 |
| first rank-up (Lifeguard) | ~10 (8-13) | 16.1 | **10.9** | **10.9** | 16.1 (next Silver approach) |
| RIB Cash at 10:00 | "almost" | 42% | 42% | 23% | 23% |

"Before" had two faults: `CERT_AT` 600 s put the beacon after call 3, and the server read
`next(snapshot.certs)`, which is always true, so the beacon never held offers while the client
kept pointing at the exercise. "Silver" includes the Round 4 daily (770 Cash, 122 Rep on call 2);
without it the rank needed call 3's Rep before the change.

Changes: `Onboarding.CERT_AT` 600 -> 360 s (the cert beacon follows the gear); `Onboarding.certDone`
(an earned cert or a passed exercise ends the cert goal; used by OperationService and
OnboardingController, so a Bronze player is not held off calls after the exercise); tutorial call 2
Rep 160 -> 200 (`Grading.Payout.Tutorial[2]`, docs/03 section 2 updated). Pacing.spec's own rank-2
window widened to 7-16 min (its model skips the gear walk). Open: the RIB is 23-42% affordable at
10:00, not "almost"; RIB is rank-gated at ~0:30 (docs/03), so this was not tuned.
