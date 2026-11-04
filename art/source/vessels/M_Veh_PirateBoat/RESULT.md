# Pirate set (2026-11-04, round 3, Opus 5.5, Blender MCP instance 2)

Boat from the "Pirate Boat Concept" spec (concept_spec.json), scaled 0.875, with the art director's fixes in adjust():
steel-grey shark head about 1.5x with a white belly and lower jaw, cheek courses sweeping back along the hull, gaping red
mouth, 18 big teeth, angry eyes, big dorsal fin, big gills; clean capped bulwark; double-size flag on a taller staff; fuller
sails. 27.5 long, 16.3 wide, 35.2 tall (studs). Crew from "Pirate Crew Concept", scaled 1.85 (about 2x the concept), raised
on plinths; captain's huge tricorn; big red and yellow macaw. All validate PASS, zfight 0 visible pairs at every LOD,
exported. Boat LODs are authored in build.py.

| Asset | LOD ids (0, 1, 2) | Tris |
|---|---|---|
| M_Veh_PirateBoat | 110238927237734, 128714989439062, 131033047854669 | 15,860 / 7,956 / 1,996 |
| M_Chr_PirateCaptain | 73019630667094, 75264763873474 | 1,306 + LOD1 |
| M_Chr_PirateDeckhand | 79038505642741, 108242503789947 | 1,006 + LOD1 |
| M_Chr_PirateLookout | 137477835537186, 130143926615466 | 868 + LOD1 |

Shared maps (T_PirateBoat_Brick): ALB 71919712908913, RGH 93864434417126, MET 93990378549016 (all Reviewing at upload),
NOR 134063939343985.

Boat MeshParts: _Body, _Castle, _Rig, _Lights (set _Lights to Neon: panes and lantern), _COL (proxy only). Pivot on the
waterline, bow -Z.

Crew offsets from the boat pivot (Roblox studs, x y z; each crew pivot is at the feet, facing -Z, same as ATT_* on the boat):
- Captain (ATT_Captain): -1.312, 7.35, 6.475 (helm dais; brings his own wheel and macaw, the concept's boat wheel is left out)
- Deckhand (ATT_Deckhand, crew A with oar): 0, 7.7, -7 (bow crate, behind the fin)
- Lookout (ATT_Lookout, crew B with spyglass): -1.4, 5.6, 2.45 (deck hatch; crow's nest stays empty)

Sheet: build/status/2026-11-04/art/pirates.png. Art director: round 1 6.8/10, round 2 7.4/10, round 3 pending.
Not done: no Studio check, not swapped into shared/PirateBoat (placeholder is 63 x 50 studs: check the size in game).
Open: crew are large for the deck, so the captain's hat and macaw overhang the hull; sail patch is a flat tan cell; the Neon
look of _Lights is unverified.
