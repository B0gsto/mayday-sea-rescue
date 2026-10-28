# 00 · Mayday: Sea Rescue — the design (canonical)

Last rewrite: 2026-10-25. **This file is the source of truth.** Every other doc must agree with it; where one
doesn't, this wins. The change log that got here is docs/23 (a)–(n). Old designs (Port Haven town, cars, the
phone, the dispatch radio, care/CPR steps, first person, the seaplane, land calls, the NPC racer) are gone; they
live in git tag `pre-hub-cut` and in `docs/archive/`.

## 1. One line

A Roblox coastguard game for kids 8–15 (many on phones): **tycoon-like** (your island grows), **exploration and
adventure** (islands, wrecks, a wild forest hub, quests), **played with friends** (ride together, crew up, visit
each other's islands). 6 players per server.

## 2. The world

| Place | What it is |
|---|---|
| **6 player islands** in a tight ring (centres 470 studs from the centre, ~80 studs of water between neighbours) | One per player. A flat **Lego baseplate** (green stud plate, berth notch facing the open sea), no terrain. Your plot: everything you build stands here, and your neighbours' empires are right next to it. Unclaimed ones are bare plates with a jetty. You spawn on your own island. |
| **Ring bridges** | Short walkable bridges join each island to its two neighbours; boats pass under. No cars. |
| **Centre lagoon** | Open water inside the ring; no island. |
| **Outer sea** | Exploration and rescues: Skerry, Puffin Isle, Gannet Rock, Wreck Reef, the Arches, Mermaid Lagoon, Penwyn; wrecks on the seabed; open sea. Calls spawn here. |

(WP-27, docs/23 (p): the old middle forest island is gone. At ~380 the 320-stud plates would overlap, so the
centres sit 470 out and the nearest plate corners are 80 apart.)

## 3. The loop

**Your island → a call → sail out → pick up → bring them home → build your island → farther calls, bigger craft.**

- **Calls** arrive as a pager card + flare + pin + beep (no radio). Calls 1–2 spawn just off your own cove; later
  calls out among the outer islands, farther as your craft grow (reach = the best craft you can launch). Pay grows with
  distance (from 1,500 studs, cap ×4). Kinds: swimmer, drifting craft, capsized ferry (big call), rip current,
  sinking vessel, vessel fire, wildlife rescue, diver at a wreck (submarine only).
- **Pick-up is simple:** an orange ring on the water marks each survivor; inside it your craft eases to boarding
  speed by itself; they swim over and climb aboard in view, "+1". Full craft shows on its seat pips. Helicopter
  winches from a hover; submarine picks up divers on the seabed.
- **Drop-off:** your own berth (a generous zone around your jetty). Calls never fail: a slow rescue just earns a lower
  grade (bronze) and less pay.
- **Quests:** quest-giver NPCs sail in on small boats and moor at your island's quest pontoon with a "!"; a quest
  tablet beside it lists offers and your active quest (or talk to the NPC: camera zoom + numbered replies, voiced). Find, deliver, salvage (sub),
  special rescue, and chains that unlock a unique building for your island (e.g. a lighthouse). One new quest a
  day per NPC; a chain's next step unlocks as soon as the previous one is done.
- **Free-roam swimmers** between the islands for anyone sailing around.

## 4. Your island (the tycoon)

- Start: a bare plate, a jetty, a jet ski.
- **Build station:** a Lego builder's yard with a **tablet** on a stand. Using it moves the camera to a top-down
  view of your island; a bar of cards shows what you can build (Cash, or Robux; a locked card shows a padlock and
  "Needs: X" with X's drawing, tapping it jumps to X); every spot not built has a paper blueprint (grey with a chain
  while locked); the chosen lot pulses as a
  flat outline (never a 3D preview); buying plays a **Lego build**: bricks drop in bottom to top with a bounce and
  a snap, builders standing by. (Today a blueprint table on the jetty does this; the tablet build mode replaces it,
  in progress, WP-14d.)
- What you build: the **unlock tree** (§6): pontoon (2nd berth, lamps, rescue board), workshop, boathouse (boat
  board, paint booth), lookout tower, crane (no relaunch wait), lifeboat slip, helipad, hangar, sub pen, station
  (beacon), trophy hall, worker buildings (workshop, fish shed, boat yard, rescue boathouse, clinic: plain Lego
  for now), quest-chain buildings, decor.
- **Your people:** survivors you rescue get a category (Builder, Gatherer, Rescuer, Mechanic, Medic) and a rarity;
  delivered home they walk to the matching building on your island and work there (faster builds, passive Cash,
  NPC rescues, faster craft, bigger payouts). Small capped offline earnings. (In progress, WP-26; replaces the crew
  lineup.)
- **Flex:** everything is visible to the server; the island with a Station and the most people rescued gets a gold
  beacon.
- **New things are Lego-style** (chunky bricks, bright colours, studs). Existing finished models keep their look.

## 5. Craft

Jet ski (free, 1 seat) → RIB (boathouse) → Lifeboat (lifeboat slip) → Rescue helicopter (hangar) and Submarine
(sub pen). Robux boats (boathouse): Storm Runner, Tidewalker, Riptide X, Gilded Gull. Choose a craft at the
boat board in your boathouse; "Boat to me" brings yours to you (60 s cooldown; a hired Mechanic cuts it to 42 s;
Quick Launch removes it). A free craft bought early with Robux (RIB, Lifeboat passes) handles the same as the earned
one. The Robux-only boats are their own, faster boats on the RIB's call reach: speed is sold, skill never is.

## 6. Progression and economy

No ranks and no Reputation. Progress is a **linear unlock tree** on your island: each building lists what it needs
("Needs: Crane"), craft unlock through their building (RIB ← Boathouse, Lifeboat ← slip, Sub ← Sub pen, Helicopter ←
Hangar), and call reach follows the best craft you can launch. Cash (from calls, quests, workers, the daily streak
reward) is the only currency; it pays for buildings, craft, decor and cosmetics. Free players reach everything
(pacing sim in `tests/`: the whole tree in ~17 h of play). The tree is one config (`DockConfig.Buildings`, rules
`shared/UnlockTree`), so new content is a new row. Badges and leaderboards count people rescued. docs/23 (q), (i).

## 7. Money (Robux)

Robux can skip the Cash for anything whose prerequisites you already have, never the order of the tree (and never skill). Passes:
2x Cash, VIP, Quick Launch, Starter Kit, Robux boats and craft, cosmetics; products: Cash packs, boosts, Storm
Summons, island buildings (once their prerequisites stand), day passes. Paid random Sea Chests come after the first public launch (cosmetics only, odds shown, pity, one Cash chest).
No pressure, no timers on offers, the player opens every prompt. Details: docs/04.

## 8. UI and feel

- **No phone.** A left column of big square icon buttons (Shop, Quests, Album, Companion, Crew, Settings, Boat to
  me) opening centred panels; a full map on M. Roblox simulator style: chunky rounded bold font with a black
  outline, bright gradient cards, thick borders, red X, green price buttons, a subtle Lego stud texture
  (in progress, WP-23).
- **Show, don't tell:** icons and 1–3 word labels; no paragraphs; no choice menus in gameplay (exceptions: NPC talk,
  the build tablet, in-world counters/boards). Every action on keyboard, touch and gamepad.
- Third-person camera only. Voices only for NPCs. One companion (Bosun the dog or one pet).

## 9. How we build

Builders: multiple DeepSeek V4 Pro agents (Opus reviews); 2D art via Gemini; Blender models via Opus/DeepSeek per
art/bench. Placeholders first, gameplay never waits on art. Checks: `~/RobloxProjects/tools/check.sh .`. Publish:
`python3 tools/publish.py` (private test place, ~2 min). Module ownership: `CONTRACT.md`.
