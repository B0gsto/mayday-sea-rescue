# 20 · Clarity redesign: one goal, one pointer, your call, your craft

2026-10-24. Owner after playing the test place: "not shippable ... after that you cannot understand nothing".
Input: a cold real-client playtest (fresh profile, no briefing, 20 min, 81 screenshots), log in
`build/ux/log.md`, screenshots `build/rbx/ux01s.png`–`ux81s.png`. This chapter wins over docs/16 where they
disagree on HUD, markers, call ownership, spawning and camera. Rules kept: no tutorial text, no choice menus
in gameplay, simple rescue (get near → they climb on → home).

## (a) What happened, as moments

| # | Shot | Player saw | Player thought | What was true |
|---|---|---|---|---|
| M1 | ux09 | Spawned in town at the Chandlery, no pin, no goal, for ~45 s | "Has the game started? What do I do?" | Cold open was waiting (`ColdOpenFlow.decide` → "Wait" until the profile answers); the town spawn is visible meanwhile |
| M2 | ux11 | Hard cut to sea on a jet ski, survivor already riding behind me | "Whose ski? Did I fall in?" | Cold open started; the board happened at spawn, unseen |
| M3 | ux12–ux23 | With the survivor aboard, the only pin was a red flame "30 m" that stayed 30 m, then sat at the edge; reached a flare ring, nothing happened for 25 s | "Is that where I take him? Is it a new emergency?" | No Home/drop-off pin ever showed. The pin pointed at the survivor's old spot / a flare scene, not home |
| M4 | ux19, ux26, ux31 | Survivor bobbing in the water beside me, then back on the seat; a second, red-outlined swimmer clinging to the ski; radio "Over here" with no pin | "Did he fall off? Who's that? Where is 'here'?" | Red outline = "no room" (jet ski holds 1). Nothing says that in the world |
| M5 | ux37–ux38 | Pressed E, got cut to the station slipway on foot, cash +1,000 | "Did I win or get reset?" | The cold open ended (off-craft grace) with the "Station" handover; no "rescued" beat |
| M6 | ux40 | After accepting: left card "Go 100 m", bottom card "Go · boat 23 m", flame pin "100 m", orange pin "20 m", dotted minimap line | "Which Go? Where is my boat?" | Strip (`OpsStepCard`) shows the call; the launch mechanic panel (`PIW/Ui`) shows the boat. Two "Go"s |
| M7 | ux43–ux45 | Bottom card covered my character and the boat; then I was suddenly riding at 44 km/h | "What happened?" | Walking onto the ski seats you; the panel hides exactly where you look |
| M8 | ux48–ux51, ux58 | At the call, pin and distance vanish, card says "0/1", camera jammed into my head, no survivor seen; 10 s later "Home" | "Where is the person? Did I do anything?" | `Waypoint.NEAR` (25 m) hides the pin and distance; the pick-up happened off-camera |
| M9 | ux65–ux67 | At the Home pin it vanished, survivor still on deck, nothing for 15 s; 20 m on, the debrief | "Where exactly is home?" | Same 25 m hide; the drop-off zone is smaller than where the pin disappears |
| M10 | ux15–ux18, ux26–ux35, ux60–ux63 | Spun past every heading, hit quays, sea wall, a trawler; speed stuck at 0–5 km/h against walls; camera side-on or inside my head | "I can't drive this" | Keyboard steer is full lock at once (jet ski 95°/s); camera arm snaps in on any hit |
| M11 | ux73–ux79 | Spawned a RIB from the phone: put on the road, "[E] Launch" floating over a railing that did nothing, then standing on the deck; W walked me off the bow; swimming with a "Launch" prompt in open water and no boat in sight | "How do I get on my boat?" | The bay's Launch prompt (re-launch last craft) shows while your craft is already out; spawn seat failed |
| M12 | ux68–ux69, ux80 | Ignored the offer card and drove at the pin: the call became mine anyway. No timer anywhere | "Does accepting matter? Am I about to fail?" | K2 auto-accept; the NPC racer leaves 12 s after accept with no warning |
| M13 | ux46 | The cold-open survivor still riding my jet ski on the next call | "Is he still mine?" | Survivor seat not cleared on the cold-open hand-over |

Owner also reported "Too slow" / an NPC boat taking the call with no reason shown; it did not trigger for me
(I was on failsafe calls 1–3), but M12 explains it: the racer (`NpcPickup.RACE_DELAY` 12 s, 42 studs/s,
from the station) beats anyone who spends 30–60 s finding their boat, which every new player does (M6, M11).

Positives: phone and Vehicles app read clearly; "[E] Board" on a beached ski; green Home card; debrief stars.

## (b) Root causes

1. **No single source of "the goal".** Strip, mechanic panel, tasking card, world pin, minimap line and
   offers each compute their own target. Offers keep showing while you carry someone, so the pin can point
   at a new call instead of home (M3, M6, M12).
2. **The pointer disappears exactly when it matters.** `Waypoint.NEAR` hides pin + distance inside 25 m for
   survivors *and* the drop-off, and nothing replaces it (M8, M9).
3. **Key moments happen off-screen.** Board, climb-off, cold-open end and spawn are teleports or seat welds
   with no beat: no "+1", no climb shown, no "safe" moment (M2, M5, M8, M9).
4. **"Full" is invisible.** Capacity is only an outline colour on a swimmer that is clinging to you (M4).
5. **Calls race you before you've started.** The racer clock starts on accept, not when you're under way,
   and the race happens behind you; failure shows a chip, not the boat that won (M12, owner).
6. **Craft state is ambiguous.** Seated / standing on deck / swimming look alike from the chase cam; the bay
   prompt advertises "Launch" while your craft is out; phone spawn can fail the seat (M7, M11, M13).
7. **Driving fights the player.** Instant full-lock steering, camera arm that snaps into the head on any
   wall contact, and no easy way off a wall (M10). Every wasted minute feeds cause 5.

## (c) Hard rules (whole game, after the tutorial too)

1. **Exactly one goal, one pointer.** At any moment the HUD shows one goal icon + one distance, and the
   world shows one pin, all from the same function. Order: get on your craft → survivor → home. Offers never
   take the pin while you carry someone or have an active call.
2. **The pointer never vanishes before the goal is done.** Inside 25 m it becomes a bouncing arrow over the
   target (survivor or pad), with the distance still on the strip.
3. **A call is yours until you finish it or drive away from it.** No hidden clock before you're aboard
   and moving. If a racer is coming, you see it leave and see it on the minimap.
4. **Every outcome has a visible beat.** Boarded: the survivor climbs on in view + "1/1". Delivered: climbs
   off on the pad + coin burst. Failed: the NPC boat is shown taking them + the boat glyph + "Too slow".
5. **Full shows on your craft, not on them.** Seat pips on the craft's marker / speedo (●○○), red when full;
   the next swimmer waves and waits instead of clinging.
6. **You can always get back on in one obvious action.** Off your craft, it carries a craft-icon pin and
   `[E] Board` reaches you from 30 studs (or the craft comes to you). The bay "Launch" prompt is only shown
   when you have no craft out.
7. **Spawning a craft seats you on it, in water, facing open sea.** Never on a road, never standing.
8. **Driving forgives.** Steering eases in, bumping a wall never zeroes you for more than 2 s, the camera
   never enters the character.
9. **Pins don't change meaning.** Flame = someone in trouble (red), house = home (green), craft = your boat
   (orange). One icon, one meaning, everywhere (pin, strip, minimap).

## (d) Changes, by impact

1. One goal resolver: `MapController.GetObjective` becomes the only source; strip, pin and minimap read it;
   offers drop out while carrying/active; cold open uses the same path (fixes M3, M6, M12).
2. Pin never hides: NEAR state = arrow over target, distance stays (M8, M9).
3. Racer starts only once you're aboard and under way, leaves visibly, and a failure plays the NPC pickup
   on camera for 2 s (M12, owner).
4. Visible board/deliver beats + "+1" pop; survivor seat cleared on every hand-over (M5, M8, M9, M13).
5. Spawn seats you in water; bay prompt hidden while your craft is out; own-craft pin + long Board range
   (M11).
6. Steering ease-in + wall unstick + camera min distance (M10).
7. Cold open: cover the wait (start at sea or behind a 2 s fade), "safe" beat + Home pin on the pad (M1, M2).
8. Full shows as seat pips on your craft; full craft makes swimmers wait, not cling (M4).
9. Remove the duplicate mechanic panel ("Go · boat") — the strip shows the craft icon + distance when the
   step is "get on your craft" (M6, M7).

### Work packages (disjoint files; Opus builders, ponytail; real-client check after each)

**WP-A · One goal, one pointer** — changes 1, 2, 9.
Files: `client/Controllers/MapController.luau`, `client/UI/Waypoint.luau`, `client/UI/OpsStepCard.luau`,
`client/UI/OpsHud.luau`, `client/Mechanics/launch.luau`, `client/Mechanics/PIW/Ui.luau`.
- Objective order in MapController: no craft → own craft (orange craft icon); call active, nobody aboard →
  nearest survivor; anyone aboard → nearest drop-off (also during the cold open); no call → offer.
- Waypoint: inside NEAR draw a bouncing down-arrow over the target instead of hiding; distance stays.
- Strip = icon + one word + distance, always; `launch` stops drawing its own panel.
Acceptance (real client): after accepting, exactly one card and one pin; walk to the boat and the pin is
the craft icon; with a survivor aboard the only pin is the green house, from the pick-up until delivery;
at 10 m from survivor or pad the arrow is still visible over it.

**WP-B · Your call, fair failure** — changes 3, 8 (server side).
Files: `server/Services/OperationService.luau`, `server/Ops/NpcPickup.luau`, `shared/Ops/Definitions/SimpleSteps.luau`,
`shared/Calls/OfferPacing.luau`, `client/UI/OpsTaskingCard.luau`, `client/UI/OpsDebrief.luau`.
- Racer clock starts when you're seated and >15 km/h; racer launches from a point the player can see
  ahead (toward the scene from the harbour mouth), siren on, red boat blip on the minimap.
- No offers while a call is active or anyone is aboard; an offer card shows the call icon + distance.
- On takeover: OpsDebrief shows the NPC-boat glyph + "Too slow" and the camera cuts to the pickup 2 s.
- Cold open: clear the survivor seat on every hand-over; never offer during the cold open.
Acceptance: accept a call, stand on the pier 30 s: no NPC boat leaves; board and drive: a red boat blip
appears and you see it leave; lose on purpose: you see it take the survivor, then the "Too slow" card. No
new card appears while someone is aboard.

**WP-C · Craft and camera** — changes 5, 6.
Files: `server/Services/VehicleService.luau`, `client/Controllers/BoatController.luau`,
`client/Controllers/VehicleExitController.luau`, `client/Controllers/CameraController.luau`,
`client/Camera/Chase.luau`, `shared/Config/VehicleConfig.luau`.
- Phone spawn = craft in open water at your bay, you seated, bow to sea; retry seat until it holds.
- Bay "Launch" prompt hidden while you have a craft out; off your craft, `[E] Board` reaches 30 studs and an
  orange craft billboard (seat pips ●○○) stays on it.
- Keyboard steer ramps to full in 0.4 s, less lock at speed; touching a wall at <3 km/h with throttle
  gives a gentle push-off.
- Camera arm never shorter than the character's shoulders; fade the rider instead of clipping.
Acceptance: spawn a RIB from the phone → seated, moving forward on W within 2 s; jump off, swim 20 m away:
an orange craft pin is visible and one E press boards; tap D for 0.3 s turns < 30°; drive into the quay at
full throttle and you're free in < 2 s; no screenshot shows the inside of the rider's head.

**WP-D · Beats and the first 3 minutes** — changes 4, 7, 8 (client side).
Files: `client/Controllers/OnboardingController.luau`, `client/UI/ColdOpenCue.luau`,
`client/UI/OnboardingReward.luau`, `client/Mechanics/auto_board.luau`, `server/Ops/PiwRescue.luau`,
`server/Services/RescueService.luau`.
- New player: no visible town wait; fade in at sea on the ski when the cold open begins.
- Board: survivor swims up and climbs on in frame (camera holds the chase shot, no zoom), "1/1" pops.
  Full craft: the swimmer waves and treads water at 5 m instead of clinging.
- Deliver: the pad pulses green from 60 m, survivor climbs off onto the pad in view, coin burst.
- Cold open ends with that same delivery beat, not a teleport; the off-craft grace only shows the craft pin.
Acceptance: fresh profile (F8 › Progress › Reset me): sea within 5 s of the world showing; first survivor
seen climbing on; green house pin to the slipway; climb-off and coins seen; full jet ski + second swimmer:
the swimmer waits at a distance, the craft shows ●(full).

Order: WP-A and WP-C first (parallel), then WP-B and WP-D (parallel). One Opus real-client sign-off at the end
with a fresh profile, using `build/ux/log.md` moments M1–M13 as the checklist.

Not verified: camera orbit by right-drag (the test driver's right-drag did not turn the camera on foot
either, so it may be the tool); the owner's "Too slow" failure was not reproduced in this session.

### WP-C addendum (owner, 2026-10-24): crowding and wrong-medium despawn

- Wrong medium: a boat that sits on land, or a car that sits in water, past the auto-recovery attempt (or with
  nobody aboard) for ~6 s despawns with a splash/poof; the player lands on their feet and the craft pin
  points to the bay (phone Spawn / bay Launch brings a new one). Occupied vehicles still try recovery first.
- Crowding with a full server: one vehicle per player (already); empty vehicles left anywhere despawn sooner
  when the server is busy (scale the idle timer by player count); spawns spread across all free bays and
  slipways (and the new island docks) instead of stacking at one; NPC traffic and moored-boat density scale
  down as players go up; player vehicles soft-collide with each other (no launches/flips from bumps) and
  never spawn overlapping another vehicle.
Acceptance: a boat dragged onto the quay and left there disappears within ~10 s; a car driven into the
harbour and abandoned disappears; with 8 test players (Studio local server) the bays and roads stay usable
and no spawn overlaps another vehicle.
