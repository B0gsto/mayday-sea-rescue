# M_Bld_HarbourLight
dims_m: 4 x 4 x 12

Axes: Blender X, Y (front = -Y, the door faces the harbour), Z up; origin at the centre of the plinth base, which sits
on the east breakwater head (map/Build.luau buildLighthouse, base at wallTop).

Class: small Victorian pier-head light (erected 1868 per src/shared/Explore/Discovery.luau), round masonry tower,
white-painted ashlar over granite with two red daymark bands (the lore's "red and white light"), corbelled granite
gallery, cast-iron rail, 12-sided lantern, red domed roof with a ventilator ball and wind vane. Comparable real
examples: Newlyn South Pier light, Penzance South Pier light, Mevagissey Victoria Pier light, St Ives Smeaton's Pier
light (Cornish harbour lights of 7 to 15 m; verify against Trinity House / Admiralty List of Lights pages).

| Part | Size (m) | Note |
|---|---|---|
| Overall | 4.0 dia x 12.0 high | row: about 12 m (tune; 05 gives 10 to 25 m); greybox is 3.3 m dia x 16 m |
| Granite plinth | 4.0 dia, 0.5 high, 2 courses | sits on the breakwater coping |
| Tower wall | 3.6 dia at the foot to 3.0 at 8.0 m (curved batter) | ashlar courses 0.40 m, painted |
| Red bands | 3.0 to 4.1 m and 5.9 to 7.0 m | daymark |
| Gallery | 4.0 dia granite slab at 8.42 to 8.58 m on 16 corbels | rail 1.04 m high, 16 stanchions (verify ~1.0 to 1.1 m) |
| Lantern | 1.84 m across the glazing, glazing 9.32 to 10.60 m, 12 sides | dome to 11.41 m, ventilator ball, vane to 12.0 m |
| Optic | drum lens 0.79 m dia, 0.80 m high, focal plane 9.95 m above the base | own MeshPart `_Lens` (Neon) |
| Door | 0.92 x 2.0 m, granite surround | `ATT_Door` at the threshold |
| Plaque | 0.70 x 0.50 m cast bronze, centre 1.70 m, 40 degrees right of the door | `ATT_Plaque` (logbook "Harbour Light history" POI) |

## Light characteristic (05 section 6.3)

**Fl(2) W 10s 12m 9M** (invented isles; the pattern is the common Cornish pier-head group-flash, e.g. Mevagissey
Victoria Pier is listed as Fl(2) 10s (verify on the Trinity House / ALL entry)).

- Two white flashes every 10 s: flash 0.5 s, eclipse 1.0 s, flash 0.5 s, eclipse 8.0 s. Under 3 flashes per second.
- Made the real way by a rotating optic: two pairs of bullseye panels 30 degrees apart, the pairs opposite each other;
  the optic turns once every 20 s (3 rpm), so each pair sweeps a viewer once per 10 s and the two panels of a pair give
  the two flashes (30 degrees at 18 degrees/s = 1.67 s apart flash to flash).
- Integration: `ATT_Light` (lens centre, 9.95 m) carries the rotating `Beam` cones (two pairs, 30 degrees apart,
  turning about +Z at 18 degrees/s) plus a short-range `PointLight` (warm white, about 4000 K) inside the lantern; the
  `_Lens` MeshPart is Neon at rest dim and brightens as a beam passes the camera. Range 9 nautical miles in the real
  world; in game the beam cone is the visible element (SpotLight range cap, 05 section 6.3).
- Elevation 12 m is the focal plane above the breakwater head plus the wall height (tune at integration).

Sources: Trinity House, https://www.trinityhouse.co.uk (light lists and lighthouse pages; verify); docs/08-references.md
row "Lighthouse light characteristics". Measurements are general knowledge of Victorian pier lights (verify).
