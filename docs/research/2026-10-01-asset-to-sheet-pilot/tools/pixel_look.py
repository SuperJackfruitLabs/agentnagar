"""pixel_look.py: the pixel sheet's tree beside the kit's sprite, round 1's and round 2's, three times size."""
from PIL import Image
import os
W = os.path.dirname(os.path.abspath(__file__))
R = os.environ['AGENTNAGAR'] + '/city/godot/styles/pixel_art/assets'
c = Image.open(f'{W}/inputs/pixel_art-banyan.png').convert('RGB')
S = 4
tiles = [c.resize((c.width * 560 // c.height, 560), Image.NEAREST)]
for p in (f'{R}/scenery/tree_square.png', f'{W}/out/pixel_art/scenery/tree_square.png', f'{W}/out2/pixel_art/scenery/tree_square.png'):
    im = Image.open(p).convert('RGBA')
    bg = Image.new('RGBA', im.size, (222, 196, 150, 255)); bg.alpha_composite(im)
    tiles.append(bg.convert('RGB').resize((im.width * 3, im.height * 3), Image.NEAREST))
h = max(t.height for t in tiles)
s = Image.new('RGB', (sum(t.width for t in tiles) + 30, h), 'white'); x = 0
for t in tiles:
    s.paste(t, (x, 0)); x += t.width + 10
s.save(f'{W}/previews/pixel-sprites.png'); print(s.size)
