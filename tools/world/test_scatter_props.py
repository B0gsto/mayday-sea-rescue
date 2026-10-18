"""props.json schema after the cliff dressing pass: 10-column rock rows (landmark flag), per-instance scale range,
cliff faces in all four steep regions, the cold-open run kept clear; max_filter on a toy grid. No Studio needed."""
import json
import math
import os
import sys
import unittest

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scatter_props as S  # noqa: E402

PROPS = os.path.join(S.REPO, "map/generated/props.json")


class PropsSchema(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = json.load(open(PROPS))

    def test_rows(self):
        assets = self.doc["assets"]
        self.assertEqual(assets, S.ASSETS)
        for r in self.doc["rocks"]:
            self.assertEqual(len(r), 10)
            self.assertIn(r[9], (0, 1))
            self.assertTrue(assets[r[0] - 1].startswith("M_Rock_"))
            self.assertGreater(r[7], 0)
        for r in self.doc["plants"]:
            self.assertEqual(len(r), 10)
            self.assertTrue(assets[r[0] - 1].startswith("M_Veg_"))

    def test_cliff_faces(self):
        faces = [r for r in self.doc["rocks"] if r[9] == 1 and "_Cliff_" in self.doc["assets"][r[0] - 1]]
        self.assertGreater(len(faces), 40)
        for r in faces:
            name = self.doc["assets"][r[0] - 1]
            self.assertGreaterEqual(r[7], S.CLIFF_SCALE[0] - 0.01)
            self.assertLessEqual(r[7], S.CLIFF_SCALE[1] + 0.01)
            self.assertLessEqual(S.ROCKS[name][0] * 3 * r[7], S.CLIFF_MAX_WIDTH + 1)
            self.assertGreater(math.hypot(r[1] - S.COLD_OPEN[0], r[3] - S.COLD_OPEN[1]), S.COLD_OPEN[2])
        landmarks = {self.doc["assets"][r[0] - 1].split("_")[2] for r in self.doc["rocks"] if r[9] == 1}
        self.assertLessEqual(landmarks, {"Cliff", "Ledge"})
        cl = self.doc["stats"]["cliffs"]
        for region in S.CLIFF_REGIONS:
            self.assertGreater(cl.get(region, {}).get("face", 0), 0, region)


class MaxFilter(unittest.TestCase):
    def test_toy(self):
        a = np.zeros((7, 7))
        a[3, 3] = 5
        m = S.max_filter(a, 2)
        self.assertEqual(m[1, 5], 5)
        self.assertEqual(m[0, 3], 0)
        self.assertEqual(m.shape, a.shape)


if __name__ == "__main__":
    unittest.main()
