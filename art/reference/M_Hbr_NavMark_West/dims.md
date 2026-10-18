# M_Hbr_NavMark_West
West cardinal, IALA Region A pillar buoy (batch HP2b, docs/12 2.3).

dims_m: 1.88 x 1.88 x 6.88

- Float 1.80 m diameter, rubbing fender 1.88 m, freeboard 0.56 m (deck); counterweight tail to 2.05 m below the waterline,
  mooring eye and chain stub to 2.67 m below. Pillar column, 4-leg cage, platform at 2.62 m, solar LED lantern
  (focal plane 2.90 m, ATT_Light), octahedral radar reflector, topmark to 4.22 m above the waterline.
- Paint: yellow with a broad black band; cones point to point; 9 quick flashes every 15 s (VQ(9) 10s allowed).
- Topmark: cones_point (black).

## Light (for the game)
- Characteristic: **Q(9) W 15s** (white lens).
- Studio rhythm, one period looped: on 0.3 s / off 0.7 s / on 0.3 s / off 0.7 s / on 0.3 s / off 0.7 s / on 0.3 s / off 0.7 s / on 0.3 s / off 0.7 s / on 0.3 s / off 0.7 s / on 0.3 s / off 0.7 s / on 0.3 s / off 0.7 s / on 0.3 s / off 6.7 s (sum 15.0 s). Q = 60 flashes/min (0.3 s on), LFl = 2 s.
- Drive the `_Lens` MeshPart (Material Neon, lens colour) and a PointLight at ATT_Light with this sequence; range about 2 NM at
  sea (verify), so in game a 150 to 250 stud light radius at night.

## Floating
ATT_WaterLine is the origin (z 0): place the model with ATT_WaterLine on the sea surface; ATT_Mooring is the chain end
(anchor the mooring constraint there), ATT_Topmark the topmark top.

IALA sources (checked 2026-10-18):
- Cardinal marks (colours, topmarks, VQ / Q rhythms): https://en.wikipedia.org/wiki/Cardinal_mark (IALA Maritime Buoyage System)
- Lateral marks, Region A: https://en.wikipedia.org/wiki/Lateral_mark
- Isolated danger: https://ialacolreg.com/en/iala/iala-isolated-danger
- Safe water: https://en.wikipedia.org/wiki/Safe_water_mark
- Pillar buoy class (verify): steel / polyethylene pillar buoys about 1.8 m float diameter, focal plane about 2.9 m, 3.5 to 4.5 m above water (Trinity House / Sealite / JFC class sizes, general knowledge; verify against a maker's sheet).
