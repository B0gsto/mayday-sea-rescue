# M_Bld_LifeguardTower
dims_m: 4.54 x 6.64 x 8.12

Axes: Blender X, Y (front = -Y, the lookout window faces the sea), Z up; origin at sand level under the cabin centre.
The overall box includes the steps (front, to y -4.55), the flag flying to -X and the flagpole top (8.0 m + finial).

Class: raised beach lifeguard hut on legs (UK beach lifeguard units: timber or composite cabins on stilts or a raised
deck with steps, red and yellow livery, a red-over-yellow patrol flag on a pole, rescue boards racked at hand).
Generic sign "LIFEGUARDS", no RNLI or other real marks. Greybox (map/Build.luau, Haven Sands LifeguardTower point):
3.3 x 3.3 m hut on 4 legs, floor 3 m up, roof 5.9 m, flagpole 8 m; this model keeps those numbers.

| Part | Size (m) | Note |
|---|---|---|
| Cabin | 3.0 x 3.0 footprint, walls 2.62 high above the deck | row: cabin about 3 x 3 m |
| Deck | 3.4 x 4.05, top 3.0 m above the sand | row: deck about 3 m up (verify against RNLI units) |
| Front porch | 0.9 m deep in front of the cabin, guard rail 1.04 m | |
| Posts | 6 x 0.15 m square treated timber, X-braced sides | |
| Roof | mono-pitch box-profile steel, 5.78 m front, 5.64 m back, 0.35 m overhangs | eaves about 2.6 m above the deck |
| Lookout window | 1.4 x 1.05 m, sill 1.0 m above the deck; two 1.2 / 0.9 m side windows | |
| Door | 0.81 x 2.03 m, front right | `ATT_Door` on the porch |
| Steps | 0.9 m wide, 15 rises of 0.2 m over 2.15 m (54 degrees, ship-ladder steep) | `ATT_StairsFoot` |
| Flagpole | 0.08 m dia, sand +0.3 to 8.0 m, clamped to the front-left post | `ATT_Flag` at the hoist top |
| Patrol flag | 0.9 x 0.6 m, red over yellow | lifeguards on patrol between the flags |
| Rescue board | 2.9 x 0.55 x 0.11 m soft board, yellow deck, red rails, on a galvanised rack 0.52 m above the deck | `ATT_BoardRack` |
| Sign | 2.6 x 0.36 m yellow board, red "LIFEGUARDS" | `ATT_Sign` |

Sources: none found online this batch (verify against RNLI lifeguard unit photos and a hut supplier's drawings);
sizes are the docs/12 row and the greybox plus general knowledge of UK beach huts and stairs (verify).
