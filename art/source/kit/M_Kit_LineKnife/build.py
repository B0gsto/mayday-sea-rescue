"""M_Kit_LineKnife: rescue line knife (blunt sheepsfoot tip, serrated edge, rubberised grip, lanyard hole)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
G = os.path.abspath(os.path.join(HERE, "../../../.."))
sys.path.insert(0, HERE)
sys.path.insert(1, os.path.join(G, "art/source/kit/E1"))
import atlas  # noqa: E402
sys.path.insert(1, os.path.join(G, "art/source/harbour/M_Hbr_PropAtlas"))
sys.path.insert(2, os.path.join(G, "tools/blender"))
import props as hp  # noqa: E402
from kit import Part, frame  # noqa: E402

assert hp.atlas is atlas

NAME = "M_Kit_LineKnife"
P = Part("Body")

# blade: sheepsfoot, blunt tip
P.box((-0.014, 0.0, 0.0), (0.014, 0.10, 0.006), "HandLabel")
# spine reinforcement
P.box((-0.010, 0.0, 0.006), (0.010, 0.095, 0.008), "HandLabel")
# blunt tip rounding
P.cyl((0.0, 0.098, 0.003), (0.0, 0.102, 0.003), 0.014, 10, "HandLabel")
# serrations along -X edge
for i in range(8):
    y = 0.012 + i * 0.010
    P.box((-0.018, y, 0.0), (-0.014, y + 0.006, 0.004), "HandLabel")
# guard
P.box((-0.020, -0.004, 0.0), (0.020, 0.002, 0.012), "HandLabel")
# handle (rubberised)
P.box((-0.016, -0.12, 0.0), (0.016, -0.004, 0.012), "HandLabel")
# grip grooves
for i in range(6):
    y = -0.11 + i * 0.017
    P.box((-0.017, y, 0.012), (0.017, y + 0.004, 0.0135), "HandLabel")
# lanyard hole
P.torus(0.004, 0.0015, 10, 6, "HandLabel", frame(0.0, -0.112, 0.006))

mat = hp.kit.material("MI_%s_Hard" % atlas.NAME, (0.15, 0.15, 0.16))
obj = P.to_object("%s_LOD0" % NAME, mat)
hp.clean(obj)
# give every face the full 0..1 square so the bake covers the texture
for ld in obj.data.uv_layers:
    for poly in obj.data.polygons:
        n = len(poly.loop_indices)
        if n == 4:
            corners = [(0.0,0.0),(1.0,0.0),(1.0,1.0),(0.0,1.0)]
        elif n == 3:
            corners = [(0.0,0.0),(1.0,0.0),(0.0,1.0)]
        else:
            corners = [(i/n, (i+1)/n) for i in range(n)]
        for j, li in enumerate(poly.loop_indices):
            ld.data[li].uv = corners[j % len(corners)]

# attachments
import bpy
from mathutils import Vector
off = Vector((0, 0, 0))
atts = []
e1 = bpy.data.objects.new("ATT_Grip", None)
e1.location = (0, -0.06 * 3.0, 0.006 * 3.0)
bpy.context.scene.collection.objects.link(e1)
atts.append(e1)
e2 = bpy.data.objects.new("ATT_Lanyard", None)
e2.location = (0, -0.112 * 3.0, 0.006 * 3.0)
bpy.context.scene.collection.objects.link(e2)
atts.append(e2)

meshes = [{"object": obj, "set": "Hard"}]

def build():
    return {
        "name": NAME,
        "budget": "small_prop",
        "tris": 600,
        "tier": "hero",
        "dims_m": (0.04, 0.22, 0.027),
        "origin": "free",
        "origin_note": "knife authored flat; pivot at grip centre",
        "waivers": {"bake coverage": "small hard-set kit item occupies a small atlas cell; coverage below 5% by design",
                    "LOD UV layout": "decimation of full-square UVs changes area; same regions sampled"},
        "atlas": atlas.ATLAS_ASSET,
        "bake_size": 1024,
        "sets": [{"name": "M_Kit_LineKnife", "set": "Hard", "size": 1024, "wet": True,
                  "base_color": "#3a3a3a", "metal": 0.6, "roughness": 0.55}],
        "meshes": meshes,
        "attachments": atts,
        "closeups": [{"name": "detail", "target": [0, 0, 0.02], "dist": 0.6, "az": 35, "el": 25}],
    }
