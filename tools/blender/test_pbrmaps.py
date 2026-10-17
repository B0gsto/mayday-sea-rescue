"""Tests for the pure parts of pbrmaps.py, bake.py and scan_ingest.py (system python3, numpy + Pillow; no Blender)."""
import os
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bake  # noqa: E402
import common  # noqa: E402
import pbrmaps  # noqa: E402
import scan_ingest  # noqa: E402


class PngAndResample(unittest.TestCase):
    def test_png_roundtrip_modes(self):
        rng = np.random.default_rng(1)
        with tempfile.TemporaryDirectory() as d:
            for shape, mode in (((8, 12), "L"), ((8, 12, 3), "RGB"), ((8, 12, 4), "RGBA")):
                a = rng.integers(0, 256, shape, dtype=np.uint8)
                p = pbrmaps.write_png(os.path.join(d, "t_%s.png" % mode), a)
                img = Image.open(p)
                self.assertEqual(img.mode, mode)
                np.testing.assert_array_equal(np.asarray(img), a)

    def test_downsize_box(self):
        a = np.arange(16, dtype=np.float32).reshape(4, 4)
        np.testing.assert_allclose(pbrmaps.downsize(a, 2), [[2.5, 4.5], [10.5, 12.5]])
        self.assertEqual(pbrmaps.downsize(a, 8).shape, (4, 4))

    def test_dilate_and_pad(self):
        cov = np.zeros((5, 5), bool)
        cov[2, 2] = True
        idx = pbrmaps.dilate_index(cov, 1)
        self.assertEqual(int((idx >= 0).sum()), 5)            # the texel and its 4 neighbours
        arr = np.zeros((5, 5, 3), np.float32)
        arr[2, 2] = (1, 2, 3)
        out = pbrmaps.pad(arr, idx, (9, 9, 9))
        np.testing.assert_allclose(out[1, 2], (1, 2, 3))
        np.testing.assert_allclose(out[0, 0], (9, 9, 9))


    def test_uv_coverage_half_square(self):
        m = pbrmaps.uv_coverage([[(0, 0), (1, 0), (0, 1)]], 16, grow=0.0)
        self.assertAlmostEqual(m.mean(), 0.5, delta=0.07)
        self.assertTrue(m[15, 0] and not m[0, 15])          # V 0 is the bottom row


class Wear(unittest.TestCase):
    def flat_inputs(self, n=32):
        z = np.linspace(1, 0, n, dtype=np.float32)[:, None].repeat(n, 1)       # top row is the top of a wall
        x = np.linspace(0, 1, n, dtype=np.float32)[None, :].repeat(n, 0)
        pos = np.stack([x, np.full_like(x, 0.5), z], axis=2)
        wn = np.zeros((n, n, 3), np.float32)
        wn[..., 1] = -1.0                                                       # a wall facing -Y
        return pos, wn

    def test_rust_runs_down_not_up(self):
        pos, wn = self.flat_inputs()
        src = np.zeros(pos.shape[:2], np.float32)
        src[16, :] = 1.0                                                        # an edge across the middle
        p = pbrmaps.wear_params({"rust_fingers": 0.0001})
        r = pbrmaps.rust_streaks(pos, wn, src, np.ones(src.shape, bool), p)
        self.assertGreater(r[20:28].mean(), 0.1)
        self.assertLess(r[2:12].mean(), 0.01)
        self.assertGreater(r[18].mean(), r[30].mean())                         # fades with distance

    def test_compose_without_wear_keeps_base(self):
        pos, wn = self.flat_inputs(8)
        base = np.full((8, 8, 3), 0.4, np.float32)
        one = np.ones((8, 8), np.float32)
        out = pbrmaps.compose(base, 0 * one, 0.6 * one, one, 0.5 * one, pos, wn, one > 0, False)
        np.testing.assert_allclose(out["alb"], 0.4, atol=1e-5)
        np.testing.assert_allclose(out["rgh"], 0.6, atol=1e-6)

    def test_edge_wear_follows_convexity(self):
        p = pbrmaps.wear_params(None)
        self.assertEqual(float(pbrmaps.edge_mask(np.float32(0.5), p)), 0.0)
        self.assertEqual(float(pbrmaps.edge_mask(np.float32(1.0), p)), 1.0)
        self.assertGreater(float(pbrmaps.salt_mask(np.float32(0.2), np.float32(0.2), p)), 0.9)
        with self.assertRaises(KeyError):
            pbrmaps.wear_params({"grunge": 1})

    def test_clamp_albedo_ranges(self):
        rgb = np.array([[[0.01, 0.01, 0.01], [1, 1, 1], [0.3, 0.3, 0.3]]], np.float32)
        out = pbrmaps.clamp_albedo(rgb, np.array([[0, 0, 1]]))
        y = pbrmaps.luma(out) * 255
        self.assertGreaterEqual(y[0, 0], 31.9)
        self.assertLessEqual(y[0, 1], 238.1)
        self.assertGreaterEqual(y[0, 2], 181.9)                                  # metal floor

    def test_wet_and_saturation(self):
        a, r = pbrmaps.wet(np.full((2, 2, 3), 0.5), np.array([[0.8, 0.2], [0.04, 0.5]]))
        np.testing.assert_allclose(a, 0.375)
        np.testing.assert_allclose(r, [[0.5, 0.04], [0.04, 0.2]], atol=1e-6)
        out, share = pbrmaps.limit_saturation(np.array([[[1.0, 0.0, 0.0], [0.5, 0.5, 0.5]]], np.float32), 0.4)
        np.testing.assert_allclose(out[0, 0], (1.0, 0.6, 0.6), atol=1e-6)
        self.assertEqual(share, 0.5)


class ScanHelpers(unittest.TestCase):
    def test_classify_names(self):
        cases = {"rock_wall_diff_2k.png": "ALB", "metal_plate_ao_1k.jpg": "AO", "metal_plate_metal_1k.png": "MET",
                 "x_nor_gl_4k.png": "NOR_GL", "x_nor_dx_4k.png": "NOR_DX", "x_arm_1k.png": "ARM",
                 "Metal032_2K-PNG_NormalGL.png": "NOR_GL", "Metal032_2K-PNG_NormalDX.png": "NOR_DX",
                 "Metal032_2K-PNG_Color.png": "ALB", "Metal032_2K-PNG_Metalness.png": "MET", "Rock_Roughness.jpg": "RGH",
                 "Wood_AmbientOcclusion.png": "AO", "Wood_BaseColor.png": "ALB", "Metal032.png": None}
        for fn, kind in cases.items():
            self.assertEqual(pbrmaps.classify_map_name(fn), kind, fn)

    def test_flip_and_unpack(self):
        n = np.array([[[0.5, 0.2, 1.0]]], np.float32)
        np.testing.assert_allclose(pbrmaps.flip_green(n)[0, 0], (0.5, 0.8, 1.0))
        self.assertEqual(int(pbrmaps.flip_green(np.array([[[1, 10, 3]]], np.uint8))[0, 0, 1]), 245)
        u = pbrmaps.unpack_packed(np.array([[[0.9, 0.6, 1.0]]]), "ORM")
        self.assertEqual((float(u["AO"][0, 0]), float(u["RGH"][0, 0]), float(u["MET"][0, 0])), (0.9, 0.6, 1.0))

    def test_process_arm_dx(self):
        alb = np.full((4, 4, 3), 0.5, np.float32)
        arm = np.stack([np.ones((4, 4)), np.full((4, 4), 0.7), np.zeros((4, 4))], 2).astype(np.float32)
        dx = np.zeros((4, 4, 3), np.float32) + (0.5, 0.3, 1.0)
        maps, notes = scan_ingest.process({"ALB": alb, "ARM": arm, "NOR_DX": dx}, "NOR_DX", args_wet=True)
        np.testing.assert_allclose(maps[("NOR", False)][0, 0], (0.5, 0.7, 1.0), atol=1e-6)
        np.testing.assert_allclose(maps[("RGH", False)], 0.7)
        self.assertIn(("ALB", True), maps)
        self.assertTrue(any("DirectX" in n for n in notes))

    def test_sizes_and_licence_row(self):
        ship, cap = common.SHIP_SIZE, common.EXPORT_CAP
        self.assertEqual(scan_ingest.target_sizes((2048, 2048)), (2048, min(2048, ship)))
        self.assertEqual(scan_ingest.target_sizes((1000, 1000)), (512, 512))
        self.assertEqual(scan_ingest.target_sizes((8192, 8192)), (4096, ship))
        self.assertEqual(scan_ingest.target_sizes((8192, 8192), cap=4096), (4096, cap))
        self.assertEqual(scan_ingest.target_sizes((8192, 8192), cap=8192), (4096, cap))
        row = scan_ingest.licence_row(scan_ingest.STATUS_HEADER, {"asset": "A", "url": "u", "author": "x", "licence": "CC0", "date": "d"})
        self.assertEqual(row[0], "A")
        self.assertEqual(row[scan_ingest.STATUS_HEADER.index("source")], "u")
        self.assertEqual(row[scan_ingest.STATUS_HEADER.index("ai_used")], "none")
        self.assertEqual(scan_ingest.licence_row(["asset", "author", "date"], {"asset": "A", "author": "x", "date": "d"}), ["A", "x", "d"])


class BakeHelpers(unittest.TestCase):
    def test_sizes_and_sets(self):
        spec = {"sets": [{"name": "A", "set": "Hull"}, {"name": "A", "set": "Deck"}], "bake_size": 1024}
        self.assertEqual(bake.bake_size(spec, env={}), 1024)
        self.assertEqual(bake.bake_size(spec, env={"MAYDAY_BAKE_SIZE": "512"}), 512)
        self.assertEqual(bake.bake_size({}, env={}), 4096)
        with self.assertRaises(ValueError):
            bake.bake_size({"bake_size": 1000}, env={})
        self.assertEqual([s["set"] for s in bake.sets_to_bake(spec, env={"MAYDAY_BAKE_SET": "Deck"})], ["Deck"])
        self.assertEqual(len(bake.sets_to_bake(spec, env={})), 2)
        with self.assertRaises(ValueError):
            bake.sets_to_bake(spec, env={"MAYDAY_BAKE_SET": "Sail"})
        self.assertEqual(bake.export_size({}, 4096), common.SHIP_SIZE)
        self.assertEqual(bake.export_size({"size": 2048}, 4096), 2048)
        self.assertEqual(bake.export_size({"size": 8192}, 4096), common.EXPORT_CAP)
        self.assertEqual(bake.export_size({"size": 1024}, 512), 512)

    def test_slot_values_priority(self):
        principled = ((0.2140, 0.2140, 0.2140), 1.0, 0.3)          # linear 0.214 = sRGB 0.5
        base, metal, rough = bake.slot_values({}, "M", principled)
        self.assertAlmostEqual(base[0], 0.5, places=2)
        self.assertEqual((metal, rough), (1.0, 0.3))
        s = {"base_color": "#808080", "roughness": 0.9, "slots": {"M": {"metal": 0.0}}}
        base, metal, rough = bake.slot_values(s, "M", principled)
        self.assertAlmostEqual(base[0], 128 / 255.0)
        self.assertEqual((metal, rough), (0.0, 0.9))

    def test_finish_maps_flat(self):
        n = 16
        cov = np.zeros((n, n), bool)
        cov[2:14, 2:14] = True
        baked = {"nor": np.zeros((n, n, 3), np.float32) + (0.5, 0.5, 1.0), "mask": np.zeros((n, n, 3), np.float32) + (1, 0.5, 1),
                 "pos": np.zeros((n, n, 3), np.float32) + 0.5, "wn": np.zeros((n, n, 3), np.float32) + (0.5, 0.5, 1.0),
                 "base": np.zeros((n, n, 3), np.float32) + 0.5, "mr": np.zeros((n, n, 3), np.float32) + (0, 0.6, 0)}
        maps, masks = bake.finish_maps(baked, cov, n, {"wet": True})
        self.assertEqual(set(maps), {("ALB", False), ("NOR", False), ("RGH", False), ("MET", False), ("ALB", True), ("RGH", True)})
        np.testing.assert_allclose(maps[("NOR", False)], np.broadcast_to((0.5, 0.5, 1.0), (n, n, 3)), atol=1e-6)
        self.assertLess(maps[("RGH", True)].mean(), maps[("RGH", False)].mean())


if __name__ == "__main__":
    unittest.main()
