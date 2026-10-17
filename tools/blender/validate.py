"""The `validate` step (docs/12-asset-list.md section 1.1 and the definition of done, 1.4). Any failed row fails the
build and nothing is exported.

Checks: names (12 1.3), real size against dims_m x 3 studs per metre and the reference board's dims.md (05 4.1),
LOD0 / per-MeshPart / LOD1 / LOD2 triangle budgets (budgets.py), one material per mesh, one UV set in 0..1 on every
LOD with the LOD0 layout kept, texel density per tier (05 5.3), PBR maps present per texture set at a power-of-two
size at or under EXPORT_CAP, the _COL proxy, ATT_* attachment names, transforms applied, scene units.
Map content (value ranges, OpenGL normals, single-channel) is check_textures.py's job, outside Blender.

The rule functions near the top are pure (tested by test_validate.py with the system python3); the mesh checks need bpy.
Ported from Gulp's validate.py; vertex colours, palette, outline shells and creature rigs dropped.
"""
import os

import budgets
import common
import names
import uvlayout

try:
    import bmesh
    import bpy
except ImportError:          # pure rules stay importable without Blender
    bpy = bmesh = None


class Report:
    def __init__(self):
        self.rows = []

    def add(self, subject, check, ok, detail="", waiver=None, info=False):
        """A failed check passes only with a waiver: a stated reason, logged in the report. info rows never fail."""
        waived = bool(not ok and waiver)
        if waived:
            detail = "WAIVED (%s): %s" % (waiver, detail)
        ok = bool(ok) or waived or info
        self.rows.append({"subject": subject, "check": check, "ok": ok, "waived": waived, "info": info, "detail": str(detail)})
        return ok

    @property
    def ok(self):
        return all(r["ok"] for r in self.rows)

    def failures(self):
        return [r for r in self.rows if not r["ok"]]

    def print(self, tag="validate"):
        for r in self.rows:
            mark = "INFO" if r["info"] else "WAIV" if r["waived"] else "PASS" if r["ok"] else "FAIL"
            print("[%s] %s  %-26s %-24s %s" % (tag, mark, r["subject"], r["check"], r["detail"]))
        print("[%s] %s: %d checks, %d failed, %d waived" % (tag, "PASS" if self.ok else "FAIL", len(self.rows),
                                                          len(self.failures()), sum(r["waived"] for r in self.rows)))


# ---------------------------------------------------------------- pure rules

def size_rows(asset, bbox_studs, dims_m, note=None, ref_dims=None, ref_path=None):
    """Rows for the real-size check. bbox_studs: (x, y, z) of the LOD0 bounding box in studs (= Blender units);
    dims_m: the spec's real size in metres (None for an axis it does not fix); ref_dims: dims.md's, when present."""
    rows = []
    if not dims_m:
        rows.append((asset, "real size", False, "spec has no dims_m (real size from the reference board)", False))
        return rows
    if ref_dims is None:
        rows.append((asset, "reference dims", True, "no art/reference/%s/dims.md yet: spec dims_m used as given (verify)" % asset, True))
    else:
        agree = all(r is None or s is None or abs(r - s) <= 0.01 * r for r, s in zip(ref_dims, dims_m))
        rows.append((asset, "reference dims", agree, "dims.md %s, spec %s (%s)" % (_fmt(ref_dims), _fmt(dims_m),
                                                                                     os.path.relpath(ref_path, common.REPO_DIR)), False))
    worst, verdicts = 0.0, []
    for axis, have, want_m in zip("xyz", bbox_studs, dims_m):
        if want_m is None:
            continue
        want = common.metres_to_studs(want_m)
        ok, waived, dev = budgets.size_verdict(have, want, note)
        verdicts.append((ok, waived))
        worst = max(worst, dev)
        rows.append((asset, "real size %s" % axis, ok,
                     "%.3f studs, real %.3f m = %.3f studs, off %.1f%% (%d%% free, %d%% with a note)%s"
                     % (have, want_m, want, 100 * dev, 100 * budgets.SIZE_FREE, 100 * budgets.SIZE_NOTED,
                        "; NOTE: %s" % note if waived else ""), False))
    return rows


def _fmt(d):
    return " x ".join("-" if v is None else "%g" % v for v in d) + " m"


def tri_rows(asset, budget_class, totals, asset_tris=None, waivers=None):
    """Rows for the asset's LOD0 / LOD1 / LOD2 totals. totals: {'LOD0': n, 'LOD1': n, ...} (LODs present)."""
    waivers = waivers or {}
    rows = []
    r = budgets.row(budget_class)
    ceil0 = budgets.lod0_ceiling(budget_class, asset_tris)
    rows.append((asset, "LOD0 triangles", totals.get("LOD0", 0) <= ceil0 and totals.get("LOD0", 0) > 0,
                 "%d of %d (%s%s)" % (totals.get("LOD0", 0), ceil0, budget_class, ", asset row" if asset_tris else ""), None))
    if r.get("tris_min") and not asset_tris:
        rows.append((asset, "LOD0 floor", totals.get("LOD0", 0) >= r["tris_min"], "%d, at least %d" % (totals.get("LOD0", 0), r["tris_min"]),
                     waivers.get("LOD0 floor")))
    want = budgets.lods_made(budget_class)
    for lod in ("LOD1", "LOD2"):
        ceiling = budgets.lod_ceiling(budget_class, lod, asset_tris)
        if lod in want:
            have = totals.get(lod)
            rows.append((asset, "%s triangles" % lod, have is not None and 0 < have <= ceiling,
                         "%s of %d" % ("missing" if have is None else have, ceiling), waivers.get("%s triangles" % lod)))
        elif lod in totals:
            rows.append((asset, "%s triangles" % lod, False, "%s has no %s (%s)" % (budget_class, lod,
                         "culled" if lod == "LOD2" else "only ever close"), waivers.get("%s triangles" % lod)))
    return rows


def part_row(name, tris, budget_class):
    limit = min(budgets.per_part_ceiling(budget_class), budgets.ROBLOX_TRI_LIMIT)
    return (name, "per-MeshPart triangles", tris <= limit, "%d of %d" % (tris, limit), None)


def map_rows(spec_name, sets, textures_dir_fn, cap=common.EXPORT_CAP):
    """Rows for PBR map presence and size per texture set. sets: [{'name', 'set', 'wet', 'dir'?}]."""
    rows = []
    for s in sets:
        directory = s.get("dir") or textures_dir_fn()
        sizes = {}
        for kind in common.MAP_KINDS:
            for wet in ((False, True) if s.get("wet") and kind in ("ALB", "RGH") else (False,)):
                stem = names.texture_stem(s["name"], s["set"], kind, wet)
                problem = names.texture_name_problem(stem)
                path = common.map_file(directory, stem) if problem is None else None
                size = common.image_size(path) if path else None
                if size:
                    sizes[stem] = size
                ok = problem is None and size is not None and all(common.is_pow2(v) and v <= cap for v in size)
                rows.append((stem, "PBR map", ok, problem or ("%d x %d, cap %d, %s" % (size[0], size[1], cap, os.path.relpath(path, common.REPO_DIR))
                                                             if size else "missing in %s" % os.path.relpath(directory, common.REPO_DIR)), None))
        if len(set(sizes.values())) > 1:
            rows.append(("%s_%s" % (s["name"], s["set"]), "set sizes match", False,
                         ", ".join("%s %dx%d" % (k, v[0], v[1]) for k, v in sorted(sizes.items())), None))
    return rows


# ---------------------------------------------------------------- Blender side

def triangle_count(mesh):
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def is_identity(matrix, eps=1e-5):
    n = len(matrix)
    return all(abs(matrix[i][j] - (1.0 if i == j else 0.0)) < eps for i in range(n) for j in range(n))


def world_bounds(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = [min(p[i] for p in pts) for i in range(3)]
    hi = [max(p[i] for p in pts) for i in range(3)]
    return lo, hi


def classify(spec):
    """Fills role and lod of every mesh entry from its name suffix when not given."""
    for e in spec["meshes"]:
        try:
            suffix = names.mesh_parts(e["object"].name)["suffix"]
        except ValueError:
            suffix = None
        e.setdefault("role", "col" if suffix == "COL" else "hp" if suffix == "HP" else "visual")
        if e["role"] == "visual":
            e.setdefault("lod", suffix if suffix in common.LOD_SUFFIXES else "LOD0")


def entries(spec, role, lod=None):
    return [e for e in spec["meshes"] if e["role"] == role and (lod is None or e.get("lod") == lod)]


def check_mesh(spec, e, report, lod0_stats):
    obj, mesh = e["object"], e["object"].data
    add = lambda check, ok, detail="", info=False: report.add(obj.name, check, ok, detail,
                                                              waiver=spec.get("waivers", {}).get(check), info=info)
    problem = names.mesh_name_problem(obj.name)
    add("naming", problem is None and mesh.name == obj.name, problem or ("object and mesh named %s" % obj.name
                                                                       if mesh.name == obj.name else "mesh data is named %s" % mesh.name))
    tris = triangle_count(mesh)
    e["tris"] = tris
    add("transforms applied", is_identity(obj.matrix_world), "location, rotation and scale")
    if e["role"] == "hp":
        return
    name, check, ok, detail, _ = part_row(obj.name, tris, spec["budget"])
    add(check, ok, detail)

    bm = bmesh.new()
    bm.from_mesh(mesh)
    open_edges = sum(1 for ed in bm.edges if not ed.is_manifold)
    loose = sum(1 for v in bm.verts if not v.link_faces)
    min_area = min((f.calc_area() for f in bm.faces), default=0.0)
    bm.free()
    if e["role"] == "col":
        add("COL closed", open_edges == 0 and loose == 0, "%d open edges, %d loose verts" % (open_edges, loose))
        add("COL triangles", tris <= budgets.COL_MAX_TRIS, "%d of %d" % (tris, budgets.COL_MAX_TRIS))
        return
    add("geometry", loose == 0 and min_area > 1e-8,
        "%d loose verts, smallest face %.2e, %d open edges (open edges allowed on cards and decals)" % (loose, min_area, open_edges))
    slots = {p.material_index for p in mesh.polygons}
    add("one material", len(mesh.materials) == 1 and slots == {0}, "%d material slot(s)" % len(mesh.materials))

    uv_names = [u.name for u in mesh.uv_layers]
    if not add("one UV set", uv_names == [common.UV_NAME], "UV sets: %s" % (", ".join(uv_names) or "none")):
        return
    stats = uvlayout.mesh_stats(mesh)
    e["uv"] = stats
    if not spec.get("tiling"):
        add("UVs in 0..1", uvlayout.in_unit_square(stats), "u %.3f to %.3f, v %.3f to %.3f"
            % (stats["min"][0], stats["max"][0], stats["min"][1], stats["max"][1]))
    add("UV faces", stats["zero_area_faces"] <= 0.01 * max(stats["faces"], 1),
        "%d of %d faces have no UV area" % (stats["zero_area_faces"], stats["faces"]))
    if e["lod"] != "LOD0":
        src = lod0_stats.get(names.mesh_base(obj.name))
        if src is None:
            add("LOD UV layout", False, "no LOD0 mesh %s_LOD0" % names.mesh_base(obj.name))
        else:
            ok, detail = uvlayout.compare_layouts(src, stats)
            add("LOD UV layout", ok, detail)
    else:
        size = texture_size_of(spec, e)
        if size and not spec.get("tiling"):
            d = uvlayout.texel_density(mesh, size)
            e["texel_density"] = round(d, 1)
            ok, rule = uvlayout.density_verdict(d, budgets.texel_target(spec.get("tier", "standard")), budgets.TEXEL_TOLERANCE)
            add("texel density", ok, "%.0f px/stud at %d px, %s tier %s" % (d, size, spec.get("tier", "standard"), rule))


def texture_size_of(spec, e):
    sets = spec.get("sets", [])
    want = e.get("set") or (sets[0]["set"] if len(sets) == 1 else None)
    for s in sets:
        if s["set"] == want:
            return s.get("size", common.EXPORT_CAP)
    return None


def run(spec):
    report = Report()
    classify(spec)
    asset = spec.get("asset", spec["name"])
    budget_class = spec["budget"]
    waivers = spec.get("waivers", {})

    us = bpy.context.scene.unit_settings
    report.add(asset, "scene units", us.scale_length == 1.0 and us.system in ('NONE', 'METRIC'),
               "unit system %s, scale %.3f (1 unit = 1 stud)" % (us.system, us.scale_length))
    report.add(asset, "budget class", budget_class in budgets.BUDGETS, budget_class)

    lod0 = entries(spec, "visual", "LOD0")
    lod0_stats = {}
    for e in sorted(spec["meshes"], key=lambda e: e.get("lod") or "Z"):      # LOD0 first, so LODs compare against it
        check_mesh(spec, e, report, lod0_stats)
        if e["role"] == "visual" and e.get("lod") == "LOD0" and "uv" in e:
            lod0_stats[names.mesh_base(e["object"].name)] = e["uv"]

    totals = {}
    for e in entries(spec, "visual"):
        totals[e["lod"]] = totals.get(e["lod"], 0) + e.get("tris", 0)
    for row in tri_rows(asset, budget_class, totals, spec.get("tris"), waivers):
        report.add(*row[:4], waiver=row[4])

    if lod0:
        lo, hi = world_bounds([e["object"] for e in lod0])
        dims = tuple(h - l for l, h in zip(lo, hi))
        spec["bbox_studs"] = dims
        ref, ref_path = common.reference_dims(asset)
        for subject, check, ok, detail, info in size_rows(asset, dims, spec.get("dims_m"), spec.get("size_note"), ref, ref_path):
            report.add(subject, check, ok, detail, waiver=waivers.get(check), info=info)
        origin = spec.get("origin", "base")
        centre = [(l + h) / 2.0 for l, h in zip(lo, hi)]
        if origin == "base":
            ok = abs(lo[2]) < 1e-3 and abs(centre[0]) < 0.01 * max(dims[0], 1e-3) and abs(centre[1]) < 0.01 * max(dims[1], 1e-3)
            report.add(asset, "origin", ok, "base at z %.4f, centre (%.3f, %.3f); origin is the centre of the base" % (lo[2], centre[0], centre[1]))
        elif origin == "centre":
            ok = all(abs(c) < 0.01 * max(d, 1e-3) for c, d in zip(centre, dims))
            report.add(asset, "origin", ok, "bbox centre (%.3f, %.3f, %.3f)" % tuple(centre))
    else:
        report.add(asset, "LOD0 meshes", False, "no visual LOD0 mesh")

    needs_col = budgets.row(budget_class)["col"] or spec.get("col", False)
    cols = entries(spec, "col")
    report.add(asset, "_COL proxy", bool(cols) or not needs_col,
               ", ".join(e["object"].name for e in cols) or ("required for %s" % budget_class if needs_col else "none (not required)"),
               waiver=waivers.get("_COL proxy"))

    sets = spec.get("sets", [])
    ok, rule = budgets.sets_ok(budget_class, len(sets), bool(spec.get("atlas")))
    report.add(asset, "texture sets", ok, "%d (%s)%s" % (len(sets), rule, ", atlas %s" % spec["atlas"] if spec.get("atlas") else ""),
               waiver=waivers.get("texture sets"))
    for row in map_rows(asset, sets, lambda: common.textures_dir(asset)):
        report.add(*row[:4], waiver=waivers.get(row[1]))

    # attachments: the spec's list, else every empty named ATT* or parented to one of the asset's meshes
    asset_objs = {e["object"] for e in spec["meshes"]}
    atts = spec.get("attachments") or [o for o in bpy.context.scene.objects if o.type == 'EMPTY'
                                       and (o.name.upper().startswith("ATT") or o.parent in asset_objs)]
    for o in atts:
        problem = names.attachment_name_problem(o.name)
        report.add(o.name, "attachment naming", problem is None, problem or "empty becomes an Attachment on import")
    spec["attachments"] = [o for o in atts if names.attachment_name_problem(o.name) is None]
    for check in spec.get("extra_checks", []):
        check(spec, report)
    report.print()
    return report
