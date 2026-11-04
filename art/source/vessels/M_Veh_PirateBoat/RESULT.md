# Pirate set (2026-11-04, Opus 5.5, Blender MCP instance 2)

Boat built part by part from the "Pirate Boat Concept" spec (concept_spec.json), scaled 0.875 to 26.1 studs long, 31.3
tall. Crew from "Pirate Crew Concept", scaled 0.9, no baseplates, static idle poses. All validate PASS, zfight 0 visible
pairs at every LOD, exported. LODs of the boat are authored in build.py (the decimator cannot go below one shell per part).

| Asset | LOD ids (0, 1, 2) | Tris |
|---|---|---|
| M_Veh_PirateBoat | 126695879452444, 137906770481276, 99302203305519 | 14,496 / 7,600 / 1,868 |
| M_Chr_PirateCaptain | 101631909892224, 77942280070308 | 1,306 + LOD1 |
| M_Chr_PirateDeckhand | 81268746620289, 123347412772601 | 1,006 + LOD1 |
| M_Chr_PirateLookout | 72723079204826, 96161518006513 | 868 + LOD1 |

Shared maps (T_PirateBoat_Brick, moderation Reviewing at upload): ALB 137498260067127, RGH 99016045377974,
MET 93990378549016, NOR 134063939343985.

Boat MeshParts: _Body, _Castle, _Rig, _Lights (set _Lights to Neon: panes and lantern), _COL (proxy only). Pivot on the
waterline, bow -Z.

Crew offsets from the boat pivot (Roblox studs, x y z; each crew pivot is at the feet, facing -Z, same as ATT_* on the boat):
- Captain (ATT_Captain): -0.744, 6.65, 6.65 (brings his own wheel and macaw; the concept's boat wheel is left out)
- Deckhand (ATT_Deckhand, crew A with oar): 0.35, 6.65, -5.513 (forecastle)
- Lookout (ATT_Lookout, crew B with spyglass): -1.75, 4.55, 1.575 (main deck; crow's nest stays empty, as in the concept)

Sheet: build/status/2026-11-04/art/pirates.png. Art director score pending.
Not done: no Studio check, not swapped into shared/PirateBoat (placeholder is 63 x 50 studs: check the size in game).
Open: sail patch is a flat tan cell, no stitching; the Neon look of _Lights is unverified.
