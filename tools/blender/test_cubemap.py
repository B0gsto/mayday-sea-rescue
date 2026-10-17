"""cubemap.py tests (system python3 with numpy + Pillow): RGBE round trip, equirect axes, HDRI faces seamless."""
import io
import os
import sys
import tempfile
import unittest
import warnings
from contextlib import redirect_stdout

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cubemap  # noqa: E402

warnings.simplefilter("ignore", DeprecationWarning)


def sky(h=64, w=128):
    """Smooth synthetic equirect: blue gradient, warm band towards +X, one hot sun pixel at (Ft, 30 deg up)."""
    v = (np.arange(h) + 0.5) / h
    u = (np.arange(w) + 0.5) / w
    el = (0.5 - v)[:, None] * np.pi
    lon = (u - 0.5)[None, :] * 2 * np.pi
    img = np.zeros((h, w, 3), np.float32)
    img[..., 2] = 0.4 + 0.3 * np.sin(el)
    img[..., 1] = 0.3 + 0.1 * np.cos(el)
    img[..., 0] = 0.2 + 0.15 * np.maximum(np.sin(lon), 0) * np.cos(el)
    img[int(h * (0.5 - 30 / 180.0)), w // 2] = (5000, 5000, 4000)
    return img


class Cubemap(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def test_rgbe_round_trip_rle_and_flat(self):
        img = sky()
        for rle in (True, False):
            p = os.path.join(self.tmp.name, "s%d.hdr" % rle)
            cubemap.write_hdr(p, img, rle=rle)
            back = cubemap.read_hdr(p)
            self.assertEqual(back.shape, img.shape)
            rel = np.abs(back - img) / np.maximum(img, 1e-3)
            self.assertLess(float(rel.max()), 0.01, rle)

    def test_equirect_axes(self):
        u, v = cubemap.equirect_uv(np.array([[0, 0, -1.0], [1, 0, 0], [-1, 0, 0], [0, 1, 0]]))
        np.testing.assert_allclose(u[:3], [0.5, 0.75, 0.25], atol=1e-9)
        np.testing.assert_allclose(v, [0.5, 0.5, 0.5, 0.0], atol=1e-9)

    def test_hdri_faces_seamless_and_sun(self):
        p = os.path.join(self.tmp.name, "sky.hdr")
        cubemap.write_hdr(p, sky(256, 512))
        with redirect_stdout(io.StringIO()) as out:
            imgs, (across, worst, inside) = cubemap.bake_hdri(p, "Test", self.tmp.name, 64, clamp="auto")
        self.assertEqual(sorted(imgs), sorted(cubemap.FACES))
        self.assertTrue(os.path.isfile(os.path.join(self.tmp.name, "Test_Up.png")))
        self.assertLess(across, inside + 1.5)
        self.assertLess(worst, 4.0)
        self.assertIn("elev 29", out.getvalue().replace("elev 30", "elev 29"))
        # +X (Lf) carries the warm band, -X (Rt) does not
        self.assertGreater(imgs["Lf"][..., 0].mean(), imgs["Rt"][..., 0].mean() + 5)


if __name__ == "__main__":
    unittest.main()
