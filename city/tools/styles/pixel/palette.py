"""The 08 pixel-art palette: 32 fixed colours, drawn by eye from the pixel-art
concept sheets, and their night twins. Lamps keep their colour at night and
windows light up; everything else darkens toward night blue."""

NAMES = [
    "outline", "dark", "brick_dark", "brick", "brick_light", "sand", "sand_light",
    "stone", "stone_light", "wood_dark", "wood", "leaf_dark", "leaf", "leaf_light",
    "water_dark", "water", "water_light", "window", "night_blue", "night_blue2",
    "lamp", "lamp_light", "skin1", "skin2", "skin3", "skin4", "red", "teal",
    "yellow", "purple", "white", "grey",
]

DAY = [
    (24, 28, 48), (46, 43, 42), (122, 48, 40), (168, 72, 52), (200, 110, 80),
    (222, 196, 150), (240, 224, 190), (170, 160, 150), (205, 198, 188),
    (92, 58, 40), (138, 90, 59), (40, 92, 52), (62, 140, 62), (120, 190, 80),
    (30, 70, 120), (50, 110, 170), (120, 180, 220), (160, 200, 225),
    (28, 34, 70), (48, 58, 110), (255, 210, 110), (255, 240, 190),
    (240, 200, 160), (200, 140, 100), (140, 90, 60), (90, 60, 40),
    (200, 60, 60), (40, 140, 140), (242, 182, 50), (130, 90, 190),
    (244, 241, 234), (120, 120, 130),
]

C = dict(zip(NAMES, DAY))


def _night(name, rgb):
    if name in ("lamp", "lamp_light"):
        return rgb
    if name == "window":
        return C["lamp"]
    if name in ("outline", "night_blue", "night_blue2"):
        return rgb
    r, g, b = rgb
    return (min(255, int(r * 0.33) + 16), min(255, int(g * 0.36) + 20), min(255, int(b * 0.46) + 44))


NIGHT_MAP = {rgb: _night(name, rgb) for name, rgb in zip(NAMES, DAY)}
NIGHT = sorted(set(NIGHT_MAP.values()))
# The base colour of each human sheet's top (figures.TOPS), in the order
# every style uses for outfits.
OUTFITS = ["teal", "red", "yellow", "leaf", "wood", "water", "purple", "white"]


# ---- Materials for the pre-rendered kit (models.py -> render.py -> post.py) ----
#
# Every face of a Blender model carries one of these keys. post.py lights the
# material's albedo (the middle of its ramp unless `base` says otherwise) and
# snaps each pixel to the nearest ramp colour in Lab, so a material can only
# ever produce the palette colours listed in its ramp (dark to light).
#
#   ramp     palette names, dark to light
#   base     the albedo's palette name (default: the ramp's middle)
#   flat     unlit: always the base colour (lamp glass, paint)
#   smooth   Gouraud normals (foliage, domes) instead of faceted ones
#   dither   ordered-dither strength between ramp steps (0 = none)
#   noise    per-voxel lightness noise in L* (leafy or grainy texture)
#   var      L* spread of the per-face variation value (pavers, clumps)
#   pattern  a post.py pattern name (courses, seams, mullions, ...)
#   frame    colour for this material's pixels that border another one
#   line     colour of the inner line where it stands in front of
#            something farther away (default: outline)
#   line_step  the depth step in metres that draws that line (default 0.35)
#   light    (ambient, diffuse) override
def _m(ramp, **kw):
    return dict(ramp=ramp, **kw)


MATERIALS = {
    # Brick workshop.
    "brick": _m(["brick_dark", "brick", "brick_light"], pattern="brick"),
    "brick_trim": _m(["brick", "brick_light", "sand"], base="brick_light"),
    "plinth": _m(["grey", "stone", "stone_light"], pattern="ashlar"),
    # Sandstone library and houses.
    "sandstone": _m(["stone", "sand", "sand_light"], base="sand", pattern="ashlar"),
    "sand_trim": _m(["sand", "sand_light", "white"], base="sand_light"),
    "render_warm": _m(["brick_light", "skin2", "skin1"], base="skin2", pattern="render"),
    "render_sand": _m(["stone", "sand", "sand_light"], base="sand", pattern="render"),
    "white_frame": _m(["stone", "stone_light", "white"], base="white"),
    "stone": _m(["grey", "stone", "stone_light"], pattern="ashlar"),
    "stone_light": _m(["stone", "stone_light", "white"], base="stone_light"),
    "concrete": _m(["grey", "stone", "stone_light"], base="stone"),
    # Roofs.
    "roof_navy": _m(["night_blue", "night_blue2", "water_dark"], base="night_blue2", pattern="seams"),
    "roof_flat": _m(["grey", "stone", "stone_light"], base="stone", pattern="roof_tiles"),
    "roof_red": _m(["brick_dark", "brick", "red"], base="brick", pattern="roof_tiles"),
    "dome": _m(["night_blue", "night_blue2", "water_dark", "water"], base="night_blue2", smooth=True,
               pattern="dome_grid"),
    "fascia": _m(["outline", "night_blue", "night_blue2"], base="night_blue"),
    # Glass.
    "glass_warm": _m(["yellow", "lamp", "lamp_light"], base="lamp", flat=True, pattern="mullions",
                     frame="outline"),
    "glass_sky": _m(["water", "water_light", "window"], base="window", pattern="panes",
                    frame="outline"),
    "glass_tower": _m(["water_dark", "water", "water_light", "window"], base="water",
                      pattern="tower_panes"),
    "glass_dark": _m(["night_blue", "night_blue2", "water_dark", "window"], base="night_blue2",
                     pattern="tram_panes", frame="outline"),
    "frame": _m(["outline", "dark", "grey"], base="dark"),
    # Wood, metal, paint.
    "wood": _m(["wood_dark", "wood", "sand"], base="wood", pattern="planks"),
    "wood_dark": _m(["outline", "wood_dark", "wood"], base="wood_dark"),
    "metal": _m(["outline", "dark", "grey"], base="dark"),
    "metal_light": _m(["grey", "stone", "stone_light"], base="stone"),
    "lamp": _m(["lamp", "lamp_light"], base="lamp_light", flat=True),
    "paint_white": _m(["white"], flat=True),
    "paint_yellow": _m(["yellow"], flat=True),
    "sign": _m(["outline", "night_blue", "night_blue2"], base="night_blue", pattern="sign"),
    "banner": _m(["water_dark", "water", "water_light"], base="water"),
    "emblem": _m(["white"], flat=True),
    "awning": _m(["yellow", "white"], pattern="stripes", light=(0.8, 0.3)),
    "canvas_red": _m(["brick", "red", "brick_light"], base="red"),
    "tram_cream": _m(["sand", "sand_light", "white"], base="sand_light"),
    "tram_red": _m(["brick_dark", "red", "brick_light"], base="red"),
    "tram_roof": _m(["outline", "dark", "grey"], base="dark"),
    "rubber": _m(["outline", "dark"], base="dark"),
    # Plants.
    "leaf": _m(["leaf_dark", "leaf", "leaf_light"], base="leaf", smooth=True, dither=0.35, noise=5, var=44,
               line="leaf_dark", line_step=0.12, light=(0.2, 1.3)),
    "leaf_dark": _m(["outline", "leaf_dark", "leaf"], base="leaf_dark", smooth=True, dither=0.3, noise=4,
                    line="leaf_dark", light=(0.35, 0.6)),
    "palm": _m(["leaf_dark", "leaf", "leaf_light"], base="leaf", dither=0.6, noise=8, line="leaf_dark"),
    "shrub": _m(["leaf_dark", "leaf", "leaf_light"], base="leaf", smooth=True, dither=1.0, noise=18, var=8,
                line="leaf_dark"),
    "flowers": _m(["leaf_dark", "leaf", "leaf_light"], base="leaf", smooth=True, dither=0.8, noise=12,
                  pattern="flowers", line="leaf_dark"),
    "trunk": _m(["outline", "wood_dark", "wood"], base="wood_dark", pattern="bark"),
    "palm_trunk": _m(["wood_dark", "wood", "sand"], base="wood", pattern="rings"),
    "grass": _m(["leaf", "leaf_light"], base="leaf_light", dither=0.7, noise=12, pattern="grass"),
    "soil": _m(["wood_dark", "wood"], base="wood_dark", noise=10),
    "terracotta": _m(["brick_dark", "brick", "brick_light"], base="brick_light"),
    # Ground.
    "paving": _m(["stone_light", "sand", "sand_light"], base="sand_light", pattern="pavers",
                 light=(1.0, 0.0)),
    "path": _m(["stone", "sand", "sand_light"], base="sand", noise=10, dither=0.5, light=(1.0, 0.0)),
    "asphalt": _m(["dark", "grey", "stone"], base="grey", noise=6, dither=0.3, light=(1.0, 0.0)),
    "kerb": _m(["stone", "stone_light", "white"], base="stone_light", pattern="kerb", light=(1.0, 0.0)),
    "sleeper": _m(["wood_dark", "wood"], base="wood_dark", light=(1.0, 0.0)),
    "rail": _m(["grey", "stone_light", "white"], base="stone_light"),
    "gravel": _m(["grey", "stone"], base="stone", noise=14, dither=0.6, light=(1.0, 0.0)),
    "floorboards": _m(["wood_dark", "wood", "sand"], base="wood", pattern="boards", light=(1.0, 0.0)),
    "floor_stone": _m(["stone", "stone_light", "white"], base="stone_light", pattern="pavers", light=(1.0, 0.0)),
    "carpet": _m(["brick_dark", "brick", "brick_light"], base="brick", pattern="carpet", light=(1.0, 0.0)),
    # People and robots (figures.py), smooth-shaded so small figures read
    # as clean bands, not facets.
    "skin_1": _m(["skin2", "skin1"], base="skin1", smooth=True),
    "skin_2": _m(["skin3", "skin2", "skin1"], base="skin2", smooth=True),
    "skin_3": _m(["skin4", "skin3", "skin2"], base="skin3", smooth=True),
    "skin_4": _m(["wood_dark", "skin4", "skin3"], base="skin4", smooth=True),
    "cloth_red": _m(["brick_dark", "red", "brick_light"], base="red", smooth=True),
    "cloth_teal": _m(["water_dark", "teal", "water_light"], base="teal", smooth=True),
    "cloth_yellow": _m(["brick_light", "yellow", "lamp"], base="yellow", smooth=True),
    "cloth_purple": _m(["night_blue2", "purple"], base="purple", smooth=True),
    "cloth_blue": _m(["water_dark", "water", "water_light"], base="water", smooth=True),
    "cloth_green": _m(["leaf_dark", "leaf", "leaf_light"], base="leaf", smooth=True),
    "cloth_coral": _m(["brick", "brick_light", "sand"], base="brick_light", smooth=True),
    "cloth_grey": _m(["dark", "grey", "stone"], base="grey", smooth=True),
    "cloth_brown": _m(["wood_dark", "wood", "brick_light"], base="wood", smooth=True),
    "cloth_white": _m(["stone", "stone_light", "white"], base="white", smooth=True),
    "cloth_stone": _m(["grey", "stone", "stone_light"], base="stone", smooth=True),
    "cloth_navy": _m(["outline", "night_blue", "night_blue2"], base="night_blue2", smooth=True),
    "cloth_denim": _m(["night_blue2", "water_dark", "water"], base="water_dark", smooth=True),
    "cloth_khaki": _m(["wood", "sand", "sand_light"], base="sand", smooth=True),
    "shoe": _m(["outline", "dark"], base="dark", smooth=True),
    "hair_black": _m(["outline", "dark"], base="dark", smooth=True),
    "hair_brown": _m(["outline", "wood_dark", "wood"], base="wood_dark", smooth=True),
    "hair_auburn": _m(["brick_dark", "brick", "brick_light"], base="brick", smooth=True),
    "hair_blond": _m(["wood", "sand", "sand_light"], base="sand", smooth=True),
    "hair_grey": _m(["grey", "stone", "stone_light"], base="stone_light", smooth=True),
    "c_eye": _m(["outline"], flat=True),
    "c_belt": _m(["outline", "dark"], base="dark"),
    "c_straw": _m(["wood", "sand", "sand_light"], base="sand", smooth=True),
    "c_band": _m(["wood_dark"], flat=True),
    "c_pack": _m(["leaf_dark", "leaf"], base="leaf_dark", smooth=True),
    "r_shell": _m(["stone", "stone_light", "white"], base="white", smooth=True, light=(0.7, 0.45)),
    "r_panel_guild": _m(["brick_light", "yellow", "lamp"], base="yellow", smooth=True),
    "r_panel_city": _m(["water_dark", "teal", "water_light"], base="teal", smooth=True),
    "r_panel_personal": _m(["night_blue2", "purple"], base="purple", smooth=True),
    "r_joint": _m(["outline", "dark"], base="dark", smooth=True),
    "r_face": _m(["outline"], flat=True),
    "r_eyes": _m(["water_light"], flat=True),
    "r_badge": _m(["leaf_dark", "leaf"], base="leaf", smooth=True),
    "water": _m(["water_dark", "water", "water_light"], base="water", dither=0.3, noise=3, pattern="ripples",
                light=(1.0, 0.0)),
    # The things to use (things.py), added after the rest so every other
    # material keeps its index in the render passes.
    "bronze": _m(["wood_dark", "wood", "yellow"], base="wood", pattern="sign"),
    "kiosk": _m(["water_dark", "teal", "water_light"], base="teal"),
    "screen": _m(["night_blue", "night_blue2", "water_dark", "teal"], base="water_dark", pattern="sign",
                 frame="outline"),
    # A meadow's blades, lit softly so a field of them is not all shadow.
    "blade": _m(["leaf_dark", "leaf", "leaf_light"], base="leaf", noise=6, line="leaf_dark", line_step=0.3,
                light=(0.8, 0.4)),
    "blade_dark": _m(["leaf_dark", "leaf"], base="leaf_dark", noise=6, line="leaf_dark", line_step=0.3,
                     light=(0.8, 0.4)),
    "blade_light": _m(["leaf", "leaf_light"], base="leaf_light", noise=6, line="leaf_dark", line_step=0.3,
                      light=(0.8, 0.4)),
    "stem": _m(["leaf_dark", "leaf"], base="leaf_dark"),
}
# Materials whose top faces also read as ground (no outline against the
# ground plane) are drawn by tiles instead; every model sprite is outlined.
OUTLINE = "outline"
