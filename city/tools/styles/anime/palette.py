"""The anime kit's palette (sRGB), after the 06 Cel-shaded anime sheets:
warm whites, bright red-orange brick, silver steel, clear blue glass and
water, fresh greens, cream and coral for the tram, and indigo and
vermilion accents. The pack shades every colour toon at runtime, so these
are the lit tones; shadows come from the pack's indigo ambient."""

PALETTE = {
    # Architecture.
    "warm_white": "#F6F1E7",
    "cream": "#EFE4CF",
    "brick": "#C9573A",
    "brick_light": "#DB6E4E",
    "brick_dark": "#9C3F2A",
    "mortar": "#E8D3C4",
    "stone": "#D9D3C7",
    "stone_dark": "#ADA598",
    "concrete": "#DDDEE2",
    "steel": "#A7AFBB",
    "steel_light": "#D9DEE6",
    "steel_dark": "#6E7682",
    "frame": "#2B2C35",
    "terracotta": "#D2714A",
    "terracotta_dark": "#A9522F",
    "render_peach": "#F2D2B6",
    "render_sky": "#CFE0EC",
    "render_mint": "#D6EAD8",
    # Glass and light.
    "glass": "#3F79A2",
    "glass_light": "#9DCDEB",
    "glass_tower": "#7FB3DA",
    "window_glow": "#FFD28E",
    "lamp_glow": "#FFE3A6",
    # Ground and water.
    "paving": "#EADFCC",
    "paving_light": "#F3EBDC",
    "paving_dark": "#D3C4AA",
    "asphalt": "#7B7E89",
    "asphalt_dark": "#62656F",
    "kerb": "#E4DFD4",
    "road_line": "#F8F5EE",
    "grass": "#7FBC52",
    "grass_dark": "#66A444",
    "soil": "#7A5638",
    "water": "#2F80CB",
    "water_light": "#71B8EF",
    "water_deep": "#1F5E9E",
    "sparkle": "#EAF7FF",
    # Plants.
    "leaf_dark": "#3B7B3B",
    "leaf": "#5C9F40",
    "leaf_light": "#8DC555",
    "leaf_sun": "#BCDC6E",
    "trunk": "#6F4A33",
    "trunk_light": "#8E6346",
    "palm": "#4E9A48",
    "palm_light": "#7FC05A",
    "flower_white": "#FBF8F0",
    "flower_pink": "#F29BB5",
    "flower_yellow": "#FFD54F",
    # Transit.
    "tram_cream": "#F4ECDB",
    "tram_coral": "#E3614B",
    "tram_dark": "#353743",
    # Wood and metal.
    "wood": "#A06F48",
    "wood_light": "#CDA06F",
    "wood_dark": "#6C4731",
    "iron": "#33343D",
    "brass": "#C9A254",
    # Accents.
    "indigo": "#3E428F",
    "vermilion": "#E4513B",
    "blue": "#2F64C9",
    "yellow": "#F4C24A",
    "canvas": "#F7F2E8",
    "canvas_stripe": "#E4513B",
    # People (painted by the pack; kit defaults).
    "skin": "#F1C9A8",
    "cloth": "#8FA2B8",
    "hair": "#2B2E52",
    "book_a": "#8A3E4C",
    "book_b": "#3F5F8C",
    "book_c": "#D9B44A",
    "book_d": "#4D8A5A",
}

# Glowing colours and their emission strength (the pack scales it at night).
EMISSIVE = {"lamp_glow": 3.0, "window_glow": 1.5}
ROUGHNESS = {"glass": 0.1, "glass_light": 0.12, "glass_tower": 0.1, "water": 0.08, "water_light": 0.1,
             "steel": 0.35, "steel_light": 0.35, "steel_dark": 0.4, "brass": 0.35}
METALLIC = {"steel": 0.55, "steel_light": 0.55, "steel_dark": 0.55, "brass": 0.6}
