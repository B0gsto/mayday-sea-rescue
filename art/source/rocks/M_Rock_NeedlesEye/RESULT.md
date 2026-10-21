# M_Rock_NeedlesEye (K1)

Round 5 (Opus): rebuilt as one continuous jointed granite mass, no glued scan chunks. `build.py` samples a signed
distance field on a 0.3-stud grid (buttress, thick lintel, narrower undercut seaward leg, crest stepping down to the
sea, wave-cut platform), cuts it with a sheeting joint set and two steep joint sets (each block set back and tilted on
its own, so you get open joints, ledges and fracture faces), adds a wave-cut notch at the tide line, then meshes it
through OpenVDB. Seven fallen blocks sit on the platform (`_Base_LOD0`). `archtex.py` bakes the HP plus CC0 Poly Haven
rock_face / rock_boulder_dry relief, box-projected in world studs, so nothing stretches. `compose_maps.py` adds the
zonation: subtidal silt, barnacles, wrack, a black tide band, runoff, bird lime and lichen.

- Validate: PASS, 80 checks, 1 waived (LOD UV layout: collapse decimation shifts island areas; the maps are baked in 3D).
- Tris: LOD0 11,800 (arch 9,800 + blocks 2,000) / 4,720 / 1,770; COL 900; HP 415,188. 28 px/stud at 4096.
- Set T_Arch_Granite (4096, + _Wet); ATT_Waterline z = 30. Silhouette: crest 53%, legs 1.59x.
- Pipeline: run.py `--steps build`, archtex.py, compose_maps.py, run.py `--steps build,lod,validate,export,turntable`, sheet.py.
- Polish (round 5b): eye cut along the joints (sheeting-joint roof, stepped overhang over the headland-side undercut,
  scoured seaward shoulder), lintel ~1.5x thicker, irregular log-spaced joints + an oblique set, wave-worn lumpy
  faces under the tide line.
- Open: Studio cells pending; UV atlas only 51% used; not uploaded.
