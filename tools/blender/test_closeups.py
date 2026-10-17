"""Close-up review renders (common.closeup_targets), the bigger sheet with its detail row (sheet.py), and the importer's
orientation fix (tools/studio/import_asset.luau; the Studio-side test is tools/studio/import_test.luau)."""
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import common  # noqa: E402

REPO = os.path.dirname(os.path.dirname(HERE))


class CloseupTargets(unittest.TestCase):
    LO, HI = [-4.36, -13.0, 0.0], [4.36, 13.0, 9.5]

    def test_default_corners_and_centre(self):
        cs = common.closeup_targets(None, self.LO, self.HI)
        self.assertEqual([c["name"] for c in cs], ["corner_FL", "corner_FR", "corner_RL", "corner_RR", "centre"])
        for c in cs[:4]:
            self.assertEqual(c["target"][2], 9.5)                 # upper corners
            self.assertEqual(c["dist"], common.CLOSEUP_DIST)
        self.assertAlmostEqual(cs[0]["az"] % 360, 360 - 341.46, delta=50)  # front-left corner: seen from the front
        self.assertGreater(cs[2]["az"], 90)                        # rear corners: seen from behind
        self.assertLess(cs[2]["az"], 270)
        self.assertEqual(cs[4]["target"], [0.0, 0.0, 4.75])

    def test_declared(self):
        decl = [{"name": "bow seam", "target": [0, -12, 3]}] + [{"name": "x", "target": [1, 2, 3], "dist": 9, "az": 90, "el": 5}] * 7
        cs = common.closeup_targets(decl, self.LO, self.HI)
        self.assertEqual(len(cs), common.CLOSEUP_MAX)
        self.assertEqual(cs[0]["name"], "bow_seam")
        self.assertEqual(cs[0]["dist"], 6.0)
        self.assertAlmostEqual(cs[0]["az"], 0.0, places=3)        # straight in front of the bow
        self.assertEqual(len({c["name"] for c in cs}), len(cs))
        self.assertEqual((cs[1]["dist"], cs[1]["az"], cs[1]["el"]), (9.0, 90.0, 5.0))
        with self.assertRaises(ValueError):
            common.closeup_targets([{"target": [1, 2]}], self.LO, self.HI)


class SheetDetailRow(unittest.TestCase):
    def test_sheet_has_bigger_cells_and_closeups(self):
        from PIL import Image
        import sheet
        with tempfile.TemporaryDirectory() as d:
            tt = os.path.join(d, "turntable")
            os.makedirs(tt)
            for v in sheet.VIEWS:
                for w in ("neutral", "overcast"):
                    Image.new("RGB", (768, 768), (90, 90, 90)).save(os.path.join(tt, "%s_%s.png" % (v, w)))
            closeups = []
            for n in ("bow", "helm", "outboards", "cleat"):
                Image.new("RGB", (1024, 1024), (200, 90, 40)).save(os.path.join(tt, "closeup_%s.png" % n))
                closeups.append({"name": n, "file": "closeup_%s.png" % n})
            rep = {"asset": "M_Test_Thing", "name": "M_Test_Thing", "date": "2026-10-17", "ok": True, "checks": [],
                   "turntable": {"dir": tt, "closeups": closeups}}
            path = os.path.join(d, "2026-10-17_report.json")
            with open(path, "w") as f:
                json.dump(rep, f)
            out, filled = sheet.build(path, os.path.join(d, "sheet.png"), studio=os.path.join(d, "none"), reference=d)
            img = Image.open(out)
            self.assertEqual(img.width, 1536)
            self.assertEqual(img.height, 3 * sheet.CELL + 2 * sheet.DCELL + sheet.CELL)   # 4 close-ups: 2 detail rows
            self.assertEqual((filled["turntable"], filled["closeups"]), (8, 4))
            self.assertEqual(img.getpixel((sheet.DCELL + 200, 3 * sheet.CELL + 200)), (200, 90, 40))

    def test_studio_shots_match_presets(self):
        import sheet
        with tempfile.TemporaryDirectory() as d:
            for n in ("M_Veh_RIB_Clear_wet.png", "M_Veh_RIB_Clear_dry.png", "M_Veh_RIB_Helm_Overcast_dry.png",
                      "M_Veh_RIB_Closeup_bow.png", "Night.png"):
                open(os.path.join(d, n), "wb").close()
            self.assertEqual(os.path.basename(sheet.studio_image(d, "Clear")), "M_Veh_RIB_Clear_dry.png")
            self.assertIsNone(sheet.studio_image(d, "Overcast"))
            self.assertEqual(os.path.basename(sheet.studio_image(d, "Night")), "Night.png")


class ImporterOrientation(unittest.TestCase):
    """Uploaded MeshParts carry the FBX axis rotation (90, 0, 0) in PivotOffset; the importer must re-point every
    PivotOffset at the Model's authored WorldPivot before it sets PrimaryPart (else PivotTo tips the model onto its
    end). Guard on the source; the behaviour is tested in Studio by tools/studio/import_test.luau."""

    def test_importer_keeps_authored_pivot(self):
        with open(os.path.join(REPO, "tools", "studio", "import_asset.luau")) as f:
            src = f.read()
        fix = src.index("local authored = model.WorldPivot")
        self.assertLess(fix, src.index("model.PrimaryPart = primary"))
        self.assertIn("d.PivotOffset = d.CFrame:ToObjectSpace(authored)", src)
        with open(os.path.join(REPO, "tools", "studio", "import_test.luau")) as f:
            test = f.read()
        for needle in ("CFrame.Angles(math.rad(90), 0, 0)", "RIB length not on Z", "bollard height not on Y"):
            self.assertIn(needle, test)

    def test_rib_frame_maps_length_to_z_height_to_y(self):
        with open(os.path.join(REPO, "art", "source", "vehicles", "M_Veh_RIB", "frame_offset.json")) as f:
            bx, by, bz = json.load(f)["bbox_studs"]
        rx, ry, rz = (-bx, bz, by)            # export.py / rbxkit: roblox = (-bx, bz, by)
        self.assertGreater(abs(rz), max(abs(rx), abs(ry)))
        self.assertAlmostEqual(abs(ry), 9.5, delta=0.5)


if __name__ == "__main__":
    unittest.main()
