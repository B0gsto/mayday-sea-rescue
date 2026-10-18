#!/usr/bin/env python3
"""Write the baked terrain in Roblox Studio and save it as map/terrain/Terrain.rbxm (see tools/world/README.md).

usage: python3 tools/world/studio_terrain.py [--no-close] [--export-only]

1. Lune stages map/generated/* into a copy of build/MaydaySeaRescue.rbxl (build/world/TerrainWork.rbxl).
2. tools/studio-open.py opens it as TestBench-MaydayTerrain (a scratch window; never another project's window).
3. Under the machine-wide Studio lock: execute_luau runs tools/world/write_terrain.luau in batches of tile rows
   (WriteVoxels), adds the Needle's Eye rock arch, then exports Terrain through SerializationService and writes the
   bytes to map/terrain/Terrain.rbxm.
4. Closes the TestBench window (Don't Save) unless --no-close."""
import base64, json, math, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TOOLS = os.path.expanduser("~/RobloxProjects/tools")
sys.path.insert(0, TOOLS)
sys.path.insert(0, HERE)
from studio import StudioSession, studio_lock  # noqa: E402
import layout as L  # noqa: E402

TAG = "MaydayTerrain"
WRITER = open(os.path.join(HERE, "write_terrain.luau")).read()


def lua_args(d):
    def v(x):
        if isinstance(x, dict):
            return "{" + ", ".join(f"{k} = {v(y)}" for k, y in x.items()) + "}"
        return json.dumps(x)
    return f"local ARGS = {v(d)}\n"


def main():
    work = os.path.join(REPO, "build/world/TerrainWork.rbxl")
    os.makedirs(os.path.dirname(work), exist_ok=True)
    export_only = "--export-only" in sys.argv  # TestBench-MaydayTerrain is already open with the terrain (e.g. a build)
    if not export_only:
        subprocess.run(["lune", "run", os.path.join(HERE, "make_work_place.luau"),
                    os.path.join(REPO, "build/MaydaySeaRescue.rbxl"), work, os.path.join(REPO, "map/generated")],
                       check=True)
        subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), work, "--tag", TAG], check=True)
    meta = json.load(open(os.path.join(REPO, "map/generated/terrain.json")))
    rows = (meta["nx"] - 1) // 64
    (gx0, gz0), (gx1, gz1) = L.GULLY["from"], L.GULLY["to"]
    glen = math.hypot(gx1 - gx0, gz1 - gz0)
    poi = next(p for p in L.POIS if p["id"] == "GullyArch")
    arch = {"x": poi["pos"][0], "y": L.GULLY["floorY"] + 2, "z": poi["pos"][2], "ax": -(gz1 - gz0) / glen,
            "az": (gx1 - gx0) / glen, "radius": L.GULLY["halfWidth"] + 8, "thick": 7}
    t0 = time.time()
    with studio_lock("mayday world terrain"):
        with StudioSession() as s:
            sid = s.studio_id(prefer="TestBench-" + TAG)

            def run(args, timeout=600):
                ok, texts, _ = s.call("execute_luau", {"studio_id": sid, "datamodel_type": "Edit",
                                                       "code": lua_args(args) + WRITER}, timeout)
                out = " ".join(texts)
                if not ok:
                    raise RuntimeError(out[:2000])
                return out

            step = 4
            for r0 in range(0, rows if not export_only else 0, step):
                print(run({"mode": "write", "row0": r0, "row1": min(rows, r0 + step)})[:200], flush=True)
            if not export_only:
                print(run({"mode": "arch", "arch": arch}))
            print(run({"mode": "colors"}))
            chunks, offset, total, n = [], 0, None, 72_000  # execute_luau output is cut near 100,000 chars
            while total is None or offset < total:
                out = run({"mode": "export", "offset": offset, "length": n})
                head, _, body = out.strip().partition("|")
                total = int(head.split()[-1])
                chunks.append(base64.b64decode(body.strip()))
                offset += n
            raw = b"".join(chunks)
            assert len(raw) == total, (len(raw), total)
            print(run({"mode": "probe"}))
    out_path = os.path.join(REPO, "map/terrain/Terrain.rbxm")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "wb") as f:
        f.write(raw)
    print(f"wrote {out_path} ({len(raw)} bytes) in {time.time() - t0:.0f}s under the Studio lock")
    # T4: Decoration on (short wind-animated blades on the Grass / Turf sward, tinted olive by the Grass MaterialColor)
    subprocess.run(["lune", "run", os.path.join(HERE, "terrain_decoration.luau"), out_path, "true", "0.3"], check=True)  # T6: 0.3 (0.5 blades read large and low-poly)
    if "--no-close" not in sys.argv:
        subprocess.run([sys.executable, os.path.join(TOOLS, "studio-open.py"), "--close", TAG], check=False)


if __name__ == "__main__":
    main()
