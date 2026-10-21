"""Cornish hedge top vegetation: alpha cards on the shared `T_FoliageLand_Main` atlas (G1).

The card system is the land-vegetation one (`art/source/veg/G1/vegkit.py`): a bent quad strip, base at the bottom
centre, V from base to tip, U across; the cell rects are read from `G1/cells.json` so the hedge always agrees with the
atlas. Cards are emitted twice (front + reversed back, separate verts) with the SAME hemisphere ("foliage") normal
computed per card, so Roblox can keep DoubleSided off and no card goes dark on its back (vegkit's rule, applied per
card here because a 5 m hedge top is far wider than one plant's hemisphere).

Everything is built in metres; the caller scales to studs.
"""
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "../../../.."))
G1 = os.path.join(GAME, "art/source/veg/G1")
CELLS = json.load(open(os.path.join(G1, "cells.json")))["cells"]
TEX_DIR = os.path.join(GAME, "assets/textures/M_Veg_FoliageLand")

SET = {"name": "FoliageLand", "set": "Main", "size": 2048, "wet": True, "dir": TEX_DIR}

# sub-rects of the G1 cells that hold only the plant: the thrift cushion is a grass tuft in the bottom 62% of its cell
SUBCELL = {"GrassTuft": (0.25, 0.0, 0.5, 0.155)}


def cell(name):
    return SUBCELL.get(name) or CELLS[name]


class Card:
    """One bent quad strip: base point, up axis, side axis, width, height, atlas cell, bend towards +X (the wind)."""

    def __init__(self, base, up, side, w, h, cellname, segs=1, bend=0.18, bend_dir=(1, 0, 0), normal="dome"):
        self.base = Vector(base)
        self.up = Vector(up).normalized()
        self.side = Vector(side).normalized()
        self.w, self.h, self.cell, self.segs, self.bend = w, h, cellname, segs, bend
        self.bend_dir = Vector(bend_dir).normalized()
        self.normal = normal


def card_geo(c):
    """vertices, faces, uvs of one card: `segs` quads (2 * segs triangles) leaning along the bend direction."""
    u0, v0, u1, v1 = cell(c.cell)
    verts, uvs = [], []
    p, d = c.base.copy(), c.up.copy()
    step = c.h / c.segs
    pts, dirs = [p.copy()], [d.copy()]
    for i in range(c.segs):
        t = (i + 0.5) / c.segs
        d = (c.up + c.bend_dir * (c.bend * t * 1.6)).normalized()
        p = p + d * step
        pts.append(p.copy())
        dirs.append(d)
    hw = c.w * 0.5
    for i, q in enumerate(pts):
        t = i / c.segs
        for s in (-1, 1):
            verts.append(q + c.side * (hw * s))
            uvs.append((u0 + (u1 - u0) * (0.5 + 0.5 * s), v0 + (v1 - v0) * t))
    faces = [(2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2) for i in range(c.segs)]
    return verts, faces, uvs


def card_normal(c, p):
    """The card's foliage normal at p: outward from a point below the card's own base, blended towards up."""
    hc = c.base - c.up * (0.35 * c.h)
    e = max(c.h * 0.5, 0.05)
    d = p - hc
    d = Vector((d.x / e, d.y / e, d.z / (e * 1.35)))
    d = d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))
    ub = 0.55 if c.normal == "up" else 0.35
    return (d * (1 - ub) + Vector((0, 0, 1)) * ub).normalized()


def veg_object(name, cards, mat, scale=3.0):
    """Build the veg mesh: each card as two faces of one quad (front + back winding) with per-loop hemisphere
    normals (carried through the weld in a temporary loop layer), scaled to studs, one material. Welding the two
    windings onto shared vertices keeps the mesh collapse-decimation friendly: no coincident duplicate verts for the
    LOD step to strand."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    nrm = bm.loops.layers.float_vector.new("foliage_n")
    for c in cards:
        vs, fs, uvs = card_geo(c)
        for back in (False, True):
            bv = [bm.verts.new(v) for v in vs]        # its own verts: bmesh refuses a face on an existing loop set
            for f in fs:
                fi = tuple(reversed(f)) if back else f
                face = bm.faces.new([bv[i] for i in fi])
                for lp, vi in zip(face.loops, fi):
                    lp[uvl].uv = uvs[vi]
                    lp[nrm] = card_normal(c, vs[vi])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    for v in bm.verts:
        v.co *= scale
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    attr = me.attributes.get("foliage_n")
    if attr is not None and len(attr.data) == len(me.loops):
        me.normals_split_custom_set([tuple(v.vector) for v in attr.data])
        me.attributes.remove(me.attributes["foliage_n"])
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def material():
    """Preview material on the shared atlas: alpha-cut cards (the atlas ALB carries the cutout), so tufts read as
    tufts, not slabs, and the turntable can keep this material while the stones take their baked maps."""
    name = "MI_CornishHedge_Veg"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    alb = os.path.join(TEX_DIR, "T_FoliageLand_Main_ALB.png")
    if bsdf and os.path.exists(alb):
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(alb, check_existing=True)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "DITHERED"
        mat.use_backface_culling = False
        if hasattr(mat, "use_transparent_shadow"):
            mat.use_transparent_shadow = True
        bsdf.inputs["Roughness"].default_value = 0.82
    return mat


def rand_dir_xy(rng):
    a = rng.uniform(0.0, 2.0 * math.pi)
    return Vector((math.cos(a), math.sin(a), 0.0))


def fit_card(card, ceiling):
    """Shorten a card so nothing of it pokes above the ceiling: a card leans and its width spreads off its axis, so
    the fit is measured on the card's own geometry (the shape is linear in h, so one scale does it)."""
    vs, _f, _u = card_geo(card)
    top = max(v.z for v in vs)
    if top > ceiling:
        card.h = max(0.08, card.h * (ceiling - card.base.z) / max(top - card.base.z, 1e-4))
    return card


def lean_card(rng, base, up_hint, w, h, cellname, segs=1, bend=0.2, normal="dome"):
    """A card leaning along +X (the prevailing wind) with a random side axis, so a top never reads as one tile."""
    up = (Vector((0, 0, 1)) + Vector((1.0, 0, 0)) * rng.uniform(0.10, 0.45) + up_hint).normalized()
    side = Vector((rng.gauss(0, 0.35), rng.gauss(0, 0.35), 0.0)).cross(up)
    if side.length < 0.05:
        side = rand_dir_xy(rng)
    return Card(base, up, side, w, h, cellname, segs=segs, bend=bend, normal=normal)
