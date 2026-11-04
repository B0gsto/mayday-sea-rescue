# Pirate set (2026-11-04, round 2, Opus 5.5, Blender MCP instance 2)

Boat from the "Pirate Boat Concept" spec (concept_spec.json), scaled 0.875, with the art director's round 1 fixes in
adjust(): new shark head about 1.5x (dark slate), hull-wide gaping jaw, 18 big teeth, bright red mouth, angry eyes and brows;
clean bulwark with a tan cap instead of stepped blocks; fuller sails. 27.5 long, 16.3 wide, 31.3 tall (studs).
Crew from "Pirate Crew Concept", scaled 1.25 (1.4x round 1), raised on plinths; captain's huge tricorn; 2x macaw in red
and yellow. All validate PASS, zfight 0 visible pairs at every LOD, exported. Boat LODs are authored in build.py.

| Asset | LOD ids (0, 1, 2) | Tris |
|---|---|---|
| M_Veh_PirateBoat | 104221753560704, 114622243767557, 80467557821622 | 15,628 / 7,828 / 1,952 |
| M_Chr_PirateCaptain | 94817428483428, 82501313513489 | 1,306 + LOD1 |
| M_Chr_PirateDeckhand | 74819528064743, 111945172792009 | 1,006 + LOD1 |
| M_Chr_PirateLookout | 126863374924021, 133997756691629 | 868 + LOD1 |

Shared maps (T_PirateBoat_Brick): ALB 128458871332767, RGH 129355603351811, MET 93990378549016 (all Reviewing at upload),
NOR 134063939343985.

Boat MeshParts: _Body, _Castle, _Rig, _Lights (set _Lights to Neon: panes and lantern), _COL (proxy only). Pivot on the
waterline, bow -Z.

Crew offsets from the boat pivot (Roblox studs, x y z; each crew pivot is at the feet, facing -Z, same as ATT_* on the boat):
- Captain (ATT_Captain): -0.744, 7.35, 6.475 (helm dais; brings his own wheel and macaw, the concept's boat wheel is left out)
- Deckhand (ATT_Deckhand, crew A with oar): 0, 7.525, -6.037 (crate on the forecastle)
- Lookout (ATT_Lookout, crew B with spyglass): -1.4, 5.6, 2.45 (deck hatch; crow's nest stays empty)

Sheet: build/status/2026-11-04/art/pirates.png. Art director: round 1 6.8/10, round 2 pending.
Not done: no Studio check, not swapped into shared/PirateBoat (placeholder is 63 x 50 studs: check the size in game).
Open: sail patch is a flat tan cell; the Neon look of _Lights is unverified.
