"""Pixel characters: the shared rig (city/tools/styles/lowpoly/characters.py)
posed and pre-rendered in eight directions through the pixel pipeline.

Each sheet is one render: the character's parts are built on the rig with
pixel-pack materials (palette.MATERIALS), posed through its actions, and a
static copy of every pose is laid out on a grid far enough apart that no
two overlap on screen; post.py cuts each copy by its world cells into a
fixed 32 x 40 frame and pastes it into the sheet.

Sheets (assets/characters/<name>.png): one row per direction, one column
per frame, 32 x 40 px per frame. The occupant's ground point is at FEET
(16, 34) in standing frames (walk, idle) and at SEAT (16, 32) in seated
frames (sit, typing), whose knees reach further down the screen.

    rows     facing 0 (north), 45, 90 (east), ... 315, clockwise seen from
             above, as the pack's facing (atan2(dir.x, -dir.y))
    columns  walk x6 (0-5), sit (6), idle x2 (7-8), typing x2 (9-10)

A human is 32 px tall to the top of its head and hair (the rig scaled by
SCALE, for the tallest hair); robots use the same scale and stand a little
shorter.
"""
import math

import models

DIRECTIONS = (0, 45, 90, 135, 180, 225, 270, 315)
# (action, frame at 24 fps): walk over its 1 s cycle; sit; idle at rest and
# mid-breath; typing with each hand down.
FRAMES = [("walk", k * 4) for k in range(6)] + [("sit", 0)] + [("idle", 0), ("idle", 18)] + \
    [("typing", 3), ("typing", 15)]
COLUMNS = {"walk": (0, 6), "sit": (6, 1), "idle": (7, 2), "typing": (9, 2)}
CELL = (32, 40)
FEET = (16, 34)
SEAT = (16, 32)
HEAD_TOP_M = 1.82  # the top of the tallest hair (the bun)
SCALE = 32.0 / (HEAD_TOP_M * 16.0)

SKINS = ["skin_1", "skin_2", "skin_3", "skin_4"]
HAIRS = ["hair_brown", "hair_black", "hair_auburn", "hair_blond"]
# Tops in the same order as every style's outfits (teal, red, yellow, green,
# brown, blue, purple, white), so a person keeps their look when the style
# changes; palette.OUTFITS names each one's base colour.
TOPS = ["cloth_teal", "cloth_red", "cloth_yellow", "cloth_green", "cloth_brown", "cloth_blue", "cloth_purple",
        "cloth_white"]
BOTTOMS = ["cloth_navy", "cloth_denim", "cloth_khaki", "cloth_navy"]


def human(k, hair=None):
    """Outfit k with hair style `hair` (k % 4 when not given). The look's
    other parts follow k, as in every style: skin k % 4, hair colour
    (k + 1) % 4, trousers (k + k // 4) % 4, a backpack with outfits 1, 5, 6."""
    return {"kind": "human", "hair": k % 4 if hair is None else hair, "pack": k in (1, 5, 6), "hat": False,
            "roles": {"skin": SKINS[k % 4], "top": TOPS[k], "bottom": BOTTOMS[(k + k // 4) % 4], "shoes": "shoe",
                      "hair": HAIRS[(k + 1) % 4], "eye": "c_eye", "brow": HAIRS[(k + 1) % 4], "belt": "c_belt",
                      "straw": "c_straw", "hat_band": "c_band", "backpack": "c_pack"}}


def robot(panel):
    return {"kind": "robot", "roles": {"shell": "r_shell", "panel": panel, "joint": "r_joint", "face": "r_face",
                                       "eyes": "r_eyes", "badge": "r_badge"}}


# A sheet per outfit and hair style, so the look's hair reads in pixel art.
VARIANTS = {f"human_{k}_{h}": human(k, h) for k in range(8) for h in range(4)}
VARIANTS["human_muted"] = dict(human(1), pack=False, roles=dict(human(1)["roles"], top="cloth_stone",
                                                                  bottom="cloth_grey", hair="hair_grey",
                                                                  brow="hair_grey"))
VARIANTS["robot_guild"] = robot("r_panel_guild")
VARIANTS["robot_city"] = robot("r_panel_city")
VARIANTS["robot_personal"] = robot("r_panel_personal")


def slot(col, row):
    """Where the copy for (col, row) stands, in Godot metres: columns 96 px
    and rows 56 px apart on screen, and at least 3 m apart in x or z from
    every other copy, so each owns the cells around it."""
    return 3.0 * col + 3.5 * row, -3.0 * col + 3.5 * row


def outputs(name):
    outs = []
    for row, _ in enumerate(DIRECTIONS):
        for col, (action, _) in enumerate(FRAMES):
            x, z = slot(col, row)
            cells = {"x": [math.floor(x) - 1, math.floor(x) + 1], "z": [math.floor(z) - 1, math.floor(z) + 1]}
            at = SEAT if action in ("sit", "typing") else FEET
            o = models.out(f"characters/{name}.png", cells, (x, z, 0), (-at[0], -at[1], CELL[0], CELL[1]))
            o["sheet"] = [col, row]
            outs.append(o)
    return outs


def figure(variant):
    def build():
        import bpy
        from mathutils import Matrix
        import characters as ch
        mats = {}
        for role, key in variant["roles"].items():
            mats[role] = bpy.data.materials.get(key) or bpy.data.materials.new(key)
        arm = ch.build_rig(variant["kind"])
        objs = (ch.build_human if variant["kind"] == "human" else ch.build_robot)(arm, mats)
        drop = []
        if variant["kind"] == "human":
            drop = [f"hair_{h}" for h in range(4) if h != variant["hair"]]
            if not variant.get("pack"):
                drop.append("backpack")
            if not variant.get("hat"):
                drop.append("hat_sun")
        for name in drop:
            bpy.data.objects.remove(objs.pop(name))
        acts = ch.add_actions(arm, variant["kind"])
        ad = arm.animation_data
        for track in ad.nla_tracks:
            track.mute = True
        scene = bpy.context.scene
        for row, facing in enumerate(DIRECTIONS):
            for col, (action, frame) in enumerate(FRAMES):
                ad.action = acts[action]
                if getattr(acts[action], "slots", None):
                    ad.action_slot = acts[action].slots[0]
                scene.frame_set(frame)
                dg = bpy.context.evaluated_depsgraph_get()
                x, z = slot(col, row)
                place = Matrix.Translation((x, -z, 0.0)) @ Matrix.Rotation(math.radians(-facing), 4, "Z") @ \
                    Matrix.Scale(SCALE, 4)
                for o in objs.values():
                    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
                    copy = bpy.data.objects.new(f"{o.name}_{row}_{col}", me)
                    copy.matrix_world = place
                    scene.collection.objects.link(copy)
        for o in list(objs.values()) + [arm]:
            bpy.data.objects.remove(o)
    return build


def add_figures():
    for name, variant in VARIANTS.items():
        models.add(f"figure_{name}", figure(variant), outputs(name),
                   info={"sheet": {"cell": list(CELL), "feet": list(FEET), "seat": list(SEAT),
                                   "directions": list(DIRECTIONS),
                                   "columns": {k: list(v) for k, v in COLUMNS.items()}}})
