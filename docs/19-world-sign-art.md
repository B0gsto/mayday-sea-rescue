# 19 · World sign and surface art requests

2D art the map polish packages (docs/17) need. The orchestrator generates each image (docs/18 rules: no vibe-coded
look), uploads it and wires the id; until then the named part keeps its neutral placeholder.

## WP-4 (coast, harbour and shore props)

| File | Size | Goes on | Description |
|---|---|---|---|
| `T_Station_RollerDoor.png` | 512 x 512, tiling vertically | `M_Bld_Station_BayDoor_LOD0` (Workspace.Dressing.Station), as a SurfaceAppearance ColorMap or a Texture on the door's front face | Lifeboat station roller shutter seen square on: horizontal galvanised-steel slats about 1/24 of the height each, painted RNLI-style deep navy (#1F3350) with soft weathering, faint rust streaks below the slat joints, a slightly darker bottom rail and a bare-steel bottom edge strip. No text, no logo. Replaces the flat blue face (docs/17 P1 17). |

Not requested: the "blank white boards" seen from `station_slipway` (-230,12,-80) are the backs of the traffic-light
backboards (`Workspace.Dressing.Street.Junctions.TrafficLight.Border`, Street.luau, WP-2): a code fix (black back,
white border only on the front), not art.
