# Spin cinematic flipbooks (spincine.py)

Three sheets pass the 8.5 bar and are uploaded. Flare and rays failed after the 3 allowed art-director rounds, so they are not uploaded: keep placeholders for `spincine_flare` and `spincine_rays`.

Ids are in `AssetIds.FxSpin`, emitted by `tools/gen_asset_ids.py`. They stay out of `AssetIds.Fx` because every entry there must be a `Flipbooks.SHEETS` row, and that contract has no 2x2 layout.

All sheets are 1024 RGBA with straight alpha. Frames run left to right, top to bottom. White-ish sheets are tinted with the emitter's `Color`.

| Sheet | Status | AD | Image id | Grid (rows x cols) | Frames | Mode, fps | Blend |
|---|---|---|---|---|---|---|---|
| FX_SpinBolt | uploaded | 8.5 | 83177753500457 | 2x2 (`Grid2x2`) | 4 variants | `Loop`, fps 0, random start | additive: LightEmission 1 |
| FX_SpinHaloBrick | uploaded | 9.0 | 86567871522291 | 4x4 (`Grid4x4`) | 16, seamless | `Loop`, 16 fps (one turn per second) | not additive: LightEmission 0.2, already gold, no tint |
| FX_SpinHaloRing | uploaded | 8.5 | 72996208588583 | 1x1 (`None`) | 1 | none | additive: LightEmission 1, tint gold |
| FX_SpinFlare | NOT uploaded | 7.5 | none | 4x4 (`Grid4x4`) | 16: charge 0-7, squash 8-9, burst 10, settle 11-15 | `OneShot`, about 20 fps | additive: LightEmission 1 |
| FX_SpinRays | NOT uploaded | 8.0 | none | 4x4 (`Grid4x4`) | 16: shoot 0-4, travel and fade 5-13, 14-15 empty | `OneShot`, about 20 fps | additive: LightEmission 1 |

Scores are from the round 3 critique of stills, so timing has not been judged in motion. Suggested fps and blend have not been tried in game.

Open fixes from round 3:

- **FX_SpinFlare:** charge frames 5-8 read as a flower, the peak is fussy, and the settle dots are too small for a phone.
- **FX_SpinRays:** rays thin to hairlines in frames 9-14, frame 1 is a dot ring, and the hub should be about 20% wider.

Rebuild: in the live Blender MCP session, run `runpy.run_path("art/source/fx/spincine.py", run_name="__main__")` (never `--background`). Then run `python3 art/source/fx/spincine_contact.py`. Scene: `spincine.blend`. PNGs are gitignored: `build/prod/spincine/` and the main checkout's `build/status/2026-11-01/spincine/art/`.
