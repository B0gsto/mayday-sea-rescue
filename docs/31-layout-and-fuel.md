# 31 · Map spread and the fuel gauge (owner 2026-11-07)

Owner: "you may change the map layout as all the players kinda go in the same path + if you think it would be better,
we can put plots on the same land. Also to be able to progress I think it would be better to have a gas meter of how
much a player can go so that a new player cannot go as far as an experienced player."

Design only; no code yet. Rules that still hold: no choice UI, show don't tell, nothing flashes or pulses orange, no
outline rings, nobody is stranded or dies, every action on keyboard, touch and gamepad, Robux boats are looks only
(docs/30 section 3), existing finished assets are never redesigned. Numbers are `-- tune`.

## A. Why everyone takes the same path

Three causes, all in data, none in the sea itself:

1. **Plot 1 every time.** `Marina.assign` hands out the first free plot. Live servers hold one or two players, so
   nearly every session starts on Plot1 (bearing 0, +X) and the second on Plot2 (60 deg). Live trails
   (build/liveops/trail-*.txt, positions bucketed by bearing round the ring centre): 584 of 2,762 home-water fixes in the
   0-30 deg wedge plus 720 in 330-360, i.e. Plot1's cove; bearings 180-300 have 232.
2. **Every destination is on one side.** All seven outer islands, the three dive sites, the ferry site (0, 1550) and
   the rip beach sit at z >= -300: Skerry Isle (44 deg), Gannet Rock, Mermaid Lagoon, Puffin Isle, Wreck Reef, plus
   Penwyn and The Arches on the axis. The -Z half (behind Plots 5 and 6) is empty water. `AmbientMix.FAR` puts 30 % of
   timed survivors off an outer island, so the survivors lean that way too. Past the Shallows line, 34 % of all live
   fixes are in the 30-60 deg wedge: the straight line from Plots 1-2 to Skerry Isle.
3. **Zones give no direction.** The five sea zones are circles round the lagoon (docs/29 B), so every heading looks the
   same and the only pull is the landmarks of cause 2.

The exit lanes are fine: each plot's lane points straight out along its own bearing, six different ways.

## B. Layout options

| Option | Fixes 1 | Fixes 2 | Cost | Assets |
|---|---|---|---|---|
| **1. Keep the ring, spread plots, fill the empty half** | yes | yes | small: one function, one data module, placed props | all kept, nothing moves |
| 2. One shared home island, plots side by side, berths facing six sectors | yes | no (still one side) | huge: RingLayout, IslandPlates, bridges, stations, Go back landings, every lot, ~10 specs | finished buildings keep their look but all move; bridges cut |
| 3. Pie-slice zones (a biome per sector) | no | partly | medium: SeaZones, tint, buoy line, map, banner | kept, but docs/29's circles (owner asked for circles) go |

**Pick option 1.** A shared island looks social, but the ring already puts neighbours 860 studs apart with bridges, and
with one or two players per server the berths would still all face the side where the islands are. Option 1 is a
few small edits and keeps docs/29's circles. The sim pattern in the LihFolk vault (World Composition, Zone and Biome Art
Direction) also fits: one hero landmark per zone, framed from the spawn, so each direction has its own goal.

What changes:

1. **Spread the plots** (`Marina.assign`): the first player in an empty server gets a random plot; each later player
   gets the free plot farthest by bearing from the taken ones (ties: lowest index). Two players sit opposite (180 deg
   apart), three sit 120 deg apart. `CallLogic.homeOf(nil)` (the server-wide call's Plot1 home) stays as is.
2. **One destination per empty sector, from existing assets.** A new data module (`shared/Calls/SectorSpots.luau`) lists
   a hotspot in each 60 deg sector that has none, in zones 2-4: about bearing 210 (Kelp Banks, r 2200), 270 (Coral
   Drift, r 3400) and 330 (Storm Reach, r 4600). Each is dressed only with finished assets already in the game (navmark
   cardinals and lights from SeamarkRules, a wreck kit like Morwenna's, the hub beacon's buoy). No new model, so no
   concept round. If the owner later wants new Lego landmarks there, those go through design-before-Blender.
3. **Survivors follow every direction.** `AmbientMix.FAR` picks a spot round-robin over the outer islands **and** the
   SectorSpots, weighted so each of the six sectors gets an even share. `ZONE_SHARE` and `zonePoint` stay.
4. Nothing moves: islands, lots, bridges, stations, exit lanes, terrain windows and zone radii are unchanged.

## C. Fuel gauge

**Idea:** a tank you can see. Your own zones burn slowly; each zone past your boat's rating burns 5x faster, the
next 25x. A new player can dash one zone past their rating but not two; a maxed boat can stay in the Wreck Abyss.
Measuring fuel in seconds of top speed (not studs) keeps it fair at 80 or 1,100 studs/s.

### Rules
- **Tank** (seconds of full throttle): `tank = 24 + 0.4 x (level - 1)`, so L1 24, L10 27.6, L11 28, L20 31.6, L30 35.6,
  L50 43.6. New `BoatLevels` row field `tank`.
- **Rating** (the farthest zone you cruise at x1) jumps with each new hull, the "massive step": L1-10 zone 2 (Kelp
  Banks), L11-20 zone 3 (Coral Drift), L21-30 zone 4 (Storm Reach), L31-50 zone 5 (Wreck Abyss). It matches the
  existing `BoatLevels.callReach` steps (2000 / 3500 / 5500 from home).
- **Burn per second** = `min(speed / topSpeed, 1) x factor(zone)`: Shallows 0, at or inside rating 1, rating + 1 is
  5, rating + 2 or more is 25. Idle, drifting or parked burns nothing. The pick-up boost and Nitro are capped at 1, so a
  boost never costs extra.
- **Refuel:** full and instant, free, whenever you are home: a Go back landing, driving into your own cove or exit lane
  (`RingLayout.laneFacing`), the station bay, a respawn. No refuel at sea.
- **Go back:** the ride costs nothing and fills the tank. Driving home by hand burns as normal (the Shallows are free).
- **Empty, so nobody is stranded:** the engine sputters (sound + a puff of smoke), the boat coasts at 15 % speed for
  3 s, then an automatic Go back runs. Survivors aboard pay as normal and the run keeps its x. Pirates cannot cancel
  this one. No other penalty: the gate is that you never got farther out.

### What each level can reach (straight dash from the berth, r ~1,115; the Shallows line is 485 studs out and free)

| Level | Speed | Tank | Rating | Reach on a full tank | Roam in own zones |
|---|---|---|---|---|---|
| L1 | 80 | 24 | Kelp | Coral line + 140 studs | 24 s |
| L5 | 285 | 25.6 | Kelp | Storm line, then empty | 25.6 s |
| L10 | 430 | 27.6 | Kelp | 190 into Storm | 27.6 s |
| L11 | 450 | 28 | Coral | 170 into Abyss | 28 s |
| L20 | 620 | 31.6 | Coral | 450 into Abyss | 31.6 s |
| L21 | 640 | 32 | Storm | Abyss to the map edge (5 s of it) | 32 s |
| L31+ | 815+ | 36+ | Abyss | anywhere, 36-44 s | 36-44 s |

So the Wreck Abyss (Mythic 4 %) is a dash from L21 and a home from L31; a new player sees the Storm line at most.
Roaming your own zones lasts 24-44 s at top speed, about one trip (tests/Pacing averages ~63 s a trip with stops).

### Other systems
- **Every craft uses the same tank.** Fuel belongs to the player, not the craft: the helicopter and sub (which ignore
  levels) use the boat level's tank and rating, or the heli would skip the gate. *Owner decision.*
- **Pirates:** unchanged. Evading burns fuel like any driving, which adds to the "one more, or go back?" tension.
- **The Deep:** fuel is frozen during the Deep Spin dive; if it surfaces you at home, you refuel there.
- **Calls:** a call offered beyond what your tank can reach is never offered: cap its distance at the level's
  `callReach`, which already matches the ratings. Cold open and tutorial calls are inside the Shallows/Kelp: the gauge
  never runs dry in the tutorial (L1-L5 roam 24+ s in Kelp, their calls take a few seconds).
- **Robux:** no fuel product. Free refuel at home makes one pointless, and selling reach is selling progress
  (docs/30 section 3: levels are never sold). Paid boats are looks, so they use the level's tank. Cash packs and 2x
  Cash are unchanged (owner review per docs/30). *Owner confirms.*

### HUD and board (icon first, no text)
- **Boat card** (`client/UI/BoatCard`): a fuel-can icon and a bar. Green, then yellow below 50 %, then red below
  20 %. The bar's drain speed shows the burn: past your rating it visibly races, and 1-3 small chevrons beside the
  icon show x1 / x5 / x25. No numbers.
- **Low fuel (20 %):** one pop of the icon, one low-fuel sound, one bounce of the Go back button. No pulse, no flash,
  no outline.
- **Crossing a line past your rating:** one shake of the icon with the zone banner (docs/29 B), so cause and effect
  read together.
- **Refuel:** the bar fills in about 0.4 s with a glug sound (paired with a small `fuel_fill` VFX at the boat).
- **Upgrade Station board:** a third jump row next to speed and room: fuel-can icon, 27.6 -> 28 drawn as two bar
  lengths. On a new hull, the rating jump as a zone-colour gem (the docs/29 zone gems).
- Sprites are Claude SVG (`art/source/ui/fuel_can.svg`, chevron), rendered by `tools/ui-art/render.py`, AD 8.5+.

### Telemetry
`Fuel` events: `Empty` (zone, level), `AutoHome`, `FirstPastRating` (zone). Funnel check: do players at L11/L21 cross
into the newly rated zone within 2 trips?

## D. Build plan (disjoint files, in order; each one builder plus a check.sh run)

1. **Plot spread** (S, ~1 h): `src/shared/Marina.luau` (`assign(taken, rng)`: random first, then farthest by
   bearing), `src/server/Services/DockService.luau` (pass the rng at its one call), `tests/Marina.spec.luau`. Check:
   nothing else assumes the first player is Plot1 (grep `Plot1`, `DockPlot`).
2. **Fuel rules, pure** (S-M, ~2 h): `src/shared/Boat/Fuel.luau` (`tank(level)`, `rating(level)`,
   `factor(zone, level)`, `burn(dt, speedFrac, zone, level)`), the `tank` field in `src/shared/BoatLevels.luau`,
   `tests/Fuel.spec.luau` (the reach table in section C as asserts), and `tests/Pacing.spec.luau` (trips capped by the
   tank; the ~15 h ladder must still hold). Runs in parallel with 1 and 3.
3. **Sector spots** (M, ~3 h): `src/shared/Calls/SectorSpots.luau` (data), `src/shared/Calls/AmbientMix.luau` (FAR
   share over islands + spots by sector), `src/server/World/SectorSpots.luau` (places the existing assets),
   `tests/AmbientMix.spec.luau` (every sector gets 1/6 +- 5 % of FAR spawns), then `tools/studio/zfight_scan.luau` in
   Studio. Parallel with 1 and 2.
4. **Fuel server** (M, ~3 h, after 2): `src/server/Services/FuelService.luau` (per-player tank, burn on Heartbeat from
   the craft's speed and `SeaZones.zoneAt`, refuel on landing/home/respawn, empty -> limp 3 s -> Go back; player
   attributes `Fuel`, `FuelMax`, `FuelBurn` (1/5/25)), a small hook in `src/server/Services/VehicleService.luau` (an
   auto Go back flag that pirate rams can't cancel), telemetry. Call distance cap via `callReach` stays where it is.
5. **Fuel HUD + board** (M, ~3 h, after 2, parallel with 4: it only reads the three attributes): `src/client/UI/BoatCard.luau`,
   `src/shared/UpgradeStation.luau` (board row), `art/source/ui/fuel_can.svg` + chevron, sounds via AudioConfig,
   `fuel_fill` and sputter through VFXKit with the DEV `vfx` bench. Then one Opus Studio playtest of 1-5 together (L1,
   L11, L21 dashes, empty -> auto home with survivors aboard, two-player plot spread), then publish.

## Owner decisions
1. Helicopter and sub share the boat's tank and rating (recommended), or stay outside fuel?
2. No Robux fuel product (recommended)?
3. Empty tank: free auto Go back with full pay (recommended), or a small Cash tow fee?
