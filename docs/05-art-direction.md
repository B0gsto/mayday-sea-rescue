# 05 · Art direction

How Mayday: Sea Rescue looks and moves. The current design is in [`00-design.md`](00-design.md); this file sets
the look for it. The rule that settles most arguments: **new things are Lego-style; finished things keep their
look.** We are not rebuilding the boats, station, helicopter or submarine that already exist.

## 1. The look in one paragraph

A bright, toy-like coastguard rescue game on a wild green hub island, six flat Lego baseplate islands, long
suspension bridges and a ring of rocky outer islands. The sea is the real stage: readable swells, white spray,
orange rescue gear and clear silhouettes at speed. The hub is overgrown and a little mysterious; the player
islands are clean, bright and built up over time. UI is Roblox simulator style: chunky, rounded, high-contrast
and readable on a phone.

## 2. Two lanes

### 2.1 Existing finished art

These keep their current look and proportions. Do not restyle, re-topology or re-texture them for this pass:

- Jet ski, RIB, lifeboat and their premium variants.
- Rescue helicopter and submarine.
- Station rig, harbour pieces, buoys, quay kit and rescue props.
- Existing wildlife, trees, rocks and terrain materials.
- Existing PBR `SurfaceAppearance` assets and their texture packs.

The asset diet (WP-16) may merge near-duplicate materials and drop unused ids. That is cleanup, not a redesign.

### 2.2 New art

New buildings, outposts, props and island pieces are **blocky and Lego-like**:

- Chunky bricks, plates and studs; big flat tops; modest part counts.
- Bright, saturated colours; clean edges; a few large shapes rather than many small details.
- Wood, canvas, rope, lanterns and painted metal for the frontier camps.
- Lego build animation when a building is bought: pieces drop in bottom to top, small bounce, snap, dust puff.

Player islands are **plain flat Lego baseplates**: green stud plates with a berth notch, no terrain and no
scatter. The hub forest and outer islands stay natural terrain.

## 3. Palette and readability

- **Rescue orange** (`#F26A1B`-class) is the signal colour for survivors, rings, flares, lifeboats and the
  player's own craft highlights.
- **Sea** runs deep blue-green to turquoise shallows, with white foam and a bright horizon.
- **Hub** is moss green, bark brown, canvas cream and lantern warm yellow.
- **Player islands** use classic Lego greens, greys and bright primary accents; each player's flag colour is
  the one strong personal colour.
- **UI** uses bright gradients, thick dark borders and a black outline on the display font.
- Never rely on colour alone: use shape, icons and labels as well. Orange/red are reserved for rescue and
  danger, not decoration.

## 4. Scale and form

- **1 metre = 3 studs.** Boats, bridges and buildings use that scale.
- Hub is about 800 studs across; player islands sit about 1,100 studs out, each with a 160-stud-radius plateau.
- Suspension bridges are 14 studs wide, with a 50-stud apex so every boat and the helicopter pass under.
- Boats read as chunky toys: wide hulls, big outboards, visible seats, orange grab rails.
- New buildings are assembled from large bricks: a boathouse is a box with a pitched roof, a roll-up door and
  a sign; a lookout is a hut on legs with a ladder and a lamp. Detail comes from silhouette and colour, not
  from tiny trim.
- Terrain is smooth and readable, with cliffs and rocks as separate meshes where sharp edges matter.

## 5. Materials and budgets

- Existing PBR assets keep `SurfaceAppearance` maps and their current texel density.
- New Lego-style pieces use flat `Material` colours or simple textures; no unique PBR set per building.
- One material per colour family per kit; reuse brick, plate, stud, canvas and wood materials.
- New props: keep part counts low enough to place dozens in the hub without hurting a phone. Prefer one mesh
  per colour group over many small parts.
- No new 4K texture sets. New UI icons are transparent PNGs, not 3D renders.
- The asset diet (WP-16) is the place to measure and cut; do not add texture packs casually.

## 6. Lighting and weather

- **Day:** bright sun, blue sky, crisp shadows, saturated sea. This is the default read.
- **Golden hour:** warm low sun for thumbnails and the hub's first arrival.
- **Storm:** grey-green light, larger swells, rain, spray and reduced visibility. Rescue orange must still
  read against the sea.
- **Night:** deep blue, warm outpost lanterns, lighthouse and dock beacons. Beacons are readable from the water.
- **Hub fog:** the forest starts fogged and clears as the player walks it. Fog is a discovery tool, not a
  permanent weather effect.
- Keep the horizon clean. The ocean must cover the view from a player camera; no square water edge.

## 7. Ocean and VFX

- One shared wave function drives the visible ocean and every hull. What the player sees is what the boat feels.
- Spray, wake, foam and bow wave are the main speed cues. Make them bold and readable from the chase camera.
- Pick-up ring: a clear orange ring on the water, visible at speed and in a storm.
- Storm VFX: rain, wind streaks, whitecaps, spindrift; no photoreal simulation rebuild.
- Helicopter downwash, submarine bubbles and seabed silt are simple, chunky effects.
- Lego build VFX: brick drop, bounce, snap flash, dust puff. Keep it short (about 5 seconds).

## 8. Characters and animation

- Players and NPCs are simple Roblox R15 characters. No custom human meshes.
- Quest givers are readable silhouettes: coat, hat, boots, one prop (clipboard, lamp, rope, crate).
- Survivors wear orange lifejackets and read at distance; in the water they wave and splash.
- Bosun is the existing low-poly dog. One companion at a time.
- Animation is toy-like and readable: big waves, clear sit/stand, exaggerated climb aboard, short build beat.
- Third person only. No first-person viewmodel, hands or photo mode.

## 9. UI

The UI is a core part of the look, not a skin on old phone screens. See [`18-ui-art-requests.md`](18-ui-art-requests.md).

- Roblox simulator style: chunky rounded display font with a black outline, bright gradient cards, thick
  dark borders, red square X, big green price buttons, coloured square icon buttons with a 1–3 word label.
- A subtle Lego stud texture on title bars and price buttons.
- Left column of big square buttons; centred panels; full map on M.
- Icons are generated 2D art, not code-drawn glyphs, once they land. Placeholders are fine until then.
- No phone frame, no iOS squircle tiles, no wallpaper, no home grid.

## 10. Production rules

- Placeholders first; gameplay never waits on art.
- New Blender work goes to DeepSeek V4.1 Flash through T3 `delegate_task`, following `art/bench/PROD_BRIEF.md`.
- Code builders are DeepSeek V4 Pro; Opus reviews. Do not redesign finished assets.
- Use the build → render → critique loop for visual work; at most three rounds, then ask.
- No real logos, liveries or insignia. The Gale Isles Coastguard is invented.
- Reference photos stay in `art/reference/` and are never uploaded.
- If an asset is not on [`12-asset-list.md`](12-asset-list.md), add it there before building it.
