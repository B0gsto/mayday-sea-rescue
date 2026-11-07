# 05 · Art direction

How Mayday: Sea Rescue looks. The game is one boat you upgrade 50 times and drive out to sea to rescue people
(`00-design.md`, `30-boat-pivot.md`). Two rules settle most arguments: **new things are Lego-style toys; finished
things keep their look.**

## 1. The look

A bright, toy-like rescue game at sea. Your boat is the hero: it starts as a small jet ski and ends as a huge,
silly Rocket Cutter, every level bolting on one big visible piece. The sea gets darker and stranger the farther
out you go. A tight ring of six Lego-baseplate islands sits round a lagoon with a small beacon atoll in the middle.
UI is Roblox simulator style: chunky, rounded, high-contrast, readable on a phone.

## 2. The boat

- Five stages (`BoatLevels.Stages`): Jet ski L1-10, RIB L11-20, Lifeboat L21-30, Hydrofoil L31-40, Rocket Cutter
  L41-50. Each level adds one exaggerated piece (`BoatLevels` piece table; meshes in `BoatLevels.HullArt`).
- Pieces are big, readable from the chase camera and on a phone, and fun, never weapons: no rocket, missile,
  spike or gun reads (owner 2026-11-05, why the first Hydrofoil and Rocket Cutter meshes were pulled).
- Height budget: the tallest level fits the station gate (concepts stay under 38 game studs).
- Robux boats (Storm Runner, Tidewalker, Riptide X, Gilded Gull, RIB, Lifeboat) are looks at your level's stats.
- Pirate boat and crew: friendly toy pirates, kid-safe, no weapons in hand.

## 3. The sea and zones

Five rings out from the lagoon (`Calls/SeaZones`): Shallows (turquoise), Kelp Banks (green), Coral Drift (blue),
Storm Reach (grey-blue), Wreck Abyss (deep navy). A crossing reads through water colour, fog and light blended over
300 studs either side of the line (`SeaZones.lookAt`), plus a buoy line; no wall or curtain. Far sector spots
(sea stacks, a wreck aground, a lighthouse rock) give each empty direction a landmark.

- One wave function drives the visible ocean and every hull.
- Spray, wake, foam and bow wave are the speed cues; bold from the chase camera.
- Default weather is sunny; the zone look sets the mood.

## 4. Palette and readability

- **Rescue orange** marks survivors, rings, flares and rescue gear. Orange and red mean rescue or danger, not decor.
- **Rarity colours** (gems, survivor tags) come from `Rarity` and the kit theme.
- **Islands**: classic Lego greens, greys and bright primary accents; each player's flag colour is their own.
- Never colour alone: shape, icon and a 1-3 word label too.

## 5. Two lanes

- **Finished art keeps its look:** jet ski, RIB, lifeboat and their pieces, premium boats, helicopter, the Upgrade
  Station, pirate boat and crew, island buildings, wildlife, pets, hub kit, rocks, trees. Cleanups may merge
  materials or drop ids, never change the look.
- **New art is Lego-style:** chunky bricks, plates and studs, big flat tops, few large shapes, bright saturated
  colours. A bought building builds itself in with a Lego drop-bounce-snap.

## 6. Materials and budgets

- Existing PBR assets keep their `SurfaceAppearance` maps.
- New pieces use flat colours or shared simple textures; no unique 4K set per asset.
- Avoid `Slate`, `WoodPlanks`, `Brick`, `Concrete` on Parts (MaterialService remaps them to terrain textures).
- LODs for every mesh (`tools/blender/budgets.py`); no coplanar faces (lift or inset 0.04-0.05 studs).

## 7. Characters

- Players and NPCs are simple R15 characters. Survivors wear orange life jackets, wave and splash.
- Bosun is the low-poly dog; one companion (Bosun or one pet) at a time.
- Third person only.

## 8. UI

Screen sprites are Claude-designed vector art (`art/source/ui/*.svg`, rendered by `tools/ui-art/render.py`): white
sticker rim, hard dark outline, bold gradient and lip, at least ~32 pt on a phone, labels 14 pt+. No text glyphs, no
outline rings round HUD buttons, never flashing or pulsing orange (one pop, an arrow or a camera focus instead).
Details: `18-ui-art-requests.md`.

## 9. Production rules

- Placeholders first; gameplay never waits on art.
- Every new model starts as a concept page (Claude Artifacts: top, front, back, sides, 3/4, phone read, spec.json,
  BLENDER.md). The art director scores it; only an approved concept goes to Blender.
- Blender work goes through the Blender MCP; the pipeline is in `06-tools-and-pipeline.md` and
  `art/bench/PROD_BRIEF.md`. Art director rounds: ship above 8/10, at most 3 rounds.
- No real logos or insignia; the Gale Isles Coastguard is invented. Thumbnails and key art are the owner's.
- Add an asset to `12-asset-list.md` before building it.
