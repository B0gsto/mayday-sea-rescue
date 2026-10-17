"""check_textures.py tests on generated sets (system python3 with Pillow and numpy):
    python3 -m unittest discover -s tools/blender -p 'test_*.py'"""
import os
import sys
import tempfile
import unittest
import warnings

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "selftest"))
import check_textures  # noqa: E402
import placeholder_pbr  # noqa: E402
from PIL import Image  # noqa: E402

warnings.simplefilter("ignore", DeprecationWarning)


def failed(report):
    return sorted({(r["subject"].split(".")[0], r["check"]) for r in report.failures()})


class CheckTextures(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def run_check(self, **kw):
        return check_textures.check_folder(self.d, **kw)

    def test_good_set_passes(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 512, wet=True, metal_share=0.25)
        r = self.run_check(want_wet=True)
        self.assertTrue(r.ok, failed(r))
        gl = [x for x in r.rows if x["check"] == "OpenGL green"][0]
        self.assertFalse(gl["info"], gl)              # decided, not just "undetermined"
        self.assertIn("OpenGL", gl["detail"])

    def test_directx_normal_fails(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 512, opengl=False)
        self.assertEqual(failed(self.run_check()), [("T_Test_Iron_NOR", "OpenGL green")])

    def test_flat_normal_is_info(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 256)
        Image.new("RGB", (256, 256), (128, 128, 255)).save(os.path.join(self.d, "T_Test_Iron_NOR.png"))
        r = self.run_check()
        self.assertTrue(r.ok, failed(r))

    def test_object_space_normal_fails(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 256)
        Image.new("RGB", (256, 256), (200, 60, 128)).save(os.path.join(self.d, "T_Test_Iron_NOR.png"))
        self.assertIn(("T_Test_Iron_NOR", "tangent space"), failed(self.run_check()))

    def test_rgb_roughness_fails(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 256, rgh_mode="RGB")
        self.assertEqual(failed(self.run_check()), [("T_Test_Iron_RGH", "single channel")])

    def test_albedo_value_range(self):
        placeholder_pbr.write_set(self.d, "Test", "Coal", 256, albedo_rgb=(8, 8, 8))
        self.assertEqual(failed(self.run_check()), [("T_Test_Coal_ALB", "non-metal albedo")])

    def test_metal_albedo_range(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 256, metal_share=0.5)
        path = os.path.join(self.d, "T_Test_Iron_ALB.png")
        img = Image.open(path).convert("RGB")
        img.paste((90, 90, 95), (0, 0, 256, 128))           # dark "metal": below 180
        img.save(path)
        self.assertEqual(failed(self.run_check()), [("T_Test_Iron_ALB", "metal albedo")])

    def test_saturation_and_signal_mask(self):
        placeholder_pbr.write_set(self.d, "Test", "Jacket", 256, saturated=True)
        self.assertEqual(failed(self.run_check()), [("T_Test_Jacket_ALB", "saturation")])
        with tempfile.TemporaryDirectory() as other:         # the mask lives outside the map folder
            mask = os.path.join(other, "jacket_signal.png")
            Image.new("L", (256, 256), 255).save(mask)
            r = self.run_check(signal_masks={"T_Test_Jacket": mask})
            self.assertTrue(r.ok, failed(r))

    def test_size_cap_and_pow2(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 2048)
        self.assertTrue(all(c == "size" for _, c in failed(self.run_check())))
        self.assertTrue(self.run_check(cap=4096).ok)        # masters
        for f in os.listdir(self.d):
            os.remove(os.path.join(self.d, f))
        placeholder_pbr.write_set(self.d, "Test", "Iron", 300)
        self.assertIn(("T_Test_Iron_ALB", "size"), failed(self.run_check()))

    def test_missing_map_and_bad_name(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 256)
        os.remove(os.path.join(self.d, "T_Test_Iron_MET.png"))
        Image.new("L", (256, 256)).save(os.path.join(self.d, "T_Test_Iron_Roughness.png"))
        f = failed(self.run_check())
        self.assertIn(("T_Test_Iron", "MET present"), f)
        self.assertIn(("T_Test_Iron_Roughness", "naming"), f)

    def test_wet_must_be_darker_and_glossier(self):
        placeholder_pbr.write_set(self.d, "Test", "Deck", 256, wet=True)
        Image.open(os.path.join(self.d, "T_Test_Deck_ALB.png")).save(os.path.join(self.d, "T_Test_Deck_ALB_Wet.png"))
        self.assertEqual(failed(self.run_check()), [("T_Test_Deck_ALB_Wet", "wet is darker")])
        os.remove(os.path.join(self.d, "T_Test_Deck_RGH_Wet.png"))
        self.assertIn(("T_Test_Deck", "RGH_Wet present"), failed(self.run_check()))

    def test_rgba_albedo_needs_alpha_flag(self):
        placeholder_pbr.write_set(self.d, "Test", "Leaf", 256, alb_mode="RGBA")
        self.assertEqual(failed(self.run_check()), [("T_Test_Leaf_ALB", "colour mode")])
        self.assertTrue(self.run_check(alpha=True).ok)

    def test_cli_exit_code(self):
        placeholder_pbr.write_set(self.d, "Test", "Iron", 256, opengl=False)
        self.assertEqual(check_textures.main([self.d, "--json", os.path.join(self.d, "r.json")]), 1)


if __name__ == "__main__":
    unittest.main()
