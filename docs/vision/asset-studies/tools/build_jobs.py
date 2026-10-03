#!/usr/bin/env python3
"""Writes the image jobs from data/styles.json, data/subjects.json and data/plan.json.

    python3 tools/build_jobs.py            # write jobs/, JOBS.md, STYLES.md, SUBJECTS.md
    python3 tools/build_jobs.py --check    # fail if any of them is out of date, or a job names a missing reference

One job is one image. A job file (jobs/<batch>/<job>.md) holds everything the image agent needs: the
reference images to load, the exact prompt, where the image goes and what to look for before saving it.
The prompts use the labelled lines of the Codex image generation skill (Use case, Asset type, Primary
request, Input images, Scene/backdrop, Subject, Style/medium, Composition/framing, Lighting/mood,
Color palette, Materials/textures, Constraints, Avoid), so the agent can submit them as they are.

Standard library only. Edit the data, not the generated files.
"""
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PACK = HERE.parent
DATA = PACK / "data"

GREY = "one plain mid-grey backdrop (about #B8B8B8) across the whole canvas, with no floor line, horizon, scenery, sky or people; a soft gradient in the grey is fine; a soft contact shadow under each object and nothing else"
NO_TEXT = "no text, letters, numbers, labels, captions, arrows, dimension lines, logos, signatures or watermark anywhere"
FLOATING = "small name labels and round markers that float in Image 1 are interface elements, not part of the scene, and are left out"
BUILDABLE = "made of a small number of solid, simple parts that a low-polygon game model can reproduce, with nothing wire-thin: legs, rails, stems and branches drawn sturdy"
# A night style on a design sheet (styles.json: night_design). The pilot's neon tree came back lit by its own lamps, and its colours could not be used.
NIGHT_RULE = ("every surface is drawn in its own colour, as neutral light shows it; lamps, lanterns and light strips are drawn switched on as small bright parts, "
              "but their light does not fall on the object, the ground or the backdrop: no glow on leaves, bark, walls or seats, no halo and no pool of light")
NIGHT_CHECK = "It is not a night scene: every surface shows its own colour, and only the lamps themselves are bright."
PLAIN_GREY = "The backdrop is plain grey with no scenery, floor or people (a soft gradient in the grey is fine)."
READABLE = "drawn in a few clear pixel clusters that still read at a sprite's small size"
# Which of a style's material phrases to offer for a set of things, by the palette groups its sheet names.
VOCAB_OF = {"timber": "timber", "metal": "metal", "stone": "stone", "foliage": "foliage", "trunk": "trunk", "light": "lamp",
            "architecture": "wall", "water": "water", "ground": "paving"}
VIEW_3D = "in three-quarter view from the front-right with the camera raised about 30 degrees"
VIEW_SPRITE = "as a game sprite seen from the game's fixed camera: an orthographic view looking down at 30 degrees with the object turned 45 degrees, the 2:1 dimetric view of classic isometric pixel games"
SPRITE_GRID = "every sprite pixel is one square block about 5 canvas pixels wide, and all blocks sit on one grid"
SIZES = {"landscape": (1536, 1024), "square": (1024, 1024), "portrait": (1024, 1536)}
FAMILY = {
    "A": "asset design sheet",
    "B": "surface",
    "C": "shape for the image-to-3D model",
    "D": "repainted game frame",
    "E": "life-cycle sheet",
}
STAGES = {
    "building": (
        "being built: the structural frame up and part of the walls and roof in place, scaffolding along one side, materials stacked at its foot",
        "newly finished",
        "after ten years of use: planting grown up its walls and on its terraces, an awning or canopy added, a few small repairs in a slightly different tone",
    ),
    "tree": (
        "newly planted: a young tree a quarter of the size, tied to a stake, in the same bed",
        "mature, as it stands today",
        "very old: a broader crown and heavier limbs, one limb propped on a timber support, more lanterns",
    ),
    "made": (
        "its parts laid out before assembly as a kit, every piece separate and flat on the ground",
        "new, just assembled",
        "after years of use: edges worn, one part replaced in a slightly different tone, one small neat repair",
    ),
}


def load():
    styles = json.loads((DATA / "styles.json").read_text())
    subjects = json.loads((DATA / "subjects.json").read_text())["subjects"]
    plan = json.loads((DATA / "plan.json").read_text())
    return styles, subjects, plan


def sentence(text):
    """`text` with its first letter capitalised and one full stop at the end."""
    text = text.strip()
    if not text:
        return ""
    text = text[0].upper() + text[1:]
    return text if text[-1] in ".!?" else text + "."


def look_of(subject_id, subject, style_id, style):
    """How this style draws the subject: the sheet's own way where the sheets show it."""
    if subject_id == "agent-a1":
        return style["agent"]
    look = subject.get("looks", {}).get(style_id)
    if look:
        return look
    v = style["vocab"]
    return (f"The concept sheets do not show this closely, so design it to belong with what they do show, "
            f"in this style's own materials: {v['timber']}; {v['metal']}; {v['stone']}")


def refs_line(style, panels):
    parts = [f"Image {k + 1}: style reference (the {p} panel)" for k, p in enumerate(panels)]
    return ("; ".join(parts) + ". These are panels from the concept sheets of the "
            f"{style['name']} style. Take from them only how this style renders, colours and builds things like this. "
            "Do not copy their composition, scenery, people or captions.")


def panel_refs(style_id, panels):
    return [(f"refs/panels/{style_id}/{p}.jpg", f"style reference: the {p} panel of this style's concept sheets") for p in panels]


def palette_for(style, groups=None, design=False):
    """The style's colours for these material groups (all of them when none are named). On a design image a
    style may name different colours (`design_palette`): the surface's own, where the scene's are lit ones."""
    palette = dict(style["palette"])
    if design:
        palette.update(style.get("design_palette", {}))
    if groups:
        text = "; ".join(palette[g] for g in groups)
    else:
        text = "; ".join(f"{g}: {v}" for g, v in palette.items())
    return f"{style['palette_rule']}: {text}" if style.get("palette_rule") else text


def design_light(style):
    return style["design_light"] + ("; " + NIGHT_RULE if style.get("night_design") else "")


def prompt_text(lines):
    return "\n".join(f"{label}: {value}" for label, value in lines if value)


def made_as(style):
    return "a finished game sprite" if style.get("sprite") else "a finished game model"


def buildable(style):
    return READABLE if style.get("sprite") else BUILDABLE


def view_for(style):
    return VIEW_SPRITE if style.get("sprite") else VIEW_3D


def sprite_note(style):
    return f" {sentence(SPRITE_GRID)}" if style.get("sprite") else ""


# ---- Family A: design sheets -------------------------------------------------------------------------------

def composition(layout, style, materials, count):
    sprite = style.get("sprite")
    swatches = "a row of flat square colour swatches, one for each of these, in this order: " + ", ".join(materials)
    if layout == "hero":
        if sprite:
            body = (f"Left two-thirds: the object large, {VIEW_SPRITE}, the whole of it in frame with a clear margin. "
                    "Right third, stacked: above, the same sprite turned to face the other way; below, its night version "
                    "with whatever lights it has lit and everything else darkened towards navy.")
        else:
            body = ("Left two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, "
                    "the whole of it in frame with a clear margin. Right third, stacked: a straight-on front elevation above, "
                    "a straight-down plan view below.")
        return f"landscape canvas, 1536 x 1024. {body} Along the bottom edge: {swatches}.{sprite_note(style)}"
    if layout == "hero-long":
        if sprite:
            body = (f"Top two-thirds: the object large, {VIEW_SPRITE}, the whole of its length in frame. "
                    "Bottom third: its night version at the same size, with whatever lights it has lit.")
        else:
            body = ("Top two-thirds: one large three-quarter view from the front-right with the camera raised about 30 degrees, "
                    "the whole of its length in frame. Bottom third: a straight-on side elevation running the width of the canvas.")
        return f"landscape canvas, 1536 x 1024. {body} In the bottom right corner: {swatches}.{sprite_note(style)}"
    if layout == "turnaround":
        how = "as game sprites, " if sprite else ""
        return (f"landscape canvas, 1536 x 1024. Four full-body views of the same figure {how}in one row, equally spaced, "
                "all the same height and standing on the same ground line: front, three-quarter front, side, back. "
                f"Along the bottom edge: {swatches}.{sprite_note(style)}")
    cells = {"grid4": "four equal cells, two across and two down", "grid6": "six equal cells, three across and two down",
             "row4": "four equal columns", "trio": "three equal columns", "pair": "two equal columns"}[layout]
    if layout == "row4":
        placed = (f"One object in each column, {view_for(style)}, standing on a ground line near the bottom of its column and drawn as tall "
                  "as the column allows, so the objects are not drawn to one scale.")
    else:
        placed = f"One object in each, centred, {view_for(style)}, drawn as large as its cell allows."
    return (f"landscape canvas, 1536 x 1024, divided into {cells} with clear empty backdrop between them. "
            f"{placed} Every object stands well clear of its neighbours and of the canvas edge: no part or shadow of one reaches another. "
            "Under each object: a short row of flat square colour swatches, one for each of its main materials."
            f"{sprite_note(style)}")


def design_job(sheet, style_id, style, subjects):
    ids = sheet["subjects"]
    layout = sheet["layout"]
    blank = any("blank" in subjects[i].get("rules", "") for i in ids)
    if len(ids) == 1 and layout in ("hero", "hero-long", "turnaround", "trio", "pair"):
        s = subjects[ids[0]]
        subject = " ".join(filter(None, [
            sentence(s["what"]), sentence(s.get("rules", "")),
            "In this style: " + sentence(look_of(ids[0], s, style_id, style)),
            "Character notes: " + sentence(s["story"]) if s.get("story") else "",
        ]))
        title = sentence(s["name"])[:-1]
        if layout in ("trio", "pair"):
            count = 3 if layout == "trio" else 2
            word = "three" if count == 3 else "two"
            request = f"a clean design sheet of {word} variants of one kind of building, {s['name']}, each drawn as {made_as(style)} in the style of the reference images"
            only = f"{word} separate variants of one kind of building, alike in size and style"
        elif layout == "turnaround":
            request = f"a clean design sheet of one figure, {s['name']}, drawn as {made_as(style)} in the style of the reference images"
            count, only = 1, "one figure only, shown four times as the same figure with the same clothes, parts and colours"
        else:
            request = f"a clean design sheet of one thing, {s['name']}, drawn as {made_as(style)} in the style of the reference images"
            count, only = 1, "one thing only, shown more than once as the same object with the same parts and colours"
        materials = s["materials"]
    else:
        items = []
        for k, i in enumerate(ids):
            s = subjects[i]
            look = s.get("looks", {}).get(style_id)
            text = sentence(s["what"]) + (" " + sentence(s["rules"]) if s.get("rules") else "") + (" In this style: " + sentence(look) if look else "")
            items.append(f"{k + 1}. {text}")
        v = style["vocab"]
        offered = "; ".join(v[VOCAB_OF[g]] for g in sheet["palette"] if g in VOCAB_OF)
        subject = (f"{len(ids)} separate objects, in reading order. " + " ".join(items) +
                   f" Where a note above does not say how this style draws an object, use the style's own materials: {offered}.")
        title = ", ".join(subjects[i]["name"] for i in ids)
        request = f"a clean design sheet of {len(ids)} separate things, each drawn as {made_as(style)} in the style of the reference images"
        count, only = len(ids), f"exactly {len(ids)} objects, each whole, inside its own cell and touching nothing"
        materials = []
    blank_rule = "; every screen, sign, board and plaque face is a plain blank surface" if blank else ""
    medium = style["medium"]
    prompt = prompt_text([
        ("Use case", "stylized-concept"),
        ("Asset type", "game asset design sheet: the target that a 3D model" + (" or sprite" if style.get("sprite") else "") + " will be built to"),
        ("Primary request", request),
        ("Input images", refs_line(style, sheet["panels"])),
        ("Scene/backdrop", GREY),
        ("Subject", subject),
        ("Style/medium", medium),
        ("Composition/framing", composition(layout, style, materials, count)),
        ("Lighting/mood", design_light(style)),
        ("Color palette", palette_for(style, sheet["palette"], design=True)),
        ("Materials/textures", style["surface"]),
        ("Constraints", f"{only}; {buildable(style)}{blank_rule}; {NO_TEXT}"),
        ("Avoid", f"scenery, extra props, people other than the subject, perspective distortion, depth of field, bloom, heavy cast shadows, {style['avoid']}"),
    ])
    checks = [
        "The canvas is landscape, close to 3:2.",
        PLAIN_GREY,
        (f"There are exactly {count} objects, each whole and inside the canvas." if count > 1 else
         "There is one thing only, whole in every view, and the views show the same object."),
        "There is no readable text, label or number anywhere.",
        "It reads as this style's concept sheets do, and as something a simple game model could reproduce.",
    ]
    if blank:
        checks.append("Screens, signs, boards and plaque faces are blank.")
    if style.get("night_design"):
        checks.append(NIGHT_CHECK)
    if style.get("sprite"):
        checks.append("Pixels are hard-edged squares of one size, with no blur.")
    return {"title": title, "family": "A", "kind": "design sheet", "size": SIZES["landscape"], "prompt": prompt,
            "refs": panel_refs(style_id, sheet["panels"]), "checks": checks, "edit": False}


# ---- Family B: surfaces ------------------------------------------------------------------------------------

def board_job(board, style_id, style):
    v = style["vocab"]
    tiles = " ".join(f"{k + 1}. {sentence(label)[:-1]}: {v[key]}." for k, (key, label) in enumerate(board["tiles"]))
    prompt = prompt_text([
        ("Use case", "stylized-concept"),
        ("Asset type", "material sample board for a game's art direction"),
        ("Primary request", f"six square samples of {board['title']}, as the reference images draw them"),
        ("Input images", refs_line(style, board["panels"])),
        ("Scene/backdrop", "a flat mid-grey backdrop (#B8B8B8) that shows only as narrow gaps between the samples"),
        ("Subject", "six flat square tiles, each a straight-on sample of one material that fills its tile from edge to edge, at a scale where the tile is about 2 m across. In reading order: " + tiles),
        ("Style/medium", f"flat material samples, drawn the way the reference images draw surfaces: {style['texture']}"),
        ("Composition/framing", "landscape canvas, 1536 x 1024: three tiles across and two down, all the same size, with equal narrow gaps"),
        ("Lighting/mood", "flat, even light with no shadows and no highlights"),
        ("Color palette", palette_for(style, board["palette"], design=True)),
        ("Constraints", f"each tile shows only its material, seen flat-on, with no objects, no perspective and no frame; {NO_TEXT}"),
        ("Avoid", f"scenes, objects, perspective, vignettes, {style['avoid']}"),
    ])
    checks = ["The canvas is landscape, close to 3:2.", "There are six square tiles in three columns and two rows.",
              "Each tile is a flat-on sample of one material, with no objects or perspective.", "There is no readable text."]
    return {"title": sentence(board["title"])[:-1] + " (board)", "family": "B", "kind": "material board", "size": SIZES["landscape"],
            "prompt": prompt, "refs": panel_refs(style_id, board["panels"]), "checks": checks, "edit": False}


def texture_job(tex, style_id, style):
    v = style["vocab"]
    prompt = prompt_text([
        ("Use case", "stylized-concept"),
        ("Asset type", "tileable game texture"),
        ("Primary request", f"a seamless tileable texture of {tex['what']}, as the reference images draw it"),
        ("Input images", refs_line(style, tex["panels"])),
        ("Subject", sentence(v[tex["vocab"]])),
        ("Style/medium", f"a seamless tileable game texture, drawn the way the reference images draw surfaces: {style['texture']}"),
        ("Composition/framing", "square canvas, 1024 x 1024, the material filling the whole canvas flat-on with no perspective"),
        ("Lighting/mood", "flat, even light with no shadows and no highlights"),
        ("Color palette", palette_for(style, tex["palette"], design=True)),
        ("Constraints", f"seamless on all four edges, so that copies placed side by side show no join; even density with no single focal element; no objects, cast shadows, borders or vignette; {NO_TEXT}"),
        ("Avoid", f"perspective, objects, a darker or lighter centre, {style['avoid']}"),
    ])
    checks = ["The canvas is square.", "The material fills the canvas flat-on, with no objects, perspective or border.",
              "The left edge would meet the right edge, and the top the bottom, without a visible join.", "There is no readable text."]
    return {"title": sentence(tex["vocab"].replace("_", " "))[:-1] + " (texture)", "family": "B", "kind": "tiling texture", "size": SIZES["square"],
            "prompt": prompt, "refs": panel_refs(style_id, tex["panels"]), "checks": checks, "edit": False}


def atlas_job(atlas, style_id, style):
    key = {"magenta": "pure magenta (#FF00FF)", "blue": "pure blue (#0000FF)"}[atlas["key"]]
    cells = " ".join(f"{k + 1}. {sentence(c)}" for k, c in enumerate(atlas["cells"]))
    prompt = prompt_text([
        ("Use case", "stylized-concept"),
        ("Asset type", "cut-out atlas for the foliage of a game"),
        ("Primary request", f"four separate cut-outs of {atlas['title']}, as the reference images draw them"),
        ("Input images", refs_line(style, atlas["panels"])),
        ("Scene/backdrop", f"one flat {key} backdrop across the whole canvas, used as a colour key, with no shadows or gradients on it"),
        ("Subject", f"four separate pieces, one in each quarter of the canvas, each centred with clear backdrop all round it. In reading order: {cells} In this style foliage is drawn as: {style['vocab']['foliage']}."),
        ("Style/medium", style["medium"]),
        ("Composition/framing", "square canvas, 1024 x 1024, divided into four equal quarters" + sprite_note(style)),
        ("Lighting/mood", design_light(style)),
        ("Color palette", palette_for(style, atlas["palette"], design=True)),
        ("Constraints", f"each piece complete, inside its own quarter and touching nothing; crisp edges with no halo and none of the backdrop colour on the pieces; no ground, pots or shadows; {NO_TEXT}"),
        ("Avoid", f"pieces that overlap or run off the canvas, soft glows, {style['avoid']}"),
    ])
    checks = ["The canvas is square.", "There are four separate pieces, one in each quarter, none touching another or the edge.",
              f"The backdrop is one flat {atlas['key']} with no shadows.", "There is no readable text."]
    return {"title": sentence(atlas["title"])[:-1] + " (cut-outs)", "family": "B", "kind": "cut-out atlas", "size": SIZES["square"],
            "prompt": prompt, "refs": panel_refs(style_id, atlas["panels"]), "checks": checks, "edit": False}


# ---- Family C: shapes --------------------------------------------------------------------------------------

def shape_job(shape, which, styles):
    size = SIZES["portrait" if shape["tall"] else "square"]
    canvas = "portrait canvas, 1024 x 1536" if shape["tall"] else "square canvas, 1024 x 1024"
    if which == "voxel":
        style = styles["styles"]["voxel"]
        refs = panel_refs("voxel", ["street", "park"])
        medium = "a plain voxel model render: everything built only from cubes on one grid, matte, each cube one flat colour, with no smooth curves"
        images = refs_line(style, ["street", "park"])
    else:
        refs, images = [], ""
        medium = ("a plain, clean 3D model render, like an untextured model in a viewer: matte surfaces, each part one flat colour "
                  "(bark brown, leaves mid green, flowers a pale colour), simple solid forms with clear gaps between them")
    prompt = prompt_text([
        ("Use case", "stylized-concept"),
        ("Asset type", "single-object render, used as the input of an image-to-3D model"),
        ("Primary request", "a plain render of " + shape["what"].split(":")[0]),
        ("Input images", images),
        ("Scene/backdrop", "one flat light-grey backdrop (#D9D9D9), with no floor, no horizon and no shadow on it"),
        ("Subject", sentence(shape["what"])),
        ("Style/medium", medium),
        ("Composition/framing", f"{canvas}. One object, centred and whole, with a clear margin on every side, in three-quarter view with the camera raised about 25 degrees so that the top of the object shows"),
        ("Lighting/mood", "soft even studio light from the upper front, with no cast shadows"),
        ("Constraints", f"exactly one object; nothing cut off by the canvas edge; no ground plane, pot, base, people or scenery; {NO_TEXT}"),
        ("Avoid", "painterly brushwork, outlines, depth of field, haze, backlight, transparency, fine noise"),
    ])
    checks = ["There is exactly one object, whole, centred, with margin on every side.", "The backdrop is one flat light grey with no floor or shadow.",
              "It looks like a plain 3D model, not a painting.", "The top of the object is visible."]
    if which == "voxel":
        checks.append("Everything is built from cubes.")
    return {"title": sentence(shape["what"].split(":")[0])[:-1], "family": "C", "kind": "shape", "size": size, "prompt": prompt,
            "refs": refs, "checks": checks, "edit": False}


# ---- Family D: frames --------------------------------------------------------------------------------------

def frame_job(frame, style_id, style):
    dressed = frame.get("dressed", False)
    target = f"refs/frames/{style_id}/{frame['view']}.jpg"
    panels = frame["panels"]
    what = frame.get("what_sprite", frame["what"]) if style.get("sprite") else frame["what"]
    images = (f"Image 1: edit target, a capture of the game as it is today in the {style['name']} pack, showing {what}; " +
              "; ".join(f"Image {k + 2}: style reference (the {p} panel of this style's concept sheets)" for k, p in enumerate(panels)) +
              ". Take the look from the style references and the layout from Image 1.")
    light = ("night and rain, as the night panel of the concept sheets shows them" if frame["view"] == "night-rain" else style["scene_light"])
    if dressed:
        request = "repaint Image 1 in the style of the reference images and dress the scene as they are dressed, keeping what exists where it is"
        constraints = ("keep the camera, the horizon, and the position, size and outline of everything that exists in Image 1; "
                       "add only what the reference panels show in such a place and Image 1 lacks: planted beds and planter boxes, flowers, "
                       "café tables and umbrellas, banners, and more people; put additions on open ground, never across a path, a doorway or the tram track; "
                       f"keep the canvas the same shape as Image 1 (1536 x 1024); {FLOATING}; {NO_TEXT}")
        avoid = "new buildings, new large trees, a different viewpoint, cropping, borders, " + style["avoid"]
    else:
        request = "repaint Image 1 in the style of the reference images, keeping its layout exactly"
        constraints = ("change only surfaces, colours, light, the detail of foliage and small surface detail; keep the camera, the horizon, "
                       "and the position, size and outline of every building, tree, lamp, bench, person, vehicle, path and kerb exactly as in Image 1; "
                       f"do not add, remove, move or resize anything; keep the canvas the same shape as Image 1 (1536 x 1024); {FLOATING}; {NO_TEXT}")
        avoid = "new or missing objects, a different viewpoint, cropping, borders, " + style["avoid"]
    prompt = prompt_text([
        ("Use case", "sketch-to-render"),
        ("Asset type", "paint-over of a game capture, used as a like-for-like art target"),
        ("Primary request", request),
        ("Input images", images),
        ("Style/medium", f"the finished look of this style's concept sheets: {style['surface']}"),
        ("Lighting/mood", light),
        ("Color palette", palette_for(style)),
        ("Constraints", constraints),
        ("Avoid", avoid),
    ])
    checks = ["The canvas is landscape, the same shape as the capture.",
              "Set beside the capture: every building, the tree, lamps, benches and people are where they were and the size they were.",
              ("Nothing that was in the capture is gone; additions are planting, furniture, banners and people only, on open ground." if dressed
               else "Nothing has been added, removed or moved."),
              "The surfaces, colours and light look like the reference panels.", "There is no readable text."]
    refs = [(target, "edit target: a capture of the game as it is today")] + panel_refs(style_id, panels)
    return {"title": sentence(what)[:-1] + (" (dressed)" if dressed else ""), "family": "D",
            "kind": "dressed frame" if dressed else "repainted frame", "size": SIZES["landscape"], "prompt": prompt, "refs": refs,
            "checks": checks, "edit": True}


# ---- Family E: states --------------------------------------------------------------------------------------

def state_job(state, style_id, style, subjects, sheet_id):
    """`sheet_id` is the design sheet the object is on. The pilot's worn bench was a different bench from its
    design sheet's, so the job loads that sheet's newest image and holds the new stage to it."""
    s = subjects[state["subject"]]
    one = state.get("one", s["name"])
    stages = STAGES[state["kind"]]
    stage_text = " ".join(f"{k + 1}. {sentence(t)}" for k, t in enumerate(stages))
    subject = " ".join(filter(None, [
        sentence(state.get("what", s["what"])), "In this style: " + sentence(look_of(state["subject"], s, style_id, style)),
        f"Three stages, left to right: {stage_text}",
    ]))
    prompt = prompt_text([
        ("Use case", "stylized-concept"),
        ("Asset type", "game asset life-cycle sheet: one asset at three stages"),
        ("Primary request", f"{one} at three stages of its life, side by side, each drawn as {made_as(style)} in the style of the reference images"),
        ("Input images", refs_line(style, state["panels"]) + f" Image {len(state['panels']) + 1}: the design sheet that shows {one}. "
         "The second stage is that object exactly: the same design, parts, proportions and colours. Take nothing else from that sheet."),
        ("Scene/backdrop", GREY),
        ("Subject", subject),
        ("Style/medium", style["medium"]),
        ("Composition/framing", f"landscape canvas, 1536 x 1024, divided into three equal columns with clear empty backdrop between them; one stage in each, {view_for(style)}, the same viewpoint and the same size in all three.{sprite_note(style)}"),
        ("Lighting/mood", design_light(style)),
        ("Color palette", palette_for(style, state["palette"], design=True)),
        ("Materials/textures", style["surface"]),
        ("Constraints", f"the same object in all three stages, with the same footprint, main form and viewpoint; {buildable(style)}; {NO_TEXT}"),
        ("Avoid", f"scenery, people, three different designs, perspective distortion, depth of field, bloom, {style['avoid']}"),
    ])
    checks = ["The canvas is landscape, close to 3:2.", "There are three stages in a row, of the same object from the same viewpoint.",
              "The backdrop is plain grey with no scenery (a soft gradient in the grey is fine).", "There is no readable text.",
              "The second stage is the object on its design sheet: the same design, not a new one."]
    if style.get("night_design"):
        checks.append(NIGHT_CHECK)
    refs = panel_refs(style_id, state["panels"]) + [(f"sheets/{style_id}/{sheet_id}/LATEST/image.png",
                                                     f"the design sheet of this object: the newest revision in `sheets/{style_id}/{sheet_id}/` (the highest rNNN)")]
    return {"title": sentence(one)[:-1] + " (three stages)", "family": "E", "kind": "life-cycle sheet", "size": SIZES["landscape"], "prompt": prompt,
            "refs": refs, "checks": checks, "edit": False}


# ---- Assembly ----------------------------------------------------------------------------------------------

def all_jobs():
    styles, subjects, plan = load()
    pilot = set(plan["pilot"])
    rest = set(plan.get("pilot_rest", []))
    # A job asked for again: the reason, or {"why": the reason, "batch": the batch it is to be run in}.
    asked_again = plan.get("redo", {})
    redo = {job_id: (v["why"] if isinstance(v, dict) else v) for job_id, v in asked_again.items()}
    redo_batch = {job_id: v["batch"] for job_id, v in asked_again.items() if isinstance(v, dict)}
    moved = {job_id: batch for batch, ids in plan.get("moved", {}).items() for job_id in ids}
    sheet_of = {subject: sheet["id"] for sheet in plan["design_sheets"] for subject in sheet["subjects"]}
    jobs = []

    def add(style_id, item_id, batch, job):
        job_id = f"{style_id}.{item_id}"
        if job_id in redo_batch:
            batch = redo_batch[job_id]
        elif job_id in rest or job_id in redo:
            batch = "00b-pilot-rest"
        elif job_id in pilot:
            batch = "00-pilot"
        elif job_id in moved:
            batch = moved[job_id]
        job.update({"id": job_id, "style": style_id, "item": item_id, "batch": batch, "out": f"sheets/{style_id}/{item_id}",
                    "redo": redo.get(job_id)})
        jobs.append(job)

    for style_id in styles["order"]:
        style = styles["styles"][style_id]
        for sheet in plan["design_sheets"]:
            add(style_id, sheet["id"], sheet["batch"], design_job(sheet, style_id, style, subjects))
        for board in plan["boards"]:
            add(style_id, board["id"], board["batch"], board_job(board, style_id, style))
        for tex in plan["textures"]:
            add(style_id, tex["id"], tex["batch"], texture_job(tex, style_id, style))
        for atlas in plan["atlases"]:
            add(style_id, atlas["id"], atlas["batch"], atlas_job(atlas, style_id, style))
        for frame in plan["frames"]:
            if style_id not in frame.get("skip", []):
                add(style_id, frame["id"], frame["batch"], frame_job(frame, style_id, style))
        for state in plan["states"]:
            add(style_id, state["id"], "04-life", state_job(state, style_id, style, subjects, sheet_of[state["subject"]]))
    for which in ("neutral", "voxel"):
        for shape in plan["shapes"][which]:
            add(which, shape["id"], "03-shapes", shape_job(shape, which, styles))
    missing = (pilot | rest | set(redo) | set(moved)) - {j["id"] for j in jobs}
    if missing:
        raise SystemExit(f"plan.json's pilot, pilot_rest, redo or moved names jobs that do not exist: {sorted(missing)}")
    order = {b: k for k, b in enumerate(plan["batches"])}
    jobs.sort(key=lambda j: (order[j["batch"]], j["id"]))
    return jobs, styles, subjects, plan


def style_label(job, styles):
    return styles["styles"][job["style"]]["name"] if job["style"] in styles["styles"] else {"neutral": "No style (plain model)", "voxel": "Voxel"}[job["style"]]


def job_markdown(job, styles):
    w, h = job["size"]
    lines = [f"# {job['id']}", "",
             f"{job['title']} · {FAMILY[job['family']]} ({job['kind']}) · style: {style_label(job, styles)} · batch {job['batch']} · canvas {w} x {h}", ""]
    if job.get("redo"):
        lines += ["## Asked for again", "", f"This job has an image already and is to be made again: {job['redo']}. The new image becomes the next revision.", ""]
    lines += ["## Reference images", ""]
    if job["refs"]:
        lines.append("Load each with `view_image`, in this order, before generating." +
                     (" Image 1 is the edit target: this job is an edit of it." if job["edit"] else " This job is a new image, not an edit."))
        lines.append("")
        lines += [f"{k + 1}. `{path}` — {role}" for k, (path, role) in enumerate(job["refs"])]
        if any("/LATEST/" in path for path, _ in job["refs"]):
            lines += ["", "`LATEST` stands for the newest revision folder of that design sheet. If the sheet has no image yet, skip this job and say so: it cannot be made first."]
    else:
        lines.append("None. This job has no reference images.")
    lines += ["", "## Prompt", "", "Submit exactly this text.", "", "```text", job["prompt"], "```", "",
              "## Before saving, look at the image", ""]
    lines += [f"- {c}" for c in job["checks"]]
    lines += ["", "## Save", "", "```sh", f"python3 tools/intake.py add {job['id']} PATH_TO_THE_GENERATED_IMAGE", "```", "",
              f"It files the image as `{job['out']}/rNNN/image.png` with its prompt and its record.", ""]
    return "\n".join(lines)


def jobs_index(jobs, styles, plan):
    lines = ["# The image jobs", "",
             "Written by `tools/build_jobs.py` from `data/`. Do not edit by hand. `python3 tools/intake.py status` shows which are done.", ""]
    for batch, about in plan["batches"].items():
        mine = [j for j in jobs if j["batch"] == batch]
        lines += [f"## {batch} ({len(mine)} images)", "", about, "", "| Job | What | Kind | Canvas |", "| --- | --- | --- | --- |"]
        lines += [f"| [{j['id']}](jobs/{batch}/{j['id']}.md) | {j['title']} | {j['kind']} | {j['size'][0]} x {j['size'][1]} |" for j in mine]
        lines.append("")
    return "\n".join(lines)


def styles_markdown(styles):
    lines = ["# The six styles", "",
             "Written by `tools/build_jobs.py` from `data/styles.json`. These are the words every prompt uses for each style. "
             "They were written on 2026-10-02 from the selected concept sheets and from colours measured in them; "
             "edit `data/styles.json` and rebuild if a description is wrong.", ""]
    for style_id in styles["order"]:
        s = styles["styles"][style_id]
        lines += [f"## {s['name']} (`{style_id}`)", "", f"Concept sheets: [style study {s['study']}](../style-studies/styles/{s['study']}/README.md).", "",
                  f"- **Medium:** {s['medium']}.", f"- **Surfaces:** {s['surface']}.", f"- **A flat sample of a surface:** {s['texture']}.",
                  f"- **Light on a design sheet:** {s['design_light']}.", f"- **Light in a scene:** {s['scene_light']}.",
                  f"- **Avoid:** {s['avoid']}.", f"- **People:** {s['people']}.", f"- **The agent:** {s['agent']}.", "",
                  "| Material | How this style draws it |", "| --- | --- |"]
        lines += [f"| {k.replace('_', ' ')} | {v} |" for k, v in s["vocab"].items()]
        lines += ["", "| Colours of | As measured in, or read from, the concept sheets |", "| --- | --- |"]
        lines += [f"| {k} | {v} |" for k, v in s["palette"].items()]
        lines.append("")
    return "\n".join(lines)


def subjects_markdown(subjects, styles):
    lines = ["# What is drawn", "",
             "Written by `tools/build_jobs.py` from `data/subjects.json`: every thing the game draws today, with its real size, "
             "what the game needs of it, how each style's concept sheets draw it, and a proposed line of character. "
             "The character lines are proposals for the owner to change. A style missing from a list means its sheets do not show the thing closely.", ""]
    for sid, s in subjects.items():
        lines += [f"## {sentence(s['name'])[:-1]} (`{sid}`)", "", sentence(s["what"]) + (" " + sentence(s["rules"]) if s.get("rules") else ""), ""]
        if s.get("story"):
            lines += [f"Character (proposed): {sentence(s['story'])}", ""]
        looks = s.get("looks", {})
        if sid == "agent-a1":
            looks = {k: styles["styles"][k]["agent"] for k in styles["order"]}
        lines += [f"- **{styles['styles'][k]['name']}:** {sentence(v)}" for k, v in looks.items()]
        if looks:
            lines.append("")
    return "\n".join(lines)


def outputs():
    jobs, styles, subjects, plan = all_jobs()
    files = {f"jobs/{j['batch']}/{j['id']}.md": job_markdown(j, styles) for j in jobs}
    slim = [{k: j[k] for k in ("id", "batch", "family", "kind", "style", "item", "title", "size", "edit", "redo", "out", "refs", "checks", "prompt")} for j in jobs]
    files["jobs/jobs.json"] = json.dumps({"jobs": slim}, indent=1, ensure_ascii=False) + "\n"
    files["JOBS.md"] = jobs_index(jobs, styles, plan)
    files["STYLES.md"] = styles_markdown(styles)
    files["SUBJECTS.md"] = subjects_markdown(subjects, styles)
    return files, jobs


def main(argv):
    files, jobs = outputs()
    if "--check" in argv:
        stale = [p for p, text in files.items() if not (PACK / p).exists() or (PACK / p).read_text() != text]
        extra = [str(p.relative_to(PACK)) for p in (PACK / "jobs").rglob("*.md") if str(p.relative_to(PACK)) not in files]
        missing = sorted({path for j in jobs for path, _ in j["refs"] if "/LATEST/" not in path and not (PACK / path).exists()})
        waiting = sum(1 for j in jobs for path, _ in j["refs"] if "/LATEST/" in path and not list((PACK / path).parents[1].glob("r[0-9][0-9][0-9]/image.png")))
        for label, items in (("out of date", stale), ("no longer a job", extra), ("missing reference image", missing)):
            for item in items:
                print(f"{label}: {item}")
        if stale or extra or missing:
            sys.exit(1)
        print(f"jobs: {len(jobs)} jobs up to date, every reference image present" + (f" ({waiting} life-cycle jobs wait for their design sheets)" if waiting else ""))
        return
    for old in (PACK / "jobs").rglob("*.md"):
        if str(old.relative_to(PACK)) not in files:
            old.unlink()
    # A file is written only when its text has changed, and put in place whole: someone may be reading the
    # jobs of a batch that is being run while another batch is added.
    for path, text in files.items():
        target = PACK / path
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_text() == text:
            continue
        fresh = target.with_name(target.name + ".new")
        fresh.write_text(text)
        os.replace(fresh, target)
    by_batch = {}
    for j in jobs:
        by_batch[j["batch"]] = by_batch.get(j["batch"], 0) + 1
    print(f"jobs: wrote {len(jobs)} jobs: " + ", ".join(f"{b} {n}" for b, n in by_batch.items()))


if __name__ == "__main__":
    main(sys.argv[1:])
