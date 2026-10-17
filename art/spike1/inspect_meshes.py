#!/usr/bin/env python3
"""Spike 1: for every downloaded Spike1 .rbxm, run rbxm-inspect (lune) for MeshPart / Size / Bone counts, then fetch the
MeshContent mesh asset through asset delivery (assets.py, the key is read there and never printed) and parse the Roblox
mesh header for the triangle count actually stored (decimation evidence) and LOD count.
usage: python3 art/spike1/inspect_meshes.py   -> art/spike1/rbxm_findings.json (+ cached meshes in art/spike1/meshcache/)"""
import glob, json, os, re, struct, subprocess, sys

G = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
import assets  # noqa: E402

CACHE = os.path.join(G, "art", "spike1", "meshcache")


def parse_mesh(b):
    head = b[:16].split(b"\n")[0].decode(errors="replace")
    out = {"version": head}
    m = re.match(r"version (\d+)\.(\d+)", head)
    if not m:
        return out
    major = int(m.group(1))
    p = len(head) + 1
    if major == 2:
        sz, vs, fs, nv, nf = struct.unpack_from("<HBBII", b, p)
        out.update(verts=nv, faces_all_lods=nf, lods=1, lod0_tris=nf)
    elif major in (4, 5):
        sz, lodtype, nv, nf, nlod, nbones, _bn, nsub = struct.unpack_from("<HHIIHHIH", b, p)
        out.update(verts=nv, faces_all_lods=nf, lods=nlod, bones=nbones, bone_subsets=nsub)
        vsize = 40
        off = p + sz + nv * vsize + (nv * 8 if nbones else 0) + nf * 12
        if nlod:
            lo = struct.unpack_from(f"<{nlod}I", b, off)
            out["lod_offsets"] = list(lo)
            out["lod0_tris"] = lo[1] - lo[0] if nlod > 1 else nf
    elif major == 3:
        sz, vs, fs, lodsz, nlod, nv, nf = struct.unpack_from("<HBBHHII", b, p)
        out.update(verts=nv, faces_all_lods=nf, lods=nlod)
    elif major >= 6:  # chunked: COREMESH / LODS / SKINNING ...
        q, chunks = p, {}
        while q + 16 <= len(b):
            ctype = b[q:q + 8].rstrip(b"\0").decode(errors="replace")
            ver, size = struct.unpack_from("<II", b, q + 8)
            chunks[ctype] = (q + 16, ver, size)
            q += 16 + size
        out["chunks"] = list(chunks)
        if "COREMESH" in chunks:
            s0, ver, _ = chunks["COREMESH"]
            if ver == 1:
                nv, = struct.unpack_from("<I", b, s0)
                nf, = struct.unpack_from("<I", b, s0 + 4 + nv * 40)
                out.update(verts=nv, faces_all_lods=nf)
            else:
                out["coremesh_version"] = ver   # v2 is Draco-compressed: counts not readable here
        if "LODS" in chunks:
            s0, ver, _ = chunks["LODS"]
            lodtype, nhq, n = struct.unpack_from("<HBI", b, s0)
            lo = struct.unpack_from(f"<{n}I", b, s0 + 7)
            out.update(lods=n, lod_offsets=list(lo))
            if n > 1:
                out["lod0_tris"] = lo[1] - lo[0]
        if "SKINNING" in chunks:
            s0, ver, _ = chunks["SKINNING"]
            out["skinning_chunk_version"] = ver
    return out


def main():
    os.makedirs(CACHE, exist_ok=True)
    res = {}
    for f in sorted(glob.glob(os.path.join(G, "assets", "models", "M_Spike1_*.rbxm"))):
        name = os.path.basename(f)[:-5]
        dump = subprocess.run(["lune", "run", os.path.join(TOOLS, "rbxm-inspect.luau"), f], capture_output=True).stdout.decode("utf-8", "replace")
        lines = dump.splitlines()
        r = {"rbxm": os.path.relpath(f, G),
             "classes": {}, "sizes": [l.split("=", 1)[1].strip() for l in lines if l.strip().startswith("Size =")],
             "skinned": [l.split("=", 1)[1].strip() for l in lines if "HasSkinnedMesh" in l]}
        for l in lines:
            mm = re.match(r"^\s*([A-Z][A-Za-z]+) \S", l)
            if mm and " = " not in l:
                r["classes"][mm.group(1)] = r["classes"].get(mm.group(1), 0) + 1
        ids = re.findall(r"MeshContent = Content Content\(Uri=rbxassetid://(\d+)\)", dump)
        r["meshes"] = []
        for mid in ids:
            path = os.path.join(CACHE, mid + ".mesh")
            if not os.path.exists(path):
                try:
                    open(path, "wb").write(assets._download_delivery(mid))
                except Exception as e:  # noqa: BLE001
                    r["meshes"].append({"id": mid, "error": str(e)[:200]})
                    continue
            r["meshes"].append({"id": mid, **parse_mesh(open(path, "rb").read())})
        res[name] = r
        print(name, r["classes"], r["sizes"], r["skinned"], [{k: v for k, v in x.items() if k != "lod_offsets"} for x in r["meshes"]])
    json.dump(res, open(os.path.join(G, "art", "spike1", "rbxm_findings.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
