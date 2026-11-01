"""Blender MCP driver (owner 2026-11-01: GUI only, no headless): tools/blender/run.py's steps without open_scene
(reloading the file from inside the add-on would drop the MCP server). In execute_blender_code:

    import sys, importlib; sys.path.insert(0, KIT); import mcp_run; importlib.reload(mcp_run)
    spec = mcp_run.build()                    # clear the scene, build.build(), zfight fix
    mcp_run.pipeline(spec)                    # lod, validate, export, save the .blend, report
"""
import importlib
import os
import sys

KIT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(KIT, "../../../.."))
LIB = os.path.join(REPO, "tools", "blender")
for p in (KIT, LIB):
    if p not in sys.path:
        sys.path.insert(0, p)

import bpy  # noqa: E402


def _fresh(*mods):
    out = []
    for m in mods:
        out.append(importlib.reload(sys.modules[m]) if m in sys.modules else importlib.import_module(m))
    return out


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.cameras, bpy.data.lights):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)


def build():
    common, = _fresh("common")
    common.set_out_root(os.path.join(REPO, "build", "prod", "M_Prop_CommonsKit"))
    lego, palette, build_mod = _fresh("lego", "palette", "build")
    validate, zfight_check = _fresh("validate", "zfight_check")
    clear()
    spec = build_mod.build()
    spec.setdefault("asset", "M_Prop_CommonsKit")
    validate.classify(spec)
    zfight_check.fix([e["object"] for e in spec["meshes"] if e["role"] == "visual"])
    sys.modules[__name__].SPEC = spec      # the MCP namespace resets each call; pipeline() picks it up here
    return spec


def pipeline(spec=None, steps=("lod", "validate", "export")):
    import json
    spec = spec or sys.modules[__name__].SPEC
    common, versions, validate, export, zfight_check = (importlib.import_module(m) for m in
                                                       ("common", "versions", "validate", "export", "zfight_check"))
    if "lod" in steps:
        versions.run_lod(spec)
        zfight_check.fix([e["object"] for e in spec["meshes"] if e["role"] == "visual" and e.get("lod") != "LOD0"])
    vreport = validate.run(spec)
    fails = [(r["subject"], r["check"], r["detail"]) for r in vreport.failures()]
    result = {"ok": vreport.ok, "fails": fails}
    if vreport.ok and "export" in steps:
        result["exports"] = export.run(spec, vreport)
        result["ok"] = vreport.ok
        result["fails"] = [(r["subject"], r["check"], r["detail"]) for r in vreport.failures()]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(KIT, "M_Prop_CommonsKit.blend"), check_existing=False, copy=True)
    tris = {}
    for e in spec["meshes"]:
        if e["role"] == "visual":
            tris[e.get("lod")] = tris.get(e.get("lod"), 0) + e.get("tris", 0)
    result["tris"] = tris
    out = os.path.join(common.review_dir(spec["asset"]), "%s_report.json" % common.today())
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"checks": vreport.rows, **result}, f, indent=1, default=str)
    return result
