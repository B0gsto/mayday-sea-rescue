# 30 · The boat loop: Go back, 50 levels, run, pirates

Owner pivot 2026-11-03: "The idea of this game pivots on upgrading the boat as much as possible, going back, then going
back in." Overview: [00-design.md](00-design.md). Map, zones and fuel: [31](31-layout-and-fuel.md). Numbers marked
`-- tune` in the code can move; the code wins over this file.

## 1. Go back

`shared/Boat/GoBack` (rules, pure), VehicleService (server ride), `GoBackController` (button, chase shot).

- A big **Go back** button low on the screen (home icon), shown while driving away from home: R, gamepad R3, touch.
  Hidden inside the station bay (60 studs) and during the spin cinematic.
- Press: the boat turns toward home in place (`TURN` 0.8 s), then drives itself home along a route round the islands
  (`RUN` 4 s, speed scaled to the route), and swings round into the Upgrade Station bay bow to sea. About 5 s from any
  distance. A route with no clear way home shows its launch, then hides the middle under a short sea-blue veil.
- Landing: survivors hop off, pay lands, workers walk off, the fuel tank fills. The camera frames the boat and the board
  until the first throttle, steer or look.
- A pirate ram during the turn cancels it. Cooldown 2 s. Server validates every press. Driving home by hand still works.
- No docking, parking, stepping off or Launch prompt. You can't step off at open sea (`Boat/SeaExit`): only at home, in a
  station bay, beside a deck or shore, or in water 5 studs deep or less.

## 2. Upgrade Station and panel

- **Station** (`shared/UpgradeStation`, `UpgradeService`): a landmark at the water on every plot with a bay the boat
  lands in. Its board shows Lv N / 50 with the five stages, the next piece, the jumps (speed, room, fuel tank),
  price and missing Cash, and one green **Upgrade** button (tap, key, gamepad). Grey when short; a press shakes the
  missing number. Usable from the boat or on foot.
- **On-boat panel** (`client/UI/Panels/Upgrade`, owner 2026-11-07): the same buy from the helm anywhere at sea, opened by
  the Next chip (tap, F, gamepad Y). One option, so not a choice menu. A buy closes it and the level-up plays where you
  are.
- **Level-up moment:** the boat lifts, spins, bursts bricks and spray, slams down with its new piece (VFX
  `boat_levelup`, one sound; reduced motion: no shake). Under 3 s. A new stage swaps the whole hull.

## 3. The ladder

`shared/BoatLevels`, 50 rows. Cash only. Per level: speed, room, scale (x1 to x2.5, looks capped at 72 studs long),
turning circle (108 + 0.15 x speed), pick-up reach (0.18 s of top speed, 14 studs at least), call reach (2,000 /
3,500 / 5,500 studs from home by stage) and fuel tank (24 + 0.4 x (level - 1) s). Speed is capped at 1,100 studs/s
(tests/BoatLevels: buoyancy holds the whole table, calm and storm). L1-L3 turn at most 80 deg/s.

| Stage | Hull | Fuel rating |
|---|---|---|
| 1-10 | Jet Ski | Kelp Banks (2) |
| 11-20 | RIB | Coral Drift (3) |
| 21-30 | Lifeboat | Storm Reach (4) |
| 31-40 | Hydrofoil (placeholder Parts on the RIB hull) | Wreck Abyss (5) |
| 41-50 | Rocket Cutter (placeholder Parts on the Lifeboat hull) | Wreck Abyss (5) |

| Lv | Piece | Speed | Room | Tank (s) | Price |
|---|---|---|---|---|---|
| 1 | Bare jet ski | 80 | 1 | 24.0 | 0 |
| 2 | Shark fin | 120 | 1 | 24.4 | 500 |
| 3 | Rescue sled | 170 | 2 | 24.8 | 550 |
| 4 | Twin engines | 225 | 2 | 25.2 | 650 |
| 5 | Flame pipes | 285 | 2 | 25.6 | 700 |
| 6 | Banana boat | 315 | 3 | 26.0 | 1,300 |
| 7 | Huge spoiler | 345 | 3 | 26.4 | 1,500 |
| 8 | Bull nose | 375 | 3 | 26.8 | 2,200 |
| 9 | Horn stack | 405 | 3 | 27.2 | 2,800 |
| 10 | Turbo crown | 430 | 3 | 27.6 | 4,300 |
| 11 | Big RIB | 450 | 4 | 28.0 | 6,000 |
| 12 | Mega outboard | 470 | 4 | 28.4 | 9,300 |
| 13 | Arch spoiler | 490 | 4 | 28.8 | 11,500 |
| 14 | Neon fins | 510 | 4 | 29.2 | 15,000 |
| 15 | Fat tubes | 530 | 4 | 29.6 | 18,000 |
| 16 | Grandstand | 550 | 5 | 30.0 | 21,000 |
| 17 | Paddle wheel | 570 | 5 | 30.4 | 25,000 |
| 18 | Shark jaws | 585 | 5 | 30.8 | 28,500 |
| 19 | Exhaust organ | 605 | 5 | 31.2 | 31,500 |
| 20 | Thunder wing | 620 | 5 | 31.6 | 35,000 |
| 21 | Big lifeboat | 640 | 8 | 32.0 | 38,500 |
| 22 | Armour spikes | 660 | 8 | 32.4 | 56,500 |
| 23 | Huge lamps | 675 | 8 | 32.8 | 60,500 |
| 24 | Ice plough | 695 | 8 | 33.2 | 64,500 |
| 25 | Roof rockets | 715 | 8 | 33.6 | 69,000 |
| 26 | Crew deck | 730 | 9 | 34.0 | 72,500 |
| 27 | Lamp tower | 750 | 9 | 34.4 | 82,000 |
| 28 | Foil lift | 765 | 9 | 34.8 | 85,500 |
| 29 | Rear rockets | 785 | 9 | 35.2 | 92,500 |
| 30 | Battle bridge | 800 | 9 | 35.6 | 96,000 |
| 31 | Hydrofoil | 815 | 10 | 36.0 | 100,000 |
| 32 | Giant jets | 830 | 10 | 36.4 | 113,000 |
| 33 | T-tail | 845 | 10 | 36.8 | 117,000 |
| 34 | Sky stilts | 860 | 10 | 37.2 | 124,000 |
| 35 | Needle nose | 875 | 10 | 37.6 | 128,000 |
| 36 | Sky wings | 890 | 10 | 38.0 | 132,000 |
| 37 | Afterburners | 905 | 10 | 38.4 | 136,000 |
| 38 | Radar dish | 920 | 10 | 38.8 | 143,000 |
| 39 | Top jet | 935 | 10 | 39.2 | 148,000 |
| 40 | Turbo halo | 950 | 10 | 39.6 | 152,000 |
| 41 | Rocket Cutter | 965 | 12 | 40.0 | 159,000 |
| 42 | Side boosters | 980 | 12 | 40.4 | 184,000 |
| 43 | Gold plating | 995 | 12 | 40.8 | 192,000 |
| 44 | Wave wall | 1010 | 12 | 41.2 | 199,000 |
| 45 | Gold eagle | 1025 | 12 | 41.6 | 207,000 |
| 46 | Rocket fins | 1040 | 12 | 42.0 | 214,000 |
| 47 | Gold throne | 1055 | 12 | 42.4 | 221,000 |
| 48 | Party cannons | 1070 | 12 | 42.8 | 228,000 |
| 49 | Mega trophy | 1085 | 12 | 43.2 | 235,000 |
| 50 | Sun booster | 1100 | 14 | 43.6 | 245,000 |
total 4309800

Whole ladder: 4,309,800 Cash. L2-L5 cost exactly the four tutorial payouts (500, 600, 600, 700, with 50 carried), and
below L5 any rescue pays at least the next level (`earlyPayFloor`). Past L8 prices are about x3 a flat-pay ladder,
because zones and the run's x2 stack.

**Pacing** (`tests/Pacing.spec.luau` output, 2026-11-07): L2 0.8 min, L5 2.9 min, L11 12 min; L10 0.2 h, L20 1.4 h,
L30 4.2 h, L40 8.6 h, L50 15.0 h over 857 trips; trips for L2-L8: 1 1 1 1 2 2 1. With no run L50 takes 29.4 h; always
at the far edge, 9.6 h. The test is seed-noisy.

**Old saves** never go down (`BoatLevels.legacyFloor`): the lowest level that holds the old boat's speed and room, so
owning the RIB starts you at L11 or more and the Lifeboat at L21.

## 4. Robux boats are looks

Paid and wheel-won boats have no stats: a design worn on your level's stats. Levels are never sold. RIB and Lifeboat
passes and every paid boat stay as owned looks. Cash packs and 2x Cash still speed up levels. Details: docs/04.

## 5. Rescue run and pick-up boost

`shared/RescueRun`, `RescueRunService`, `UI/RunChip`. A run counts survivors delivered home in a row; delivery pay x1,
x1.25 at 3, x1.5 at 6, x2 at 10 (cap). It ends 75 s after your last pick-up or delivery, or on a pirate hit. The chip
shows x and a timer; pay uses the x on the chip when you arrive. Each pick-up gives +25% top speed for 3 s with a wake
and sound. The new player's stripped HUD has no run (flat tutorial pay).

## 6. Pirates

`shared/PirateRules`, `shared/PirateBoat` (placeholder Parts), `PirateService`, `PirateController`, DEV `pirate`.
Kid-safe: no guns, no combat, nobody dies.

- Only with survivors aboard, in zone 2+, after 5 saved calls (never in the tutorial). A roll every 5 s; chance rises
  with zone and how full the boat is. At most 2 per zone per server; 45 s cooldown after a chase.
- Spawns 5 s of your top speed away (300 studs at least), to the side, and steers an intercept at 0.92x your top speed,
  so fast boats still get cut off. One horn, one pop, an edge arrow.
- A ram knocks one survivor into the water (they keep their roll; can't climb back for 4 s), ends your run and cancels a
  Go back turn. The pirates then sail off. They give up after 40 s or at the Shallows line.
- Escape: a boost slows them to 0.7x; land between you for 2 s shakes them. Go back after a chase with no hit pays
  +25%.
- Server-steered, no physics, culled and cleaned up.

## 7. Tutorial (boat first)

`OnboardingController`, `shared/Onboarding`, `Boat/ColdOpen`. The free Rescue Hut is granted at load; you start on the
jet ski in a cold open: three swimmers fanned off your cove, all with the normal ring. The first one home completes the
cold open (a Builder); the other two roll as free roam and leave. The first delivery lands in the station bay and pays
L2; one arrow on Go back (taught once), then the Upgrade button, then one arrow out to sea. After L2 and a trip home,
the free spin (beacon only while home), then the Next chip leads with the boat level. No pirates until it ends. Old
saves with 5+ rescues skip it.

Funnel: Joined, AtSea, FirstBoard, FirstDelivery, FirstUpgrade, BackOut, FirstSpin, BoatL3, BoatL5, BoatL11
(`tools/trail.py`).
