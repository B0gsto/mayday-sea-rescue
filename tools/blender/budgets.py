"""Triangle, LOD, texture-set and texel-density budgets per asset class (pure Python).

Copied from docs/05-art-direction.md section 5.6 (05 wins where they differ) and the rows docs/12 section 2 adds
(land vehicles, trailers, parked cars, vegetation). Change the docs first, then this table. All numbers (tune).

Row fields:
  tris      LOD0 ceiling for the whole asset (all LOD0 MeshParts together)
  tris_min  floor where the doc gives a range (waivable)
  per_part  ceiling per MeshPart (never above MAX_PER_MESHPART)
  lod1/lod2 LOD ceilings: an int is absolute, a float is a share of the asset's LOD0 ceiling;
            None means that LOD is not made (lod1 None: only ever close; lod2 None: culled / streamed out)
  sets      (min, max) texture sets at EXPORT_CAP, or "atlas" (the asset uses a shared atlas or trim)
  col       a _COL proxy is required
"""

MAX_PER_MESHPART = 10000          # 05 5.6: split heavy assets into MeshParts of 10,000 or fewer
ROBLOX_TRI_LIMIT = 20000          # engine cap per MeshPart (rbxkit.ROBLOX_TRI_LIMIT); export refuses above it
COL_MAX_TRIS = 1000               # a collision proxy is boxes or hulls (tune)
RIG_MAX_BONES = None              # set from Spike 1's skinned-mesh bone test (verify); Gulp's 32 is too low

# docs/12 1.1: LOD generation targets, a share of the actual LOD0 count (vehicles ~0.35 / 0.1, rocks 0.4 / 0.15,
# props 0.5 / cull). The ceiling of the row still applies; the lower of the two is the target.
LOD_SHARE = {
    "vehicle": (0.35, 0.1),
    "rock": (0.4, 0.15),
    "prop": (0.5, None),
    "building": (0.4, 0.1),
    "character": (0.4, 0.1),
    "veg": (0.5, 0.25),
}

BUDGETS = {
    # vessels and aircraft (05 5.6)
    "allweather_lifeboat": dict(tris=60000, per_part=10000, lod1=25000, lod2=6000, sets=(5, 6), col=True, share="vehicle"),
    "rib": dict(tris=35000, per_part=10000, lod1=12000, lod2=3000, sets=(3, 4), col=True, share="vehicle"),
    "jetski": dict(tris=20000, per_part=10000, lod1=8000, lod2=2000, sets=(2, 2), col=True, share="vehicle"),
    "helicopter": dict(tris=60000, per_part=10000, lod1=25000, lod2=6000, sets=(5, 6), col=True, share="vehicle"),
    "big_ship": dict(tris=90000, per_part=10000, lod1=30000, lod2=8000, sets=(6, 8), col=True, share="vehicle"),
    "small_craft": dict(tris=20000, per_part=10000, lod1=8000, lod2=2000, sets=(1, 3), col=True, share="vehicle"),   # kayak, paddleboard, liferaft (12 2.x; tune)
    # land vehicles (12 2.1, not in 05's table; tune)
    "land_vehicle": dict(tris=30000, per_part=10000, lod1=12000, lod2=3000, sets=(4, 4), col=True, share="vehicle"),
    "trailer": dict(tris=8000, per_part=8000, lod1=4000, lod2=1000, sets=(1, 1), col=True, share="vehicle"),
    "parked_car": dict(tris=15000, per_part=10000, lod1=6000, lod2=1500, sets=(2, 2), col=True, share="vehicle"),
    # close-up sets (05 5.6)
    "viewmodel": dict(tris=12000, per_part=10000, lod1=None, lod2=None, sets=(2, 2), col=False, share="character"),
    "jetski_closeup": dict(tris=8000, per_part=8000, lod1=None, lod2=None, sets=(1, 1), col=False, share="vehicle"),
    "helm_interior": dict(tris=30000, tris_min=15000, per_part=10000, lod1=None, lod2=None, sets=(2, 3), col=False, share="vehicle"),
    # characters and animals (05 5.6)
    "npc_person": dict(tris=20000, per_part=10000, lod1=8000, lod2=2000, sets=(2, 2), col=False, share="character"),
    "dog": dict(tris=25000, per_part=10000, lod1=10000, lod2=3000, sets=(2, 3), col=False, share="character"),
    "dog_fur_cards": dict(tris=15000, per_part=10000, lod1=0.4, lod2=0.1, sets=(1, 1), col=False, share="character"),
    # buildings (05 5.6)
    "hero_building": dict(tris=40000, per_part=10000, lod1=15000, lod2=3000, sets=(4, 5), col=True, share="building"),
    "building_module": dict(tris=8000, tris_min=3000, per_part=8000, lod1=0.5, lod2=None, sets="atlas", col=False, share="building"),
    # nature (05 5.6, 12 2.5 to 2.7)
    "rock": dict(tris=15000, tris_min=5000, per_part=10000, lod1=0.4, lod2=0.15, sets=(1, 1), col=True, share="rock"),
    "boulder": dict(tris=8000, tris_min=2000, per_part=8000, lod1=0.4, lod2=0.15, sets=(1, 1), col=False, share="rock"),
    "vegetation": dict(tris=6000, tris_min=300, per_part=6000, lod1=0.5, lod2=0.25, sets="atlas", col=False, share="veg"),
    # props (05 5.6)
    "small_prop": dict(tris=3000, tris_min=500, per_part=3000, lod1=0.5, lod2=None, sets="atlas", col=False, share="prop"),
    "large_prop": dict(tris=8000, tris_min=1000, per_part=8000, lod1=0.5, lod2=0.25, sets=(1, 2), col=True, share="prop"),   # nav marks, pontoons (12 2.3; tune)
}

# 05 section 5.3: texel density targets, pixels per stud.
TIERS = {"hero": (100, 128), "standard": (51, None), "background": (25, None)}
TEXEL_TOLERANCE = 0.9             # pass at 90% of the target (tune): decimation and packing margins cost a little

# 12 1.1: real-size check, 05 4.1.
SIZE_FREE = 0.05                  # pass with no note
SIZE_NOTED = 0.15                 # pass only with a written gameplay note in the spec ("size_note")


def row(budget_class):
    if budget_class not in BUDGETS:
        raise KeyError("budget class '%s' is not one of %s" % (budget_class, ", ".join(sorted(BUDGETS))))
    return BUDGETS[budget_class]


def lod0_ceiling(budget_class, asset_tris=None):
    """The asset's own LOD0 ceiling (its docs/12 row, e.g. a bollard's 800) capped by the class ceiling."""
    r = row(budget_class)
    return min(asset_tris, r["tris"]) if asset_tris else r["tris"]


def per_part_ceiling(budget_class):
    return min(row(budget_class)["per_part"], MAX_PER_MESHPART)


def lod_ceiling(budget_class, lod, asset_tris=None):
    """Ceiling for LOD1 / LOD2 of the whole asset, or None when that LOD is not made."""
    if lod == "LOD0":
        return lod0_ceiling(budget_class, asset_tris)
    value = row(budget_class)["lod1" if lod == "LOD1" else "lod2"]
    if value is None:
        return None
    if isinstance(value, float):
        return int(value * lod0_ceiling(budget_class, asset_tris))
    if asset_tris:          # an asset row smaller than its class scales the class's absolute LOD ceilings with it
        return min(value, int(value * lod0_ceiling(budget_class, asset_tris) / float(row(budget_class)["tris"])) or 1)
    return value


def lods_made(budget_class):
    """The LODs versions.py generates for this class."""
    r = row(budget_class)
    out = []
    if r["lod1"] is not None:
        out.append("LOD1")
        if r["lod2"] is not None:
            out.append("LOD2")
    return out


def lod_target(budget_class, lod, lod0_tris, asset_tris=None):
    """Triangle target for generating one LOD mesh from a LOD0 mesh of `lod0_tris`: the class share of the actual
    count, never above the LOD ceiling share of this mesh."""
    shares = LOD_SHARE[row(budget_class)["share"]]
    share = shares[0] if lod == "LOD1" else shares[1]
    ceiling = lod_ceiling(budget_class, lod, asset_tris)
    if ceiling is None:
        return None
    lod0_ceil = lod0_ceiling(budget_class, asset_tris)
    by_ceiling = int(lod0_tris * ceiling / float(lod0_ceil))
    return max(4, by_ceiling if share is None else min(int(lod0_tris * share), by_ceiling))


def sets_ok(budget_class, n_sets, atlas=False):
    """(ok, rule text) for the number of unique texture sets."""
    want = row(budget_class)["sets"]
    if want == "atlas":
        return (atlas or n_sets <= 1), "shared atlas or trim (at most 1 unique set)"
    lo, hi = want
    return lo <= n_sets <= hi, "%d to %d sets" % (lo, hi)


def texel_target(tier):
    if tier not in TIERS:
        raise KeyError("tier '%s' is not one of %s" % (tier, ", ".join(TIERS)))
    return TIERS[tier]


def size_verdict(actual, wanted, note=None):
    """Real-size check for one axis or the worst axis. Returns (ok, waived, deviation)."""
    dev = abs(actual - wanted) / wanted
    if dev <= SIZE_FREE + 1e-9:
        return True, False, dev
    if dev <= SIZE_NOTED + 1e-9 and note:
        return True, True, dev
    return False, False, dev
