# The six styles

Written by `tools/build_jobs.py` from `data/styles.json`. These are the words every prompt uses for each style. They were written on 2026-10-02 from the selected concept sheets and from colours measured in them; edit `data/styles.json` and rebuild if a description is wrong.

## Low-poly tropical (`lowpoly_tropical`)

Concept sheets: [style study 11-low-poly-tropical-diorama](../style-studies/styles/11-low-poly-tropical-diorama/README.md).

- **Medium:** stylised low-poly 3D game model, seen as a clean render: flat faceted planes on foliage, rocks, hair and cloth; buildings and furniture as smooth painted volumes with crisp chamfered edges; matte surfaces, no outlines.
- **Surfaces:** flat painted colour on each face with a soft gradient from light to shade; timber shows a few broad plank lines, stone a few large blocks, foliage is clumps of flat facets in three or four tones; no photographic texture, no noise.
- **A flat sample of a surface:** flat painted colour with soft gradients and a few broad lines; no photographic texture and no noise.
- **Light on a design sheet:** soft even daylight from the upper left, as in a product render: every surface readable, gentle shading, no coloured light, no hard cast shadows.
- **Light in a scene:** warm late-morning tropical sun from the upper left, soft-edged shadows, clear blue sky with a few faceted white clouds.
- **Avoid:** smooth realistic foliage, photographic textures, ink outlines, glossy plastic.
- **People:** low-poly people with faceted hair and clothes and smoothly shaded faces, in green, yellow, white and terracotta everyday clothes, some with straw sun hats.
- **The agent:** City Agent A1 is a white and yellow robot with a rounded head, a dark glass visor showing two cyan eyes, yellow ear pieces, a black neck and black joints, and a green leaf badge on the chest.

| Material | How this style draws it |
| --- | --- |
| timber | chunky warm-brown timber in broad boards |
| metal | matte charcoal iron in simple square sections |
| stone | pale warm stone in a few large blocks |
| wall | cream limewash with sandstone trim |
| roof | terracotta tiles drawn as broad ridged planes |
| glass | dark teal glass in simple panes |
| paving | warm cream square slabs, each a slightly different tone |
| foliage | clumps of flat leaf facets, olive in shade and yellow-green in light, with a few pale blossoms |
| trunk | warm mid-brown trunk in a few long facets |
| lamp | warm yellow lantern glass |
| accent | jackfruit yellow, with coral red on the tram |
| wall workshop | an orange-brown timber and steel frame with dark glass between the posts |
| wall library | cream limewash with sandstone trim |
| roof library | green copper sheet with a few raised seams |
| path | a sand-coloured compacted path with a few larger pavers |
| street | plain warm-grey asphalt |
| lawn | soft yellow-green grass in broad flat patches of two tones |
| water | teal water with a few lighter flat facets |

| Colours of | As measured in, or read from, the concept sheets |
| --- | --- |
| architecture | limewash cream and sandstone walls, terracotta roofs, green copper domes |
| timber | warm mid-brown timber, #613E2B in shade to #C78860 in light |
| metal | charcoal iron, #2C282B to #4A4548 |
| stone | pale warm stone, #817572 in shade to #E7CEB4 in light |
| foliage | olive to yellow-green leaves (#233019, #586C27, #939B2D, #C5C44A) with pale and pink blossoms |
| trunk | warm brown bark, #45311F to #B38E62 |
| ground | warm cream paving, soft yellow-green lawn, warm grey street |
| water | teal water |
| light | warm yellow lantern light |
| accent | jackfruit yellow for awnings, banners and umbrellas |
| tram | a cream body with a coral-red stripe |
| people | green, yellow, white and terracotta clothes |

## Voxel (`voxel`)

Concept sheets: [style study 02-voxel](../style-studies/styles/02-voxel/README.md).

- **Medium:** voxel 3D game model, seen as a clean render: forms built from cubes on one grid, with stepped edges where a curve would be; only the largest roofs (the workshop's sawtooth, the library's vault) are drawn smooth; no outlines.
- **Surfaces:** one flat saturated colour on each cube, with a slight tone difference from cube to cube and soft shading where cubes meet; no painted texture inside a cube face.
- **A flat sample of a surface:** a grid of square cube faces, each one flat colour, with slight tone differences from cube to cube.
- **Light on a design sheet:** bright even daylight from the upper left, soft shading between cubes, no coloured light, no hard cast shadows.
- **Light in a scene:** bright midday sun, clear blue sky with white cube clouds, short soft shadows.
- **Avoid:** smooth or rounded surfaces, diagonal slopes, textures inside cube faces, ink outlines, tiny noisy cubes.
- **People:** blocky people with square heads, cube hair and simple dot eyes, in blue, orange, green and white clothes.
- **The agent:** City Agent A1 is a white box-headed robot whose black screen face shows a green pixel smile and eyes, with dark ear panels, black hands and feet, and a green and white chequered torso; its leaf badge sits on a white chest plate.

| Material | How this style draws it |
| --- | --- |
| timber | orange-brown timber cubes |
| metal | dark grey cubes |
| stone | grey stone cubes in two tones |
| wall | flat-coloured cube walls with a grey stone base course |
| roof | flat parapet roofs, some with roof gardens or blue roof panels |
| glass | cobalt-blue glass cubes with a lighter mullion grid |
| paving | large light-grey square tiles, each a slightly different tone |
| foliage | green cubes in three tones, a few set proud of the mass, with white blossom cubes |
| trunk | brown cubes, two to three wide for a large tree |
| lamp | one warm glowing cube inside a dark frame |
| accent | orange, cobalt and emerald |
| wall workshop | bright yellow cubes on a grey stone base course |
| wall library | orange cubes with white trim cubes |
| roof library | an orange vault with white rounded end caps |
| path | light tan square tiles |
| street | plain dark grey asphalt cubes |
| lawn | bright green lawn tiles in two tones |
| water | saturated blue water with lighter square glints |

| Colours of | As measured in, or read from, the concept sheets |
| --- | --- |
| architecture | a bright yellow workshop, an orange library vault, white and cobalt-glass towers, grey stone base courses |
| timber | orange-brown timber, #643511 in shade to #F7A544 in light |
| metal | dark grey, #2E2F35 to #434249 |
| stone | grey stone, #635E64 to #9F979A |
| foliage | saturated greens (#18330B, #448114, #69A715, #A1D026) with white blossom cubes |
| trunk | brown, #40250B to #98612A |
| ground | light grey paving tiles, bright green lawn, dark grey street |
| water | saturated blue water |
| light | a warm yellow glow |
| accent | orange, cobalt and emerald |
| tram | a white body with an orange-red stripe |
| people | blue, orange, green and white clothes |

## Cel-shaded anime (`anime_cel`)

Concept sheets: [style study 06-anime](../style-studies/styles/06-anime/README.md).

- **Medium:** cel-shaded anime background art, drawn as a clean toon-shaded 3D game model: flat colour fills, two steps of cool lavender-grey shadow, thin dark ink lines on silhouettes and main edges.
- **Surfaces:** flat fills with a hard-edged shadow step and small painted highlights; brick, planks and paving joints drawn as a few thin lines; foliage as layered clusters of small leaf shapes.
- **A flat sample of a surface:** flat colour fills with one hard-edged darker tone and a few thin ink lines.
- **Light on a design sheet:** clear even daylight from the upper left; each surface keeps one flat colour, with a single darker step only on the faces turned away from the light; no shadow shapes or streaks painted across a flat face, no coloured light, no long cast shadows.
- **Light in a scene:** vivid clear daylight with crisp cel shadows and cumulus clouds in a blue sky.
- **Avoid:** photorealism, soft airbrushed gradients, heavy black outlines, chibi proportions, lens flare.
- **People:** anime characters in everyday summer clothes with thin ink outlines and simple cel shading.
- **The agent:** City Agent A1 is a young woman with navy-blue hair tied in a loose bun, a white work jacket over a blue shirt, and a blue leaf badge.

| Material | How this style draws it |
| --- | --- |
| timber | broad timber planks from dark brown to honey |
| metal | near-black iron in slim bars |
| stone | grey stone with a few joint lines |
| wall | red brick with thin mortar lines, or pale concrete |
| roof | red-brown roof slopes like the brick, each with one long blue-grey skylight |
| glass | blue glass in dark slim frames |
| paving | pale beige stone slabs with thin joints |
| foliage | layered clusters of small leaves, yellow-green in light and deep green in shade |
| trunk | grey-brown trunk with a clear shadow side |
| lamp | warm cream lantern glass in a black frame |
| accent | indigo and vermilion, with coral red on the tram |
| wall workshop | red brick with thin pale mortar lines |
| wall library | pale stone panels with thin joints |
| roof library | silver standing-seam metal curving over the vault |
| path | a pale gravel path |
| street | blue-grey asphalt |
| lawn | fresh green grass with small tufts drawn as short strokes |
| water | deep blue water with white sparkle strokes |

| Colours of | As measured in, or read from, the concept sheets |
| --- | --- |
| architecture | red brick, red-brown workshop roofs with long blue-grey skylights, silver metal on the library's vault, pale concrete and blue glass, warm white render |
| timber | timber from #3F312A in shade to #EABE8E in light |
| metal | near-black iron, #25242B to #6E696C |
| stone | grey stone, #5D5C61 to #A29493 |
| foliage | deep green to yellow-green leaves (#3A4634, #757C49, #A9A550, #D0C870) with white and pink flowers |
| trunk | grey-brown bark, #423934 to #8E7C66 |
| ground | pale beige paving, fresh green lawn, blue-grey street |
| water | deep blue water with white sparkles |
| light | warm cream lamp light |
| accent | indigo and vermilion |
| tram | a cream body with a coral-red stripe |
| people | white, navy, red and khaki summer clothes |

## Solarpunk retro-futurism (`solarpunk`)

Concept sheets: [style study 09-solarpunk](../style-studies/styles/09-solarpunk/README.md).

- **Medium:** optimistic solarpunk design, drawn as a clean stylised 3D game model: rounded ceramic forms, slatted blonde timber, brass trim and blue solar glass, softly shaded, no outlines.
- **Surfaces:** smooth matte ceramic, timber with a fine straight grain, brushed brass, blue solar panels with a visible cell grid; planting in soft clumps of small leaves; gentle painted shading, not photographic.
- **A flat sample of a surface:** a softly painted surface with fine, even grain; not photographic.
- **Light on a design sheet:** soft even warm daylight from the upper left, as in a product render: every surface readable, no golden-hour glow, no bloom, no hard cast shadows.
- **Light in a scene:** warm low golden sun with soft bloom on foliage, long gentle shadows and a pale blue sky.
- **Avoid:** photorealism, heavy machinery, rust and grime, dystopian detail, ink outlines.
- **People:** people in loose everyday linen and cotton clothes in natural colours, softly shaded.
- **The agent:** City Agent A1 is a cream-white rounded robot with brass joints and a brass coil neck, black hands, a dark glass face showing two cyan smiling eyes, a round brass-rimmed ear lens, a teal scarf, and a green leaf name tag hanging at the chest.

| Material | How this style draws it |
| --- | --- |
| timber | blonde timber slats with solid timber ends |
| metal | brushed brass trim with dark slim steel |
| stone | cream ceramic or pale stone with rounded corners |
| wall | cream ceramic panels or blonde timber slat cladding |
| roof | blue solar panels in a pale frame, or a planted roof |
| glass | clear turquoise-tinted glass in slim frames |
| paving | warm sandstone slabs |
| foliage | soft clumps of small olive and khaki leaves with pink, white and purple flowers |
| trunk | pale brown trunk with smooth bark |
| lamp | warm glass lantern with a brass cap |
| accent | jade green and coral, with red on the tram |
| wall workshop | blonde vertical timber slats |
| wall library | cream ceramic panels with fine joints |
| roof library | blue solar glass in a pale grid |
| path | warm sandy gravel |
| street | pale grey asphalt |
| lawn | soft olive-green grass and ground cover |
| water | clear blue water with gentle ripples |

| Colours of | As measured in, or read from, the concept sheets |
| --- | --- |
| architecture | cream ceramic, blonde timber slats, blue solar panels, brass trim, planted roofs |
| timber | timber from #70482E in shade to #FACC97 in light |
| metal | brushed brass, with dark slim steel |
| stone | cream ceramic and pale stone |
| foliage | olive and khaki leaves (#342F14, #6A6A29, #979139, #C5BE5C) with pink, white and purple flowers |
| trunk | pale brown bark, #372617 to #B88F62 |
| ground | warm sandstone paving, soft olive lawn, pale grey street |
| water | clear blue water |
| light | warm lantern light |
| accent | jade green and coral |
| tram | a white body with a red stripe and black door frames |
| people | natural linen, cream, olive and rust clothes |

## Neon noir (`neon_noir`)

Concept sheets: [style study 10-neon-noir](../style-studies/styles/10-neon-noir/README.md).

- **Medium:** neon noir city design, drawn as a clean stylised 3D game model: dark charcoal and navy forms with slim lines of built-in light, softly shaded, no outlines.
- **Surfaces:** matte dark metal and concrete, dark timber with a faint grain, glass that glows from behind, thin strips of warm or coloured light set into edges; wet stone only where a scene asks for it.
- **A flat sample of a surface:** a matte dark surface with faint grain and a slight sheen.
- **Light on a design sheet:** neutral soft studio light from the upper left so that the true surface colours read, with the object's own lamps and light strips switched on and glowing; no night scene, no rain, no coloured light on the backdrop.
- **Light in a scene:** night after rain: deep blue sky, warm amber light from windows, lamps and strings of small lights, thin magenta and cyan neon accents, reflections on wet dark paving.
- **Avoid:** daylight scenes, dirt and decay, weapons, dystopian signage, heavy fog, lens flare over the object, photorealism, photographic materials and lighting.
- **People:** people in dark everyday jackets and scarves with approachable faces, softly lit.
- **The agent:** City Agent A1 is a robot with a glossy black visor under a silver-white cranium plate, one cyan ring light at the ear and a cyan bar on the cheek, white armour plates, and a dark hooded jacket; its leaf badge is on a white card on a lanyard.

| Material | How this style draws it |
| --- | --- |
| timber | dark timber slats on dark metal |
| metal | matte charcoal steel in slim sections |
| stone | dark concrete with a thin warm light strip set into its edge |
| wall | charcoal steel frames with tall glazing that glows amber |
| roof | dark navy panels |
| glass | glass glowing amber from inside, or dark blue glass |
| paving | dark stone slabs |
| foliage | dark olive leaves and violet flowers |
| trunk | dark brown trunk |
| lamp | a warm amber lantern or strip |
| accent | amber, with thin magenta and cyan lines |
| wall workshop | vertical ribbed cladding, tan to brown and lighter than the dark steel frame round it |
| wall library | pale smooth stone |
| roof library | dark blue glass in a fine grid |
| path | dark gravel |
| street | near-black asphalt |
| lawn | dark green grass |
| water | dark navy water with small ripples |

| Colours of | As measured in, or read from, the concept sheets |
| --- | --- |
| architecture | charcoal steel frames, ribbed cladding that reads tan to brown on the workshop's gables, dark navy roofs, pale stone on the library, glazing that glows amber (#FFB560) |
| timber | dark timber, #1B100D to #846058 |
| metal | matte charcoal and black |
| stone | dark concrete, #2F2322 to #5C4A45 |
| foliage | dark olive leaves with warm highlights (#171A12, #4A3D1F, #846127, #DAA854) and violet flowers |
| trunk | dark brown bark, #251303 to #52300D, warm where lit |
| ground | dark stone paving, dark green lawn, near-black street |
| water | dark navy water |
| light | warm amber light (#FFB560), with thin violet-magenta (about #B030C0) and cyan (#3FE3FF) lines |
| accent | amber, magenta and cyan light |
| tram | a white and silver body with a red lower band |
| people | dark jackets in charcoal, navy and mustard |

## Pixel art (`pixel_art`)

Concept sheets: [style study 08-pixel-art](../style-studies/styles/08-pixel-art/README.md).

- **Medium:** detailed 16-bit-era pixel art game sprite: hard-edged square pixels on one consistent grid, a small fixed palette, dark navy outlines, selective dithering, no anti-aliasing and no blur.
- **Surfaces:** flat pixel clusters in two or three tones for each material, with selective dithering between tones; bricks, planks and leaves drawn as small pixel patterns.
- **A flat sample of a surface:** hard-edged pixels on one grid in two or three tones with selective dithering, every pixel a square block about 5 canvas pixels wide.
- **Light on a design sheet:** the sprite's own fixed light from the upper left, with flat tone steps.
- **Light in a scene:** bright daylight pixel scene with a blue sky and pixel clouds; at night, navy shadows with amber lamps and windows.
- **Avoid:** anti-aliasing, blur, gradients, mixed pixel sizes, 3D render look, more than about forty colours.
- **People:** small pixel characters with clear silhouettes and simple faces.
- **The agent:** City Agent A1 is a person with white hair tipped in blue, a dark jacket with a round blue and white patch on the shoulder, a blue scarf, and a leaf emblem on the backpack and on a lanyard card.

| Material | How this style draws it |
| --- | --- |
| timber | brown plank pixels in two tones with dark gaps |
| metal | dark navy and black frame pixels |
| stone | grey stone blocks with lighter top faces |
| wall | red brick, or sand-coloured stone, in a small pixel pattern |
| roof | dark slate-blue roofs |
| glass | pale blue windows by day, amber when lit |
| paving | beige and pink paving bricks |
| foliage | clustered leaf pixels in three greens with a few flower pixels |
| trunk | brown trunk with a darker shadow side |
| lamp | amber lantern pixels in a black frame |
| accent | red, royal blue and yellow |
| wall workshop | red brick in a small pixel pattern |
| wall library | sand-coloured stone blocks |
| roof library | slate-blue dome tiles |
| path | beige path tiles |
| street | grey-blue asphalt |
| lawn | bright green grass with small darker tufts |
| water | blue water with lighter ripple pixels |

| Colours of | As measured in, or read from, the concept sheets |
| --- | --- |
| architecture | brick #7A3028 #A84834 #C86E50, sand stone #DEC496 #F0E0BE, slate-blue roofs #303A6E, windows #A0C8E1 |
| timber | wood #5C3A28 #8A5A3B |
| metal | dark #2E2B2A and outline navy #181C30 |
| stone | stone #AAA096 #CDC6BC and grey #787882 |
| foliage | leaf #285C34 #3E8C3E #78BE50, with one darker teal-green for deep shade and one yellow-green for highlights |
| trunk | wood #5C3A28 #8A5A3B |
| ground | sand #DEC496 #F0E0BE paving, the leaf greens for lawn, grey #787882 street |
| water | water #1E4678 #326EAA #78B4DC |
| light | lamp #FFD26E #FFF0BE |
| accent | red #C83C3C, royal blue #0251A4, yellow #F2B632, purple #825ABE |
| tram | red #C83C3C and cream #F4F1EA |
| people | skin tones, with red, blue, yellow and purple clothes |
