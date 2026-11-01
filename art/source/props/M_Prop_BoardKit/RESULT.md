# M_Prop_BoardKit (2026-11-01, Opus 5.5, Blender MCP, 4 AD rounds)

Validate PASS; zfight 0 visible pairs on LOD0-2. LOD0 7,334 tris, LOD1 3,408, LOD2 1,654. One flat-palette set
(T_BoardKit_Brick; NOR/RGH/MET = the Depot palette bytes, SHARED_BYTES).

Modules (fronts face -Z): L01_RescueBoard, L02_ComingSoon, L03_IslandSign, L04_HarbourBeacon, L05_BeaconLens (Neon
#FFC83A in code), L06_BeaconPanes (Transparency 0.85). Attachments: ATT_Board/Soon/Sign/Beacon (ground origins),
ATT_BoardFaceF/B (13.14 x 10.06), ATT_SoonFace (11.5 x 5.75), ATT_NamePlate (27 x 7 x 0.8), ATT_BeaconIcon (2.6),
ATT_BeaconLight.

Ids: LOD0 114404971301410, LOD1 76453127495122, LOD2 134133978588718; ALB 103092706271226 (Reviewing at upload).

Wiring (AssetLoader.cloneModule; code Parts stay as the fallback and as invisible colliders): LeaderboardService
(5-row SurfaceGuis on both faces, footer under row 5), ComingSoon (PNG decal on the face), DockService nameSign
(NameBoard resized to the plate, tint kept), setMaster (glow + beam on the lens, medal decal on the icon plate).

AD (bar 9.1): r1 7.6, r2 8.7, r3 8.9, r4 9.2. Critiques and sheets: build/status/2026-11-01/perfect/M_Prop_BoardKit/
(main checkout). r4_AD.md fixes: trophy plinth as a studded brick, cone inboard, sign flush columns, stepped beacon
plinth, lamp emission. Not Studio-tested (face text fit, decals on invisible parts, collider fit).
