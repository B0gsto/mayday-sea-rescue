# M_Sea_SandRipples

Validate: **PASS**, 192 checks, 0 failed, 1 waived (_COL: flat seabed decals lie on the terrain; collision comes from the terrain).
LOD0 5,742 tris / LOD1 2,869 / LOD2 1,432 (large_prop, asset row 6,000).

Four decal pieces, 2.4 x 1.7, 3.7 x 2.6, 6.0 x 4.1 and 4.4 x 3.0 m; kit 10.13 x 6.99 x 0.10 m, base origin, centred on x/y. Lobed rims fade to zero height (no rectangular edges). Geometry carries the 0.8 to 1.2 m bedform swells; a dense 130k-tri _HP bakes 12 to 15 cm ripples and grain into NOR.

PatchD has 48 shell-grit shards, 4 scallop fragments and 9 half-embedded pebbles in the troughs, as separate MeshParts.

One shared 2048 set `T_SandRipples_Seabed`: dry and wet ALB/RGH plus NOR/MET. Planar top UVs, 54 to 83 px/stud. No attachments (scenery decals).

Open issues: no reference dims.md; the "seabed atlas" is this asset's own set, not yet repacked with the other seabed kits; no Studio pass or upload run.
