"""How a build marks which material a face is, and how a capture reads it back.

A build that paints several kinds of face (timber and frame, say) writes each kind's code into a UV layer
(shade.py's `kind_marks`: u is the code; flat-coloured kit pieces have no UVs of their own, and no material
reads them; a piece with leaf cards keeps its texture's layer first and takes the marks as its second). asset_views.gd draws u as grey with no tone curve, and asset_bands.py reads the grey back. The
n-th kind in an asset's config takes the n-th code; a face nobody marked reads 0. (The vertex colours' alpha
would have been the obvious place, but Blender's glTF exporter writes colours without alpha unless the
material uses it.)
"""
CODE = (0.8, 0.6, 0.4, 0.2)


def srgb(v):
    return 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055


def marks_of(kinds):
    """{kind: code} for a config's list of kinds."""
    return {k: CODE[i] for i, k in enumerate(kinds)}


def level_of(kinds):
    """{kind: grey level, 0-255, as a capture shows it}."""
    return {k: round(255 * srgb(CODE[i])) for i, k in enumerate(kinds)}
