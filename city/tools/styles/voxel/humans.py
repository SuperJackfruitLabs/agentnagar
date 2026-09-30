"""Blocky voxel humans on the shared human rig.

The rig is task 2.3's `rig_human` (city/tools/styles/lowpoly/characters.py):
bones hips, spine, chest, neck, head and, per side, upper_arm, forearm,
hand, thigh, shin and foot (`_l` is the character's left, -x). `parts()`
gives, for every bone, the voxels that move with it, sorted into the
character's recolourable objects, placed so the joints fall where the rig's
joints are (hip 0.83 m, knee 0.485 m, shoulder 1.34 m, elbow 1.08 m, wrist
0.855 m, neck 1.39 m). build_humans.py (Blender) meshes them, skins each
object rigidly to the rig, adds the rig's walk, sit, idle and typing
actions and writes `human.glb`.

Objects and materials follow the low-poly character's convention, so the
pack recolours by `material_override` on the node of that name:
    skin, top, bottom, shoes          one material each, named after the role
    details                           eye, mouth, belt
    hair_0 (bun), hair_1 (short), hair_2 (long), hair_3 (curly)
                                      material `hair`; the pack shows one
    hat_sun                           straw, hat_band (an accessory)
    backpack                          material `backpack` (an accessory)
`VARIANTS` are ready-made looks: role -> palette key, plus a hair style and
the accessories to show.

Axes: Godot's, y up, the character facing -z, feet on y = 0, 1.8 m to the
top of the hair. Voxels are 5 cm.

Ruling: humans use 5 cm voxels, not the kit's 10 cm: at 10 cm a 1.75 m
person is 17 voxels tall and has no face, and the sheets' people show eyes,
hair shapes and hands.
"""
from voxel import Asset, Grid, unit

HUMAN_VOXEL = 0.05

BONES = ["hips", "spine", "chest", "neck", "head",
         "upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
         "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]

OBJECTS = ["skin", "top", "bottom", "shoes", "details", "hair_0", "hair_1", "hair_2", "hair_3",
           "hat_sun", "backpack"]
HAIRS = {"bun": "hair_0", "short": "hair_1", "long": "hair_2", "curly": "hair_3"}
# Default colours of the roles (palette keys).
DEFAULTS = {"skin": "skin_2", "top": "shirt_blue", "bottom": "pants_navy", "shoes": "shoes",
            "hair": "hair_black", "eye": "eye", "mouth": "skin_4", "belt": "charcoal",
            "straw": "straw", "hat_band": "wood_dark", "backpack": "blue"}

VARIANTS = {
    "a": {"skin": "skin_2", "hair": "hair_black", "style": "short", "top": "shirt_blue", "bottom": "pants_navy",
          "accessories": ["backpack"]},
    "b": {"skin": "skin_3", "hair": "hair_brown", "style": "curly", "top": "shirt_green", "bottom": "pants_denim",
          "accessories": []},
    "c": {"skin": "skin_1", "hair": "hair_ginger", "style": "long", "top": "orange", "bottom": "pants_navy",
          "accessories": []},
    "d": {"skin": "skin_4", "hair": "hair_black", "style": "bun", "top": "shirt_white", "bottom": "pants_khaki",
          "accessories": [], "mouth": "skin_2"},
    "e": {"skin": "skin_2", "hair": "hair_brown", "style": "short", "top": "shirt_blue", "bottom": "pants_khaki",
          "accessories": ["hat_sun"]},
    "f": {"skin": "skin_3", "hair": "hair_black", "style": "curly", "top": "orange", "bottom": "pants_denim",
          "accessories": ["backpack"], "backpack": "orange"},
}

# The left side's limbs in cells (x0, y0, z0, x1, y1, z1); the right
# mirrors x. Joints: shoulder 1.35, elbow 1.10, wrist 0.85, hip 0.80,
# knee 0.50, ankle 0.10 m.
_LIMBS = {
    "upper_arm": (-7, 22, -2, -4, 27, 2),
    "forearm": (-7, 17, -2, -4, 22, 2),
    "hand": (-7, 14, -2, -4, 17, 2),
    "thigh": (-4, 10, -2, 0, 16, 2),
    "shin": (-4, 2, -2, 0, 10, 2),
    "foot": (-4, 0, -4, 0, 2, 2),
}


def _box(g, box, key):
    x0, y0, z0, x1, y1, z1 = box
    g.box(x0, y0, z0, x1, y1, z1, key)


def _head(out):
    """A 0.4 x 0.35 x 0.4 m head from 1.40 m: skin with two tall dark eyes
    and a mouth on the front (-z), and four hair styles, each its own
    object, wrapped one voxel round it, and a straw sun hat."""
    _box(out["skin"], (-4, 28, -4, 4, 35, 4), "skin")
    face = [(-3, 31, "eye"), (-3, 32, "eye"), (2, 31, "eye"), (2, 32, "eye"), (-1, 29, "mouth"), (0, 29, "mouth")]
    for x, y, key in face:
        out["skin"].erase(x, y, -4)
        out["details"].put(x, y, -4, key)
    for style, name in HAIRS.items():
        g = out[name]
        back_from = 28 if style in ("long", "bun") else 30
        side_from = 28 if style == "long" else 32
        for x in range(-5, 5):
            for z in range(-5, 5):
                ragged = style == "curly" and (x in (-5, 4) or z == 4) and unit("curl", x, z) < 0.3
                if z >= -4 and not ragged:
                    g.put(x, 35, z, "hair")
                for y in range(28, 35):
                    if z == 4 and y >= back_from:
                        g.put(x, y, z, "hair")
                    elif x in (-5, 4) and z >= -3 and y >= side_from:
                        g.put(x, y, z, "hair")
                    elif z == -5 and y >= 34 and -4 <= x < 4:
                        g.put(x, y, z, "hair")
        if style == "curly":
            for x in range(-5, 5):
                for y in range(30, 35):
                    if unit("curl-back", x, y) < 0.5:
                        g.put(x, y, 5, "hair")
        if style == "long":
            g.box(-5, 23, 5, 5, 29, 6, "hair")
        if style == "bun":
            g.box(-2, 31, 5, 2, 35, 8, "hair")
    hat = out["hat_sun"]
    for x in range(-7, 7):
        for z in range(-7, 7):
            hat.put(x, 36, z, "straw")
    hat.box(-4, 37, -4, 4, 38, 4, "hat_band")
    hat.box(-4, 38, -4, 4, 39, 4, "straw")


def parts():
    """{bone: {object name: Grid}}: every bone's voxels by object, in the
    character's own space (5 cm cells from the origin on the floor)."""
    out = {bone: {name: Grid(HUMAN_VOXEL) for name in OBJECTS} for bone in BONES}
    _box(out["hips"]["bottom"], (-4, 16, -2, 4, 18, 2), "bottom")
    _box(out["hips"]["details"], (-4, 18, -2, 4, 19, 2), "belt")
    _box(out["spine"]["top"], (-4, 19, -2, 4, 23, 2), "top")
    _box(out["chest"]["top"], (-4, 23, -2, 4, 27, 2), "top")
    _box(out["chest"]["backpack"], (-3, 19, 2, 3, 26, 4), "backpack")
    for x in (-3, 2):
        _box(out["chest"]["backpack"], (x, 25, -3, x + 1, 26, -2), "backpack")
    _box(out["neck"]["skin"], (-1, 27, -1, 1, 28, 1), "skin")
    _head(out["head"])
    for side, sign in (("l", 1), ("r", -1)):
        for limb, (x0, y0, z0, x1, y1, z1) in _LIMBS.items():
            if sign < 0:
                x0, x1 = -x1, -x0
            grids = out[f"{limb}_{side}"]
            if limb == "upper_arm":
                _box(grids["top"], (x0, y0, z0, x1, y1, z1), "top")
            elif limb == "forearm":
                _box(grids["skin"], (x0, y0, z0, x1, y1 - 1, z1), "skin")
                _box(grids["top"], (x0, y1 - 1, z0, x1, y1, z1), "top")
            elif limb == "hand":
                _box(grids["skin"], (x0, y0, z0, x1, y1, z1), "skin")
            elif limb in ("thigh", "shin"):
                _box(grids["bottom"], (x0, y0, z0, x1, y1, z1), "bottom")
            else:
                _box(grids["shoes"], (x0, y0, z0, x1, y1, z1), "shoes")
    return out


def colours(variant):
    """Role -> palette key for a variant (the defaults, overridden)."""
    v = VARIANTS[variant]
    return {role: v.get(role, key) for role, key in DEFAULTS.items()}


def static(variant):
    """The parts in the rest pose, one node per object, only the variant's
    hair and accessories, keys renamed to palette colours (review renders
    and tests only; the pack gets the skinned human.glb)."""
    v = VARIANTS[variant]
    keep = {"skin", "top", "bottom", "shoes", "details", HAIRS[v["style"]], *v["accessories"]}
    cols = colours(variant)
    every = parts()
    a = Asset(f"human_{variant}")
    for name in OBJECTS:
        if name not in keep:
            continue
        g = Grid(HUMAN_VOXEL)
        for bone in BONES:
            for (x, y, z), key in every[bone][name].cells.items():
                g.put(x, y, z, cols[key])
        a.part(name, g)
    return a
