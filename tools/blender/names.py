"""Name rules (docs/12-asset-list.md section 1.3). Pure Python; tested by test_validate_names.py.

Each *_problem(name) returns None when the name is good, else a short reason.
"""
import re

CATEGORIES = ("Veh", "Bld", "Hbr", "Road", "Veg", "Rock", "Sea", "Kit", "Chr", "Ani", "Prop")
MESH_SUFFIXES = ("HP", "LOD0", "LOD1", "LOD2", "COL")
MAP_SUFFIXES = ("ALB", "NOR", "RGH", "MET")

WORD = r"[A-Z][A-Za-z0-9]*"
NN = r"\d\d"
RE_WORD = re.compile(r"^%s$" % WORD)
RE_NN = re.compile(r"^%s$" % NN)
RE_RIG = re.compile(r"^RIG_%s$" % WORD)
RE_ACTION = re.compile(r"^A_%s(_%s)+$" % (WORD, WORD))
RE_FX = re.compile(r"^FX_%s(_%s)+$" % (WORD, WORD))
RE_SFX = re.compile(r"^SFX_%s(_%s)+(_%s)?$" % (WORD, WORD, NN))
RE_ATTACH = re.compile(r"^ATT_%s(_%s)*(_%s)?$" % (WORD, WORD, NN))


def mesh_parts(name):
    """{'cat', 'words', 'nn', 'suffix'} for a good mesh name, else raises ValueError with the reason.
    Pattern: M_<Cat>_<Name>[_NN][_HP|_LOD0|_LOD1|_LOD2|_COL]; <Name> is one or more PascalCase words."""
    parts = name.split("_")
    if len(parts) < 3 or parts[0] != "M":
        raise ValueError("must be M_<Cat>_<Name>[_NN][_HP|_LOD0|_LOD1|_LOD2|_COL]")
    cat, rest = parts[1], parts[2:]
    if cat not in CATEGORIES:
        raise ValueError("category '%s' is not one of %s" % (cat, ", ".join(CATEGORIES)))
    suffix = rest[-1] if rest[-1] in MESH_SUFFIXES else None
    if suffix:
        rest = rest[:-1]
    nn = rest[-1] if rest and RE_NN.match(rest[-1]) else None
    if nn:
        rest = rest[:-1]
    if not rest:
        raise ValueError("no name words before '%s'" % (nn or suffix))
    for w in rest:
        if w in MESH_SUFFIXES:
            raise ValueError("suffix '%s' must end the name" % w)
        if RE_NN.match(w):
            raise ValueError("the two-digit number '%s' must come right before the suffix" % w)
        if not RE_WORD.match(w):
            raise ValueError("'%s' is not a PascalCase word (no spaces, hyphens or lower-case starts)" % w)
    return {"cat": cat, "words": rest, "nn": nn, "suffix": suffix}


def mesh_name_problem(name):
    try:
        mesh_parts(name)
    except ValueError as e:
        return str(e)
    return None


def mesh_base(name):
    """M_Hbr_Bollard_01_LOD0 -> M_Hbr_Bollard_01 (the name without its suffix)."""
    p = mesh_parts(name)
    return "_".join(["M", p["cat"]] + p["words"] + ([p["nn"]] if p["nn"] else []))


def with_suffix(name, suffix):
    """Replace or add the mesh suffix: with_suffix('M_Veh_RIB_Hull_LOD0', 'LOD1') -> 'M_Veh_RIB_Hull_LOD1'."""
    return mesh_base(name) + ("_" + suffix if suffix else "")


def texture_parts(stem):
    """T_<Name>_<Set>_<ALB|NOR|RGH|MET>[_Wet] (no extension) -> {'name', 'set', 'map', 'wet'}; raises ValueError."""
    parts = stem.split("_")
    if parts[0] != "T":
        raise ValueError("must start with T_")
    wet = parts[-1] == "Wet"
    if wet:
        parts = parts[:-1]
    if len(parts) < 4:
        raise ValueError("must be T_<Name>_<Set>_<ALB|NOR|RGH|MET>[_Wet]")
    kind = parts[-1]
    if kind not in MAP_SUFFIXES:
        raise ValueError("map suffix '%s' is not one of %s" % (kind, ", ".join(MAP_SUFFIXES)))
    words = parts[1:-1]
    for w in words:
        if w in MAP_SUFFIXES or w == "Wet":
            raise ValueError("'%s' must end the name" % w)
        if not (RE_WORD.match(w) or RE_NN.match(w)):
            raise ValueError("'%s' is not a PascalCase word or a two-digit number" % w)
    if RE_NN.match(words[0]):
        raise ValueError("the name must start with a word")
    return {"name": "_".join(words[:-1]), "set": words[-1], "map": kind, "wet": wet}


def texture_name_problem(stem):
    try:
        texture_parts(stem)
    except ValueError as e:
        return str(e)
    return None


def texture_stem(name, set_name, kind, wet=False):
    return "T_%s_%s_%s%s" % (name, set_name, kind, "_Wet" if wet else "")


def attachment_name_problem(name):
    return None if RE_ATTACH.match(name) else "must be ATT_<Name>[_NN] (PascalCase words)"


def rig_name_problem(name):
    return None if RE_RIG.match(name) else "must be RIG_<Name>"


def action_name_problem(name):
    return None if RE_ACTION.match(name) else "must be A_<Rig>_<Action>"


def fx_name_problem(name):
    if name.startswith("SFX_"):
        return None if RE_SFX.match(name) else "must be SFX_<Group>_<Name>[_NN]"
    return None if RE_FX.match(name) else "must be FX_<Group>_<Name>"
