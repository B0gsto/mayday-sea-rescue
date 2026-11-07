# 01 · Game canon

Last rewrite: 2026-10-25. This file is the canon for names, tone, world and characters. `docs/00-design.md` is
the source of truth; if this file disagrees, 00 wins. Mechanics: `docs/02-core-loop-and-mechanics.md`. Numbers:
`docs/03-progression.md`. Prices: `docs/04-monetization.md`. Store: `docs/07-store-page-thumbnails-and-trailer.md`. Retention: `docs/15-retention-and-new-players.md`. The
history that got here is `docs/23-dock-and-core-loop.md`.

## 1. Identity

| | |
|---|---|
| **Name** | Mayday: Sea Rescue |
| **Pitch** | Grow your own rescue island. Answer mayday calls. Bring everyone home. |
| **Fantasy** | A kid runs a small coastguard station: fast boats, a big sea, people who need help. |
| **Platform** | Roblox, phone first. Keyboard, touch and gamepad. |
| **Genre** | Rescue adventure + island tycoon. Stylised, chunky, Lego for new things. |
| **Players** | 6 per server, each with one island. |
| **Audience** | 8–15, many on phones. Reading-light, warm, never grim. |
| **Session** | 20–30 minutes; one call chain, a rank, a build, a quest. |
| **Rating** | Roblox All Ages. No blood, no gambling, no paid skill. |

## 2. Pillars

1. **Your island grows.** Every rescue pays for something you can see from the water: a pontoon, a boathouse, a
   hangar, a beacon. This is the tycoon spine.
2. **The rescue reads at a glance.** Flare, ring, seat pips, "+1". No paragraph explains a call, and no menu
   chooses an action. The player drives, pulls up, and the survivor climbs aboard.
3. **The sea is worth exploring.** Seven outer islands, wrecks below, fog that lifts as you walk the hub, quest
   camps, stickers, a lighthouse at the end of a chain.
4. **Friends make it louder.** Six islands in one harbour, bridges to walk, a crew to ride with, a big call that
   the whole server answers.
5. **Show, don't tell.** Icons and one to three words. NPCs talk; nothing else does.
6. **Fair and warm.** Every rank, island, building, call and free craft is earnable. Calls never steal from each
   other. Nobody is hurt; a late call fails safe.

Every feature serves at least one pillar. If it serves none, it is not in the game.

## 3. What Mayday is not

- Not a town or role-play game. The hub is a wild forest with six camps, not a high street. There are no houses
  to decorate, no jobs behind counters, no cars.
- Not a military simulator. Ranks are rescue grades, not command. Nobody carries a weapon.
- Not grim. There is no blood, drowning, burning or panic. "Fire" is smoke and orange light; the crew is out.
- Not a menu game. Gameplay actions happen in the world. Menus belong to the left-button panels and the build
  tablet. NPC talk is the numbered-reply exception.
- Not pay-to-win. Money buys time, looks and server fun, never a better grade or promotion.
- Not a gambling product. Sea Chests, when they ship, are cosmetics only with odds shown.
- Not a photoreal game. The coastguard world is bright, readable and toy-like. New builds are Lego; finished
  models keep the look they were made in.

## 4. The world

| Place | What it is |
|---|---|
| **The hub** | A wild forest island, about 800 studs across, that the coastguard has only just reached. Rough trails, frontier camps, a lookout-hut HQ with the call board, a market stall that serves as the shop counter, the harbourmaster's shack, a campfire stage, the rescuer monument, a visitor jetty and a drop-off quay. Terrain. |
| **Six player islands** | One per player, on a ring about 1,100 studs out. A flat Lego baseplate (green stud plate, berth notch for a boat and a sub). Unclaimed plates are bare, with a jetty. |
| **Six suspension bridges** | Hub to each island. Walkable. High enough for every boat and the helicopter to pass under. No roads, no cars. |
| **The outer ring** | Skerry, Puffin Isle, Gannet Rock, Wreck Reef, the Arches, Mermaid Lagoon and Penwyn. Beaches, rocks and shallows for free-roam rescues; wrecks on the seabed; open water beyond. |
| **The map** | Radius about 7,000 studs. Calls stay inside the reach of your rank, so the edge is for exploring, not for commuting. |

The sea is calm by default. The only storm is one a player calls with a Storm Summon (a paid server event,
`docs/04-monetization.md`); natural storm cycles are retired. Weather effects for that event are in progress.

## 5. Characters

### Bosun

A brown and white rescue dog. Bosun wears a life ring, rides on the jet ski and the RIB, and is the default
companion. The companion slot can hold Bosun or one pet; Bosun is the face of the game.

### The six quest givers

| Name | Camp role | Voice / cast | What they ask for |
|---|---|---|---|
| **Old Maud** | Passenger | Hazel | Her dog Biscuit, then a lost satchel. |
| **Tam** | Boater | Patrol | A crate for the Gannet Rock keeper, then Penwyn's post. |
| **Captain Rook** | Boater | Barnaby | A ship's bell and a sea chest, both below, both need the submarine. |
| **Nell** | Passenger | Parent | Two swimmers overdue at Wreck Reef and the Arches; both are calls. |
| **Keeper Ives** | Boater | Informant | Glass, oil and a lens for the old lamp; the chain ends in a lighthouse blueprint. |
| **Pip** | Passenger | Teen | A kite from Mermaid Lagoon and lunch for Dad on Skerry. |

Each has a camp on the hub, a pin, and one quest a day. They speak in short voiced lines and numbered replies;
the player never picks a dialogue tree.

### The player

A new coastguard recruit, dropped at the hub visitor jetty with a jet ski and a bare island. No family, no
backstory, no voice. The rank ladder is the character arc.

## 6. Quests and story

Thirteen quests, six givers, one a day per giver. The kinds are **find** (pick it up on an outer island), **deliver**
(carry it from the camp to a drop spot), **salvage** (submarine, from a wreck) and **rescue** (a call in a named
zone, then bring the survivor home). Each returns to the giver.

- One chain matters: **Keeper Ives** asks for glass, then oil, then the lens (three days). The last quest unlocks
  the **lighthouse blueprint** for the player's island.
- Everything else is a warm errand with a joke. No quest gates a rank, a craft or a call.
- Quest pins are in the world and on the map. The quest panel is a list of pins, not a story bible.
- No cutscenes. Talk zooms the camera in, plays a short voiced line, and shows numbered replies.
- The story never blocks play. A player can ignore every NPC and still reach Admiral.

## 7. Tone

1. **Nobody dies or is hurt.** People are stranded, tired, cold or late. The rescue is the fun; the danger is
   never shown in detail.
2. **A late call fails safe.** "Too slow" costs most of the pay, not the survivor and not the player's Cash stack.
3. **The player never loses progress.** No dropped rank, no lost craft, no stolen call.
4. **Warm and funny.** Bosun steals a sandwich. Pip's dad forgot his lunch. Captain Rook is dramatic about a bell.
5. **Heroic, not military.** "Coastguard" means rescue, not authority. No guns, no sirens as weapons.
6. **Real signals, simplified.** Mayday, flares, life rings and channel 16 language can appear as flavour; the
   mechanics stay ring-and-pick-up.
7. **Readable first.** A phone player must understand a call in one look. Big icons, one to three words.
8. **Lego for new things.** New buildings and props are chunky bricks with studs and bright colours. Boats,
   characters and the hub keep their finished look.
9. **One game for everyone.** The same calls, rules and island for a free player and a paying one. Third person
   only; no first-person cockpit.

## 8. Signature features

| Feature | What the player feels | Status |
|---|---|---|
| Hub forest + six Lego islands + bridges | A harbour that is theirs, with friends next door | Live |
| Mayday calls (pager, flare, ring) | A clear, exciting job anywhere on the water | Live |
| Simple pick-up, helicopter winch, submarine dive | The rescue itself is the toy | Live |
| Dock levels, hangar, sub pen, lighthouse | The island visibly grows | Live |
| Ranks Recruit to Admiral | A long, legible ladder | Live |
| Quests from six islanders | A reason to walk the hub and sail the ring | Live |
| Album, fog and stickers | Exploration that remembers | Live |
| Daily streak reward (join prompt) | A gentle reason to come back | Live |
| Crew hiring | A living station | In progress (WP-15) |
| Tablet build mode | Lego building, not a menu | In progress (WP-14d) |
| New phone-free UI | The Roblox simulator look | In progress (WP-23) |

## 9. Retired design

These were part of the old game. They are not canon, not planned, and must not appear in new docs, store art or
copy. The old build is preserved at git tag `pre-hub-cut`.

| Retired | Replaced by |
|---|---|
| Port Haven town, shops, houses, town square | Wild forest hub with six frontier camps |
| Cars, roads, garage, vehicle upgrades | Boats, bridges and walking |
| Phone, phone apps, phone shop | Left column of icon buttons and centred panels |
| Dispatch radio and voice chatter | Pager card, flare, pin and beep |
| Care steps, CPR, vitals, medical gear | Ring pick-up; survivors climb aboard |
| Certifications, gear tree, skill points | Rank plus Cash; paid craft skip the wait, not skill |
| First-person cockpit and photoreal art | Third-person chase camera; stylised Lego for new things |
| Seaplane, land calls, mainland | Outer islands, wrecks and open sea |
| NPC racer, race courses, time trials | Free-roam calls, big ferry call |
| Operations, tasking cards, debriefs, cold open | One call at a time, ring, drop-off |
| Natural storms, storm seasons, storm zones | Calm sea; Storm Summon event (in progress) |
| Port Haven lighthouse relight zones | Keeper Ives chain unlocks a lighthouse on your island |
| Animal sanctuary, pet adoptions, rotating stock | Wildlife calls; Bosun or one pet companion |
| Challenges, daily/weekly contracts, rerolls | Quests, daily streak reward, Album |
| Leaderboards, trophies, badges as a ladder | Rescuer monument, trophy hall, badges as flavour |
| Season pass, Season Logbook, seasonal events | Base game plus quests and Service Stars |
| Private servers, gifting, ads, subscriptions | Not part of the design |
| Paid Rep, 2x Rep, Sea Time, Fast-Track | Cash and cosmetics only; Rep is earned |
| Signature vehicles, vehicle tiers, gear stats | One handling model; paid boats are alternatives |

## 10. Glossary

| Term | Meaning |
|---|---|
| **Call** | One rescue job: pager, flare, ring, survivors, drop-off. |
| **Survivor** | A person, animal or diver in a call. Counts as one seat. |
| **Big call** | The capsized ferry. Public, server-wide, four or more survivors. |
| **Berth** | The boat notch on a player island. Drop-off point. |
| **Hub quay** | The shared drop-off on the hub. |
| **Reach** | The farthest call your rank can be offered, 2,000–5,500 studs. |
| **Grade** | Gold, Silver or Bronze from time taken. Multiplies pay. |
| **Rep** | Rescue reputation. Rank currency. Never sold. |
| **Cash** | Soft currency. Craft, buildings, crew wages, cosmetics. |
| **Dock level** | The main island upgrade, Lv1–Lv5. |
| **Crew** | Up to four players riding together for a pay bonus. |
| **Service Star** | Endless post-Admiral level, every 30,000 Rep. |
| **Blueprints** | Quest-chain buildings: the lighthouse. |
| **Storm Summon** | A paid, player-started storm event. In progress. |
