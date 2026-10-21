# M_Sea_LostPot

Validate: PASS (202 checks, 0 failed, 1 waived).

LOD0 5946 tris (Frame 1400, Net 2622, Growth 576, Rope 540, Float 264, Silt 544, COL 24).
LOD1 2971, LOD2 1442. Budget `large_prop`, one 1024 wet set `T_LostPot_Shell`.
FBX LOD0/LOD1/LOD2 + attachments JSON in `build/prod/M_Sea_LostPot/fbx/`.

Built: real 72 mm diamond netting of 3-sided twine with a funnel eye and end panel, crusted
six-hoop parlour-pot frame, wrack/filament weed/barnacles, a sagging bridle coiled across the
silt, a crushed orange marker float, and a soft lobed silt mound that buries the settled +Y
flank and feathers into the seabed. UVs are island-normalised and shelf-packed per part;
LOD UV areas are matched after decimation.

Waiver: Net LOD2 is a rebuilt coarse net (the fine net has a decimation floor above its LOD2
target); its UVs are surface-projected into the same layout, and only its UV area differs.

Attachments: ATT_Grab (top of pot), ATT_RopeEnd (frayed bridle end).
Open issues: net reads a little tangled at close range; no reference dims.md exists yet.
