# 24 · Owner feedback 2026-10-26: feel, builders, open islands, spin wheel, tutorial

Owner: "the island looks claustrophobic, I don't know how to get people to work or where I see them work,
everything is houses and barns. We need diversity, the flex element, RNG spin wheel for pets, boats, vehicles,
make it flex and nice. Remove the slowing down on jet skis, it is fine just to go next to the survivor. Better
handling. Better core loop. Builders: any build takes time, every builder present cuts the time, and it looks under
construction. Build a tutorial. Refine progression."

Rules that still hold: CLAUDE.md (no choice UI in gameplay, show don't tell, every action on keyboard/touch/gamepad,
new things Lego-style), docs/00-design.md, CONTRACT.md. This doc wins over docs/00 where they differ (docs/00 gets
updated when the work merges).

## A. Jet ski: no slowdown, better handling

- Pick-up = drive next to the survivor. A craft with room that passes within the pick-up reach of a survivor takes
  them at ANY speed and tilt: they leap/climb aboard (short tween onto a seat, "+1"), no hold time. No ram/knock-away
  for boats. The orange ring stays as the "drive here" mark, sized to the reach.
- No automatic braking: `PickupRingController.Assist` no longer cuts throttle (the small helm nudge may stay).
  Helicopter winch and submarine rules are unchanged.
- Handling (jet ski first, then RIB and the Robux boats on the same feel): quicker throttle response, tighter turning
  circle at speed, less sideways slide (grippier, arcade), small lean into turns; jet ski top speed a bit higher.
  The verify pass found the RIB turning circle too wide to hit a ring at full throttle: fix that too.

## B. Builders and timed construction

- Every building and decor build takes time. Base work `T = clamp(20 * (cash / 1000) ^ 0.9, 20, 600)` seconds of
  one-crew work (Workshop 500 → 20 s, 10,000 → ~2:40, 40,000 → ~9 min); decor 8 s (tuned in docs/23 (r)). Robux-bought builds take the
  same time (Robux skips Cash, not the build).
- One construction at a time per island. Rate = `1 + 0.15 * units`, units = sum of `WorkerRules.RARITY_MULT` over
  the Builder workers present at the site (the island's best Builders go there, max 5: a full crew ~halves a build). The island always has its
  base crew (the two hard-hat builder NPCs at the build station) so a 0-Builder player still builds at rate 1.
  Progress is saved (progress + last tick, server clock); it keeps going while the owner is offline at the last rate,
  so a build finished while away is standing on rejoin. Builders now cut TIME instead of Cash: the Builder Cash
  discount is removed (one meaning per category).
- A building under construction is not owned yet: no effects, no unlocks, its workers wait, until it finishes.
- Looks under construction: red/white Lego safety fence round the lot, scaffold poles, a small Lego crane, brick
  stacks, a sign, and the building itself rising bottom to top with progress (parts above the progress height
  hidden on the client; same ordering as `BuildSeq`). Builders (base crew + Builder workers) walk to the site and
  hammer (dust puffs, tink sounds). A billboard: progress bar, time left, a hammer glyph x builder count. Finish:
  the last bricks drop with the `BuildSeq` bounce, confetti, fence/scaffold go away, builders walk back.
- The build tablet shows the busy site (timer) and the other cards wait (hourglass glyph); the lot pulse still works.

## C. Open, varied islands; workers you can see at work

- Too many gabled houses. Give every building its own silhouette, Lego style, open where people work so you SEE
  them working:
  - Builder → Workshop: open-air carpentry yard (workbench, timber stacks, a half-built boat frame).
  - Gatherer → Fish shed becomes a fish market / pier: awning stalls, crates, drying racks, a small fishing jetty.
  - Mechanic → Boat yard: a boat up on a cradle, a gantry crane, tool chests.
  - Rescuer → Rescue boathouse: open slipway with its rescue boat, lifebuoy racks, a lookout chair.
  - Medic → Clinic: white pavilion/tent with a red cross, beds and a stretcher in view.
  - Non-worker buildings keep their roles but read differently: hangar = arched roof, sub pen = round pool with a
    dome, trophy hall = columns + gold dome, crane = tall jib, lookout = tall tower, helipad = flat pad.
- Open the island up: fewer fixed clutter pieces (hedges, garden clusters, prop clusters, court, playground), a clear
  central plaza and sightlines from the jetty, buildings scaled back toward their lots. Aim: about 40% of the lawn
  is open. If that is impossible on the current plate, widen the plate as long as the ring layout specs pass.
- Worker job contract: each published worker (`ReplicatedStorage.Workers.<UserId>.<index>`) carries a string
  attribute `Job`: `Build` (at a construction site), `Fish`, `Repair`, `Rescue`, `Heal`, `Gather`, `Idle`. The client
  plays a job loop with a small held prop (hammer, crate, wrench, clipboard...) at the spot, and money workers pop a
  small "+$" over their head when they pay.
- How you get people to work, shown not told: a delivered survivor walks off the jetty to their building (if built);
  if not built, they wait on the jetty with their category icon and the tablet card for that building shows "x3"
  of that worker icon waiting.

## D. Spin wheel (RNG, flex)

- A Spin button in the left menu opens a full-screen animated prize wheel (menus outside gameplay are allowed).
  Free spins: 1 a day + 1 every 10 people rescued. Robux: 1 / 5 / 15 spins (dev products, `ready = false` until the
  owner creates them). Odds are shown on the wheel (Roblox rule for paid random items).
- Rarities: Common 50, Uncommon 25, Rare 15, Epic 7, Legendary 2.5, Mythic 0.5 (%). Pity: an Epic or better at
  least every 10 spins, a Legendary or better at least every 50. Duplicates turn into Cash by rarity.
- Prizes: Cash (Common/Uncommon); pet variants of the existing pets (Golden, Neon, Rainbow, Galaxy with a sparkle
  aura); boat finishes for any craft (Gold chrome, Neon glow, Lava, Galaxy) and wake trails (rainbow, fire, stars);
  the grand prize a Robux boat (owned already → a Mythic finish).
- Flex: Epic+ wins show a reveal card with rays; Legendary/Mythic wins also put a server-wide banner up ("Ava won a
  MYTHIC Galaxy Otter!", rarity colour, icon) and a confetti burst over the winner that everyone sees. Equipped rare
  items carry a rarity aura (particles) so others notice them on the water and on islands.
- Owned finishes are picked where liveries are picked today; pet variants in the Companion panel.

## E. Tutorial (after A–D merge)

World-shown, no sentences: a guide arrow/beam and the minimap pin lead, a pulsing ring on the one button to press,
input glyphs for the one key. Beats: jet ski → first survivor → home → they walk to work → build tablet → build the
Workshop (watch it rise, builders hammer) → next call → free spin. A top chip row of 1–3 word goals with ticks.
Saved step; a returning player never repeats it.

## F. Progression and core loop (with E)

Re-run the pacing sims with build times and the spin wheel; keep "the whole tree in ~17 h"; first build inside
5 minutes; always one visible next goal (a "Next" chip pointing at the next affordable building or call).
