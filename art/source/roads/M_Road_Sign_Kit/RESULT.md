# M_Road_Sign_Kit

**Validate: PASS (190 checks, 0 failed, 0 waived).** Five invented UK-style coastal signs, each its own MeshPart, on one
shared sign atlas. They stand on a 3 m line (post axis on the ground at Blender x = 0 / 3 / 6 / 9 / 12 m); the Roblox
offsets from the model pivot are in `<Name>.attachments.json` (`ATT_<Sign>`, `ATT_Read_<Sign>`).

- **Tris:** LOD0 5,892 (Fingerpost 1,676, TideBoard 1,432, LaunchSign 948, CarPark 948, CliffWarning 888; docs/12 row
  300 to 1,500 per sign, asset ceiling 7,500), LOD1 2,946, LOD2 1,470, `_COL` 204 (five closed proxies). Tallest post
  2.95 m. Plates are folded 18 to 22 mm with a rolled front edge; posts 76 mm galvanised tube with a black cap sleeve,
  timber fingerpost with a finial; band clips with a screw housing at every plate.
- **Sets:** one shared sign atlas `T_Sign_Main_{ALB,NOR,RGH,MET}` 1024 + `_Wet` (1024 ship, 2048 masters in `textures/`).
  `sign_layout.py` holds the rects: printed faces at 100 to 148 px/stud (hero tier), tiled trim at 28 to 33, the band
  clip's strap at 114. `T_Sign_Main_signal.png` masks the red and blue signal faces.
- **Text (DIN, invented, no real sign copied):** PORT HAVEN 1, HAVEN SANDS 1/2, HAVEN HEAD 3/4, GALE ISLES 3; the Port
  Haven tide table (8 days x 4 tides, SLIPWAY KEEP CLEAR); LIFEBOAT LAUNCH + KEEP CLEAR; P + HARBOUR CAR PARK; a 900 mm
  rockfall triangle + CLIFF EDGE.
- **Open:** the Studio preset row is pending (12 1.4 item 7); TSM sizes are from memory (verify); trims are coarse on
  purpose (a plain post, and it keeps the LOD UV layout stable).
