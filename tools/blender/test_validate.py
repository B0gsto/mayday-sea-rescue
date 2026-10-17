"""Tests for the pure validate rules, budgets, UV maths, atlas packing and helpers. No Blender:
    python3 -m unittest discover -s tools/blender -p 'test_*.py'"""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "selftest"))
import budgets  # noqa: E402
import common  # noqa: E402
import texgen  # noqa: E402
import uvlayout  # noqa: E402
import validate  # noqa: E402


def by_check(rows):
    return {r[1]: r for r in rows}


class Budgets(unittest.TestCase):
    def test_05_rows(self):
        rib = budgets.row("rib")
        self.assertEqual((rib["tris"], rib["per_part"], rib["lod1"], rib["lod2"]), (35000, 10000, 12000, 3000))
        self.assertEqual(budgets.row("allweather_lifeboat")["tris"], 60000)
        self.assertEqual(budgets.row("big_ship")["lod2"], 8000)

    def test_every_row_is_well_formed(self):
        for name, r in budgets.BUDGETS.items():
            self.assertLessEqual(r["per_part"], budgets.MAX_PER_MESHPART, name)
            self.assertIn(r["share"], budgets.LOD_SHARE, name)
            self.assertTrue(r["sets"] == "atlas" or (r["sets"][0] <= r["sets"][1]), name)
            for lod in budgets.lods_made(name):
                self.assertLess(budgets.lod_ceiling(name, lod), r["tris"], name)

    def test_lod_ceilings(self):
        self.assertEqual(budgets.lod_ceiling("small_prop", "LOD1", asset_tris=800), 400)
        self.assertIsNone(budgets.lod_ceiling("small_prop", "LOD2"))
        self.assertEqual(budgets.lod_ceiling("rock", "LOD2"), 2250)
        self.assertEqual(budgets.lods_made("small_prop"), ["LOD1"])
        self.assertEqual(budgets.lods_made("viewmodel"), [])
        self.assertEqual(budgets.lods_made("rib"), ["LOD1", "LOD2"])
        self.assertEqual(budgets.lod0_ceiling("small_prop", 800), 800)
        self.assertEqual(budgets.lod0_ceiling("small_prop", 9000), 3000)      # an asset row never lifts the class

    def test_lod_targets(self):
        self.assertEqual(budgets.lod_target("small_prop", "LOD1", 672, 800), 336)
        t1 = budgets.lod_target("rib", "LOD1", 30000)
        t2 = budgets.lod_target("rib", "LOD2", 30000)
        self.assertLessEqual(t1, 0.35 * 30000)
        self.assertLessEqual(t1, 12000 * 30000 / 35000.0 + 1)
        self.assertLessEqual(t2, 3000)
        self.assertIsNone(budgets.lod_target("small_prop", "LOD2", 672))
        for name in budgets.BUDGETS:                     # every LOD a class makes gets a target
            for lod in budgets.lods_made(name):
                self.assertGreater(budgets.lod_target(name, lod, 4000), 0, (name, lod))

    def test_sets(self):
        self.assertTrue(budgets.sets_ok("rib", 4)[0])
        self.assertFalse(budgets.sets_ok("rib", 5)[0])
        self.assertTrue(budgets.sets_ok("small_prop", 3, atlas=True)[0])
        self.assertFalse(budgets.sets_ok("small_prop", 2)[0])

    def test_tiers(self):
        self.assertEqual(budgets.texel_target("standard")[0], 51)
        self.assertEqual(budgets.texel_target("hero"), (100, 128))
        with self.assertRaises(KeyError):
            budgets.texel_target("stylized")


class SizeRule(unittest.TestCase):
    def test_free_noted_fail(self):
        self.assertEqual(budgets.size_verdict(1.05 * 3, 3.0)[:2], (True, False))
        self.assertEqual(budgets.size_verdict(1.10 * 3, 3.0)[:2], (False, False))
        self.assertEqual(budgets.size_verdict(1.10 * 3, 3.0, note="cabin room")[:2], (True, True))
        self.assertEqual(budgets.size_verdict(1.20 * 3, 3.0, note="cabin room")[:2], (False, False))

    def test_rows_in_studs(self):
        rows = by_check(validate.size_rows("Bollard", (1.05, 1.05, 1.65), (0.35, 0.35, 0.55)))
        self.assertTrue(all(rows["real size %s" % a][2] for a in "xyz"))
        self.assertTrue(rows["reference dims"][4])                    # no dims.md: info row

    def test_rows_catch_metres_authored_as_studs(self):
        rows = by_check(validate.size_rows("Bollard", (0.35, 0.35, 0.55), (0.35, 0.35, 0.55)))
        self.assertFalse(rows["real size z"][2])

    def test_unfixed_axis_and_reference(self):
        ref = (0.75, 0.75, None)
        rows = by_check(validate.size_rows("Lifebuoy", (2.25, 2.25, 0.4), (0.75, 0.75, None), ref_dims=ref,
                                           ref_path=os.path.join(common.REPO_DIR, "art/reference/Lifebuoy/dims.md")))
        self.assertNotIn("real size z", rows)
        self.assertTrue(rows["reference dims"][2])
        rows = by_check(validate.size_rows("Lifebuoy", (2.25, 2.25, 0.4), (0.75, 0.75, None), ref_dims=(0.8, 0.8, None),
                                           ref_path=os.path.join(common.REPO_DIR, "art/reference/Lifebuoy/dims.md")))
        self.assertFalse(rows["reference dims"][2])

    def test_no_dims(self):
        self.assertFalse(validate.size_rows("X", (1, 1, 1), None)[0][2])

    def test_dims_md(self):
        self.assertEqual(common.parse_dims_md("# Bollard\n\nSource: x\n\ndims_m: 0.35 x 0.35 x 0.55\n"), (0.35, 0.35, 0.55))
        self.assertEqual(common.parse_dims_md("**dims_m**: 0.75 x 0.75 x -"), (0.75, 0.75, None))
        self.assertEqual(common.parse_dims_md("dims_m = 8.4, 2.85, 3"), (8.4, 2.85, 3.0))
        self.assertIsNone(common.parse_dims_md("about 5 m long"))


class TriangleRules(unittest.TestCase):
    def test_prop(self):
        rows = by_check(validate.tri_rows("B", "small_prop", {"LOD0": 672, "LOD1": 336}, asset_tris=800))
        self.assertTrue(rows["LOD0 triangles"][2] and rows["LOD1 triangles"][2])
        self.assertNotIn("LOD2 triangles", rows)
        rows = by_check(validate.tri_rows("B", "small_prop", {"LOD0": 900, "LOD1": 336}, asset_tris=800))
        self.assertFalse(rows["LOD0 triangles"][2])
        rows = by_check(validate.tri_rows("B", "small_prop", {"LOD0": 700, "LOD1": 336, "LOD2": 100}, asset_tris=800))
        self.assertFalse(rows["LOD2 triangles"][2])                  # props are culled, a LOD2 is a mistake

    def test_vehicle_lods_required(self):
        rows = by_check(validate.tri_rows("RIB", "rib", {"LOD0": 34000, "LOD1": 11000}))
        self.assertTrue(rows["LOD0 triangles"][2])
        self.assertFalse(rows["LOD2 triangles"][2])
        rows = by_check(validate.tri_rows("RIB", "rib", {"LOD0": 34000, "LOD1": 13000, "LOD2": 2000}))
        self.assertFalse(rows["LOD1 triangles"][2])

    def test_floor_and_waiver(self):
        rows = by_check(validate.tri_rows("Rock", "rock", {"LOD0": 3000, "LOD1": 1200, "LOD2": 400}))
        self.assertFalse(rows["LOD0 floor"][2])
        rows = by_check(validate.tri_rows("Rock", "rock", {"LOD0": 3000, "LOD1": 1200, "LOD2": 400}, waivers={"LOD0 floor": "pebble"}))
        self.assertEqual(rows["LOD0 floor"][4], "pebble")

    def test_per_part(self):
        self.assertTrue(validate.part_row("M_Veh_RIB_Hull_LOD0", 10000, "rib")[2])
        self.assertFalse(validate.part_row("M_Veh_RIB_Hull_LOD0", 10001, "rib")[2])
        self.assertFalse(validate.part_row("M_Prop_Crate_LOD0", 3001, "small_prop")[2])

    def test_report_waiver_and_info(self):
        r = validate.Report()
        r.add("a", "x", False, "bad", waiver="reason")
        r.add("a", "y", False, "note", info=True)
        self.assertTrue(r.ok)
        r.add("a", "z", False, "bad")
        self.assertFalse(r.ok)
        self.assertEqual(len(r.failures()), 1)


class Maps(unittest.TestCase):
    def test_presence_and_size(self):
        import placeholder_pbr
        with tempfile.TemporaryDirectory() as d:
            placeholder_pbr.write_set(d, "Test", "Iron", 256)
            rows = validate.map_rows("Test", [{"name": "Test", "set": "Iron", "dir": d}], lambda: d)
            self.assertEqual(len(rows), 4)
            self.assertTrue(all(r[2] for r in rows), rows)
            rows = validate.map_rows("Test", [{"name": "Test", "set": "Iron", "dir": d}], lambda: d, cap=128)
            self.assertFalse(any(r[2] for r in rows))
            rows = validate.map_rows("Test", [{"name": "Test", "set": "Iron", "wet": True, "dir": d}], lambda: d)
            self.assertEqual(sum(not r[2] for r in rows), 2)          # ALB_Wet and RGH_Wet missing
            os.remove(os.path.join(d, "T_Test_Iron_NOR.png"))
            rows = validate.map_rows("Test", [{"name": "Test", "set": "Iron", "dir": d}], lambda: d)
            self.assertEqual([r[0] for r in rows if not r[2]], ["T_Test_Iron_NOR"])

    def test_image_size(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as d:
            for ext in ("png", "jpg", "bmp", "tga"):
                p = os.path.join(d, "t." + ext)
                Image.new("RGB", (64, 32)).save(p)
                self.assertEqual(tuple(common.image_size(p)), (64, 32), ext)
        self.assertTrue(common.is_pow2(1024) and not common.is_pow2(1000))


class UVMaths(unittest.TestCase):
    QUAD = [[(0.0, 0.0), (0.5, 0.0), (0.5, 0.5), (0.0, 0.5)]]

    def test_stats_and_density(self):
        s = uvlayout.uv_stats(self.QUAD, [4.0])
        self.assertAlmostEqual(s["uv_area"], 0.25)
        self.assertTrue(uvlayout.in_unit_square(s))
        # a 2 x 2 stud face on a quarter of a 1024 map: 512 px over 2 studs = 256 px/stud
        self.assertAlmostEqual(texgen.texel_density_px_per_stud(s["uv_area"], s["area3d"], 1024), 256.0)
        self.assertFalse(uvlayout.in_unit_square(uvlayout.uv_stats([[(0, 0), (1.2, 0), (1.2, 1)]], [1.0])))
        self.assertEqual(uvlayout.uv_stats([[(0, 0), (0, 0), (0, 0)]], [1.0])["zero_area_faces"], 1)

    def test_lod_layout(self):
        a = uvlayout.uv_stats(self.QUAD, [4.0])
        same = uvlayout.uv_stats([[(0.0, 0.0), (0.5, 0.0), (0.5, 0.48), (0.0, 0.5)]], [4.0])
        moved = uvlayout.uv_stats([[(0.5, 0.5), (1.0, 0.5), (1.0, 1.0), (0.5, 1.0)]], [4.0])
        self.assertTrue(uvlayout.compare_layouts(a, same)[0])
        self.assertFalse(uvlayout.compare_layouts(a, moved)[0])

    def test_density_verdict(self):
        self.assertTrue(uvlayout.density_verdict(47, (51, None), 0.9)[0])
        self.assertFalse(uvlayout.density_verdict(40, (51, None), 0.9)[0])


class Atlas(unittest.TestCase):
    def test_pack(self):
        rects = texgen.atlas_rects([("a", 2048, 2048), ("b", 2048, 2048), ("c", 1024, 1024)], 4096)
        self.assertEqual(rects["a"], (0.0, 0.5, 0.5, 1.0))
        self.assertEqual(rects["c"], (0.0, 0.25, 0.25, 0.5))
        with self.assertRaises(ValueError):
            texgen.atlas_rects([("a", 4096, 4096), ("b", 16, 16)], 4096)
        with self.assertRaises(ValueError):
            texgen.atlas_rects([("a", 64, 64)], 8192)

    def test_downsize_and_margin(self):
        px, clean = texgen.scale_rect_to((0.0, 0.5, 0.5, 1.0))
        self.assertEqual((px, clean), ([0, 512, 512, 1024], True))
        self.assertEqual(texgen.margin_px(1024), 16)
        self.assertEqual(texgen.remap_uv((0.5, 0.5), (0.0, 0.5, 0.5, 1.0)), (0.25, 0.75))
        self.assertEqual(texgen.texture_size_for(51, 25.0), 512)

    def test_constants(self):
        self.assertEqual((common.EXPORT_CAP, common.MASTER, common.STUDS_PER_METRE), (1024, 4096, 3.0))


if __name__ == "__main__":
    unittest.main()
