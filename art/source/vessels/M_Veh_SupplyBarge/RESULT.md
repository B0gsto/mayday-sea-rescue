# M_Veh_SupplyBarge result

Validate PASS (139 checks, 0 failed, 19 waived). LOD0 7,036 tris / 5 meshes,
LOD1 2,456 (34.9%), LOD2 698 (9.9%); COL 60 tris closed. Waived naming is (9 x naming) the cargo meshes keeping their gameplay
names `Crate_1..3` (docs/25 D, so the game can unload them one at a time). Waived LOD UV layout is the shared
flat-palette material (decimation merges cells by design; one 16-cell atlas, tiling=True).

Meshes: `M_Veh_SupplyBarge_Hull` (5,252: hull, deck studs, fenders, bollards, mast, rudder, life ring; the fittings
are merged into it because their LOD2 shells would not decimate), `_Wheelhouse` (968), `Crate_1..3` (272 each).
Bbox 15.80 x 36.35 studs, 10.20 high (funnel cap 9.0; hull bottom -1.2 draft); dims 5.33 x 12.0 x 3.4 m.
Pivot at the waterline (z 0) and midships, bow -Y (Roblox -Z). Real-size check: beam -1.2%, length +1.0%,
height 0.0%.

Set: 1 - Barge Hull 1024 px, 4 x 4 flat palette (shared with the Depot), ALB/NOR/RGH/MET in
build/prod/M_Veh_SupplyBarge/textures/M_Veh_SupplyBarge (T_Barge_Hull_*).

4 attachments: ATT_Waterline (0, 0, 0), ATT_Bow (0, -16, 0.8), ATT_Stern (0, 16.8, 0.8),
ATT_Helm (0, 12.5, 4.0).

Built: lofted hull (red lower hull, blue flared topsides, tan tile-planked deck, 4 x 8 plates with 2 x 2 studs on
every tile), white studded gunwales, three orange hung fender pads per side (rope straps over the rail, set high so
they do not read as wheels), four blue-capped bollards on the rail, bow mast with lamp, rudder; white stern
wheelhouse with dark-framed glass front, two-pane sides, stern windows, glass door, 24-stud blue roof with stud rows
and red funnel; 3 strapped 5 x 5 x 3.5 cargo crates; red/white life ring on the cabin side. Rope coils and brown deck
discs removed.

Open issues: Studio preset cells are pending (12 1.4 item 7) and show as placeholders on the sheet. Moored at the
Depot quay the barge sits at ATT_BargeMoor x 32.8 (pad faces 1 stud off the quay edge).

Rebuild: maketex.py then `blender-run.sh tools/blender/run.py -- --build .../build.py --out-root
build/prod/M_Veh_SupplyBarge --steps build,lod,validate,export,turntable`.
