"""Name rule tests (docs/12 1.3). No Blender:  python3 tools/blender/test_validate_names.py"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import names  # noqa: E402
import validate  # noqa: E402  (imports without bpy)


class MeshNames(unittest.TestCase):
    def test_doc_examples(self):
        for name in ("M_Veh_RIB_LOD0", "M_Bld_Cottage_Wall_02_LOD1", "M_Prop_Bollard_01_COL", "M_Hbr_Bollard_01",
                     "M_Veh_JetSki_CloseUp", "M_Veh_RIB_Helm", "M_Rock_Cliff_08_LOD2", "M_Veh_RIB_HP", "M_Chr_Aggie_Head_LOD0"):
            self.assertIsNone(names.mesh_name_problem(name), name)

    def test_every_category(self):
        for cat in names.CATEGORIES:
            self.assertIsNone(names.mesh_name_problem("M_%s_Thing_LOD0" % cat))

    def test_bad(self):
        bad = ["M_Fish_Minnow",            # unknown category
               "M_Veh_LOD0",               # no name before the suffix
               "M_Veh_RIB_LOD0_COL",       # suffix not at the end
               "M_Veh_rib",                # lower-case word
               "M_Veh_RIB-Hull",           # hyphen
               "M_Veh_RIB Hull",           # space
               "M_Veh_01_RIB",             # number before the name words
               "M_Veh_RIB_1",              # one digit
               "Veh_RIB", "SM_Veh_RIB", "M_Veh"]
        for name in bad:
            self.assertIsNotNone(names.mesh_name_problem(name), name)

    def test_validate_reexports_the_rule(self):
        self.assertIsNone(validate.names.mesh_name_problem("M_Kit_Lifebuoy_LOD0"))

    def test_suffix_helpers(self):
        self.assertEqual(names.mesh_base("M_Hbr_Bollard_01_LOD0"), "M_Hbr_Bollard_01")
        self.assertEqual(names.with_suffix("M_Veh_RIB_Hull_LOD0", "LOD2"), "M_Veh_RIB_Hull_LOD2")
        self.assertEqual(names.with_suffix("M_Prop_Crate", "LOD1"), "M_Prop_Crate_LOD1")
        self.assertEqual(names.mesh_parts("M_Bld_Cottage_Wall_02_LOD1"),
                         {"cat": "Bld", "words": ["Cottage", "Wall"], "nn": "02", "suffix": "LOD1"})


class TextureNames(unittest.TestCase):
    def test_doc_examples(self):
        self.assertEqual(names.texture_parts("T_RIB_Hull_ALB"), {"name": "RIB", "set": "Hull", "map": "ALB", "wet": False})
        self.assertEqual(names.texture_parts("T_RIB_Hull_RGH_Wet"), {"name": "RIB", "set": "Hull", "map": "RGH", "wet": True})
        self.assertEqual(names.texture_parts("T_HarbourProps_Metal_NOR")["set"], "Metal")
        self.assertEqual(names.texture_parts("T_Cottage_Wall_02_MET")["set"], "02")

    def test_bad(self):
        for stem in ("T_RIB_ALB", "T_RIB_Hull_COL", "T_RIB_Hull_ALB_Dry", "RIB_Hull_ALB", "T_RIB_Hull_alb",
                     "T_RIB_ALB_Hull_NOR", "T_rib_Hull_ALB", "T_RIB_Hull_Wet_ALB", "T_01_Hull_ALB"):
            self.assertIsNotNone(names.texture_name_problem(stem), stem)

    def test_stem_round_trip(self):
        stem = names.texture_stem("RIB", "Deck", "RGH", wet=True)
        self.assertEqual(stem, "T_RIB_Deck_RGH_Wet")
        self.assertIsNone(names.texture_name_problem(stem))


class OtherNames(unittest.TestCase):
    def test_good(self):
        self.assertIsNone(names.rig_name_problem("RIG_Bosun"))
        self.assertIsNone(names.action_name_problem("A_Bosun_SwimTow"))
        self.assertIsNone(names.fx_name_problem("FX_Spray_BowSheet"))
        self.assertIsNone(names.fx_name_problem("SFX_Eng_RIB_Plane"))
        self.assertIsNone(names.fx_name_problem("SFX_Eng_Plane_02"))
        self.assertIsNone(names.attachment_name_problem("ATT_RopeNeck"))
        self.assertIsNone(names.attachment_name_problem("ATT_Seat_Helm_02"))

    def test_bad(self):
        self.assertIsNotNone(names.rig_name_problem("Rig_Bosun"))
        self.assertIsNotNone(names.action_name_problem("A_Bosun"))
        self.assertIsNotNone(names.fx_name_problem("FX_Spray"))
        self.assertIsNotNone(names.fx_name_problem("SFX_Eng_plane"))
        self.assertIsNotNone(names.attachment_name_problem("Empty"))
        self.assertIsNotNone(names.attachment_name_problem("ATT_rope"))
        self.assertIsNotNone(names.attachment_name_problem("Att_Rope"))


if __name__ == "__main__":
    unittest.main()
