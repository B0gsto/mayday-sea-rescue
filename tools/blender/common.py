"""Shared paths, constants and small pure helpers for the Mayday Blender pipeline (docs/12-asset-list.md section 1).

Pure Python: imports inside Blender and from the system python3 (check_textures.py, the tests).
Ported from Gulp's assets/source/_shared/blender/common.py; species, fog-zone and palette code dropped.
"""
import datetime
import os
import re
import struct
import subprocess
import sys

LIB_DIR = os.path.dirname(os.path.abspath(__file__))            # tools/blender
REPO_DIR = os.path.dirname(os.path.dirname(LIB_DIR))
SHARED_TOOLS = os.path.expanduser("~/RobloxProjects/tools")
SHARED_BLENDER = os.path.join(SHARED_TOOLS, "blender")         # rbxkit.py lives here (measured axis mapping)
if SHARED_BLENDER not in sys.path:
    sys.path.append(SHARED_BLENDER)

# Folder layout: docs/12 section 1.3.
ART_DIR = os.path.join(REPO_DIR, "art")
SOURCE_DIR = os.path.join(ART_DIR, "source")
REFERENCE_DIR = os.path.join(ART_DIR, "reference")
STATUS_DIR = os.path.join(ART_DIR, "status")
ASSETS_DIR = os.path.join(REPO_DIR, "assets")
KINDS = ("vehicles", "buildings", "harbour", "roads", "veg", "rocks", "seabed", "kit", "characters", "animals", "fx")

# The output root (assets/) can be moved for self-tests: MAYDAY_OUT_ROOT=<dir> or run.py --out-root <dir>.
_out_root = os.environ.get("MAYDAY_OUT_ROOT") or ASSETS_DIR


def set_out_root(path):
    global _out_root
    _out_root = os.path.abspath(path) if path else ASSETS_DIR


def out_root():
    return _out_root


def _sub(kind, asset):
    path = os.path.join(_out_root, kind, asset)
    os.makedirs(path, exist_ok=True)
    return path


def fbx_dir(asset):
    return _sub("fbx", asset)


def textures_dir(asset):
    return os.path.join(_out_root, "textures", asset)      # not created: maps are written by bake / scan_ingest


def review_dir(asset):
    return _sub("review", asset)


def reference_dir(asset):
    return os.path.join(REFERENCE_DIR, asset)


# Scale: 05 section 4.1. 1 Blender unit = 1 stud (rbxkit's measured importer mapping), 1 m = 3 studs.
STUDS_PER_METRE = 3.0
MANNEQUIN_STUDS = 5.5

# Textures: docs/12 section 1.2. One constant; re-export the library at a new cap after Spike 1.
EXPORT_CAP = 1024
MASTER = 4096
MAP_KINDS = ("ALB", "NOR", "RGH", "MET")
MAP_EXTS = (".png", ".jpg", ".jpeg", ".tga", ".bmp")

UV_NAME = "UVMap"
LOD_SUFFIXES = ("LOD0", "LOD1", "LOD2")


def metres_to_studs(m):
    return m * STUDS_PER_METRE


def today():
    return datetime.date.today().isoformat()


def git_commit():
    try:
        out = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=REPO_DIR, capture_output=True, text=True, timeout=10)
        dirty = subprocess.run(["git", "status", "--porcelain", "--", "art", "assets", "tools/blender"], cwd=REPO_DIR,
                               capture_output=True, text=True, timeout=10)
        return (out.stdout.strip() or "unknown") + ("+dirty" if dirty.stdout.strip() else "")
    except Exception:
        return "unknown"


def find_asset_dir(asset_id):
    """The folder under art/source/<kind>/ named <asset_id> that holds a build.py."""
    hits = [root for root, dirs, files in os.walk(SOURCE_DIR)
            if os.path.basename(root) == asset_id and "build.py" in files]
    if len(hits) != 1:
        raise SystemExit("asset '%s': expected one build.py under art/source/, found %d %s" % (asset_id, len(hits), hits))
    return hits[0]


# ---------------------------------------------------------------- reference dimensions

_NUM = r"(-|[0-9]*\.?[0-9]+)"
_DIMS_RE = re.compile(r"dims_m\W*" + _NUM + r"\s*[x,]\s*" + _NUM + r"\s*[x,]\s*" + _NUM, re.IGNORECASE)


def parse_dims_md(text):
    """The real size in metres from a reference board's dims.md: the first line holding
    `dims_m: <x> x <y> x <z>` (Blender axes: X width, Y length (front is -Y), Z height; '-' for an axis the
    board does not fix, e.g. `dims_m: 0.35 x 0.35 x 0.55`). Returns a tuple with None for '-', or None."""
    m = _DIMS_RE.search(text)
    if not m:
        return None
    return tuple(None if g == "-" else float(g) for g in m.groups())


def reference_dims(asset):
    """(dims_m tuple or None, path or None) from art/reference/<asset>/dims.md."""
    path = os.path.join(reference_dir(asset), "dims.md")
    if not os.path.isfile(path):
        return None, None
    with open(path, "r", encoding="utf-8") as f:
        return parse_dims_md(f.read()), path


# ---------------------------------------------------------------- image headers (no Pillow inside Blender)

def image_size(path):
    """(width, height) of a PNG, JPEG, BMP or TGA file from its header, or None."""
    with open(path, "rb") as f:
        head = f.read(32)
        if head[:8] == b"\x89PNG\r\n\x1a\n":
            return struct.unpack(">II", head[16:24])
        if head[:2] == b"BM":
            w, h = struct.unpack("<ii", head[18:26])
            return w, abs(h)
        if head[:2] == b"\xff\xd8":
            f.seek(2)
            while True:
                marker = f.read(2)
                if len(marker) < 2 or marker[0] != 0xFF:
                    return None
                if marker[1] in (0xD8, 0x01) or 0xD0 <= marker[1] <= 0xD7:
                    continue
                length = struct.unpack(">H", f.read(2))[0]
                if marker[1] in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                    h, w = struct.unpack(">xHH", f.read(5))
                    return w, h
                f.seek(length - 2, 1)
        if path.lower().endswith(".tga") and len(head) >= 18:
            return struct.unpack("<HH", head[12:16])
    return None


def is_pow2(n):
    return n > 0 and n & (n - 1) == 0


def map_file(directory, stem):
    """The file for a texture stem (T_..._ALB) in `directory`, any allowed extension, or None."""
    for ext in MAP_EXTS:
        p = os.path.join(directory, stem + ext)
        if os.path.isfile(p):
            return p
    return None
