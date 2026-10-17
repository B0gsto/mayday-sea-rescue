# art/lookdev: shared Studio look-dev pass

`shot-setup.luau` is the `--setup` for every batch's Studio pass (`~/RobloxProjects/tools/studio-shot.py`, run under
`with-lock.sh studio` then `with-heavy.sh`; see the header of `shot-setup.luau` and `shots-example.json`). It installs
`_G.LookDev.apply(preset, wet)`, `shot`, `hideBillboards`, `restore` and `preload`.

## Wet shots render white: preload + white check (use both in every batch)

Freshly uploaded maps first needed mid-pass (the wet SurfaceAppearance swapped in by `apply(_, true)`, `_Wet`
MaterialVariants) are still loading / processing at capture time and render flat or ghost white (Bosun, K1, G1, swimmer).

1. **Preload, automatic.** The setup ends with `_G.LookDev.preload()`: every SurfaceAppearance map in workspace (active,
   and stored `SurfaceAppearance_Dry` / `_Wet` in `SurfaceVariants`), every MaterialVariant map (dry and `_Wet`) and
   MeshPart TextureIDs; stored SAs get hidden 0.05-stud carrier clones (workspace `LookDevPreload`, removed by
   `restore()`) so they are processed too; `ContentProvider:PreloadAsync` with 3 tries, waits for Success on all
   (timeout 120 s: workspace attribute `LookDevPreloadTimeout`). Its result ends the setup line studio-shot.py prints:
   `preload: N maps (S SAs, V variants, C hidden clones), F failed in T s [failed ids]`. So: insert / import the assets
   **before** running the setup (else call `_G.LookDev.preload()` again). Opt out: workspace attribute
   `LookDevNoPreload = true`. Replaces the RIB's local `assets/review/M_Veh_RIB/studio/preload.luau`.
2. **White check, add `--white-check` to the studio-shot.py call.** Shots with > 8 % pixels at luma > 245 in the asset
   area (`white_box` per shot, default central [0.15, 0.15, 0.85, 0.9]) are re-captured once after 8 s
   (`--white-check PCT`, `--white-luma`, `--white-wait`); report on stdout (`WHITE ...`, `WHITE-CHECK: ...`) and in
   `<keep>/white_check.json`.
3. **Still white after preload and the retry: the maps are wrong**, not loading. Check the wet set: ALB near-white,
   ALB saved without its alpha channel (alpha cards then render opaque), a dry/wet id mix-up. Fix the textures, re-upload.
   `assets/review/M_Veh_RIB/studio/wet_check.luau` shows how to prove the swap itself applied.

A legitimately bright shot (white hull, sea foam, snow) can trip the check: give that shot a tighter `white_box` or run
without `--white-check`.
