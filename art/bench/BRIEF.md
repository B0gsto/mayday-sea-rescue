# Modelling benchmark brief: M_Kit_StretcherBasket

You are one of several AI models given this exact brief. Your result is rendered and judged against the others, so
quality of the modelled object is what counts. Work only inside your own folder. Stop as soon as the deliverables below exist.

## Your folder

- Source: `art/bench/<slug>/M_Kit_StretcherBasket/build.py` (and any helper `.py` files next to it)
- Outputs: `build/bench/<slug>/` (passed as `--out-root`; fbx, textures, review renders land there)
- `<slug>` is given in your task. Do **not** edit, move or delete anything outside these two folders. No git commits, no
  uploads, no edits to `tools/`, `docs/`, `assets/` or other assets.

## The asset

A rescue **basket stretcher** (Ferno / Stokes / "Neil Robertson"-adjacent generic, *not* a branded replica) as used by
lifeboat and coastguard crews to lift a casualty out of a boat or off rocks.

- About **2.13 x 0.61 x 0.20 m** (L x W x H), long axis on Blender **Y** (head end at -Y), base at Z 0.
- Frame: welded tubular rim (powder-coated or stainless), cross ribs and longitudinal runners under the bed, a slightly
  raised head section, a split / two-piece join at the middle (bolted sleeves) is a nice touch.
- Bed: high-visibility **orange or yellow HDPE / plastic shell** or galvanised wire mesh liner (pick one, commit to it),
  with drain holes.
- Furniture: 4 to 6 webbing **patient straps** with buckles (black or orange webbing), a foot plate, 4 lifting points /
  lifting bridle rings at the rim corners, grab handles along the rim, optional flotation collars.
- Wear: scuffs, salt, abrasion on the runners, faded plastic. Should read clearly at 6 studs (2 m) and at 30 studs.
- Look at real photos in your head before modelling: proportions and silhouette matter most.

## Pipeline (follow it, it is how the judge renders you)

Read `tools/blender/README.md` first (10 minutes, not more). Model in **studs: 1 m = 3 studs** (`common.metres_to_studs`).
Copy the spec shape from the README. Good example builds to skim (do not edit them):
`art/source/kit/E1/kitgeo.py` (kit props), `art/source/harbour/M_Hbr_Bollard_01/build.py`.

Spec values: `"name": "M_Kit_StretcherBasket"`, `"budget": "small_prop"`, `"tris": 3000`, `"tier": "standard"`,
`"dims_m": (0.61, 2.13, 0.20)`, `"origin": "base"`, one own texture set (e.g. `{"name": "StretcherBasket", "set": "Kit",
"size": 1024, "wet": True}`) written under your out-root (use `"dir"`), `_COL` if the class wants it, plus
attachments `ATT_Lift_FL/FR/RL/RR` (lifting rings) and `ATT_Casualty` (centre of the bed, top surface).
Textures: procedural or derived from CC0 scans already in the repo; PBR ALB / NOR (OpenGL) / RGH / MET + `_Wet`.

Run every Blender job through the shared lock (max 2 Blenders on this machine; you will sometimes wait in a queue, that
is normal, do not work around it):

```sh
~/RobloxProjects/tools/blender-run.sh tools/blender/run.py -- --build art/bench/<slug>/M_Kit_StretcherBasket/build.py \
  --out-root build/bench/<slug> --no-template --steps build,lod,validate,export,turntable
python3 tools/blender/sheet.py --asset M_Kit_StretcherBasket --out-root build/bench/<slug>
```

`build()` returns LOD0 (+ `_COL`) only: the `lod` step makes `_LOD1` / `_LOD2` itself and crashes if you already made them.
Pipe long output through `tail -40`. Iterate: build, look at the validate report, fix, rebuild. You may look at
your own turntable renders (downscale first: `sips -Z 768 in.png --out small.png`) to fix obvious problems. Cap
yourself at about 6 Blender runs.

## Deliverables (then stop)

1. `build.py` that runs cleanly through the command above.
2. `build/bench/<slug>/` containing the export, textures, turntable and the contact sheet from `sheet.py`.
3. `art/bench/<slug>/RESULT.md`, under 200 words: validate pass/fail (and which checks failed), LOD0 / LOD1 / LOD2 tris,
   number of Blender runs, what you would improve with more time.

Your final reply: the RESULT.md text and the path of the contact sheet. Nothing else.
