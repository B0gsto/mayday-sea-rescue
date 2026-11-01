# Mocap source licences

Raw downloads live in `build/mocap/src/<source>/` (gitignored, local only). Candidate list: `build/mocap/CANDIDATES.md`.

## Sources

### Quaternius Universal Animation Library 1 and 2 (Standard, free tier)
- URLs: https://quaternius.itch.io/universal-animation-library , https://quaternius.itch.io/universal-animation-library-2
- Licence: CC0 1.0 Universal (public domain dedication), https://creativecommons.org/publicdomain/zero/1.0/ (`License.txt` in each pack). Commercial use OK.
- Attribution: not required. Optional credit: "Animations by Quaternius (quaternius.com)".
- Files: `src/ual1/UAL1_Standard.glb`, `src/ual2/UAL2_Standard.glb` (+ `License.txt`), downloaded 2026-11-01.

### CMU Graphics Lab Motion Capture Database (BVH conversion by Bruce Hahne / cgspeed, 2010 release)
- URLs: http://mocap.cs.cmu.edu/ ; BVH mirror https://github.com/una-dinosauria/cmu-mocap (copy of https://sites.google.com/a/cgspeed.com/cgspeed/motion-capture/cmu-bvh-conversion)
- Licence: CMU terms (no named licence): "This data is free for use in research and commercial projects worldwide" (quoted in `src/cmu/READMEFIRST.txt`); the current CMU site wording adds "You may include this data in commercially-sold products, but you may not resell this data directly, even in converted form." The BVH conversion adds no restrictions. Commercial use in a game OK; do not redistribute the raw clips.
- Attribution (requested): "The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217."

## Rejected / skipped
- Bandai-Namco-Research-Motiondataset 1 and 2: CC BY-NC 4.0 (non-commercial), rejected.
- Mixamo: needs an Adobe login; skipped (owner's account would be required).
- OpenGameArt: search returned HTTP 403 to automated fetch; not checked.
- Quaternius UAL Pro/Source (paid tiers, more clips): not downloaded.

## Files per slot (candidates; the final pick per slot is not made yet)
| Slot | File | Original clip / trial |
|---|---|---|
| 1 hammering | src/cmu/62_07.bvh, 62_08.bvh, 62_10.bvh | CMU 62_07 / 62_08 "hammering a nail", 62_10 "hammering sequence" |
| 1 hammering (alt) | src/ual2/UAL2_Standard.glb | TreeChopping_Loop |
| 2 sawing | src/cmu/62_03.bvh | CMU 62_03 "sawing, hand saw" |
| 3 wrench | src/cmu/62_01.bvh, 62_02.bvh, 62_25.bvh | CMU 62_01 / 62_25 "bolt loosening, wrench", 62_02 "bolt tightening, wrench" |
| 3 wrench (alt) | src/ual1/UAL1_Standard.glb | Fixing_Kneeling |
| 4 carry box | src/ual2/UAL2_Standard.glb | Walk_Carry_Loop |
| 4 carry box (alt) | src/cmu/143_11.bvh, 62_20.bvh | CMU 143_11 "Walk And Pick up Box", 62_20 "closing, moving and opening a box" |
| 5 pointing | src/cmu/13_27.bvh, 14_24.bvh | CMU 13_27 / 14_24 "direct traffic, wave, point" |
| 6 sit on ground | src/cmu/82_05.bvh | CMU 82_05 "sitting on ground relaxing" |
| 7 ladder | src/cmu/13_33.bvh, 14_33.bvh, 143_37.bvh | CMU 13_33 / 14_33 "climb ladder", 143_37 "Climb Up And Down Ladder" |
