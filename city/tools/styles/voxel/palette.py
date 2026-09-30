"""The voxel kit's colours, after the 02-voxel sheets.

Keys shared with the pack's style.json `palette` keep exactly its values
(test_assets checks this), so the generated kit and anything the pack still
draws itself agree. Each key may also appear as a light (`key+`) or dark
(`key-`) shade; voxel.py derives those.
"""

PALETTE = {
    # Shared with style.json.
    "yellow": "#F2C230",
    "yellow_dark": "#D39B1C",
    "yellow_roof": "#F7D04A",
    "glass": "#4F86C6",
    "stone": "#A9A8A0",
    "white": "#F4F1EA",
    "cream": "#EDE2C8",
    "orange": "#EE8424",
    "orange_light": "#F59E45",
    "lawn": "#5AA844",
    "lawn_dark": "#4E9A3A",
    "water": "#2F7FD8",
    "water_light": "#5C9FEA",
    "asphalt": "#6C6E73",
    "kerb": "#CFCFC8",
    "rail": "#56585D",
    "blue": "#3F6FB5",
    "leaf": "#4CAF3C",
    "leaf_dark": "#2E8A2E",
    # Foliage and ground.
    "leaf_light": "#86CF45",
    "trunk": "#7A4A2A",
    "trunk_dark": "#5B351D",
    "soil": "#6B4A32",
    "paving": "#D3CFC6",
    "paving_light": "#DFDBD2",
    "paving_dark": "#BDB8AE",
    "stone_dark": "#8A8983",
    "flower_white": "#F7F6EE",
    "flower_pink": "#EE86AE",
    "flower_yellow": "#FFD447",
    # Building trim and glass.
    "glass_dark": "#2E568F",
    "glass_light": "#8DB8E6",
    "glass_grey": "#8395A8",
    "steel": "#8E969E",
    "charcoal": "#3A3E44",
    "navy": "#1F2F5C",
    "orange_dark": "#C9621A",
    "lamp_glow": "#FFE3A0",
    "window_glow": "#FFD68A",
    # Wood and furniture.
    "wood": "#B8763A",
    "wood_light": "#D59A58",
    "wood_dark": "#87522A",
    "book_red": "#C0443A",
    "book_green": "#3E8E4E",
    # People.
    "skin_1": "#F2C9A5",
    "skin_2": "#D9A077",
    "skin_3": "#A86B45",
    "skin_4": "#6B4128",
    "hair_black": "#2A211C",
    "hair_brown": "#5B3A22",
    "hair_ginger": "#B8582A",
    "shirt_blue": "#2F63C8",
    "shirt_green": "#3E9A45",
    "shirt_white": "#EDEDE8",
    "pants_navy": "#26335C",
    "pants_denim": "#3E5E9A",
    "pants_khaki": "#B59A6A",
    "shoes": "#2A2A2E",
    "eye": "#1B1B22",
    "straw": "#E3C27A",
}

# Material properties by base key; everything else is matte (roughness 0.85).
PROPS = {
    "glass": {"roughness": 0.18, "metallic": 0.1},
    "glass_dark": {"roughness": 0.18, "metallic": 0.1},
    "glass_light": {"roughness": 0.18, "metallic": 0.1},
    "glass_grey": {"roughness": 0.22, "metallic": 0.1},
    "water": {"roughness": 0.25},
    "water_light": {"roughness": 0.25},
    "steel": {"roughness": 0.45, "metallic": 0.4},
    "rail": {"roughness": 0.4, "metallic": 0.5},
    "charcoal": {"roughness": 0.6},
    "lamp_glow": {"roughness": 0.4, "emissive": 1.0},
    "window_glow": {"roughness": 0.4, "emissive": 0.8},
}
