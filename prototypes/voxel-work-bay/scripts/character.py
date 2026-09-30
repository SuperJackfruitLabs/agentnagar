"""Original Coder Kai voxel appearance and rigid segmented animation rig.

No reference humanoid assets are loaded. Block proportions derive from the
02-voxel living/conversation panels; apron and tools derive from Kai's brief.
"""
import math
import bpy
from geometry import Blocks


def _chest_motif_kai(b):
    # Canvas apron, straps, pocket, pencil, and a tiny mechanism badge.
    b.box((0,-.167,1.02), (.35,.055,.35), 'cream', 'Spine')
    for x in (-.135,.135):
        b.box((x,-.162,1.20), (.050,.035,.16), 'wood_honey', 'Spine')
        b.box((x,-.19,1.132), (.029,.018,.029), 'orange', 'Spine')
    b.box((0,-.203,1.009), (.22,.021,.115), 'sand', 'Spine')
    b.box((-.065,-.222,1.075), (.025,.022,.14), 'orange', 'Spine')
    b.box((-.065,-.222,1.154), (.018,.018,.025), 'steel', 'Spine')
    b.box((.06,-.223,1.075), (.028,.022,.11), 'metal', 'Spine')
    b.box((.06,-.223,1.135), (.064,.024,.025), 'steel', 'Spine')
    b.box((0,-.204,.891), (.33,.016,.025), 'wood_honey', 'Spine')


def _head_crest_kai(b):
    b.box((.15,-.08,1.727), (.09,.15,.014), 'orange', 'Head')


def _chest_motif_lyra(b):
    # GR05: reversible colour panels and sketch sheets, within the robot shell.
    b.box((-.09,-.172,1.047), (.19,.060,.34), 'teal', 'Spine')
    b.box((.10,-.178,1.047), (.18,.066,.34), 'coral', 'Spine')
    for x in (-.135,.135):
        b.box((x,-.164,1.207), (.055,.038,.14), 'violet', 'Spine')
    b.box((.065,-.220,.98), (.19,.04,.15), 'violet', 'Spine')
    # Layered sketch sheets stay in a chest pouch, clear of joints.
    b.box((.065,-.242,1.04), (.15,.012,.16), 'paper', 'Spine')
    b.box((.041,-.253,1.05), (.024,.008,.08), 'cobalt', 'Spine')
    b.box((.090,-.253,1.075), (.046,.008,.025), 'coral', 'Spine')
    b.box((-.11,-.218,1.03), (.023,.025,.15), 'orange', 'Spine')
    b.box((-.11,-.218,1.11), (.028,.026,.025), 'steel', 'Spine')


def _head_crest_lyra(b):
    b.box((0,.02,1.729), (.33,.29,.018), 'violet', 'Head')
    b.box((-.18,.02,1.72), (.055,.29,.035), 'coral', 'Head')
    b.box((.18,.02,1.72), (.055,.29,.035), 'teal', 'Head')


def _chest_motif_olivia(b):
    # GR01: folded route-map panel — her card's route-map quilt, two crossing
    # path lines (stepped, like the head's chevron pixels) meeting at a
    # location pip.
    b.box((0,-.165,1.06), (.32,.045,.28), 'paper', 'Spine')
    for i, (x, z) in enumerate(((-.13,.94),(-.065,.99),(0,1.04),(.065,1.09),(.13,1.14))):
        b.box((x,-.185,z), (.075,.018,.06), 'cobalt', 'Spine')
    for i, (x, z) in enumerate(((.13,.95),(.065,1.00),(0,1.05),(-.065,1.10),(-.13,1.15))):
        b.box((x,-.195,z), (.075,.018,.06), 'orange', 'Spine')
    b.box((0,-.215,1.045), (.045,.024,.045), 'mint', 'Spine')


def _head_crest_olivia(b):
    b.box((0,-.06,1.725), (.07,.10,.014), 'mint', 'Head')
    b.box((0,-.10,1.735), (.03,.03,.02), 'orange', 'Head')


def _chest_motif_chotu(b):
    # GR02: shallow display shelf of miniature prototypes — his card's tiny
    # museum of lab prototypes. Fix round: the first pass used one hue
    # (wood_honey) for the backing, the shelf and one of the three
    # prototypes, so nothing separated from the ground at a glance. This
    # pass gives the shelf a dark 'ink' shadow-box behind it for value
    # contrast, a bright 'cream' lip so the ledge itself reads as an edge,
    # and pulls the three prototypes forward of the shelf's front face
    # with visible gaps between them, so they stand proud as distinct
    # objects rather than fusing into the panel.
    b.box((0,-.150,1.075), (.310,.020,.260), 'ink', 'Spine')          # shadow-box back
    b.box((0,-.190,1.000), (.310,.060,.040), 'wood_honey', 'Spine')   # shelf plank
    b.box((0,-.215,1.021), (.300,.012,.008), 'cream', 'Spine')        # shelf front lip
    for side in (-1,1):
        b.box((side*.165,-.175,.975), (.036,.050,.044), 'wood_dark', 'Spine')  # end brackets
    b.box((-.095,-.222,1.045), (.076,.070,.090), 'steel', 'Spine')    # prototype 1
    b.box((0,-.222,1.065), (.080,.070,.120), 'cobalt', 'Spine')       # prototype 2
    b.box((.095,-.218,1.040), (.072,.064,.076), 'orange', 'Spine')    # prototype 3


def _head_crest_chotu(b):
    b.box((-.13,-.05,1.728), (.05,.08,.016), 'orange', 'Head')
    b.box((-.13,-.09,1.745), (.025,.025,.018), 'steel', 'Head')


def _chest_motif_pete(b):
    # GR03: movable planning wall — a grid of cards on his navy board, one
    # offset as if just moved, per his card.
    b.box((0,-.165,1.06), (.32,.05,.28), 'navy', 'Spine')
    b.box((-.09,-.195,1.14), (.07,.016,.055), 'paper', 'Spine')
    b.box((0,-.195,1.14), (.07,.016,.055), 'paper', 'Spine')
    b.box((.09,-.195,1.14), (.07,.016,.055), 'paper', 'Spine')
    b.box((-.09,-.195,1.00), (.07,.016,.055), 'paper', 'Spine')
    b.box((0,-.195,1.00), (.07,.016,.055), 'paper', 'Spine')
    b.box((.095,-.215,1.035), (.07,.016,.055), 'paper', 'Spine')


def _head_crest_pete(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'navy', 'Head')
    b.box((.05,-.11,1.735), (.03,.03,.018), 'paper', 'Head')


def _chest_motif_ray(b):
    # GR06: annotated map cabinet — three stacked drawers, the bottom one
    # cracked open with a paper edge showing, per his card.
    b.box((0,-.16,1.06), (.30,.03,.30), 'wood_dark', 'Spine')
    b.box((0,-.185,1.155), (.26,.02,.075), 'wood_dark', 'Spine')
    b.box((0,-.185,1.06), (.26,.02,.075), 'wood_dark', 'Spine')
    b.box((0,-.21,.965), (.26,.02,.075), 'wood_dark', 'Spine')
    b.box((0,-.20,1.155), (.05,.012,.014), 'steel', 'Spine')
    b.box((0,-.20,1.06), (.05,.012,.014), 'steel', 'Spine')
    b.box((0,-.225,.965), (.05,.012,.014), 'steel', 'Spine')
    b.box((0,-.235,.94), (.22,.01,.012), 'paper', 'Spine')


def _head_crest_ray(b):
    b.box((0,-.08,1.727), (.09,.09,.014), 'wood_dark', 'Head')
    b.box((0,-.11,1.735), (.05,.025,.016), 'green', 'Head')


def _chest_motif_quill(b):
    # GR..: paper lantern beside a slim closed book — her card's paper
    # lanterns and reading nook. A dark 'ink' ground behind both objects
    # gives value contrast against the lighter paper/wood, and a clear gap
    # separates the two objects so each reads on its own (Chotu's fix-round
    # lesson: strong ground contrast, negative space between objects).
    b.box((0,-.150,1.075), (.34,.020,.30), 'ink', 'Spine')           # shadow-box back
    b.box((-.09,-.195,1.130), (.11,.060,.150), 'paper', 'Spine')     # lantern body
    b.box((-.09,-.205,1.2175), (.075,.050,.025), 'wood_dark', 'Spine')  # lantern top cap
    b.box((-.09,-.205,1.0425), (.075,.050,.025), 'wood_dark', 'Spine')  # lantern bottom cap
    b.box((-.09,-.225,1.130), (.050,.020,.090), 'orange', 'Spine')   # lit inner glow
    b.box((.10,-.200,.975), (.130,.050,.085), 'wood_dark', 'Spine')  # closed book cover
    b.box((.10,-.225,.975), (.120,.015,.075), 'ivory', 'Spine')      # page-edge sliver
    b.box((.135,-.228,1.005), (.015,.012,.045), 'orange', 'Spine')   # bookmark ribbon


def _head_crest_quill(b):
    b.box((0,-.08,1.727), (.09,.11,.014), 'wood_honey', 'Head')
    b.box((0,-.12,1.738), (.04,.04,.02), 'orange', 'Head')


def _chest_motif_echo(b):
    # GR..: kinetic bar-chart relief, rising blocks — his card's bar-chart
    # sculpture. A dark 'ink' ground behind and under the bars gives value
    # contrast, and each bar is gapped from its neighbours and pulled
    # forward of the ground so it stands proud instead of fusing into a
    # slab (the lesson from Chotu's first pass).
    b.box((0,-.160,1.06), (.34,.030,.32), 'ink', 'Spine')     # shadow-box back
    b.box((0,-.185,.915), (.34,.020,.04), 'ink', 'Spine')     # baseline plinth
    heights = (.08,.14,.20,.24,.28)
    xs = (-.152,-.076,0,.076,.152)
    colors = ('sky','led_green','sky','led_green','sky')
    for x, h, color in zip(xs, heights, colors):
        z = .935 + h/2
        b.box((x,-.205,z), (.06,.05,h), color, 'Spine')


def _head_crest_echo(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'sky', 'Head')
    b.box((.035,-.115,1.735), (.03,.03,.018), 'led_green', 'Head')


def _chest_motif_paul(b):
    # GR..: a branching fork — her card's weather mobile and branching
    # paths. A single ivory trunk splits into two stepped blue_light
    # branches (contiguous boxes, Olivia's fix-round lesson so the path
    # reads as a line, not scattered squares), with a sky weather bead
    # hanging below one branch tip. A dark navy ground sets both apart.
    b.box((0,-.155,1.06), (.32,.020,.28), 'navy', 'Spine')    # shadow-box back
    b.box((0,-.185,.950), (.05,.030,.10), 'ivory', 'Spine')   # trunk
    for i, (x, z) in enumerate(((-.02,1.02),(-.07,1.08),(-.12,1.14))):
        b.box((x,-.20-.005*i,z), (.06,.03,.06), 'blue_light', 'Spine')  # branch left
    for i, (x, z) in enumerate(((.02,1.02),(.07,1.08),(.12,1.14))):
        b.box((x,-.20-.005*i,z), (.06,.03,.06), 'blue_light', 'Spine')  # branch right
    b.box((.15,-.230,1.10), (.04,.04,.04), 'sky', 'Spine')    # hanging weather bead


def _head_crest_paul(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'blue_light', 'Head')
    b.box((0,-.115,1.740), (.03,.03,.02), 'sky', 'Head')


def _chest_motif_sam(b):
    # GR..: small chequered board with one piece — her card's garden chess
    # table. Fix round: the original 3x3 grid of small squares did not
    # resolve into a board at lineup distance, and the centred standing
    # piece lined up exactly with the shared neck/waist trim every resident
    # carries, so the whole read as a vertical stripe rather than a board
    # with a piece on it. This pass uses a 2x2 grid of larger squares (still
    # ivory/ink checkered, so the alternation still reads) so the pattern
    # resolves at distance; sets the squares forward of a wider, set-back
    # wood_dark frame so the board has a legible rectangular edge before the
    # checkering itself resolves; and shrinks the standing piece and moves
    # it off the centreline onto one square, so it no longer lines up with
    # the trim above and below. orange_dark — Sam's identity colour — stays
    # on the piece.
    b.box((0,-.150,1.025), (.22,.020,.22), 'wood_dark', 'Spine')  # board frame, set back
    for x, z, color in (
        (-.045,1.070,'ivory'), (.045,1.070,'ink'),
        (-.045,0.980,'ink'), (.045,0.980,'ivory'),
    ):
        b.box((x,-.175,z), (.09,.025,.09), color, 'Spine')        # 2x2 checker squares, proud of the frame
    b.box((.045,-.205,1.1425), (.032,.028,.055), 'orange_dark', 'Spine')  # standing piece, off-centre, on the ink square


def _head_crest_sam(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'orange_dark', 'Head')
    b.box((0,-.115,1.740), (.035,.035,.02), 'ivory', 'Head')


def _chest_motif_casey(b):
    # GR..: rack of resource tokens — her card's resource-token cabinet. A
    # dark 'ink' shadow-box gives value contrast, a 'steel' frame (the rack)
    # reads as a distinct mid-grey ring around it, and two rows of three
    # tokens in three different bright hues (not a two-colour alternation,
    # so it cannot collapse into a checker/cross silhouette at distance) sit
    # forward of the frame with gaps between them.
    b.box((0,-.150,1.06), (.34,.020,.28), 'ink', 'Spine')          # shadow-box back
    b.box((0,-.175,1.17), (.30,.020,.020), 'steel', 'Spine')       # frame top rail
    b.box((0,-.175,.95), (.30,.020,.020), 'steel', 'Spine')        # frame bottom rail
    b.box((-.15,-.175,1.06), (.020,.020,.24), 'steel', 'Spine')    # frame left rail
    b.box((.15,-.175,1.06), (.020,.020,.24), 'steel', 'Spine')     # frame right rail
    for x, color in ((-.09,'orange'),(0,'cobalt'),(.09,'mint')):
        b.box((x,-.215,1.12), (.05,.035,.05), color, 'Spine')      # token row 1
    for x, color in ((-.09,'mint'),(0,'orange'),(.09,'cobalt')):
        b.box((x,-.215,1.00), (.05,.035,.05), color, 'Spine')      # token row 2


def _head_crest_casey(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'steel', 'Head')
    b.box((0,-.115,1.740), (.03,.03,.02), 'orange', 'Head')


def _chest_motif_ollie(b):
    # GR..: looping marble-run track with a travelling bead — his card's
    # marble-run laboratory. First pass filled the whole loop's interior
    # with a solid wood_honey plate the same footprint as the coral rails,
    # so it read as a plain picture frame, not a track (a real finding,
    # caught by looking at the render before commit). This pass removes
    # that fill — the dark 'ink' ground now shows straight through the
    # loop's open middle — and adds a second, smaller wood_honey loop
    # nested asymmetrically toward the upper-right of the main coral loop,
    # so the shape reads as two connected loops (a run, not a frame) rather
    # than a single symmetric rectangle. The 'sky' marble sits proud on the
    # main loop's top rail, large enough to read as a ball riding the track.
    b.box((0,-.150,1.06), (.32,.020,.26), 'ink', 'Spine')           # shadow-box back — stays open behind the loops
    b.box((0,-.205,1.15), (.22,.025,.025), 'coral', 'Spine')        # outer loop top rail
    b.box((0,-.205,.97), (.22,.025,.025), 'coral', 'Spine')         # outer loop bottom rail
    b.box((-.11,-.205,1.06), (.025,.025,.20), 'coral', 'Spine')     # outer loop left rail
    b.box((.11,-.205,1.06), (.025,.025,.20), 'coral', 'Spine')      # outer loop right rail
    b.box((.05,-.215,1.065), (.10,.025,.02), 'wood_honey', 'Spine')  # inner loop top rail
    b.box((.05,-.215,.975), (.10,.025,.02), 'wood_honey', 'Spine')   # inner loop bottom rail
    b.box((0,-.215,1.02), (.02,.025,.09), 'wood_honey', 'Spine')     # inner loop left rail
    b.box((.10,-.215,1.02), (.02,.025,.09), 'wood_honey', 'Spine')   # inner loop right rail
    b.box((-.06,-.235,1.15), (.05,.05,.05), 'sky', 'Spine')          # travelling marble, on the outer top rail


def _head_crest_ollie(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'coral', 'Head')
    b.box((0,-.115,1.740), (.03,.03,.02), 'wood_honey', 'Head')


def _chest_motif_theo(b):
    # GR..: puzzle-lock plate with tumblers — his card's puzzle-lock
    # display. A 'steel' back plate (mid-grey, so it separates from the
    # white shell even though the disc riding on it is near-black) carries
    # an 'ink' disc built from three stepped bands (an octagon
    # approximation, so its silhouette reads as round, not square) with
    # three 'led_green' tumbler pips proud around its edge and a small
    # 'steel' keyhole slot at the centre for close-range detail.
    b.box((0,-.155,1.06), (.30,.020,.26), 'steel', 'Spine')        # back plate
    b.box((0,-.19,1.13), (.14,.05,.06), 'ink', 'Spine')            # disc — top band
    b.box((0,-.19,1.05), (.19,.05,.09), 'ink', 'Spine')            # disc — middle band
    b.box((0,-.19,.965), (.14,.05,.06), 'ink', 'Spine')            # disc — bottom band
    b.box((0,-.22,1.155), (.025,.025,.025), 'led_green', 'Spine')  # tumbler — top
    b.box((-.075,-.22,.99), (.025,.025,.025), 'led_green', 'Spine')  # tumbler — lower-left
    b.box((.075,-.22,.99), (.025,.025,.025), 'led_green', 'Spine')   # tumbler — lower-right
    b.box((0,-.235,1.055), (.025,.02,.05), 'steel', 'Spine')       # keyhole slot


def _head_crest_theo(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'ink', 'Head')
    b.box((0,-.115,1.740), (.03,.03,.02), 'led_green', 'Head')


def _chest_motif_cody(b):
    # GR..: mended blocks with visible repair seams — his card's
    # repaired-object shelves. Three mismatched-size blocks in three
    # different woods/tones (so each reads as a separate object by value
    # even where they nearly touch) sit on a dark 'ink' ground; thin
    # 'leaf_light' seam strips bridge the small gaps between them and a
    # small patch on the centre block, all pulled proud of the blocks
    # themselves, plus two 'steel' rivets at the seam ends for close detail.
    b.box((0,-.150,1.06), (.34,.020,.26), 'ink', 'Spine')          # shadow-box back
    b.box((-.115,-.185,1.02), (.085,.05,.16), 'wood_dark', 'Spine')  # block 1
    b.box((0,-.205,1.065), (.10,.06,.22), 'sand', 'Spine')         # block 2 (mismatched, tallest)
    b.box((.115,-.19,1.03), (.08,.055,.18), 'cream', 'Spine')      # block 3
    b.box((-.058,-.225,1.05), (.014,.03,.20), 'leaf_light', 'Spine')  # seam 1-2
    b.box((.058,-.225,1.05), (.014,.03,.20), 'leaf_light', 'Spine')   # seam 2-3
    b.box((0,-.235,1.09), (.05,.02,.014), 'leaf_light', 'Spine')   # mend patch on block 2
    b.box((-.058,-.240,1.05), (.014,.014,.014), 'steel', 'Spine')  # rivet 1
    b.box((.058,-.240,1.05), (.014,.014,.014), 'steel', 'Spine')   # rivet 2


def _head_crest_cody(b):
    b.box((0,-.08,1.727), (.09,.10,.014), 'leaf_light', 'Head')
    b.box((0,-.115,1.740), (.03,.03,.02), 'wood_dark', 'Head')


# One entry per resident: display/rig name, GS registry id, source profile
# tag, the two accent colours that vary outside the motif/crest blocks, the
# review string, and the resident's own chest-motif/head-crest geometry
# functions. Adding a resident means adding one entry here plus its two
# geometry functions above; nothing else in create_character changes.
RESIDENTS = {
    'kai': {
        'mesh_name': 'GS030_CoderKai',
        'rig_name': 'KaiRig',
        'gs_id': 'GS-030 / GS-041 pilot subset',
        'source_profile': 'coder-kai',
        'head_accent': 'cobalt',
        'thigh_accent': 'cobalt',
        'review': 'Kai robot appearance approved by user 2026-09-22; movement extension subject to technical verification',
        'chest_motif': _chest_motif_kai,
        'head_crest': _head_crest_kai,
        'roster': 4,
    },
    'lyra': {
        'mesh_name': 'GS031_ArtisticLyra',
        'rig_name': 'LyraRig',
        'gs_id': 'GS-031 / GS-041 pilot subset',
        'source_profile': 'artistic-lyra',
        'head_accent': 'violet',
        'thigh_accent': 'teal',
        'review': 'Lyra robot appearance approved by user 2026-09-22; movement extension subject to technical verification',
        'chest_motif': _chest_motif_lyra,
        'head_crest': _head_crest_lyra,
        'roster': 5,
    },
    'onboarding-olivia': {
        'mesh_name': 'GS027_OnboardingOlivia',
        'rig_name': 'OliviaRig',
        'gs_id': 'GS-027 / GS-041 pilot subset',
        'source_profile': 'onboarding-olivia',
        'head_accent': 'mint',
        'thigh_accent': 'mint',
        'review': 'New Olivia appearance; operator review pending',
        'chest_motif': _chest_motif_olivia,
        'head_crest': _head_crest_olivia,
        'roster': 1,
    },
    'super-chotu': {
        'mesh_name': 'GS028_SuperChotu',
        'rig_name': 'ChotuRig',
        'gs_id': 'GS-028 / GS-041 pilot subset',
        'source_profile': 'super-chotu',
        'head_accent': 'orange',
        'thigh_accent': 'orange',
        'review': 'New Chotu appearance; operator review pending',
        'chest_motif': _chest_motif_chotu,
        'head_crest': _head_crest_chotu,
        'roster': 2,
    },
    'project-manager-pete': {
        'mesh_name': 'GS029_ProjectManagerPete',
        'rig_name': 'PeteRig',
        'gs_id': 'GS-029 / GS-041 pilot subset',
        'source_profile': 'project-manager-pete',
        'head_accent': 'navy',
        'thigh_accent': 'navy',
        'review': 'New Pete appearance; operator review pending',
        'chest_motif': _chest_motif_pete,
        'head_crest': _head_crest_pete,
        'roster': 3,
    },
    'research-ray': {
        'mesh_name': 'GS032_ResearchRay',
        'rig_name': 'RayRig',
        'gs_id': 'GS-032 / GS-041 pilot subset',
        'source_profile': 'research-ray',
        'head_accent': 'green',
        'thigh_accent': 'green',
        'review': 'New Ray appearance; operator review pending',
        'chest_motif': _chest_motif_ray,
        'head_crest': _head_crest_ray,
        'roster': 6,
    },
    'writer-quill': {
        'mesh_name': 'GS033_WriterQuill',
        'rig_name': 'QuillRig',
        'gs_id': 'GS-033 / GS-041 pilot subset',
        'source_profile': 'writer-quill',
        'head_accent': 'wood_honey',
        'thigh_accent': 'wood_honey',
        'review': 'New Quill appearance; operator review pending',
        'chest_motif': _chest_motif_quill,
        'head_crest': _head_crest_quill,
        'roster': 7,
    },
    'analyst-echo': {
        'mesh_name': 'GS034_AnalystEcho',
        'rig_name': 'EchoRig',
        'gs_id': 'GS-034 / GS-041 pilot subset',
        'source_profile': 'analyst-echo',
        'head_accent': 'teal',
        'thigh_accent': 'teal',
        'review': 'New Echo appearance; operator review pending',
        'chest_motif': _chest_motif_echo,
        'head_crest': _head_crest_echo,
        'roster': 8,
    },
    'predictor-paul': {
        'mesh_name': 'GS035_PredictorPaul',
        'rig_name': 'PaulRig',
        'gs_id': 'GS-035 / GS-041 pilot subset',
        'source_profile': 'predictor-paul',
        'head_accent': 'blue_light',
        'thigh_accent': 'blue_light',
        'review': 'New Paul appearance; operator review pending',
        'chest_motif': _chest_motif_paul,
        'head_crest': _head_crest_paul,
        'roster': 9,
    },
    'strategy-sam': {
        'mesh_name': 'GS036_StrategySam',
        'rig_name': 'SamRig',
        'gs_id': 'GS-036 / GS-041 pilot subset',
        'source_profile': 'strategy-sam',
        'head_accent': 'orange_dark',
        'thigh_accent': 'orange_dark',
        'review': 'New Sam appearance; operator review pending',
        'chest_motif': _chest_motif_sam,
        'head_crest': _head_crest_sam,
        'roster': 10,
    },
    'controller-casey': {
        'mesh_name': 'GS037_ControllerCasey',
        'rig_name': 'CaseyRig',
        'gs_id': 'GS-037 / GS-041 pilot subset',
        'source_profile': 'controller-casey',
        'head_accent': 'steel',
        'thigh_accent': 'steel',
        'review': 'New Casey appearance; operator review pending',
        'chest_motif': _chest_motif_casey,
        'head_crest': _head_crest_casey,
        'roster': 11,
    },
    'optimizer-ollie': {
        'mesh_name': 'GS038_OptimizerOllie',
        'rig_name': 'OllieRig',
        'gs_id': 'GS-038 / GS-041 pilot subset',
        'source_profile': 'optimizer-ollie',
        'head_accent': 'coral',
        'thigh_accent': 'coral',
        'review': 'New Ollie appearance; operator review pending',
        'chest_motif': _chest_motif_ollie,
        'head_crest': _head_crest_ollie,
        'roster': 12,
    },
    'threat-hunter-theo': {
        'mesh_name': 'GS039_ThreatHunterTheo',
        'rig_name': 'TheoRig',
        'gs_id': 'GS-039 / GS-041 pilot subset',
        'source_profile': 'threat-hunter-theo',
        'head_accent': 'led_green',
        'thigh_accent': 'led_green',
        'review': 'New Theo appearance; operator review pending',
        'chest_motif': _chest_motif_theo,
        'head_crest': _head_crest_theo,
        'roster': 13,
    },
    'cleaner-cody': {
        'mesh_name': 'GS040_CleanerCody',
        'rig_name': 'CodyRig',
        'gs_id': 'GS-040 / GS-041 pilot subset',
        'source_profile': 'cleaner-cody',
        'head_accent': 'leaf_light',
        'thigh_accent': 'leaf_light',
        'review': 'New Cody appearance; operator review pending',
        'chest_motif': _chest_motif_cody,
        'head_crest': _head_crest_cody,
        'roster': 14,
    },
}


def create_character(materials, profile='kai'):
    try:
        resident = RESIDENTS[profile]
    except KeyError:
        raise ValueError(f"Unknown resident profile: {profile!r}") from None
    b = Blocks(resident['mesh_name'], materials)
    b.box((0,0,.855), (.42,.26,.17), 'joint', 'Hips')
    b.box((0,0,1.075), (.47,.29,.30), 'shell', 'Spine')
    b.box((0,0,1.235), (.20,.20,.09), 'joint', 'Spine')
    b.box((0,-.12,1.227), (.28,.08,.065), 'orange', 'Spine')
    resident['chest_motif'](b)
    # Robot identity follows A1's design grammar, with Kai's own casing details.
    # A solid white enclosure, inset dark display, pixel chevrons and smile.
    b.box((0,0,1.50), (.48,.40,.44), 'shell', 'Head')
    b.box((0,-.208,1.50), (.404,.022,.344), 'display', 'Head')
    for eye_x in (-.105,.105):
        for step in range(-2,3):
            b.box((eye_x+step*.022,-.223,1.558-abs(step)*.023),
                  (.026,.012,.030), 'led_green', 'Head')
    for step in range(-2,3):
        b.box((step*.026,-.223,1.413+abs(step)*.012),
              (.030,.012,.026), 'led_green', 'Head')
    # Recessed side modules and cooling slots; no ears, hair, nose or skin.
    for side in (-1,1):
        b.box((side*.244,.02,1.50), (.025,.22,.24), 'steel', 'Head')
        b.box((side*.261,.02,1.50), (.014,.15,.16), resident['head_accent'], 'Head')
        for level in range(3):
            b.box((side*.270,.02,1.46+level*.04), (.008,.10,.012), 'joint', 'Head')
    resident['head_crest'](b)
    # Limbs use rigid weights: cubes stay cubes when joints turn.
    for side, suffix in ((-1,'L'),(1,'R')):
        x = side*.285
        b.box((x,0,1.12), (.16,.245,.17), 'shell', 'UpperArm.'+suffix)
        b.box((x,0,.987), (.13,.16,.14), 'joint', 'UpperArm.'+suffix)
        b.box((x,0,.816), (.125,.15,.24), 'shell', 'Forearm.'+suffix)
        b.box((x,-.013,.678), (.15,.18,.105), 'shell', 'Hand.'+suffix)
        b.box((x-side*.078,-.027,.692), (.048,.09,.07), 'joint', 'Hand.'+suffix)
        lx = side*.115
        b.box((lx,0,.660), (.185,.225,.34), 'shell', 'Thigh.'+suffix)
        b.box((lx,-.12,.605), (.13,.025,.12), resident['thigh_accent'], 'Thigh.'+suffix)
        b.box((lx,0,.310), (.165,.19,.32), 'shell', 'Shin.'+suffix)
        b.box((lx,-.005,.14), (.185,.205,.10), 'joint', 'Shin.'+suffix)
        b.box((lx,-.068,.074), (.19,.315,.112), 'ink', 'Foot.'+suffix)
        b.box((lx,-.068,.018), (.198,.326,.036), 'steel', 'Foot.'+suffix)
        b.box((lx,-.10,.134), (.12,.13,.016), 'shell', 'Foot.'+suffix)
    mesh = b.finish()
    armature = bpy.data.armatures.new('GuildVoxelSkeleton')
    rig = bpy.data.objects.new(resident['rig_name'], armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')

    def bone(name, head, tail, parent=None):
        item = armature.edit_bones.new(name)
        item.head, item.tail = head, tail
        if parent:
            item.parent = armature.edit_bones[parent]
        return item

    bone('Root',(0,0,0),(0,0,.12))
    bone('Hips',(0,0,.83),(0,0,.96),'Root')
    bone('Spine',(0,0,.96),(0,0,1.23),'Hips')
    bone('Head',(0,0,1.27),(0,0,1.69),'Spine')
    for side,suffix in ((-1,'L'),(1,'R')):
        x = side*.285
        bone('UpperArm.'+suffix,(x,0,1.2),(x,0,.93),'Spine')
        bone('Forearm.'+suffix,(x,0,.93),(x,0,.72),'UpperArm.'+suffix)
        bone('Hand.'+suffix,(x,0,.72),(x,0,.64),'Forearm.'+suffix)
        x = side*.115
        bone('Thigh.'+suffix,(x,0,.83),(x,0,.49),'Hips')
        bone('Shin.'+suffix,(x,0,.49),(x,0,.11),'Thigh.'+suffix)
        bone('Foot.'+suffix,(x,0,.11),(x,-.18,.11),'Shin.'+suffix)
    bpy.ops.object.mode_set(mode='OBJECT')
    # Blender expects the modifier's rig to parent the source mesh. The export
    # removes this redundant armature object, leaving the skin at scene root.
    mesh.parent = rig
    modifier = mesh.modifiers.new('Rigid voxel skin','ARMATURE')
    modifier.object = rig
    rig['gs_id'] = resident['gs_id']
    rig['source_profile'] = resident['source_profile']
    rig['style'] = '02-voxel'
    rig['revision'] = 'pilot-r004-full-cast'
    rig['review'] = resident['review']
    rig.select_set(False)
    animate(rig)
    return rig, mesh


def animate(rig):
    rig.animation_data_create()
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = 'XYZ'
    clips = {'idle':96, 'walk':32, 'seated_idle':96, 'typing':48, 'attend':96, 'sit_down':32, 'stand_up':32}
    for name,duration in clips.items():
        shared = bpy.data.actions.get(name)
        if shared is not None:
            track = rig.animation_data.nla_tracks.new()
            track.name = name
            strip = track.strips.new(name,1,shared)
            strip.name = name
            track.mute = True
            continue
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        for frame in range(1,duration+2):
            phase = (frame-1)/duration * 2*math.pi
            for pb in rig.pose.bones:
                pb.location = (0,0,0)
                pb.rotation_euler = (0,0,0)
            seated = name in ('seated_idle','typing','attend')
            if seated:
                # Hips underside meets .48 m seat. Knees drop .05 m relative
                # to the hip pivot so the unchanged shin length grounds soles.
                rig.pose.bones['Root'].location.y = -.29
                for side in ('L','R'):
                    thigh_angle = -math.pi/2 + math.asin(.05/.34)
                    rig.pose.bones['Thigh.'+side].rotation_euler.x = thigh_angle
                    rig.pose.bones['Shin.'+side].rotation_euler.x = -thigh_angle
                    rig.pose.bones['UpperArm.'+side].rotation_euler.x = -.80
                    rig.pose.bones['Forearm.'+side].rotation_euler.x = -.40
                # Raise hands from lap to keyboard in the work fixture.
                if name == 'typing':
                    for index,side in enumerate(('L','R')):
                        rig.pose.bones['UpperArm.'+side].rotation_euler.x = -1.60
                        rig.pose.bones['Forearm.'+side].rotation_euler.x = -.015 + .012*math.sin(phase*4+index*math.pi)
                        rig.pose.bones['Hand.'+side].rotation_euler.x = 0
            if name in ('sit_down','stand_up'):
                t = (frame-1)/duration
                t = t*t*(3-2*t)
                seated_fraction = t if name=='sit_down' else 1-t
                angle = (-math.pi/2 + math.asin(.05/.34))*seated_fraction
                # Root movement exactly compensates the knee arc: both feet
                # stay on the floor at fixed world positions during transfer.
                rig.pose.bones['Root'].location.y = -.34*(1-math.cos(angle))
                rig.pose.bones['Root'].location.z = math.sqrt(.34**2-.05**2)+.34*math.sin(angle)
                for side in ('L','R'):
                    rig.pose.bones['Thigh.'+side].rotation_euler.x = angle
                    rig.pose.bones['Shin.'+side].rotation_euler.x = -angle
                    rig.pose.bones['UpperArm.'+side].rotation_euler.x = -.045 + (-.80+.045)*seated_fraction
                    rig.pose.bones['Forearm.'+side].rotation_euler.x = -.40*seated_fraction
            if name == 'walk':
                rig.pose.bones['Root'].location.y = -.03
                for side,offset in (('L',0),('R',.5)):
                    cycle = ((frame-1)/duration+offset)%1
                    if cycle < .5:
                        forward = .18 - .72*cycle
                        lift = 0
                    else:
                        swing = (cycle-.5)*2
                        forward = -.18*math.cos(math.pi*swing)
                        lift = .06*math.sin(math.pi*swing)
                    height = .69-lift
                    reach = math.hypot(forward,height)
                    direction = math.atan2(-forward,height)
                    thigh = direction-math.acos((.34**2+reach**2-.38**2)/(2*.34*reach))
                    shin = direction+math.acos((.38**2+reach**2-.34**2)/(2*.38*reach))
                    rig.pose.bones['Thigh.'+side].rotation_euler.x = thigh
                    rig.pose.bones['Shin.'+side].rotation_euler.x = shin-thigh
                    # Foot bone points forward and has an opposite local X axis.
                    rig.pose.bones['Foot.'+side].rotation_euler.x = shin
                    rig.pose.bones['UpperArm.'+side].rotation_euler.x = -.28*math.sin(phase+offset*2*math.pi)
            if name == 'idle':
                rig.pose.bones['Spine'].rotation_euler.x = .012*math.sin(phase)
                for side in ('L','R'):
                    rig.pose.bones['UpperArm.'+side].rotation_euler.x = -.045
            if name == 'attend':
                rig.pose.bones['Head'].rotation_euler.y = .28*math.sin(phase)
                rig.pose.bones['Head'].rotation_euler.x = .05*math.sin(phase)
            elif name not in ('walk','sit_down','stand_up'):
                rig.pose.bones['Head'].rotation_euler.x = .014*math.sin(phase)
            for pb in rig.pose.bones:
                pb.keyframe_insert(data_path='location',frame=frame,group=pb.name)
                pb.keyframe_insert(data_path='rotation_euler',frame=frame,group=pb.name)
        for slot in action.slots:
            for layer in action.layers:
                for strip_data in layer.strips:
                    bag = strip_data.channelbag(slot)
                    if bag:
                        for curve in bag.fcurves:
                            for key in curve.keyframe_points: key.interpolation = 'LINEAR'
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name,1,action)
        strip.name = name
        track.mute = True
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location=(0,0,0); pb.rotation_euler=(0,0,0)
    return clips
