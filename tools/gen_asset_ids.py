#!/usr/bin/env python3
"""gen_asset_ids.py: generates the game's asset id tables from assets/manifest.json (docs/06 step 18,
docs/12 section 1). Run by hand after every upload batch, from the repo root or anywhere:

    python3 tools/gen_asset_ids.py

Writes
  src/shared/Config/AssetIds.luau          Models[<asset>][LOD0|LOD1|LOD2] = "rbxassetid://N",
                                           Textures[<asset>][<set>] = {ALB, NOR, RGH, MET, Wet = {...}},
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
TEX_RE = re.compile(r"^assets/textures/(M_\w+?)/T_\w+?_([A-Za-z][A-Za-z0-9]*(?:_\d+)?)_(ALB|NOR|RGH|MET)(_Wet)?\.png$")

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

    models, textures = {}, {}
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
            models.setdefault(base, {})[lod] = e["assetId"]
        elif kind == "Image":
            r = TEX_RE.match(src)
            if r and e.get("imageId"):
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
        "-- Models[asset][LOD] and Textures[asset][set][map] are asset URIs; Attachments[asset][ATT_*] are",
        "-- positions in studs from the asset's authored pivot (Blender origin, upright, forward -Z).",
        "",
        "local AssetIds = {}",
        "",
        "AssetIds.Models = {",
    ]
    for base in sorted(models):
        lods = ", ".join(f"{k} = {uri(v)}" for k, v in sorted(models[base].items()))
        out.append(f"\t{base} = {{ {lods} }},")
    out += ["} :: { [string]: { [string]: string } }", "", "AssetIds.Textures = {"]
    for asset in sorted(textures):
        out.append(f"\t{asset} = {{")
        for name, s in sorted(textures[asset].items()):
            maps = [f"{k} = {uri(s[k])}" for k in MAPS if k in s]
            if s.get("Wet"):
                maps.append("Wet = { " + ", ".join(f"{k} = {uri(s['Wet'][k])}" for k in MAPS if k in s["Wet"]) + " }")
            out.append(f"\t\t{name} = {{ " + ", ".join(maps) + " },")
        out.append("\t},")
    out += ["} :: { [string]: { [string]: any } }", "", "AssetIds.Attachments = {"]
    for asset in sorted(attachments):
        out.append(f"\t{asset} = {{")
        for name, p in attachments[asset].items():
            out.append(f"\t\t{name} = Vector3.new({num(p[0])}, {num(p[1])}, {num(p[2])}),")
        out.append("\t},")
    out += ["} :: { [string]: { [string]: Vector3 } }", "", "return AssetIds", ""]
    with open(OUT_LUAU, "w") as f:
        f.write("\n".join(out))
    stylua = shutil.which("stylua")
    if stylua:  # check.sh runs stylua --check on src
        subprocess.run([stylua, OUT_LUAU], check=False)

    def appearance(name, maps):
        props = {MAPS[k]: f"rbxassetid://{maps[k]}" for k in MAPS if k in maps}
        return {"Name": name, "ClassName": "SurfaceAppearance", "Properties": props}

    folders = []
    for asset in sorted(textures):
        sets = []
        for name, s in sorted(textures[asset].items()):
            kids = [appearance("Dry", s)]
            if s.get("Wet"):
                kids.append(appearance("Wet", {**{k: v for k, v in s.items() if k != "Wet"}, **s["Wet"]}))
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
