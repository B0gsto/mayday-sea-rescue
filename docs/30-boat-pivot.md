# 30 · The pivot: upgrade your boat (owner 2026-11-03)

Owner: "The idea of this game pivots on upgrading the boat as much as possible, going back, then going back in so the
core loop is simple and engaging." "Every step needs to be a massive improvement and you may exaggerate on every step."
"The player should not care about going back and parking the vehicle."

**Loop: go out -> rescue -> press Go back -> upgrade -> go out, faster and further.** Far water (docs/29) has better
survivors. This wins over docs/00 sections 3-7 wherever they differ; docs/00 gets rewritten once this is playtested.

## 1. Go back (no parking, ever)
- A big **Go back** button low on the screen (home icon + 2 words; keyboard key, gamepad button, touch), shown while
  driving away from home. Works on every craft, with or without survivors.
- Press: a charge of about 1.5 s with a fast camera whoosh, then you, your boat and everyone aboard are home.
  Survivors hop off by themselves, pay lands, workers walk off.
- **You stay on the boat, already at the jetty, bow to the open sea, throttle ready.** No docking, parking, stepping off
  or Launch prompt in the loop. The Upgrade button is right there. Getting off to walk your island is optional.
- A pirate ram during the charge cancels it (docs/29 D). Server validates everything. Driving home by hand still works.

## 2. Fifty levels, every one massive
One boat, one straight ladder, one big **Upgrade** button (home only, green price, one tap; nothing to choose, so it
is not a choice menu). Cash only. Exaggerate everything.

**Every level changes all of:** speed, how it looks, and a level-up moment. The moment: the boat lifts out of the
water, spins, blasts bricks and spray, slams down bigger and new, one big sound (reduced-motion: no shake). Under 3 s.

| Levels | Hull (a whole new boat each stage) | Exaggeration |
|---|---|---|
| 1-10 | Jet ski (existing) | fins, twin engines, flames, rescue sled |
| 11-20 | RIB (existing) | oversized engines, spoilers, tubes, neon wake |
| 21-30 | Lifeboat (existing) | rockets, armour plates, huge lamps, foil wings |
| 31-40 | Hydrofoil (new, Lego) | flies above the water, giant jets |
| 41-50 | Rocket Cutter (new, Lego) | absurd: boosters, gold, a wake like a wall |

Each level adds a named, clearly visible piece, and the boat's scale grows (about x1 to x2.5). Wake and trail get
bigger and change colour; speed lines and FOV grow with speed. Details on a concept board first (design before Blender).

**Speed** (studs/s, `-- tune`): 80, 120, 170, 225, 285 (L5), about 430 at L10, about 620 at L20, about 800 at L30,
about 950 at L40, about 1100 at L50, with early jumps far above the late ones in % terms. The real limit is what the
boat physics, sea and streaming hold: find it by test, and if it is lower, compress the table and exaggerate with
looks. Handling grows too, so it never feels like ice.

**Room:** 1, L3 2, L6 3, L11 4, L16 5, L21 8, L26 9, L31 10, L41 12, L50 14. Survivors past the visible seats just count.

**Speed has to stay playable:** pick-up reach grows with speed, or a fast boat drives past people; hitting an island at
speed glances off, never stops you dead or throws you off.

**Price:** the first rescue pays exactly for L2 and the next few take one or two trips. Whole ladder about 15 h free
play (tests/Pacing).

## 3. Robux is cosmetic for boats
Paid boats are **completely different cool designs with no stats**: a look on your level's stats, hull included. Levels
are never sold. Existing buyers keep what they paid for: RIB and Lifeboat passes and every paid boat stay as owned looks,
and the store text changes. Old saves never go down: owning the RIB starts you at L11 at least, the Lifeboat at L21.
Unchanged for now, owner to review: Cash packs and 2x Cash (they speed up levels), Starter Kit contents.

## 4. Island and tutorial
- The island stays optional: workers, flex, spin. Boat levels stop depending on buildings. Which buildings to cut is a
  later owner review. Helicopter and submarine stay as they are for now.
- Tutorial: free Hut -> first rescue (docs/29 A) -> Go back -> Upgrade to L2 -> out again, feeling the speed. The Workshop
  beat and the jet ski hold (CraftHeld) leave the tutorial.

## 5. Changes to docs/29
Pirates (D) no longer chase you home, since Go back removes that trip. They hunt you while you have survivors aboard;
a ram knocks one off and cancels a Go back charge, so the tension is the last seconds before pressing. Go back after a
chase with no hit pays the +25%. Pick-up boost and run stay.
