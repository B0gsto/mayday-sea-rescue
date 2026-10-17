"""Extra validate rows for M_Chr_Bosun: the docs/12 row gives the shoulder (withers) height, not a bounding box."""
import bpy
import numpy as np

WITHERS_STUDS = 2.1          # 0.70 m (66 to 71 cm at the shoulder; dims.md, 05 section 4.1)
TOL = 0.05


def withers(spec, report):
    wy = bpy.context.scene.get("bosun_withers_y", 0.0)
    best = 0.0
    for e in spec["meshes"]:
        o = e["object"]
        if e.get("lod") == "LOD0" and "_Body" in o.name:
            V = np.array([v.co[:] for v in o.data.vertices])
            sel = (np.abs(V[:, 0]) < 0.15) & (np.abs(V[:, 1] - wy) < 0.18)
            if sel.any():
                best = max(best, float(V[sel, 2].max()))
    dev = abs(best - WITHERS_STUDS) / WITHERS_STUDS
    report.add(spec["asset"], "real size", dev <= TOL,
               "withers %.3f studs, want %.2f (0.70 m x 3) +-%d%%: %.1f%% off" % (best, WITHERS_STUDS, 100 * TOL, 100 * dev))
