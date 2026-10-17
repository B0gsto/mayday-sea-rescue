"""rope.py pure parts (no Blender): triangle budget, UV layout, catenary, tileable trim that passes check_textures."""
import os
import sys
import tempfile
import unittest
import warnings

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check_textures  # noqa: E402
import common  # noqa: E402
import rope  # noqa: E402

warnings.simplefilter("ignore", DeprecationWarning)


class Rope(unittest.TestCase):
    def test_budget_and_uvs(self):
        v, f, uv, tris, v_end = rope.tube([(0, 0, 0), (1, 0, 0)], 0.02, "three_strand", sides=8, max_tris=500)
        self.assertLessEqual(tris, 500)
        self.assertEqual(tris, sum(len(x) - 2 for x in f))
        us = [c[0] for poly in uv[:-16] for c in poly]
        self.assertAlmostEqual(min(us), 0.0)
        self.assertAlmostEqual(max(us), 1.0)
        self.assertAlmostEqual(v_end, common.metres_to_studs(1.0) / common.metres_to_studs(np.pi * 0.02), places=6)

    def test_catenary_sag(self):
        p = rope.catenary((0, 0, 1.0), (4, 0, 1.0), 0.5, 101)
        self.assertAlmostEqual(p[50, 2], 0.5, places=3)
        np.testing.assert_allclose(p[-1], (4, 0, 1.0), atol=1e-6)

    def test_trims_tile_and_pass(self):
        for set_name, prof in (("Manila", "three_strand"), ("Nylon", "braid")):
            h = rope.trim_height(prof, 256)
            self.assertLess(np.abs(h[:, 0] - h[:, -1]).mean(), 0.08)
            self.assertLess(np.abs(h[0] - h[-1]).mean(), 0.08)
            with tempfile.TemporaryDirectory() as d:
                rope.write_trim(d, set_name, prof, 256)
                r = check_textures.check_folder(d)
                self.assertTrue(r.ok, [(x["subject"], x["check"]) for x in r.failures()])


if __name__ == "__main__":
    unittest.main()
