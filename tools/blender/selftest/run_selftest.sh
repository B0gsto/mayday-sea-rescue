#!/bin/bash
# Pipeline self-test (docs/12 B00): placeholder PBR set, Python tests, one good Blender run (build, lod, validate,
# export), one broken run (built in metres: validate must fail and nothing may be exported), check_textures.
# Blender only through ~/RobloxProjects/tools/blender-run.sh (one heavy slot per run). Outputs: build/blender-selftest/.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO"
OUT=build/blender-selftest
BUILD=tools/blender/selftest/PipelineBollard/build.py
RUN=~/RobloxProjects/tools/blender-run.sh
fail=0
rm -rf "$OUT"
python3 -W ignore tools/blender/selftest/placeholder_pbr.py "$OUT/textures/PipelineBollard" PipelineBollard Iron 1024 >/dev/null
if python3 -m unittest discover -b -s tools/blender -p 'test_*.py' > "$OUT/unittest.log" 2>&1; then echo "unit tests: $(grep '^Ran' "$OUT/unittest.log"), OK"; else echo "unit tests: FAILED (see $OUT/unittest.log)"; fail=1; fi
python3 tools/blender/check_textures.py "$OUT/textures/PipelineBollard" | tail -1
[ "${PIPESTATUS[0]}" = 0 ] || fail=1
"$RUN" tools/blender/run.py -- --build "$BUILD" --out-root "$OUT" --no-template --steps build,lod,validate,export > "$OUT/good.log" 2>&1
rc=$?; grep -E '^\[(lod|export|run)\]|FAIL' "$OUT/good.log" | grep -v "^\[run\] report\|peak"
[ $rc = 0 ] || { echo "good run: FAILED (rc $rc)"; fail=1; }
mv "$OUT/fbx" "$OUT/fbx-good"
PIPELINE_SELFTEST_BREAK=scale "$RUN" tools/blender/run.py -- --build "$BUILD" --out-root "$OUT" --no-template --steps lod,validate,export > "$OUT/broken.log" 2>&1
rc=$?; grep -E 'FAIL|nothing exported' "$OUT/broken.log" | head -5
if [ $rc = 0 ] || ls "$OUT"/fbx/PipelineBollard/*.fbx >/dev/null 2>&1; then echo "broken run: should have failed with no FBX"; fail=1; else echo "broken run: failed as expected, no FBX written"; fi
rm -rf "$OUT/fbx"; mv "$OUT/fbx-good" "$OUT/fbx"
echo "selftest: $([ $fail = 0 ] && echo PASS || echo FAIL)"
exit $fail
