"""The `export` step (docs/12 1.1): one FBX per LOD into assets/fbx/<Asset>/, through the shared rbxkit.export_fbx
(~/RobloxProjects/tools/blender/rbxkit.py), whose axis and scale mapping was measured in Studio:
axis_forward '-Z', axis_up 'Y', FBX_SCALE_UNITS, global scale 1, so 1 Blender unit = 1 stud and roblox = (-bx, bz, by).
Constants live there, not here. Textures are not embedded (maps upload separately as Images for SurfaceAppearance).

Files: <Name>_LOD0.fbx (LOD0 meshes plus the _COL proxies), <Name>_LOD1.fbx, <Name>_LOD2.fbx, and
<Name>.attachments.json (every ATT_* empty in Roblox axes, since empties may not survive the importer; verify).
Every file is read back: units, axes, mesh names, all triangles, triangle count.
"""
import json
import os
import re

import bpy

import common
import names
import rbxkit

# What rbxkit.export_fbx writes, read back from its files (S0 measurement in the selftest, 2026-10-17): FBX_SCALE_UNITS
# with the factory scene (metric, scale 1) stores UnitScaleFactor 100 (centimetres) and leaves vertices in Blender units.
EXPECTED_UNIT_SCALE = 100.0
EXPECTED_AXES = (1, 1, 2, 1)     # UpAxis Y +, FrontAxis Z (sign as Blender writes it for axis_forward '-Z')


def recorded_settings():
    return {"exporter": "rbxkit.export_fbx", "axis_forward": "-Z", "axis_up": "Y", "apply_scale_options": "FBX_SCALE_UNITS",
            "global_scale": 1.0, "embed_textures": False, "mapping": "roblox = (-bx, bz, by), 1 BU = 1 stud",
            "roblox_tri_limit": rbxkit.ROBLOX_TRI_LIMIT}


def _props(elem):
    for child in elem.elems:
        if child.id == b'Properties70':
            return {p.props[0].decode(): list(p.props[4:]) for p in child.elems}
    return {}


def _name(raw):
    return raw.split(b'\x00\x01')[0].decode()


def _parse_fbx():
    import importlib
    for base in ("io_scene_fbx", "bl_ext.blender_org.io_scene_fbx"):
        try:
            return importlib.import_module(base + ".parse_fbx")
        except ImportError:
            continue
    raise RuntimeError("io_scene_fbx.parse_fbx is not importable")


def inspect_fbx(path):
    """Reads back what was written: units, axes, mesh names, triangles."""
    root, version = _parse_fbx().parse(path)
    info = {"file": os.path.relpath(path, common.REPO_DIR), "bytes": os.path.getsize(path), "fbx_version": version,
            "meshes": [], "geometry": []}
    for elem in root.elems:
        if elem.id == b'GlobalSettings':
            p = _props(elem)
            info["unit_scale_factor"] = p.get("UnitScaleFactor", [None])[0]
            info["axes"] = tuple(p.get(k, [None])[0] for k in ("UpAxis", "UpAxisSign", "FrontAxis", "FrontAxisSign"))
        elif elem.id == b'Objects':
            for obj in elem.elems:
                kind = obj.props[2] if len(obj.props) > 2 else b''
                if obj.id == b'Model' and kind == b'Mesh':
                    info["meshes"].append(_name(obj.props[1]))
                elif obj.id == b'Geometry' and kind == b'Mesh':
                    g = {"name": _name(obj.props[1])}
                    for child in obj.elems:
                        if child.id == b'Vertices':
                            v = child.props[0]
                            g["min"] = [round(min(v[i::3]), 4) for i in range(3)]
                            g["max"] = [round(max(v[i::3]), 4) for i in range(3)]
                        elif child.id == b'PolygonVertexIndex':
                            idx = child.props[0]
                            g["polygons"] = sum(1 for i in idx if i < 0)
                            g["all_triangles"] = len(idx) == 3 * g["polygons"]
                        elif child.id == b'LayerElementUV':
                            g["uv"] = True
                    info["geometry"].append(g)
    return info


def attachments_table(spec):
    """ATT_* empties: Blender position, and the Roblox offset from the LOD0 bounding-box centre (where the imported
    MeshPart / Model pivot lands) plus look and up vectors, all in Roblox axes."""
    lod0 = [e["object"] for e in spec["meshes"] if e["role"] == "visual" and e.get("lod") == "LOD0"]
    pts = [o.matrix_world @ v.co for o in lod0 for v in o.data.vertices]
    centre = [(min(p[i] for p in pts) + max(p[i] for p in pts)) / 2.0 for i in range(3)] if pts else [0.0, 0.0, 0.0]
    rows = []
    for o in spec.get("attachments", []):
        m = o.matrix_world
        loc = tuple(m.translation)
        fwd = tuple(-m.col[1][i] for i in range(3))       # an empty's local -Y is its front (Blender -Y = Roblox forward)
        up = tuple(m.col[2][i] for i in range(3))
        rows.append({"name": o.name, "parent": o.parent.name if o.parent else None,
                     "blender": [round(c, 4) for c in loc],
                     "roblox_from_origin": [round(c, 4) for c in rbxkit.rbx_from_blender(loc)],
                     "roblox_from_bbox_centre": [round(c, 4) for c in rbxkit.rbx_from_blender([a - b for a, b in zip(loc, centre)])],
                     "look": [round(c, 4) for c in rbxkit.rbx_from_blender(fwd)],
                     "up": [round(c, 4) for c in rbxkit.rbx_from_blender(up)]})
    return {"asset": spec.get("asset"), "units": "studs", "mapping": "roblox = (-bx, bz, by)", "attachments": rows}


def run(spec, report):
    asset = spec.get("asset", spec["name"])
    out = common.fbx_dir(asset)
    files = []
    groups = {}
    for e in spec["meshes"]:
        if e["role"] == "visual":
            groups.setdefault(e["lod"], []).append(e["object"])
        elif e["role"] == "col":
            groups.setdefault("LOD0", []).append(e["object"])
    for lod in sorted(groups):
        objs = groups[lod]
        stem = "%s_%s" % (spec["name"], lod)
        path = os.path.join(out, stem + ".fbx")
        rbxkit.export_fbx(objs, path, bake_z=False, embed_textures=False)
        info = inspect_fbx(path)
        files.append(info)
        add = lambda check, ok, detail="": report.add(stem + ".fbx", check, ok, detail)
        add("file naming", names.mesh_name_problem(stem) is None, os.path.relpath(path, common.REPO_DIR))
        add("units", abs((info.get("unit_scale_factor") or 0.0) - EXPECTED_UNIT_SCALE) < 1e-6,
            "UnitScaleFactor %s (rbxkit FBX_SCALE_UNITS, global scale 1; expected %s)" % (info.get("unit_scale_factor"), EXPECTED_UNIT_SCALE))
        add("axes", info.get("axes") == EXPECTED_AXES, "UpAxis, sign, FrontAxis, sign = %s, expected %s" % (info.get("axes"), EXPECTED_AXES))
        want = sorted(o.name for o in objs)
        tris = sum(g.get("polygons", 0) for g in info["geometry"])
        want_tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
        add("meshes", sorted(info["meshes"]) == want and all(g.get("all_triangles") for g in info["geometry"]) and tris == want_tris,
            "%s; %d triangles (scene %d)" % (", ".join(sorted(info["meshes"])), tris, want_tris))
        visual = [g for g in info["geometry"] if not re.sub(r"\.\d+$", "", g["name"]).endswith("_COL")]   # exporter temp meshes get .001
        add("UVs exported", all(g.get("uv") for g in visual), "UV layer on %d of %d visual meshes" % (sum(bool(g.get("uv")) for g in visual), len(visual)))
        print("[export] %s  %d bytes, %d triangles" % (info["file"], info["bytes"], tris))
    table = attachments_table(spec)
    path = os.path.join(out, spec["name"] + ".attachments.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(table, f, indent=1)
    files.append({"file": os.path.relpath(path, common.REPO_DIR), "attachments": [r["name"] for r in table["attachments"]]})
    print("[export] %s  %d attachments" % (os.path.relpath(path, common.REPO_DIR), len(table["attachments"])))
    return files
