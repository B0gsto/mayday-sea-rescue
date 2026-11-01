# Mocap -> R15 clips (slots, takes, frames: `clips.json`; licences: `LICENSES.md`; sources in `build/mocap/src/`)
1. Retarget to `out/<Name>.json` (Blender MCP, only when no other Blender is open):
   `P = "<repo>/art/source/anim/mocap/retarget.py"; exec(open(P).read(), {"__file__": P, "__name__": "__main__", "MOCAP_ARGS": []})`
   (`MOCAP_ARGS`: clip names, empty = all; `["--scan", Name]` prints arm poses to pick frames.)
2. Hand-keyed clips (key poses in `keyed.py`; replace the mocap slot of the same name), Blender MCP:
   `P = "<repo>/art/source/anim/mocap/keyed.py"; exec(open(P).read(), {"__file__": P, "__name__": "__main__", "KEYED_ARGS": []})`
   -> `out/keyed/<Name>.json`; rig + actions saved in `keyed.blend`.
3. Build + self-check from the repo root: `lune run art/source/anim/mocap/mocap.luau [Name]` -> `art/out/anims/<Name>.rbxm`.
