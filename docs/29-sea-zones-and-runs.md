# 29 · Sea zones, rescue runs and pirates (owner 2026-11-03)

Owner: "go get rescuers, go back" is boring. Wants: clearly visible circles, go further = new biomes and better
survivors ("steal an egg type"), pirates or similar to avoid, no chosen survivor in the tutorial.

Rules that still hold: no procedural rescue steps (auto-board stays), no choice UI, show don't tell, nothing flashes,
nobody dies, kid-safe (no guns), every action on keyboard, touch, gamepad. Every effect has a sound. Numbers are `-- tune`.

## A. Tutorial: no chosen survivor
The cold open spawns 3 swimmers fanned off your cove (about 40 degrees apart, same distance as today). None gets the
special white ring: all get the normal pick-up ring and wave. The first one you bring home completes the cold open
(a Builder, as today). The other two roll as free roam (no pity, no Builder) and leave when the cold open ends, so neither
sits in the cove lane or fills the seat on the next call; the cove-mouth spawns take over. Later tutorial calls are unchanged.

## B. Sea zones: five circles round the lagoon
Measured from `RingLayout.Center` (origin/main: islands at 860 + 320 radius, so the Shallows hold all six and the outer islands fall in zones 2-5). New pure module `shared/Calls/SeaZones.luau` (Lune-tested): the table and
`zoneAt(pos)`. Jet ski may go anywhere: the risk is the trip home, not a gate.

| # | Zone | Radius | Water | Rarity % Common..Mythic | Free-roam pay |
|---|---|---|---|---|---|
| 1 | Shallows | 0-1600 | bright teal | 78/18/4/0/0/0 | x1 |
| 2 | Kelp Banks | 1600-2800 | green teal | 55/28/13/4/0/0 | x1.25 |
| 3 | Coral Drift | 2800-4000 | violet blue | 32/33/22/10/3/0 | x2 |
| 4 | Storm Reach | 4000-5200 | steel blue, overcast | 15/28/30/19/7/1 | x3 |
| 5 | Wreck Abyss | 5200+ | near-black indigo | 5/15/30/30/16/4 | x4 |

Pay tuned down from x1.5 / 2.5 / 4 / 6 (tests/Pacing: a full RIB or lifeboat made 1.8-1.9x the calls, now at most
1.3x). Better crews also rushed the tree, so Gatherer 3 -> 2.3 and Rescuer 40 -> 31 Cash per unit (with the run stacked).

A survivor's rarity rolls from the zone they spawn in (`WorkerRules` `opts.weights`; pity, specials and Crew luck
unchanged). Call pay keeps its own distance rule. Free-roam spawns must cover every zone, so far water is worth the
trip, and a tiny number of Legendary+ scenes can be seen from far by a tall rarity-coloured light column.

Clearly visible, in order of importance:
1. **World line:** a client-pooled line of tall Lego buoys in the zone colour with a soft vertical glow curtain between
   them, only near the player (pool about 24). Vertical, so no coplanar sea faces.
2. **Water:** sea tint and fog ease to the zone colours over about 2 s when you cross.
3. **Map:** coloured circles on the full map and minimap.
4. **Crossing:** one banner pop: zone name + best rarity gem + a sound. Once per crossing, respects reduce motion.

## C. Rescue run
A run counts survivors delivered home in a row. Multiplier on delivery pay: x1, x1.25 at 3, x1.5 at 6, x2 at 10 (cap).
It ends 75 s after your last pick-up or delivery, or when a pirate hits you. A small HUD chip shows x and a timer. It
pays at delivery, so "one more, or go home?" matters. **Pick-up boost:** each pick-up gives +25% top speed for 3 s
with a wake effect and sound. Built: `shared/RescueRun`, `RescueRunService`, `UI/RunChip`; pay reads the x before its own
delivery counts (the x on the chip when you arrive); no run counts on the new player's stripped HUD (flat tutorial pay).

## D. Pirates
**Changed by docs/30 section 5:** no chase home; rams hit during collecting and cancel a Go back charge.
Cartoon Lego pirate boat (placeholder Parts first). One per player at most, 2 per server per zone band budget.
- Only with survivors aboard, in zone 2+, after the first 5 saved calls (no tutorial). Chance rises with zone and load.
- Spawns 300+ studs away, off to the side, then steers an intercept course at 0.92x your craft's top speed, so
  fast Robux boats still get cut off and a boost or an island gets you away. One horn + one pop + edge arrow, no flash.
- A ram within reach knocks one survivor into the water (they keep their roll, you can turn back) and ends your run.
  Then the pirates sail off. They give up after 40 s or at the Shallows line.
- Home with no hit while chased: +25% pay and a small burst.
- Server-steered, no physics, no combat, culled and cleaned up.

## Art
Design before Blender: concepts in `art/source/concepts/` (HTML), AD first, Blender only for approved ones.
