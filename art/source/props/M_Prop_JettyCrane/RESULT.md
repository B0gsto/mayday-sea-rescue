# M_Prop_JettyCrane: perfect pass (docs/28), 2026-10-31

Bar: a fresh Opus AD scores 9.1+. **Not reached after the 3 allowed refine rounds; not uploaded.**
The game still uses r3 (LOD0 131828506127675, LOD1 86006746697409, LOD2 73426253708503).

| Round | Builder | AD score | Main notes |
|---|---|---|---|
| r1-r2 | earlier | 6.5 / 7.6 | see git log |
| r3 (shipped) | Opus, MCP | 8.3 (in-game sheet, capped: no close-ups) | thin jib, flat bracing, cab lost, thin rope, dark at dusk |
| r4 | Opus, MCP | 8.3 | diagonals kinked/cutting frames, matte clay, hook through ring, orange wedge under cab |
| r5 | Opus, MCP | 8.7 | faceted hook, plain hook block, polygonal studs, hard edges |
| r6 | Opus, MCP | 8.7 | hook-block sheave reads as a washer, roof studs off-grid, flat glazing, plain cab back, no slewing ring, ring band facets |

r6 source: build.py (7896 / 8000 tris, validate PASS, zfight 0 visible pairs left), glossy RGH (palette.py),
ATT_Lamp_JibTip / ATT_Lamp_Cab markers + `DockPieces.slipCrane` amber NightLamp bulbs (dormant until an upload adds
the markers to AssetIds). Sheets: build/status/2026-10-31/perfect/M_Prop_JettyCrane/ (r4-r6 sheets, close-ups,
M_Prop_JettyCrane_r6.blend).

Open: next round should take the r6 AD list. The triangle budget is the limit: freeing tris (8-sided pins and hidden
studs) is needed before adding a slotted sheave block, a slewing gear ring and glazing glints. A large_prop budget
raise is the other option.
