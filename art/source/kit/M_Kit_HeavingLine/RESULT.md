# M_Kit_HeavingLine — result

**Validate: PASS** (51 checks, 0 failed, 2 waived: *LOD UV layout* on both LOD1 meshes — collapse decimation of a
tiled rope tube moves UVs; the LODs sample the same one-tile-per-circumference trim). `check_textures.py`: 31/31
PASS (OpenGL normals, luma 20..240, saturation 0.29, `_Wet` darker/glossier).

- LOD0 **2,996** tris (Line 1,878 + Fist 1,118), LOD1 **1,496** (938 + 558). Class `small_prop`, ceiling 3,000:
  the docs/12 row's 1,500 to 2,500 is raised to the class cap as HP2a did for its rope props. No LOD2: the lod
  step's collapse decimation cannot take a rope tube below ~84 tris per coil turn, so a LOD2 of any coil is out of
  reach (that is why the row's siblings are `small_prop`).
- Real size **0.400 x 0.337 x 0.089 m** as it sits, base at Z 0: **11.8 m of 6 mm line** in ten large throwing
  loops (2 wide over 5 layers, oval, seized with twine), a 61 mm woven monkey's fist on the bundle, its worked end
  hanging onto the deck, and a teardrop spliced eye out at +X.
- Set: one rope trim `T_Rope_Poly_{ALB,NOR,RGH,MET}` + `_Wet`, 512 px, painted by `maketex.py` (rope.py's braid
  base, sun-bleached yellow, salt, deck grime).
- Attachments: `ATT_Grip` (the seized bundle), `ATT_Throw` (the fist), `ATT_LineExit` (where the line leaves the
  coil for the fist: Beam origin), `ATT_LineEnd` (the eye the tow line is bent onto).
- Open issues: the line is 12 m against the reference's 20 to 25 m (see the budget note above); no reference photo
  board; the Studio preset row is pending.
