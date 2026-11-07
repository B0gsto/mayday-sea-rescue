# 00 · Mayday: Sea Rescue: the design

Last rewrite: 2026-11-07. This is the one current design; where another doc disagrees, this wins, and the code wins
over both. Details: [30 the boat loop](30-boat-pivot.md), [31 the map, zones and fuel](31-layout-and-fuel.md).
Open work: [NEXT.md](NEXT.md). Owner rules: `CLAUDE.md`.

## 1. What it is

A Roblox rescue game for kids 8-15, many on phones. You drive one boat out to sea, pick up survivors, press **Go
back**, spend the Cash on the next boat level, and go out again: faster, bigger, farther. Six players per server, each
with a plot on a ring of Lego islands. Upgrading the boat is the game; the island is a quiet side.

## 2. The loop

**Go out -> rescue -> Go back -> upgrade -> go out farther.**

| Step | How it works |
|---|---|
| Go out | You start on your boat in your plot's Upgrade Station bay, bow to the open sea. |
| Rescue | Drive near a survivor; the pick-up eases you to boarding speed and they climb on by themselves. Room per level (1 to 14). |
| Go back | One button (R, gamepad R3, touch) while away from home. The boat turns (0.8 s), then drives itself home along a route clear of islands and swings into the station bay, about 5 s after the press from anywhere. Survivors hop off, pay lands, workers walk off. |
| Upgrade | At the station board, or from the on-boat Upgrade panel anywhere (Next chip: tap, F, gamepad Y). Cash only, one option, grey when short. |

No docking, parking, walking or Launch prompt in the loop. You can't step off the boat at open sea (`Boat/SeaExit`):
only at home, in a station bay, beside a deck or shore, or in shallow water. Driving home by hand still works.

What makes a trip a choice ("one more, or go back?"):
- **Sea zones:** five rings round the lagoon; farther out = rarer survivors and more free-roam pay (31).
- **Fuel:** a tank sized by level; past your boat's rated zone it burns x5, then x25. Empty = limp, then ride home (31).
- **Rescue run:** survivors delivered in a row multiply delivery pay up to x2; a pirate hit ends it (30).
- **Pirates:** with survivors aboard in zone 2+, a pirate boat hunts you; a ram knocks one survivor off (30).

## 3. The boat: 50 levels

One boat, one ladder (`shared/BoatLevels`). Every level adds a named, visible piece, more speed and a level-up moment
(lift, spin, brick burst, slam). Each stage is a new hull.

| Levels | Hull | Speed (studs/s) | Room | Fuel rating |
|---|---|---|---|---|
| 1-10 | Jet Ski | 80 -> 430 | 1 -> 3 | Kelp Banks (zone 2) |
| 11-20 | RIB | 450 -> 620 | 4 -> 5 | Coral Drift (3) |
| 21-30 | Lifeboat | 640 -> 800 | 8 -> 9 | Storm Reach (4) |
| 31-40 | Hydrofoil | 815 -> 950 | 10 | Wreck Abyss (5) |
| 41-50 | Rocket Cutter | 965 -> 1100 | 12 -> 14 | Wreck Abyss (5) |

Hydrofoil and Rocket Cutter are placeholder Parts on the RIB and Lifeboat hulls for now; new concepts go to the owner
first. Prices, pieces and the station: 30.

**Pacing** (`tests/Pacing.spec.luau`, 2026-11-07): L2 at 0.8 min, L5 at 2.9 min, L11 at 12 min; L20 1.4 h, L30 4.2 h,
L40 8.6 h, L50 15.0 h (857 trips). L2-L5 take one trip each.

## 4. The first session

1. Join: the free Rescue Hut is granted at load and you start on the jet ski in a cold open, three swimmers fanned off
   your cove.
2. The first delivery lands in the station bay and pays exactly L2. One arrow on Go back, taught once.
3. Upgrade to L2, one arrow out to sea, out again. No pirates until the tutorial ends.
4. After L2 and a trip home: the free spin, then the Next chip leads with the next boat level.

The HUD stays quiet (side menus, Robux chips) until boat L2 or 5 rescues (`Layout.quietHud`). The island's pulls (goal
board, build arrows) stay quiet until boat L5 (`NextGoal.TREE_FROM_BOAT`). Below L5 any rescue pays at least the next
level (`BoatLevels.earlyPayFloor`). Funnel: Joined, AtSea, FirstBoard, FirstDelivery, FirstUpgrade, BackOut, FirstSpin,
BoatL3, BoatL5, BoatL11.

## 5. The world

Details and numbers: 31.

| Place | What it is |
|---|---|
| Hub | A small beacon atoll in the centre lagoon: a landmark, not an island. |
| 6 plots | Lego-baseplate islands (640-stud plates) on a ring 860 studs from the centre, joined by walkable bridges. Each has an Upgrade Station with a bay. Players are spread round the ring (`Marina.assign`). |
| Sea zones | Shallows, Kelp Banks, Coral Drift, Storm Reach, Wreck Abyss: rings from the centre, shown by water colour, fog, buoys, map circles and a crossing banner. No wall. |
| Destinations | Outer islands (Skerry, Puffin Isle, Gannet Rock, Mermaid Lagoon, Wreck Reef, The Arches, Penwyn) plus three sector hotspots (Gull Stacks, Wreck Shoal, Storm Light), so every direction has a goal. |

## 6. Your island (secondary)

Still in the game, but the boat comes first. Built from a tablet at the build station (top-down view, Lego build
animation). Buildings and the unlock tree are data (`Config/DockConfig`, rules `shared/UnlockTree`): Rescue HQ (Hut ->
Coastguard HQ), Harbour, Depot, Workshop, two sea plates, Bunkhouse, Fish Shed, Boathouse, Boat Yard, Clinic, Rescue
Boathouse, Lookout Tower, Air Station, Sub Pen, Trophy Hall, Lighthouse, decor. Island tree alone: about 15 h
(`tests/Pacing`); it shares the Cash purse with the boat ladder.

- **Workers:** each delivered survivor gets a category (Builder, Hauler, Gatherer, Rescuer, Mechanic, Medic) and a
  rarity (rolled from the zone they were found in), walks to the matching building and works there.
- **Skills:** one radial tree (Captain, Rescue, Crew, Industry), paid in Medals (`shared/SkillRules`).
- **Helicopter and submarine** stay as they were (40,000 and 64,000 Cash behind their buildings); they ignore boat
  levels but share the boat's fuel tank and rating.
- **Prize wheel (Deep Spin):** an in-world wheel on your island; a spin breaks the ground and dives to the Deep, one
  spin per trip, auto-surfaces. Free spins: 1 a day and 1 per 10 rescues; odds and pity shown.

## 7. Retention

- **Daily streak:** one Collect prompt on join (no reward chests). The day's Cash is the bigger of a flat amount (100 ->
  900 over 7 days) or a share of the next boat level's price (20% -> 60%, capped at 30,000) (`StreakRules`).
- Offline pay and welcome-back show in the same join prompt.
- Badges and leaderboards count people rescued.

## 8. Money (Robux)

- **Boats are looks only.** Paid and won boats are designs with no stats, worn on your level's stats. Levels are never
  sold. Old saves never go down: owning the RIB starts you at L11 or more, the Lifeboat at L21.
- Passes: 2x Cash, VIP, Quick Launch, Starter Kit, cosmetics. Products: Cash packs, spins (Spin1/5/15), Finish Now on
  island builds. No fuel product.
- Paid spins only at the wheel, odds and pity shown, PolicyService-gated. The player opens every prompt.
- Details: [04-monetization.md](04-monetization.md).

## 9. UI and feel

- **No choice UI in gameplay.** Exceptions: NPC talk (numbered replies) and the owner-asked upgrade panel (one option).
  Menus only outside gameplay (left icon buttons: Shop, Quests, Album, Pet, Crew, Skills, Settings, Map, Boat, Home).
- **Show, don't tell:** icons and 1-3 word labels, no paragraphs. Every action on keyboard, touch and gamepad.
- Nothing flashes or pulses orange; no outline rings round HUD buttons (one pop, a bounce, a red badge or a camera focus
  instead).
- Roblox simulator style UI (chunky outlined font, gradient cards, red X, green price buttons). Screen sprites are
  Claude SVG (`art/source/ui/`).
- Third-person camera. Voices only for NPCs. One companion (Bosun the dog or one pet).
- New things are Lego-style; existing finished assets keep their look.

## 10. Cut

Gone (kept in git tag `pre-hub-cut` and `docs/archive/`): the town (Port Haven), cars, the phone, the dispatch radio,
care/CPR and grab steps, first person, the seaplane, land calls, the NPC racer, the forest hub island, ranks and
Reputation, buying hulls with Cash, the zone glow curtain, parking and the Launch prompt.

## 11. How we build

Checks: `~/RobloxProjects/tools/check.sh .`. Studio driver `tools/studio/smoke.py`, playtests `tools/studio/play.py`
(Opus only). Publish from Studio: `python3 tools/studio/publish_studio.py` (test), then `--launch`. Module ownership:
`CONTRACT.md`. Art: design concept before Blender, Blender via MCP. VFX: [26-vfx.md](26-vfx.md).

## History

Older design docs, moved to `docs/archive/` on 2026-11-07:
- `01-game-canon.md`: names, tone, characters for the island-tycoon design.
- `02-core-loop-and-mechanics.md`: the call-and-build loop before the boat pivot.
- `03-progression.md`: the unlock-tree economy (the tree still runs from `DockConfig`).
- `10-world-and-map.md`: the forest-hub map; the ring is now in 31.
- `15-retention-and-new-players.md`: the island-first first session.
- `23-dock-and-core-loop.md`: the 2026-10-25 dock redesign log (a)-(q).
- `24-flex-builders-tutorial.md`: builders, open islands, spin wheel, island tutorial (2026-10-26).
- `25-island-skills-survivors.md` + `25-visuals.html`: HQ levels, buildings, radial skill tree (2026-10-27).
- `27-expansion.md`: sea plates, era ladder, the Deep (2026-10-29).
- `28-perfect-pass.md`: the 2026-10-31 art quality pass.
- `29-sea-zones-and-runs.md`: zones, run, pirates; merged into 30 and 31.
