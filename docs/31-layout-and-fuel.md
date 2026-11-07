# 31 · The map, sea zones and fuel

Owner 2026-11-03 (zones: "go further = new biomes and better survivors") and 2026-11-07 (spread the map, a fuel gauge
"so that a new player cannot go as far as an experienced player"). Overview: [00-design.md](00-design.md). Boat loop:
[30](30-boat-pivot.md). Numbers marked `-- tune` in the code can move; the code wins over this file.

## 1. Layout

All distances from `RingLayout.Center` (the lagoon's centre). Map radius 7,000 studs (`WorldConfig.MapRadius`; past it
`Boat/SeaEdge` turns the boat back).

| Place | Where | Notes |
|---|---|---|
| Hub beacon atoll | centre lagoon | A landmark, not an island. |
| 6 player plots | ring at 860, plates 640 studs | Lego baseplates, walkable bridges between neighbours, boats pass under. Each has an Upgrade Station bay and an exit lane along its own bearing. |
| Outer islands | zones 2-5, mostly z >= -300 | Skerry Isle, Puffin Isle, Gannet Rock, Mermaid Lagoon, Wreck Reef, The Arches, Penwyn. |
| Gull Stacks | bearing 212, r 2,200 (Kelp Banks) | Sea stacks. |
| Wreck Shoal | bearing 270, r 3,400 (Coral Drift) | A wreck aground between rocks. |
| Storm Light | bearing 330, r 4,600 (Storm Reach) | A lighthouse rock, the tallest thing out there. |

The three hotspots (`shared/Calls/SectorSpots`, dressed by `server/World/SectorSpots` with finished hub-kit pieces) fill
the empty -Z half, so every 60 deg sector has a destination. `AmbientMix` spreads far survivors evenly over the outer
islands and the hotspots by sector.

**Plot spread** (`Marina.assign`): the first player in an empty server gets a random plot; each later player gets the
free plot farthest by bearing from the taken ones (ties: lowest index). Two players sit opposite, three 120 deg apart.
Live trails before this showed nearly every session on Plot 1, all heading the same way.

## 2. Sea zones

`shared/Calls/SeaZones` (pure, tests/SeaZones). Five rings; a survivor's rarity rolls from the zone they spawn in, and
free-roam pay scales by zone. Call pay keeps its own distance rule.

| # | Zone | Radius | Water | Rarity % Common..Mythic | Free-roam pay |
|---|---|---|---|---|---|
| 1 | Shallows | 0-1,600 | bright teal | 78/18/4/0/0/0 | x1 |
| 2 | Kelp Banks | 1,600-2,800 | green teal | 55/28/13/4/0/0 | x1.25 |
| 3 | Coral Drift | 2,800-4,000 | violet blue | 32/33/22/10/3/0 | x2 |
| 4 | Storm Reach | 4,000-5,200 | steel blue, overcast | 15/28/30/19/7/1 | x3 |
| 5 | Wreck Abyss | 5,200+ | near-black indigo | 5/15/30/30/16/4 | x4 |

How you see them, no wall (the glow curtain was cut 2026-11-07):
1. Water colour, fog, exposure, saturation and overcast blend by distance over 300 studs either side of a line
   (`SeaZones.lookAt`).
2. A client-pooled line of tall buoys in the zone colour near the player (pool 24).
3. Coloured circles on the full map and minimap.
4. Crossing a line: one banner pop (zone name, best rarity gem, a sound), once per crossing.

Legendary+ survivors far out show a tall rarity-coloured light column.

## 3. Fuel

`shared/Boat/Fuel` (pure, tests/Fuel), `FuelService` (server), `client/UI/FuelGauge`. Fuel is counted in seconds of
full throttle, so it is fair at 80 or 1,100 studs/s. It belongs to the player: the boat, helicopter and sub all use the
boat level's tank and rating.

| Rule | Value |
|---|---|
| Tank | 24 + 0.4 x (level - 1) s: L1 24, L10 27.6, L11 28, L20 31.6, L30 35.6, L50 43.6 |
| Rating (zone burning x1) | stage + 1: L1-10 Kelp Banks, L11-20 Coral Drift, L21-30 Storm Reach, L31-50 Wreck Abyss |
| Burn per second | speed share (0..1) x zone factor: Shallows 0, up to rating 1, one zone past 5, two or more 25 |
| Free | idling, a Go back ride, the Deep Spin; boost and Nitro cost no extra (speed share capped at 1) |
| Refuel | full, instant, free at home: a Go back landing, the drop-off zone, the station bay (`GoBack.isHome`), respawn. Never at sea. |
| Empty | the boat coasts at 15% speed for 3 s, then rides home by itself (`VehicleService.FuelHome`): no pirate ram cancels it, survivors aboard pay as normal. No other penalty. |

**Reach on a full tank**, straight out from the berth (r ~1,115; tests/Fuel asserts these):

| Level | Reach |
|---|---|
| L1 | Coral line + 140 |
| L5 | Storm line, then empty |
| L10 | 190 into Storm Reach |
| L11 | 170 into Wreck Abyss |
| L20 | 450 into Wreck Abyss |
| L21+ | the map edge |

So a new player sees the Storm line at most; the Wreck Abyss (4% Mythic) is a dash from L21 and home water from L31.

**Calls** never go past the level's `callReach` (2,000 / 3,500 / 5,500 from home), which matches the ratings, so the
tutorial never runs dry. No Robux fuel product: refuel is free and reach is progress.

**HUD** (`FuelGauge`, just over Go back while you drive): a fuel can and a bar, no numbers. Green, yellow under 50%,
red under 20%. The drain speed shows the burn, 1-2 chevrons show x5 / x25. At 20%: one pop of the can, one beep, one
Go back bounce. Burn steps up: one shake of the can. Empty: `fuel_sputter` VFX. Refuel: the bar fills in ~0.4 s with
`fuel_fill`. Reduce motion: no pop, shake or bounce. The Upgrade Station board and panel show the tank jump.

Player attributes: `Fuel`, `FuelMax`, `FuelBurn` (0/1/5/25). Telemetry: `Fuel` `Empty` (boat level, zone name).
