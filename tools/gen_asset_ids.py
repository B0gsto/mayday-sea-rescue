#!/usr/bin/env python3
"""gen_asset_ids.py: generates the game's asset id tables from assets/manifest.json (docs/06 step 18,
docs/12 section 1). Run by hand after every upload batch, from the repo root or anywhere:

    python3 tools/gen_asset_ids.py

Writes
  src/shared/Config/AssetIds.luau          Models[<asset>][LOD0|LOD1|LOD2] = "rbxassetid://N",
                                           Attachments[<asset>][ATT_*] = Vector3 (studs, from the authored
                                           pivot, from assets/fbx/<asset>/<asset>.attachments.json)
  src/server/Assets/Appearances.model.json a Folder per asset, a Folder per texture set, holding the
                                           SurfaceAppearances "Dry" and "Wet" (map ids are not writable
                                           from game scripts, so they are built into the place by Rojo and
                                           cloned at run time by AssetLoader)

The manifest keeps every upload of a source (keyed by content hash): the id used is the entry whose sha
matches the file on disk now; when the file is missing, the entry listed in art/status/*.csv, else the
last entry (with a warning).
"""
import csv
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "manifest.json")
OUT_LUAU = os.path.join(ROOT, "src", "shared", "Config", "AssetIds.luau")
OUT_APPEAR = os.path.join(ROOT, "src", "server", "Assets", "Appearances.model.json")
MAPS = {"ALB": "ColorMap", "NOR": "NormalMap", "RGH": "RoughnessMap", "MET": "MetalnessMap"}
# Texture folders whose ALB alpha is a cutout (docs/12 2.8 alpha cards): AlphaMode Transparency (Enum 1).
# The default, Overlay, shows the part Color through alpha 0, so the G1 plant cards rendered flat white.
ALPHA_TRANSPARENCY = ("M_Veg_",)
# Single texture sets that are alpha cards inside an otherwise opaque asset: (asset, set).
ALPHA_TRANSPARENCY_SETS = {("M_Chr_Bosun", "Fur"), ("M_Bld_Station", "Grime"), ("M_Hbr_PropAtlas", "Rope"), ("M_Bld_Cottage_Kit", "Grime"), ("M_Sea_Morwenna", "Kelp"), ("M_Sea_AdmiraltyAnchor", "Sand"), ("M_Veh_GaleQueen", "Decals")}  # Morwenna kelp cards (S1a); anchor sand bed alpha rim (POL2); Bosun fur cards (DogService); station H3 grime decals; cottage H3b grime decals
SHARED_BYTES = ("M_Veh_SupplyBarge", "M_Bld_WorkshopAddons", "M_Bld_FishMarketAddons", "M_Bld_ClinicAddons", "M_Bld_LookoutAddons")  # their NOR/RGH/MET are the Depot palette's bytes
FX_RE = re.compile(r"^assets/textures/FX/(FX_\w+)\.png$")  # FX1 / FX2 flipbooks and foam maps (docs/12 2.11)
TEX_RE = re.compile(r"^assets/textures/(M_\w+?)/T_\w+?_([A-Za-z][A-Za-z0-9]*(?:_\d+)?)_(ALB|NOR|RGH|MET)(_Wet)?\.png$")

# WP-16 asset diet (docs/23 (j)): assets nothing in src/ or map/ loads (cut cars, town, kits, spikes; scan before
# adding one back) are left out of both outputs; their uploads stay in the manifest
DROP = {
    "M_Bld_BoatyardShed", "M_Bld_Chandlery_Ext", "M_Bld_Chandlery_Int", "M_Bld_Cottage_01", "M_Bld_Cottage_03",
    "M_Bld_Cottage_04", "M_Bld_Cottage_05", "M_Bld_Cottage_06", "M_Bld_HarbourLight", "M_Bld_Harbourmaster",
    "M_Bld_Hospital", "M_Bld_LifeguardTower", "M_Bld_Slipway", "M_Bld_Station", "M_Chr_Casualty_Swimmer",
    "M_Chr_Casualty_Swimmer_Rig", "M_Chr_HumanBase_F", "M_Chr_HumanBase_M", "M_Hbr_Bollard_03", "M_Hbr_Cleat_01",
    "M_Hbr_Cleat_02", "M_Hbr_Fender_Ball", "M_Hbr_Fender_Cyl_01", "M_Hbr_Fender_Cyl_02", "M_Hbr_Fender_Cyl_03",
    "M_Hbr_Pontoon", "M_Hbr_Pontoon_Corner", "M_Hbr_Pontoon_Finger", "M_Hbr_Pontoon_Gangway",
    "M_Hbr_Pontoon_Straight12", "M_Hbr_Pontoon_Straight6", "M_Hbr_QuayKit_Armour", "M_Hbr_QuayKit_Corner",
    "M_Hbr_QuayKit_Steps", "M_Hbr_Rope_Chain", "M_Hbr_Rope_Flaked", "M_Hbr_TravelHoist", "M_Kit_Atlas",
    "M_Kit_Bridle", "M_Kit_ChartTablet", "M_Kit_FirstAidBag", "M_Kit_HandFlare", "M_Kit_HeavingLine",
    "M_Kit_Lifebuoy", "M_Kit_LineKnife", "M_Kit_OxygenBag", "M_Kit_ParaFlare", "M_Kit_RescueTube",
    "M_Kit_StretcherBasket", "M_Kit_Strobe", "M_Kit_ThermalBlanket", "M_Kit_ThermalBlanketDraped", "M_Kit_ThrowBag",
    "M_Kit_ThrowLine", "M_Kit_TriageTags", "M_Kit_VHFHandset", "M_Prop_Chandlery", "M_Prop_Chandlery_Stock",
    "M_Road_Bench", "M_Road_Bin", "M_Road_Bollard", "M_Road_CornishHedge", "M_Road_CrashBarrier",
    "M_Road_DryStoneWall", "M_Road_FieldGate", "M_Road_ParkedCar_01", "M_Road_ParkedCar_02", "M_Road_ParkedCar_03",
    "M_Road_Ribbon", "M_Road_Sign_Kit", "M_Road_StreetLamp", "M_Rock_Cliff_06", "M_Rock_Cliff_07", "M_Rock_Cliff_08",
    "M_Rock_IslandProxy_Kit", "M_Rock_Ledge_04", "M_Rock_NeedlesEye", "M_Sea_BottleField", "M_Sea_LostPot",
    "M_Sea_MooringBlock", "M_Spike1_RefBox", "M_Spike1_ScaleCube", "M_Spike1_Tentacle20", "M_Spike1_Tentacle40",
    "M_Spike1_TexPlane", "M_Spike1_Tris09990", "M_Spike1_Tris19990", "M_Spike1_Tris20500", "M_Spike1_Tris21500",
    "M_Spike1_Tris30000", "M_Veg_Eelgrass_Kit", "M_Veg_Wrack_Kit", "M_Veh_ATV", "M_Veh_Ambulance",
    "M_Veh_BoatTrailer_JetSki", "M_Veh_BoatTrailer_RIB", "M_Veh_Coastguard4x4", "M_Veh_HarbourGT", "M_Veh_Kayak",
    "M_Veh_LifeguardPickup", "M_Veh_LighthouseCruiser", "M_Veh_Optimist", "M_Veh_Paddleboard",
}

RIG_SETS = ("Atlas",)  # texture sets a rigged (single skinned MeshPart) asset keeps

_sha_cache = {}


def disk_sha(rel):
    if rel not in _sha_cache:
        try:
            with open(os.path.join(ROOT, rel), "rb") as f:
                _sha_cache[rel] = hashlib.sha256(f.read()).hexdigest()
        except OSError:
            _sha_cache[rel] = None
    return _sha_cache[rel]


def csv_ids():
    ids = set()
    for path in glob.glob(os.path.join(ROOT, "art", "status", "*.csv")):
        with open(path, newline="") as f:
            for row in csv.DictReader(f):
                if (row.get("assetId") or "").strip():
                    ids.add(row["assetId"].strip())
    return ids


def pick(entries, listed, label):
    """entries: manifest entries sharing one source file. Returns the current one."""
    src = entries[0].get("source", "")
    cur = disk_sha(src)
    if cur:
        hit = [e for e in entries if e.get("sha") and cur.startswith(e["sha"])]
        if hit:
            return hit[-1]
    hit = [e for e in entries if e.get("assetId") in listed]
    if hit:
        return hit[-1]
    if len(entries) > 1 or cur:
        print(f"warning: {label}: no upload matches {src} on disk; using the last entry", file=sys.stderr)
    return entries[-1]


def main():
    with open(MANIFEST) as f:
        manifest = json.load(f)
    listed = csv_ids()
    by_source = {}
    for e in manifest.values():
        if e.get("source") and e.get("assetId"):
            by_source.setdefault((e.get("type"), e["source"]), []).append(e)

    models, textures, fx = {}, {}, {}
    # a map with the same bytes as one already uploaded (a shared palette) is keyed under the first file's path only:
    # give SHARED_BYTES assets' files their own source too, so they get the full set (opt-in: older assets that ship
    # without such maps would change look)
    by_sha = {e["sha"]: e for e in manifest.values() if e.get("type") == "Image" and e.get("sha") and e.get("assetId")}
    for path in (p for a in SHARED_BYTES for p in glob.glob(os.path.join(ROOT, "assets", "textures", a, "T_*.png"))):
        rel = os.path.relpath(path, ROOT)
        if ("Image", rel) not in by_source and TEX_RE.match(rel) and disk_sha(rel) in by_sha:
            by_source[("Image", rel)] = [dict(by_sha[disk_sha(rel)], source=rel)]
    for (kind, src), entries in sorted(by_source.items()):
        e = pick(entries, listed, src)
        if kind == "Model":
            m = re.match(r"^(.*?)(?:_(LOD\d))?$", e["name"])
            base, lod = m[1], m[2]
            if not lod:
                s = re.search(r"_(LOD\d)\.fbx$", src)
                lod = s[1] if s else "LOD0"
            if base.endswith("_RigRaw"):  # a rigged re-upload (new version) of an asset's LOD0
                base = base[: -len("Raw")]
            if base not in DROP:
                models.setdefault(base, {})[lod] = e["assetId"]
        elif kind == "Image":
            f = FX_RE.match(src)
            if f and e.get("imageId"):
                fx[f[1]] = e["imageId"]
            r = TEX_RE.match(src)
            if r and e.get("imageId") and r[1] not in DROP:
                s = textures.setdefault(r[1], {}).setdefault(r[2], {})
                (s.setdefault("Wet", {}) if r[4] else s)[r[3]] = e["imageId"]

    # <asset>_Rig shares the asset's markers and its merged texture set (RIG_SETS) with the static asset
    for base in models:
        src_asset = base[: -len("_Rig")] if base.endswith("_Rig") else None
        if src_asset and src_asset in textures:
            keep = {k: v for k, v in textures[src_asset].items() if k in RIG_SETS}
            if keep:
                textures[base] = keep

    attachments = {}
    for base in models:
        stem = base[: -len("_Rig")] if base.endswith("_Rig") else base
        path = os.path.join(ROOT, "assets", "fbx", stem, stem + ".attachments.json")
        if os.path.exists(path):
            with open(path) as f:
                d = json.load(f)
            attachments[base] = {a["name"]: a["roblox_from_origin"] for a in d.get("attachments", [])}

    def num(v):
        t = ("%.4f" % v).rstrip("0").rstrip(".")
        return "0" if t in ("-0", "") else t

    uri = lambda i: f'"rbxassetid://{i}"'
    out = [
        "--!strict",
        "-- GENERATED by tools/gen_asset_ids.py from assets/manifest.json. Do not edit; re-run the tool.",
        "-- Models[asset][LOD] are asset URIs; Attachments[asset][ATT_*] are",
        "-- positions in studs from the asset's authored pivot (Blender origin, upright, forward -Z).",
        "",
        "local AssetIds = {}",
        "",
        "AssetIds.Models = {",
    ]
    for base in sorted(models):
        lods = ", ".join(f"{k} = {uri(v)}" for k, v in sorted(models[base].items()))
        out.append(f"\t{base} = {{ {lods} }},")
    # no Textures table (WP-16): nothing reads it, AssetLoader clones the maps from Appearances.model.json
    out += ["} :: { [string]: { [string]: string } }", "", "AssetIds.Attachments = {"]
    for asset in sorted(attachments):
        out.append(f"\t{asset} = {{")
        for name, p in attachments[asset].items():
            out.append(f"\t\t{name} = Vector3.new({num(p[0])}, {num(p[1])}, {num(p[2])}),")
        out.append("\t},")
    out += ["} :: { [string]: { [string]: Vector3 } }", "", "-- FX flipbook sheets and foam maps (Image ids), read by src/shared/Fx/Flipbooks.luau",
            "AssetIds.Fx = {"]
    out += [f"\t{name} = {uri(fx[name])}," for name in sorted(fx)]
    out += ["} :: { [string]: string }", "", "return AssetIds", ""]
    with open(OUT_LUAU, "w") as f:
        f.write("\n".join(out))
    stylua = shutil.which("stylua")
    if stylua:  # check.sh runs stylua --check on src
        subprocess.run([stylua, OUT_LUAU], check=False)

    def appearance(name, maps, asset, set_name=None):
        props = {MAPS[k]: f"rbxassetid://{maps[k]}" for k in MAPS if k in maps}
        if asset.startswith(ALPHA_TRANSPARENCY) or (asset, set_name) in ALPHA_TRANSPARENCY_SETS:
            props["AlphaMode"] = {"Enum": 1}  # Enum.AlphaMode.Transparency
        return {"Name": name, "ClassName": "SurfaceAppearance", "Properties": props}

    folders = []
    for asset in sorted(textures):
        sets = []
        for name, s in sorted(textures[asset].items()):
            kids = [appearance("Dry", s, asset, name)]
            if s.get("Wet"):
                kids.append(appearance("Wet", {**{k: v for k, v in s.items() if k != "Wet"}, **s["Wet"]}, asset, name))
            sets.append({"Name": name, "ClassName": "Folder", "Children": kids})
        folders.append({"Name": asset, "ClassName": "Folder", "Children": sets})
    os.makedirs(os.path.dirname(OUT_APPEAR), exist_ok=True)
    with open(OUT_APPEAR, "w") as f:
        json.dump({"ClassName": "Folder", "Children": folders}, f, indent=1)
        f.write("\n")
    print(f"models {len(models)}, texture assets {len(textures)}, attachment sets {len(attachments)}")
    for base in ("M_Veh_RIB", "M_Veh_RIB_Helm"):
        print(base, models.get(base))


if __name__ == "__main__":
    main()
