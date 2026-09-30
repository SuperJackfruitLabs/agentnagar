"""The neon noir kit's palette (sRGB), after the 10 Neon noir sheets:
dark slate, charcoal and navy architecture, dark glass, warm amber windows
and lamps, cyan, amber and magenta neon, wet stone paving, deep greens and
a deep blue river, and the cream-and-red tram.

The pack renders these lit (no toon) and night-first: `neon_*` colours are
emissive tubes the pack switches on at dusk; by day they read as dark
glass. Keys shared with the anime palette mean the same parts, so
generator code can move between kits."""

PALETTE = {
    # Architecture.
    "warm_white": "#C9CCD3",
    "cream": "#B8B4AA",
    "slate": "#2C3545",
    "slate_light": "#3D4859",
    "slate_dark": "#1D2431",
    "charcoal": "#24272E",
    "navy": "#1B2742",
    "brick": "#3A3F4A",
    "brick_light": "#4A505C",
    "brick_dark": "#262A33",
    "mortar": "#555B66",
    "stone": "#6E7280",
    "stone_dark": "#4D5260",
    "concrete": "#5C616C",
    "steel": "#8D95A3",
    "steel_light": "#B5BCC8",
    "steel_dark": "#454B57",
    "frame": "#15171C",
    "terracotta": "#5B4A4A",
    "terracotta_dark": "#433737",
    "render_peach": "#5E5A63",
    "render_sky": "#48546A",
    "render_mint": "#4A5A5A",
    # Glass and light.
    "glass": "#18263D",
    "glass_light": "#5F82AD",
    "glass_tower": "#22385A",
    "window_glow": "#FFB560",
    "lamp_glow": "#FFC470",
    "neon_magenta": "#FF3DB8",
    "neon_cyan": "#3FE3FF",
    "neon_amber": "#FFB23C",
    "neon_violet": "#9B5CFF",
    "screen_glow": "#8FD0FF",
    # Ground and water.
    "paving": "#5A606B",
    "paving_light": "#6B717D",
    "paving_dark": "#454A55",
    "asphalt": "#2B2F37",
    "asphalt_dark": "#22252C",
    "kerb": "#767B86",
    "road_line": "#C9CCD2",
    "grass": "#2E5534",
    "grass_dark": "#244529",
    "soil": "#3E3027",
    "water": "#173F73",
    "water_light": "#2F6FAE",
    "water_deep": "#0F2C55",
    "sparkle": "#FFE2A8",
    # Plants.
    "leaf_dark": "#18402A",
    "leaf": "#265E36",
    "leaf_light": "#3D7E45",
    "leaf_sun": "#5B9650",
    "trunk": "#3F2F26",
    "trunk_light": "#574134",
    "palm": "#23583A",
    "palm_light": "#3A7A48",
    "flower_white": "#E8E6EE",
    "flower_pink": "#E35C9F",
    "flower_yellow": "#F2B84A",
    "flower_violet": "#8C62C9",
    # Transit.
    "tram_cream": "#E8E4DC",
    "tram_coral": "#CC3129",
    "tram_dark": "#1F2228",
    # Wood and metal.
    "wood": "#6A4B36",
    "wood_light": "#8C6849",
    "wood_dark": "#46301F",
    "iron": "#1E2026",
    "brass": "#B08A48",
    # Accents.
    "indigo": "#3A3F8F",
    "vermilion": "#D8453A",
    "blue": "#2F64C9",
    "yellow": "#F2B84A",
    "canvas": "#3A3F4C",
    "canvas_stripe": "#CC3129",
    # People and agents (painted by the pack; kit defaults).
    "skin": "#D9A887",
    "cloth": "#3A4050",
    "hair": "#1E1C22",
    "shell": "#14161B",
    "plate": "#E9EAEE",
    "trim": "#2A2D35",
    "joint": "#0E0F12",
    "visor": "#050608",
    "hoodie": "#23252D",
    "hoodie_lining": "#30333C",
    "badge": "#2F9C6A",
    "umbrella": "#1E2230",
    "card": "#F2F2F5",
    "book_a": "#6A2E3C",
    "book_b": "#2F4A6C",
    "book_c": "#A98A3A",
    "book_d": "#3D6A48",
}

# Glowing colours and their strength at night (the pack switches neon off
# by day and scales windows and lamps with the light).
EMISSIVE = {"lamp_glow": 3.2, "window_glow": 1.6, "screen_glow": 1.4, "neon_magenta": 5.0, "neon_cyan": 5.0,
            "neon_amber": 4.0, "neon_violet": 4.5}
ROUGHNESS = {
    "glass": 0.05, "glass_light": 0.07, "glass_tower": 0.05, "water": 0.04, "water_light": 0.06,
    "water_deep": 0.04, "slate": 0.55, "slate_light": 0.55, "slate_dark": 0.6, "charcoal": 0.6,
    "steel": 0.3, "steel_light": 0.3, "steel_dark": 0.35, "brass": 0.3, "shell": 0.12, "plate": 0.22,
    "visor": 0.04, "paving": 0.45, "paving_light": 0.45, "paving_dark": 0.5, "asphalt": 0.5,
    "neon_magenta": 0.2, "neon_cyan": 0.2, "neon_amber": 0.2, "neon_violet": 0.2,
}
METALLIC = {"steel": 0.65, "steel_light": 0.65, "steel_dark": 0.65, "brass": 0.85, "trim": 0.5}
