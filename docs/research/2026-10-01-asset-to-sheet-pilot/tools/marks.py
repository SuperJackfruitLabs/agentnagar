"""What a builder tells the painting about its faces, and the one call that paints a placed prop.

A builder adds its parts and calls `Marks.mark(kind, part)` after each: the faces added since the last call are
of that kind (a ramp in the asset's ramps.json: "timber", "frame", ...), belong to that part (one tone a part)
and may fall on the ramp where the settings' ranges say: tops in its lighter stops, undersides in its darkest
(`tops`, `sides`, `under`; `ranges` overrides them for a kind). `paint()` then runs shade.py with the pack's
light at the hour its sheets are drawn and marks each face's kind for a capture to read back (kinds.py).

Three things learnt on the first prop are carried here so a builder need not learn them again:
  * the kits' box() and beam() wind their faces inside out (the game shows them right because the kits'
    materials are two-sided). The painting reads normals, so `mark` turns new faces outward first;
  * a prop stands at many facings, so the sun is averaged over a full turn (`turns`) and the painted light is
    in the prop's own frame (from above, a little from the front), not the noon sun's direction;
  * a night-first style (its sheets are drawn after dark) has nothing of the day's light to take back out.
"""
import bmesh

import kinds
import shade


def settings(style, toon=False):
    """The settings every placed prop starts from; a builder adds its kinds' `weights` and `ranges` and the
    style's fitted values (params/<style>.json) on top. `style` is the pack's style.json."""
    night = bool(style.get("sheet_night"))
    return {"take_out": 0.0 if night else 0.85, "floor": 0.6, "ao_share": 0.3, "e_ref": 0.8, "gain": {}, "channel": {},
            "curve": {}, "stop_gain": {}, "painted": [0.0, 0.35, 0.94], "turns": 16, "tops": [0.45, 1.0],
            "sides": [0.1, 0.8], "under": [0.0, 0.25], "ranges": {}, "weights": {}, "minute": 1308 if night else 780,
            "diffuse": "toon:0.32" if toon else "lambert"}


def where(normal_z, kind, P):
    """Where on its ramp a face of `kind` may fall, by which way it faces."""
    r = {**P, **P["ranges"].get(kind, {})}
    return r["tops"] if normal_z > 0.5 else (r["under"] if normal_z < -0.5 else r["sides"])


class Marks:
    """The paint entries of a kit Mesh's faces, in the order the faces are added."""

    def __init__(self, m, P):
        self.m, self.P, self.entries = m, P, []

    def mark(self, kind, part, turn="out"):
        """The faces added since the last call: of `kind` (None: left to the kit's own colour), part `part`.
        `turn` says how to set their normals for the painting: "out" for closed solids (boxes, beams, balls),
        "up" for open leaves and blades whose material is two-sided (each face is turned to look up), None to
        leave them (leaf cards, which are one-sided and must keep their winding)."""
        self.m.bm.faces.ensure_lookup_table()
        new = list(self.m.bm.faces)[len(self.entries):]
        if turn == "out":
            bmesh.ops.recalc_face_normals(self.m.bm, faces=new)
        for f in new:
            f.normal_update()
            if turn == "up" and f.normal.z < 0.0:
                f.normal_flip()
                f.normal_update()
            lo, hi = where(f.normal.z, kind, self.P)
            self.entries.append((kind, part, 0.0, lo, hi, 1.0) if kind else None)


def by_colour(P, kinds, leaf_from=0.0, cell=0.3, hearts=None, tol=0.012):
    """Paint entries for a piece a kit's own builder made (built, baked, in the open scene), read off its
    baked colours: leaf cards and green faces from `leaf_from` metres up are "leaf"; a face in one of
    `kinds`' colours ({kind: [linear rgb, ...]}, the kit's palette colours for that material) is of that
    kind; every other face keeps the kit's colour. Faces share a part by where they stand (cells of `cell`
    metres), so neighbours take one tone. `hearts` (lo, hi) keeps plain green faces, the dark hearts under
    leaf cards, to that part of the ramp. Set P["fix_winding"] for such a piece: its boxes are inside out."""
    import bpy
    out = {}
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or not o.data.polygons:
            continue
        me, mw = o.data, o.matrix_world
        attr = me.color_attributes.get("Col")
        if attr is None:
            continue
        names = [m.name if m else "" for m in me.materials]
        signs = shade.winding_signs(o)
        n3 = mw.to_3x3()
        rows = []
        for p in me.polygons:
            nm = names[p.material_index] if names else ""
            c = mw @ p.center
            r, g, b = attr.data[p.loop_start].color[:3]
            nz = (n3 @ p.normal).normalized().z * signs[p.index]
            group = (round(c.x / cell), round(c.y / cell), round(c.z / cell))
            entry = None
            if nm == shade.CARDS:
                if c.z >= leaf_from:
                    entry = ("leaf", group, 0.0, 0.0, 1.0, 1.0)
            elif nm.startswith("baked_"):
                kind = next((k for k, cols in kinds.items()
                             if any(abs(r - w[0]) + abs(g - w[1]) + abs(b - w[2]) < tol for w in cols)), None)
                if kind:
                    lo, hi = where(nz, kind, P)
                    entry = (kind, group, 0.0, lo, hi, 1.0)
                elif c.z >= leaf_from and g > r * 1.08 and g > b * 1.08:
                    lo, hi = hearts if hearts else where(nz, "leaf", P)
                    entry = ("leaf", group, 0.0, lo, hi, 1.0)
            rows.append(entry)
        out[o.name] = rows
    return out


def paint(entries, ramps, style, P, kind_names):
    """Paints the open scene: `entries` is {object name: [entry per polygon]}; returns shade.py's statistics."""
    sun_now, ambient_now = shade.light_at(style, P["minute"])
    return shade.shade_scene(paint=entries, ramps=ramps, floor=P["floor"], ambient=ambient_now, sun_energy=sun_now,
                             ao_share=P["ao_share"], take_out=P["take_out"], e_ref=P["e_ref"], weights=P["weights"],
                             gain=P["gain"], channel=P["channel"], curve=P["curve"], stop_gain=P["stop_gain"],
                             painted=P["painted"], diffuse=P["diffuse"], turns=P["turns"],
                             kind_marks=kinds.marks_of(kind_names), fix_winding=P.get("fix_winding", False))
