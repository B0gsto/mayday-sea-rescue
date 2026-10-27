# 25 · Island layout, building levels, one radial skill tree, survivors (proposal, 2026-10-27)

Owner: "Improve the buildings and the skills so we have a clear, satisfying progression. The placement of the
buildings makes no sense and no building has upgrades. Skill trees like Assassin's Creed Valhalla: from the middle
to the edges so we can keep adding as we update, full screen. One tree for the player + survivors. Which survivor
types (with special ones for the RNG), which buildings, a basic map. Animation heavy: survivors seen working,
gathering (builders take materials from a deposit; later lumberjacks and miners feed it)."

Status: **approved 2026-10-27, in implementation** (owner changes in section J, build contracts in K). Once approved this replaces docs/24 G (the two
left-to-right trees) and docs/00 §4 and §6 get rewritten to match. Rules that still hold: CLAUDE.md (no choice UI in
gameplay, show don't tell, every action on keyboard/touch/gamepad, new things Lego-style, keep finished models' looks).
Visual board (map, HQ spine, tree mock): `docs/25-visuals.html`.

What is wrong today:
- Lots sit wherever they fit on the plate. Nothing explains why the clinic is behind the bunkhouse or why the boat
  yard is far from the boats; there are no districts and no visible flows between buildings.
- Every building is a one-time buy. After ~15 builds the island stops growing and Cash has nothing to go into.
- Two trees (build tree and a 7-branch skill list) that read left to right and have no centre or room to grow.

## A. The spine: the Rescue Station (HQ) has 5 levels

The HQ stands on the plaza at the head of the berth cove, the first thing you see from the jetty. Its level is your
island's level (a building, not a rank). Each HQ level unlocks new buildings and raises every building's max level.
To upgrade the HQ you need Cash plus everything the current HQ level allows built at least once; the HQ card shows
those as icons with ticks, so the next goal is always on screen. A green arrow floats over anything you can
build or upgrade right now (Clash of Clans style).

| HQ | Look (Lego) | Unlocks | Max building level |
|---|---|---|---|
| 1 Rescue Hut (start, free) | hut + flag + bell | Harbour (jetty), Depot, Workshop, Bunkhouse, Fish Market | 1 |
| 2 Rescue Post | + watch room, 2nd floor | Boathouse (RIB), Boat Yard, Clinic | 2 |
| 3 Lifeboat Station | today's Station model (kept) | Rescue Boathouse, Lookout Tower | 3 |
| 4 Coastguard Base | + radio mast wing | Air Station (helicopter); Update 1: Lumber Camp, Quarry | 3 (Bunkhouse 4) |
| 5 Coastguard HQ | + gold beacon tower | Sub Pen, Trophy Hall, Harbour Master gold beacon | 3 (Bunkhouse 5) |

HQ prices: Lv2 3k, Lv3 12k, Lv4 80k, Lv5 160k Cash (tune with tests/Pacing; the last level fills the ~17 h track).

## B. Buildings and their levels

Each level is a visible Lego add-on to the same building (a wing, a floor, a second stall, a bigger boat), played
with the timed construction (docs/24 B). The Lv1 model stays what we have; levels add pieces, they never reshape it.
Lv2 ≈ 3x the Lv1 price (6x on HQ3+ rows), Lv3 ≈ 16-20x (tune). Robux can skip the Cash of any level the HQ allows, never the order.

| Building | Zone | Workers | Lv1 → Lv2 → Lv3 (what you see / what it does) |
|---|---|---|---|
| Harbour | Cove | none | jetty, 1 berth → **pontoon**, 2nd berth + lamps → **crane** over the cove, no relaunch wait |
| Depot | Work yard | Haulers | brick pile + freight quay, holds 20 loads → bigger pile, barge 2x → conveyor from the quay, holds 80 |
| Workshop | Work yard | Builders | open carpentry yard, 3 builder slots → 5 slots + saw bench → 8 slots + half-built boat frame |
| Bunkhouse | Village | (home) | 10 people → 20 → 30 (Lv4 45, Lv5 60); floors and hammocks added, lights at night |
| Fish Market | Harbour E | Fishers | 2 stalls + fishing pier → 4 stalls → smokehouse, 8 slots |
| Boathouse | Harbour W | none | RIB, boat board, paint booth → **lifeboat slip**, Lifeboat → quick-launch bay, Boat to me −15% |
| Boat Yard | Harbour W | Mechanics | hull on a cradle → gantry crane → dry dock (more slots, bigger caps) |
| Clinic | Village | Medics | tent with a red cross → pavilion → small hospital + ambulance |
| Rescue Boathouse | Harbour E | Rescuers | NPC dinghy → NPC RIB (more seats) → NPC lifeboat (more trips) |
| Lookout Tower | Air field | none | call pins from farther → golden calls x1.5 → spotlight, golden calls x2 |
| Air Station | Air field | (Update 2: Pilots) | helipad + hangar, Helicopter → refuel pad, faster heli → Pilots' NPC patrol |
| Sub Pen | Harbour E | (Update 2: Divers) | domed pool, Submarine → deeper dives → Divers' salvage |
| Trophy Hall | Landmarks | none | columns + gold dome; plinths show your rarest survivors, wheel prizes, quest trophies (more per level) |
| Lighthouse | Front-left tip | none | quest chain reward (Keeper Ives), never sold |
| Lumber Camp, Quarry | Wild corner | Lumberjacks, Miners | Update 1 (section D) |
| Canteen | Village | Cooks | Update 2: lunch at noon, work speed buff |

Merged from today's list: Pontoon and Crane become Harbour Lv2/Lv3; Lifeboat slip becomes Boathouse Lv2; Helipad +
Hangar become Air Station Lv1; Station becomes HQ Lv3. Old saves migrate to the matching levels (refund any
difference). Decor stays as it is (Cash sink, the build tablet's Decor tab).

## C. The map (districts and flows)

The 320-stud plate keeps its shape: berth cove cut into the sea side, bridges entering both sides toward the back.
Rule: **water jobs on the water, work near its supply, the island fills from the plaza outward** (HQ1 buildings
nearest the plaza, HQ5 ones in the far corners), and **every worker walks a route you can watch from the plaza**.

```
                         LAGOON (neighbours see this side)
   +--------------------------------------------------------------------+
   | WILD CORNER (Update 1)  |  LANDMARKS            |  AIR FIELD          |
   |  grove = Lumber Camp    |  Trophy Hall (HQ5)    |  Lookout (HQ3)      |
   |  rocks = Quarry         |  flag tower, decor    |  Air Station (HQ4)  |
BRIDGE ==================== BRIDGE ROAD ====================================== BRIDGE
   | WORK YARD               |  PLAZA                |  VILLAGE            |
 barge> freight quay        |  HQ Rescue Station    |  Clinic (HQ2)       |
   |  Depot (HQ1)            |  prize wheel, tablet  |  Bunkhouse (HQ1)    |
   |  Workshop (HQ1)         |  (main avenue)        |  Canteen (Update 2) |
   +-------------------------+-----+    COVE   +-----+---------------------+
   | HARBOUR W               |     |  jetty    |     | HARBOUR E           |
   |  Boathouse (HQ2)        |     |  pontoon  |     |  Rescue Bh. (HQ3)   |
   |  Lifeboat slip (Bh. L2) |     |  crane    |     |  Fish Market (HQ1)  |
   |  Boat Yard (HQ2)        |     |           |     |  + fishing pier >   |
   |  Lighthouse (quest)     |     |           |     |  Sub Pen (HQ5)      |
   +-------------------------+     +-----------+     +---------------------+
     quest pontoon               OPEN SEA (calls)
```

Flows you can watch (each one is a walking route with a held prop):
1. Barge → freight quay → Depot: Haulers push hand carts of brick crates; the pile grows.
2. Depot → construction site: Builders carry brick stacks over their heads, hammer, walk back for more.
3. Pier → Fish Market: Fishers cast, reel in a flopping fish, carry crates to the stalls, "+$" pops.
4. Jetty → Clinic → job: every new arrival walks off the jetty in a blanket, gets checked, walks to work.
5. Rescue Boathouse → cove → sea: Rescuers run to their NPC boat and sail out; it comes back with people.
6. Boat Yard → your berth: Mechanics walk to your moored boat and work on it with a wrench (sparks).
7. Bunkhouse ↔ jobs: at dusk everyone walks home and the windows light up; at dawn they walk back out.
8. Update 1: grove and quarry → Depot (logs on shoulders, a mine cart on a short track).

Room to grow: the wild corner is reserved for Update 1. Later updates bolt **expansion plates** onto the two front
corners (out to sea, never toward a neighbour): a shipyard wharf, a bigger fishing wharf.

## D. Materials: the Depot and what feeds it (how this scales)

One place holds materials, the **Depot**. Builders take from it; producers fill it. Each new material arrives with its
own building, survivor type, outer skill branch and a section of the Depot pile.

- **Now: Bricks.** The supply barge moors at the freight quay every 60 s and Haulers unload it (no Haulers: the
  barge crew drops a few crates itself). A build's Cash price already pays for its bricks. A build needs
  `loads = ceil(T / 10)` (T from docs/24 B); each builder trip delivers one and the building rises by that much.
  Build speed = min(how fast builders carry, how fast the Depot refills). An empty Depot stops the builders: they
  wait at the pile and the pile shows an empty-crate icon. A full Depot makes the next build fly, so upgrading the
  Depot and hiring Haulers matters.
- **Update 1, "Timber & Stone":** Lumber Camp (Lumberjacks chop Lego trees in the grove; the tree falls apart brick
  by brick and regrows) and Quarry (Miners, pickaxe, a mine cart). Planks and Stone go to the Depot. Lv3 upgrades and
  new Update 1 buildings need some Planks/Stone on top of Cash.
- **Update 2, "Deep salvage":** Divers (Sub Pen) and the player (floating crates picked up at sea, tree node Salvage)
  bring Metal for Lv4–5 levels. Cooks, Pilots and the Canteen come in the same update.

## E. Survivors

Every rescued person rolls a **type**, a **rarity** and (Uncommon and up) a **trait** at pick-up, on the server,
never with Robux. The roll shows in the water: their badge colour, and from Epic up a light beam over them, visible
from far (the RNG moment happens in the world). Home, they walk the jetty → clinic → job route. The Bunkhouse level
sets how many you keep; when it is full a rarer arrival replaces your lowest one (Crew panel: send someone home).

Types (code key in brackets where it differs):

| Type | Works at | Seen doing | Effect |
|---|---|---|---|
| Builder | Workshop → any site | carries brick stacks Depot → site, hammers, dust puffs | build speed |
| Hauler (new) | Depot + freight quay | unloads barge crates onto a hand cart, stacks the pile | Depot refill rate |
| Fisher (`Gatherer`) | Fish Market + pier | casts, reels, carries crates to stalls, "+$" | Cash per minute |
| Mechanic | Boat Yard → your berth | welds under a hull (sparks), wrenches your moored boat | craft speed, Boat to me |
| Medic | Clinic | meets each arrival with a blanket, clipboard at the beds | call pay + |
| Rescuer | Rescue Boathouse | runs to the NPC boat, sails out, comes back with people | Cash per trip, recruits |
| Lumberjack, Miner | Lumber Camp, Quarry | Update 1 | Planks, Stone |
| Cook, Pilot, Diver | Canteen, Air Station, Sub Pen | Update 2 | lunch buff, heli patrols, Metal |

Rarity (same names and colours as the prize wheel, so the game has one rarity language):

| Rarity | Chance | Work value | Look |
|---|---|---|---|
| Common | 62% | x1 | grey badge |
| Uncommon | 25% | x1.25 | green badge, has a trait |
| Rare | 9% | x1.6 | blue, sparkles |
| Epic | 3% | x2.2 | purple, light beam in the water |
| Legendary | 0.9% | x3 | gold beam, toast for your server |
| Mythic | 0.1% | x5 | rainbow, server banner + confetti |

Pity: an Epic or better at least every 40 people rescued, a Legendary or better every 250 (tune). Golden Mayday
calls (gold flare, gold pin; about 1 in 40 calls, more with the Lookout and the tree) always carry an Epic or better.

Traits (icon on the badge): **Speedy** walks and carries 30% faster · **Strong** carries two loads ·
**Lucky** better recruits on NPC trips · **Night Owl** full rate while you are offline · **Cheerful** +5% to
co-workers in the same building.

Specials: named, one of each per player, collected in the Album (grey silhouettes until found). When a Legendary or
Mythic rolls, a special of that type you don't own yet can come instead; some only come from their own calls.

| Special | Rarity, type | What makes them special | Where from |
|---|---|---|---|
| Brickbeard | Legendary Builder | gold hard hat, carries 3 stacks at once | any call |
| Big Lou | Legendary Hauler | wheels a whole pallet, Depot refill x2 | any call |
| Captain Marlow | Legendary Rescuer | his NPC boat brings back twice as many, rarer recruits | any call |
| Dr. Coral | Legendary Medic | 5% of arrivals she checks go up one rarity (their name tag changes colour with a pop) | any call |
| Bolt the Robot | Mythic Mechanic | works all night and offline at full rate, beeps, sparks | any call |
| Pearl the Mermaid | Mythic Fisher | sits on the pier, catches golden fish (big "+$") | Mermaid Lagoon calls only |
| Nova the Astronaut | Mythic, any job | counts x5 in any building | Splashdown event: a capsule falls into the sea in flames, the whole server sees it |
| Old Bones | Mythic Diver | glows green, salvages treasure at night | Update 2, Wreck Reef at night |

Seasonal events add one special each (e.g. a Santa sailor). Robux and luck (behind the PolicyService gate, like the
wheel): Lucky Flare (15 min, x2 rarity luck for you) and Lucky Tide (15 min for the whole server, gold sky). Pity is
the same for everyone.

## F. One radial skill tree (player + survivors)

Full screen, opened from the left-menu Skills button. A dark sea-chart background, a compass rose at the centre
("You"), four coloured sectors spreading out to the corners like Valhalla's Melee / Ranged / Stealth. Paths wind
outward through small dots (minor nodes, +1–3%) to octagon badges (keystones: a new ability or a big jump).
Neighbouring sectors are joined by grey bridge nodes. **Updates add new outer rings and new branches at the rim**,
never by changing what is already there.

Currency: **Medals**, earned by rescuing (1 per 2 people, +1 for a gold grade), quests (+3), HQ levels (+5), the daily
chest. Minor nodes cost 1, keystones 3 (rings 1–2) or 5 (rings 3–4), bridges 4. Rings 1–4 ≈ 250 Medals ≈ the 17 h
track (tune). Cash goes to buildings and levels; Medals only to the tree. Robux never buys Medals or nodes. Reset is
free in the panel.

| Sector | Ring 1 | Ring 2 | Ring 3 | Ring 4 | Rim (updates) |
|---|---|---|---|---|---|
| **Captain** (you, your craft) | Throttle: speed +4% · Fins: swim +20% | Long Reach: pick-up +3 studs · Grip: tighter turns | Nitro: double-tap boost burst · Boat Call: Boat to me −20% | Bounty: call pay +10% · Golden Eye: Epic+ survivors on the map from any distance | Storm Rider |
| **Rescue** (Rescuers, Mechanics, Medics) | Tune-up: Mechanic cap +5% · First Aid: Medic cap +10% | Fast Launch: NPC trips −15% · Spare Parts: Boat to me cap −10% | Big Boat: NPC boat +2 seats · Recruiter: recruits +5% | Air Patrol: Pilots (Update 2) · Glow Up: Medics can raise an arrival's rarity | Deep Divers |
| **Crew & Luck** (survivors) | Bunks: +5 people · Lucky Flare: rarity luck +10% | Team Spirit: +5% with 3+ co-workers · Homecoming: offline cap 2 h → 4 h | Clover: traits roll twice, keep the best · Mentor: a Legendary trains one Common to Uncommon every 2 h | Big Family: +10 people · Golden Mayday: golden calls x2 | Celebrity Visits |
| **Industry** (Builders, Haulers, Fishers) | Strong Backs: builders carry 2 · Fresh Catch: fish Cash +15% | Hard Hats: base crew 2 → 3 · Hand Carts: Depot refill +50% | Double Site: two builds at once · Market Day: +1 stall slot | Night Shift: offline rate 0.15 → 0.25 · Golden Bricks: builds +20% faster | Lumberjacks, Miners |

Bridges: **Lifeguard** (Captain–Rescue: your craft +1 seat), **Welcome Home** (Rescue–Crew: each arrival pays a
little Cash), **Foreman** (Crew–Industry: +1% build speed per 5 people), **Salvage** (Industry–Captain: pick up
floating crates at sea, they go to the Depot).

Look and feel:
- States: owned (filled sector colour, glow), reachable (outlined, slow pulse), beyond reach (dim dots; keystone names
  stay hidden until a neighbour is owned, so every buy reveals something), rim (dashed "?" nodes for coming updates).
- Tap a node: a small card (icon, name, 1–3 word effect, Medal price, green button). Buying: light runs along the path
  from the owned neighbour into the node, the badge pops, the next nodes fade in with a ripple, the chime rises in
  pitch along a chain.
- Opens centred on your newest node; drag / pinch / wheel to pan and zoom; gamepad stick jumps node to node.
- Data: `SkillRules` nodes get `ring` + `angle` instead of `col` + `row`; a keystone lists its minor nodes as
  `path = { stat, amount, count }`, so the dense dots are generated, not hand-written. Polar layout in `TreeMath`.

The build tablet stays a top-down view of your island (no tree): tap a lot or building for its build/upgrade card.
docs/24 G-a2 (the build tablet as a tree) is dropped.

## G. Animation list (what makes the island feel alive)

- Every job above loops with a held prop (brick stack, crate cart, rod and fish, wrench and sparks, clipboard, axe,
  pickaxe) at a fixed work spot; money jobs pop "+$" when they pay.
- Builds: bricks arrive with builders and snap on with the BuildSeq bounce; on finish the crew cheers, confetti,
  the fence and scaffold fold away.
- Level-up: the add-on builds on, the building's sign gets one more star.
- Day/night: dusk walk home, lit windows, "Zzz" over the Bunkhouse; dawn walk back out.
- Idle: workers chat in pairs on the plaza, wave when the owner walks by, play volleyball, sit on the pier.
- Specials have their own idle (Pearl splashes on the pier, Bolt beeps, Nova floats in low gravity hops).
- Arrivals: rarity beam in the water, the blanket walk, a sparkle at the clinic when Dr. Coral promotes someone.

## H. Work packages (after the OK)

| WP | What | Notes |
|---|---|---|
| 29a | Layout: districts, new spots, freight quay + barge, merges | existing models moved, not reshaped; AD render loop |
| 29b | Building levels + HQ gate: `levels` per DockConfig row, UnlockTree reads the HQ level, save migration | build tablet: upgrade cards + green arrows |
| 29c | Depot + bricks: stock, barge, Haulers, builder carry loop, BuildTimer rate = min(carry, supply) | |
| 29d | Survivors v2: 6 rarities, traits, Hauler, specials, golden calls, pity, Album page | WorkerRules + roll |
| 29e | Radial skill tree: polar TreeMath, full-screen view, Medals, SkillRules rewrite, refund Cash spent on skills | replaces G-a1's list layout |
| 29f | Animation pass: job loops, day/night commute, idles | |
| U1 / U2 | Timber & Stone; Deep salvage + Canteen + Pilots | later updates |

## I. Owner decisions needed

1. Skills cost **Medals** (earned by rescuing) instead of Cash; Cash goes to buildings and levels.
2. Bricks are a **real limit** (an empty Depot pauses builds), not only a visual.
3. The **merges**: Pontoon + Crane → Harbour levels, Lifeboat slip → Boathouse Lv2, Helipad + Hangar → Air Station,
   Station → HQ Lv3.
4. The build tablet stays a top-down island (no build tree); the radial tree is only for player + survivors.

## J. Owner decisions 2026-10-27 (these win over A–I)

- Section I: all four approved (Medals, bricks are a real limit, the merges, the tablet stays a top-down island).
- Rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic.
- **No building ever sparkles** (no glitter, glow or gold-brick effects on buildings or construction sites).
- **Every survivor shows their name above them, coloured by rarity** (Mythic: a moving rainbow): in the water, aboard,
  walking and at work. **Click/tap a survivor** (ProximityPrompt for keyboard/gamepad) to see their properties: name,
  rarity, type, trait, work value, workplace, effect. Info only.
- **Empty start, no placeholders:** an unbuilt lot shows nothing (no paper blueprints, lot pads, flags, gardens, fixed
  decor, trees). At first nothing stands on land. The build stand (tablet) stands on the jetty head. The plate keeps its
  edge (beach step, quay edge), the jetty, the berth and the bridges.
- **The first build is free:** the Rescue Hut (HQ Lv1), and the tutorial's first beat teaches building with it (arrow to
  the tablet → the HQ card pulses → tap → watch the crew build it). The prize wheel arrives with the HQ (on the plaza).
- **Focus on tap:** tapping a skill node moves the camera to your rarest survivor of that node's type (Captain nodes:
  you; Crew & Luck nodes: your rarest survivor of any type); the tree fades so the world shows, the node card stays.
  Tapping a building card on the build tablet moves the camera to that building (or its lot).
- **Skill tree view (owner 2026-10-28, wins over F and "Focus on tap"):** the tree shows only nodes you own and nodes
  you can unlock next (no "?" tiles, no links to hidden nodes; a buy pops the new neighbours in) and opens zoomed to
  fit just those plus the centre (max zoom capped), easing out as more is revealed; tapping a node shrinks the tree
  into a bottom-left minimap and slides in a big card (icon, name, effect, Medal price button; minimap / X / B / Esc /
  empty tap restore it); Captain nodes never move the camera, the others focus your rarest survivor of the type; no
  looping or orange pulses, only one gentle pop and steady outlines.
- **Loading → play:** when the loading screen ends the camera tweens straight from the top view to the player. No orbit,
  no stop at the spawn point.
- **Walk-in buildings, no clutter (owner 2026-10-27):** you can walk into every building and object (wide openings,
  walkable floor, collision that keeps the doorway and interior open, never one box). Inside you see where the
  survivors work and what they get (e.g. the Depot: brick stacks on racks by colour, marked pick-up and drop spots,
  a clear walkway). No loose props on the floor; detail sits on walls, racks and counters.
- **Art:** new building art is made in Blender, Lego style, as layered meshes so the construction rise still works.
  Each asset gets an art-director score; it ships at > 8/10, at most 3 rounds (a 4th only if truly necessary).

## K. Build contracts (every builder codes against these)

K1 Survivors (attributes on every survivor Model, in the water, aboard and at home, and on the published workers
`ReplicatedStorage.Workers.<UserId>.<index>`): `SurvivorName` string, `Rarity` number 1–6 (Common..Mythic),
`Category` string (`Builder`, `Hauler`, `Gatherer` (shown as "Fisher"), `Mechanic`, `Medic`, `Rescuer`), `Trait` string
(`""`, `Speedy`, `Strong`, `Lucky`, `NightOwl`, `Cheerful`), `Special` string (`""` or the special's id), `Workplace`
string (DockConfig building key, `""` while waiting), `Job` (as today). One shared rarity table (name + colour per tier)
used by survivors and the prize wheel: `src/shared/Rarity.luau` (`Rarity.TIERS[i] = { name, color }`, `Rarity.MYTHIC = 6`).
Survivors roll when they spawn (so the tag shows in the water), on the server.

K2 Buildings: `DockConfig.Buildings[key].levels = { { cash, robux?, hq, effect?, piece? }, ... }` (index = level; `hq` =
HQ level needed). The HQ is the row `HQ` (5 levels; Lv1 cash 0). Save: `data.dock.levels[key] = n` (nil = not built).
`UnlockTree` answers: can I build/upgrade `key` to level `n` (HQ gate + `needs`), and what does the next HQ level need
(every building the current HQ level unlocks built at least Lv1). Merged rows: `Harbour` (Lv1 jetty is the start, Lv2
pontoon, Lv3 crane), `Boathouse` (Lv2 lifeboat slip), `AirStation` (helipad + hangar), `HQ` (Lv3 = the Station model).
New rows: `Depot`, `Bunkhouse`.

K3 Skills: `SkillRules.nodes()` returns every node, keystones and generated minor nodes:
`{ id, sector ("Captain"|"Rescue"|"Crew"|"Industry"|"Bridge"), ring (number, may be fractional), angle (degrees: offset
-36..36 inside the sector, absolute for Bridge), name, icon, medals, needs = { ids } (any one owned), effect = { kind,
amount }, focus ("Captain" | a K1 Category | "Any"), keystone = bool, soon = bool }`. Minor nodes: id
`<keystone>_m<i>`, between the keystone and its first need. Sector centres: Captain 315°, Rescue 45°, Crew 135°,
Industry 225° (0° = up, clockwise). Save: `data.medals` (number), `data.skills` (owned ids). Medals: 1 per 2 people
rescued, +1 per gold grade, +3 per quest, +5 per HQ level, daily chest +1–3.

**K4. Depot and bricks (W5, section D).** `src/shared/DepotRules.luau` (pure, tested, used by the server and the
pacing sim): `cap(depotLevel)` loads the Depot holds (Lv1 20, Lv2 40, Lv3 80; 0 with no Depot);
`BARGE_PERIOD = 60` s; `bargeLoads(depotLevel, haulerUnits)` loads one mooring puts in the Depot (no Haulers: the
barge crew drops 2; Lv2 doubles it); `loadsFor(work)` = `ceil(T / 10)` with T the build's `BuildTimer.work` seconds;
a site advances one load per builder trip, so its rate is min(how fast builders carry, Depot stock + refill). No
Depot built yet: builds run on the barge crew's drop alone, never blocked forever. Save: `data.depot = { stock }`.
Island plot model attributes (server -> clients, next to the `Site*` ones): `DepotStock` (loads now), `DepotCap`,
`BargeNext` (`Workspace:GetServerTimeNow()` of the next mooring), `HaulRate` and `CarryRate` (loads per minute; they
pace the walk loops), `SiteWaiting` (true while the site waits on an empty Depot). `SiteRate` stays the site's
effective rate. Visuals are client-side and read only these: the barge sails in to `ATT_BargeMoor` at `BargeNext`,
stays 20 s and leaves; Haulers loop barge -> `ATT_DropOff_*`; Builders loop `ATT_PickUp_*` -> site with a brick
stack over their heads; the pile's `Stack_1..4` show `DepotStock / DepotCap` in quarters; an empty-crate icon over
the pile while `SiteWaiting`.
