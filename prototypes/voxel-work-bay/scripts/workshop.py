"""Original modular furniture and a bounded workshop backdrop."""
import random
from geometry import Blocks, anchor, label


def furniture(materials):
    desk = Blocks('GS019_Desk', materials)
    desk.box((0,0,.73), (1.8,.8,.10), 'wood_light')
    for x in (-.78,.78):
        for y in (-.28,.28):
            desk.box((x,y,.345), (.09,.09,.69), 'navy')
            desk.box((x,y,.035), (.12,.12,.07), 'metal')
        desk.box((x,0,.19), (.07,.62,.07), 'metal')
    desk.box((0,.30,.61), (1.6,.055,.14), 'wood')
    # Thin planked tabletop, inset drawers, readable joinery.
    for x in (-.6,-.3,0,.3,.6):
        desk.box((x,0,.780), (.012,.78,.004), 'wood_honey')
    desk.box((-.59,.05,.59), (.42,.59,.16), 'wood_honey')
    desk.box((-.59,-.253,.59), (.18,.03,.035), 'navy')
    # Notebook and mug are decorative parts of the pilot desk package.
    desk.box((.60,-.10,.806), (.22,.29,.045), 'orange_dark')
    desk.box((.60,-.10,.832), (.195,.27,.009), 'paper')
    desk.box((.57,-.06,.843), (.018,.19,.012), 'cobalt')
    desk.box((-.70,.19,.845), (.10,.10,.13), 'ivory')
    desk.box((-.70,.19,.913), (.075,.075,.007), 'wood_dark')
    desk.box((-.77,.19,.85), (.045,.035,.07), 'ivory')
    d = desk.finish()
    d['gs_id'] = 'GS-019'; d['revision'] = 'pilot-r001'
    anchor('terminal_mount', (0,-.12,.78), d)
    anchor('chair_approach', (0,.65,0), d)

    chair = Blocks('GS018_Chair', materials)
    chair.box((0,0,.425), (.53,.51,.07), 'wood')
    chair.box((0,0,.468), (.49,.46,.024), 'cobalt')
    for x in (-.205,.205):
        for y in (-.18,.18):
            chair.box((x,y,.195), (.065,.065,.39), 'wood_dark')
        chair.box((x,.23,.68), (.075,.07,.59), 'wood')
    chair.box((0,.23,.92), (.50,.08,.12), 'wood_light')
    chair.box((0,.23,.77), (.48,.07,.10), 'wood_honey')
    c = chair.finish()
    c['gs_id'] = 'GS-018'; c['revision'] = 'pilot-r001'
    anchor('seat_anchor', (0,0,.48), c)

    terminal = Blocks('GS022_Terminal', materials)
    terminal.box((0,0,.025), (.28,.22,.05), 'metal')
    terminal.box((0,0,.15), (.07,.07,.24), 'steel')
    terminal.box((0,0,.38), (.60,.08,.38), 'navy')
    terminal.box((0,.047,.38), (.548,.016,.322), 'screen')
    terminal.box((0,.058,.247), (.06,.008,.016), 'orange')
    # Pixel terminal: decorative status blocks, not real text or private logs.
    for row, width in enumerate((.34,.25,.39,.29,.20)):
        terminal.box((-.22+width/2,.060,.49-row*.047), (width,.008,.012), 'mint' if row%2==0 else 'blue_light')
        terminal.box((-.24,.061,.49-row*.047), (.014,.009,.014), 'orange')
    terminal.box((0,.27,.021), (.51,.185,.042), 'steel')
    for col in range(10):
        for row in range(3):
            terminal.box((-.224+col*.049,.216+row*.044,.047), (.038,.030,.012), 'ivory' if col!=9 else 'orange')
    terminal.box((0,.343,.047), (.22,.025,.012), 'ivory')
    terminal.box((.36,.26,.03), (.09,.14,.06), 'navy')
    t = terminal.finish()
    t['gs_id'] = 'GS-022'; t['revision'] = 'pilot-r001'
    anchor('keyboard_anchor', (0,.27,.05), t)
    return {'desk': [d, *d.children], 'chair': [c, *c.children], 'terminal': [t, *t.children]}


def environment(materials):
    b = Blocks('WorkshopBackdrop', materials)
    rng = random.Random(22)
    b.box((0,0,-.18), (8,6,.24), 'sand')
    b.box((0,0,-.065), (7.9,5.9,.07), 'cream')
    for x in range(16):
        for y in range(6):
            b.box((-3.75+x*.5,-2.5+y,-.015), (.485,.985,.030), rng.choice(('wood_light','wood_honey','wood_light')))
    # Edge tiles define the crop without implying a complete district.
    for x in range(20):
        b.box((-3.8+x*.4,-2.85,.035), (.39,.29,.07), 'ivory')
    b.box((0,2.78,1.50), (7.8,.16,3.0), 'cream')
    b.box((-3.78,1.0,1.5), (.16,3.55,3), 'cream')
    b.box((0,2.65,.30), (7.8,.14,.60), 'cobalt')
    b.box((-3.65,1.0,.30), (.14,3.55,.60), 'cobalt')
    for x in (-3.60,-1.20,1.20,3.60):
        b.box((x,2.58,1.55), (.16,.24,3.10), 'wood_honey')
    b.box((0,2.57,3.0), (7.55,.27,.20), 'wood_light')
    for x in (-3.55,-1.2,1.2,3.55):
        b.box((x,1.0,3.06), (.14,3.35,.18), 'wood_honey')
    # A broad stepped window in the back wall, flat sky treatment.
    b.box((1.3,2.64,1.92), (3.4,.14,1.65), 'wood_dark')
    b.box((1.3,2.545,1.92), (3.22,.035,1.46), 'sky')
    for x in (-.30,.77,1.84,2.91):
        b.box((x,2.505,1.92), (.055,.06,1.5), 'ivory')
    b.box((1.3,2.50,1.95), (3.25,.06,.055), 'ivory')
    b.box((1.3,2.42,1.10), (3.55,.36,.10), 'wood_light')
    # Shelf on the left wall: orange bins and spare components.
    for z in (.75,1.40,2.05):
        b.box((-3.40,1.0,z), (.62,2.65,.08), 'wood_dark')
    for y in (-.23,2.23):
        b.box((-3.41,y,1.13), (.10,.10,2.26), 'navy')
    for y in (-.05,.6,1.25,1.9):
        for z in (.94,1.59):
            b.box((-3.36,y,z), (.40,.43,.30), 'orange' if y<1 else 'cobalt')
            b.box((-3.145,y,z+.02), (.014,.16,.045), 'paper')
    # Pegboard, peg holes and three simple tools.
    b.box((-2.42,2.52,1.58), (1.20,.06,1.12), 'wood')
    for col in range(8):
        for row in range(7):
            b.box((-2.93+col*.145,2.483,1.13+row*.145), (.022,.01,.022), 'wood_dark')
    for x, h in ((-2.80,.42),(-2.45,.32),(-2.1,.44)):
        b.box((x,2.445,1.55), (.055,.075,h), 'orange')
        b.box((x,2.435,1.55+h/2), (.14,.08,.09), 'steel')
    # Small canopy plants, each assembled from contiguous stepped masses.
    for x,y,scale in ((3.12,1.93,1.0),(-2.96,-1.56,.78),(2.9,-1.25,.62)):
        b.box((x,y,.23), (.46,.46,.46), 'cream')
        b.box((x,y,.47), (.49,.49,.08), 'wood_dark')
        b.box((x,y,.76*scale+.36), (.13,.13,.58*scale), 'wood')
        for dx,dy,dz,size in ((0,0,.98,.58),(-.25,0,.87,.4),(.23,.05,1.1,.4),(0,.22,1.24,.38),(.05,-.23,1.20,.38)):
            b.box((x+dx*scale,y+dy*scale,.3+dz*scale), (size*scale,)*3, rng.choice(('green','leaf','leaf_light')))
    # Low side rail and display blocks keep the space framed, front stays open.
    for y in (-1.4,-.1,1.2,2.5):
        b.box((3.70,y,.46), (.12,.12,.92), 'navy')
    b.box((3.70,.55,.94), (.16,4.05,.10), 'wood_light')
    obj = b.finish()
    obj['scope'] = 'One workshop work-bay crop; not the complete W1 hall'
    signs = [label('GUILD / 04', (-2.40,2.435,2.35), .21, materials['navy'])]
    return [obj, *signs]
