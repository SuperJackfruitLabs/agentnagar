"""Turns a generated model (a dense textured GLB from the image-to-3D model) into a game piece that takes the
place of a kit piece: turned and sized, cut down to a triangle count, with its colour (and, unless told not
to, its fine relief) baked into its own textures, its colours matched to the design image the model was
generated from, and the parts the game lights put in place.

    blender --background --factory-startup --python-exit-code 1 --python fit_generated.py -- \
        RAW.glb OUT.glb [--kit KIT.glb | --size X,Y,Z | --tree W,D,BED,CROWN,HEIGHT] [options]

Prints one line beginning FIT with the numbers, and writes them to --report.

Size and place
--kit KIT.glb  the kit piece it replaces: its bounding box gives the size and the origin, its shape from above
               gives which way round the new piece stands (the quarter turn whose height map agrees best with
               the kit piece's), and its root node gives the name.
--size X,Y,Z   with no kit piece: the box to fill, metres, as width,height,depth (glTF axes), standing on the
               ground and centred.
--keep-aspect  scale evenly (to the box's width) and stand it on the ground, instead of filling the box on each
               axis. --aspect-by width|depth|height names the side of the box the even scale is taken from
               (default width): a lamp post is scaled to its height, and is then as wide as it was drawn.
--axis         a post (a lamp post, a bollard) the game stands on a point unscaled: its own axis, not the middle
               of its box, goes on the middle of the box (the origin, with --size). The axis is the median of
               the middles of its slices over the lower half of its height, so an arm, a banner or a lantern
               that reaches to one side does not move the post off its point.
--arm-at-x     a post with an arm (a lamp's banner arm): turned by quarter turns so that what reaches furthest
               from its axis in its upper half points to +x, where the kit's low-poly lamp carries its banner
               (the game turns the lamp's -z to the street, so the banner hangs along the street). A post that
               reaches alike all round is not turned.
--hang-above R,Z[,FROM]  with --axis: nothing further than R metres from the axis may hang lower than Z metres
               (the collision audit reads what a lamp draws up to 1.9 m above the ground under it, and a banner
               there reaches over the cells people walk on). What lies out there above FROM metres (default 1)
               is drawn up towards its own top until its lowest point is at Z: a banner keeps its shape and
               loses some of its length.
--panel        a fence panel the game lays end to end as instances of one mesh (a railing): turned so that its
               long side lies along x with its own post (the taller of the two ends that stand on the ground)
               at -x; the post drawn at the far end is cut off where it begins and the rails are closed there,
               because the next panel's post stands in that place; the cut-down piece is then set to run from
               exactly -1 to +1 of the box's width and to lie alike on both sides of z = 0 where people walk
               (0.15 to 2.2 m up: the game sets a fence off the floor by that half depth). Where the post's
               foot or cap is wider than its shaft, the rails are carried through the post to the piece's -x
               end (unless --panel-no-stubs), as the kits' rails run: the next panel's rails end on that
               plane, and would otherwise stop short of the shaft. Use with --keep-aspect and a box (--size).
               Sized evenly by its length a panel can come out taller than its kit's spec allows (the box's
               height and a tenth, and 2 cm): its height alone is then brought down to that.
--panel-post OUT.glb  with --panel: the panel's own post alone as a second file (the kit's `railing_post`, which
               the game stands at a fence's ends unturned): the outer half of the panel's post and its mirror
               image, so it is the same from both sides along the run and carries no rail, centred on the
               origin, with the panel's textures. Its root is named after the file. --panel-post-tris N cuts
               that file down to N triangles where its kit's limit is lower than what the panel's post has.
--yaw DEG      turn it by this instead of choosing the quarter turn.
--name NODE    the root node's name (default: the kit piece's).
--seat         with --kit: the piece is a seat. The top of its seat (where rays dropped on its middle mostly
               land) is moved to the height of the kit piece's, by scaling what is below it and what is above
               it separately: the game seats a figure at one height whatever the piece.
--tree W,D,BED,CROWN,HEIGHT  a tree standing in a raised bed, sized part by part instead of to a box: the bed
               to W by D metres and BED metres high, the crown to CROWN metres across, the whole to HEIGHT. A
               generated tree's bed is as large against its crown as the image drew it, and the game's is not.
               The bed's top, the trunk's narrowest height and the crown's start are read off the model's width
               at each height. The crown is then raised until what lies outside the bed is above --clear metres
               (default 2.45): the game shrinks a piece that draws anything outside its footprint between 0.15
               and 2.2 m up.
--planted CROWN,HEIGHT  a tree or palm the game plants by the hundred (a street tree, a palm), which it draws as
               copies of the file's first mesh and does not fit to a box: it turns each copy about the
               piece's origin, and scales its width by 0.25 m over the trunk's reach (the farthest point from
               the origin, between 0.15 and 2.2 m up, of everything whose material is not named as leaf). So
               the piece is sized evenly to CROWN metres across and HEIGHT metres tall and stood with its
               trunk's foot on the origin; after the cut its trunk is set upright over the origin up to 2.6 m
               (what is above keeps its lean), given a foot that reaches exactly --reach metres (default
               0.25), and drawn in to that reach wherever wood stands further out below 2.6 m; and the piece
               is written as one mesh with two materials, --wood-material (default `trunk`) and
               --leaf-material (default `leaf`: the game tells leaf from trunk by that name), sharing its
               textures. Use it with --parts.
--planted-box X,Z  with --planted: the kit's spec gives the piece's width and depth apart, and its test holds each
               within a tenth; a crown is never quite round. The model is turned a quarter where that puts its
               longer side along the spec's longer side, and sized so that both are equally near (the CROWN of
               --planted is then not used). The game turns every copy by any angle, so the turn shows nowhere.
--planted-clear M  with --planted: the fork is raised to M metres (a street tree drawn with a low fork: the stem
               below the fork is stretched to M and what is above pressed into what is left of the height),
               so that between 0.15 and 2.2 m there is one stem and nothing else. The fork is where the piece
               first is nearly twice its trunk's width.
--planted-leaf-from M  with --planted: leaf faces lying wholly below M metres are taken out. The generator can
               leave a patch of the drawn ground or shadow at a tree's foot that the leaf rules take for leaf (and
               the blossom rule then paints pale): the solarpunk small street tree had one on every copy, 26
               triangles up to 0.17 m.
--far N        with --planted: also write OUT's far twin (<name>_far.glb beside it, root <name>_far), the same
               piece cut to N triangles with its textures a quarter the size: the game draws a planted piece's
               far twin beyond 90 m wherever the twin's file sits beside it (build.py places it where the kit has
               twins of its own: neon, anime, solarpunk; far_swap.py in any style).
--kit-body-box with --kit: the kit's box is taken over its body alone, without its `light` and `lights` parts. A
               neon table's candle stands on its top and its umbrella's bulbs hang outside its canopy: counted
               in, they make the new piece 6 cm taller and 3 cm wider than the kit's body.
--stem         with --kit or --size: the piece is a top on a stem on a foot (a pedestal table, an umbrella), and
               is sized part by part instead of filling the box on each axis. The three are read off the model's
               width at each height (the stem is the longest run of slices no wider than 2.2 times the
               narrowest, a knuckle or handle of a few slices bridged). The whole is scaled evenly until the top is as wide as the box, so the top keeps its
               thickness or pitch and the foot its shape, as drawn; then the stem alone is stretched or pressed
               until the whole is as high as the box. It is placed with the stem's axis on the origin, not its
               box's middle (the game stands an umbrella by its origin, and puts its pole through a table's
               middle), and the top is moved onto that axis when it is off it by less than 3% of its width.
               Without a stem to be found the box is filled as usual and the report says `stem: null`.
--stem-edge M  with --stem: the top's lowest point beyond 0.5 m from the axis (a canopy's edge) is at least M
               metres up. The stem is lengthened until it is, and the piece is then taller than the box.
--stem-foot M[,ACROSS]  with --stem: the foot is at most M metres high (pressed, if the even scale leaves it
               higher) and, with ACROSS, at most that many metres across (drawn in about the axis). An
               umbrella's weighted base stands under its table: low and narrow enough, the table's feet pass
               over it; as drawn, they pass through it.
--stem-grid G  with --stem, for a style built from cubes of G metres: the foot and the top are each made a whole
               number of cubes high (pressed or stretched by up to half a cube, one cube at least), and what
               --stem-edge adds to the stem is a whole number of cubes, so that with a box a whole number of
               cubes high every level between foot, stem and top lies on the grid. The piece is also scaled
               to the box's width and to its depth each, by its top's own two widths, not evenly.
--stem-across M[,UPTO]  with --stem: the stem is at most M metres across: each slice of it wider than that is
               drawn in about the axis. With UPTO only below that height (metres), over 3 cm: an umbrella's pole
               thinned where a table's column has to hide it, and left as drawn above the table's top.
--top-sharp DEG  with --stem: in the top, edges sharper than DEG degrees are kept sharp (elsewhere, and without
               this, 40). A canopy's gores meet at about 20 degrees; smoothed over, they shade as blotches.
--feet-off-x   with --stem: the piece is turned (by any angle, after the quarter turn) so that its feet point
               as far from the x axis as they can: a café table's two chairs stand on its x sides, and a foot
               pointing along x lies where a sitter's feet and shins are. The feet are read off the foot's
               reach at each angle (its strongest harmonic from 2 to 6); a round foot is left as it is.
--feet-on-x    with --stem: the other way: turned so that one foot, or one corner of a square base, points along
               x. A table's feet point between the axes; an umbrella's square base under it, turned so, lies
               between them with its corners clear of their ends.
--planter W,D,RIM  a planting box, planted full, sized part by part instead of to a box: the box itself (the
               run of slices from the ground that keep the ground slice's outline) to W by D metres and its rim
               to RIM metres up (`keep`: as high as the model's own proportions make it); what stands above the
               rim (the plants) is scaled evenly with the box's width and then drawn in until nothing of it
               reaches past the box's outline less --planter-inset (default 0.03 m). The game fits whatever a
               filled piece draws between 0.15 and 2.2 m up to its footprint: plants overhanging the rim would
               be fitted in the box's place and the box drawn that much smaller. Placed with the box's middle
               on the origin.
--planter-tiers STEP  with --planter: the box is found through the steps of a plinth or a coping. Its rim is
               then the highest level at which the model has a broad surface looking up just inside its
               outline, not the end of the run of slices that keep the ground slice's outline (which stops at a
               plinth's step, a centimetre up, and leaves the box itself to be taken for plants). The box is
               the tier that holds the rim and it is sized to W by D; a run of heights whose outline differs
               from the next by STEP metres or more (as built) is a tier of its own. With --planter-parts the
               box is built plain, tier by tier, each tier a copy of the body's own outline read from the model
               as a convex polygon, so rounded corners stay rounded; a tier wider than the body that reaches
               0.14 m up or higher is held to the body's outline, because the game fits whatever stands widest
               in its walking band to the footprint.
--drop-below F drop loose parts smaller than this share of the whole surface (default 0.002; 0 keeps them all,
               which a tree needs: its leaf clumps are loose parts).
--object shortest|tallest|largest|smallest  the generated model holds more than one object (the cut-out held
               its neighbour whole: the solarpunk bollard came with the catenary pole beside it). Its loose
               parts are gathered into objects (parts whose outlines from above overlap are one object) and one
               object is kept: the shortest, the tallest, or the one with the most or the least surface.
--drop-plate   the generator can stand an object on a plate of its own making (the voxel bollard came on a
               slab a metre square, of one piece with it). Where the model's lowest slices are more than
               twice as wide as it is higher up, they are cut off, the object is closed underneath and stands
               on the ground.
--keep-strays  keep loose parts whose middle lies outside the largest part's box. Without it (and without
               --tree or --planted) they are dropped: they are what the generator made of the swatches and neighbours in
               the image.
--mesh-name NODE  the name of the piece's mesh part (default `body`; a kit's spec names the tram shelter's `shelter`).
--save-sized OUT.glb  also write the generated model as it stands after sizing, before it is cut down (to look at
               what a zone-by-zone sizing did).

A shelter (a canopy on posts over a bench), sized zone by zone
--shelter X0,Z0,X1,Z1  with --kit: the piece is a shelter, open to its front (-z), with a screen across its -x end and
               a bench against its back. X0,Z0,X1,Z1 is its kind's footprint box in the piece's own frame (glTF x
               and z, metres; the tram shelter's is -2.15,-0.40,2.15,0.75). The game stretches a shelter until what
               it draws between 0.15 and 2.2 m up fills that box, canopy and all, so filling the kit's whole box
               will not do: a design with posts under its canopy's front corners would be drawn half as deep.
               Instead:
               - what stands under the canopy (posts, back screen, end screen, bench) is sized so that its slice
                 between 0.15 and 2.2 m is exactly that box, the end structures --shelter-end metres thick
                 (default 0.15, the footprint's end screen);
               - the canopy and what hangs from it (lamps, roof beams) are sized to the kit piece's whole box
                 from front to back, and along the length as the posts are (a canopy drawn resting on its corner
                 posts stays on them). What hangs and what stands is read off the plan cell by cell, and each
                 post is cut under whatever hangs beside it, at its own height (a roof may slope);
               - a post standing in front of the back screen at the open (+x) end is taken out up to the canopy:
                 it would stand where people walk. The canopy is left hanging over the front, as the kit's does.
                 The post is what stands there ahead of the bench's front edge; where the bench is as deep as
                 the shelter (its edge no further back than the post), the post is taken from where it starts,
                 and where a panel runs from the screen to the post, everything in front of the screen goes;
               - heights fill the kit piece's height, with the bench's seat moved to the kit bench's (see
                 --shelter-bench). A roof that starts low: if anything of the canopy outside the footprint would
                 come out under 2.26 m (--shelter-set clear), in the band the game measures, the heights are
                 divided again so that it does not;
               - if the walk from the roof reaches the ground when the posts are cut one by one (a sign box whose
                 top lies between two posts, a rail that joins the roof to a post), the whole model is cut at
                 one height instead: the one just under the roof's underside where the least is crossed. What
                 that leaves under the cut but joined to nothing on the ground, or lying where nothing stands
                 at mid height (a roof's low end, a lamp rail under the soffit), is the canopy's;
               - a screen that stands well forward of the back of the -x end structure (a sign box that runs
                 from behind the screen to the front posts) is parted from that structure and moved back to
                 the footprint's back strip, instead of crushing the structure's back half into the strip.
               Where two zones are sized differently the mesh is cut along a plane, parted, and both cut faces
               closed (the closing faces take the colours of the faces round them). The landmarks are read off
               the model (the canopy's underside, the end structures' inner faces, the back screen's front face,
               the bench's top and seat, the post to take out) and reported under `shelter`.
--shelter-bench X0,Z0,X1,Z1[,TOP]  the bench's rectangle in the footprint (the tram shelter's is
               -1.75,0.15,0.65,0.55): what stands between the end structures below the back screen's lower edge
               is the bench; it is parted from them and sized along the length to X0..X1, its seat's front edge
               put at Z0. TOP is the height its seat's top is moved to (default: the kit bench's, found by rays
               dropped inside that rectangle from 0.62 m).
--shelter-stub F  where the bench ran into an end structure, the stub of it left on that structure is pressed
               flat onto the face it stands on and takes that face's colour, as far as F of the model's length
               behind the structure's inner face (default 0.012: to the face of a screen set a little back
               between its posts).
--shelter-end W  how thick the end structures are made, metres (default 0.15).
--shelter-set KEY=VALUE[,KEY=VALUE]  landmarks to use instead of the ones read off the model, in the model's own
               units after it is turned (heights as shares of its height): slab (the canopy's underside), xa, xb
               (the inner faces of the -x and +x end structures), wall (the back screen's front face, y), bench
               (the bench's top), seat (its seat's top), behind (the face of a screen that stands behind the bench
               at the bench's own height, y), post (0: take no post out), cut (one height at which every post
               is parted from the canopy, where a rail that runs into a post just under the roof leaves no
               clean gap for the rule to find), screen (0: do not move a screen that stands forward of the end
               structure's back). And settings, not landmarks:
               floor (a share of the height, or `auto`): the sheet that lies on the ground under the model is
               taken out first. A design image cut out with its contact shadow gives that shadow as a thin dark
               slab a few centimetres up; `auto` finds its top;
               roof (metres): the piece is cut down from a copy whose canopy is rebuilt as a plain slab on plan
               cells of this size: what the canopy shows from above, what it shows from below, upright walls
               round its outline. For a soffit of slats, which comes out of the reduction crumpled (see
               --under-reach for its colours);
               clear (metres, default 2.26): the height everything of the canopy outside the footprint is kept above;
               height (metres): the piece's height, where it is not to be the kit piece's (a kit piece that
               carries a tall sign on its roof, which the design does not);
               feet (metres): what stands is pressed down below the top of the posts' feet so that the feet end
               at this height: feet wider than their posts that rise into the walking band (from 0.25 m)
               stand within 10 cm of the walkable cells beside the end structure;
               back (`front`): the screen's back is painted with the picture of its front, as if seen through,
               for a glass screen whose unseen back the generator closed with a dark slab.
--shelter-screen #HEX  what is colourless on the back screen's faces (those that look to the front or the back in
               the footprint's back strip, between the end structures, under the canopy) takes this colour: its
               mean takes it, its variation stays. For a screen the generator painted as dark as its frame.
--glass NAME,H0,H1,S0,S1,V0,V1  the faces the generator painted in this range of colour (hue in degrees, saturation
               and value 0 to 1) become a material of their own called NAME, with the piece's texture and the
               roughness --glass-rough (default 0.1). The game lights a material whose name begins `glass` at
               night; one material for the whole piece gets none. `front` after the range: only the faces that
               look to the front or the back (a screen's panes; a lit sign of the same colour that faces along
               the piece is not glass). --glass-colour #HEX: the glass takes this colour (its mean; its own
               variation stays), where the generator painted a pane another colour than the design's.
--lamp-faces auto|Z0,Z1[,#HEX]  the faces between these heights (metres) that look down are lamps: painted this
               colour (default #FFE9B8) and, with --glow, lit. `auto`, with --shelter: what hangs under the
               canopy. The generator paints a lamp's face a few bright specks; the design draws it lit.

A fountain (a round basin with a centre piece), with its water handled apart
--fountain R,RIM,HEIGHT  the piece is a fountain. Its basin's outer wall is made R metres from its axis (the game
               draws it unscaled on a disc of that radius, 1.5), its rim's top RIM metres up (0.45, where the
               game's perch seats meet it), the whole HEIGHT metres or `kit` (the kit piece's). The axis, the
               outer wall, the rim's top and inner edge and the water's level are read off the model (reported
               under `fountain`). Then:
               - the basin's wall and rim are built by rule: a ring of --fountain-sides (default 48) sides on
                 the footprint, exactly round, its top flat, coloured from the generated stone (the generated
                 wall is left out of the piece and kept as what the colours are baked from);
               - the water in the basin, with its splashes, is left out, and one flat disc is laid from wall to
                 wall at its level, in a part named `water` with a material `water` of its own: the colour
                 --water-colour, roughness --water-rough (default 0.05), no texture;
               - what the generator painted as water above the basin (--water) goes into the same part with the
                 piece's texture, as the material `water_drawn`: all of it with --fountain-falls keep (the
                 default), or with --fountain-falls drop only the still water lying in the bowls: the falling
                 sheets and the jet are taken out, and where they met stone or still water the hole is closed;
               - the centre piece stands as generated, scaled evenly above the rim.
--fountain-sides N  the sides of the basin's ring and of the water's disc (default 48).
--fountain-rim #HEX  the top of the basin's ring takes this colour (its middle colour; its variation stays): for a
               design that lays another stuff on the rim than the wall is made of (timber on a dark basin).
--fountain-wall top  the ring's walls are painted the middle colour of its top: for a basin generated as a ring of
               cubes, which has no round wall for the ring's colours to be baked from.
--fountain-level M  the water in the basin is put M metres up, and what stands in it is raised with it: the
               model's heights are divided at its water's level as well as at its rim. For a model whose
               basin is deeper than its design drew it.
--fountain-pool flat|painted  the disc in the basin: `flat` (the default), one colour, the material `water`; or
               `painted`, with the piece's texture, baked from the generated water under it (its deep colour
               and the rings of foam where the streams land), in the material `water_drawn` with the rest.
--fountain-falls keep|drop  see --fountain.
--water H0,H1,SAT,VALUE,WHITE  what the generator painted as water: hue between H0 and H1 degrees and either
               saturation above SAT or value above VALUE; or value above WHITE with almost no colour (foam).
               Default 165,255,0.4,0.75,0.85.
--water-colour #HEX  the colour of the flat water (the design sheet's water swatch). Default: the middle colour
               of what the design image paints as deep water.
--water-rough F  the roughness of both water materials (default 0.05; it is what makes it water).

The piece from above (with --kit): the game stretches what a filled piece draws between 0.15 and 2.2 m up onto
its kind's footprint, and its collision audit (city/godot/tools/collision_audit) then reads what the piece draws
between 0.25 and 1.9 m against the cells the grid blocks: a walkable cell's centre within 10 cm of it, or a
blocked cell's with nothing within 10 cm, fails the game's own test. The kit's box does not say this shape; these
do. They are applied in this order, on the generated model, before it is cut down, and the piece is then put
back on the kit's box. Which way the piece faces is read off the kit's piece (its tall part is its back).
--plan-pull SIDES  rear, front, left, right (any, with commas) or all: on that side, whatever stands out past
               the side's main edge is pressed onto it. The main edge is the middle value of how far the piece
               reaches, along the side, between 0.25 and 1.9 m. A bench's splayed back legs, or side frames
               longer than its back, otherwise set the box's back edge and leave the back rest short of it.
--plan-cols    every strip of the piece from side to side is made as deep as the piece: side frames that stop
               short of the back they hold are drawn out to its rear face. Done before --plan-rows, which then
               finds those corners filled.
--plan-rows    every row of the piece from front to back is made as wide as the piece: a back rest shorter than
               the frames it stands between is drawn out to their outer faces. For a piece whose footprint is
               a full rectangle (a bench); not for one whose footprint is not (an armchair).
--plan-notch HALF,SHARE  an armchair: between its arms (and at least HALF of the box's width either side of the
               middle) nothing reaches further forward than SHARE of the box's depth behind the arms' fronts:
               the seat's front is pressed back to there. The catalogue's reading chair is arms and a back
               round a seat square; the strip in front of the seat, between the arms, is floor a sitter
               steps on. The arms' inner faces are read off the model a little above the seat.

Planting (a shrub, a kerbed bed)
--shrub R|kit  with --kit or --size: a piece the game draws by the hundred as copies of its first mesh, each scaled
               across by its footprint's radius over the piece's reach (the farthest from its origin that it
               draws between 0.15 and 2.2 m up, vertices and the points where edges cross those heights:
               kit_town.gd band_reach). After the box is filled the origin is moved to the middle of the
               piece's outline from above, and the piece is scaled evenly across until its reach is R metres
               (`kit`: the kit piece's own reach), so the game draws it as large as it draws the kit's. The
               reach is held again on the cut-down piece. The height at which the piece is widest (its ring)
               is moved up to --ring-least metres (default 0.4, the top of the kits' drum) when it is lower,
               by scaling what is below it and what is above it separately: the collision audit reads a
               shrub's outline from 0.25 m above the ground drawn under it, on a shrub the game has squashed
               to as little as 0.85 of its height.
--round F      with --shrub: the outline from above is drawn towards a circle, which is what the collision
               audit holds a shrub to (the kits build theirs on a drum). In each direction the piece is
               scaled across so that the farthest it reaches at its ring's height goes F of the way (0 to 1)
               to the reach, no direction by more than --round-most (default 1.3); what then reaches past the
               circle at other heights comes back to it, and stands there as an upright side. Done on the
               generated model (72 directions) and finished after the bakes on the piece itself, where its
               own surface crosses the ring's height. With --skin and F = 1 the ring of the skin's corners
               lies on the circle exactly.
--leaves N,LENGTH,WIDTH[,CORE[,SPACE]]  with --skin and --shrub: a loose shrub. A skin alone makes a solid mound
               of it: the gaps between its branches are bridged and its outline is smooth. So the skin becomes
               the shrub's inside. Away from its ring it stands in the middle of the leaves (where the share
               CORE, default 0.5, of the model's corners in each direction lie nearer the axis; half that
               share straight up, where a loose shrub is a few sprays); at its ring it
               stays on the circle the game measures. It is the shade between the leaves: a middling leaf tone
               at its ring, where it stands as far out as they do, passing to the colour of the darkest fifth
               of them, and darker still the further from its ring and where it faces down (down to
               --core-dark of that). Under its ring it is held out to a straight line to its foot (--skin-tuck:
               the fan its stems make). On it stand up to N leaves, each a folded blade of two
               triangles about LENGTH by WIDTH metres, set where the generated model has a leaf outside that
               inside (no two nearer than SPACE, default half a LENGTH), lying as that leaf lies, its tip
               away from the foot of the shrub, in the colour the generator painted that leaf. More leaves
               (36 to 72, by their width) lie across the ring against the circle, side by side all the way
               round, so that the ring does not show as a bare rim, and one more is laid on the ring's shoulder
               in every direction where the model has no leaf over it. Nothing reaches outside the circle, and
               the shrub's reach stays its model's.
--leaves-under  with --leaves: a leaf under the ring that lies inside the inside is brought straight out to the
               inside's surface. For a shrub drawn as a ball: it tucks under itself, the inside is held out
               there so that the shrub stands on the ground (--skin-tuck), and without this its lower half
               is a bare inside. Not for a loose shrub, whose lower part is its stems.
--flowers M,SIZE,#HEX[,#HEX...]  with --leaves: the generated model's flowers put back as flowers, up to M of them.
               What the generator painted in the hue of one of the colours given (the design sheet's flower
               swatches; a pale swatch finds what is pale) is a flower where it lies together: a patch up to
               about SIZE metres in radius is one flower, where it is, as wide as it is and facing as it
               faces; a wider patch (a spray of blossoms) is several of that size. Each is five petals in the
               sheet's colour: a star of ten triangles, or five triangles when it is under 4.5 cm in radius.
--flower-centre  with --flowers: each flower gets a centre (three triangles) that keeps the colour the generator
               painted there (a yellow eye).
--leaf-swatches #HEX,#HEX[,...]  with --leaves: every leaf takes one of these colours (the sheet's leaf swatches),
               the nearest to the colour the match gave it. For a style painted in flat colours (low-poly).
--all-leaf     the whole piece is leaf (a shrub): --leaf-smooth and --leaf-round then work on all of it.
--bed KERB[,OVERHANG]  with --kit: a kerbed bed, which the game stretches until what it draws between 0.15 and
               2.2 m up fills its footprint, and whose kerb the collision audit reads between 0.25 and 1.9 m.
               It is sized by its kerb, not by its box: the kerb's top (the height, in the lower six tenths of
               the model, where most of what faces up lies) goes to KERB metres, the kerb's walls (the outermost
               place, on each side, where upright faces of the upper half of the kerb stand in number) to the
               sides of the kit piece's box, and
               what grows above the kerb to the rest of the box's height. Plants that reach more than
               OVERHANG metres (default 0) outside the kerb's walls are pulled in to that line, on the
               generated model and again on the cut-down piece. The piece is then cut down in two parts: the
               kerb as a plain box on the kit's sides (ten triangles, its stone and joints baked on from the
               generated kerb; --bed-colour sets its colour), and everything above the kerb or outside its
               walls as plants, with the rest of --tris (--max-tris when `auto`), rebuilt from cells of
               --remesh (default 0.012 m) after a swell of --inflate (0.004 m), bits smaller than --min-part
               (0.05 m) dropped. The plants are leaf for --leaf-smooth and --leaf-round.

Triangles
--tris N|auto  the triangle count, or `auto` (the default): the smallest of 1500, 2000, 3000, 4000, 6000, 9000,
               14000 (up to --max-tris, default 6000) at which 95% of the generated surface lies within 0.16%
               of the piece's diagonal of the cut-down surface, and all of it within 0.8%.
--within P95,MAX  with --tris auto: the two distances in millimetres instead of shares of the diagonal. A tall
               thin piece (a lamp post 4.2 m high with a ball 8 cm across on top) is not held by a share of
               its diagonal: at 0.16% of it the lamp's finial came out a crumpled spike.
--remesh V     rebuild the surface from V-metre cells before cutting it down. A generated tree's mesh has
               thousands of edges shared by three or more faces, which stop the triangle reduction; the rebuilt
               surface is closed and reduces cleanly (parts thinner than V are lost). Without it, a reduction
               that stalls (more than 1.15 times the triangles asked for) is done again from a rebuilt surface
               with cells 1/180 of the piece's diagonal; the report then has `rebuilt_because_stalled_m`.
--drop-hidden  a generated model is a shell: it has a second skin inside it, a centimetre or two under the
               first (a third to a half of the triangles and the texture of a piece cut down as generated are
               on that skin: of the anime bench's 1,499 triangles, 295 are loose parts inside it), and a
               rebuilt surface keeps the skin wherever some gap lets the rebuild see into the hollow. With
               this the piece is first cut to --drop-hidden-from triangles (default six times the count asked
               for, or the --planar count), then every face from which no ray leaves the piece (some ninety
               directions round its normal) is dropped, then it is cut to the count asked for. What is shut
               in behind a lantern's glass goes too. The distance the cut-down piece stands off the model is
               then measured from the corners left after the drop.
--inflate M    with --remesh: swell the surface by M metres first, so thin leaves survive the rebuild.
--min-part M   with --remesh: drop the rebuilt bits smaller than M metres across before the reduction.
--parts W,L,C[,B]  with --tree (and --glow-warm) or --planted: cut the tree down part by part, to W triangles
               of wood and bed, L of lanterns and C of leaves (see cut_parts and painted_class); --tris is then
               not used. With L = 0 nothing is looked for as a lantern (a warm yellow in the crown is leaf).
               With --planted the stem below the fork is not cut down at all: it is built again as a tube
               through the generated trunk's cross-sections (stem_tube), because a thin trunk rebuilt from
               cells comes back torn. What wood is above the fork is rebuilt from cells a fourteenth of the
               trunk's width (or --parts-wood-cell). With a
               fourth count the bed is cut down on its own to B triangles, without a rebuild. The cells each part is rebuilt
               from: --parts-wood-cell (0.05), --parts-lantern-cell (0.03), --parts-leaf-cell (0.12, after a
               swell of --parts-leaf-swell, 0.04). Lantern bits smaller than --parts-lantern-least (0.25 m) are
               dropped. --lantern-reach (0.35 m) is how far from its glass a lantern's frame is looked for.
--planar DEG   for a piece of flat-sided bars (a railing): the reduction leaves a flat face cut into more
               triangles than it needs, and the round parts short of them. The piece is first cut to
               --planar-from triangles (default three times the count asked for), then neighbouring faces that
               lie in one plane to within DEG degrees are joined and the corners left on straight edges taken
               out (Blender's planar reduction), then it is cut to the count asked for if it is still over it.
--skin N       instead of cutting the generated mesh down: a closed skin of N triangles is drawn over the model
               from outside (--tris is then not used). From a point on the piece's axis (with --shrub, at the
               height of its widest ring) the model is looked at along about N/2 evenly spread directions, and
               the skin's corner on each direction stands as far out as the model does there and close round it. For a
               shrub: a mass of thin leaves, which comes out as shards when cut down straight and with a wall
               inside it when rebuilt from cells. What the skin cannot keep is anything a straight line from the
               axis crosses twice (a gap between two branches is bridged). With --shrub 48 of the directions lie
               level, at the widest ring, and --round puts that ring of corners on the circle.
--skin-colour rays|nearest  with --skin: where the skin's colour texture comes from. `rays` (the default): the bake,
               its rays cast straight in towards the axis point the skin was drawn from (level under the ring),
               so the texture shows the model as it is seen from outside. `nearest`: each texel takes what lies
               close behind it looking straight in (within --skin-look metres, default 0.06: the leaves, and the
               darker ones in the small gaps between them), and where nothing lies that close, the colour of
               the nearest point of the generated model. For a shrub: where the skin bridges a gap between
               branches or is held out under the ring, a ray cast in brings back the dark inside of the model
               or the bare stems, and the texture comes out blotched.
--skin-wide F  with --skin: how far round each direction the model is looked at, as a share of the way to the
               neighbouring directions (default 0.75). Wider, the skin bridges more of the gaps between a
               loose shrub's branches and comes out as fewer, rounder masses.
--skin-tuck T  with --skin and --shrub: below its ring the skin stands no further in than a line that leaves the
               ring upright and reaches the ground T of the ring's radius in from it. A generated ball of leaves
               tucks far under itself to its stems; drawn twice as wide as it is built, as the game draws a
               shrub, that tuck becomes a saucer hovering over the lawn. Where the skin is held out like this
               it takes the colour of what lies behind it, the leaves under the ball.
--split        instead of --remesh: split the edges that three or more faces share and reduce the generator's
               own surface. Tried on both trees and not used: the crown came apart.
--bed-box      with --parts: the bed's walls and top are a plain box on the footprint (ten triangles), coloured
               from the generated bed; the generated walls are left out. For a bed that comes out ragged.
--planter-parts PLANTS[,BOX]  with --planter: cut the planter down part by part; --tris is then not used. The
               plants (what stands above the rim, and above the soil inside the walls) are rebuilt from cells of
               --planter-cell metres (0.02) after a swell of --planter-swell (0.008), bits smaller than
               --planter-least (0.12 m) dropped, and cut to PLANTS triangles: cut with the box, thin leaves come
               out as shards. The box is a plain one on the outline (outer walls, rim, inner walls, soil and a
               closed bottom: 28 triangles; the walls' thickness and the soil's depth are read off the model),
               painted from the generated box. With a second count the generated box itself is kept and cut to
               BOX triangles without a rebuild, its outer walls pressed flat onto the outline (tried for a box
               with rounded corners and a plinth: in the game its walls came out torn; --planter-tiers builds
               such a box plain). --planter-wall M gives the walls' thickness instead of reading it off the
               model (a style built from cubes wants a whole number of cubes). --planter-tones F: the plain
               box's stone (walls and rim) keeps the share F of its own variation about its middle colour (0:
               one flat colour), for a box whose blocks the match parts into light and dark patches; use it
               with --bed-colour, which gives the stone the design's colour.
--planter-fill SHARE,TURN[,SHARE,TURN]  with --planter-parts: before the cut, the generated model's plants are
               copied, drawn in to SHARE of their spread about the box's middle and turned TURN degrees,
               standing on the soil as they did; PLANTS triangles then cover plants and copies. The generator
               sees a planter from one side and plants its near edges, leaving the middle bare.
--flat         flat faces (a low-poly crown is meant to show its facets). Otherwise smooth, with edges sharper
               than 40 degrees kept sharp.
--square-normals DEG  the faces of the piece's main part that look within DEG degrees of an axis are shaded as
               if they looked exactly along it. For a piece of flat panes and square members (a shelter): cut
               down, its panes are a millimetre or two off flat and show their triangles when shaded smooth.
--own-normals  the piece's shading normals are made from its own faces. Without it the generated model's
               normals stay on the piece: Blender keeps them through the reduction, relative to faces that are
               no longer there, so they point anywhere (on the seats built before this option, half to nine
               tenths of the larger faces have a corner whose normal leans more than 20 degrees off its face;
               on the kits' pieces none to a fifth), and with them in place only a fraction of the edges
               sharper than 40 degrees are marked sharp (160 of 565 on the anime railing).
--weighted-normals  with --own-normals (which it implies): the smooth faces' shading normals are weighted by
               the faces' areas (Blender's weighted normals, sharp edges kept): a large flat face then shades
               flat although a small bevel beside it is smooth. Without it a cut-down box (a post's cap, a
               plinth) shows a dark wedge across each flat face, where its corners' normals lean towards the
               bevels: plain to see in a style that shades in two tones. Not with --flat.
--leaf-smooth  with --parts, --planter-parts, --all-leaf or --bed: no edge between two leaf faces is sharp, so
               the leaf masses shade as rounded forms. For a style that draws an ink line at every crease.
--leaf-round F with --parts, --all-leaf or --bed: the leaf faces' normals are turned F of the way (0 to 1) towards
               the direction out from the middle of the crown, so the crown takes the light as one rounded form.
--leaf-lift Z  with --leaf-round: the direction the leaf normals are turned towards leans upward by Z (0: straight
               out from the middle of the crown; 1: half way to straight up). The anime kit's own trees lean
               theirs up, so that a sun high in the sky finds most of the crown in light: with a toon step,
               leaves in shade are drawn at well under half their painted brightness.

Textures
--tex N        the textures' size (default 1024).
--uv seams|smart  the piece's own texture layout: seams along its sharp edges (the default), or Blender's
               smart projection (for a tree, and the default for a piece cut from a rebuilt surface, which
               has no sharp edges; --uv-angle, default 66, is its angle limit).
--no-normal    bake no relief map.
--bake-wood-reach M  with --parts: the wood's texels are baked a second time with a reach of M metres and take
               the place of the first bake's. A limb inside the crown otherwise reads the leaves round it.
--leaf-despeckle  with --parts: leaf texels much darker than the leaf round them (the bake read a dark face
               inside the generated model through an open leaf shell) take the colour of the leaf round them.
--bake-reach-most F  the bakes look for the generated surface within one and a half times the distance 95% of it
               lies from the cut-down piece, but no further than F of the piece's diagonal (default 0.02). A
               small tree whose leaves are rebuilt coarsely stands further off than that, and where the bake
               does not reach it reads the dark faces inside the generated model: specks.
--mend-tangents  a relief map needs a tangent at every corner, and the exporter writes a zero one where the
               corner's faces pull opposite ways in the texture (18 corners of the anime bench). The Khronos
               validator, which the kits' tests run, calls each an error. The zero ones are replaced in the
               written file by a unit vector square to the corner's normal: the relief there is then lit a
               little wrong instead of not at all.
--image-format F  the textures inside the file: AUTO (PNG, the default), WEBP or JPEG, at --image-quality (90).
--rough F      the material's roughness (default 0.85).
--save-bake    keep the colour texture as it was baked, before any matching (OUT.baked.png).
--under-reach Z,M  the faces that look down above Z metres are baked a second time with rays that reach M metres:
               for a soffit of slats rebuilt as one level face (--shelter-set roof), whose gaps would otherwise
               take the slats' colour instead of the dark behind them.
--bake-reach M how far from the piece's surface the bakes look for the generated one, metres. Default: one and a
               half times the 95% deviation, held between 1% and 2% of the piece's diagonal, which for a piece
               six metres long is 6 to 12 cm: far enough to find the wrong member of a frame (and, on a railing,
               2 to 5 cm: further than a rail is from the rail beside it).

Colours
The generator's metal map is always ignored: it marks whole pieces as metal, and a metal bakes black.
--design PNG   the cut-out of the design image (RGBA). The design's pixels are gathered into --materials colours
               (default 5); each texel goes to the nearest; one rising curve of lightness and one scale of
               colourfulness are fitted through the pairs (materials within three lightness steps of each other
               count as one); then a 3 by 3 median, and each texel is drawn towards its material's colour, its
               lightness by 0.4 x --flatten (default 0.5) and its hue by --flatten-hue (default: --flatten).
--tones-by-rank TOP  the lightness curve is fitted by rank, not material by material: the texture's darkest tones
               take the lightness of the design's darkest, and so on up (twelve ranks), and each rank is drawn
               three quarters of the way to the design's colour at that rank. The design is read over the upper
               TOP of its height only (1: all of it): the part the drawing's light falls on. For foliage, which
               is one material in many tones: the generator paints it in a narrow band of them, and matched by
               material the piece comes out one flat green.
--facet-colour  every triangle of the piece takes one colour, the mean of what the finished texture holds for it
               (a bed's kerb, a box of four-cornered faces, keeps its stone and joints). For a low-poly piece:
               its kit paints one flat colour a facet.
--lift F       multiply the lightness by F afterwards.
--kerb-tones UP,DOWN  with --bed-colour: nothing on the box's walls is more than UP lighter than that colour or DOWN
               darker (CIELAB lightness). For a kerb of one stone, whose joints should stay and whose painted
               edge light should not; not for a kerb of several materials (ceramic, timber and brass).
--bed-colour auto|#HEX  with --bed-box or --bed: the box's walls (and the rim on its top) take this colour, their own
               variation kept; `auto` reads it off the design image's lowest sixteenth, where the bed's near
               walls are. For a bed the generator painted the colour of the bark.
--leaf-colour #HEX[,#HEX]  what the generator painted as leaf is moved as a whole to this colour (its mean
               takes the colour; its variation stays). With two colours, the sheet's swatches for leaves in
               light and in shade, the mean goes between them, --leaf-blend of the way from the shaded one to
               the lit one (default 0.33). For a tree whose design
               image shows its leaves lit by its lamps, or whose leaves the match leaves too dark.
--leaf-ramp HEX,HEX[,...]  with --parts: the leaves take the sheet's own leaf swatches, from the darkest to the
               lightest, by how light the generator painted each texel (the 8th to the 92nd hundredth of the
               leaves' lightness run from the first swatch to the last; --leaf-ramp-from F, default 0.25,
               starts the run that far up it, because the game shades the leaves again). Pale texels with
               little colour (blossoms) keep the generator's colour. The match gathers a small tree's design
               into a few colours and can leave its lit leaves dark; the swatches are the sheet's own word.
--leaf-blossoms HEX[,HEX...]  with --leaf-ramp: the sheet's blossom swatches. A leaf texel the generator painted as
               a flower is not run along the leaf ramp but takes the blossom swatch nearest its own colour: a
               flower is a texel lighter than the middle leaf and plainly not leaf-coloured (reddish, pink or
               violet: its a in CIELAB above 8), or pale with little colour (lightness above 65, chroma under
               20). Without this a flowering tree comes out all leaf: a rebuilt crown keeps about 3% of its
               texels as flowers and the ramp turns them green. --leaf-blossoms-grow N draws each flower N texels
               wider (default 0), because the generator paints fewer and smaller flowers than the sheet.
--wood-ramp HEX,HEX[,...]  the same for the wood, with the sheet's bark swatches (--wood-ramp-from, default 0.2).
--wood-colour #HEX  with --parts: the texels of the faces that are wood (not leaf, not bed) take the generator's
               own colours moved as a whole to this colour, the sheet's bark swatch. For a small tree, whose
               trunk the match draws towards the leaf colours.
--paint H0,H1,SAT,#HEX  what the generator painted with a hue between H0 and H1 degrees and a saturation above SAT is
               moved as a whole to this colour (its mean takes the colour; its variation stays). For a stuff the
               generator paints too dull for the match to find: the timber of a fountain's column, with the
               sheet's timber swatch.
--lantern-colour #HEX  with --glow-warm: what the generator painted as a lantern takes this colour.
--glow-pale V,S  with --glow-warm: texels lighter than V and less saturated than S count as lantern glass too
               (a generator can paint a lit lantern pale). Only for a piece with nothing else pale on it; with
               --glass, what is glass is left out (a pale pane is matched to the design like the rest, and is not lit).
--pale-colour #HEX  with --glow-pale: those pale texels take this colour's hue and half its lightness (a sign's lit
               face the generator painted white where the design has cream).
--no-match     keep the generator's own colours, with --lift and --colourfulness (a scale, default 1), instead
               of matching the design. For a design image that is a night scene: its colours are light.

Lights
--glow NAME    the piece's material is called NAME and what glows on it emits light at --glow-strength (default
               2.0), in the colour of --glow-colour or its own. What glows: bright texels (lighter than 0.86 and
               saturated, or near white), or with
--glow-warm    only what the generator painted as a lantern or lamp: a strong warm yellow. --warm H0,H1,SAT,VALUE
               sets the rule (default 28,62,0.42,0.62: hue in degrees, least saturation, least value). Those
               texels also keep the generator's colour through the match, unless
--glow-matched they take the matched colour like the rest (a lit sign panel the generator painted orange
               where the design has cream).
--glow-part NAME  the glowing faces become a part of their own with this name (a kit tree's `lanterns`; a lamp
               post's `light`, at the middle of which the game hangs its lamp). Fewer than 12 glowing faces in
               all are not made a part: a stray texel or two is not a lantern.
--glow-part-least N  with --glow-part: only groups of N or more glowing faces that touch go into the part
               (default 1: every glowing face). A tree's lantern is such a group (8 is used for the trees); a
               face or two glowing alone there is a stray warm texel and stays in the body. A lamp's panes can
               be a few faces each, so the default takes them all.
--glow-from Z  only what lies Z metres up or higher glows (a lamp post's lantern, not a highlight the design
               painted on its post).
--glow-part-from Z  only the glowing faces Z metres up or higher go into the part (a neon lamp post is lit
               along its post and on its foot as well: all of that glows, and the lantern alone is the `light`
               the game hangs its lamp at).
--glow-light   a tiny part named `light` at the middle of what glows (or at --light-at X,Y,Z), which the game
               lights with a small lamp from dusk (KitTown.light_point reads a mesh, so it has to be one).
--kit-lights   copy the kit piece's own `light` and `lights` parts across (they sit in the same box).
               --kit-lights-as NAME renames them (`light` also gives each a small lamp).
--under-glow Z0,Z1,INSET  a thin lit slab under the piece, from Z0 to Z1 metres up and INSET of its outline in
               from each side (negative: out), named by --under-glow-as (default `lights`, which only glows;
               `light` also gets a small lamp from the game), its material named by --under-glow-material
               (default `lamp_glow`; it must not be a name the piece already uses). With --tree it runs round
               the bed, with --bed round the kerb (a lit strip in the kerb's wall: give it the strip's two
               heights and a small negative INSET, so that it stands a few millimetres proud of the stone).
--band-glow Z0,Z1[,OUT]  a lit band round the piece between the heights Z0 and Z1 (metres), following its
               outline there (the convex outline of what it draws between them) and standing OUT metres proud
               of it (default 0.003): the strip of light a night style's design draws round a table's rim or a
               base, which the generator does not reproduce. Named by --band-glow-as (default `lights`, which
               only glows), its material by --band-glow-material (default `lamp_glow`; not a name the piece
               already uses).
--fairy N,FROM[,SIZE]  N small lights scattered over the surface above FROM metres, as a night style's sheets
               string them through a crown. The generator does not reproduce small lights, so they are put back:
               each a four-sided solid SIZE metres across (default 0.18) at a random point of a random face (by
               area), 5 cm off it, in a part named `lights` with the material `fairy_glow`, as the kit's own
               trees carry them. The part's origin is --light-at (the game hangs the tree's lamp there).
--fairy-halo SIGMA,STRENGTH  with --fairy and --glow: the light those small lights throw on the faces round
               them, painted into the glow texture (each face by how near it is; SIGMA in metres).
--crown-fill SHARE,TURN[,SHARE,TURN]  with --parts: the crown's upper leaf masses are copied, drawn in to SHARE
               of their size about the crown's top and turned TURN degrees, to fill a crown that is open in the
               middle; a second pair makes a second, smaller copy for a crown that is a wide ring.
--core-plan SHEET.png,X0,Y0,X1,Y1  with --core: the mass is painted with the design sheet's view of the tree
               from straight above (the box, in the sheet's pixels), laid over it from above; what in that
               drawing is not leaf takes the leaves' shade. A generated crown is open or patchy on top.
--core S       with --tree: a dark mass inside the crown, S of its width, named by --core-name (default
               `canopy`), between --core-span of the crown's height (default 0.42,0.90), coloured as the leaves'
               shade times --core-dark (0.8), flat-faced unless --core-smooth. The generator models the crown
               as a shell of leaf clumps seen from one side; from the street and from above the sky and the
               ground show through it.
--empty NAMES  empty parts with these names (comma-separated) under the root.
--report JSON  where to write the numbers.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
raw, out = Path(argv[0]), Path(argv[1])


def opt(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


kit_path = opt("--kit")
tris_arg = opt("--tris", "auto")
max_tris = int(opt("--max-tris", "6000"))
tex = int(opt("--tex", "1024"))
design = opt("--design")
rough = float(opt("--rough", "0.85"))
forced_yaw = opt("--yaw")
name = opt("--name")
glow = opt("--glow")
drop_below = float(opt("--drop-below", "0.002"))
report = {}
LUM = np.array([0.2126, 0.7152, 0.0722])


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o not in before]


def world_verts(objs):
    pts = []
    for o in objs:
        if o.type != "MESH":
            continue
        m = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", m)
        m = m.reshape(-1, 3)
        w = np.array(o.matrix_world)
        pts.append(m @ w[:3, :3].T + w[:3, 3])
    return np.concatenate(pts) if pts else np.zeros((0, 3))


def tri_count(o):
    return int(sum(len(p.vertices) - 2 for p in o.data.polygons))


def height_map(pts, n=12):
    """What a piece looks like from above: the greatest height in each cell of an n by n grid over its own box,
    as a share of its height (0 where nothing stands)."""
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    span = np.maximum(hi - lo, 1e-6)
    ix = np.minimum(((pts[:, 0] - lo[0]) / span[0] * n).astype(int), n - 1)
    iy = np.minimum(((pts[:, 1] - lo[1]) / span[1] * n).astype(int), n - 1)
    grid = np.zeros((n, n))
    np.maximum.at(grid, (ix, iy), (pts[:, 2] - lo[2]) / span[2])
    return grid


def turned(pts, degrees):
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    out_pts = pts.copy()
    out_pts[:, 0] = pts[:, 0] * c - pts[:, 1] * s
    out_pts[:, 1] = pts[:, 0] * s + pts[:, 1] * c
    return out_pts


def only(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def seat_top_of(objs):
    """The height of a seat's top, as a sitter meets it (the same measure as seat_top.py): rays are dropped on
    the middle of the piece, and the height most of them land at, between a quarter and three quarters of
    the piece's height, is the seat. None when nothing is hit there."""
    verts, polys = [], []
    for o in objs:
        base = len(verts)
        verts += [o.matrix_world @ v.co for v in o.data.vertices]
        polys += [[base + i for i in poly.vertices] for poly in o.data.polygons]
    tree = BVHTree.FromPolygons([tuple(v) for v in verts], polys)
    xs, ys, zs = ([v[i] for v in verts] for i in range(3))
    x0, x1, y0, y1, top = min(xs), max(xs), min(ys), max(ys), max(zs)
    cx, cy, w, d = (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0
    hits = []
    for i in range(25):
        for j in range(25):
            hit = tree.ray_cast(Vector((cx + (i / 24 - 0.5) * 0.5 * w, cy + (j / 24 - 0.5) * 0.6 * d, top + 0.1)), Vector((0, 0, -1)))
            if hit[0] is not None and 0.25 * top <= hit[0].z <= 0.75 * top:
                hits.append(hit[0].z)
    if not hits:
        return None
    values, counts = np.unique(np.round(np.array(hits) / 0.01).astype(int), return_counts=True)
    return float(values[np.argmax(counts)] * 0.01)


def stem_zones(p, n=80):
    """A top on a stem on a foot (a pedestal table, an umbrella), read off the model's width at each height.
    The stem is the longest run of slices no wider than 2.2 times the narrowest slice of the lower nine tenths
    (so a column's collars and a pole's sleeve are stem, and a foot's arms and a canopy's stretchers are not);
    the foot is what lies below it and the top what lies above. Returns the two heights, the stem's axis, each
    slice's width, the top's width and middle; None when no run is a fifth of the height."""
    lo_, hi_ = p.min(axis=0), p.max(axis=0)
    h = float(hi_[2] - lo_[2])
    idx = np.minimum(((p[:, 2] - lo_[2]) / h * n).astype(int), n - 1)
    wide, mids = np.zeros(n), np.zeros((n, 2))
    for i in range(n):
        sl = p[idx == i]
        if len(sl):
            wide[i] = max(float(np.ptp(sl[:, 0])), float(np.ptp(sl[:, 1])))
            mids[i] = (sl[:, :2].min(axis=0) + sl[:, :2].max(axis=0)) / 2
        elif i:
            wide[i], mids[i] = wide[i - 1], mids[i - 1]
    lower = wide[1:int(0.9 * n)]
    thin = float(lower[lower > 0].min())
    is_stem = (wide > 0) & (wide <= 2.2 * thin)
    # A knuckle or a crank handle on a pole is a few slices wider than that: a gap of up to 6% of the height
    # between two runs of stem, itself no wider than six times the narrowest, is stem too.
    gap_from = None
    for i in range(1, n):
        if is_stem[i]:
            if gap_from is not None and i - gap_from <= max(2, int(0.06 * n)) and is_stem[gap_from - 1] and (wide[gap_from:i] <= 6 * thin).all():
                is_stem[gap_from:i] = True
            gap_from = None
        elif gap_from is None:
            gap_from = i
    best, start = (0, 0), None
    for i in range(1, n + 1):                    # not the ground slice: a stem stands on a foot
        if i < n and is_stem[i]:
            start = i if start is None else start
            continue
        if start is not None and i - start > best[1] - best[0]:
            best = (start, i)
        start = None
    a, b = best
    if b - a < 0.2 * n or b >= n:
        return None
    z_f, z_t = float(lo_[2] + a * h / n), float(lo_[2] + b * h / n)
    top = p[p[:, 2] >= z_t]
    return {"z_f": z_f, "z_t": z_t, "axis": mids[a:b].mean(axis=0), "wide": wide, "slices": (a, b), "n": n, "lo": float(lo_[2]), "height": h,
            "top_w": max(float(np.ptp(top[:, 0])), float(np.ptp(top[:, 1]))), "top_mid": (top[:, :2].min(axis=0) + top[:, :2].max(axis=0)) / 2}


def feet_turn(p, zone, on_x=False):
    """How far (degrees) to turn a piece on a stem so that its feet point as far from the x axis as they can
    (or, with on_x, so that one of them points along it). The foot's reach is taken at each of 72 angles round
    the stem's axis; its strongest harmonic from 2 to 6 says how many feet (or corners) it has and which way
    one points (a foot whose reach hardly varies is round: no turn). Among the turns that do it, the smallest
    is taken."""
    foot = p[p[:, 2] <= zone["z_f"]]
    d = foot[:, :2] - zone["axis"]
    r = np.hypot(d[:, 0], d[:, 1])
    far = r > 0.5 * r.max()
    bins = 72
    reach_at = np.zeros(bins)
    np.maximum.at(reach_at, ((np.arctan2(d[far, 1], d[far, 0]) + np.pi) / (2 * np.pi) * bins).astype(int) % bins, r[far])
    angles = -np.pi + (np.arange(bins) + 0.5) * 2 * np.pi / bins
    waves = {k: complex((reach_at * np.exp(-1j * k * angles)).sum()) / max(float(reach_at.sum()), 1e-9) for k in (2, 3, 4, 5, 6)}
    feet = max(waves, key=lambda k: abs(waves[k]))
    found = {"harmonics": {str(k): round(abs(v), 3) for k, v in waves.items()}}
    if abs(waves[feet]) < 0.05:                    # a square's corners make 0.076, a cross of arms 0.8, a disc next to nothing
        return 0.0, {**found, "feet": 0}
    points_at = -math.degrees(np.angle(waves[feet])) / feet          # one foot points this way

    def off_x(turn):
        each = [(points_at + turn + j * 360.0 / feet) % 180.0 for j in range(feet)]
        return min(min(a, 180.0 - a) for a in each)
    turns = np.arange(-180.0 / feet, 180.0 / feet, 0.5)
    if on_x:
        best = min(off_x(t) for t in turns)
        turn = min((t for t in turns if off_x(t) <= best + 0.26), key=abs)
    else:
        best = max(off_x(t) for t in turns)
        turn = min((t for t in turns if off_x(t) >= best - 0.26), key=abs)
    return float(turn), {**found, "feet": feet, "one_points_at_deg": round(points_at % 360, 1), "nearest_to_x_deg": round(off_x(turn), 1)}
def planter_through_steps(obj, p, step_share, n=120):
    """A planting box read through the steps of a plinth or a coping (--planter-tiers). The rim is the highest
    level at which the model has a broad surface that looks up just inside its outline: of the faces that look
    up between 0.4% and 5% of the width inside the outline of the model's lowest tenth, the area at each of n
    heights is taken, and the rim is the highest pair of heights holding at least half of what the fullest
    pair holds (a rim is a ring as wide as the wall; a plinth's ledge is narrower, a leaf smaller). Below it
    the heights are gathered into tiers: runs whose outline stays within `step_share` of the width. Returns the
    rim's height above the model's foot, the outline (x0, y0, x1, y1) of the tier that holds most of the box's
    height, and the tiers as (from, to, outline), all in the model's own units."""
    lo_, hi_ = p.min(axis=0), p.max(axis=0)
    h = float(hi_[2] - lo_[2])
    idx = np.minimum(((p[:, 2] - lo_[2]) / h * n).astype(int), n - 1)
    # Each slice's outline: its corners and, because a flat wall has few corners (a slice half a centimetre
    # high can hold none of one wall's), the points where the model's edges cross the slice's two levels.
    ends = np.empty(len(obj.data.edges) * 2, dtype=np.int64)
    obj.data.edges.foreach_get("vertices", ends)
    ea, eb = p[ends[0::2]], p[ends[1::2]]
    rise = eb[:, 2] - ea[:, 2]
    crossings = []
    for k in range(n + 1):
        level = lo_[2] + k * h / n
        with np.errstate(divide="ignore", invalid="ignore"):
            f = (level - ea[:, 2]) / rise
        cross = (rise != 0) & (f > 0) & (f < 1)
        crossings.append((ea[cross] + (eb[cross] - ea[cross]) * f[cross][:, None])[:, :2])
    bounds = np.full((n, 4), np.nan)
    for i in range(n):
        sl = np.concatenate([p[idx == i][:, :2], crossings[i], crossings[i + 1]])
        if len(sl):
            bounds[i] = (sl[:, 0].min(), sl[:, 1].min(), sl[:, 0].max(), sl[:, 1].max())
        elif i:
            bounds[i] = bounds[i - 1]
    ref = np.nanmedian(bounds[1:max(4, n // 10)], axis=0)
    width = float(max(ref[2] - ref[0], ref[3] - ref[1]))
    polys = obj.data.polygons
    mids, nors, areas = np.empty(len(polys) * 3), np.empty(len(polys) * 3), np.empty(len(polys))
    polys.foreach_get("center", mids)
    polys.foreach_get("normal", nors)
    polys.foreach_get("area", areas)
    mids, nors = mids.reshape(-1, 3), nors.reshape(-1, 3)
    inward = np.minimum(np.minimum(mids[:, 0] - ref[0], ref[2] - mids[:, 0]), np.minimum(mids[:, 1] - ref[1], ref[3] - mids[:, 1]))
    near = (nors[:, 2] > 0.9) & (inward > 0.004 * width) & (inward < 0.05 * width)
    level = np.minimum(((mids[near, 2] - lo_[2]) / h * n).astype(int), n - 1)
    at = np.bincount(level, weights=areas[near], minlength=n).astype(float)
    at[:2] = 0.0                                               # the ground's own slices
    pair = at + np.append(at[1:], 0.0)
    rim_i = int(np.nonzero(pair >= 0.5 * pair.max())[0].max())
    on_rim = near.copy()
    on_rim[near] = (level == rim_i) | (level == rim_i + 1)
    order = np.argsort(mids[on_rim, 2])
    rim = float(mids[on_rim, 2][order][np.searchsorted(np.cumsum(areas[on_rim][order]) / areas[on_rim].sum(), 0.5)]) - float(lo_[2])
    last = max(int(rim / h * n) - 1, 1)                        # the slices that are wall from top to bottom
    tiers, start = [], 0
    for i in range(1, last + 1):
        if i == last or np.abs(bounds[i] - bounds[start]).max() > step_share * width:
            if i - start >= 1:
                tiers.append((start * h / n, i * h / n, np.nanmedian(bounds[start:i], axis=0)))
            start = i
    tiers[0] = (0.0, tiers[0][1], tiers[0][2])
    tiers[-1] = (tiers[-1][0], rim, tiers[-1][2])
    body = max(tiers, key=lambda t: t[1] - t[0])[2]
    return rim, body, tiers


def convex_outline(points, within=0.002, most=40):
    """The convex outline of points (x, y), counter-clockwise, with the corners that stand less than `within`
    off the line through their neighbours taken out (more, until no more than `most` are left): a square box
    comes back as its four corners, one with rounded corners keeps a few points to each."""
    pts2 = sorted({(round(float(x), 5), round(float(y), 5)) for x, y in points})

    def half(run):
        chain = []
        for q in run:
            while len(chain) >= 2 and ((chain[-1][0] - chain[-2][0]) * (q[1] - chain[-2][1]) - (chain[-1][1] - chain[-2][1]) * (q[0] - chain[-2][0])) <= 0:
                chain.pop()
            chain.append(q)
        return chain[:-1]
    ring = [np.array(q) for q in half(pts2) + half(pts2[::-1])]
    while True:
        changed = True
        while changed and len(ring) > 4:
            changed = False
            for i in range(len(ring)):
                a, b, c = ring[i - 1], ring[i], ring[(i + 1) % len(ring)]
                along = c - a
                off = abs(along[0] * (b[1] - a[1]) - along[1] * (b[0] - a[0])) / max(float(np.linalg.norm(along)), 1e-12)
                if off < within:
                    del ring[i]
                    changed = True
                    break
        if len(ring) <= most:
            return np.array(ring)
        within *= 1.5


def face_colours(obj):
    """The colour the generator painted each face (sRGB, 0 to 1), read at the middle of the face's place in its texture."""
    image = None
    for m in obj.data.materials:
        for node in (m.node_tree.nodes if m and m.use_nodes else []):
            if node.type == "BSDF_PRINCIPLED" and node.inputs["Base Color"].is_linked:
                source = node.inputs["Base Color"].links[0].from_node
                if source.type == "TEX_IMAGE" and source.image is not None:
                    image = source.image
    iw, ih = image.size
    pix = np.empty(iw * ih * 4, dtype=np.float32)
    image.pixels.foreach_get(pix)
    pix = pix.reshape(ih, iw, 4)
    uvs = np.empty(len(obj.data.loops) * 2, dtype=np.float32)
    obj.data.uv_layers.active.data.foreach_get("uv", uvs)
    uvs = uvs.reshape(-1, 2)
    out = np.zeros((len(obj.data.polygons), 3))
    for poly in obj.data.polygons:
        u, v = uvs[poly.loop_start: poly.loop_start + poly.loop_total].mean(axis=0)
        out[poly.index] = pix[min(int(v * ih), ih - 1), min(int(u * iw), iw - 1), :3]
    return out


def hsv_of(rgb):
    """Hue (degrees), saturation and value of rows of sRGB colours."""
    mx, mn = rgb.max(axis=1), rgb.min(axis=1)
    hue = np.degrees(np.arctan2(np.sqrt(3) * (rgb[:, 1] - rgb[:, 2]), 2 * rgb[:, 0] - rgb[:, 1] - rgb[:, 2])) % 360
    return hue, (mx - mn) / np.maximum(mx, 1e-4), mx


def painted_water(rgb):
    """Which of these colours the generator (or the design) painted as water (--water): blue to teal and either
    strong or light, or foam, which is light with almost no colour."""
    h0, h1, s_least, v_least, white = (float(v) for v in opt("--water", "165,255,0.4,0.75,0.85").split(","))
    hue, sat, val = hsv_of(rgb)
    return ((hue > h0) & (hue < h1) & ((sat > s_least) | ((val > v_least) & (sat > 0.1)))) | ((val > white) & (sat < 0.1))


def mesh_arrays(me):
    """A mesh's vertices, and its faces' middles, normals and areas."""
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    n = len(me.polygons)
    cen, nor, area = np.empty(n * 3), np.empty(n * 3), np.empty(n)
    me.polygons.foreach_get("center", cen)
    me.polygons.foreach_get("normal", nor)
    me.polygons.foreach_get("area", area)
    return co.reshape(-1, 3), cen.reshape(-1, 3), nor.reshape(-1, 3), area


def piecewise(values, src, dst):
    """Piecewise-linear through the knots, the end pieces carried on beyond them."""
    src, dst = np.asarray(src, dtype=float), np.asarray(dst, dtype=float)
    values = np.asarray(values, dtype=float)
    out = np.interp(values, src, dst)
    below, above = values < src[0], values > src[-1]
    out[below] = dst[0] + (values[below] - src[0]) * (dst[1] - dst[0]) / (src[1] - src[0])
    out[above] = dst[-1] + (values[above] - src[-1]) * (dst[-1] - dst[-2]) / (src[-1] - src[-2])
    return out


def band_extent(co, edges, z0=0.15, z1=2.2):
    """What a mesh draws between two heights, by the game's own measure (kit_town.gd _band_points): the least
    and greatest x and y of its vertices there and of the points where its edges cross the two heights.
    Blender's frame (z up); None with nothing in the band."""
    found = [co[(co[:, 2] >= z0) & (co[:, 2] <= z1)][:, :2]]
    a, b = co[edges[:, 0]], co[edges[:, 1]]
    rise = b[:, 2] - a[:, 2]
    for level in (z0, z1):
        with np.errstate(divide="ignore", invalid="ignore"):
            f = (level - a[:, 2]) / rise
        crosses = (rise != 0) & (f > 0) & (f < 1)
        found.append(a[crosses][:, :2] + (b[crosses][:, :2] - a[crosses][:, :2]) * f[crosses][:, None])
    found = np.concatenate(found)
    return (found.min(axis=0), found.max(axis=0)) if len(found) else None


def carve(obj, planes, inside, zone=None, drop=False, choose=None):
    """Parts some of a mesh's faces from the rest, cleanly: the faces that cross a plane are cut along it
    (`planes`: axis, value, and a test of a face's middle that says whether this plane may cut it), the faces
    for which `inside` holds (given the face's middle, its normal and the greatest `zone` mark among its
    vertices) are disconnected from the others, and the open edges left on both sides are closed with faces
    that take the colours of the faces round them. With `zone` the parted vertices are marked with that number
    in the vertex attribute `zone`; with `drop` the parted faces are deleted instead and only the rest is
    closed. Returns how many faces were parted, how many closing faces were made and how many open edges could
    not be closed. `choose`, given the cut mesh, returns the faces to part instead of `inside` being asked face
    by face (for a choice that goes by what is joined to what)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.verts.layers.int.get("zone") or bm.verts.layers.int.new("zone")
    for axis, value, near in planes:
        crossing = [f for f in bm.faces if min(v.co[axis] for v in f.verts) < value - 1e-7 and max(v.co[axis] for v in f.verts) > value + 1e-7
                    and near(f.calc_center_median())]
        if not crossing:
            continue
        geom = crossing + list(dict.fromkeys(e for f in crossing for e in f.edges)) + list(dict.fromkeys(v for f in crossing for v in f.verts))
        at, normal = Vector((0, 0, 0)), Vector((0, 0, 0))
        at[axis], normal[axis] = value, 1.0
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=at, plane_no=normal, clear_inner=False, clear_outer=False)
    bm.normal_update()
    if choose is not None:
        picked = choose(bm)
        part = [f for f in bm.faces if f in picked]          # in the mesh's order, not the set's (which differs from run to run)
    else:
        part = [f for f in bm.faces if inside(f.calc_center_median(), f.normal, max(v[layer] for v in f.verts))]
    chosen = set(part)

    def key(e):
        return frozenset(tuple(round(c, 6) for c in v.co) for v in e.verts)
    border = [e for e in bm.edges if any(f in chosen for f in e.link_faces) and any(f not in chosen for f in e.link_faces)]
    keys = {key(e) for e in border}
    parted = len(part)
    if drop:
        bmesh.ops.delete(bm, geom=part, context="FACES")
        part = []
    else:
        bmesh.ops.split_edges(bm, edges=border)
    open_edges = [e for e in bm.edges if len(e.link_faces) == 1 and key(e) in keys]
    caps = bmesh.ops.holes_fill(bm, edges=open_edges, sides=0)["faces"] if open_edges else []
    left_open = sum(1 for e in open_edges if e.is_valid and len(e.link_faces) == 1)
    # Where two cutting planes meet, one closing face comes out folded over both (a bench's end and the
    # underside of the screen above it as one face). Such a face is divided along the fold, so that every
    # closing face lies in one plane.
    if len(planes) > 1:
        queue, caps = list(caps), []
        while queue:
            f = queue.pop()
            ring = [l.vert for l in f.loops]
            divided = False
            for axis, value, _ in planes:
                on = [abs(v.co[axis] - value) < 1e-5 for v in ring]
                if all(on) or sum(on) < 2:
                    continue                                      # it lies in this plane, or does not reach it
                turns = [i for i in range(len(ring)) if on[i] and not (on[i - 1] and on[(i + 1) % len(ring)])]
                if len(turns) == 2 and abs(turns[0] - turns[1]) not in (1, len(ring) - 1):
                    try:
                        other = bmesh.utils.face_split(f, ring[turns[0]], ring[turns[1]])[0]
                    except ValueError:
                        continue
                    queue += [f, other]
                    divided = True
                    break
            if not divided:
                caps.append(f)
    if zone is not None:
        for f in part:
            for v in f.verts:
                v[layer] = zone
    counts = (parted, len(caps), left_open)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return counts


def zones_of(me):
    """The vertex attribute `zone` (see carve) as an array, zeros where it was never set."""
    out = np.zeros(len(me.vertices), dtype=np.int32)
    if "zone" in me.attributes:
        me.attributes["zone"].data.foreach_get("value", out)
    return out


def runs_of(values, gap):
    """The runs of the sorted values in which no step is wider than `gap`, each as (least, greatest)."""
    values = np.sort(np.asarray(values, dtype=float))
    if not len(values):
        return []
    breaks = np.nonzero(np.diff(values) > gap)[0]
    starts, ends = np.concatenate([[0], breaks + 1]), np.concatenate([breaks, [len(values) - 1]])
    return [(float(values[a]), float(values[b])) for a, b in zip(starts, ends)]


def floor_sheet_out(obj, share):
    """A design image cut out with its contact shadow on the ground gives a model in which that shadow is a
    thin dark sheet lying a few centimetres up, as wide as the shadow was. It is taken out: the level faces
    (looking up or down) wholly lower than `share` of the height that are joined, through such faces, to one
    lying where nothing stands (no vertex between that height and half the model's in its plan cell), and
    the faces of the sheet's edge with them. Where it ran into a foot the hole is closed, and crumbs of it
    left lying loose are dropped. `share` may be `auto`: just over the height where most of the low faces
    that look up lie (the sheet's top), or nothing when they cover less than a twentieth of the plan. Returns
    the share used and carve's counts."""
    me = obj.data
    co, cen, nor, area = mesh_arrays(me)
    lo, top = co.min(axis=0), co.max(axis=0)
    wide, deep, high = top - lo
    if share == "auto":
        up = nor[:, 2] > 0.7
        hist, _ = np.histogram((cen[up, 2] - lo[2]) / high, bins=24, range=(0, 0.06), weights=area[up])
        peak = int(np.argmax(hist))
        if hist[peak] < 0.05 * wide * deep:
            return None, (0, 0, 0)
        while peak + 1 < len(hist) and hist[peak + 1] > 0.1 * hist.max():
            peak += 1
        share = (peak + 1) * 0.0025 + 0.004
    share = float(share)
    limit = lo[2] + share * high
    n_x, n_y = 100, max(8, int(round(100 * deep / wide)))
    ix = np.clip(((co[:, 0] - lo[0]) / wide * n_x).astype(int), 0, n_x - 1)
    iy = np.clip(((co[:, 1] - lo[1]) / deep * n_y).astype(int), 0, n_y - 1)
    stands = np.zeros((n_x, n_y), dtype=bool)
    body = (co[:, 2] >= limit) & (co[:, 2] < lo[2] + 0.5 * high)
    stands[ix[body], iy[body]] = True

    hover = lo[2] + 0.2 * share * high                   # the sheet lies over the ground; a foot's sole lies on it

    def the_sheet(bm):
        low = {f for f in bm.faces if max(v.co.z for v in f.verts) < limit and min(v.co.z for v in f.verts) > hover}
        level = {f for f in low if abs(f.normal.z) > 0.7}
        found = set()
        for f in level:
            c = f.calc_center_median()
            if not stands[min(max(int((c.x - lo[0]) / wide * n_x), 0), n_x - 1), min(max(int((c.y - lo[1]) / deep * n_y), 0), n_y - 1)]:
                found.add(f)
        stack = list(found)
        while stack:
            f = stack.pop()
            for e in f.edges:
                for g in e.link_faces:
                    if g in level and g not in found:
                        found.add(g)
                        stack.append(g)
        if not found:
            return found
        # The sheet's edge: the low faces round its outline that are not level, between its underside and its
        # top. A vertex is the sheet's own when every face on it is low.
        heights = sorted(f.calc_center_median().z for f in found)
        z_lo, z_hi = heights[len(heights) // 20] - 0.003 * high, heights[-1 - len(heights) // 20] + 0.003 * high
        between = {f for f in low if f not in found and min(v.co.z for v in f.verts) > z_lo and max(v.co.z for v in f.verts) < z_hi}
        own = {v for f in low for v in f.verts if all(g in low for g in v.link_faces)}
        verts = {v for f in found for v in f.verts}
        for _ in range(4):
            more = {f for f in between if f not in found and any(v in verts for v in f.verts) and all(v in verts or v in own for v in f.verts)}
            if not more:
                break
            found |= more
            verts |= {v for f in more for v in f.verts}
        return found
    counts = carve(obj, [], None, drop=True, choose=the_sheet)
    bm = bmesh.new()                                     # the closing faces may have many sides; what follows reads triangles
    bm.from_mesh(me)
    many = [f for f in bm.faces if len(f.verts) > 3]
    if many:
        bmesh.ops.triangulate(bm, faces=many)
    # crumbs of the sheet left lying loose: whatever is joined to nothing that rises above the sheet
    seen, crumbs = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        stack, bit, rises = [f], [], False
        seen.add(f)
        while stack:
            g = stack.pop()
            bit.append(g)
            rises = rises or max(v.co.z for v in g.verts) >= limit
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        stack.append(h)
        if not rises:
            crumbs += bit
    if crumbs:
        bmesh.ops.delete(bm, geom=crumbs, context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    return share, counts


def behind_out(obj):
    """What stands low down and further back than everything that stands at mid height, by more than three
    hundredths of the model's length, is not the shelter's: a generator can lay a plank on the ground behind
    the screen, on the side the image never showed. It would be the back of the piece's slice and push the
    screen forward out of the footprint's back strip. It is taken out, from a line just behind the back of
    what stands at mid height, and the faces that close the cut take the colour of the screen's back above
    them (they would keep the plank's). Returns carve's counts, or None when nothing lies there."""
    me = obj.data
    co, cen, nor, area = mesh_arrays(me)
    lo, top = co.min(axis=0), co.max(axis=0)
    wide, deep, high = top - lo
    f_v, f_c = (co[:, 2] - lo[2]) / high, (cen[:, 2] - lo[2]) / high
    down = nor[:, 2] < -0.7
    hist, _ = np.histogram(f_c[down], bins=100, range=(0, 1), weights=area[down])
    found = [k for k in range(50, 98) if hist[k:k + 3].sum() >= 0.4 * wide * deep]
    slab = (found[0] if found else 50 + int(np.argmax(hist[50:]))) / 100
    band, low = (f_v > 0.45 * slab) & (f_v < 0.8 * slab), (f_v > 0.03) & (f_v <= 0.45 * slab)
    if not (band.any() and low.any()) or co[band, 1].min() - co[low, 1].min() <= 0.03 * wide:
        return None
    line, under = float(co[band, 1].min() - 0.002 * wide), float(lo[2] + 0.45 * slab * high)
    counts = carve(obj, [(1, line, lambda c: c.z < under)], lambda c, n, z: c.y < line and c.z < under, drop=True)
    bm = bmesh.new()                                     # the closing faces may have many sides; what follows reads triangles
    bm.from_mesh(me)
    bm.normal_update()
    uv_layer = bm.loops.layers.uv.active
    closing = [f for f in bm.faces if all(abs(v.co.y - line) < 1e-6 for v in f.verts)]
    looks_back = [f for f in bm.faces if f.normal.y < -0.7 and f not in set(closing) and f.calc_center_median().z < under + 0.1 * high]
    if closing and looks_back and uv_layer is not None:
        lv = list(dict.fromkeys(v for f in looks_back for v in f.verts))
        at = {v: i for i, v in enumerate(lv)}
        above = BVHTree.FromPolygons([tuple(v.co) for v in lv], [[at[v] for v in f.verts] for f in looks_back])
        for f in closing:
            c = f.calc_center_median()
            near = above.find_nearest(Vector((c.x, line, max(v.co.z for v in f.verts) + 0.02 * high)))
            if near[2] is not None:
                src = looks_back[near[2]]
                u = sum((l[uv_layer].uv for l in src.loops), Vector((0.0, 0.0))) / len(src.loops)
                for l in f.loops:
                    l[uv_layer].uv = u
    many = [f for f in bm.faces if len(f.verts) > 3]
    if many:
        bmesh.ops.triangulate(bm, faces=many)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return counts


def canopy_rebuilt(hi, cell, keep_clear=None):
    """A copy of the sized shelter for the piece to be cut down from, its canopy (zone 1) rebuilt as a plain
    closed slab: what the canopy shows from straight above, what it shows from straight below, and upright
    walls round its outline, on plan cells of about `cell` metres (the cells are fitted to the canopy's box, so
    a roof that is a rectangle in plan keeps straight edges). A roof whose underside is slats or ribs finer
    than the triangle count can carry comes out of the reduction crumpled; rebuilt, the slats are one level
    soffit, and the bake paints them on it (the generated model, slats and all, stays what the colours are
    baked from). Heights are taken at the cells' corners: the highest, and the lowest, of the canopy in the
    cells that meet there. `keep_clear` (x0, y0, x1, y1, height): outside that box, and one cell inside its
    edge, the underside is not let below that height (taking the lowest of four cells carries a low point
    under the canopy, a post's stub, one cell further out than it was)."""
    halves = []
    for keep_canopy in (False, True):
        only(hi)
        bpy.ops.object.duplicate()
        half = bpy.context.view_layer.objects.active
        bm = bmesh.new()
        bm.from_mesh(half.data)
        layer = bm.verts.layers.int.get("zone")
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(v[layer] == 1 for v in f.verts) != keep_canopy], context="FACES")
        bm.to_mesh(half.data)
        bm.free()
        halves.append(half)
    rest, roof = halves
    me = roof.data
    before = tri_count(roof)
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    me.calc_loop_triangles()
    tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int32)
    me.loop_triangles.foreach_get("vertices", tri)
    corners = co[tri.reshape(-1, 3)]
    # points on every triangle, no further apart than half a cell (a large closing face would otherwise fall between the cells)
    longest = np.linalg.norm(corners - np.roll(corners, 1, axis=1), axis=2).max(axis=1)
    steps = np.clip(np.ceil(longest / (0.5 * cell)).astype(int), 1, 64)
    points = [co]
    for n in np.unique(steps):
        these = corners[steps == n]
        for i in range(n + 1):
            for j in range(n + 1 - i):
                w = np.array([i, j, n - i - j]) / n
                points.append(np.einsum("k,nkc->nc", w, these))
    pts = np.concatenate(points)
    lo, top = pts.min(axis=0), pts.max(axis=0)
    n_x, n_y = max(1, int(round((top[0] - lo[0]) / cell))), max(1, int(round((top[1] - lo[1]) / cell)))
    ix = np.clip(((pts[:, 0] - lo[0]) / (top[0] - lo[0]) * n_x).astype(int), 0, n_x - 1)
    iy = np.clip(((pts[:, 1] - lo[1]) / (top[1] - lo[1]) * n_y).astype(int), 0, n_y - 1)
    high, low = np.full((n_x, n_y), -np.inf), np.full((n_x, n_y), np.inf)
    np.maximum.at(high, (ix, iy), pts[:, 2])
    np.minimum.at(low, (ix, iy), pts[:, 2])
    there = np.isfinite(high)
    # at the corners: the highest and the lowest of the cells that meet there
    node_high, node_low = np.full((n_x + 1, n_y + 1), -np.inf), np.full((n_x + 1, n_y + 1), np.inf)
    for da in (0, 1):
        for db in (0, 1):
            node_high[da:da + n_x, db:db + n_y] = np.maximum(node_high[da:da + n_x, db:db + n_y], np.where(there, high, -np.inf))
            node_low[da:da + n_x, db:db + n_y] = np.minimum(node_low[da:da + n_x, db:db + n_y], np.where(there, low, np.inf))
    xs, ys = np.linspace(lo[0], top[0], n_x + 1), np.linspace(lo[1], top[1], n_y + 1)
    if keep_clear is not None:
        kx0, ky0, kx1, ky1, k_height = keep_clear
        edge_x, edge_y = (top[0] - lo[0]) / n_x, (top[1] - lo[1]) / n_y
        outside = ((xs < kx0 + edge_x) | (xs > kx1 - edge_x))[:, None] | ((ys < ky0 + edge_y) | (ys > ky1 - edge_y))[None, :]
        node_low = np.where(outside & np.isfinite(node_low), np.maximum(node_low, k_height), node_low)
        node_high = np.where(np.isfinite(node_high), np.maximum(node_high, node_low + 0.01), node_high)
    bm = bmesh.new()
    above, below = {}, {}

    def node(i, j, which, heights):
        if (i, j) not in which:
            which[(i, j)] = bm.verts.new((xs[i], ys[j], heights[i, j]))
        return which[(i, j)]
    for i in range(n_x):
        for j in range(n_y):
            if not there[i, j]:
                continue
            ring = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            bm.faces.new([node(a_, b_, above, node_high) for a_, b_ in ring])
            bm.faces.new([node(a_, b_, below, node_low) for a_, b_ in reversed(ring)])
            for k, (da, db) in enumerate(((0, -1), (1, 0), (0, 1), (-1, 0))):          # the wall on each side that has no cell beyond it
                c_, d_ = i + da, j + db
                if 0 <= c_ < n_x and 0 <= d_ < n_y and there[c_, d_]:
                    continue
                p, q = ring[k], ring[(k + 1) % 4]
                bm.faces.new([node(*p, below, node_low), node(*q, below, node_low), node(*q, above, node_high), node(*p, above, node_high)])
    slab = bpy.data.meshes.new("canopy_slab")
    bm.to_mesh(slab)
    bm.free()
    bpy.data.objects.remove(roof, do_unlink=True)
    roof = bpy.data.objects.new("canopy_slab", slab)
    bpy.context.scene.collection.objects.link(roof)
    report["canopy_rebuilt"] = {"cells": [n_x, n_y], "cell_m": [round(float((top[0] - lo[0]) / n_x), 4), round(float((top[1] - lo[1]) / n_y), 4)],
                                "tris_before": before, "tris_rebuilt": tri_count(roof)}
    bpy.ops.object.select_all(action="DESELECT")
    roof.select_set(True)
    rest.select_set(True)
    bpy.context.view_layer.objects.active = rest
    bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def size_shelter(hi):
    """The generated shelter sized zone by zone (--shelter): see the top of this file. Works in the model's own
    units and frame after it is turned (Blender's: x along the shelter, +y its open front, z up) and leaves it
    in metres in the piece's frame. Returns the heights (metres) between which the lamps hang under the canopy,
    and what the piece is to be cut down from when that is not the sized model itself (its canopy rebuilt:
    --shelter-set roof), else None."""
    x0, z0, x1, z1 = (float(v) for v in opt("--shelter").split(","))
    end_w = float(opt("--shelter-end", "0.15"))
    given = dict(item.split("=") for item in (opt("--shelter-set") or "").split(",") if item)
    k_lo, k_hi = kit_box
    me = hi.data
    parted, floor_share = {}, None
    if "floor" in given:
        floor_share, parted["floor_sheet"] = floor_sheet_out(hi, given["floor"])
    lay_behind = behind_out(hi)
    if lay_behind is not None:
        parted["behind_the_screen"] = lay_behind
    co, cen, nor, area = mesh_arrays(me)
    lo, top = co.min(axis=0), co.max(axis=0)
    wide, deep, high = top - lo
    f_v, f_c = (co[:, 2] - lo[2]) / high, (cen[:, 2] - lo[2]) / high
    # The canopy's underside: the lowest height in the upper half where the faces looking down cover a good
    # part of the plan (a rail's or a lamp's underside covers little).
    if "slab" in given:
        slab = float(given["slab"])
    else:
        down = nor[:, 2] < -0.7
        hist, _ = np.histogram(f_c[down], bins=100, range=(0, 1), weights=area[down])
        found = [k for k in range(50, 98) if hist[k:k + 3].sum() >= 0.4 * wide * deep]
        slab = (found[0] if found else 50 + int(np.argmax(hist[50:]))) / 100
    # The back screen's front face: at mid height, in the middle of the length, how far forward anything stands.
    band = (f_v > 0.45 * slab) & (f_v < 0.8 * slab)
    if "wall" in given:
        wall = float(given["wall"])
    else:
        cell = np.clip(((co[:, 0] - lo[0]) / wide * 100).astype(int), 0, 99)
        fronts = [co[band & (cell == k), 1].max() for k in range(20, 80) if (band & (cell == k)).any()]
        wall = float(np.median(fronts))
    proud = 0.006 * wide                                 # what stands this far in front of the screen is not the screen

    def end_face(side):
        """The inner face of the structure at one end: of what stands proud of the screen at mid height, the
        run that starts at that end (posts, an end screen), up to the first gap."""
        half = (co[:, 0] < lo[0] + 0.5 * wide) if side < 0 else (co[:, 0] > lo[0] + 0.5 * wide)
        xs = np.sort(co[band & half & (co[:, 1] > wall + proud), 0])
        if side > 0:
            xs = xs[::-1]
        if len(xs) == 0:
            return float(lo[0] if side < 0 else top[0])
        gaps = np.nonzero(np.abs(np.diff(xs)) > 0.02 * wide)[0]
        return float(xs[gaps[0]] if len(gaps) else xs[-1])
    xa = float(given["xa"]) if "xa" in given else end_face(-1)
    xb = float(given["xb"]) if "xb" in given else end_face(1)
    # The bench: between the end structures, the heights at which something stands in front of the screen,
    # from the ground up to the first height where only the screen is left.
    inner = (co[:, 0] > xa + 0.01 * wide) & (co[:, 0] < xb - 0.01 * wide)
    bench_spec = [float(v) for v in opt("--shelter-bench").split(",")] if opt("--shelter-bench") else None
    # Posts that stand before the screen between the ends (a wall with a frame of posts in front of it) reach
    # further forward at mid height than the screen's face does: they are not the bench, and the bench is then
    # what stands further forward than they do.
    stands_out = float(co[band & inner, 1].max()) if (band & inner).any() else wall
    posts_before = stands_out > wall + 0.01 * wide
    over = (stands_out + 0.004 * wide) if posts_before else (wall + 0.01 * wide)
    bench = None
    for k in range(6, int(120 * slab)):
        here = inner & (f_v >= k / 200) & (f_v < (k + 1) / 200)
        if here.any() and co[here, 1].max() > over:
            bench = (k + 1) / 200
        elif bench is not None and k / 200 > bench + 0.02:
            break
    bench = float(given.get("bench", bench or 0)) if bench_spec else 0.0
    seat = front = None
    if bench:
        flat = (cen[:, 0] > xa) & (cen[:, 0] < xb) & (f_c < bench) & (f_c > 0.05) & (nor[:, 2] > 0.9) & (cen[:, 1] > wall + 0.01 * wide)
        hist, _ = np.histogram(f_c[flat], bins=200, range=(0, 1), weights=area[flat])
        near = flat & (np.abs(f_c - (int(np.argmax(hist)) + 0.5) / 200) < 0.015)
        seat = float(given.get("seat", np.average(f_c[near], weights=area[near])))
        on_seat = flat & (np.abs(f_c - seat) < 0.01)
        front = float(np.percentile(cen[on_seat, 1], 99.5))          # the seat's front edge
    # The feet's steps: below this height the end posts are wider than their shafts, and reach in under the bench's ends.
    shaft = co[band, 0].max() - co[band, 0].min()
    steps = [k / 200 for k in range(0, 40) if ((f_v >= k / 200) & (f_v < (k + 1) / 200)).any()
             and co[(f_v >= k / 200) & (f_v < (k + 1) / 200), 0].max() - co[(f_v >= k / 200) & (f_v < (k + 1) / 200), 0].min() > shaft + 0.002 * wide]
    foot = (max(steps) + 0.005) if steps else 0.0
    # Is there a screen behind the bench, down at the bench's own height (a wall the bench stands against), or is
    # the bench all there is below the screen (a bench whose back is the screen's foot)? Along the length, how
    # far forward anything stands at the bench's height: where there is no bench that is the screen's face.
    behind_bench = None
    if bench:
        at_height = inner & (f_v > foot) & (f_v < bench)
        cell = np.clip(((co[:, 0] - lo[0]) / wide * 100).astype(int), 0, 99)
        fronts = [co[at_height & (cell == k), 1].max() for k in range(100) if (at_height & (cell == k)).any()]
        if fronts and np.percentile(fronts, 10) < front - 0.5 * (front - wall):
            behind_bench = float(given.get("behind", np.percentile(fronts, 10) + 0.004 * wide))
        if posts_before and "behind" not in given:
            # the bench is parted from the posts that stand before the screen, just in front of their faces
            behind_bench = max(behind_bench if behind_bench is not None else -np.inf, stands_out + 0.002 * wide)
    # A post in front of the screen at the open end: where people walk. Its plan box, feet included.
    ahead = (front + 0.04 * wide) if front is not None else (wall + co[band, 1].max()) / 2
    low = f_v < 0.5 * slab
    post = low & (co[:, 0] > xb - 0.015 * wide) & (co[:, 1] > ahead)
    post_box, post_rule = None, None
    if post.any() and given.get("post") != "0":
        post_box = (float(co[post, 0].min() - 0.001 * wide), float(co[post, 1].min() - 0.002 * wide))
        post_rule = "ahead of the bench"
        # a foot wider than its post by more than the margin looked in: the foot goes with the post
        foot_in = low & (co[:, 1] > post_box[1]) & (co[:, 0] > xb - 0.08 * wide) & (co[:, 0] <= post_box[0])
        if foot_in.any():
            post_box = (float(co[foot_in, 0].min() - 0.001 * wide), post_box[1])
    # A bench as deep as the shelter: its front edge is then no further back than the post is, and the test
    # above misses the post or takes only its front half. What stands at the open end beyond the end
    # structure's inner face shows it, read as runs from back to front: a run that the line `ahead` falls
    # inside (a post no further forward than the bench's edge), or a first run that starts at the screen and
    # reaches further forward than a back post would (a panel from the screen to a post in front). The first
    # is taken out from where it starts, the second from just in front of the screen and its posts.
    if front is not None and given.get("post") != "0":
        at_end = low & (f_v > foot + 0.01) & (co[:, 0] > xb + 0.002 * wide)
        runs = runs_of(co[at_end, 1], 0.008 * wide)
        falls_in = [r for r in runs if r[0] < ahead <= r[1]]
        from_the_screen = bool(runs) and runs[0][0] < stands_out + 0.01 * wide and runs[0][1] > stands_out + 0.05 * wide
        if from_the_screen or falls_in:
            start = (stands_out + 0.004 * wide) if from_the_screen else (falls_in[0][0] - 0.002 * wide)
            if not from_the_screen:
                # the post's foot is wider than its shaft, and starts a little further back
                flare = low & (co[:, 0] > xb + 0.002 * wide) & (co[:, 1] > start - 0.02 * wide) & (co[:, 1] <= start)
                if flare.any():
                    start = float(co[flare, 1].min() - 0.002 * wide)
            taken = low & (co[:, 0] > xb - 0.015 * wide) & (co[:, 1] > start)
            post_box = (float(co[taken, 0].min() - 0.001 * wide), float(start))
            post_rule = "everything in front of the screen at the open end (a panel runs from the screen to the post)" if from_the_screen else "from where the post starts (the bench is as deep as the shelter)"
    # Does the screen stand well forward of the back of the structure at the -x end (see 4 below)?
    screen_y = None
    end_mid, screen_mid = band & (co[:, 0] < xa - 0.002 * wide), band & inner
    if end_mid.any() and screen_mid.any() and given.get("screen") != "0":
        if float(co[screen_mid, 1].min() - co[end_mid, 1].min()) > 0.05 * wide:
            screen_y = (float(co[screen_mid, 1].min()), stands_out)

    bench_z, slab_z = lo[2] + bench * high, lo[2] + slab * high
    # 1. The canopy, and what hangs from it, parted from what stands under it. The plan is read cell by cell (a
    #    hundredth of the length): where something reaches down into the lower half, it stands (a post, a
    #    screen, the bench); where nothing does, what is there hangs from the canopy or is the canopy (a lamp, a
    #    roof beam, the roof's overhang). What stands and reaches up to the underside of what hangs beside it
    #    (a post under a beam or under the roof) is cut just under that underside, each post at its own height:
    #    a roof may slope, and one post may stand under a beam where the next stands under the roof itself.
    n_x, n_y = 100, max(8, int(round(100 * deep / wide)))
    ix = np.clip(((co[:, 0] - lo[0]) / wide * n_x).astype(int), 0, n_x - 1)
    iy = np.clip(((co[:, 1] - lo[1]) / deep * n_y).astype(int), 0, n_y - 1)
    lowest = np.full((n_x, n_y), np.inf)
    np.minimum.at(lowest, (ix, iy), co[:, 2])
    half_way = lo[2] + 0.5 * slab * high
    standing = lowest < half_way
    hanging = np.isfinite(lowest) & ~standing
    beside = np.full((n_x, n_y), np.inf)                 # over each standing cell: the lowest underside that hangs right beside it
    for i, j in np.argwhere(standing):
        window = (slice(max(i - 1, 0), i + 2), slice(max(j - 1, 0), j + 2))
        if hanging[window].any():
            beside[i, j] = lowest[window][hanging[window]].min()
    for _ in range(12):                                  # and inwards from there, for the cells in the middle of a thing wider than two cells
        unknown = [(i, j) for i, j in np.argwhere(standing & ~np.isfinite(beside))]
        if not unknown:
            break
        found = {}
        for i, j in unknown:
            window = beside[max(i - 1, 0):i + 2, max(j - 1, 0):j + 2]
            if np.isfinite(window).any():
                found[(i, j)] = window[np.isfinite(window)].min()
        if not found:
            break
        for at, value in found.items():
            beside[at] = value
    beside[~np.isfinite(beside)] = slab_z
    reaches = np.full((n_x, n_y), -np.inf)               # how high each standing cell reaches under that underside
    below = co[:, 2] < beside[ix, iy] - 0.002 * high
    np.maximum.at(reaches, (ix[below], iy[below]), co[below, 2])
    tall = standing & (reaches > beside - 0.04 * high)
    post_of = np.full((n_x, n_y), -1)
    blobs = []
    for i, j in np.argwhere(tall):
        if post_of[i, j] >= 0:
            continue
        stack, members = [(i, j)], []
        post_of[i, j] = len(blobs)
        while stack:
            a_, b_ = stack.pop()
            members.append((a_, b_))
            for da in (-1, 0, 1):
                for db in (-1, 0, 1):
                    c_, d_ = a_ + da, b_ + db
                    if 0 <= c_ < n_x and 0 <= d_ < n_y and tall[c_, d_] and post_of[c_, d_] < 0:
                        post_of[c_, d_] = len(blobs)
                        stack.append((c_, d_))
        blobs.append(members)
    round_post = post_of.copy()                          # each post's cells and the ring of cells round them
    for i, j in np.argwhere(post_of >= 0):
        for da in (-1, 0, 1):
            for db in (-1, 0, 1):
                c_, d_ = i + da, j + db
                if 0 <= c_ < n_x and 0 <= d_ < n_y and round_post[c_, d_] < 0:
                    round_post[c_, d_] = post_of[i, j]
    # Where each post is cut: a little under the lowest of what hangs in the cells round it (those cells show
    # the underside a little higher than it is at the post itself), and never above the roof's own underside.
    tri = np.empty(len(me.polygons) * 3, dtype=np.int32)
    me.polygons.foreach_get("vertices", tri)
    tri_z = co[tri.reshape(-1, 3), 2]
    face_lo, face_hi = tri_z.min(axis=1), tri_z.max(axis=1)
    f_ix = np.clip(((cen[:, 0] - lo[0]) / wide * n_x).astype(int), 0, n_x - 1)
    f_iy = np.clip(((cen[:, 1] - lo[1]) / deep * n_y).astype(int), 0, n_y - 1)
    cut_at = [float(min(min(beside[m] for m in members), slab_z) - 0.015 * high) for members in blobs]
    if "cut" in given:
        cut_at = [float(lo[2] + float(given["cut"]) * high)] * len(blobs)          # one height for every post, as given

    def gap_over_a_rail(k):
        """For a post cut under something that hangs beside it well below the roof: the gap between that
        thing's top and whatever hangs next above it, read from the heights the faces in the cells round the
        post span, from the bottom up; None when it runs up into the roof without a gap (a roof beam)."""
        ring = (round_post[f_ix, f_iy] == k) & hanging[f_ix, f_iy] & (face_hi > half_way)
        spans = sorted(zip(face_lo[ring], face_hi[ring]))
        if not spans:
            return None
        ceiling = spans[0][1]
        for z_lo, z_hi in spans:
            if z_lo > ceiling + 0.003 * high:
                return float(ceiling), float(z_lo)
            ceiling = max(ceiling, z_hi)
        return None

    def cell_of(c):
        return min(max(int((c.x - lo[0]) / wide * n_x), 0), n_x - 1), min(max(int((c.y - lo[1]) / deep * n_y), 0), n_y - 1)

    def in_canopy(c, n, z):
        at = cell_of(c)
        if post_of[at] >= 0:
            return c.z > cut_at[post_of[at]]
        if standing[at]:
            return c.z > beside[at] - 0.006 * high
        return c.z > half_way
    planes = [(2, cut_at[k], lambda c, k=k: round_post[cell_of(c)] == k) for k in range(len(cut_at))]
    one_cut = float(lo[2] + float(given["cut"]) * high) if "cut" in given else None
    if one_cut is not None:
        # one height for everything that stands (given): every face in a cell where something stands is cut there
        planes = [(2, one_cut, lambda c: bool(standing[cell_of(c)]) or round_post[cell_of(c)] >= 0)]
    leaked, recut, whole, hung = [], [], [], []

    def least_crossed():
        """The height just under the roof's underside at which the least is crossed: posts are thin, and a
        roof, a sign's top or a rail are not. Of the heights from 3% of the model's under the underside to 2%
        over it, a quarter per cent apart, the one whose plane cuts faces in the fewest plan cells (the
        highest, of equals)."""
        best = None
        for step in range(-12, 9):
            level = slab_z + step * 0.0025 * high
            crossing = (face_lo < level) & (face_hi > level)
            count = len(np.unique(f_ix[crossing] * n_y + f_iy[crossing]))
            if best is None or count <= best[0]:
                best = (count, level)
        return float(best[1])

    def joined_to_the_roof(bm):
        """The canopy: everything joined to the roof without passing a post's cut. The posts are cut through;
        from the faces well above the roof's underside the mesh is walked face to face, never across an edge
        that lies in a post's cut, and what is reached is the canopy with all that hangs from it. (A rail on
        the screen that stands a hair's breadth into a cell where nothing reaches the ground is not reached,
        and stays with the screen.) If the walk reaches the ground a post was missed: the whole model is then
        cut at one height, the one just under the roof where the least is crossed, and walked again; only if
        that fails too do the plan's cells decide instead."""
        def walk():
            barrier = set()
            for e in bm.edges:
                a_, b_ = e.verts
                if whole:
                    if abs(a_.co.z - whole[0]) < 1e-6 and abs(b_.co.z - whole[0]) < 1e-6:
                        barrier.add(e)
                    continue
                at = cell_of((a_.co + b_.co) / 2)
                k = round_post[at]
                if one_cut is not None:
                    if (k >= 0 or standing[at]) and abs(a_.co.z - one_cut) < 1e-6 and abs(b_.co.z - one_cut) < 1e-6:
                        barrier.add(e)
                elif k >= 0 and abs(a_.co.z - cut_at[k]) < 1e-6 and abs(b_.co.z - cut_at[k]) < 1e-6:
                    barrier.add(e)
            reached = {f for f in bm.faces if f.calc_center_median().z > slab_z + 0.02 * high}
            stack = list(reached)
            while stack:
                f = stack.pop()
                for e in f.edges:
                    if e in barrier:
                        continue
                    for g in e.link_faces:
                        if g not in reached:
                            reached.add(g)
                            stack.append(g)
            return reached, any(f.calc_center_median().z < half_way for f in reached), barrier

        def with_what_hangs(reached, barrier):
            """What a cut left hanging goes with the canopy: a piece under a cut that is joined to nothing in
            the lower half (the lower end of a lamp or of a roof's low edge, in a cell where something
            stands) hung from what is above the cut."""
            seen = set(reached)
            for e in bm.edges:
                if e not in barrier:
                    continue
                for g in e.link_faces:
                    if g in seen:
                        continue
                    piece, stack, grounded = [g], [g], False
                    seen.add(g)
                    while stack:
                        f = stack.pop()
                        grounded = grounded or f.calc_center_median().z < half_way
                        for e2 in f.edges:
                            if e2 in barrier:
                                continue
                            for h in e2.link_faces:
                                if h not in seen:
                                    seen.add(h)
                                    piece.append(h)
                                    stack.append(h)
                    if not grounded:
                        reached.update(piece)
                        hung.append(len(piece))
            return reached
        reached, to_the_ground, barrier = walk()
        if to_the_ground:
            # A post cut under something that hangs beside it well below the roof (a rail between two posts,
            # which is the screen's and not the roof's) is still joined, above its cut, to that rail and so
            # to the screen. Such posts are cut again in the gap between that rail and the roof.
            for k in [k for k in range(len(cut_at)) if cut_at[k] < slab_z - 0.03 * high]:
                gap = gap_over_a_rail(k)
                if gap is None:
                    continue
                again = (gap[0] + gap[1]) / 2
                crossing = [f for f in bm.faces if min(v.co.z for v in f.verts) < again - 1e-7 and max(v.co.z for v in f.verts) > again + 1e-7
                            and round_post[cell_of(f.calc_center_median())] == k]
                if crossing:
                    geom = crossing + list(dict.fromkeys(e for f in crossing for e in f.edges)) + list(dict.fromkeys(v for f in crossing for v in f.verts))
                    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=Vector((0, 0, again)), plane_no=Vector((0, 0, 1)), clear_inner=False, clear_outer=False)
                cut_at[k] = again
            recut.append(True)
            reached, to_the_ground, barrier = walk()
        if to_the_ground:
            level = one_cut if one_cut is not None else least_crossed()
            crossing = [f for f in bm.faces if min(v.co.z for v in f.verts) < level - 1e-7 and max(v.co.z for v in f.verts) > level + 1e-7]
            if crossing:
                geom = crossing + list(dict.fromkeys(e for f in crossing for e in f.edges)) + list(dict.fromkeys(v for f in crossing for v in f.verts))
                bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=Vector((0, 0, level)), plane_no=Vector((0, 0, 1)), clear_inner=False, clear_outer=False)
            whole.append(level)
            cut_at[:] = [level] * len(cut_at)
            reached, to_the_ground, barrier = walk()
            if not to_the_ground:
                # Under that one height lie things that are the roof's all the same, though joined to what
                # stands: a roof's low end (a hip that comes down over an end wall), a lamp rail on brackets
                # under the soffit. They are what lies in the top tenth under the roof's underside where
                # nothing stands at mid height in the plan cell or in the cells round it.
                mid = (co[:, 2] > lo[2] + 0.5 * slab * high) & (co[:, 2] < lo[2] + 0.9 * slab * high)
                stands_mid = np.zeros((n_x + 2, n_y + 2), dtype=bool)
                stands_mid[ix[mid] + 1, iy[mid] + 1] = True
                near_mid = np.zeros((n_x, n_y), dtype=bool)
                for da in (0, 1, 2):
                    for db in (0, 1, 2):
                        near_mid |= stands_mid[da:da + n_x, db:db + n_y]
                for f in bm.faces:
                    if f not in reached:
                        c = f.calc_center_median()
                        if c.z > lo[2] + 0.9 * slab * high and not near_mid[cell_of(c)]:
                            reached.add(f)
        if to_the_ground:
            leaked.append(True)
            return {f for f in bm.faces if in_canopy(f.calc_center_median(), None, 0)}
        return with_what_hangs(reached, barrier)
    parted["canopy"] = carve(hi, planes, None, zone=1, choose=joined_to_the_roof)
    # 2. The post at the open end, out, up to the canopy.
    if post_box:
        px_, py_ = post_box
        planes = [(1, py_, lambda c: c.x > px_ and c.z < slab_z)]
        if post_rule != "ahead of the bench":
            planes.append((0, px_, lambda c: c.y > py_ and c.z < slab_z))          # the bench's end may reach across this line
        parted["post"] = carve(hi, planes, lambda c, n, z: z == 0 and c.x > px_ and c.y > py_, drop=True)
    # 3. The bench, parted from the end structures and from the screen above it: cut a little way in from each
    #    end structure's face (the faces that lie in that face itself must stay with the structure), and the
    #    stub that leaves on the structure taken off and the hole closed.
    slice_, hair, behind = 0.0015 * wide, 0.0003 * wide, float(opt("--shelter-stub", "0.012")) * wide

    def press(sides, within, middle_of=None):
        """What is left of a parted thing on each structure it ran into (an end structure, or a screen behind
        it): a stub as long as the slice, and as far again as the thing ran in past the posts' faces to a
        screen set back between them. It is pressed flat onto the face it stands on and takes that face's
        colour. Nothing is deleted, so no hole can be left open. `sides`: axis, the structure's face, which
        way is out from it, how thick the stub is and how far in behind the face it may reach; `within` says
        of a face's middle whether it lies where stubs are looked for. With `middle_of` (a distance) the colour
        is not the nearest face's but that of the middle face, by lightness, of the structure's faces within
        that distance at the stub's own height (what lies to either side of an upright joint): a generator
        shades a panel darker along a joint, and a stub that took the joint's shade would stay on a lit panel
        as a grey mark. The stub is then also found from the cut itself: the closing faces in the cut's plane
        and the faces joined to them that do not look along the axis; a face of the structure that stands a
        millimetre proud of the plane read off its posts is the structure's, not a stub. (A closing face is
        one face as tall as what was cut: it is divided into bands a hundredth of the height tall first, so
        that each band takes the colour of what lies beside it.) Returns how many faces were pressed."""
        painted = face_colours(hi) @ LUM if middle_of else None
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.normal_update()
        layer, uv_layer = bm.verts.layers.int.get("zone"), bm.loops.layers.uv.active
        pressed = 0
        for axis, face, sign, thick, deep_in in sides:
            if middle_of:
                plane = face + sign * thick
                closing = [f for f in bm.faces if max(v[layer] for v in f.verts) == 0 and all(abs(v.co[axis] - plane) < 1e-6 for v in f.verts)]
                heights = [v.co.z for f in closing for v in f.verts]
                level = (min(heights) + 0.01 * high) if heights else np.inf
                while heights and level < max(heights):
                    crossing = [f for f in closing if f.is_valid and min(v.co.z for v in f.verts) < level - 1e-7 and max(v.co.z for v in f.verts) > level + 1e-7]
                    if crossing:
                        geom = crossing + list(dict.fromkeys(e for f in crossing for e in f.edges)) + list(dict.fromkeys(v for f in crossing for v in f.verts))
                        made = bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-7, plane_co=Vector((0, 0, level)), plane_no=Vector((0, 0, 1)), clear_inner=False, clear_outer=False)
                        closing = [f for f in closing if f.is_valid and f not in crossing] + [g for g in made["geom"] if isinstance(g, bmesh.types.BMFace)]
                    level += 0.01 * high
                bm.normal_update()
            stub, solid = [], []
            for f in bm.faces:
                c = f.calc_center_median()
                if max(v[layer] for v in f.verts) != 0 or not within(c):
                    continue
                depth = (c[axis] - face) * sign                   # how far out from the structure's face
                if -deep_in - 0.01 * wide < depth < hair and abs(f.normal[axis]) > 0.9:
                    solid.append(f)                               # the structure's own face (a post's, a screen's)
                elif -deep_in < depth < thick + hair and (axis == 0 or c.y > face - deep_in):
                    stub.append(f)
            if middle_of:
                plane, pool = face + sign * thick, stub + solid
                among = set(pool)
                found = {f for f in pool if all(abs(v.co[axis] - plane) < 1e-6 for v in f.verts)}
                stack = [f for f in pool if f in found]
                while stack:
                    f = stack.pop()
                    for e in f.edges:
                        for g in e.link_faces:
                            if g in among and g not in found and abs(g.normal[axis]) <= 0.9:
                                found.add(g)
                                stack.append(g)
                stub = [f for f in pool if f in found]
                solid = [f for f in pool if f not in found and abs(f.normal[axis]) > 0.9]
            if not (stub and solid):
                continue
            sv = list(dict.fromkeys(v for f in solid for v in f.verts))
            at = {v: i for i, v in enumerate(sv)}
            faces_of = BVHTree.FromPolygons([tuple(v.co) for v in sv], [[at[v] for v in f.verts] for f in solid])
            here = set(stub) | set(solid)
            for v in dict.fromkeys(v for f in stub for v in f.verts):
                if any(f not in here for f in v.link_faces):
                    continue                                      # shared with something outside the stub (the screen above, a foot below): it stays
                near_ = faces_of.find_nearest(v.co)
                if near_[0] is not None:
                    v.co[axis] = near_[0][axis]
            for f in stub:
                near_ = faces_of.find_nearest(f.calc_center_median())
                if near_[2] is not None and uv_layer is not None:
                    src = solid[near_[2]]
                    if middle_of:
                        at = f.calc_center_median()
                        round_it = sorted((float(painted[solid[hit[2]].index]), hit[2]) for hit in faces_of.find_nearest_range(at, middle_of)
                                          if abs(hit[0].z - at.z) < 0.2 * middle_of and hit[3] > 0.15 * middle_of)          # beside it, not the joint itself
                        if round_it:
                            src = solid[round_it[len(round_it) // 2][1]]
                    u = sum((l[uv_layer].uv for l in src.loops), Vector((0.0, 0.0))) / len(src.loops)
                    for l in f.loops:
                        l[uv_layer].uv = u
            pressed += len(stub)
        bm.to_mesh(me)
        bm.free()
        me.update()
        return pressed
    if bench:
        foot_z, reach = lo[2] + foot * high, front + 0.04 * wide
        back_y = -np.inf if behind_bench is None else behind_bench
        def at_bench(c):
            return foot_z < c.z < bench_z + 0.01 * high and back_y < c.y < reach
        def in_bench(c, n, z):
            return xa + slice_ < c.x < xb - slice_ and c.z < bench_z and back_y < c.y < reach and (c.z > foot_z or xa + 0.03 * wide < c.x < xb - 0.03 * wide)
        planes = [(0, xa + slice_, at_bench), (0, xb - slice_, at_bench), (2, bench_z, lambda c: xa - 0.01 * wide < c.x < xb + 0.01 * wide and back_y - 0.005 * wide < c.y < reach)]
        if behind_bench is not None:
            planes.append((1, behind_bench, lambda c: xa < c.x < xb and c.z < bench_z + 0.01 * high))
        seat_z = lo[2] + seat * high

        def the_bench(bm):
            """The bench alone: of the faces in the bench's region, those joined to its seat. A post's foot or
            a plinth that stands a little proud of the screen in the same region is not the bench."""
            region = {f for f in bm.faces if in_bench(f.calc_center_median(), None, 0)}
            found = {f for f in region if abs(f.calc_center_median().z - seat_z) < 0.012 * high and f.normal.z > 0.8}
            stack = list(found)
            while stack:
                f = stack.pop()
                for e in f.edges:
                    for g in e.link_faces:
                        if g in region and g not in found:
                            found.add(g)
                            stack.append(g)
            return found
        parted["bench"] = carve(hi, planes, None, zone=2, choose=the_bench)
        sides = [(0, xa, 1, slice_, behind), (0, xb, -1, slice_, behind)]
        if behind_bench is not None:
            sides.append((1, behind_bench - 0.004 * wide, 1, 0.004 * wide, 0.006 * wide))
        parted["bench_stubs"] = (press(sides, lambda c: foot_z < c.z < bench_z and c.y < reach and xa - behind < c.x < xb + behind), 0, 0)
    # 4. A screen that stands well forward of the back of the structure at the -x end (a sign box that runs
    #    from behind the screen to the front posts) cannot be brought into the footprint's back strip by one
    #    scale from back to front without crushing that structure's back half. It is parted from the end
    #    structure, with all that is joined to it beyond that structure's inner face, and sized on its own:
    #    moved back to the strip (zone 3).
    if screen_y is not None:
        def by_the_screen(c):
            return c.z < slab_z and screen_y[0] - 0.02 * wide < c.y < screen_y[1] + 0.02 * wide

        def the_screen(bm):
            layer = bm.verts.layers.int.get("zone")
            region = {f for f in bm.faces if max(v[layer] for v in f.verts) == 0 and f.calc_center_median().x > xa + slice_}
            found = {f for f in region if by_the_screen(f.calc_center_median()) and f.calc_center_median().z > half_way}
            stack = list(found)
            while stack:
                f = stack.pop()
                for e in f.edges:
                    for g in e.link_faces:
                        if g in region and g not in found:
                            found.add(g)
                            stack.append(g)
            return found
        parted["screen"] = carve(hi, [(0, xa + slice_, lambda c: c.z < slab_z)], None, zone=3, choose=the_screen)
        # The screen may have run in past the end structure's posts to a panel set back between them: how far
        # back that panel's face lies is read off the faces that look along the shelter there.
        _, cen_now, nor_now, _ = mesh_arrays(me)
        facing = (nor_now[:, 0] > 0.9) & (cen_now[:, 0] > xa - 0.06 * wide) & (cen_now[:, 0] < xa + hair) & (cen_now[:, 2] < slab_z) \
            & (cen_now[:, 1] > screen_y[0] - 0.02 * wide) & (cen_now[:, 1] < screen_y[1] + 0.02 * wide)
        set_back = float(xa - np.percentile(cen_now[facing, 0], 5)) if facing.any() else 0.0
        parted["screen_stubs"] = (press([(0, xa, 1, slice_, max(behind, set_back + 0.004 * wide))], by_the_screen, middle_of=0.03 * wide), 0, 0)

    # ---- The maps ----
    co = mesh_arrays(me)[0]
    zone = zones_of(me)
    under, canopy, seat_part, screen_part = zone == 0, zone == 1, zone == 2, zone == 3
    edges = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    height = float(given["height"]) if "height" in given else float(k_hi[2] - k_lo[2])
    seat_top = None
    if bench:
        seat_top = bench_spec[4] if len(bench_spec) > 4 else kit_bench
    rel = co[:, 2] - lo[2]
    z_src, z_dst = ([0.0, seat * high, high], [0.0, seat_top, height]) if seat_top else ([0.0, high], [0.0, height])
    clear, lifted, pressed_feet = float(given.get("clear", 2.26)), None, None
    while True:
        new = np.empty_like(co)
        if seat_top or lifted:
            new[:, 2] = k_lo[2] + piecewise(rel, z_src, z_dst)
        else:
            new[:, 2] = k_lo[2] + rel * height / high
        if "feet" in given and 0 < foot * high < z_src[1] and float(piecewise([foot * high], z_src, z_dst)[0]) > float(given["feet"]):
            # Feet wider than their posts that rise into the walking band (it starts at 0.25 m) stand within
            # 10 cm of the walkable cells beside the end structure. What stands (not the bench, whose seat has
            # its own height) is pressed down below the feet's top, so that they end at the height given.
            stands_there = under | screen_part
            new[stands_there, 2] = k_lo[2] + piecewise(rel[stands_there], [0.0, foot * high] + list(z_src[1:]), [0.0, float(given["feet"])] + list(z_dst[1:]))
            pressed_feet = {"top_was_m": round(float(piecewise([foot * high], z_src, z_dst)[0]), 3), "now_m": float(given["feet"])}
        # Along the length and from back to front, what stands under the canopy fills the footprint box with its
        # slice between 0.15 and 2.2 m, as the game measures it.
        probe = co.copy()
        probe[:, 2] = new[:, 2]
        probe[canopy, 2] = 99.0                                          # the canopy is no part of that slice
        b_lo, b_hi = band_extent(probe, edges)
        if seat_part.any() or screen_part.any():
            # From back to front the slice is that of what is sized by this scale alone: a bench that reaches
            # further forward than the posts is put in its own rectangle afterwards, and a screen that is moved
            # back is no measure of the end structure's depth.
            probe[seat_part | screen_part, 2] = 99.0
            own_lo, own_hi = band_extent(probe, edges)
            if own_lo[1] != b_lo[1] or own_hi[1] != b_hi[1]:
                b_lo, b_hi = np.array([b_lo[0], own_lo[1]]), np.array([b_hi[0], own_hi[1]])
        x_src, x_dst = [b_lo[0], xa, xb, b_hi[0]], [x0, x0 + end_w, x1 - end_w, x1]
        new[:, 0] = piecewise(co[:, 0], x_src, x_dst)
        # From back to front one scale; but what stands at the back beyond the end screen (the screen, its posts, a
        # plinth under a post) is held to 22 cm from the back: the footprint's back strip is 20 cm deep, and the
        # next cells in front of it are walked on where there is no bench.
        y_src, y_dst = [b_lo[1], b_hi[1]], [-z1, -z0]
        at_back = under & (co[:, 0] > xa) & (co[:, 1] < wall + 0.10 * wide) & (new[:, 2] > 0.25) & (new[:, 2] < 1.9)
        if at_back.any() and not screen_part.any():
            reach_fwd = float(co[at_back, 1].max())
            if (reach_fwd - b_lo[1]) * (z1 - z0) / (b_hi[1] - b_lo[1]) > 0.22 and b_lo[1] < reach_fwd < b_hi[1]:
                y_src, y_dst = [b_lo[1], reach_fwd, b_hi[1]], [-z1, -z1 + 0.22, -z0]
        new[:, 1] = piecewise(co[:, 1], y_src, y_dst)
        numbers = {}
        back_src, back_dst = y_src, y_dst                                # the scale that places what stands at the back
        if screen_part.any():
            # The screen that was parted: its back face to the footprint's back, at the end structure's scale
            # unless that makes it deeper than the 22 cm it may take.
            standing_there = screen_part & (new[:, 2] > 0.25) & (new[:, 2] < 1.9)
            s_lo, s_hi = float(co[standing_there, 1].min()), float(co[standing_there, 1].max())
            depth = min((s_hi - s_lo) * (z1 - z0) / (b_hi[1] - b_lo[1]), 0.22)
            back_src, back_dst = [s_lo, s_hi], [-z1, -z1 + depth]
            new[screen_part, 1] = piecewise(co[screen_part, 1], back_src, back_dst)
            numbers["screen_moved_back"] = {"from_y": [round(s_lo, 4), round(s_hi, 4)], "depth_m": round(float(depth), 3),
                                            "stood_forward_of_the_end_structure_by_m": round(float((s_lo - b_lo[1]) * (z1 - z0) / (b_hi[1] - b_lo[1])), 3)}
        if bench and seat_part.any():
            bx0, bz0, bx1, bz1 = bench_spec[:4]
            own = co[seat_part]
            new[seat_part, 0] = piecewise(own[:, 0], [own[:, 0].min(), own[:, 0].max()], [bx0, bx1])
            back = float(own[:, 1].min())
            new[seat_part, 1] = piecewise(own[:, 1], [back, front], [float(piecewise([back], back_src, back_dst)[0]), -bz0])
            numbers["bench"] = {"x": [round(float(new[seat_part, 0].min()), 3), round(float(new[seat_part, 0].max()), 3)],
                                "front_edge_z": round(float(-new[seat_part, 1].max()), 3), "seat_front_z": bz0, "seat_top_m": round(float(seat_top), 3),
                                "top_m": round(float(new[seat_part, 2].max()), 3), "shortened_to": round(float((bx1 - bx0) / ((own[:, 0].max() - own[:, 0].min()) * (x1 - x0 - 2 * end_w) / (xb - xa))), 3)}
        # The canopy fills the kit piece's box from front to back.
        if canopy.any():
            own = co[canopy]
            new[canopy, 1] = piecewise(own[:, 1], [own[:, 1].min(), own[:, 1].max()], [float(k_lo[1]), float(k_hi[1])])
        # A roof that starts low: whatever of the canopy lies outside the footprint must stay clear of the band
        # the game measures (up to 2.2 m), or the game takes the whole canopy for the shelter's size and draws
        # the piece half as deep. If its lowest such point comes out under `clear`, the heights are divided
        # again: up to that point's height the model is stretched to `clear`, and the canopy takes what is left.
        if lifted is None:
            outside = canopy & ((new[:, 0] < x0 - 0.01) | (new[:, 0] > x1 + 0.01) | (new[:, 1] < -z1 - 0.01) | (new[:, 1] > -z0 + 0.01))
            if outside.any() and float(new[outside, 2].min()) < k_lo[2] + clear:
                lowest = float(rel[outside].min())
                lifted = {"lowest_outside_was_m": round(float(new[outside, 2].min()), 3), "raised_to_m": clear, "at": round(lowest / high, 4)}
                if seat_top:
                    z_src, z_dst = [0.0, seat * high, lowest, high], [0.0, seat_top, clear, height]
                else:
                    z_src, z_dst = [0.0, lowest, high], [0.0, clear, height]
                continue
        break
    # The posts' cut tops go a little way up into the canopy, so that no gap shows under it.
    ix = np.clip(((co[:, 0] - lo[0]) / wide * n_x).astype(int), 0, n_x - 1)
    iy = np.clip(((co[:, 1] - lo[1]) / deep * n_y).astype(int), 0, n_y - 1)
    whose = round_post[ix, iy]
    tops = under & (whose >= 0) & (np.abs(co[:, 2] - np.array(cut_at + [0.0])[whose]) < 0.002 * high)
    if whole:
        tops = (under | screen_part) & (np.abs(co[:, 2] - whole[0]) < 1e-5 * high)        # everything was cut at one height
    elif screen_part.any():
        tops |= screen_part & (whose >= 0) & (np.abs(co[:, 2] - np.array(cut_at + [0.0])[whose]) < 0.002 * high)
    if lifted:
        new[tops, 2] = k_lo[2] + piecewise(rel[tops] + 0.015 * high, z_src, z_dst) + 0.02
    else:
        new[tops, 2] += 0.015 * height + 0.02
    me.vertices.foreach_set("co", new.ravel())
    me.update()
    b_lo, b_hi = band_extent(np.where(canopy[:, None], 99.0, new), edges)
    slab_m = float(k_lo[2] + piecewise([slab * high], z_src, z_dst)[0]) if (seat_top or lifted) else float(k_lo[2] + slab * height)
    hang = float(new[canopy, 2].min()) if canopy.any() else slab_m
    found_by = "what is joined to the roof" + (", after cutting the posts that stand under a rail again, under the roof" if recut and not whole else "")
    if whole:
        found_by = "what is joined to the roof above one cut through the whole model, at the height just under the roof where the least is crossed (cut post by post, the walk from the roof reached the ground)"
    if leaked:
        found_by = "the plan's cells (the walk from the roof reached the ground)"
    report["shelter"] = {"canopy_underside": round(slab, 3), "end_faces_x": [round(xa, 4), round(xb, 4)], "screen_front_y": round(wall, 4),
                         "bench_top": round(bench, 3), "seat_top": None if seat is None else round(seat, 4), "feet_steps_to": round(foot, 3),
                         "screen_behind_bench_y": None if behind_bench is None else round(behind_bench, 4),
                         "posts_cut_at": [round((v - lo[2]) / high, 3) for v in cut_at], "canopy_found_by": found_by,
                         "post_taken_out_at": None if post_box is None else [round(v, 4) for v in post_box],
                         "parted": {k: {"faces": v[0], "closing_faces": v[1], "left_open": v[2]} for k, v in parted.items()},
                         "band_box": [round(float(v), 3) for v in (b_lo[0], -b_hi[1], b_hi[0], -b_lo[1])], "footprint": [x0, z0, x1, z1],
                         "back_held_to_22cm": len(y_src) == 3,
                         "canopy_lowest_m": round(hang, 3), "canopy_underside_m": round(slab_m, 3), **numbers}
    if floor_share is not None:
        report["shelter"]["floor_sheet_below"] = round(floor_share, 4)
    if posts_before:
        report["shelter"]["posts_before_the_screen_reach_y"] = round(stands_out, 4)
    if post_rule not in (None, "ahead of the bench"):
        report["shelter"]["post_taken_out"] = post_rule
    if hung:
        report["shelter"]["hung_pieces_given_to_the_canopy"] = {"pieces": len(hung), "faces": int(sum(hung))}
    if lifted:
        report["shelter"]["canopy_lifted"] = lifted
    if pressed_feet:
        report["shelter"]["feet_pressed_down"] = pressed_feet
    cut_down_from = canopy_rebuilt(hi, float(given["roof"]), (x0, -z1, x1, -z0, k_lo[2] + clear)) if "roof" in given and canopy.any() else None
    if given.get("back") == "front":
        # A generator closes the back of a glass screen, which the image never showed, with a dark slab. The
        # screen is given its front's picture on its back instead, as if seen through: in the model the colours
        # are baked from, the faces that look to the front in the footprint's back strip, between the end
        # structures, are copied, turned to look back and laid flat a hair behind the back's own faces (copies
        # of the same faces, so the picture is exact; what stood further forward, a post before the glass,
        # lies a hair further out and is found first). The piece is cut down from the model without them.
        if cut_down_from is None:
            only(hi)
            bpy.ops.object.duplicate()
            cut_down_from = bpy.context.view_layer.objects.active
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.normal_update()
        layer = bm.verts.layers.int.get("zone")
        standing_there = [f for f in bm.faces if max(v[layer] for v in f.verts) in (0, 3) and f.calc_center_median().y < -z1 + 0.30
                          and f.calc_center_median().x > x0 + end_w - 0.005]
        fronts = [f for f in standing_there if f.normal.y > 0.7]
        backs = [f for f in standing_there if f.normal.y < -0.7 and f.calc_center_median().y < -z1 + 0.05]
        if fronts and backs:
            bv = list(dict.fromkeys(v for f in backs for v in f.verts))
            at = {v: i for i, v in enumerate(bv)}
            behind_it = BVHTree.FromPolygons([tuple(v.co) for v in bv], [[at[v] for v in f.verts] for f in backs])
            flat_y = float(np.median([f.calc_center_median().y for f in backs]))
            made = bmesh.ops.duplicate(bm, geom=fronts)["geom"]
            for v in (g for g in made if isinstance(g, bmesh.types.BMVert)):
                # where the back's own face lies straight behind this corner: the last one met, which is the outer one
                back_y, start, left = None, v.co.copy(), 0.35
                for _ in range(12):
                    hit = behind_it.ray_cast(start, Vector((0, -1, 0)), left)
                    if hit[0] is None:
                        break
                    back_y, left, start = hit[0].y, left - hit[3] - 1e-4, hit[0] - Vector((0, 1e-4, 0))
                    if left <= 0:
                        break
                back_y = flat_y if back_y is None else back_y
                v.co.y = back_y - 0.002 - 0.01 * (v.co.y - back_y)
            bmesh.ops.reverse_faces(bm, faces=[g for g in made if isinstance(g, bmesh.types.BMFace)])
        bm.to_mesh(me)
        bm.free()
        me.update()
        report["shelter"]["back_painted_as_front"] = {"faces_copied": len(fronts) if backs else 0}
    return (hang - 0.01, slab_m - 0.02), cut_down_from


def size_fountain(hi):
    """The generated fountain sized and taken apart (--fountain): see the top of this file. Works in the model's
    own units and leaves it in metres about its basin's axis. Returns what the piece is cut down from (the
    centre piece alone), the basin's ring and the water's disc (objects)."""
    radius, rim, height = opt("--fountain").split(",")
    radius, rim = float(radius), float(rim)
    height = float(kit_box[1][2] - kit_box[0][2]) if height == "kit" else float(height)
    sides = int(opt("--fountain-sides", "48"))
    me = hi.data
    co, cen, nor, area = mesh_arrays(me)
    water = painted_water(face_colours(hi))
    lo, top = co.min(axis=0), co.max(axis=0)
    high = top[2] - lo[2]
    # The axis: of the circle through the outermost points.
    mid = (lo[:2] + top[:2]) / 2
    r0 = np.hypot(co[:, 0] - mid[0], co[:, 1] - mid[1])
    outer = r0 > 0.93 * r0.max()
    fit = np.linalg.lstsq(np.c_[2 * co[outer, 0], 2 * co[outer, 1], np.ones(outer.sum())], (co[outer, :2] ** 2).sum(axis=1), rcond=None)[0]
    axis = fit[:2]
    r_v, r_c = np.hypot(co[:, 0] - axis[0], co[:, 1] - axis[1]), np.hypot(cen[:, 0] - axis[0], cen[:, 1] - axis[1])
    r_out = float(np.percentile(r_v[outer], 99))
    # The rim's top: where the stone that looks up, out near the wall, mostly lies. A generated model is a shell
    # with an inside, and the inside of its floor looks up too, under the whole basin: of the heights that hold
    # a good share of such stone, the highest is the rim.
    looks_up = nor[:, 2] > 0.9
    on_rim = looks_up & ~water & (r_c > 0.75 * r_out) & (cen[:, 2] < lo[2] + 0.6 * high)
    hist, bins = np.histogram(cen[on_rim, 2], bins=400, range=(lo[2], top[2]), weights=area[on_rim])
    wide_enough = np.convolve(hist, np.ones(5), mode="same")
    highest = int(np.nonzero(wide_enough >= 0.3 * wide_enough.max())[0].max())
    highest = max(highest - 4, 0) + int(np.argmax(hist[max(highest - 4, 0): highest + 1]))
    peak = bins[highest] + (bins[1] - bins[0]) / 2
    near = on_rim & (np.abs(cen[:, 2] - peak) < 0.005 * high)
    rim_z = float(np.average(cen[near, 2], weights=area[near]))
    # The rim's inner edge: how far in its flat top reaches (the generated wall is a shell with an inside of
    # its own, so the wall's faces do not say).
    order = np.argsort(r_c[near])
    r_in = float(r_c[near][order][np.searchsorted(np.cumsum(area[near][order]), 0.02 * area[near].sum())])
    # The water's level in the basin.
    pool = looks_up & water & (r_c > 0.3 * r_out) & (r_c < r_in) & (cen[:, 2] < rim_z)
    if pool.any():
        hist, bins = np.histogram(cen[pool, 2], bins=400, range=(lo[2], top[2]), weights=area[pool])
        wide_enough = np.convolve(hist, np.ones(5), mode="same")          # the highest of the heights that hold a good share, as for the rim
        highest = int(np.nonzero(wide_enough >= 0.3 * wide_enough.max())[0].max())
        highest = max(highest - 4, 0) + int(np.argmax(hist[max(highest - 4, 0): highest + 1]))
        peak = bins[highest] + (bins[1] - bins[0]) / 2
        near = pool & (np.abs(cen[:, 2] - peak) < 0.01 * high)
        level = float(np.average(cen[near, 2], weights=area[near]))
    else:
        level = float(lo[2] + 0.7 * (rim_z - lo[2]))
    gap = rim_z - level
    report["fountain"] = {"axis": [round(float(v), 4) for v in axis], "outer_radius": round(r_out, 4), "rim_top": round((rim_z - lo[2]) / high, 4),
                          "rim_inner_radius": round(r_in, 4), "water_level": round((level - lo[2]) / high, 4),
                          "painted_as_water": round(float(area[water].sum() / area.sum()), 3)}

    def loose_bits_out(obj, share):
        """Drops the loose parts of a mesh smaller than `share` of its largest (by area)."""
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        seen, found = set(), []
        for f in bm.faces:
            if f in seen:
                continue
            stack, isl, a = [f], [], 0.0
            seen.add(f)
            while stack:
                g = stack.pop()
                isl.append(g)
                a += g.calc_area()
                for e in g.edges:
                    for h in e.link_faces:
                        if h not in seen:
                            seen.add(h)
                            stack.append(h)
            found.append((a, isl))
        most = max(a for a, _ in found)
        doomed = [f for a, isl in found if a < share * most for f in isl]
        if doomed:
            bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
        return len(found), sum(1 for a, _ in found if a < share * most)

    # Still water lies flat: the generator models the water standing in a bowl or a trough with its ripples,
    # and cut down they are lumps. Each patch of water that looks up, above the basin, is levelled at its own
    # mean height (the vertices on its edge, where it meets stone or falling water, stay).
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    still = [f for f in bm.faces if water[f.index] and nor[f.index, 2] > 0.8 and cen[f.index, 2] > level + 0.4 * gap]
    lying, seen, levelled = set(still), set(), 0
    for f in still:
        if f in seen:
            continue
        stack, patch = [f], []
        seen.add(f)
        while stack:
            g = stack.pop()
            patch.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h in lying and h not in seen:
                        seen.add(h)
                        stack.append(h)
        size = sum(area[g.index] for g in patch)
        heights = [cen[g.index, 2] for g in patch]
        if size < 1e-4 * area.sum() or max(heights) - min(heights) > 0.02 * high:
            continue                                     # a speck; or not lying flat at all (something blue that is not water: a tilted panel)
        z = sum(area[g.index] * cen[g.index, 2] for g in patch) / size
        own = set(patch)
        for v in dict.fromkeys(v for g in patch for v in g.verts):
            if all(h in own for h in v.link_faces):
                v.co.z = z
        levelled += 1
    bm.to_mesh(me)
    bm.free()
    me.update()
    report["fountain"]["still_water_patches_levelled"] = levelled

    falls = opt("--fountain-falls", "keep")
    if falls == "drop":
        # The falling water and the jet come out of the model itself (the colours are baked from it, and a
        # stone face beside a sheet of water would take the water's colour): what was painted as water and
        # does not lie flat. The holes they leave in the stone and in the still water are closed.
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.faces.ensure_lookup_table()
        falling = [f for f in bm.faces if water[f.index] and nor[f.index, 2] <= 0.8 and cen[f.index, 2] > level + 0.4 * gap]
        chosen = set(falling)
        border = [e for e in bm.edges if any(f in chosen for f in e.link_faces) and any(f not in chosen for f in e.link_faces)]
        bmesh.ops.delete(bm, geom=falling, context="FACES")
        open_edges = [e for e in border if e.is_valid and len(e.link_faces) == 1]
        caps = bmesh.ops.holes_fill(bm, edges=open_edges, sides=0)["faces"] if open_edges else []
        report["fountain"]["falls_out"] = {"faces": len(falling), "closing_faces": len(caps), "left_open": sum(1 for e in open_edges if e.is_valid and len(e.link_faces) == 1)}
        bm.to_mesh(me)
        bm.free()
        me.update()
        co, cen, nor, area = mesh_arrays(me)
        water = painted_water(face_colours(hi))
        r_v, r_c = np.hypot(co[:, 0] - axis[0], co[:, 1] - axis[1]), np.hypot(cen[:, 0] - axis[0], cen[:, 1] - axis[1])
    # What the piece is cut down from: the model without its basin's wall (built by rule) and without the
    # water in the basin and its splashes (one flat disc instead).
    only(hi)
    bpy.ops.object.duplicate()
    centre = bpy.context.view_layer.objects.active
    centre.name = "centre"
    bm = bmesh.new()
    bm.from_mesh(centre.data)
    bm.faces.ensure_lookup_table()
    out = [f for f in bm.faces if r_c[f.index] > r_in - 0.03 * r_out or (water[f.index] and cen[f.index, 2] < level + 0.4 * gap) or cen[f.index, 2] < level - 0.2 * gap]
    bmesh.ops.delete(bm, geom=out, context="FACES")
    # Where the centre piece and its falling water met the basin's water they are now open: each open edge
    # near the water's level is carried down under the disc, so no gap shows round a foot or a stream.
    # (Built here edge by edge, in the mesh's own order. The mesh operator that extrudes edges makes its faces
    # in the order of a table keyed by memory addresses, which differs from one run to the next: the piece was
    # then cut down from a mesh whose faces stood in another order, and no two builds were the same file.)
    low_edges = [e for e in bm.edges if len(e.link_faces) == 1 and all(v.co.z < level + 0.6 * gap for v in e.verts)]
    under = {}
    for e in low_edges:
        for v in e.verts:
            if v not in under:
                under[v] = bm.verts.new((v.co.x, v.co.y, level - 0.5 * gap))
    for e in low_edges:
        first = e.link_loops[0].vert                     # the face on this edge runs from `first` to the other end
        other = e.other_vert(first)
        try:
            bm.faces.new((other, first, under[first], under[other]))          # the skirt's face runs the other way along it
        except ValueError:
            pass
    bm.to_mesh(centre.data)
    bm.free()
    centre.data.update()
    report["fountain"]["loose_bits"] = dict(zip(("parts", "dropped"), loose_bits_out(centre, 0.03)))
    report["fountain"]["skirt_edges"] = len(low_edges)

    # ---- Sizes: the wall to the footprint's radius, the rim's top to its height, the rest evenly up to the height asked ----
    scale = radius / r_out
    # Heights: the ground, the rim's top, the top. With --fountain-level the water's own level is a fourth
    # mark: a model whose basin is deeper than its design drew it (a saucer three cubes deep where the sheet
    # has one) has its water, and what stands and splashes in it, raised to the height given.
    z_marks, z_goes = [lo[2], rim_z, top[2]], [0.0, rim, height]
    if opt("--fountain-level") and lo[2] < level < rim_z and 0.0 < float(opt("--fountain-level")) - 0.01 < rim:
        z_marks, z_goes = [lo[2], level, rim_z, top[2]], [0.0, float(opt("--fountain-level")) - 0.01, rim, height]          # the disc lies a centimetre over the level
    def placed(obj):
        own = mesh_arrays(obj.data)[0]
        new = np.empty_like(own)
        new[:, 0], new[:, 1] = (own[:, 0] - axis[0]) * scale, (own[:, 1] - axis[1]) * scale
        new[:, 2] = piecewise(own[:, 2], z_marks, z_goes)
        obj.data.vertices.foreach_set("co", new.ravel())
        obj.data.update()
    placed(hi)
    placed(centre)
    level_m = float(piecewise([level], z_marks, z_goes)[0])
    inner = float(np.clip(r_in * scale, radius - 0.5, radius - 0.10))
    # The ring: outer wall, flat top, inner wall down to under the water. Four upright seams in each wall, so
    # that the walls lie in the texture as four short strips and not one long one.
    bm = bmesh.new()
    rings = []
    for r, z in ((radius, 0.0), (radius, rim), (inner, rim), (inner, max(level_m - 0.12, 0.0))):
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * k / sides), r * math.sin(2 * math.pi * k / sides), z)) for k in range(sides)])
    for a, b in ((0, 1), (1, 2), (2, 3)):
        for k in range(sides):
            bm.faces.new((rings[a][k], rings[a][(k + 1) % sides], rings[b][(k + 1) % sides], rings[b][k]))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.edges.ensure_lookup_table()
    for a, b in ((0, 1), (2, 3)):
        for k in range(0, sides, max(sides // 4, 1)):
            e = bm.edges.get((rings[a][k], rings[b][k]))
            if e is not None:
                e.seam = True
    ring_mesh = bpy.data.meshes.new("ring")
    bm.to_mesh(ring_mesh)
    bm.free()
    mark = ring_mesh.attributes.new("is_ring", "INT", "FACE")
    for item in mark.data:
        item.value = 1
    ring = bpy.data.objects.new("ring", ring_mesh)
    bpy.context.scene.collection.objects.link(ring)
    # The disc: a little into the wall, a little over the measured level (the generated surface is not flat).
    bm = bmesh.new()
    bm.faces.new([bm.verts.new(((inner + 0.02) * math.cos(2 * math.pi * k / sides), (inner + 0.02) * math.sin(2 * math.pi * k / sides), level_m + 0.01)) for k in range(sides)])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    if bm.faces[:][0].normal.z < 0:
        bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    disc_mesh = bpy.data.meshes.new("water_disc")
    bm.to_mesh(disc_mesh)
    bm.free()
    mark = disc_mesh.attributes.new("is_pool", "INT", "FACE")
    for item in mark.data:
        item.value = 1
    disc = bpy.data.objects.new("water_disc", disc_mesh)
    bpy.context.scene.collection.objects.link(disc)
    report["fountain"].update({"scale": round(scale, 4), "ring": {"outer_m": radius, "inner_m": round(inner, 3), "top_m": rim, "sides": sides},
                               "water_level_m": round(level_m + 0.01, 3), "height_m": height, "falls": falls})
    return centre, ring, disc


def mend_tangents(path):
    """Replaces the zero tangents in a written GLB by unit vectors square to their normals; returns how many."""
    import struct
    data = bytearray(Path(path).read_bytes())
    n_json = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(bytes(data[20:20 + n_json]))
    base = 20 + n_json + 8
    def place(index):
        a = doc["accessors"][index]
        view = doc["bufferViews"][a["bufferView"]]
        width = {"VEC3": 3, "VEC4": 4}[a["type"]]
        return base + view.get("byteOffset", 0) + a.get("byteOffset", 0), view.get("byteStride", 4 * width), a["count"]
    mended = 0
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            at = prim["attributes"]
            if "TANGENT" not in at or "NORMAL" not in at:
                continue
            (t_at, t_step, count), (n_at, n_step, _) = place(at["TANGENT"]), place(at["NORMAL"])
            for k in range(count):
                tx, ty, tz, _w = struct.unpack_from("<4f", data, t_at + k * t_step)
                if tx * tx + ty * ty + tz * tz > 0.25:
                    continue
                nx, ny, nz = struct.unpack_from("<3f", data, n_at + k * n_step)
                ax = (0.0, 1.0, 0.0) if abs(ny) < 0.9 else (1.0, 0.0, 0.0)
                cx, cy, cz = ax[1] * nz - ax[2] * ny, ax[2] * nx - ax[0] * nz, ax[0] * ny - ax[1] * nx
                length = math.sqrt(cx * cx + cy * cy + cz * cz) or 1.0
                struct.pack_into("<4f", data, t_at + k * t_step, cx / length, cy / length, cz / length, 1.0)
                mended += 1
    if mended:
        Path(path).write_bytes(bytes(data))
    return mended


def band_from_above(objs, z0=0.15, z1=2.2):
    """What the game measures of a piece where people walk (kit_town.gd _band_points), from above: every vertex
    between the two heights and every point where an edge crosses one of them, as (x, y) in Blender's axes."""
    found = [np.zeros((0, 2))]
    for o in objs:
        if o.type != "MESH" or not len(o.data.vertices):
            continue
        v = world_verts([o])
        found.append(v[(v[:, 2] >= z0) & (v[:, 2] <= z1)][:, :2])
        e = np.empty(len(o.data.edges) * 2, dtype=np.int32)
        o.data.edges.foreach_get("vertices", e)
        a, b = v[e[0::2]], v[e[1::2]]
        rise = b[:, 2] - a[:, 2]
        for level in (z0, z1):
            with np.errstate(divide="ignore", invalid="ignore"):
                f = (level - a[:, 2]) / rise
            crosses = (rise != 0) & (f > 0) & (f < 1)
            found.append((a[crosses] + (b[crosses] - a[crosses]) * f[crosses][:, None])[:, :2])
    return np.concatenate(found)


def band_reach(objs):
    """How far from its origin a piece draws where people walk (kit_town.gd band_reach)."""
    pts_ = band_from_above(objs)
    return float(np.hypot(pts_[:, 0], pts_[:, 1]).max()) if len(pts_) else 0.0


# ---- The kit piece: its box, its look from above, its name ----
reset()
kit_box = None
kit_map = None
kit_seat = None
kit_back = None
kit_bench = None
kit_reach = None
if kit_path:
    kit_objs = load(kit_path)
    if opt("--shrub") == "kit":
        kit_reach = band_reach(kit_objs)
    if "--seat" in argv:
        kit_seat = seat_top_of([o for o in kit_objs if o.type == "MESH" and o.name.split(".")[0] not in ("light", "lights")])
    if opt("--shelter-bench"):
        # The top of the kit shelter's bench: where rays dropped inside the bench's rectangle from under its
        # back rail mostly land (the canopy is above where they start).
        bx0, bz0, bx1, bz1 = (float(v) for v in opt("--shelter-bench").split(",")[:4])
        k_verts, k_polys = [], []
        for o in (o for o in kit_objs if o.type == "MESH"):
            base = len(k_verts)
            k_verts += [o.matrix_world @ v.co for v in o.data.vertices]
            k_polys += [[base + i for i in poly.vertices] for poly in o.data.polygons]
        k_tree = BVHTree.FromPolygons([tuple(v) for v in k_verts], k_polys)
        landed = []
        for i in range(21):
            for j in range(7):
                hit = k_tree.ray_cast(Vector((bx0 + 0.1 + (bx1 - bx0 - 0.2) * i / 20, -(bz0 + 0.05 + (bz1 - bz0 - 0.1) * j / 6), 0.62)), Vector((0, 0, -1)))
                if hit[0] is not None and hit[0].z > 0.2:
                    landed.append(hit[0].z)
        if landed:
            values, counts = np.unique(np.round(np.array(landed) / 0.005).astype(int), return_counts=True)
            kit_bench = float(values[np.argmax(counts)] * 0.005)
        report["kit_bench_top_m"] = kit_bench
    kp = world_verts(kit_objs)
    if "--kit-body-box" in argv:
        kp = world_verts([o for o in kit_objs if o.name.split(".")[0] not in ("light", "lights")])
    kit_box = (kp.min(axis=0), kp.max(axis=0))
    kit_map = height_map(kp)
    # Which way it faces: its tall part (a seat's back) is off the box's middle towards its back.
    kit_tall = kp[kp[:, 2] > kp[:, 2].min() + 0.7 * (kp[:, 2].max() - kp[:, 2].min())]
    kit_off = kit_tall[:, :2].mean(axis=0) - (kp[:, :2].min(axis=0) + kp[:, :2].max(axis=0)) / 2
    kit_back = (int(np.argmax(np.abs(kit_off))), float(np.sign(kit_off[int(np.argmax(np.abs(kit_off)))]) or 1.0))
    roots = [o for o in kit_objs if o.parent is None]
    if name is None and roots:
        name = roots[0].name
    report["kit_tris"] = int(sum(tri_count(o) for o in kit_objs if o.type == "MESH"))
    report["kit_light_parts"] = sorted(o.name for o in kit_objs if o.type == "MESH" and o.name.split(".")[0] in ("light", "lights"))
    reset()
elif opt("--size"):
    sx, sy, sz = (float(v) for v in opt("--size").split(","))      # glTF width, height, depth -> Blender x, z, y
    kit_box = (np.array([-sx / 2, -sz / 2, 0.0]), np.array([sx / 2, sz / 2, sy]))
name = name or out.stem

# ---- The generated model ----
objs = [o for o in load(raw) if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
if len(objs) > 1:
    bpy.ops.object.join()
hi = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
hi.name = "generated"
report["raw_tris"] = tri_count(hi)

# The generator paints a metal map too, and marks whole pieces as metal when the image is a night scene (a neon
# tree 0.99, a neon chair 0.93). A metal has no colour of its own to bake: the colour pass returns black. The
# game's pieces are not metal; read the painted colour alone.
metal = []
for m in hi.data.materials:
    if m is None or not m.use_nodes:
        continue
    for node in m.node_tree.nodes:
        if node.type == "BSDF_PRINCIPLED":
            socket = node.inputs["Metallic"]
            metal.append(bool(socket.is_linked))
            for link in list(socket.links):
                m.node_tree.links.remove(link)
            socket.default_value = 0.0
report["metal_map_ignored"] = any(metal)

# The generator's mesh comes split along the seams of its UV charts: weld those first (the UVs stay, they
# belong to face corners), or every chart counts as a loose part and the cut-down mesh opens along them.
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=1e-6)
bpy.ops.object.mode_set(mode="OBJECT")

# Loose crumbs the generator leaves beside the object.
bm = bmesh.new()
bm.from_mesh(hi.data)
bm.faces.ensure_lookup_table()
seen, islands = set(), []
for f in bm.faces:
    if f.index in seen:
        continue
    stack, island, area = [f], [], 0.0
    seen.add(f.index)
    while stack:
        g = stack.pop()
        island.append(g)
        area += g.calc_area()
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    islands.append((area, island))
if opt("--object") and len(islands) > 1:
    # The loose parts gathered into objects by where they stand: two parts whose boxes from above overlap (a
    # hundredth of the model's size allowed between them) belong to one object, and so does a part's inner skin.
    boxes = []
    for _area, isl in islands:
        cs = np.array([v.co[:] for f in isl for v in f.verts])
        boxes.append((cs.min(axis=0), cs.max(axis=0)))
    whole = np.array([b[1] for b in boxes]).max(axis=0) - np.array([b[0] for b in boxes]).min(axis=0)
    slack = 0.01 * float(whole.max())
    group = list(range(len(islands)))
    def root_of(i):
        while group[i] != i:
            group[i] = group[group[i]]
            i = group[i]
        return i
    for i in range(len(islands)):
        for j in range(i):
            if all(boxes[i][0][k] <= boxes[j][1][k] + slack and boxes[j][0][k] <= boxes[i][1][k] + slack for k in (0, 1)):
                group[root_of(i)] = root_of(j)
    objects = {}
    for i in range(len(islands)):
        objects.setdefault(root_of(i), []).append(i)
    described = []
    for members in objects.values():
        lo_o = np.array([boxes[i][0] for i in members]).min(axis=0)
        hi_o = np.array([boxes[i][1] for i in members]).max(axis=0)
        described.append({"parts": members, "height": float(hi_o[2] - lo_o[2]), "area": float(sum(islands[i][0] for i in members))})
    by = {"shortest": lambda o: o["height"], "tallest": lambda o: -o["height"], "largest": lambda o: -o["area"], "smallest": lambda o: o["area"]}[opt("--object")]
    kept_object = min(described, key=by)
    report["objects"] = {"found": len(described), "kept": opt("--object"), "heights": [round(o["height"], 4) for o in described], "kept_height": round(kept_object["height"], 4)}
    gone = [f for i in range(len(islands)) if i not in kept_object["parts"] for f in islands[i][1]]
    islands = [islands[i] for i in kept_object["parts"]]
    if gone:
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bm.to_mesh(hi.data)
total = sum(a for a, _ in islands)
crumbs = [isl for a, isl in islands if a < drop_below * total]
report["loose_parts"] = len(islands)
report["dropped_parts"] = len(crumbs)
report["dropped_area_share"] = round(float(sum(a for a, _ in islands if a < drop_below * total) / total), 4)
if not opt("--tree") and not opt("--planted") and "--keep-strays" not in argv and len(islands) > 1:
    # The generator makes things of whatever else was in the image: the colour swatches under the object come
    # out as slabs on the ground, the edge of a neighbour as a lump. A loose part whose middle lies outside the
    # box of the largest part (a twentieth wider each way) is such a stray, and goes. Not for a tree, whose
    # leaf masses are loose parts of their own.
    def box_of(isl):
        cs = np.array([v.co[:] for f in isl for v in f.verts])
        return cs.min(axis=0), cs.max(axis=0)
    main_lo, main_hi = box_of(max(islands, key=lambda t: t[0])[1])
    pad = 0.05 * (main_hi - main_lo)
    kept_ids = {id(isl) for isl in crumbs}
    strays, stray_area = [], 0.0
    for area, isl in islands:
        if id(isl) in kept_ids:
            continue
        lo_i, hi_i = box_of(isl)
        mid = (lo_i + hi_i) / 2
        if ((mid < main_lo - pad) | (mid > main_hi + pad)).any():
            strays.append(isl)
            stray_area += area
    report["stray_parts"] = len(strays)
    report["stray_area_share"] = round(float(stray_area / total), 4)
    crumbs = crumbs + strays
if crumbs:
    bmesh.ops.delete(bm, geom=[f for isl in crumbs for f in isl], context="FACES")
    bm.to_mesh(hi.data)
bm.free()

def close_cut(bmp, rim, axis, at, outward):
    """Closes what a level cut leaves open. A generated model is a shell with a skin inside it: a cut crosses
    each member twice, its outside and the skin within. Each outline the cut leaves (edges joined end to end)
    is closed by a fan of faces from its middle, except an outline that lies within another: closing the outer
    one closes the member. `rim` are the cut's edges, `axis` the axis the cut is square to (0 or 2), `at` where
    it lies on that axis, `outward` (1 or -1) the way the closing faces look. Returns the faces made."""
    ua, va = [k for k in range(3) if k != axis]
    uv_l = bmp.loops.layers.uv.active
    on_rim, outlines = set(rim), []
    left = set(rim)
    for first in rim:                                    # in the mesh's own order, so that the same model gives the same file
        if first not in left:
            continue
        left.discard(first)
        stack, group = [first], []
        while stack:
            e = stack.pop()
            group.append(e)
            for v in e.verts:
                for other in v.link_edges:
                    if other in left:
                        left.discard(other)
                        stack.append(other)
        cs = np.array([v.co[:] for e in group for v in e.verts])[:, [ua, va]]
        outlines.append((group, cs.min(axis=0), cs.max(axis=0)))
    caps, cap_set = [], set()
    for group, lo_c, hi_c in outlines:
        if any(other is not group and (o_lo <= lo_c).all() and (o_hi >= hi_c).all() and ((o_lo < lo_c).any() or (o_hi > hi_c).any())
               for other, o_lo, o_hi in outlines):
            continue                                     # the skin inside a member
        around = list(dict.fromkeys(v for e in group for v in e.verts))
        middle = np.mean([(v.co[ua], v.co[va]) for v in around], axis=0)
        place = [0.0, 0.0, 0.0]
        place[axis], place[ua], place[va] = at, float(middle[0]), float(middle[1])
        centre = bmp.verts.new(Vector(place))
        # An outline can be open (a low wall with no face underneath is cut as three sides): the stretches of
        # its convex outline that no edge runs along are closed as well.
        joined = {frozenset(e.verts) for e in group}
        def turn(p, q, r):
            return (q.co[ua] - p.co[ua]) * (r.co[va] - p.co[va]) - (q.co[va] - p.co[va]) * (r.co[ua] - p.co[ua])
        hull_v = []
        for v in sorted(around, key=lambda v: (v.co[ua], v.co[va])):
            while len(hull_v) >= 2 and turn(hull_v[-2], hull_v[-1], v) <= 0:
                hull_v.pop()
            hull_v.append(v)
        upper_v = []
        for v in sorted(around, key=lambda v: (v.co[ua], v.co[va]), reverse=True):
            while len(upper_v) >= 2 and turn(upper_v[-2], upper_v[-1], v) <= 0:
                upper_v.pop()
            upper_v.append(v)
        hull_v = hull_v[:-1] + upper_v[:-1]
        reach = max(float(np.ptp([v.co[ua] for v in around])), float(np.ptp([v.co[va] for v in around])), 1e-6)
        gaps = [(p, q) for p, q in zip(hull_v, hull_v[1:] + hull_v[:1]) if p is not q and frozenset((p, q)) not in joined
                and (p.co - q.co).length > 0.02 * reach
                and sum(1 for e in p.link_edges if e in on_rim) < 2 and sum(1 for e in q.link_edges if e in on_rim) < 2]
        # The closing faces take one colour, that of the largest face of the member that meets the cut and does
        # not look down (the generator paints undersides dark): a patch of its texture a texel across.
        sides = list(dict.fromkeys(f for v in around for f in v.link_faces if f not in cap_set and f.normal.z > -0.5))
        shown = max(sides, key=lambda f: f.calc_area()) if sides else None
        at_uv = np.mean([l[uv_l].uv[:] for l in shown.loops], axis=0) if shown is not None else np.zeros(2)
        for pair in [tuple(e.verts) for e in group] + gaps:
            face = bmp.faces.new((centre, pair[0], pair[1]))
            face.normal_update()
            if face.normal[axis] * outward < 0:
                face.normal_flip()
            for loop in face.loops:
                loop[uv_l].uv = (at_uv[0] + 0.5 / 1024 * (loop.vert.co[ua] - centre.co[ua]) / reach, at_uv[1] + 0.5 / 1024 * (loop.vert.co[va] - centre.co[va]) / reach)
            caps.append(face)
            cap_set.add(face)
    return caps


def panel_ends(p, n=240):
    """A fence panel's make-up along its length (x): which of its slices stand on the ground, and the run of
    such slices at each end (a post). Rails and balusters hang clear of the ground between the posts; the
    height they hang at is the middle value of the slices' lowest points over the middle of the length. Gives
    (hang, low end, high end), each end None or {"x0", "x1", "top"}: the extent of what stands on the ground
    there and the greatest height over it.

    A panel that stands on the ground all along (a low wall under its rails) has no such height. Its posts
    are then the slices that are filled, unbroken, from the ground to seven tenths of the panel's height or
    more (the wall stops lower, and there is air between the rails above it); the extent is that of those
    slices."""
    x0, x1, z0 = float(p[:, 0].min()), float(p[:, 0].max()), float(p[:, 2].min())
    idx = np.minimum(((p[:, 0] - x0) / max(x1 - x0, 1e-9) * n).astype(int), n - 1)
    z_min, z_max = np.full(n, np.inf), np.full(n, -np.inf)
    np.minimum.at(z_min, idx, p[:, 2])
    np.maximum.at(z_max, idx, p[:, 2])
    middle = z_min[int(0.2 * n): int(0.8 * n)]
    hang = float(np.median(middle[np.isfinite(middle)])) - z0
    height = float(p[:, 2].max() - z0)
    if hang < 0.02 * height:
        bins = 60
        filled = np.zeros((n, bins), dtype=bool)
        filled[idx, np.minimum(((p[:, 2] - z0) / height * bins).astype(int), bins - 1)] = True
        rise = np.zeros(n)
        for i in range(n):
            if not filled[i, :3].any():
                continue
            top = gap = 0
            for b in range(bins):
                if filled[i, b]:
                    top, gap = b + 1, 0
                elif top:
                    gap += 1
                    if gap > 1:
                        break
            rise[i] = top / bins * height
        post = rise >= 0.7 * height
        ends = []
        for side in (0, 1):
            order = range(n) if side == 0 else range(n - 1, -1, -1)
            run = []
            for i in order:
                if post[i]:
                    run.append(i)
                elif run or abs(i - (0 if side == 0 else n - 1)) > 0.2 * n:
                    break
            if not run:
                ends.append(None)
                continue
            a, b = min(run), max(run)
            ends.append({"x0": x0 + a / n * (x1 - x0), "x1": x0 + (b + 1) / n * (x1 - x0), "top": float(z_max[a:b + 1].max() - z0)})
        return hang, ends[0], ends[1]
    level = z0 + 0.5 * hang
    grounded = z_min < level
    ends = []
    for side in (0, 1):
        order = range(n) if side == 0 else range(n - 1, -1, -1)
        run = []
        for i in order:
            if grounded[i]:
                run.append(i)
            elif run or len(run) == 0 and abs(i - (0 if side == 0 else n - 1)) > 0.2 * n:
                break
        if not run:
            ends.append(None)
            continue
        a, b = min(run), max(run)
        here = p[(idx >= a) & (idx <= b)]
        low = here[here[:, 2] < level]
        ends.append({"x0": float(low[:, 0].min()), "x1": float(low[:, 0].max()), "top": float(here[:, 2].max() - z0)})
    return hang, ends[0], ends[1]


def post_axis(p):
    """Where a post's axis stands (x, y): the median of the middles of its slices between 3% and 50% of its
    height. The middle of its box is its axis only while nothing on it reaches further to one side."""
    lo_z, span_z = float(p[:, 2].min()), float(np.ptp(p[:, 2]))
    mids = []
    for i in range(24):
        a_z, b_z = (lo_z + (0.03 + 0.47 * (i + j) / 24) * span_z for j in (0, 1))
        sl = p[(p[:, 2] >= a_z) & (p[:, 2] < b_z)]
        if len(sl) >= 12:
            mids.append((sl[:, :2].min(axis=0) + sl[:, :2].max(axis=0)) / 2)
    return np.median(np.array(mids), axis=0)


if "--drop-plate" in argv:
    # The plate: from the ground up, the slices (fiftieths of the height) that are more than twice as wide as the
    # middle value of the slices in the upper two thirds.
    plate_pts = world_verts([hi])
    z_lo, z_span = float(plate_pts[:, 2].min()), float(np.ptp(plate_pts[:, 2]))
    widths = []
    for i in range(50):
        sl = plate_pts[(plate_pts[:, 2] >= z_lo + z_span * i / 50) & (plate_pts[:, 2] < z_lo + z_span * (i + 1) / 50)]
        widths.append(float(max(np.ptp(sl[:, 0]), np.ptp(sl[:, 1]))) if len(sl) else 0.0)
    body = float(np.median([w for w in widths[17:] if w > 0]))
    top = 0
    while top < 25 and widths[top] > 2 * body:
        top += 1
    report["plate_dropped"] = None
    if top:
        z_cut = z_lo + z_span * top / 50 + 0.002 * z_span
        bmp = bmesh.new()
        bmp.from_mesh(hi.data)
        res = bmesh.ops.bisect_plane(bmp, geom=list(bmp.verts) + list(bmp.edges) + list(bmp.faces), dist=1e-7,
                                     plane_co=(0.0, 0.0, z_cut), plane_no=(0.0, 0.0, -1.0), clear_outer=True, clear_inner=False)
        close_cut(bmp, [g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMEdge)], 2, z_cut, -1.0)
        bmp.to_mesh(hi.data)
        bmp.free()
        hi.data.update()
        report["plate_dropped"] = {"share_of_height": round(top / 50, 2), "plate_across": round(max(widths[:top]), 3), "object_across": round(body, 3)}

# Which way round: the quarter turn whose look from above agrees best with the kit piece's.
pts = world_verts([hi])
if forced_yaw is not None:
    yaw = float(forced_yaw)
    report["yaw_scores"] = None
elif "--arm-at-x" in argv:
    # How far the upper half reaches from the axis each way (+x, +y, -x, -y); the way that reaches furthest by
    # a quarter more than the next is the arm's, and is turned to +x.
    ax = post_axis(pts)
    upper = pts[pts[:, 2] > pts[:, 2].min() + 0.5 * np.ptp(pts[:, 2])]
    reach = [float((upper[:, 0] - ax[0]).max()), float((upper[:, 1] - ax[1]).max()), float((ax[0] - upper[:, 0]).max()), float((ax[1] - upper[:, 1]).max())]
    arm = int(np.argmax(reach))
    yaw = float((360 - 90 * arm) % 360) if reach[arm] > 1.25 * sorted(reach)[-2] else 0.0
    report["yaw_scores"] = None
    report["arm"] = {"reach_each_way": [round(v, 4) for v in reach], "turn": yaw}
elif "--panel" in argv:
    # A fence panel: its long side along x, its own post at -x. Its own post is the end that stands on the
    # ground and reaches highest (it carries the finial); where both reach alike, the longer of the two.
    ext = pts.max(axis=0) - pts.min(axis=0)
    yaw = 0.0 if ext[0] >= ext[1] else 90.0
    _hang, end_lo, end_hi = panel_ends(turned(pts, yaw))
    height = float(ext[2])
    def weight(e):
        return (-1.0, 0.0) if e is None else (round(e["top"] / (0.03 * height)), e["x1"] - e["x0"])
    if weight(end_hi) > weight(end_lo):
        yaw += 180.0
    report["yaw_scores"] = None
    report["panel_turn"] = {"ends_m": [None if e is None else {k: round(v, 4) for k, v in e.items()} for e in (end_lo, end_hi)], "turn": yaw}
elif kit_map is not None:
    scores = {deg: float(np.abs(height_map(turned(pts, deg)) - kit_map).mean()) for deg in (0, 90, 180, 270)}
    yaw = min(scores, key=scores.get)
    report["yaw_scores"] = {str(k): round(v, 4) for k, v in scores.items()}
    # A plain block looks the same from above whichever way it is turned. Among the turns that agree with the
    # kit piece as well as the best does (within half a per cent), the one that stretches the piece least to
    # fill the kit's box is taken: a seat stone drawn 55 by 30 goes into the kit's 30 by 55 box turned, not
    # squeezed to a third.
    def stretch_of(deg):
        t = turned(pts, deg)
        sc = (kit_box[1] - kit_box[0]) / np.maximum(t.max(axis=0) - t.min(axis=0), 1e-9)
        return float(sc.max() / sc.min())
    close = [deg for deg in (0, 90, 180, 270) if scores[deg] <= scores[yaw] * 1.005]
    if len(close) > 1:
        yaw = min(close, key=lambda deg: (round(stretch_of(deg), 3), deg != yaw, deg))
        report["yaw_by_least_stretch"] = {str(deg): round(stretch_of(deg), 3) for deg in close}
else:
    yaw = 0.0
if ("--feet-off-x" in argv or "--feet-on-x" in argv) and "--stem" in argv:
    # A café table's chairs stand on its two x sides: its feet are turned to point between them. An umbrella's
    # square base under such a table is turned the other way, a corner along x, so that it lies between them.
    zone = stem_zones(turned(pts, yaw))
    if zone is not None:
        extra, report["feet"] = feet_turn(turned(pts, yaw), zone, on_x="--feet-on-x" in argv)
        report["feet"]["turned_deg"] = round(extra, 1)
        yaw += extra
hi.matrix_world = Matrix.Rotation(math.radians(yaw), 4, "Z") @ hi.matrix_world
only(hi)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

if "--panel" in argv:
    # The far post goes: the game lays the panels end to end, each bringing its own post at -x, and the next
    # panel's post stands where this one's far post is drawn. The cut is made where the far post's foot begins
    # (the first place from that end where nothing stands on the ground), so it crosses the rails alone; they
    # are closed there, and the closing faces take the colour of the rail beside them.
    _hang, _own, far = panel_ends(world_verts([hi]))
    report["panel"] = {"far_post_cut": None}
    length = float(np.ptp(world_verts([hi])[:, 0]))
    if far is not None and far["x1"] - far["x0"] < 0.25 * length:
        x_cut = far["x0"] - 0.002 * length
        bmp = bmesh.new()
        bmp.from_mesh(hi.data)
        res = bmesh.ops.bisect_plane(bmp, geom=list(bmp.verts) + list(bmp.edges) + list(bmp.faces), dist=1e-7,
                                     plane_co=(x_cut, 0.0, 0.0), plane_no=(1.0, 0.0, 0.0), clear_outer=True, clear_inner=False)
        rim = [g for g in res["geom_cut"] if isinstance(g, bmesh.types.BMEdge)]
        caps = close_cut(bmp, rim, 0, x_cut, 1.0)
        bmp.to_mesh(hi.data)
        bmp.free()
        hi.data.update()
        report["panel"]["far_post_cut"] = {"at_share_of_length": round((x_cut - float(world_verts([hi])[:, 0].min())) / length, 4),
                                           "far_post_m": [round(far["x0"], 4), round(far["x1"], 4)], "rail_ends_closed_with_faces": len(caps)}

# Size and place: fill the kit piece's box (or scale evenly to its width and stand on the ground).
pts = world_verts([hi])
lo, hi_pt = pts.min(axis=0), pts.max(axis=0)
span = hi_pt - lo
zone = stem_zones(pts) if ("--stem" in argv and kit_box is not None) else None
if "--stem" in argv and zone is None:
    report["stem"] = None
cut_from = hi                    # what the piece is cut down from: the whole generated model, unless a rule leaves parts of it out
basin_ring = water_disc = lamp_heights = None
if opt("--tree"):
    bed_w, bed_d, bed_h, crown_w, tree_h = (float(v) for v in opt("--tree").split(","))
    n = 60
    frac = (pts[:, 2] - lo[2]) / span[2]
    widths = np.zeros(n)
    for i in range(n):
        sl = pts[(frac >= i / n) & (frac < (i + 1) / n)]
        if len(sl):
            widths[i] = max(sl[:, 0].max() - sl[:, 0].min(), sl[:, 1].max() - sl[:, 1].min())
    base = widths[:3].max()
    bed_top_i = 0
    while bed_top_i + 1 < n // 2 and widths[bed_top_i + 1] >= 0.93 * base:      # the run of full-width slices from the ground
        bed_top_i += 1
    narrow_i = bed_top_i + 1 + int(np.argmin(widths[bed_top_i + 1: n // 2]))
    bed_top, narrow = (bed_top_i + 1) / n, (narrow_i + 0.5) / n
    crown_from = min(narrow + 0.08, 0.6)
    bed = pts[frac <= bed_top]
    bed_lo, bed_hi = bed.min(axis=0), bed.max(axis=0)
    centre = (bed_lo[:2] + bed_hi[:2]) / 2
    crown = pts[frac >= crown_from]
    crown_span = max(crown[:, 0].max() - crown[:, 0].min(), crown[:, 1].max() - crown[:, 1].min())
    s_bed = np.array([bed_w / (bed_hi[0] - bed_lo[0]), bed_d / (bed_hi[1] - bed_lo[1])])
    s_crown = crown_w / crown_span
    # Heights: the bed's wall to BED metres, the rest evenly up to HEIGHT.
    z_bed = bed_top * span[2]
    up = (tree_h - bed_h) / (span[2] - z_bed)
    me = hi.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    f = (co[:, 2] - lo[2]) / span[2]
    t = np.clip((f - narrow) / (crown_from - narrow), 0, 1)[:, None]          # 0 in the bed and trunk foot, 1 in the crown
    sxy = s_bed[None, :] * (1 - t) + s_crown * t
    new = np.empty_like(co)
    new[:, :2] = (co[:, :2] - centre) * sxy
    h = co[:, 2] - lo[2]
    new[:, 2] = np.where(h <= z_bed, h * (bed_h / z_bed), bed_h + (h - z_bed) * up)
    # The game squeezes a piece it fills until nothing it draws between 0.15 and 2.2 m up lies outside its
    # footprint (kit_town.gd band_box_of): one low leaf beyond the bed shrinks the whole tree. So the crown is
    # raised until what lies outside the bed clears that band: the trunk's zone is stretched, the crown's
    # pressed a little, and the few stragglers left are lifted to the line.
    clear = float(opt("--clear", "2.45"))
    outside = ((np.abs(new[:, 0]) > bed_w / 2) | (np.abs(new[:, 1]) > bed_d / 2)) & (new[:, 2] > bed_h + 0.05)
    low = float(np.percentile(new[outside, 2], 0.5)) if outside.any() else clear
    if low < clear:
        z = new[:, 2]
        new[:, 2] = np.where(z <= bed_h, z, np.where(z <= low, bed_h + (z - bed_h) * (clear - bed_h) / (low - bed_h),
                                                     clear + (z - low) * (tree_h - clear) / (tree_h - low)))
        stragglers = outside & (new[:, 2] < clear - 0.1)
        new[stragglers, 2] = clear - 0.1
    me.vertices.foreach_set("co", new.ravel())
    me.update()
    crown_starts_m = float(bed_h + (crown_from * span[2] - z_bed) * up)
    crown_starts_m = max(crown_starts_m, clear) if low < clear else crown_starts_m
    report["tree_raised"] = {"lowest_outside_m": round(low, 2), "clear_m": clear} if low < clear else None
    report["tree"] = {"bed_top": round(bed_top, 3), "narrowest": round(narrow, 3), "crown_from": round(crown_from, 3),
                      "bed_scale": [round(float(v), 3) for v in s_bed], "crown_scale": round(float(s_crown), 3), "up_scale": round(float(up), 3),
                      "crown_starts_m": round(crown_starts_m, 2), "crown_started_before_it_was_raised_m": round(float(bed_h + (crown_from * span[2] - z_bed) * up), 2)}
elif opt("--planted"):
    # A planted tree or palm fills no box. It is sized evenly across to CROWN metres and to HEIGHT metres tall,
    # and stood with the middle of its trunk's foot on the origin: the game turns each copy about the origin
    # and scales its width about it.
    crown_w, tree_h = (float(v) for v in opt("--planted").split(","))
    bed_h = 0.0
    crown_scale = None
    if opt("--planted-box"):
        box_x, box_z = (float(v) for v in opt("--planted-box").split(","))
        if abs(math.log((box_x / span[0]) / (box_z / span[1]))) > abs(math.log((box_x / span[1]) / (box_z / span[0]))):
            hi.matrix_world = Matrix.Rotation(math.radians(90), 4, "Z") @ hi.matrix_world
            only(hi)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            pts = world_verts([hi])
            lo, hi_pt = pts.min(axis=0), pts.max(axis=0)
            span = hi_pt - lo
            report["planted_quarter_turn"] = True
        crown_scale = math.sqrt((box_x / span[0]) * (box_z / span[1]))
    n = 60
    frac = (pts[:, 2] - lo[2]) / span[2]
    widths = np.zeros(n)
    for i in range(n):
        sl = pts[(frac >= i / n) & (frac < (i + 1) / n)]
        if len(sl):
            widths[i] = max(sl[:, 0].max() - sl[:, 0].min(), sl[:, 1].max() - sl[:, 1].min())
    low = widths[3:12][widths[3:12] > 0]                                # the trunk, between 5% and 20% of the height
    trunk_w = float(np.median(low)) if len(low) else float(widths.max()) / 8
    crown_i = next((i for i in range(6, n - 1) if widths[i] > 4.0 * trunk_w and widths[i + 1] > 4.0 * trunk_w), n // 2)
    crown_from = crown_i / n
    # Where the stem ends: the first height at which the piece is nearly twice the trunk's width (its limbs
    # part, or its leaves begin).
    fork_i = next((i for i in range(3, n - 1) if widths[i] > 1.8 * trunk_w and widths[i + 1] > 1.8 * trunk_w), crown_i)
    foot = pts[frac < 0.05]
    centre = (foot[:, :2].min(axis=0) + foot[:, :2].max(axis=0)) / 2
    s_xy = crown_scale if crown_scale is not None else crown_w / max(span[0], span[1])
    s_z = tree_h / span[2]
    me = hi.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    new = np.empty_like(co)
    new[:, :2] = (co[:, :2] - centre) * s_xy
    new[:, 2] = (co[:, 2] - lo[2]) * s_z
    crown_starts_m = float(crown_from * tree_h)
    fork_m = float(fork_i / n * tree_h)
    clear = float(opt("--planted-clear", "0"))
    raised = None
    if clear > fork_m + 0.02:
        # One stem and nothing else where people walk: the stem below the fork is stretched until the fork is
        # at `clear`, and what is above is pressed into the height that is left.
        z = new[:, 2]
        press = (tree_h - clear) / (tree_h - fork_m)
        new[:, 2] = np.where(z <= fork_m, z * clear / fork_m, clear + (z - fork_m) * press)
        raised = {"fork_from_m": round(fork_m, 2), "to_m": clear, "crown_pressed_to": round(press, 3)}
        crown_starts_m = clear + (crown_starts_m - fork_m) * press if crown_starts_m > fork_m else crown_starts_m * clear / fork_m
        fork_m = clear
    # Upright through the band the game measures: the trunk's middle at each height up to 2.6 m (or to where
    # the crown starts, if lower) is taken from what stands within one and a half trunk widths of the axis, a
    # straight line is put through those middles, and everything up to that height is moved by the line so
    # the trunk stands over the origin; what is above moves as one, by the line's place at the top. A palm
    # drawn leaning from the ground keeps its lean above head height, as the kits' palms have it.
    top = 2.6
    near = np.hypot(new[:, 0], new[:, 1]) < 1.5 * trunk_w * s_xy + 0.25
    zs, mids = [], []
    for hz in np.arange(0.3, min(top, max(fork_m - 0.1, 1.0)) + 0.01, 0.1):
        sl = new[near & (np.abs(new[:, 2] - hz) <= 0.05)]
        if len(sl) >= 12:
            zs.append(hz)
            mids.append((sl[:, :2].min(axis=0) + sl[:, :2].max(axis=0)) / 2)
    lean = 0.0
    line_x = line_y = np.zeros(2)
    if len(zs) >= 4:
        zs, mids = np.array(zs), np.array(mids)
        line_x, line_y = np.polyfit(zs, mids[:, 0], 1), np.polyfit(zs, mids[:, 1], 1)
        zc = np.minimum(new[:, 2], top)
        new[:, 0] -= np.polyval(line_x, zc)
        new[:, 1] -= np.polyval(line_y, zc)
        lean = float(np.hypot(line_x[0], line_y[0]) * top)
    # Where the trunk runs, for telling wood from leaf (painted_class): over the origin up to `top`, and on
    # along its line above; and how far from that a face still counts as the trunk's.
    planted_axis = (line_x, line_y, top)
    trunk_core_r = 0.75 * trunk_w * float(s_xy)
    me.vertices.foreach_set("co", new.ravel())
    me.update()
    report["planted"] = {"crown_m": crown_w, "height_m": tree_h, "scale_across": round(float(s_xy), 3), "scale_up": round(float(s_z), 3),
                         "trunk_width_generated_m": round(trunk_w * float(s_xy), 3), "crown_starts_m": round(crown_starts_m, 2),
                         "trunk_lean_taken_out_m": round(lean, 3), "fork_m": round(fork_m, 2), "fork_raised": raised}
elif opt("--planter"):
    # A planting box: the box to its outline and its rim's height, the plants evenly and inside the outline.
    box_w, box_d, rim_arg = opt("--planter").split(",")
    box_w, box_d = float(box_w), float(box_d)
    planter_tiers = None
    if opt("--planter-tiers"):
        # The box through the steps of a plinth or a coping: its rim, the outline of the tier that holds most of
        # its height, and its tiers (planter_through_steps).
        rim_raw, base, tiers_raw = planter_through_steps(hi, pts, float(opt("--planter-tiers")) / box_w)
    else:
        n = 120
        idx = np.minimum(((pts[:, 2] - lo[2]) / span[2] * n).astype(int), n - 1)
        bounds = np.full((n, 4), np.nan)
        for i in range(n):
            sl = pts[idx == i]
            if len(sl):
                bounds[i] = (sl[:, 0].min(), sl[:, 1].min(), sl[:, 0].max(), sl[:, 1].max())
        base = np.nanmedian(bounds[1:6], axis=0)                       # the box's outline, read just above the ground
        tol = 0.008 * max(base[2] - base[0], base[3] - base[1])
        rim_i = 0
        while rim_i + 1 < n and not np.isnan(bounds[rim_i + 1]).any() and np.abs(bounds[rim_i + 1] - base).max() <= tol:
            rim_i += 1
        # The rim's own height: where the faces that look up just inside the outline lie, about there (the slices
        # are 1/120 of the height, and a leaf can lie on the wall's plane).
        polys = hi.data.polygons
        p_mid, p_nor, p_area = np.empty(len(polys) * 3), np.empty(len(polys) * 3), np.empty(len(polys))
        polys.foreach_get("center", p_mid)
        polys.foreach_get("normal", p_nor)
        polys.foreach_get("area", p_area)
        p_mid, p_nor = p_mid.reshape(-1, 3), p_nor.reshape(-1, 3)
        inward = np.minimum(np.minimum(p_mid[:, 0] - base[0], base[2] - p_mid[:, 0]), np.minimum(p_mid[:, 1] - base[1], base[3] - p_mid[:, 1]))
        rim_about = float(lo[2]) + (rim_i + 1) * span[2] / n
        on_top = (p_nor[:, 2] > 0.9) & (inward > 0.5 * tol) & (inward < 4 * tol) & (np.abs(p_mid[:, 2] - rim_about) < 4 * span[2] / n)
        if on_top.sum() > 20:
            order = np.argsort(p_mid[on_top, 2])
            rim_raw = float(p_mid[on_top, 2][order][np.searchsorted(np.cumsum(p_area[on_top][order]) / p_area[on_top].sum(), 0.5)]) - float(lo[2])
        else:
            rim_raw = rim_about - float(lo[2])
    centre = np.array([(base[0] + base[2]) / 2, (base[1] + base[3]) / 2])
    sx, sy = box_w / float(base[2] - base[0]), box_d / float(base[3] - base[1])
    s_even = math.sqrt(sx * sy)
    rim_h = rim_raw * s_even if rim_arg == "keep" else float(rim_arg)
    me = hi.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    new = np.empty_like(co)
    new[:, 0] = (co[:, 0] - centre[0]) * sx
    new[:, 1] = (co[:, 1] - centre[1]) * sy
    h = co[:, 2] - lo[2]
    new[:, 2] = np.where(h <= rim_raw, h * rim_h / rim_raw, rim_h + (h - rim_raw) * s_even)
    # The plants in: the game fits whatever a filled piece draws between 0.15 and 2.2 m up to its footprint, so
    # a leaf past the rim is fitted there in the box's place. What stands above the rim is drawn in about the
    # box's middle until all but a few stragglers are inside the outline (less the inset), and those are put on
    # the line. The cut-down piece's plants are held to the outline once more after the cut.
    inset = float(opt("--planter-inset", "0.03"))
    above = new[:, 2] > rim_h + 0.012
    drawn_in = []
    for axis_, half in ((0, box_w / 2), (1, box_d / 2)):
        k = 1.0
        if above.any():
            k = min(1.0, (half - inset) / float(np.percentile(np.abs(new[above, axis_]), 99.5)))
            new[:, axis_] *= 1 + (k - 1) * np.clip((new[:, 2] - rim_h - 0.012) / 0.03, 0, 1)
            out_there = above & (np.abs(new[:, axis_]) > half - inset)
            new[out_there, axis_] = np.sign(new[out_there, axis_]) * (half - inset)
        drawn_in.append(round(k, 3))
    me.vertices.foreach_set("co", new.ravel())
    me.update()
    report["scale"] = [round(sx, 4), round(sy, 4), round(s_even, 4)]
    report["stretch"] = round(max(sx, sy) / min(sx, sy), 3)
    report["planter"] = {"box_as_generated": [round(float(v), 3) for v in (base[2] - base[0], base[3] - base[1], rim_raw)], "rim_m": round(rim_h, 3),
                         "rim_if_kept_m": round(rim_raw * s_even, 3), "rim_stretch": round(rim_h / (rim_raw * s_even), 3),
                         "plants_drawn_in": drawn_in, "inset_m": inset, "height_m": round(float(new[:, 2].max()), 3)}
    if opt("--planter-tiers"):
        # The tiers as built: each from one height to another, half as wide and half as deep as given (alike
        # on both sides of the box's middle: a step that shows on one side only is the generator's unevenness).
        # Neighbours less than STEP apart are one tier, and a tier wider than the body that reaches the walking
        # band is held to the body's outline.
        step = float(opt("--planter-tiers"))
        planter_tiers = []
        for z0, z1, b in tiers_raw:
            half = [float(b[2] - b[0]) / 2 * sx, float(b[3] - b[1]) / 2 * sy]
            top_m = z1 * rim_h / rim_raw
            if top_m > 0.14:
                half = [min(half[0], box_w / 2), min(half[1], box_d / 2)]
            if abs(half[0] - box_w / 2) < step and abs(half[1] - box_d / 2) < step:
                half = [box_w / 2, box_d / 2]
            if planter_tiers and abs(planter_tiers[-1][2] - half[0]) < step and abs(planter_tiers[-1][3] - half[1]) < step:
                planter_tiers[-1][1] = top_m
            else:
                planter_tiers.append([z0 * rim_h / rim_raw, top_m, half[0], half[1]])
        planter_tiers[0][0], planter_tiers[-1][1] = 0.0, rim_h
        report["planter"]["tiers"] = [{"from_m": round(t[0], 3), "to_m": round(t[1], 3), "across_m": [round(2 * t[2], 3), round(2 * t[3], 3)]} for t in planter_tiers]
        report["planter"]["tiers_as_generated"] = [[round(float(z0), 3), round(float(z1), 3)] + [round(float(v), 3) for v in b] for z0, z1, b in tiers_raw]
elif zone is not None:
    # A top on a stem on a foot: scaled evenly to the box's width, and the stem alone made as long as the
    # box's height asks. The stem's axis goes on the origin.
    k_lo, k_hi = kit_box
    k_span = k_hi - k_lo
    f = float(max(k_span[0], k_span[1]) / zone["top_w"])
    axis, z_f, z_t = zone["axis"], zone["z_f"], zone["z_t"]
    foot_drawn = (z_f - float(lo[2])) * f
    foot_asked = [float(v) for v in opt("--stem-foot").split(",")] if opt("--stem-foot") else []
    foot_h = min(foot_drawn, foot_asked[0]) if foot_asked else foot_drawn
    top_h = (float(hi_pt[2]) - z_t) * f
    top_up = f                                   # the top's scale upward: the even scale, unless --stem-grid changes its height
    cube = float(opt("--stem-grid", "0"))
    if cube:
        # A style built from cubes: the foot and the top are each a whole number of cubes high (one at least),
        # so that their upper and lower faces lie on the grid's levels and not half way through a cube.
        foot_h = max(cube, round(foot_h / cube) * cube)
        top_cubes = max(cube, round(top_h / cube) * cube)
        top_up, top_h = f * top_cubes / top_h, top_cubes
    stem_len = float(k_span[2]) - foot_h - top_h
    me = hi.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    z = co[:, 2]
    in_top = z >= z_t
    edge = None
    far = in_top & (np.hypot(co[:, 0] - axis[0], co[:, 1] - axis[1]) * f > 0.5)
    if far.any():
        edge = foot_h + stem_len + (float(z[far].min()) - z_t) * top_up
        if opt("--stem-edge") and edge < float(opt("--stem-edge")):
            more = float(opt("--stem-edge")) - edge
            if cube:
                more = math.ceil(more / cube - 1e-6) * cube
            stem_len += more
            edge = edge + more if cube else float(opt("--stem-edge"))
    new = np.empty_like(co)
    new[:, 0] = (co[:, 0] - axis[0]) * f
    new[:, 1] = (co[:, 1] - axis[1]) * f
    if cube:
        # ... and the top fills the box's width and its depth each (a generated round top can be an eighth
        # narrower one way than the other): its two ends then lie alike on the grid both ways, which the cube
        # step needs to make the piece alike across its diagonals as well.
        in_top0 = pts[pts[:, 2] >= z_t]
        across = np.array([float(np.ptp(in_top0[:, 0])), float(np.ptp(in_top0[:, 1]))])
        new[:, 0] = (co[:, 0] - axis[0]) * float(k_span[0]) / across[0]
        new[:, 1] = (co[:, 1] - axis[1]) * float(k_span[1]) / across[1]
        report["stem_top_filled_to_the_box"] = [round(float(k_span[0]) / across[0], 4), round(float(k_span[1]) / across[1], 4)]
    off = (zone["top_mid"] - axis) * f
    on_axis = bool(np.linalg.norm(off) < 0.03 * zone["top_w"] * f)
    if on_axis:
        new[in_top, :2] -= off
    new[:, 2] = np.where(z <= z_f, (z - lo[2]) * foot_h / max(z_f - float(lo[2]), 1e-9),
                         np.where(z < z_t, foot_h + (z - z_f) * stem_len / (z_t - z_f), foot_h + stem_len + (z - z_t) * top_up))
    a, b = zone["slices"]
    stem_wide = zone["wide"][a:b] * f
    foot_wide = float(zone["wide"][:a].max()) * f
    foot_in = min(1.0, foot_asked[1] / foot_wide) if len(foot_asked) > 1 else 1.0
    new[z <= z_f, :2] *= foot_in
    thinned = None
    if opt("--stem-across"):
        # Each slice of the stem wider than this is drawn in about the axis (so a square post stays square).
        asked = opt("--stem-across").split(",")
        most, upto = float(asked[0]), (float(asked[1]) if len(asked) > 1 else None)
        mids_z = zone["lo"] + (np.arange(a, b) + 0.5) * zone["height"] / zone["n"]
        k = np.where((z > z_f) & (z < z_t), np.interp(z, mids_z, np.minimum(1.0, most / np.maximum(stem_wide, 1e-9))), 1.0)
        if upto is not None:
            k = 1 + (k - 1) * np.clip((upto - new[:, 2]) / 0.03 + 0.5, 0, 1)
        new[:, 0] *= k
        new[:, 1] *= k
        thinned = {"most_m": most, "upto_m": upto, "least_factor": round(float(k.min()), 3)}
    me.vertices.foreach_set("co", new.ravel())
    me.update()
    report["scale"] = [round(f, 4)] * 3
    report["stretch"] = round(stem_len / ((z_t - z_f) * f), 3)                  # how much longer the stem is than drawn
    report["stem"] = {"foot_m": round(foot_h, 3), "foot_as_drawn_m": round(foot_drawn, 3), "foot_across_m": round(foot_wide * foot_in, 3),
                      "foot_across_as_drawn_m": round(foot_wide, 3), "stem_m": round(stem_len, 3), "top_m": round(top_h, 3),
                      "stem_across_as_drawn_m": [round(float(stem_wide.min()), 3), round(float(stem_wide.max()), 3)], "thinned": thinned,
                      "top_off_axis_mm": round(float(np.linalg.norm(off)) * 1000, 1), "top_moved_onto_axis": on_axis,
                      "edge_m": None if edge is None else round(edge, 3), "height_m": round(foot_h + stem_len + top_h, 3)}
elif opt("--shelter"):
    lamp_heights, rebuilt = size_shelter(hi)
    if rebuilt is not None:
        cut_from = rebuilt
elif opt("--fountain"):
    cut_from, basin_ring, water_disc = size_fountain(hi)
elif opt("--bed") and kit_box is not None:
    # A kerbed bed. The game stretches it until what it draws between 0.15 and 2.2 m fills its footprint
    # (pack_3d.gd _fit_prop), and the collision audit reads its outline between 0.25 and 1.9 m: the kerb has
    # to be what stands on the box's sides, and has to stand higher than 0.25 m. A generated bed's plants hang
    # over its kerb and its kerb is as low as the image drew it, so filling the kit's box puts the plants on
    # the box's sides and the kerb inside them, under the band. The bed is sized by its kerb instead.
    bed_args = opt("--bed").split(",")
    kerb_h = float(bed_args[0])
    overhang = float(bed_args[1]) if len(bed_args) > 1 else 0.0
    k_lo, k_hi = kit_box
    me = hi.data
    n_f = len(me.polygons)
    f_n, f_c, f_a = np.empty(n_f * 3), np.empty(n_f * 3), np.empty(n_f)
    me.polygons.foreach_get("normal", f_n)
    me.polygons.foreach_get("center", f_c)
    me.polygons.foreach_get("area", f_a)
    f_n, f_c = f_n.reshape(-1, 3), f_c.reshape(-1, 3)
    frac = (f_c[:, 2] - lo[2]) / span[2]
    # The kerb's top: the height, between a tenth and six tenths of the model's, where most of what faces up
    # lies (the coping and the soil; leaves face every way and lie at every height).
    up_faces = f_n[:, 2] > 0.9
    bins = 50
    up_area = np.zeros(bins)
    np.add.at(up_area, np.minimum((frac[up_faces] * bins).astype(int), bins - 1), f_a[up_faces])
    k_top = bins // 10 + int(np.argmax(up_area[bins // 10: 6 * bins // 10]))
    near = up_faces & (frac >= (k_top - 1) / bins) & (frac < (k_top + 2) / bins)
    kerb_top = float(np.average(f_c[near, 2], weights=f_a[near]))
    kerb_frac = (kerb_top - lo[2]) / span[2]
    # Its walls: on each side, the upright faces of the upper half of the kerb (what will stand in the band)
    # are gathered by where they stand, in slabs a hundredth of the model's size thick; the wall is the
    # outermost slab that holds at least three tenths of the area of the fullest one. Leaves hanging over the
    # wall are upright here and there, but they are little of it; and a kerb built of separate cubes (the
    # voxel sheets') has upright faces at every joint along it, each of them as much as the end wall, so the
    # outermost counts, not the most.
    upright = (np.abs(f_n[:, 2]) < 0.2) & (frac > 0.5 * kerb_frac) & (frac < 0.95 * kerb_frac)

    def wall(axis, sign):
        m = upright & (sign * f_n[:, axis] > 0.9)
        slab = np.floor((f_c[m, axis] - lo[axis]) / (0.01 * span[axis])).astype(int)
        held = np.bincount(np.clip(slab, 0, 100), weights=f_a[m], minlength=101)
        full = np.nonzero(held >= 0.3 * held.max())[0]
        pick = full[-1] if sign > 0 else full[0]
        return float(np.average(f_c[m, axis][slab == pick], weights=f_a[m][slab == pick]))

    wx0, wx1, wy0, wy1 = wall(0, -1), wall(0, 1), wall(1, -1), wall(1, 1)
    s_x, s_y = (k_hi[0] - k_lo[0]) / (wx1 - wx0), (k_hi[1] - k_lo[1]) / (wy1 - wy0)
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    new = np.empty_like(co)
    new[:, 0] = k_lo[0] + (co[:, 0] - wx0) * s_x
    new[:, 1] = k_lo[1] + (co[:, 1] - wy0) * s_y
    h, kt, box_top = co[:, 2] - lo[2], kerb_top - lo[2], float(k_hi[2])
    new[:, 2] = np.where(h <= kt, h * kerb_h / kt, kerb_h + (h - kt) * (box_top - kerb_h) / (span[2] - kt))
    # What reaches outside the walls is pulled in: unchanged up to half the overhang allowed, then drawn in
    # ever more strongly so that nothing passes the line (with no overhang allowed, to just inside the wall,
    # where the stone hides it).
    out_before = np.zeros(len(new))
    for axis in (0, 1):
        for sign, side in ((-1, k_lo[axis]), (1, k_hi[axis])):
            d = sign * (new[:, axis] - side)
            out_before = np.maximum(out_before, d)
            if overhang > 0:
                half = overhang / 2
                d_new = np.where(d <= half, d, half + half * (1 - np.exp(-(np.maximum(d, half) - half) / half)))
            else:
                d_new = np.where(d <= 0, d, -0.004)
            new[:, axis] = side + sign * d_new
    me.vertices.foreach_set("co", new.ravel())
    me.update()
    report["bed"] = {"kerb_top_share_of_model": round(float(kerb_frac), 3), "kerb_m": kerb_h, "overhang_allowed_m": overhang,
                     "walls_of_model": [round(v, 4) for v in (wx0, wy0, wx1, wy1)],
                     "scale_across_up_kerb_up_plants": [round(float(v), 3) for v in (s_x, s_y, kerb_h / kt, (box_top - kerb_h) / (span[2] - kt))],
                     "plants_reached_outside_m": round(float(out_before.max()), 3),
                     "vertices_pulled_in": int((out_before > (overhang / 2 if overhang > 0 else 0)).sum())}
    report["scale"] = [round(float(v), 4) for v in (s_x, s_y, box_top / span[2])]
    report["stretch"] = round(float(max(s_x, s_y) / min(s_x, s_y)), 3)
elif kit_box is not None:
    k_lo, k_hi = kit_box
    k_span = k_hi - k_lo
    if "--keep-aspect" in argv:
        by = {"width": 0, "depth": 1, "height": 2}[opt("--aspect-by", "width")]
        f = k_span[by] / span[by]
        scale = np.array([f, f, f])
        centre = (k_lo + k_hi) / 2
        offset = np.array([centre[0] - (lo[0] + span[0] / 2) * f, centre[1] - (lo[1] + span[1] / 2) * f, k_lo[2] - lo[2] * f])
    else:
        scale = k_span / span
        offset = k_lo - lo * scale
    if "--axis" in argv:
        # A post is stood on a point by its axis, read off the post itself (post_axis).
        axis_xy = post_axis(pts)
        centre = (k_lo + k_hi) / 2
        offset[:2] = centre[:2] - axis_xy * scale[:2]
        report["axis"] = {"off_the_middle_of_its_box_m": [round(float(v), 4) for v in (axis_xy - (lo[:2] + span[:2] / 2)) * scale[:2]]}
    hi.matrix_world = Matrix.Translation(Vector(offset)) @ Matrix.Diagonal(Vector((*scale, 1.0))) @ hi.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if "--panel" in argv and "--keep-aspect" in argv and span[2] * scale[2] > 1.1 * k_span[2] + 0.02:
        scale[2] = (1.1 * k_span[2] + 0.02 - 0.001) / span[2]
        offset[2] = k_lo[2] - lo[2] * scale[2]
        hi.matrix_world = Matrix.Diagonal(Vector((1.0, 1.0, float(scale[2] / scale[0]), 1.0))) @ hi.matrix_world
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        report["panel"]["height_brought_down_to_m"] = round(float(span[2] * scale[2]), 3)
    report["scale"] = [round(float(v), 4) for v in scale]
    report["stretch"] = round(float(scale.max() / scale.min()), 3)      # 1 = the generated proportions kept
    if opt("--hang-above") and "--axis" in argv:
        # A banner on an arm: where it hangs lower than the audit's band reaches up, it is drawn up towards
        # its own top (eased in over the 5 cm outside the radius, so the arm does not shear where it leaves
        # the post).
        values = [float(v) for v in opt("--hang-above").split(",")]
        out_r, least_z, from_z = values[0], values[1], values[2] if len(values) > 2 else 1.0
        centre = (k_lo + k_hi) / 2
        co = np.empty(len(hi.data.vertices) * 3)
        hi.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        r = np.hypot(co[:, 0] - centre[0], co[:, 1] - centre[1])
        hanging = (r > out_r) & (co[:, 2] > from_z)
        report["hang_above"] = None
        if hanging.any():
            # What hangs is taken part by part (corners joined by edges out there): a lantern's eaves are out
            # there too, higher up, and are not the banner's.
            ed = np.empty(len(hi.data.edges) * 2, dtype=np.int64)
            hi.data.edges.foreach_get("vertices", ed)
            ed = ed.reshape(-1, 2)
            ed = ed[hanging[ed[:, 0]] & hanging[ed[:, 1]]]
            label = np.arange(len(co))
            while True:
                low = np.minimum(label[ed[:, 0]], label[ed[:, 1]])
                before = label.copy()
                np.minimum.at(label, ed[:, 0], low)
                np.minimum.at(label, ed[:, 1], low)
                label = label[label]
                if (label == before).all():
                    break
            drawn = []
            for part in np.unique(label[hanging]):
                mine = hanging & (label == part)
                top, bottom = float(co[mine, 2].max()), float(co[mine, 2].min())
                if bottom < least_z < top:
                    ease = np.clip((r - out_r) / 0.05, 0.0, 1.0)
                    drawn_up = top - (top - co[:, 2]) * (top - least_z) / (top - bottom)
                    co[:, 2] = np.where(mine, co[:, 2] + (drawn_up - co[:, 2]) * ease, co[:, 2])
                    drawn.append({"was_from_m": round(bottom, 3), "to_m": round(top, 3), "now_from_m": round(least_z, 3), "reaches_m": round(float(r[mine].max()), 3)})
            if drawn:
                hi.data.vertices.foreach_set("co", co.ravel())
                hi.data.update()
                report["hang_above"] = drawn
    if kit_seat is not None:
        # The game seats a figure by its own sitting pose, at one height whatever the piece. Filling the kit's
        # box does not put the design's seat where the kit's is, so the heights are moved: everything up to
        # the seat's top is scaled to the kit's seat height, everything above it to the rest of the box.
        own = seat_top_of([hi])
        report["seat_top_m"] = {"kit": round(kit_seat, 3), "generated": None if own is None else round(own, 3)}
        if own is not None and abs(own - kit_seat) > 0.005:
            base, top = float(k_lo[2]), float(k_hi[2])
            for v in hi.data.vertices:
                z = v.co.z
                v.co.z = base + (z - base) * (kit_seat - base) / (own - base) if z <= own else kit_seat + (z - own) * (top - kit_seat) / (top - own)
            hi.data.update()
# ---- The piece from above, as the game's collision audit reads it ----
FILL_BAND, AUDIT_BAND = (0.15, 2.2), (0.25, 1.9)


def plan_points(obj, z_lo, z_hi, per_cm2=6.0):
    """Points on the object's surface between two heights (its vertices there, and points spread over each face
    that reaches into the band): enough that a 1 cm grid of the plan is marked wherever the surface is."""
    me = obj.data
    me.calc_loop_triangles()
    tri = np.empty(len(me.loop_triangles) * 3, dtype=np.int32)
    me.loop_triangles.foreach_get("vertices", tri)
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    p = co[tri.reshape(-1, 3)]
    p = p[(p[:, :, 2].max(axis=1) >= z_lo) & (p[:, :, 2].min(axis=1) <= z_hi)]
    if not len(p):
        return np.zeros((0, 3))
    area = 0.5 * np.linalg.norm(np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0]), axis=1)
    idx = np.repeat(np.arange(len(p)), np.maximum(1, np.ceil(area * 1e4 * per_cm2).astype(int)))
    spread = np.random.default_rng(11)
    r1, r2 = np.sqrt(spread.random(len(idx))), spread.random(len(idx))
    on = (1 - r1)[:, None] * p[idx, 0] + (r1 * (1 - r2))[:, None] * p[idx, 1] + (r1 * r2)[:, None] * p[idx, 2]
    on = np.concatenate([on, p.reshape(-1, 3)])
    return on[(on[:, 2] >= z_lo) & (on[:, 2] <= z_hi)]


def edge_profile(along, out, step=0.01):
    """How far the points reach outward at each step along a side: (the steps' middles, the reach at each)."""
    bins = np.floor((along - along.min()) / step).astype(int)
    far = np.full(bins.max() + 1, -np.inf)
    np.maximum.at(far, bins, out)
    seen = np.isfinite(far)
    return (along.min() + (np.nonzero(seen)[0] + 0.5) * step), far[seen]


plan_notch = None
plan_asked = [name_ for name_ in ("--plan-pull", "--plan-cols", "--plan-rows", "--plan-notch") if name_ in argv]
if plan_asked and kit_box is not None and kit_back is not None:
    me = hi.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    d_axis, back_sign = kit_back
    a_axis = 1 - d_axis
    # Plan coordinates: `a` across, `d` in depth, growing towards the front.
    to_plan = lambda xyz: (xyz[:, a_axis].copy(), -back_sign * xyz[:, d_axis])
    a, d = to_plan(co)
    plan = {"front_is": ("-" if back_sign > 0 else "+") + "xy"[d_axis]}

    def audit_pts():
        scratch = co.copy()
        scratch[:, a_axis], scratch[:, d_axis] = a, -back_sign * d
        me.vertices.foreach_set("co", scratch.ravel())
        me.update()
        return to_plan(plan_points(hi, *AUDIT_BAND))

    if opt("--plan-pull"):
        sides = opt("--plan-pull").split(",")
        sides = ["rear", "front", "left", "right"] if "all" in sides else sides
        pulled = {}
        for side in sides:
            pa, pd = audit_pts()
            if not len(pa):
                break
            along, out_now = {"rear": (pa, -pd), "front": (pa, pd), "left": (pd, -pa), "right": (pd, pa)}[side]
            _, reach_at = edge_profile(along, out_now)
            main = float(np.median(reach_at))
            mine = {"rear": -d, "front": d, "left": -a, "right": a}[side]
            past = mine > main + 0.003
            if past.any() and float(mine.max()) > main + 0.006:
                pulled[side] = {"stood_out_m": round(float(mine.max()) - main, 3), "share_of_the_side_at_the_main_edge": round(float((reach_at > main - 0.01).mean()), 2)}
                mine = np.where(past, main + (mine - main) * 0.05, mine)
                if side == "rear":
                    d = -mine
                elif side == "front":
                    d = mine
                elif side == "left":
                    a = -mine
                else:
                    a = mine
        plan["pulled"] = pulled
    if "--plan-cols" in argv:
        pa, pd = audit_pts()
        lo_d, hi_d = float(d.min()), float(d.max())
        step_a = 0.01
        cols = np.floor((pa - a.min()) / step_a).astype(int)
        n_cols = int(np.floor((a.max() - a.min()) / step_a)) + 1
        rear, front = np.full(n_cols, np.inf), np.full(n_cols, -np.inf)
        ok = (cols >= 0) & (cols < n_cols)
        np.minimum.at(rear, cols[ok], pd[ok])
        np.maximum.at(front, cols[ok], pd[ok])
        seen = np.isfinite(rear) & (front - rear > 0.05 * (hi_d - lo_d))
        if seen.any():
            known = np.nonzero(seen)[0]
            every = np.arange(n_cols)
            scale_at = np.clip(np.interp(every, known, ((hi_d - lo_d) / np.maximum(front - rear, 1e-6))[known]), 1.0, 1.35)
            mid_at = np.interp(every, known, ((rear + front) / 2)[known])
            # Softened over three strips, so that what crosses from a strip that is drawn out into one that is
            # not (a slat's end in a frame) bends over 3 cm and does not break.
            soft = np.ones(3) / 3
            scale_at = np.convolve(np.pad(scale_at, 1, mode="edge"), soft, mode="valid")
            mid_at = np.convolve(np.pad(mid_at, 1, mode="edge"), soft, mode="valid")
            mine = np.clip(np.floor((a - a.min()) / step_a).astype(int), 0, n_cols - 1)
            d = np.clip((lo_d + hi_d) / 2 + (d - mid_at[mine]) * scale_at[mine], lo_d, hi_d)
            plan["cols"] = {"strips_deepened": int((scale_at > 1.01).sum()), "of": int(n_cols), "most": round(float(scale_at.max()), 3)}
    if "--plan-rows" in argv:
        pa, pd = audit_pts()
        lo_a, hi_a = float(a.min()), float(a.max())
        step_d = 0.01
        rows = np.floor((pd - d.min()) / step_d).astype(int)
        n_rows = int(np.floor((d.max() - d.min()) / step_d)) + 1
        left, right = np.full(n_rows, np.inf), np.full(n_rows, -np.inf)
        ok = (rows >= 0) & (rows < n_rows)
        np.minimum.at(left, rows[ok], pa[ok])
        np.maximum.at(right, rows[ok], pa[ok])
        seen = np.isfinite(left) & (right - left > 0.05 * (hi_a - lo_a))
        if seen.any():
            scale_at = np.where(seen, (hi_a - lo_a) / np.maximum(right - left, 1e-6), np.nan)
            mid_at = np.where(seen, (left + right) / 2, np.nan)
            known = np.nonzero(seen)[0]
            every = np.arange(n_rows)
            scale_at = np.clip(np.interp(every, known, scale_at[known]), 1.0, 1.35)
            mid_at = np.interp(every, known, mid_at[known])
            mine = np.clip(np.floor((d - d.min()) / step_d).astype(int), 0, n_rows - 1)
            a = (lo_a + hi_a) / 2 + (a - mid_at[mine]) * scale_at[mine]
            a = np.clip(a, lo_a, hi_a)                                   # what else stood in a row (a foot) stays in the box
            plan["rows"] = {"rows_widened": int((scale_at > 1.01).sum()), "of": int(n_rows), "most": round(float(scale_at.max()), 3)}
    if opt("--plan-notch"):
        half_share, depth_share = (float(v) for v in opt("--plan-notch").split(","))
        pa, pd = audit_pts()
        mid_a, wide, deep = (a.min() + a.max()) / 2, float(a.max() - a.min()), float(d.max() - d.min())
        half = half_share * wide
        # The arms' inner faces: a little above the seat, in the front third, the piece is two arms with a gap.
        seat_h = kit_seat if kit_seat is not None else 0.45
        scratch = co.copy()
        scratch[:, a_axis], scratch[:, d_axis] = a, -back_sign * d
        me.vertices.foreach_set("co", scratch.ravel())
        me.update()
        above = plan_points(hi, seat_h + 0.05, seat_h + 0.12)
        aa, ad = to_plan(above)
        front_third = ad > d.max() - 0.18 * deep                        # the arms' front ends: a pillow rarely lies this far forward
        inner = {}
        for side, sign in (("left", -1.0), ("right", 1.0)):
            # From the piece's outer face inwards, the arm is what is there before the first gap of 2 cm (a
            # pillow or a throw on the seat is further in, past the gap).
            off = (aa[front_third] - mid_a) * sign
            filled = np.zeros(int(wide / 2 / 0.01) + 2, dtype=bool)
            filled[np.clip((off[off > 0] / 0.01).astype(int), 0, len(filled) - 1)] = True
            outer = int(np.nonzero(filled)[0].max()) if filled.any() else 0
            k_in = outer
            while k_in > 1 and (filled[k_in - 1] or filled[k_in - 2]):
                k_in -= 1
            inner[side] = k_in * 0.01 if 0.1 * wide < k_in * 0.01 < outer * 0.01 else None
        # A chair's arms are a pair: one that could not be read (a throw over it) takes the other's.
        found = [v for v in inner.values() if v is not None]
        inner = {side: (v if v is not None else (min(found) if found else half)) for side, v in inner.items()}
        # What moves is the seat and its meeting with each arm; the change from moving to still lies in the
        # first centimetre of the arm itself, so the faces drawn out along the arm's inner side are the arm's
        # own (its timber), not the seat's cloth.
        reach_l, reach_r = max(half, inner["left"] + 0.010), max(half, inner["right"] + 0.010)
        off = a - mid_a
        blend = 0.008
        weight = np.where(off < 0, np.clip((reach_l + off) / blend, 0, 1), np.clip((reach_r - off) / blend, 0, 1))
        # The arms' fronts (what stays), the seat's front now, and where it has to be.
        arms_front = float(d[weight < 0.5].max()) if (weight < 0.5).any() else float(d.max())
        zone = (np.where(pa - mid_a < 0, reach_l + (pa - mid_a), reach_r - (pa - mid_a)) > 0.012)
        seat_front = float(np.percentile(pd[zone], 99.8)) if zone.any() else arms_front
        want = arms_front - depth_share * (arms_front - float(d.min()))
        pivot = min(want - 0.05, (d.min() + d.max()) / 2)
        if seat_front > want + 0.002:
            k = (want - pivot) / (seat_front - pivot)
            moved = pivot + (d - pivot) * k
            ahead = d > pivot
            d = np.where(ahead, d + (np.minimum(moved, want) - d) * weight, d)
        plan["notch"] = {"arms_inner_faces_m": [round(inner["left"], 3), round(inner["right"], 3)], "cleared_either_side_m": [round(reach_l, 3), round(reach_r, 3)],
                         "seat_front_was_m_behind_the_arms": round(arms_front - seat_front, 3), "now_m": round(arms_front - min(seat_front, want), 3),
                         "asked_m": round(depth_share * (arms_front - float(d.min())), 3)}
    # Back on the kit's box, across and in depth (heights were not touched).
    k_lo, k_hi = kit_box
    a_lo, a_hi, d_lo, d_hi = float(a.min()), float(a.max()), float(d.min()), float(d.max())
    a = k_lo[a_axis] + (a - a_lo) * (k_hi[a_axis] - k_lo[a_axis]) / (a_hi - a_lo)
    dd = -back_sign * d                                                 # back in the model's own axis
    dd_lo, dd_hi = float(dd.min()), float(dd.max())
    dd = k_lo[d_axis] + (dd - dd_lo) * (k_hi[d_axis] - k_lo[d_axis]) / (dd_hi - dd_lo)
    plan["put_back_on_the_box"] = [round(float((k_hi[a_axis] - k_lo[a_axis]) / (a_hi - a_lo)), 3), round(float((k_hi[d_axis] - k_lo[d_axis]) / (dd_hi - dd_lo)), 3)]
    if "notch" in plan:
        # Where the notch's two walls are in the finished piece (the arms' inner faces, bared by setting the
        # seat back): they are given the arms' colour once the texture is baked.
        fa = (k_hi[a_axis] - k_lo[a_axis]) / (a_hi - a_lo)
        fd = (k_hi[d_axis] - k_lo[d_axis]) / (dd_hi - dd_lo)
        d_of = lambda v: k_lo[d_axis] + (-back_sign * v - dd_lo) * fd          # plan depth -> the model's own axis
        plan_notch = {"mid": k_lo[a_axis] + (mid_a - a_lo) * fa, "reach": ((reach_l - 0.010) * fa, (reach_r - 0.010) * fa), "a_axis": a_axis, "d_axis": d_axis,
                      "seat_at": d_of(min(seat_front, want)), "arms_at": d_of(arms_front), "seat_h": seat_h}
    co[:, a_axis], co[:, d_axis] = a, dd
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    report["plan"] = plan
want_reach = ring_z = None
if opt("--shrub"):
    # A shrub. The game draws it as copies of its first mesh, each scaled across by 1.05 m over the piece's
    # reach about its origin (pack_3d.gd _planted_across), and its collision audit reads what each copy draws
    # between 0.25 and 1.9 m, flattened, against the footprint's disc. So the origin has to be the middle of
    # the outline, the reach the kit's, and the outline a whole circle.
    SECTORS = 72
    want_reach = kit_reach if opt("--shrub") == "kit" else float(opt("--shrub"))
    me = hi.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    turn_of = (np.arange(SECTORS) + 0.5) / SECTORS * 2 * math.pi - math.pi

    def outline(z0=0.15, z1=2.2):
        """The farthest the model reaches from the origin, between two heights, in each of 72 directions."""
        p = co[(co[:, 2] >= z0) & (co[:, 2] <= z1)]
        s = ((np.arctan2(p[:, 1], p[:, 0]) + math.pi) / (2 * math.pi) * SECTORS).astype(int) % SECTORS
        r = np.zeros(SECTORS)
        np.maximum.at(r, s, np.hypot(p[:, 0], p[:, 1]))
        return r

    # The origin: the middle (centre of area) of the outline from above.
    moved = np.zeros(2)
    for _ in range(6):
        r = outline()
        ox, oy = r * np.cos(turn_of), r * np.sin(turn_of)
        cross = ox * np.roll(oy, -1) - np.roll(ox, -1) * oy
        c = np.array([((ox + np.roll(ox, -1)) * cross).sum(), ((oy + np.roll(oy, -1)) * cross).sum()]) / (3 * cross.sum())
        co[:, :2] -= c
        moved += c
    co[:, 2] -= co[:, 2].min()
    top = float(co[:, 2].max())
    shrub_numbers = {"origin_moved_m": [round(float(v), 4) for v in moved]}
    # Where the piece is widest: the height whose outline, over all directions, reaches farthest on average.
    # That ring is what makes the circle, and it is moved up to --ring-least (0.4 m, the top of the kits' drum)
    # when it is lower, by scaling what is below it and what is above it separately: the audit's band begins
    # 0.25 m above the ground drawn under the piece, the game squashes a shrub to 0.85 of its height, and
    # ground can be drawn a few centimetres up.
    levels = np.arange(0.15, min(top, 2.2) - 0.02, 0.02)
    widest = float(levels[int(np.argmax([outline(z - 0.04, z + 0.04).mean() for z in levels]))])
    ring_z = max(widest, float(opt("--ring-least", "0.4")))
    shrub_numbers["widest_at_m"] = round(widest, 3)
    if widest < ring_z - 0.005:
        z = co[:, 2]
        co[:, 2] = np.where(z <= widest, z * ring_z / widest, ring_z + (z - widest) * (top - ring_z) / (top - widest))
        shrub_numbers["widest_moved_to_m"] = round(ring_z, 3)
    round_by = float(opt("--round", "0"))
    round_most = float(opt("--round-most", "1.3"))
    if round_by > 0:
        # The generated model is turned out towards the circle first, so that the cut-down piece starts round;
        # the piece itself is finished after the bakes (below), where its own surface can be measured.
        full = float(outline().max())
        before = outline(ring_z - 0.06, ring_z + 0.06)
        for _ in range(4 if round_by >= 1 else 1):
            ring = outline(ring_z - 0.06, ring_z + 0.06)
            gain = 1 + round_by * (np.minimum(full / np.maximum(ring, 1e-6), round_most) - 1)
            at = (np.arctan2(co[:, 1], co[:, 0]) + math.pi) / (2 * math.pi) * SECTORS - 0.5
            i0 = np.floor(at).astype(int)
            t = at - i0
            co[:, :2] *= (gain[i0 % SECTORS] * (1 - t) + gain[(i0 + 1) % SECTORS] * t)[:, None]
        # What the turning-out pushed past the circle (a leaf that was widest at another height) comes back to it.
        rr = np.hypot(co[:, 0], co[:, 1])
        past = (co[:, 2] >= 0.10) & (rr > full)
        co[past, :2] *= (full / rr[past])[:, None]
        after = outline(ring_z - 0.06, ring_z + 0.06)
        shrub_numbers["round"] = {"by": round_by, "generated_ring_least_before": round(float(before.min() / before.max()), 3),
                            "generated_ring_least_after": round(float(after.min() / max(float(outline().max()), 1e-9)), 3), "generated_vertices_pulled_back": int(past.sum())}
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    was = band_reach([hi])
    co[:, :2] *= want_reach / was
    # Nothing stands outside the circle at any height: a leaf lying on the ground beyond it is under the band the
    # game measures, and would be drawn outside the footprint (and would carry the skin out with it).
    rr = np.hypot(co[:, 0], co[:, 1])
    beyond = rr > want_reach
    co[beyond, :2] *= (want_reach / rr[beyond])[:, None]
    shrub_numbers["pulled_into_the_circle"] = int(beyond.sum())
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    shrub_numbers.update({"reach_m": round(float(want_reach), 4), "reach_after_the_box_m": round(was, 4), "scaled_across": round(float(want_reach / was), 4)})
    report["shrub"] = shrub_numbers
pts = world_verts([hi])
diag = float(np.linalg.norm(pts.max(axis=0) - pts.min(axis=0)))
reach = max(0.02 * diag, 1.5 * float(opt("--remesh", "0")))
report["yaw"] = yaw
report["box_min"] = [round(float(v), 3) for v in pts.min(axis=0)]
report["box_max"] = [round(float(v), 3) for v in pts.max(axis=0)]
if opt("--save-sized"):
    only(hi)
    bpy.ops.export_scene.gltf(filepath=opt("--save-sized"), export_format="GLB", export_yup=True, use_selection=True)

# ---- The game piece: fewer triangles ----
rng = np.random.default_rng(7)
sample = rng.choice(len(cut_from.data.vertices), size=min(6000, len(cut_from.data.vertices)), replace=False)
sample_pts = [cut_from.data.vertices[int(i)].co.copy() for i in sample]


def painted_class(obj):
    """What each face of the generated tree is, by where it is and the colour the generator painted it:
    0 wood, stone and whatever else stands at the foot, 1 a lantern, 2 leaves and blossoms, 3 the bed (only
    when the bed is cut down on its own).

    Up to 30 cm above the bed everything is the foot (bed, soil, plants, the trunk's base). Above that a
    lantern is what the warm rule finds (--warm, --glow-pale) in the lower half of the crown and under it:
    lanterns hang from the lower limbs, and the same warm yellow at the crown's top is sunlit leaf. In the
    crown, wood is what is brown (hue 8 to 45 degrees) or dark and colourless, and everything else is leaf:
    green, olive, yellow, blossom of any colour. Below the crown what is not a lantern is wood. In a planted
    tree (--planted) what stands on the trunk's line is wood too, unless it is plainly green."""
    colours = face_colours(obj)
    w_h0, w_h1, w_sat, w_val = (float(v) for v in opt("--warm", "28,62,0.42,0.62").split(","))
    pale_v, pale_s = (float(v) for v in opt("--glow-pale", "9,0").split(","))          # off unless asked for
    polys = obj.data.polygons
    top = max(p.center.z for p in polys)
    z_mid = crown_starts_m + 0.5 * (top - crown_starts_m)
    bed_alone = len(opt("--parts").split(",")) > 3
    lanterns_wanted = int(opt("--parts").split(",")[1]) > 0
    classes = np.zeros(len(polys), dtype=np.int8)
    axis = globals().get("planted_axis")
    for poly in polys:
        r, g, b = (float(c) for c in colours[poly.index])
        mx, mn = max(r, g, b), min(r, g, b)
        sat = (mx - mn) / max(mx, 1e-4)
        hue = math.degrees(math.atan2(math.sqrt(3) * (g - b), 2 * r - g - b)) % 360
        z = poly.center.z
        if axis is not None and z < 2.45 and math.hypot(poly.center.x, poly.center.y) > 1.6 * trunk_core_r:
            # A planted tree has one stem where people walk (the fork is raised above it; a palm has none), so
            # what stands away from the axis there is leaf whatever its colour: a dry frond, a low leaf mass.
            # Classed as wood it would count as trunk in the game's measure and the tree would be drawn thin.
            classes[poly.index] = 2
            continue
        if z < bed_h + 0.3:
            classes[poly.index] = 3 if (bed_alone and z < bed_h + 0.05) else 0
            continue
        warm = (w_h0 < hue < w_h1 and sat > w_sat and mx > w_val) or (mx > pale_v and sat < pale_s)
        if warm and z < z_mid and lanterns_wanted:
            classes[poly.index] = 1
        elif z > crown_starts_m:
            brown = 8 < hue < 45 and sat > 0.08
            dull = sat <= 0.08 and mx < 0.65
            on_trunk = False
            if axis is not None:
                # A planted tree's trunk runs up through its crown, and a style can paint its shaded side in a
                # colour that is not bark's (the anime sheets shade in lavender grey): a face on the trunk's
                # line is wood unless it is plainly green.
                ax = np.polyval(axis[0], z) - np.polyval(axis[0], axis[2]) if z > axis[2] else 0.0
                ay = np.polyval(axis[1], z) - np.polyval(axis[1], axis[2]) if z > axis[2] else 0.0
                on_trunk = math.hypot(poly.center.x - ax, poly.center.y - ay) < trunk_core_r and not (60 < hue < 170 and sat > 0.2)
            classes[poly.index] = 0 if (brown or dull or on_trunk) else 2
    # A lantern is its glass and the dark frame and cap round it: what is not leaf within reach of the warm
    # faces goes with them.
    from mathutils import kdtree
    warm_faces = [int(i) for i in np.nonzero(classes == 1)[0]]
    if warm_faces:
        kd = kdtree.KDTree(len(warm_faces))
        for k2, i in enumerate(warm_faces):
            kd.insert(polys[i].center, k2)
        kd.balance()
        reach = float(opt("--lantern-reach", "0.35"))
        for i in np.nonzero(classes == 0)[0]:
            if polys[int(i)].center.z > bed_h + 0.3 and kd.find(polys[int(i)].center)[2] < reach:
                classes[int(i)] = 1
    return classes


def reduced(o, target, remesh=None, inflate=None, least=None):
    """`o` rebuilt (optionally) and cut to `target` triangles."""
    only(o)
    if inflate:
        dp = o.modifiers.new("swell", "DISPLACE")
        dp.strength = inflate
        dp.mid_level = 0.0
        bpy.ops.object.modifier_apply(modifier=dp.name)
    if remesh:
        rm = o.modifiers.new("rebuild", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = remesh
        rm.adaptivity = 0.0
        bpy.ops.object.modifier_apply(modifier=rm.name)
    if least:
        bm2 = bmesh.new()
        bm2.from_mesh(o.data)
        bm2.verts.ensure_lookup_table()
        seen2, doomed = set(), []
        for v in bm2.verts:
            if v.index in seen2:
                continue
            stack, part = [v], []
            seen2.add(v.index)
            while stack:
                u = stack.pop()
                part.append(u)
                for e in u.link_edges:
                    w = e.other_vert(u)
                    if w.index not in seen2:
                        seen2.add(w.index)
                        stack.append(w)
            cs = np.array([q.co[:] for q in part])
            if float(np.linalg.norm(cs.max(axis=0) - cs.min(axis=0))) < least:
                doomed += part
        if doomed:
            bmesh.ops.delete(bm2, geom=doomed, context="VERTS")
            bm2.to_mesh(o.data)
        bm2.free()
    n = tri_count(o)
    if n > target:
        mod = o.modifiers.new("cut", "DECIMATE")
        mod.ratio = target / n
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if opt("--planted"):
        # A planted piece is drawn hundreds of times, so its count is held: a cut that stops short is run again.
        for _ in range(3):
            n = tri_count(o)
            if n <= 1.03 * target or target <= 0:
                break
            mod = o.modifiers.new("cut again", "DECIMATE")
            mod.ratio = target / n
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
    return tri_count(o)


def stem_tube(part, z_top, sectors=10, step=0.3):
    """A planted tree's stem as a tube lofted through the generated trunk's own cross-sections: a ring every
    `step` metres or less, each ring's middle and its radius in each of `sectors` directions read off the wood
    that stands near the ring below it (the 85th hundredth of how far it stands out, smoothed round the ring).
    The tube runs from the ground to `z_top`, or, with no `z_top` (a palm: one stem to its head), as far up
    as a trunk can be followed. The stem's own faces are taken out of `part`, which keeps the rest (limbs, a
    palm's head). Returns the tube and the height it ends at.

    A generated trunk is an open shell some 30 cm across. Rebuilt from cells and cut down it came back torn
    or full of tunnels, which the reduction cannot close; a tube has neither."""
    me = part.data
    co = np.array([v.co[:] for v in me.vertices])
    limit = z_top if z_top is not None else 0.92 * float(co[:, 2].max()) if len(co) else 0.0
    if len(co) < 20 or limit < 0.6:
        return None, 0.0
    count = max(3, int(math.ceil(limit / step)) + 1)
    levels = np.linspace(0.0, limit, count)
    half = (levels[1] - levels[0]) / 2
    rings = []
    centre, width = np.zeros(2), trunk_core_r / 0.75                      # where the stem is looked for, and how wide
    missed = 0
    for level in levels:
        near = np.hypot(co[:, 0] - centre[0], co[:, 1] - centre[1]) < 1.1 * width
        sl = co[near & (np.abs(co[:, 2] - level) <= half)]
        if len(sl) >= 8:
            missed = 0
            centre = (sl[:, :2].min(axis=0) + sl[:, :2].max(axis=0)) / 2
            d = sl[:, :2] - centre
            ang, rr = np.arctan2(d[:, 1], d[:, 0]), np.hypot(d[:, 0], d[:, 1])
            radii = np.full(sectors, np.nan)
            for j in range(sectors):
                a0 = -math.pi + j * 2 * math.pi / sectors
                m = (ang >= a0) & (ang < a0 + 2 * math.pi / sectors)
                if m.sum() >= 2:
                    radii[j] = np.percentile(rr[m], 85)
            radii = np.where(np.isnan(radii), np.nanmedian(radii) if not np.isnan(radii).all() else np.percentile(rr, 85), radii)
            radii = (np.roll(radii, 1) + 2 * radii + np.roll(radii, -1)) / 4
            width = max(2 * float(np.median(radii)), 0.5 * width)
            rings.append((centre.copy(), radii, float(level)))
        else:
            missed += 1
            if z_top is None and missed >= 2:
                break                                                     # the trunk is not followed further
            if rings:
                rings.append((rings[-1][0], rings[-1][1], float(level)))
    if len(rings) < 3:
        return None, 0.0
    bmt = bmesh.new()
    rows = []
    for ring_centre, radii, level in rings:
        rows.append([bmt.verts.new((ring_centre[0] + radii[j] * math.cos(-math.pi + (j + 0.5) * 2 * math.pi / sectors),
                                    ring_centre[1] + radii[j] * math.sin(-math.pi + (j + 0.5) * 2 * math.pi / sectors), level)) for j in range(sectors)])
    for k in range(len(rows) - 1):
        for j in range(sectors):
            bmt.faces.new((rows[k][j], rows[k][(j + 1) % sectors], rows[k + 1][(j + 1) % sectors], rows[k + 1][j]))
    cap = bmt.verts.new((rings[-1][0][0], rings[-1][0][1], rings[-1][2]))
    for j in range(sectors):
        bmt.faces.new((rows[-1][j], rows[-1][(j + 1) % sectors], cap))
    bmesh.ops.recalc_face_normals(bmt, faces=list(bmt.faces))
    bmesh.ops.triangulate(bmt, faces=list(bmt.faces))
    tube_mesh = bpy.data.meshes.new("stem")
    bmt.to_mesh(tube_mesh)
    bmt.free()
    tube = bpy.data.objects.new("stem", tube_mesh)
    bpy.context.scene.collection.objects.link(tube)
    # Out of `part` goes what the tube stands for: the wood within reach of its rings, up to its top.
    ends = rings[-1][2]
    ring_z = np.array([q[2] for q in rings])
    ring_c = np.array([q[0] for q in rings])
    ring_r = np.array([float(np.max(q[1])) for q in rings])
    bmp = bmesh.new()
    bmp.from_mesh(me)
    doomed = []
    for f in bmp.faces:
        c = f.calc_center_median()
        if c.z < ends - 0.05:
            k = int(np.argmin(np.abs(ring_z - c.z)))
            if math.hypot(c.x - ring_c[k][0], c.y - ring_c[k][1]) < 1.6 * ring_r[k] + 0.05:
                doomed.append(f)
    bmesh.ops.delete(bmp, geom=doomed, context="FACES")
    bmp.to_mesh(me)
    bmp.free()
    return tube, ends


def cut_parts(spec):
    """The tree cut down part by part (--parts WOOD,LANTERNS,LEAVES triangles): its wood and bed, its lanterns and
    its leaves are separated by the colour the generator painted them, and each is reduced on its own, the
    leaves from a coarser rebuild that fuses neighbouring clumps. Cut as one mesh, the leaves' many separate
    clumps hold most of the triangles and the trunk, bed and lanterns are taken apart."""
    counts_asked = [int(v) for v in spec.split(",")]
    t_wood, t_lantern, t_leaf = counts_asked[:3]
    t_bed = counts_asked[3] if len(counts_asked) > 3 else 0
    classes = painted_class(hi)
    made, counts = [], {}
    if "--bed-box" in argv:
        # The bed's walls as a plain box on the footprint, its top at the bed's height: cut down with the trunk,
        # a bed's flat walls come out ragged, and its outline is what the game measures against the footprint.
        # The generated bed stays in the model the colours are baked from, so the box takes its stone, and its
        # top a picture of the soil and plants from above. Of the generated model, what lies under the bed's
        # top near the walls is left out of the piece; plants and the trunk's foot stay and stand through the top.
        polys = hi.data.polygons
        for poly in polys:
            c = poly.center
            near_wall = abs(c.x) > bed_w / 2 - 0.15 or abs(c.y) > bed_d / 2 - 0.15
            if classes[poly.index] == 0 and (c.z < bed_h - 0.10 or (near_wall and c.z < bed_h + 0.02)):
                classes[poly.index] = -1
        bmb = bmesh.new()
        x0, x1, y0, y1 = -bed_w / 2, bed_w / 2, -bed_d / 2, bed_d / 2
        v = [bmb.verts.new(q) for q in ((x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0), (x0, y0, bed_h), (x1, y0, bed_h), (x1, y1, bed_h), (x0, y1, bed_h))]
        for a, b, c2, d2 in ((0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)):
            bmb.faces.new((v[a], v[b], v[c2], v[d2]))
        bmesh.ops.recalc_face_normals(bmb, faces=list(bmb.faces))
        box_mesh = bpy.data.meshes.new("bed")
        bmb.to_mesh(box_mesh)
        bmb.free()
        mark = box_mesh.attributes.new("is_bed", "INT", "FACE")
        for item in mark.data:
            item.value = 1
        box = bpy.data.objects.new("bed", box_mesh)
        bpy.context.scene.collection.objects.link(box)
        made.append(box)
        counts["bed"] = tri_count(box)
    for which, name in ((3, "bed"), (0, "wood"), (1, "lantern"), (2, "leaf")):
        only(hi)
        bpy.ops.object.duplicate()
        part = bpy.context.view_layer.objects.active
        bmp = bmesh.new()
        bmp.from_mesh(part.data)
        bmp.faces.ensure_lookup_table()
        bmesh.ops.delete(bmp, geom=[f for f in bmp.faces if classes[f.index] != which], context="FACES")
        bmp.to_mesh(part.data)
        bmp.free()
        if tri_count(part) == 0:
            bpy.data.objects.remove(part, do_unlink=True)
            continue
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-5)
        bpy.ops.object.mode_set(mode="OBJECT")
        before = tri_count(part)
        box0 = world_verts([part])
        print(f"PART {name}: {before} triangles of the generated model, z {box0[:, 2].min():.2f} to {box0[:, 2].max():.2f}")
        if name == "bed":
            # The bed's own shape (walls, a rim, planter boxes at its corners) is plain and flat-sided: cut down
            # on its own, without a rebuild, it keeps its faces; cut with the trunk it came out ragged.
            counts[name] = reduced(part, t_bed)
        elif name == "wood":
            # The cells the wood is rebuilt from: 5 cm for a great tree. A planted tree's trunk is a shell some
            # 30 cm across, and from cells that coarse it came back in tatters: there they are a fourteenth of
            # the trunk's width (no finer than 12 mm).
            wood_cell = float(opt("--parts-wood-cell", "0.05" if not opt("--planted") else str(round(min(0.05, max(0.012, report["planted"]["trunk_width_generated_m"] / 14)), 4))))
            report["wood_cell_m"] = wood_cell
            # A street tree's stem ends at its fork (raised with --planted-clear); a palm's is followed up to its head.
            tube, tube_top = stem_tube(part, fork_m if opt("--planted-clear") else None) if opt("--planted") else (None, 0.0)
            tube_tris = tri_count(tube) if tube is not None else 0
            if tri_count(part) > 0:
                counts[name] = reduced(part, max(t_wood - tube_tris, 80), remesh=wood_cell, least=0.35) + tube_tris
            else:
                counts[name] = tube_tris
            if tube is not None:
                report["stem_tube"] = {"to_m": round(float(tube_top), 2), "triangles": tube_tris}
                if tri_count(part) > 0:
                    bpy.ops.object.select_all(action="DESELECT")
                    tube.select_set(True)
                    part.select_set(True)
                    bpy.context.view_layer.objects.active = part
                    bpy.ops.object.join()
                    part = bpy.context.view_layer.objects.active
                else:
                    bpy.data.objects.remove(part, do_unlink=True)
                    part = tube
        elif name == "lantern":
            counts[name] = reduced(part, t_lantern, remesh=float(opt("--parts-lantern-cell", "0.03")), least=float(opt("--parts-lantern-least", "0.25")))
        else:
            counts[name] = reduced(part, t_leaf, remesh=float(opt("--parts-leaf-cell", "0.12")), inflate=float(opt("--parts-leaf-swell", "0.04")), least=0.5)
        box1 = world_verts([part]) if tri_count(part) else None
        print(f"PART {name}: now {tri_count(part)} triangles" + (f", z {box1[:, 2].min():.2f} to {box1[:, 2].max():.2f}" if box1 is not None else ""))
        if name == "leaf":
            mark = part.data.attributes.new("is_leaf", "INT", "FACE")
            for item in mark.data:
                item.value = 1
        made.append(part)
    bpy.ops.object.select_all(action="DESELECT")
    for part in made:
        part.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    report["parts"] = counts
    tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    d = np.array([tree.find_nearest(q)[3] for q in sample_pts])
    return o, {"tris": tri_count(o), "mean_mm": round(float(d.mean() * 1000), 2), "p95_mm": round(float(np.percentile(d, 95) * 1000), 2), "max_mm": round(float(d.max() * 1000), 1)}


planter_foot = None          # the outline of a tiered planter's lowest tier, for its bottom


def cut_planter(spec):
    """The planter cut down part by part (--planter-parts PLANTS[,BOX]): its plants and its box are told apart
    by where they are, and each is made on its own. The plants are what stands above the rim (1.5 cm clear of
    it over the walls) and, inside the walls, above the soil: rebuilt from small cells after a swell, so that
    thin leaves fuse into leaf masses, then reduced. The box is a plain one on the outline, painted from the
    generated box (the bake reads the whole generated model), or the generated box itself reduced without a
    rebuild. The walls' thickness is read off the rim's top faces and the soil's depth off the faces that look
    up inside the walls."""
    global planter_foot
    asked = [int(v) for v in spec.split(",")]
    t_plants, t_box = asked[0], (asked[1] if len(asked) > 1 else 0)
    half_w, half_d = box_w / 2, box_d / 2

    def faces_of(obj):
        polys = obj.data.polygons
        mids, nors, sizes = np.empty(len(polys) * 3), np.empty(len(polys) * 3), np.empty(len(polys))
        polys.foreach_get("center", mids)
        polys.foreach_get("normal", nors)
        polys.foreach_get("area", sizes)
        mids = mids.reshape(-1, 3)
        return mids, nors.reshape(-1, 3), sizes, np.minimum(half_w - np.abs(mids[:, 0]), half_d - np.abs(mids[:, 1]))
    centres, normals, areas, to_wall = faces_of(hi)
    # The walls' thickness: the rim's top faces lie from the outline in to the inner edge. Their area by
    # distance from the outline, in half-centimetre steps, falls away there.
    on_rim = (normals[:, 2] > 0.9) & (np.abs(centres[:, 2] - rim_h) < 0.012) & (to_wall > 0)
    hist, edges = np.histogram(to_wall[on_rim], bins=np.arange(0, 0.305, 0.005), weights=areas[on_rim])
    wall_t = 0.1
    if hist.max() > 0:
        # ... for good: three steps running with next to nothing (a joint or a leaf on the rim thins one step)
        little = 0.15 * float(np.median(hist[hist > 0.2 * hist.max()]))
        for i in range(2, len(hist) - 2):
            if (hist[i:i + 3] < little).all():
                wall_t = float(edges[i])
                break
    wall_t = min(max(wall_t, 0.03), 0.3 * min(box_w, box_d))
    wall_read = wall_t
    if opt("--planter-wall"):
        wall_t = float(opt("--planter-wall"))
    inside = (np.abs(centres[:, 0]) < half_w - wall_t) & (np.abs(centres[:, 1]) < half_d - wall_t)
    # The soil: the lower of the surfaces that look up inside the walls (leaves look up too, higher).
    looks_up = inside & (to_wall > wall_t + 0.02) & (normals[:, 2] > 0.7) & (centres[:, 2] < rim_h - 0.005) & (centres[:, 2] > 0.3 * rim_h)
    if looks_up.sum() > 20:
        order = np.argsort(centres[looks_up, 2])
        share = np.cumsum(areas[looks_up][order]) / areas[looks_up].sum()
        soil_h = float(centres[looks_up, 2][order][np.searchsorted(share, 0.35)])
    else:
        soil_h = rim_h - 0.04
    soil_h = min(soil_h, rim_h - 0.01)
    plants = np.where(inside, centres[:, 2] > soil_h + 0.012, centres[:, 2] > rim_h + 0.015)
    filled = None
    if opt("--planter-fill"):
        # The generator sees the planter from one side: it plants the edges it can see and leaves soil showing
        # in the middle, which the design draws planted full. The generated model's own plants are copied, drawn
        # in about the box's middle (SHARE of their spread) and turned (TURN degrees) so that a copy does not
        # line up with what it was copied from. Heights stay, so a copy stands on the soil as its plants did,
        # and it keeps their place in the generator's texture, so the bake finds the same leaves on it.
        values = [float(v) for v in opt("--planter-fill").split(",")]
        bmf = bmesh.new()
        bmf.from_mesh(hi.data)
        bmf.faces.ensure_lookup_table()
        source = [f for f in bmf.faces if plants[f.index]]
        for share_, turn in zip(values[0::2], values[1::2]):
            copied = bmesh.ops.duplicate(bmf, geom=source)
            ca, sa = math.cos(math.radians(turn)), math.sin(math.radians(turn))
            for v in (g for g in copied["geom"] if isinstance(g, bmesh.types.BMVert)):
                x, y = v.co.x, v.co.y
                v.co.x = (x * ca - y * sa) * share_
                v.co.y = (x * sa + y * ca) * share_
        bmf.to_mesh(hi.data)
        bmf.free()
        hi.data.update()
        before_fill = len(plants)
        centres, normals, areas, to_wall = faces_of(hi)
        inside = (np.abs(centres[:, 0]) < half_w - wall_t) & (np.abs(centres[:, 1]) < half_d - wall_t)
        plants = np.where(inside, centres[:, 2] > soil_h + 0.012, centres[:, 2] > rim_h + 0.015)
        filled = {"shares_and_turns": values, "faces_copied_in_the_generated_model": len(plants) - before_fill}
    made, counts = [], {}
    if t_box:
        only(hi)
        bpy.ops.object.duplicate()
        box = bpy.context.view_layer.objects.active
        bmp = bmesh.new()
        bmp.from_mesh(box.data)
        bmp.faces.ensure_lookup_table()
        bmesh.ops.delete(bmp, geom=[f for f in bmp.faces if plants[f.index]], context="FACES")
        bmp.to_mesh(box.data)
        bmp.free()
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-5)
        bpy.ops.object.mode_set(mode="OBJECT")
        counts["box"] = reduced(box, t_box)
        # Its outer walls pressed flat onto the outline and its foot onto the ground: the outline is what the
        # game measures. Corners rounded more than a centimetre stay rounded.
        for v in box.data.vertices:
            if abs(v.co.x) > half_w - 0.012:
                v.co.x = math.copysign(half_w, v.co.x)
            if abs(v.co.y) > half_d - 0.012:
                v.co.y = math.copysign(half_d, v.co.y)
            if v.co.z < 0.008:
                v.co.z = 0.0
        box.data.update()
    elif planter_tiers:
        # The box plain, tier by tier (--planter-tiers). Every tier is a copy of the body's own outline, read
        # off the sized model as a convex polygon between the heights where the body is wall alone (rounded
        # corners keep a few points each), grown or drawn in to the tier's width; a ledge joins a tier to the
        # next; the top tier carries the rim, the inner walls and the soil, as the plain box does.
        body_tier = max(planter_tiers, key=lambda t: t[1] - t[0])
        co_hi = np.array([v.co[:] for v in hi.data.vertices])
        clear = min(0.01, 0.25 * (body_tier[1] - body_tier[0]))
        in_body = co_hi[(co_hi[:, 2] > body_tier[0] + clear) & (co_hi[:, 2] < min(body_tier[1], rim_h) - clear) & (np.abs(co_hi[:, 0]) <= half_w + 0.02) & (np.abs(co_hi[:, 1]) <= half_d + 0.02)]
        outline = convex_outline(in_body[:, :2])
        # ... set exactly on the box's outline (the generated wall is a millimetre or two off it here and there)
        o_lo, o_hi = outline.min(axis=0), outline.max(axis=0)
        outline = (outline - (o_lo + o_hi) / 2) * np.array([box_w, box_d]) / (o_hi - o_lo)
        bmb = bmesh.new()

        def ring_of(half_x, half_y, zz):
            return [bmb.verts.new((float(x) * half_x / half_w, float(y) * half_y / half_d, zz)) for x, y in outline]
        sides = len(outline)
        below = ring_of(planter_tiers[0][2], planter_tiers[0][3], 0.0)
        for k, (z0, z1, hx, hy) in enumerate(planter_tiers):
            above = ring_of(hx, hy, z1)
            for i in range(sides):
                j = (i + 1) % sides
                bmb.faces.new((below[i], below[j], above[j], above[i]))                 # the tier's wall
            if k + 1 < len(planter_tiers):
                nxt = ring_of(planter_tiers[k + 1][2], planter_tiers[k + 1][3], z1)
                for i in range(sides):
                    j = (i + 1) % sides
                    bmb.faces.new((above[i], above[j], nxt[j], nxt[i]))                 # the ledge: looks up where the next tier is narrower, down where it is wider
                below = nxt
        top_hx, top_hy = planter_tiers[-1][2], planter_tiers[-1][3]
        lip, soil = ring_of(top_hx - wall_t, top_hy - wall_t, rim_h), ring_of(top_hx - wall_t, top_hy - wall_t, soil_h)
        for i in range(sides):
            j = (i + 1) % sides
            bmb.faces.new((above[i], above[j], lip[j], lip[i]))
            bmb.faces.new((lip[i], lip[j], soil[j], soil[i]))
        bmb.faces.new(soil)
        box_mesh = bpy.data.meshes.new("box")
        bmb.to_mesh(box_mesh)
        bmb.free()
        box = bpy.data.objects.new("box", box_mesh)
        bpy.context.scene.collection.objects.link(box)
        counts["box"] = tri_count(box)
        planter_foot = [(float(x) * planter_tiers[0][2] / half_w, float(y) * planter_tiers[0][3] / half_d) for x, y in outline]
        report["planter"]["outline_corners"] = sides
    else:
        x0, x1, y0, y1 = -half_w, half_w, -half_d, half_d
        bmb = bmesh.new()

        def ring(xa, xb, ya, yb, zz):
            return [bmb.verts.new(q) for q in ((xa, ya, zz), (xb, ya, zz), (xb, yb, zz), (xa, yb, zz))]
        foot, top = ring(x0, x1, y0, y1, 0.0), ring(x0, x1, y0, y1, rim_h)
        lip, soil = ring(x0 + wall_t, x1 - wall_t, y0 + wall_t, y1 - wall_t, rim_h), ring(x0 + wall_t, x1 - wall_t, y0 + wall_t, y1 - wall_t, soil_h)
        for k in range(4):                               # wound so that each face looks out of the stone
            k2 = (k + 1) % 4
            bmb.faces.new((foot[k], foot[k2], top[k2], top[k]))
            bmb.faces.new((top[k], top[k2], lip[k2], lip[k]))
            bmb.faces.new((lip[k], lip[k2], soil[k2], soil[k]))
        bmb.faces.new(soil)
        box_mesh = bpy.data.meshes.new("box")
        bmb.to_mesh(box_mesh)
        bmb.free()
        box = bpy.data.objects.new("box", box_mesh)
        bpy.context.scene.collection.objects.link(box)
        counts["box"] = tri_count(box)
    mark = box.data.attributes.new("is_bed", "INT", "FACE")
    for item in mark.data:
        item.value = 1
    made.append(box)
    only(hi)
    bpy.ops.object.duplicate()
    part = bpy.context.view_layer.objects.active
    bmp = bmesh.new()
    bmp.from_mesh(part.data)
    bmp.faces.ensure_lookup_table()
    bmesh.ops.delete(bmp, geom=[f for f in bmp.faces if not plants[f.index]], context="FACES")
    bmp.to_mesh(part.data)
    bmp.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.object.mode_set(mode="OBJECT")
    before = tri_count(part)
    counts["plants"] = reduced(part, t_plants, remesh=float(opt("--planter-cell", "0.02")), inflate=float(opt("--planter-swell", "0.008")),
                               least=float(opt("--planter-least", "0.12")))
    print(f"PART plants: {before} triangles of the generated model, now {counts['plants']}; walls {wall_t:.3f} m thick, soil at {soil_h:.3f} m, rim at {rim_h:.3f} m")
    mark = part.data.attributes.new("is_leaf", "INT", "FACE")
    for item in mark.data:
        item.value = 1
    made.append(part)
    bpy.ops.object.select_all(action="DESELECT")
    for part in made:
        part.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    report["parts"] = counts
    if opt("--planter-wall"):
        report["planter"]["walls_as_read_m"] = round(wall_read, 3)
    report["planter"].update({"walls_m": round(wall_t, 3), "soil_m": round(soil_h, 3), "box": "its own, cut down" if t_box else "plain",
                              "plant_faces_of_the_generated_model": int(plants.sum()), "fill": filled,
                              "rim_top_area_by_half_cm_from_the_outline": [round(float(v), 4) for v in hist[:40]]})
    tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    d = np.array([tree.find_nearest(q)[3] for q in sample_pts])
    return o, {"tris": tri_count(o), "mean_mm": round(float(d.mean() * 1000), 2), "p95_mm": round(float(np.percentile(d, 95) * 1000), 2), "max_mm": round(float(d.max() * 1000), 1)}


def drop_hidden(o):
    """Drops the faces of `o` that cannot be seen from anywhere outside it: those from whose middle no ray, in
    any of the directions of a sphere of 192 that lie more than 8 degrees above the face, leaves the piece.
    Returns how many went."""
    bmh = bmesh.new()
    bmh.from_mesh(o.data)
    tree = BVHTree.FromBMesh(bmh)
    golden = math.pi * (3.0 - math.sqrt(5.0))
    rays = []
    for i in range(192):
        z = 1.0 - 2.0 * (i + 0.5) / 192
        r = math.sqrt(max(0.0, 1.0 - z * z))
        rays.append(Vector((r * math.cos(golden * i), r * math.sin(golden * i), z)))
    lift = 1e-4 * max(diag, 1.0)
    doomed = []
    for f in bmh.faces:
        normal = f.normal
        origin = f.calc_center_median() + normal * lift
        if not any(ray.dot(normal) > 0.14 and tree.ray_cast(origin, ray)[0] is None for ray in rays):
            doomed.append(f)
    if doomed:
        bmesh.ops.delete(bmh, geom=doomed, context="FACES")
        loose = [v for v in bmh.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bmh, geom=loose, context="VERTS")
        # What is left of the inner skin beside a gap (its faces there do see out): small bits, torn open where
        # their neighbours went. A bit with an open edge and under a fiftieth of the piece's faces goes too; a
        # small part that is whole (a hook, a finial) has no open edge and stays.
        bmh.verts.ensure_lookup_table()
        seen, crumbs, total = set(), [], len(bmh.faces)
        for v in bmh.verts:
            if v.index in seen:
                continue
            stack, part = [v], []
            seen.add(v.index)
            while stack:
                u = stack.pop()
                part.append(u)
                for e in u.link_edges:
                    w = e.other_vert(u)
                    if w.index not in seen:
                        seen.add(w.index)
                        stack.append(w)
            faces = {f for u in part for f in u.link_faces}
            if len(faces) < 0.02 * total and any(len(e.link_faces) == 1 for u in part for e in u.link_edges):
                crumbs += part
        if crumbs:
            bmesh.ops.delete(bmh, geom=crumbs, context="VERTS")
        bmh.to_mesh(o.data)
        o.data.update()
    bmh.free()
    return len(doomed)


def cut(target, rebuild=None):
    """The generated model cut down to `target` triangles. `rebuild` is the cell size of a rebuilt surface to
    cut from (--remesh, or the fallback below)."""
    rebuild = rebuild or (float(opt("--remesh")) if opt("--remesh") else None)
    only(cut_from)
    bpy.ops.object.duplicate()
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.object.mode_set(mode="OBJECT")
    if "--split" in argv:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_mode(type="EDGE")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.mesh.select_non_manifold(extend=False, use_wire=True, use_boundary=False, use_multi_face=True, use_non_contiguous=True, use_verts=True)
        bpy.ops.mesh.edge_split(type="EDGE")
        bpy.ops.object.mode_set(mode="OBJECT")
    if opt("--inflate"):
        # Leaves thinner than a cell of the rebuild vanish in it: swell the surface first, so they survive as
        # small masses (chunkier than drawn, but there).
        dp = o.modifiers.new("swell", "DISPLACE")
        dp.strength = float(opt("--inflate"))
        dp.mid_level = 0.0
        bpy.ops.object.modifier_apply(modifier=dp.name)
    points = sample_pts
    if rebuild:
        rm = o.modifiers.new("rebuild", "REMESH")
        rm.mode = "VOXEL"
        rm.voxel_size = rebuild
        rm.adaptivity = 0.0
        bpy.ops.object.modifier_apply(modifier=rm.name)
        # A generated model has surfaces inside it (where its parts run into each other); the rebuilt surface
        # is its outside alone. Points on those inner surfaces are far from any outside, so the deviation of a
        # piece cut from a rebuilt surface is measured from points on that surface.
        picks = np.random.default_rng(7).choice(len(o.data.vertices), size=min(6000, len(o.data.vertices)), replace=False)
        points = [o.data.vertices[int(i)].co.copy() for i in picks]
        report["rebuilt_surface_m"] = round(float(rebuild), 4)
    if opt("--min-part"):
        # The rebuild leaves hundreds of specks (a leaf tip, a crumb of bark), each a closed bit the reduction
        # cannot take below four triangles: it then takes the triangles from the trunk and the bed instead.
        # Bits smaller across than this go first.
        least = float(opt("--min-part"))
        bm2 = bmesh.new()
        bm2.from_mesh(o.data)
        bm2.verts.ensure_lookup_table()
        seen2, doomed = set(), []
        for v in bm2.verts:
            if v.index in seen2:
                continue
            stack, part = [v], []
            seen2.add(v.index)
            while stack:
                u = stack.pop()
                part.append(u)
                for e in u.link_edges:
                    w = e.other_vert(u)
                    if w.index not in seen2:
                        seen2.add(w.index)
                        stack.append(w)
            cs = np.array([q.co[:] for q in part])
            if float(np.linalg.norm(cs.max(axis=0) - cs.min(axis=0))) < least:
                doomed += part
        if doomed:
            bmesh.ops.delete(bm2, geom=doomed, context="VERTS")
            bm2.to_mesh(o.data)
        bm2.free()
    n = tri_count(o)
    hidden_from = "--drop-hidden" in argv and not opt("--planar")
    if hidden_from and n > target:
        # The skin inside the shell: cut to a count at which every face can be asked whether it sees out, drop
        # those that do not, and go on from what is left.
        first = min(n, int(opt("--drop-hidden-from", str(6 * target))))
        if n > first:
            mod = o.modifiers.new("cut", "DECIMATE")
            mod.ratio = first / n
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        before = tri_count(o)
        report["hidden_faces_dropped"] = {"of": before, "dropped": drop_hidden(o)}
        picks = np.random.default_rng(7).choice(len(o.data.vertices), size=min(6000, len(o.data.vertices)), replace=False)
        points = [o.data.vertices[int(i)].co.copy() for i in picks]
        n = tri_count(o)
    if opt("--planar") and n > target:
        # Flat-sided bars: cut to a count that still holds the round parts, join what lies flat, cut again.
        first = min(n, int(opt("--planar-from", str(3 * target))))
        for step in ("first", "hidden", "flat", "last"):
            n = tri_count(o)
            if step == "hidden":
                if "--drop-hidden" in argv:
                    report["hidden_faces_dropped"] = {"of": n, "dropped": drop_hidden(o)}
                    picks = np.random.default_rng(7).choice(len(o.data.vertices), size=min(6000, len(o.data.vertices)), replace=False)
                    points = [o.data.vertices[int(i)].co.copy() for i in picks]
            elif step == "flat":
                mod = o.modifiers.new("flat", "DECIMATE")
                mod.decimate_type = "DISSOLVE"
                mod.angle_limit = math.radians(float(opt("--planar")))
                bpy.ops.object.modifier_apply(modifier=mod.name)
                mod = o.modifiers.new("triangles", "TRIANGULATE")
                bpy.ops.object.modifier_apply(modifier=mod.name)
                report["planar"] = {"degrees": float(opt("--planar")), "from": n, "to": tri_count(o)}
            elif n > (first if step == "first" else target):
                mod = o.modifiers.new("cut", "DECIMATE")
                mod.ratio = (first if step == "first" else target) / n
                mod.use_collapse_triangulate = True
                bpy.ops.object.modifier_apply(modifier=mod.name)
    elif n > target:
        mod = o.modifiers.new("cut", "DECIMATE")
        mod.ratio = target / n
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if tri_count(o) > 1.15 * target and not rebuild:
        # The reduction stalled: the generated mesh has edges shared by three or more faces, which it will not
        # collapse (seen on trees, and on some seats: an armchair stopped at 14,859 of 1,500 asked for and came
        # out a crumpled sheet). Cut from a rebuilt surface instead, its cells 1/180 of the piece's diagonal.
        bpy.data.objects.remove(o, do_unlink=True)
        report["rebuilt_because_stalled_m"] = round(diag / 180, 4)
        return cut(target, rebuild=diag / 180)
    tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    d = np.array([tree.find_nearest(p)[3] for p in points])
    return o, {"tris": tri_count(o), "mean_mm": round(float(d.mean() * 1000), 2), "p95_mm": round(float(np.percentile(d, 95) * 1000), 2), "max_mm": round(float(d.max() * 1000), 1),
               "measured_from": ("the rebuilt surface" if rebuild else "the generated model") + (", its hidden faces dropped" if "--drop-hidden" in argv else "")}


def cut_bed(target):
    """A kerbed bed cut down in two parts (--bed). The kerb is what the game sizes the bed by and what its
    collision audit reads, so it is a plain box on the kit piece's sides, as high as the kerb (ten triangles):
    the generated kerb stays in the model the colours are baked from, so the box takes its stone and its
    joints, and its top a picture of the coping and the soil. Everything that stands above the kerb or hangs
    outside its walls is plant, and takes the rest of the triangles: swollen a little (--inflate, default
    0.004 m), rebuilt from small cells (--remesh, default 0.012 m), the specks dropped (--min-part, default
    0.05 m) and cut down. Cut as one mesh the plants and the kerb are fused by the rebuild: the flowers melt
    into a carpet and the walls come out dented where a plant hangs over them."""
    k_lo, k_hi = kit_box
    me = hi.data
    f_c = np.empty(len(me.polygons) * 3)
    me.polygons.foreach_get("center", f_c)
    f_c = f_c.reshape(-1, 3)
    # Plant: what stands more than 25 mm above the kerb's top or outside its walls. The generated kerb is not
    # the box to the millimetre (its blocks' edges and its coping stand a little proud), and what of it lay
    # just outside the box came through as a pale frame of stone round every wall.
    skin_of_kerb = 0.025
    plant = ((f_c[:, 2] > kerb_h + skin_of_kerb) | (f_c[:, 0] < k_lo[0] - skin_of_kerb) | (f_c[:, 0] > k_hi[0] + skin_of_kerb)
             | (f_c[:, 1] < k_lo[1] - skin_of_kerb) | (f_c[:, 1] > k_hi[1] + skin_of_kerb))
    bmb = bmesh.new()
    x0, x1, y0, y1 = float(k_lo[0]), float(k_hi[0]), float(k_lo[1]), float(k_hi[1])
    v = [bmb.verts.new(q) for q in ((x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0), (x0, y0, kerb_h), (x1, y0, kerb_h), (x1, y1, kerb_h), (x0, y1, kerb_h))]
    for a, b, c2, d2 in ((0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)):
        bmb.faces.new((v[a], v[b], v[c2], v[d2]))
    bmesh.ops.recalc_face_normals(bmb, faces=list(bmb.faces))
    box_mesh = bpy.data.meshes.new("kerb")
    bmb.to_mesh(box_mesh)
    bmb.free()
    mark = box_mesh.attributes.new("is_bed", "INT", "FACE")
    for item in mark.data:
        item.value = 1
    box = bpy.data.objects.new("kerb", box_mesh)
    bpy.context.scene.collection.objects.link(box)
    counts = {"kerb": tri_count(box)}
    only(hi)
    bpy.ops.object.duplicate()
    part = bpy.context.view_layer.objects.active
    bmp = bmesh.new()
    bmp.from_mesh(part.data)
    bmp.faces.ensure_lookup_table()
    bmesh.ops.delete(bmp, geom=[f for f in bmp.faces if not plant[f.index]], context="FACES")
    bmp.to_mesh(part.data)
    bmp.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5)
    bpy.ops.object.mode_set(mode="OBJECT")
    counts["plants_generated"] = tri_count(part)
    cell = float(opt("--remesh", "0.012"))
    counts["plants"] = reduced(part, target - counts["kerb"], remesh=cell, inflate=float(opt("--inflate", "0.004")), least=float(opt("--min-part", "0.05")))
    mark = part.data.attributes.new("is_leaf", "INT", "FACE")
    for item in mark.data:
        item.value = 1
    bpy.ops.object.select_all(action="DESELECT")
    box.select_set(True)
    part.select_set(True)
    bpy.context.view_layer.objects.active = box
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    report["parts"] = counts
    report["rebuilt_surface_m"] = cell
    tree = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    d = np.array([tree.find_nearest(q)[3] for q in sample_pts])
    return o, {"tris": tri_count(o), "mean_mm": round(float(d.mean() * 1000), 2), "p95_mm": round(float(np.percentile(d, 95) * 1000), 2), "max_mm": round(float(d.max() * 1000), 1),
               "measured_from": "the generated model"}


bake_further = 0.0          # how much further than usual the bakes look for the generated surface (a skin held out from it)
skin_from = None            # the point on the axis a skin was drawn from


def skin(target):
    """A skin of `target` triangles drawn over the generated model from outside (--skin). A generated shrub is
    tens of thousands of leaves, each a thin sheet: rebuilt from cells it comes out with an inner wall behind
    the outer one, and cut down straight it comes out as shards. A shrub is a mass seen from outside, so its
    outside alone is taken: seen from a point on its axis, in evenly spread directions, the farthest the model
    stands along each direction and close round it is where the skin stands. With --shrub, 48 of the
    directions lie level at the height of the widest ring, so that the skin has a ring of edges there to make
    the circle of; with --skin-tuck 48 more point at the foot of the line the skin is held out to, so that it
    meets the ground in a clean ring, and what would lie flat on the ground under the piece is left out."""
    ring_n = 48 if want_reach is not None else 0
    tuck = float(opt("--skin-tuck")) if (opt("--skin-tuck") and ring_n) else None
    pts_hi = world_verts([hi])
    floor = float(pts_hi[:, 2].min())
    centre = np.array([0.0, 0.0, ring_z]) if want_reach is not None else np.array([*((pts_hi.min(axis=0) + pts_hi.max(axis=0))[:2] / 2), floor + 0.4 * np.ptp(pts_hi[:, 2])])
    tree = BVHTree.FromObject(hi, bpy.context.evaluated_depsgraph_get())
    far = 3 * float(np.linalg.norm(pts_hi.max(axis=0) - pts_hi.min(axis=0)))
    from_centre = pts_hi - centre
    how_far = np.linalg.norm(from_centre, axis=1)
    towards = from_centre / np.maximum(how_far, 1e-9)[:, None]

    def reach_along(some, spread, share=1.0):
        """The farthest the model stands along each of the directions `some`: of all its corners that lie, seen
        from the centre, within three quarters of the way to the neighbouring directions, the farthest (measured
        along the direction). One leaf tip is so shared by the directions round it, and a gap between two
        leaves makes no pit. With `share` under 1, not the farthest but the distance that share of those
        corners lie within (a half: the middle of the leaves in that direction)."""
        out_ = np.zeros(len(some))
        near = math.cos(float(opt("--skin-wide", "0.75")) * spread)
        for i0 in range(0, len(some), 48):
            along = towards @ some[i0: i0 + 48].T                         # corners by directions
            if share >= 1.0:
                out_[i0: i0 + 48] = np.where(along >= near, along * how_far[:, None], 0.0).max(axis=0)
            else:
                with np.errstate(all="ignore"):
                    out_[i0: i0 + 48] = np.nan_to_num(np.nanquantile(np.where(along >= near, along * how_far[:, None], np.nan), share, axis=0))
        return out_

    turns = 2 * math.pi * np.arange(ring_n) / max(ring_n, 1)
    ring_dirs = np.stack([np.cos(turns), np.sin(turns), np.zeros(ring_n)], axis=1) if ring_n else np.zeros((0, 3))
    ring_r = reach_along(ring_dirs, 2 * math.pi / ring_n) if ring_n else np.zeros(0)
    foot = np.zeros((0, 3))
    if tuck is not None:
        # The foot of the line the skin is held out to: on the ground, `tuck` of the ring's radius in from the
        # ring. Its 48 directions are one level circle (so that each is a corner of the skin with the ring
        # above it); where each corner stands is set below, from the ring's own radius in its direction.
        foot_at = np.stack([np.cos(turns) * ring_r * (1 - tuck), np.sin(turns) * ring_r * (1 - tuck), np.full(ring_n, floor)], axis=1)
        foot = np.stack([np.cos(turns) * ring_r.mean() * (1 - tuck), np.sin(turns) * ring_r.mean() * (1 - tuck), np.full(ring_n, floor)], axis=1) - centre
        foot = foot / np.linalg.norm(foot, axis=1)[:, None]
        foot_up = float(foot[0, 2])

    def directions(m):
        k = np.arange(m)
        up = 1 - 2 * (k + 0.5) / m
        turn = k * math.pi * (3 - math.sqrt(5))
        d = np.stack([np.cos(turn) * np.sqrt(1 - up * up), np.sin(turn) * np.sqrt(1 - up * up), up], axis=1)
        keep = np.ones(m, dtype=bool)
        room = 0.6 * math.sqrt(4 * math.pi / m)
        if ring_n:
            keep[np.abs(np.arcsin(up)) < room] = False                     # room for the ring
        if tuck is not None:
            keep[np.abs(np.arcsin(up) - math.asin(foot_up)) < room] = False          # and for the foot's
            keep[np.arcsin(up) < math.asin(foot_up)] = False                # under the piece: nothing
        else:
            keep[(up < -0.5) & (k % 3 != 0)] = False                       # under the piece: a third as many
        return d[keep]

    spare = 2 * ring_n if tuck is not None else ring_n
    count = max(target // 2 + 2, 20)                                       # a closed skin of V corners has 2V - 4 triangles
    made = None
    for _ in range(4):
        m = max(count - spare, 8)
        while len(directions(m)) < count - spare:
            m += 1
        free = directions(m)[: count - spare]
        spread = math.sqrt(4 * math.pi / m)                                # how far apart neighbouring directions are, radians
        dirs = np.concatenate([ring_dirs, foot, free])
        bms = bmesh.new()
        for d in dirs:
            bms.verts.new(tuple(d))
        bmesh.ops.convex_hull(bms, input=list(bms.verts))
        bms.verts.index_update()
        bms.verts.ensure_lookup_table()
        if tuck is not None:
            # what lies under the piece (the faces between the foot's corners alone) is left out; the corners stay
            under = [f for f in bms.faces if all(ring_n <= v.index < 2 * ring_n for v in f.verts)]
            bmesh.ops.delete(bms, geom=under, context="FACES_ONLY")
        if made is not None:
            made.free()
        made = bms
        if len(bms.faces) == target or len(bms.faces) > target - 2 and len(bms.faces) <= target:
            break
        count += (target - len(bms.faces)) // 2
    bms = made
    assert len(bms.verts) == len(dirs), "the skin lost a corner"
    bmesh.ops.recalc_face_normals(bms, faces=list(bms.faces))
    radii = np.concatenate([ring_r, reach_along(dirs[ring_n:], spread)])
    if opt("--leaves") and ring_n:
        # A loose shrub's skin is its inside (see --leaves): away from its ring it stands in the middle of the
        # leaves, where the share CORE of the model's corners in each direction lie nearer the axis; at its ring
        # it stays the outside, and between the two (within about 9 degrees of level) it passes from one to
        # the other.
        given = opt("--leaves").split(",")
        share = float(given[3]) if len(given) > 3 else 0.5
        rise = np.degrees(np.arcsin(np.clip(dirs[ring_n:, 2], -1, 1)))
        middle = reach_along(dirs[ring_n:], spread, share)
        # towards its top the inside stands deeper (half that share straight up): a loose shrub's top is a few
        # sprays, and an inside set in the middle of them is a bare dome between them
        middle += (reach_along(dirs[ring_n:], spread, share / 2) - middle) * np.clip(rise / 90.0, 0, 1)
        at_ring = np.exp(-(rise / 9.0) ** 2)
        radii[ring_n:] = middle + (radii[ring_n:] - middle) * at_ring
    missed = radii <= 0
    radii[missed] = 0.02
    # How far behind the skin the model's surface lies where the skin bridges a gap (what a single ray from
    # outside meets first): the bakes have to look that far in.
    first = np.array([(lambda hit: float((np.array(hit[0]) - centre) @ d) if hit[0] is not None else 0.0)(tree.ray_cast(Vector(centre + d * far), Vector(-d), far)) for d in dirs])
    behind = float(np.maximum(radii - first, 0.0).max())
    filled = 0.0
    if tuck is not None:
        # Under the ring the skin is held out to a line: upright at the ring, `tuck` of the ring's radius in at
        # the ground (r = ring * (1 - tuck * (1 - z / ring height) ** 2)). A loose shrub's inside (--leaves) is
        # held out too, to a straight line from its ring to its foot (the fan its stems make): left as narrow
        # as the stems, a shrub that is widest high up came out as a table on a stalk, and held out to the
        # curved line, as a bowl.
        height = centre[2] - floor
        for i in range(ring_n, len(dirs)):
            d = dirs[i]
            if d[2] >= 0:
                continue
            level = math.hypot(d[0], d[1])
            here = float(np.interp(math.degrees(math.atan2(d[1], d[0])) % 360, np.degrees(turns), ring_r, period=360))
            a_ = here * tuck * d[2] * d[2] / (height * height)
            on_line = (-level + math.sqrt(level * level + 4 * a_ * here)) / (2 * a_) if a_ > 1e-9 else here / max(level, 1e-9)
            if opt("--leaves"):
                on_line = here / (level + here * tuck * -d[2] / height)
            least = min(on_line, height / -d[2])                           # the line, or the ground under it
            if radii[i] < least:
                filled = max(filled, least - radii[i])
                radii[i] = least
    for i, (v, d, r) in enumerate(zip(bms.verts, dirs, radii)):
        q = centre + d * r
        if tuck is not None and ring_n <= i < 2 * ring_n:
            q = foot_at[i - ring_n]                                        # the foot's corners stand on the ground
        v.co = (q[0], q[1], max(q[2], floor))
    loose = [e for e in bms.edges if not e.link_faces]
    if loose:
        bmesh.ops.delete(bms, geom=loose, context="EDGES")
    mesh = bpy.data.meshes.new("skin")
    bms.to_mesh(mesh)
    bms.free()
    o = bpy.data.objects.new("skin", mesh)
    bpy.context.scene.collection.objects.link(o)
    report["skin"] = {"directions": int(len(dirs)), "ring_directions": ring_n, "foot_directions": int(len(foot)), "missed": int(missed.sum()),
                      "from_m": [round(float(v), 3) for v in centre], "held_out_under_the_ring_by_up_to_m": round(filled, 3)}
    report["skin"]["surface_behind_the_skin_by_up_to_m"] = round(behind, 3)
    global bake_further, skin_from
    bake_further = max(filled, behind)                                     # the bakes look that much further in
    skin_from = centre
    tree_o = BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())
    dist = np.array([tree_o.find_nearest(q)[3] for q in sample_pts])
    return o, {"tris": tri_count(o), "mean_mm": round(float(dist.mean() * 1000), 2), "p95_mm": round(float(np.percentile(dist, 95) * 1000), 2), "max_mm": round(float(dist.max() * 1000), 1),
               "measured_from": "the generated model, whose inner leaves the skin leaves out"}


if opt("--parts"):
    lo_obj, numbers = cut_parts(opt("--parts"))
elif opt("--planter-parts") and opt("--planter"):
    lo_obj, numbers = cut_planter(opt("--planter-parts"))
elif opt("--skin"):
    lo_obj, numbers = skin(int(opt("--skin")))
elif opt("--bed"):
    lo_obj, numbers = cut_bed(max_tris if tris_arg == "auto" else int(tris_arg))
elif tris_arg == "auto":
    tried = []
    lo_obj = None
    for target in (1500, 2000, 3000, 4000, 6000, 9000, 14000):
        if target > max_tris:
            break
        cand, numbers = cut(target)
        tried.append(numbers)
        if lo_obj is not None:
            bpy.data.objects.remove(lo_obj, do_unlink=True)
        lo_obj = cand
        within = [float(v) for v in opt("--within").split(",")] if opt("--within") else [1.6 * diag, 8.0 * diag]      # 0.16% and 0.8% of the diagonal
        if numbers["p95_mm"] <= within[0] and numbers["max_mm"] <= within[1]:
            break
    report["tried"] = tried
else:
    lo_obj, numbers = cut(int(tris_arg))
report["tris"] = tri_count(lo_obj)
report["deviation"] = numbers
if cut_from is not hi and basin_ring is None:
    bpy.data.objects.remove(cut_from, do_unlink=True)          # a copy made to be cut down from (a shelter's, its canopy rebuilt)
if not opt("--remesh"):
    reach = float(np.clip(1.5 * numbers["p95_mm"] / 1000, 0.01 * diag, float(opt("--bake-reach-most", "0.02")) * diag))
if opt("--bake-reach"):
    reach = float(opt("--bake-reach"))
report["bake_reach_m"] = round(reach, 4)
report["diagonal_m"] = round(diag, 3)
pool_painted = opt("--fountain-pool", "flat") == "painted"
if basin_ring is not None:
    # The basin's ring, built by rule, joins the piece here: it is given its place in the texture and its
    # colours (from the generated wall, which is still in the model the colours are baked from) with the rest.
    # So does the water's disc when it is to be painted from the generated water (--fountain-pool painted).
    bpy.ops.object.select_all(action="DESELECT")
    basin_ring.select_set(True)
    if pool_painted:
        water_disc.select_set(True)
    lo_obj.select_set(True)
    bpy.context.view_layer.objects.active = lo_obj
    bpy.ops.object.join()
    lo_obj = bpy.context.view_layer.objects.active
    report["tris"] = tri_count(lo_obj)
    bpy.data.objects.remove(cut_from, do_unlink=True)
lo_obj.name = opt("--mesh-name", "body")
lo_obj.data.name = opt("--mesh-name", "body")


def band_points(obj, z0=0.15, z1=2.2):
    """What a piece draws where people walk, by the game's own measure (kit_town.gd band_points_of): its corners
    between the two heights and the points where its edges cross them."""
    co = np.array([v.co[:] for v in obj.data.vertices])
    found = [co[(co[:, 2] >= z0) & (co[:, 2] <= z1)]]
    ed = np.array([e.vertices[:] for e in obj.data.edges])
    a, b = co[ed[:, 0]], co[ed[:, 1]]
    den = b[:, 2] - a[:, 2]
    for level in (z0, z1):
        with np.errstate(divide="ignore", invalid="ignore"):
            f = (level - a[:, 2]) / den
        crossing = (den != 0) & (f > 0) & (f < 1)
        found.append(a[crossing] + (b[crossing] - a[crossing]) * f[crossing][:, None])
    return np.concatenate(found)


if "--panel" in argv or "--axis" in argv:
    # A fixture stands on the ground. The reduction can lift a foot's lowest corners off it by a centimetre or
    # two (the solarpunk planter's by 1.6 cm): where the lowest lie under 3 cm, those within a centimetre of
    # the lowest are put on the ground.
    co = np.array([v.co[:] for v in lo_obj.data.vertices])
    lowest = float(co[:, 2].min())
    if 0.0005 < abs(lowest) < 0.03:
        down = co[:, 2] < lowest + 0.01
        co[down, 2] = 0.0
        lo_obj.data.vertices.foreach_set("co", co.ravel())
        lo_obj.data.update()
        report["stood_on_the_ground"] = {"lowest_was_m": round(lowest, 4), "corners_moved": int(down.sum())}
if "--panel" in argv and kit_box is not None:
    # The game lays panels 2 m apart and takes each to run from -1 to +1: the cut-down piece's two ends are
    # put exactly there (the reduction moves them by a millimetre or two). And it sets the whole fence off
    # the floor by the piece's half depth where people walk, measured from z = 0, so the piece is centred
    # across on what it draws between 0.15 and 2.2 m, to lie alike on both sides.
    co = np.array([v.co[:] for v in lo_obj.data.vertices])
    was = [float(co[:, 0].min()), float(co[:, 0].max())]
    co[:, 0] = kit_box[0][0] + (co[:, 0] - was[0]) * (kit_box[1][0] - kit_box[0][0]) / (was[1] - was[0])
    co[co[:, 0] > kit_box[1][0] - 0.003, 0] = kit_box[1][0]          # the rails' ends, flat on the +x end
    lo_obj.data.vertices.foreach_set("co", co.ravel())
    lo_obj.data.update()
    across = band_points(lo_obj)[:, 1]
    shift = (kit_box[0][1] + kit_box[1][1]) / 2 - float(across.min() + across.max()) / 2
    for o in (lo_obj, hi):
        o.data.transform(Matrix.Translation(Vector((0.0, shift, 0.0))))
        o.data.update()
    across = band_points(lo_obj)[:, 1]
    report["panel"]["ends_before_m"] = [round(v, 4) for v in was]
    report["panel"]["moved_across_m"] = round(shift, 4)
    report["panel"]["half_depth_in_band_m"] = [round(float(-across.min()), 4), round(float(across.max()), 4)]
if want_reach is not None and opt("--leaves") and skin_from is not None:
    # A loose shrub's reach is its leaves', which are the generated model's and already inside the circle: its
    # skin, which will be its inside, is only held inside the circle too (a skin stands a little outside the
    # model where it bridges from one leaf tip to the next).
    co = np.empty(len(lo_obj.data.vertices) * 3)
    lo_obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    rr = np.hypot(co[:, 0], co[:, 1])
    beyond = rr > want_reach
    co[beyond, :2] *= (want_reach / rr[beyond])[:, None]
    lo_obj.data.vertices.foreach_set("co", co.ravel())
    lo_obj.data.update()
    report["shrub"]["skin_corners_held_inside_the_circle"] = int(beyond.sum())
elif want_reach is not None:
    # The reduction moves the outline a little. The reach is held on the piece itself (and the generated model
    # follows, so the bakes still meet it).
    f = want_reach / band_reach([lo_obj])
    for o in (lo_obj, hi):
        co = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        co[:, :2] *= f
        o.data.vertices.foreach_set("co", co.ravel())
        o.data.update()
    report["shrub"]["cut_down_scaled_across"] = round(float(f), 4)
core_vertices = None          # with --leaves: how many of the piece's vertices, the first ones, are its inside
flower_colours = []           # with --flowers: the colours given (hex)
if opt("--leaves") and skin_from is not None and want_reach is not None:
    # A loose shrub: the skin is its dark inside (skin() set it in the middle of the leaves), and the generated
    # model's own leaves and flowers are set on it as separate blades and flowers, so that it has an outline
    # of leaves and gaps between them.
    values = opt("--leaves").split(",")
    n_leaves, leaf_len, leaf_wid = int(values[0]), float(values[1]), float(values[2])
    space = float(values[4]) if len(values) > 4 else 0.5 * leaf_len
    rng_l = np.random.default_rng(21)
    me = lo_obj.data
    co = np.array([v.co[:] for v in me.vertices])
    floor = float(co[:, 2].min())
    core_vertices = len(me.vertices)
    # 1. How far each face of the inside is from its ring (0 on it, 1 well above and below), for its shade.
    rel = co - skin_from
    off_ring = 1 - np.exp(-(np.degrees(np.arctan2(rel[:, 2], np.maximum(np.hypot(rel[:, 0], rel[:, 1]), 1e-9))) / 9.0) ** 2)
    drawn = me.attributes.new("drawn_in", "FLOAT", "FACE")
    for poly in me.polygons:
        # what faces down is under the leaves, and as dark as the inside gets wherever it is
        drawn.data[poly.index].value = 1.0 if poly.normal.z < -0.25 else float(np.mean([off_ring[i] for i in poly.vertices]))
    me.attributes.new("part", "INT", "FACE")          # 0 the inside, 1 a leaf, 2 a petal, 3 a flower's centre
    bpy.context.view_layer.update()
    inside_tree = BVHTree.FromObject(lo_obj, bpy.context.evaluated_depsgraph_get())

    def shows(point):
        """Whether a point of the model lies outside the shrub's inside (seen from the point on its axis)."""
        away = np.array(point) - skin_from
        far = float(np.linalg.norm(away))
        if far < 1e-6:
            return False
        hit = inside_tree.ray_cast(Vector(skin_from), Vector(away / far))
        return hit[0] is not None and far > (hit[0] - Vector(skin_from)).length + 0.005

    # 2. What the generator painted each face of the model: leaf, flower or neither.
    src = hi.data
    n_f = len(src.polygons)
    f_c, f_n, f_a = np.empty(n_f * 3), np.empty(n_f * 3), np.empty(n_f)
    src.polygons.foreach_get("center", f_c)
    src.polygons.foreach_get("normal", f_n)
    src.polygons.foreach_get("area", f_a)
    f_c, f_n = f_c.reshape(-1, 3), f_n.reshape(-1, 3)
    painted = face_colours(hi)
    mx, mn = painted.max(axis=1), painted.min(axis=1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    hue = np.degrees(np.arctan2(np.sqrt(3) * (painted[:, 1] - painted[:, 2]), 2 * painted[:, 0] - painted[:, 1] - painted[:, 2])) % 360
    leafy = (painted[:, 1] > painted[:, 2] * 1.25) & (painted[:, 1] >= painted[:, 0] * 0.9)
    verts, faces, kinds, tints, paints = [], [], [], [], []
    held_in = 0

    def add(points, triangles, kind, tint=0, paint=(-1.0, -1.0, -1.0)):
        """Adds corners and triangles to what stands on the inside; nothing outside the circle or under the ground."""
        global held_in
        base = len(verts)
        for q in points:
            q = np.array(q, dtype=float)
            r = float(np.hypot(q[0], q[1]))
            if r > 0.998 * want_reach:
                q[:2] *= 0.998 * want_reach / r
                held_in += 1
            q[2] = max(q[2], floor + 0.01)
            verts.append(tuple(q))
        for t in triangles:
            faces.append(tuple(base + i for i in t))
            kinds.append(kind)
            tints.append(tint)
            paints.append(paint)

    brought = {}          # the leaves brought out from under the ring: face -> where it stands now

    def spaced(order_, least, most_, bring=False):
        """Of the model's faces `order_`, taken in that order: those that show outside the inside and stand at
        least `least` from every one kept before, up to `most_` of them. With `bring`, a face under the ring
        that lies inside the inside is brought straight out to its surface (a shrub drawn as a ball tucks
        under itself, and the inside is held out there so that the shrub stands on the ground: the ball's
        lower leaves are set on what it is held out to)."""
        cells_, kept_ = {}, []
        for i in order_:
            if len(kept_) >= most_:
                break
            at_, moved_ = f_c[i], False
            if not shows(at_):
                level_ = float(np.hypot(at_[0], at_[1]))
                if not bring or at_[2] > ring_z - 0.02 or level_ < 1e-6:
                    continue
                out_ = Vector((at_[0] / level_, at_[1] / level_, 0.0))
                hit = inside_tree.ray_cast(Vector((0.0, 0.0, float(at_[2]))), out_)
                if hit[0] is None:
                    continue
                at_, moved_ = np.array(hit[0] + 0.012 * out_), True
            cell = tuple(np.floor(at_ / least).astype(int))
            if any(np.sum((other - at_) ** 2) < least * least for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
                   for other in cells_.get((cell[0] + dx, cell[1] + dy, cell[2] + dz), ())):
                continue
            cells_.setdefault(cell, []).append(at_)
            kept_.append(int(i))
            if moved_:
                brought[int(i)] = at_
        return kept_

    def by_chance(pool_):
        """Faces in a chance order in which a larger face comes sooner (the same every run)."""
        return pool_[np.argsort(-rng_l.random(len(pool_)) ** (f_a[pool_].mean() / np.maximum(f_a[pool_], 1e-12)))]

    def frame(i):
        """A face's place, the way it faces (outwards) and the way out from the shrub's axis there. A leaf brought
        out from under the ring stands where it was brought to, and faces mostly straight out."""
        at_ = brought.get(int(i), f_c[i])
        out_ = at_ - skin_from
        out_ = out_ / max(float(np.linalg.norm(out_)), 1e-9)
        facing = f_n[i] if f_n[i] @ out_ > 0 else -f_n[i]
        if int(i) in brought:
            level_ = np.array([at_[0], at_[1], 0.0]) / max(float(np.hypot(at_[0], at_[1])), 1e-9)
            facing = 0.7 * level_ + 0.3 * facing
            facing /= max(float(np.linalg.norm(facing)), 1e-9)
        return at_, facing, out_

    # 3. Flowers: what is painted in a flower's hue. Where it lies together it is one patch; a patch no wider
    #    than a flower is one flower, a wider one (a spray of small blossoms) several.
    flower_face = np.zeros(n_f, dtype=bool)
    flowers = 0
    if opt("--flowers"):
        from mathutils import kdtree
        given = opt("--flowers").split(",")
        most, widest = int(given[0]), float(given[1])
        flower_colours = given[2:]
        which = np.full(n_f, -1)
        for k, text in enumerate(flower_colours):
            r, g, b = (int(text[i:i + 2], 16) / 255 for i in (1, 3, 5))
            t_mx, t_mn = max(r, g, b), min(r, g, b)
            t_sat = (t_mx - t_mn) / max(t_mx, 1e-4)
            t_hue = math.degrees(math.atan2(math.sqrt(3) * (g - b), 2 * r - g - b)) % 360
            if t_sat >= 0.25:
                warm = t_hue < 50 or t_hue > 330                                # bark is warm too, and darker
                near = np.abs((hue - t_hue + 180) % 360 - 180) <= 40
                match = near & (sat >= 0.25) & (mx >= (0.5 if warm else 0.3)) & ~leafy
            else:
                match = (mx >= 0.7) & (sat <= 0.42)                             # a white flower is painted pale
            which[match & (which < 0)] = k
        flower_face = which >= 0
        ids = np.nonzero(flower_face)[0]
        patches = []
        if len(ids):
            kd = kdtree.KDTree(len(ids))
            for j, i in enumerate(ids):
                kd.insert(f_c[i], j)
            kd.balance()
            group = np.full(len(ids), -1)
            for j in range(len(ids)):
                if group[j] >= 0:
                    continue
                group[j] = len(patches)
                stack, members = [j], []
                while stack:
                    u = stack.pop()
                    members.append(ids[u])
                    for _co, v, _d in kd.find_range(f_c[ids[u]], 0.025):
                        if group[v] < 0 and which[ids[v]] == which[ids[j]]:
                            group[v] = len(patches)
                            stack.append(v)
                patches.append(np.array(members))
        patches = sorted((m_ for m_ in patches if f_a[m_].sum() > 0), key=lambda m_: -f_a[m_].sum())
        patches = [m_ for m_ in patches if f_a[m_].sum() >= 0.03 * f_a[patches[0]].sum()]
        wanted = []                                                              # (place, facing, radius, colour), a patch at a time
        for members in patches:
            middle = np.average(f_c[members], axis=0, weights=f_a[members])
            spread_ = np.cov((f_c[members] - middle).T, aweights=f_a[members]) if len(members) > 3 else np.eye(3) * 1e-6
            size, axes = np.linalg.eigh(spread_)
            radius = float(np.sqrt(2 * max(size[1] + size[2], 1e-9)))
            out_ = middle - skin_from
            out_ /= max(float(np.linalg.norm(out_)), 1e-9)
            facing = axes[:, 0] if axes[:, 0] @ out_ > 0 else -axes[:, 0]
            if radius <= 1.3 * widest:
                wanted.append([(middle, facing, min(radius, widest), int(which[members[0]]))] if radius >= 0.008 and shows(middle) else [])
            else:
                wanted.append([(f_c[i], frame(i)[1], widest * float(rng_l.uniform(0.7, 1.0)), int(which[i])) for i in spaced(by_chance(members), 1.5 * widest, most)])
        while flowers < most and any(wanted):
            for patch in wanted:                                                 # a flower from each patch in turn, the largest patch first
                if patch and flowers < most:
                    at, facing, radius, colour = patch.pop(0)
                    out_ = at - skin_from
                    out_ /= max(float(np.linalg.norm(out_)), 1e-9)
                    n_ = 0.6 * facing + 0.4 * out_                               # a flower shows its face to who stands outside
                    n_ /= np.linalg.norm(n_)
                    u_ = np.cross(n_, [0.0, 0.0, 1.0] if abs(n_[2]) < 0.9 else [1.0, 0.0, 0.0])
                    u_ /= np.linalg.norm(u_)
                    v_ = np.cross(n_, u_)
                    r_ = 1.15 * max(radius, 0.012)
                    at = at + 0.015 * n_
                    turn = float(rng_l.uniform(0, 2 * math.pi))
                    if r_ >= 0.045:                                              # five petals: a star of ten triangles
                        rim = [at + (r_ if i % 2 == 0 else 0.62 * r_) * (math.cos(turn + i * math.pi / 5) * u_ + math.sin(turn + i * math.pi / 5) * v_)
                               + (0.18 * r_ if i % 2 == 0 else 0.0) * n_ for i in range(10)]
                        add([at] + rim, [(0, 1 + i, 1 + (i + 1) % 10) for i in range(10)], 2, colour)
                    else:                                                        # a small blossom: five triangles
                        rim = [at - 0.2 * r_ * n_ + r_ * (math.cos(turn + i * 2 * math.pi / 5) * u_ + math.sin(turn + i * 2 * math.pi / 5) * v_) for i in range(5)]
                        add([at] + rim, [(0, 1 + i, 1 + (i + 1) % 5) for i in range(5)], 2, colour)
                    if "--flower-centre" in argv:
                        eye = [at + 0.07 * r_ * n_ + 0.3 * r_ * (math.cos(turn + i * 2 * math.pi / 5) * u_ + math.sin(turn + i * 2 * math.pi / 5) * v_) for i in range(5)]
                        add(eye, [(0, 1, 2), (0, 2, 3), (0, 3, 4)], 3)
                    flowers += 1
    # 4. Leaves: the model's leaf faces taken in a chance order (by their area), each kept if it shows outside
    #    the inside and stands at least `space` from every leaf kept before it. A leaf is one colour, the one
    #    the generator painted that face (its second half a little darker, as a folded blade takes the light).
    kept_leaves = spaced(by_chance(np.nonzero(leafy & ~flower_face & (f_a > 0))[0]), space, n_leaves, bring="--leaves-under" in argv)
    foot = np.array([0.0, 0.0, floor])
    for i in kept_leaves:
        at, n_, _out = frame(i)
        along = at - foot
        t_ = along - (along @ n_) * n_
        if np.linalg.norm(t_) < 0.2 * np.linalg.norm(along):
            t_ = np.array([0.0, 0.0, 1.0]) - n_[2] * n_
        if np.linalg.norm(t_) < 1e-6:
            t_ = np.cross(n_, [1.0, 0.0, 0.0])
        t_ /= np.linalg.norm(t_)
        twist = float(rng_l.uniform(-0.6, 0.6))
        t_ = t_ * math.cos(twist) + np.cross(n_, t_) * math.sin(twist)
        s_ = np.cross(n_, t_)
        long_, wide_ = leaf_len * float(rng_l.uniform(0.8, 1.25)), leaf_wid * float(rng_l.uniform(0.8, 1.25))
        stem, tip, belly = at - 0.45 * long_ * t_, at + 0.55 * long_ * t_, at + 0.05 * long_ * t_ + 0.14 * wide_ * n_
        add([stem, tip, belly + 0.5 * wide_ * s_], [(0, 1, 2)], 1, paint=tuple(painted[i]))
        add([stem, belly - 0.5 * wide_ * s_, tip], [(0, 1, 2)], 1, paint=tuple(0.9 * painted[i]))
    # 5. Leaves round the ring. The inside's ring is the one place where it stands as far out as the leaves do,
    #    and it would show there as a bare rim: more leaves lie across it against the circle, side by side all
    #    the way round (36 to 72 of them, by their width), their tips up and down turn about.
    round_ring = int(np.clip(round(2 * math.pi * want_reach / (1.1 * leaf_wid)), 36, 72))
    for k in range(round_ring):
        turn = (k + float(rng_l.uniform(-0.3, 0.3))) * 2 * math.pi / round_ring
        n_ = np.array([math.cos(turn), math.sin(turn), 0.0])
        up_ = -1.0 if k % 2 == 0 else 1.0
        long_, wide_ = leaf_len * float(rng_l.uniform(0.8, 1.25)), leaf_wid * float(rng_l.uniform(0.8, 1.25))
        twist = float(rng_l.uniform(-0.5, 0.5))
        t_ = np.array([0.0, 0.0, up_]) * math.cos(twist) + np.cross(n_, [0.0, 0.0, up_]) * math.sin(twist)
        s_ = np.cross(n_, t_)
        at = 0.99 * want_reach * n_ + np.array([0.0, 0.0, ring_z + long_ * float(rng_l.uniform(-0.15, 0.15))])
        stem, tip, belly = at - 0.45 * long_ * t_, at + 0.55 * long_ * t_, at + 0.05 * long_ * t_
        if kept_leaves:                                                      # in the colour of one of the leaves kept, taken by chance
            colour = painted[kept_leaves[int(rng_l.integers(len(kept_leaves)))]]
            add([stem, tip, belly + 0.5 * wide_ * s_], [(0, 1, 2)], 1, paint=tuple(colour))
            add([stem, belly - 0.5 * wide_ * s_, tip], [(0, 1, 2)], 1, paint=tuple(0.9 * colour))
        else:
            add([stem, tip, belly + 0.5 * wide_ * s_, belly - 0.5 * wide_ * s_], [(0, 1, 2), (0, 3, 1)], 1)
    # 6. Leaves on the ring's shoulder. Inside its ring the inside's top is a shoulder a hand or two wide; where
    #    the model has no leaf over it (a side of the shrub the generator left thin) it would show as a bare
    #    ledge. In every such direction a leaf is laid on it, pointing out, in the colour of one of the leaves
    #    kept (taken by chance).
    on_shoulder = 0
    if kept_leaves:
        near_ring = [frame(i)[0] for i in kept_leaves if 0 <= frame(i)[0][2] - ring_z < 0.15 and np.hypot(frame(i)[0][0], frame(i)[0][1]) > 0.6 * want_reach]
        covered_turns = np.array([math.atan2(q[1], q[0]) for q in near_ring]) if near_ring else np.zeros(0)
        for k in range(round_ring):
            turn = (k + 0.5 + float(rng_l.uniform(-0.25, 0.25))) * 2 * math.pi / round_ring
            if len(covered_turns) and np.min(np.abs((covered_turns - turn + math.pi) % (2 * math.pi) - math.pi)) < 1.2 * math.pi / round_ring:
                continue
            out_ = np.array([math.cos(turn), math.sin(turn), 0.0])
            n_ = 0.35 * out_ + np.array([0.0, 0.0, 0.94])
            n_ /= np.linalg.norm(n_)
            t_ = out_ - (out_ @ n_) * n_
            t_ /= np.linalg.norm(t_)
            twist = float(rng_l.uniform(-0.5, 0.5))
            t_ = t_ * math.cos(twist) + np.cross(n_, t_) * math.sin(twist)
            s_ = np.cross(n_, t_)
            long_, wide_ = leaf_len * float(rng_l.uniform(0.9, 1.3)), leaf_wid * float(rng_l.uniform(0.9, 1.3))
            at = float(rng_l.uniform(0.72, 0.9)) * want_reach * out_ + np.array([0.0, 0.0, ring_z + 0.04 + float(rng_l.uniform(0.0, 0.05))])
            stem, tip, belly = at - 0.45 * long_ * t_, at + 0.55 * long_ * t_, at + 0.05 * long_ * t_ + 0.14 * wide_ * n_
            colour = painted[kept_leaves[int(rng_l.integers(len(kept_leaves)))]]
            add([stem, tip, belly + 0.5 * wide_ * s_], [(0, 1, 2)], 1, paint=tuple(colour))
            add([stem, belly - 0.5 * wide_ * s_, tip], [(0, 1, 2)], 1, paint=tuple(0.9 * colour))
            on_shoulder += 1
    mesh = bpy.data.meshes.new("leaves")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mark = mesh.attributes.new("part", "INT", "FACE")
    tint = mesh.attributes.new("flower_colour", "INT", "FACE")
    paint_ = mesh.attributes.new("painted", "FLOAT_VECTOR", "FACE")
    for i in range(len(faces)):
        mark.data[i].value = kinds[i]
        tint.data[i].value = tints[i]
        paint_.data[i].vector = paints[i]
    leaves_obj = bpy.data.objects.new("leaves", mesh)
    bpy.context.scene.collection.objects.link(leaves_obj)
    bpy.ops.object.select_all(action="DESELECT")
    leaves_obj.select_set(True)
    lo_obj.select_set(True)
    bpy.context.view_layer.objects.active = lo_obj
    bpy.ops.object.join()
    report["leaves"] = {"asked": n_leaves, "leaves": len(kept_leaves), "leaves_round_the_ring": round_ring, "leaves_on_the_ring_s_shoulder": on_shoulder,
                        "length_m": leaf_len, "width_m": leaf_wid,
                        "no_nearer_than_m": round(space, 3), "inside_triangles": report["tris"], "corners_held_inside_the_circle": held_in,
                        "leaves_brought_out_from_under_the_ring": len(brought),
                        "flowers": flowers, "flower_colours": flower_colours, "flower_faces_of_the_model": int(flower_face.sum())}
    report["tris"] = tri_count(lo_obj)
if opt("--bed"):
    # Nothing of the cut-down piece may stand outside the walls by more than the overhang allowed.
    co = np.empty(len(lo_obj.data.vertices) * 3)
    lo_obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    limit_lo, limit_hi = kit_box[0][:2] - overhang, kit_box[1][:2] + overhang
    held_in = int(((co[:, :2] < limit_lo) | (co[:, :2] > limit_hi)).any(axis=1).sum())
    co[:, :2] = np.clip(co[:, :2], limit_lo, limit_hi)
    co[:, 2] = np.maximum(co[:, 2], 0.0)
    lo_obj.data.vertices.foreach_set("co", co.ravel())
    lo_obj.data.update()
    report["bed"]["cut_down_vertices_held_in"] = held_in
if "--all-leaf" in argv:
    mark = lo_obj.data.attributes.new("is_leaf", "INT", "FACE")
    for item in mark.data:
        item.value = 1
if opt("--tree"):
    # Nothing the piece draws between 0.15 and 2.2 m up may lie outside the footprint (the game measures the
    # vertices in that band and the points where edges cross its two heights). Three things can: the bed
    # itself, swollen by the rebuild; a vertex left hanging in the band; and an edge that crosses 2.2 m on
    # its way from inside the footprint to a vertex outside it.
    line = 2.27
    half_w, half_d = bed_w / 2 - 0.002, bed_d / 2 - 0.002
    moved = pulled = 0
    for v in lo_obj.data.vertices:
        outside = abs(v.co.x) > half_w or abs(v.co.y) > half_d
        if outside and v.co.z <= bed_h + 0.3:
            v.co.x = min(max(v.co.x, -half_w), half_w)
            v.co.y = min(max(v.co.y, -half_d), half_d)
            pulled += 1
        elif outside and v.co.z < line:
            v.co.z = line
            moved += 1
    for _ in range(4):
        again = 0
        for e in lo_obj.data.edges:
            a, b = (lo_obj.data.vertices[i] for i in e.vertices)
            if a.co.z > b.co.z:
                a, b = b, a
            if a.co.z < 2.2 < b.co.z:
                f = (2.2 - a.co.z) / (b.co.z - a.co.z)
                x, y = a.co.x + (b.co.x - a.co.x) * f, a.co.y + (b.co.y - a.co.y) * f
                if abs(x) > half_w or abs(y) > half_d:
                    b.co.x = min(max(b.co.x, -half_w), half_w)
                    b.co.y = min(max(b.co.y, -half_d), half_d)
                    again += 1
        pulled += again
        if not again:
            break
    lo_obj.data.update()
    report["lifted_to_clear_band"] = moved
    report["pulled_into_footprint"] = pulled
if report.get("stem"):
    # A swell before a rebuild (--inflate) pushes the foot's underside below the ground: it is put back on it.
    sunk = [v for v in lo_obj.data.vertices if v.co.z < 0.0]
    for v in sunk:
        v.co.z = 0.0
    if sunk:
        lo_obj.data.update()
        report["stem"]["vertices_put_back_on_the_ground"] = len(sunk)
if opt("--planter") and "is_leaf" in lo_obj.data.attributes:
    # The plants once more inside the box's outline: the swell and the rebuild move their surface out by a
    # centimetre or so, and one vertex past the outline in the band is fitted to the footprint in the box's place.
    half_w, half_d = box_w / 2 - 0.002, box_d / 2 - 0.002
    leafy = [item.value == 1 for item in lo_obj.data.attributes["is_leaf"].data]
    leaf_verts = sorted({vi for poly in lo_obj.data.polygons if leafy[poly.index] for vi in poly.vertices})
    pulled = 0
    for vi in leaf_verts:
        v = lo_obj.data.vertices[vi]
        if abs(v.co.x) > half_w or abs(v.co.y) > half_d:
            v.co.x = min(max(v.co.x, -half_w), half_w)
            v.co.y = min(max(v.co.y, -half_d), half_d)
            pulled += 1
    lo_obj.data.update()
    report["planter"]["plant_vertices_put_on_the_outline"] = pulled

# Smooth faces, with the edges the shape really has kept sharp. Set before baking: the relief is baked
# against these normals.
only(lo_obj)
for p in lo_obj.data.polygons:
    p.use_smooth = "--flat" not in argv
if ("--own-normals" in argv or "--weighted-normals" in argv) and "custom_normal" in lo_obj.data.attributes:
    # The generated model's normals came through the reduction with the mesh. They are stored relative to the
    # faces round each corner, and those faces are gone: they point anywhere now, and while they are there
    # the sharp edges below are not found.
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    report["own_normals"] = True
if "--flat" not in argv:
    lo_obj.data.set_sharp_from_angle(angle=math.radians(40))
    if "--leaf-smooth" in argv and "is_leaf" in lo_obj.data.attributes:
        # A style that inks every crease (the anime pack's line pass draws one wherever the surface turns by
        # about 49 degrees) turns a crown of facets into a scribble. The leaf masses are shaded as rounded
        # forms instead: no edge between two leaf faces is sharp.
        leafy = [item.value == 1 for item in lo_obj.data.attributes["is_leaf"].data]
        bms = bmesh.new()
        bms.from_mesh(lo_obj.data)
        bms.edges.ensure_lookup_table()
        soft = [e.index for e in bms.edges if e.link_faces and all(leafy[f.index] for f in e.link_faces)]
        bms.free()
        sharp = lo_obj.data.attributes.get("sharp_edge")
        if sharp is not None:
            for i in soft:
                sharp.data[i].value = False
        report["leaf_edges_smoothed"] = len(soft)
    if opt("--top-sharp") and report.get("stem"):
        # A canopy's gores are flat panels that meet at about 20 degrees: under the 40-degree rule every ridge
        # is smoothed over, and the cut-down canopy's uneven triangles then shade as blotches. In the top (what
        # stands above the stem) edges sharper than this are kept sharp.
        top_from = report["stem"]["foot_m"] + report["stem"]["stem_m"] - 0.002
        bms = bmesh.new()
        bms.from_mesh(lo_obj.data)
        bms.edges.ensure_lookup_table()
        limit = math.radians(float(opt("--top-sharp")))
        crisp = [e.index for e in bms.edges if len(e.link_faces) == 2 and all(f.calc_center_median().z >= top_from for f in e.link_faces)
                 and e.calc_face_angle(0.0) > limit]
        bms.free()
        sharp = lo_obj.data.attributes.get("sharp_edge") or lo_obj.data.attributes.new("sharp_edge", "BOOLEAN", "EDGE")
        for i in crisp:
            sharp.data[i].value = True
        report["top_edges_kept_sharp"] = len(crisp)

def weighted_normals(o):
    """A flat face beside a smooth bevel: the corner's one normal is the average of both, and the flat face
    shades as if it were dished. Weighted by area, the large face decides its corners' normals (sharp edges
    stay sharp). The normals are kept with the mesh as Blender keeps them, relative to the faces round each
    corner, so they are written again after anything that changes which faces those are (a part split off,
    faces added): until then they point wrong."""
    only(o)
    if "custom_normal" in o.data.attributes:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    wn = o.modifiers.new("weighted", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    wn.mode = "FACE_AREA"
    wn.weight = 100
    bpy.ops.object.modifier_apply(modifier=wn.name)


if "--weighted-normals" in argv and "--flat" not in argv:
    weighted_normals(lo_obj)          # before the bakes: the relief is baked against these normals
    report["weighted_normals"] = True

# ---- Its own UVs, and the bakes ----
for uv in list(lo_obj.data.uv_layers):
    lo_obj.data.uv_layers.remove(uv)
lo_obj.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
if opt("--uv", "smart" if ("rebuilt_surface_m" in report or "skin" in report) else "seams") == "seams":
    # Seams along the edges that are sharp anyway, so a join in the texture falls where the shape turns.
    bpy.ops.mesh.select_mode(type="EDGE")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.mesh.edges_select_sharp(sharpness=math.radians(40))
    bpy.ops.mesh.mark_seam(clear=False)
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.004)
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
else:
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(float(opt("--uv-angle", "66"))), island_margin=0.0)
    bpy.ops.uv.pack_islands(margin=0.0015, rotate=True)
bpy.ops.object.mode_set(mode="OBJECT")

def uv_mask(face_indices):
    """The texels the faces `face_indices` of the piece cover in its texture."""
    mask = np.zeros((tex, tex), dtype=bool)
    uv_data = lo_obj.data.uv_layers.active.data
    for fi in face_indices:
        loops = list(lo_obj.data.polygons[fi].loop_indices)
        for kk in range(1, len(loops) - 1):
            tri = np.array([[uv_data[i].uv[0] * tex, uv_data[i].uv[1] * tex] for i in (loops[0], loops[kk], loops[kk + 1])])
            xs, ys = tri[:, 0], tri[:, 1]
            x0, x1 = max(int(np.floor(xs.min())), 0), min(int(np.ceil(xs.max())), tex - 1)
            y0, y1 = max(int(np.floor(ys.min())), 0), min(int(np.ceil(ys.max())), tex - 1)
            det = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if x1 < x0 or y1 < y0 or abs(det) < 1e-12:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            a = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / det
            b = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / det
            mask[y0:y1 + 1, x0:x1 + 1] |= (a >= -0.05) & (b >= -0.05) & (1 - a - b >= -0.05)
    return mask.ravel()


mat = bpy.data.materials.new("sheet_albedo")
mat.use_nodes = True
nodes, links = mat.node_tree.nodes, mat.node_tree.links
bsdf = nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = rough
bsdf.inputs["Metallic"].default_value = 0.0
lo_obj.data.materials.clear()
lo_obj.data.materials.append(mat)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 4


def bake(kind, image_name, colourspace, far=None):
    image = bpy.data.images.new(image_name, tex, tex, alpha=True)
    image.generated_color = (0, 0, 0, 0)
    image.colorspace_settings.name = colourspace
    node = nodes.new("ShaderNodeTexImage")
    node.image = image
    nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    lo_obj.select_set(True)
    bpy.context.view_layer.objects.active = lo_obj
    if kind == "DIFFUSE":
        bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, cage_extrusion=reach,
                            max_ray_distance=far or (3 * reach + bake_further), margin=12, use_clear=True)
    else:
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_selected_to_active=True, cage_extrusion=reach,
                            max_ray_distance=3 * reach + bake_further, margin=12, use_clear=True)
    return image, node


if skin_from is not None:
    # A skin takes its colours as it was drawn: looking in from outside. The bakes cast their rays along the
    # piece's normals, and a skin's own normals follow its lumps, which smears the leaves where it bridges a
    # gap; for the bakes its normals point straight out from the axis point instead (level under the ring,
    # where a walker sees the piece from the side). Without a relief map they are taken off again afterwards.
    co = np.array([v.co[:] for v in lo_obj.data.vertices])
    away = co - skin_from
    away[co[:, 2] < skin_from[2] - 1e-6, 2] = 0.0
    away /= np.maximum(np.linalg.norm(away, axis=1), 1e-9)[:, None]
    for poly in lo_obj.data.polygons:
        poly.use_smooth = True
    lo_obj.data.normals_split_custom_set_from_vertices([tuple(float(c) for c in v) for v in away])


def nearest_colours():
    """The piece's colour texture, each texel taking the colour of the point of the generated model nearest to
    where the texel lies on the piece (--skin-colour nearest). A skin bridges the gaps between a loose shrub's
    branches; a ray cast in from such a place passes between the leaves and brings back the dark inside of the
    model, and the texture comes out as blotches. The nearest leaf is what the eye expects there."""
    src = hi.data
    src.calc_loop_triangles()
    n_t = len(src.loop_triangles)
    t_verts, t_loops = np.empty(n_t * 3, dtype=np.int32), np.empty(n_t * 3, dtype=np.int32)
    src.loop_triangles.foreach_get("vertices", t_verts)
    src.loop_triangles.foreach_get("loops", t_loops)
    t_verts, t_loops = t_verts.reshape(-1, 3), t_loops.reshape(-1, 3)
    s_co = world_verts([hi])
    s_uv = np.empty(len(src.loops) * 2, dtype=np.float32)
    src.uv_layers.active.data.foreach_get("uv", s_uv)
    s_uv = s_uv.reshape(-1, 2)
    image = None
    for m in src.materials:
        for node in (m.node_tree.nodes if m and m.use_nodes else []):
            if node.type == "BSDF_PRINCIPLED" and node.inputs["Base Color"].is_linked:
                source = node.inputs["Base Color"].links[0].from_node
                if source.type == "TEX_IMAGE" and source.image is not None:
                    image = source.image
    iw, ih = image.size
    pix = np.empty(iw * ih * 4, dtype=np.float32)
    image.pixels.foreach_get(pix)
    pix = pix.reshape(ih, iw, 4)
    tree = BVHTree.FromPolygons([tuple(v) for v in s_co], [tuple(int(i) for i in t) for t in t_verts])
    me = lo_obj.data
    uv = np.empty(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2).astype(np.float64) * tex
    corner = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", corner)
    co = np.array([v.co[:] for v in me.vertices])
    where, which = [], []
    for poly in me.polygons:
        loops = list(poly.loop_indices)
        for k in range(1, len(loops) - 1):
            ids = [loops[0], loops[k], loops[k + 1]]
            xs, ys = uv[ids, 0], uv[ids, 1]
            x0, x1 = max(int(np.floor(xs.min())) - 1, 0), min(int(np.ceil(xs.max())) + 1, tex - 1)
            y0, y1 = max(int(np.floor(ys.min())) - 1, 0), min(int(np.ceil(ys.max())) + 1, tex - 1)
            det = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if x1 < x0 or y1 < y0 or abs(det) < 1e-12:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            a = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / det
            b = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / det
            inside = (a >= -0.03) & (b >= -0.03) & (1 - a - b >= -0.03)
            a, b = a[inside], b[inside]
            where.append(a[:, None] * co[corner[ids[0]]] + b[:, None] * co[corner[ids[1]]] + (1 - a - b)[:, None] * co[corner[ids[2]]])
            which.append(gy[inside].astype(np.int64) * tex + gx[inside].astype(np.int64))
    where, which = np.concatenate(where), np.concatenate(which)
    # Where the model lies close behind the skin (within --skin-look, default 0.06 m, looking straight in towards
    # the axis point, level under the ring) the texel takes what is seen there: the leaves, and the darker ones
    # in the small gaps between them. Only where nothing is that close does it take the nearest point.
    look = float(opt("--skin-look", "0.06"))
    inward = where - skin_from
    inward[where[:, 2] < skin_from[2] - 1e-6, 2] = 0.0
    inward /= np.maximum(np.linalg.norm(inward, axis=1), 1e-9)[:, None]
    hit_tri, hit_at = np.zeros(len(where), dtype=np.int64), np.zeros_like(where)
    seen = 0
    for i, q in enumerate(where):
        found = tree.ray_cast(Vector(q + inward[i] * 0.02), Vector(-inward[i]), look + 0.02) if look > 0 else (None, None, None, None)
        if found[0] is None:
            found = tree.find_nearest(Vector(q))
        else:
            seen += 1
        hit_tri[i], hit_at[i] = found[2], found[0]
    a_, b_, c_ = s_co[t_verts[hit_tri, 0]], s_co[t_verts[hit_tri, 1]], s_co[t_verts[hit_tri, 2]]
    v0, v1, v2 = b_ - a_, c_ - a_, hit_at - a_
    d00, d01, d11, d20, d21 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1), (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = d00 * d11 - d01 * d01
    ok = np.abs(den) > 1e-18
    w1 = np.where(ok, (d11 * d20 - d01 * d21) / np.where(ok, den, 1.0), 0.0)
    w2 = np.where(ok, (d00 * d21 - d01 * d20) / np.where(ok, den, 1.0), 0.0)
    at = (1 - w1 - w2)[:, None] * s_uv[t_loops[hit_tri, 0]] + w1[:, None] * s_uv[t_loops[hit_tri, 1]] + w2[:, None] * s_uv[t_loops[hit_tri, 2]]
    colours = pix[np.clip((at[:, 1] * ih).astype(int), 0, ih - 1), np.clip((at[:, 0] * iw).astype(int), 0, iw - 1), :3]
    texels = np.zeros((tex * tex, 4), dtype=np.float32)
    texels[which, :3] = colours
    texels[which, 3] = 1.0
    made_ = bpy.data.images.new("albedo", tex, tex, alpha=True)
    made_.colorspace_settings.name = "sRGB"
    made_.pixels.foreach_set(texels.ravel())
    node = nodes.new("ShaderNodeTexImage")
    node.image = made_
    report["skin"]["colour"] = {"texels": int(len(where)), "seen_close_behind_the_skin": round(seen / max(len(where), 1), 3), "look_m": look}
    return made_, node


if skin_from is not None and opt("--skin-colour", "rays") == "nearest":
    albedo, albedo_node = nearest_colours()
else:
    albedo, albedo_node = bake("DIFFUSE", "albedo", "sRGB")
links.new(albedo_node.outputs["Color"], bsdf.inputs["Base Color"])
if opt("--bake-wood-reach") and "is_leaf" in lo_obj.data.attributes:
    # A tree's leaves stand far off their coarse rebuild and need a long reach; its wood does not, and with a
    # long reach a limb inside the crown reads the leaves round it. The wood's texels are baked again from
    # close in and put in the place of the first bake's.
    leaf_reach, reach = reach, float(opt("--bake-wood-reach"))
    close, close_node = bake("DIFFUSE", "albedo_wood", "sRGB")
    reach = leaf_reach
    near = np.empty(tex * tex * 4, dtype=np.float32)
    close.pixels.foreach_get(near)
    near = near.reshape(-1, 4)
    far_px = np.empty(tex * tex * 4, dtype=np.float32)
    albedo.pixels.foreach_get(far_px)
    far_px = far_px.reshape(-1, 4)
    marks = [item.value for item in lo_obj.data.attributes["is_leaf"].data]
    wood_tx = uv_mask([poly.index for poly in lo_obj.data.polygons if marks[poly.index] != 1]) & (near[:, 3] > 0.5)
    far_px[wood_tx] = near[wood_tx]
    albedo.pixels.foreach_set(far_px.ravel())
    nodes.remove(close_node)
    bpy.data.images.remove(close)
    nodes.active = albedo_node
    report["wood_baked_from_m"] = round(float(opt("--bake-wood-reach")), 3)

# ---- Match the colours to the design image, material by material ----
# The generator's colours come out darker and stronger than the image it was given. The design's pixels are
# gathered into a few colours (its materials); each texel goes to the nearest of them; and one rising curve of
# lightness and one scale of colourfulness are fitted through the pairs, so the fit does not depend on how much
# of each material the texture holds (it holds the undersides and backs the image never showed).
def to_lab(rgb):
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    xyz = lin @ np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]]).T / np.array([0.9505, 1.0, 1.089])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], axis=1)


def from_lab(lab_):
    fy = (lab_[:, 0] + 16) / 116
    f = np.stack([fy + lab_[:, 1] / 500, fy, fy - lab_[:, 2] / 200], axis=1)
    xyz = np.where(f ** 3 > 0.008856, f ** 3, (f - 16 / 116) / 7.787) * np.array([0.9505, 1.0, 1.089])
    lin = xyz @ np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]]).T
    lin = np.clip(lin, 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * lin ** (1 / 2.4) - 0.055)


def kmeans(x, k, rounds=25):
    rng_ = np.random.default_rng(3)
    centres = x[rng_.choice(len(x), k, replace=False)]
    for _ in range(rounds):
        idx = np.argmin(((x[:, None, :] - centres[None]) ** 2).sum(axis=2), axis=1)
        for j in range(k):
            if (idx == j).any():
                centres[j] = x[idx == j].mean(axis=0)
    return centres, idx


px = np.empty(tex * tex * 4, dtype=np.float32)
albedo.pixels.foreach_get(px)
px = px.reshape(-1, 4).astype(np.float64)
if opt("--under-reach"):
    # A soffit of slats, made one level face: the bake finds the slats' undersides, and in the gaps between them
    # nothing within its reach, so the gaps come out the slats' colour. The faces that look down above a height
    # are baked a second time with rays that go on further, to what lies behind the gaps.
    under_z, under_far = (float(v) for v in opt("--under-reach").split(","))
    under_faces = [poly.index for poly in lo_obj.data.polygons if poly.center.z > under_z and poly.normal.z < -0.7]
    if under_faces:
        deep, deep_node = bake("DIFFUSE", "albedo_under", "sRGB", far=under_far)
        dp = np.empty(tex * tex * 4, dtype=np.float32)
        deep.pixels.foreach_get(dp)
        dp = dp.reshape(-1, 4).astype(np.float64)
        take = uv_mask(under_faces) & (dp[:, 3] > 0.5)
        px[take] = dp[take]
        nodes.remove(deep_node)
        bpy.data.images.remove(deep)
        nodes.active = albedo_node
    report["under_reach"] = {"above_m": under_z, "reach_m": under_far, "faces": len(under_faces)}
covered = px[:, 3] > 0.5
if "--save-bake" in argv:
    albedo.filepath_raw = str(out.with_suffix(".baked.png"))
    albedo.file_format = "PNG"
    albedo.save()
if core_vertices is not None:
    # A loose shrub's leaves are each one colour, the one the generator painted the leaf it stands for (what
    # the bake finds at a blade's place is also the flower beside it and the leaf behind it).
    me = lo_obj.data
    uv_l = np.empty(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv_l)
    uv_l = uv_l.reshape(-1, 2).astype(np.float64) * tex
    img_l = px.reshape(tex, tex, 4)
    leaf_texels = np.zeros((tex, tex), dtype=bool)
    own = me.attributes["painted"].data
    for poly in me.polygons:
        colour = own[poly.index].vector
        if colour[0] < 0 or me.attributes["part"].data[poly.index].value != 1:
            continue
        loops = list(poly.loop_indices)
        xs, ys = uv_l[loops, 0], uv_l[loops, 1]
        x0, x1 = max(int(np.floor(xs.min())) - 2, 0), min(int(np.ceil(xs.max())) + 2, tex - 1)
        y0, y1 = max(int(np.floor(ys.min())) - 2, 0), min(int(np.ceil(ys.max())) + 2, tex - 1)
        det = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if x1 < x0 or y1 < y0 or abs(det) < 1e-12:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / det
        b = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / det
        reach_px = 1.5 / max(math.sqrt(abs(det)), 1e-6)
        img_l[y0: y1 + 1, x0: x1 + 1][(a >= -reach_px) & (b >= -reach_px) & (1 - a - b >= -reach_px)] = (colour[0], colour[1], colour[2], 1.0)
        leaf_texels[y0: y1 + 1, x0: x1 + 1] |= (a >= 0) & (b >= 0) & (1 - a - b >= 0)
    covered = px[:, 3] > 0.5
# Texels no ray reached take their neighbours' colour (a face the bake missed would show black).
img4 = px.reshape(tex, tex, 4)
have = img4[..., 3] > 0.5
for _ in range(40):
    if have.all():
        break
    total, count = np.zeros((tex, tex, 3)), np.zeros((tex, tex))
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        total += np.roll(np.roll(img4[..., :3] * have[..., None], dy, axis=0), dx, axis=1)
        count += np.roll(np.roll(have, dy, axis=0), dx, axis=1)
    fill = (~have) & (count > 0)
    img4[..., :3][fill] = total[fill] / count[fill][:, None]
    have = have | fill
px = img4.reshape(-1, 4)
if "--leaf-despeckle" in argv and "is_leaf" in lo_obj.data.attributes:
    # The generator's leaf clumps are open shells with dark faces inside; where the bake's ray goes in through
    # an opening it reads one, and the crown is peppered with black specks. A leaf texel much darker than the
    # leaf round it (the mean over 17 by 17 texels of leaf) takes the mean colour of the leaf texels there
    # that are not such specks.
    marks = [item.value for item in lo_obj.data.attributes["is_leaf"].data]
    leaf_tx = (uv_mask([poly.index for poly in lo_obj.data.polygons if marks[poly.index] == 1]) & covered).reshape(tex, tex)

    def box(a, r=8):
        """The sum of `a` over a square of 2r + 1 texels round each texel."""
        c = np.pad(a, ((r + 1, r), (r + 1, r))).cumsum(axis=0).cumsum(axis=1)
        return c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]
    rgb = px[:, :3].reshape(tex, tex, 3).astype(np.float64)
    lum = rgb @ LUM
    count = np.maximum(box(leaf_tx.astype(np.float64)), 1.0)
    around = box(lum * leaf_tx) / count
    speck = leaf_tx & (lum < 0.55 * around) & (around - lum > 0.04)
    good = leaf_tx & ~speck
    good_n = np.maximum(box(good.astype(np.float64)), 1.0)
    for ch in range(3):
        mean = box(rgb[..., ch] * good) / good_n
        rgb[..., ch] = np.where(speck, mean, rgb[..., ch])
    px[:, :3] = rgb.reshape(-1, 3)
    report["leaf_specks_filled"] = round(float(speck.sum() / max(leaf_tx.sum(), 1)), 4)
px0 = px[:, :3].copy()                                   # the generator's own colours
mx0, mn0 = px0.max(axis=1), px0.min(axis=1)
sat0 = (mx0 - mn0) / np.maximum(mx0, 1e-4)
hue0 = np.degrees(np.arctan2(np.sqrt(3) * (px0[:, 1] - px0[:, 2]), 2 * px0[:, 0] - px0[:, 1] - px0[:, 2])) % 360
# Lanterns and lamps as the generator paints them: a strong warm yellow, lighter than bark, yellower than leaf.
w_h0, w_h1, w_sat, w_val = (float(v) for v in opt("--warm", "28,62,0.42,0.62").split(","))
warm0 = covered & (hue0 > w_h0) & (hue0 < w_h1) & (sat0 > w_sat) & (mx0 > w_val)
if opt("--glow-pale"):
    # A generator can paint a lantern's glass pale and cold where the design lit it warm. Where nothing else on
    # the piece is pale (no blossoms), pale texels are lantern glass too.
    pale_v, pale_s = (float(v) for v in opt("--glow-pale").split(","))
    pale0 = covered & (mx0 > pale_v) & (sat0 < pale_s)
    warm0 = warm0 | pale0
report["texels_used"] = round(float(covered.mean()), 3)
measures, measured_px = [], None                        # set by the colour match, when one runs: (report tag, its measure) a group of texels
if "--no-match" in argv:
    # The generator's own colours, lifted. For a piece whose design image is mostly its own light on itself
    # (a tree strung with lamps), the image's colours are light, not surface, and cannot be matched.
    own = to_lab(px[:, :3])
    own[:, 0] = np.clip(own[:, 0] * float(opt("--lift", "1.0")), 0, 100)
    own[:, 1:] *= float(opt("--colourfulness", "1.0"))
    px[:, :3] = np.clip(from_lab(own), 0, 1)
    report["colour_match"] = "none"
elif design:
    d_img = bpy.data.images.load(design)
    d = np.empty(d_img.size[0] * d_img.size[1] * 4, dtype=np.float32)
    d_img.pixels.foreach_get(d)
    d = d.reshape(-1, 4).astype(np.float64)
    d = d[d[:, 3] > 0.9][:, :3]
    rng2 = np.random.default_rng(5)
    # One match of all the texture against all of the design; or, for a piece whose water is handled apart
    # (--fountain), two: what the generator painted as water against what the design paints as water, and
    # the rest against the rest. One scale of colourfulness cannot serve both: generated water is stronger
    # than the design's and generated timber duller, and matched together the timber comes out grey.
    groups = [(None, None, "")]
    if opt("--fountain"):
        wet_px, wet_d = painted_water(px0), painted_water(d)
        if min(int((covered & wet_px).sum()), int((covered & ~wet_px).sum()), int(wet_d.sum()), int((~wet_d).sum())) > 500:
            groups = [(~wet_px, ~wet_d, ""), (wet_px, wet_d, "water_")]
    d_whole, px_whole, matched = d, px, px.copy()
    for of_texels, of_design, tag in groups:
        d = d_whole if of_design is None else d_whole[of_design]
        px = px_whole if of_texels is None else px_whole.copy()
        chosen = covered if of_texels is None else covered & of_texels
        d_lab = to_lab(d[rng2.choice(len(d), min(30000, len(d)), replace=False)])
        s_rgb = px[chosen][:, :3]
        s_lab0 = to_lab(s_rgb[rng2.choice(len(s_rgb), min(30000, len(s_rgb)), replace=False)])
        k = int(opt("--materials", "5")) if of_texels is None or not tag else 3
        lo_s, hi_s = np.percentile(s_lab0[:, 0], [8, 92])
        lo_d, hi_d = np.percentile(d_lab[:, 0], [8, 92])
        covered_lab = to_lab(px[chosen][:, :3][rng2.choice(int(chosen.sum()), min(30000, int(chosen.sum())), replace=False)])

        def fitted(l_weight):
            """One fit with lightness weighing `l_weight` against hue when a texel looks for its material: the
            curve's knots, the colourfulness scale, and how the result stands against the design (each of the
            design's materials against the texels that came nearest it; a material no texel reached counts by its
            distance to the nearest texel colour)."""
            weight = np.array([l_weight, 1.0, 1.0])
            centres, d_idx = kmeans(d_lab * weight, k)
            ks, kd, scale = np.array([0.0, lo_s, hi_s, 100.0]), np.array([0.0, lo_d, hi_d, 100.0]), 1.0
            for _ in range(6):
                cur = s_lab0.copy()
                cur[:, 0] = np.interp(s_lab0[:, 0], ks, kd)
                cur[:, 1:] *= scale
                s_idx = np.argmin((((cur * weight)[:, None, :] - centres[None]) ** 2).sum(axis=2), axis=1)
                pairs = []
                for j in range(k):
                    ds, ss = d_lab[d_idx == j], s_lab0[s_idx == j]
                    if len(ds) < 0.01 * len(d_lab) or len(ss) < 0.005 * len(s_lab0):
                        continue
                    pairs.append((float(np.median(ss[:, 0])), float(np.median(ds[:, 0])), float(np.median(np.hypot(ss[:, 1], ss[:, 2]))),
                                  float(np.median(np.hypot(ds[:, 1], ds[:, 2]))), len(ds) / len(d_lab)))
                if not pairs:
                    break
                pairs.sort()
                # Two of the design's materials can fall on nearly one lightness of the texture (a generator paints
                # timber one flat brown where the design has a mid and a light orange). Knots that close would make
                # the curve a cliff, and the texture's grain would come out as blotches: they are one knot.
                knots = []
                for q in pairs:
                    if knots and q[0] - knots[-1][0] < 3.0:
                        a = knots[-1]
                        knots[-1] = ((a[0] * a[2] + q[0] * q[4]) / (a[2] + q[4]), (a[1] * a[2] + q[1] * q[4]) / (a[2] + q[4]), a[2] + q[4])
                    else:
                        knots.append((q[0], q[1], q[4]))
                ls = np.array([q[0] for q in knots])
                ld = np.maximum.accumulate(np.array([q[1] for q in knots]))          # a rising curve
                ks = np.concatenate([[0.0], ls + np.arange(len(ls)) * 1e-6, [100.0]])
                kd = np.concatenate([[0.0], ld, [100.0]])
                coloured = [(q[3] / q[2], q[4]) for q in pairs if q[2] > 6 and q[3] > 6]
                if coloured:
                    scale = float(np.clip(np.average([c[0] for c in coloured], weights=[c[1] for c in coloured]), 0.5, 1.6))
            after = covered_lab.copy()
            after[:, 0] = np.interp(covered_lab[:, 0], ks, kd)
            after[:, 1:] *= scale
            a_idx = np.argmin((((after * weight)[:, None, :] - centres[None]) ** 2).sum(axis=2), axis=1)
            materials, reached = [], 0.0
            for j in range(k):
                ds, as_ = d_lab[d_idx == j], after[a_idx == j]
                share = len(ds) / len(d_lab)
                if share < 0.01:
                    continue
                mid = np.median(ds, axis=0)
                if len(as_) >= 0.005 * len(after):
                    got, reached = np.median(as_, axis=0), reached + share
                else:
                    got = after[np.argmin(np.linalg.norm(after - mid, axis=1))]
                materials.append({"design": [round(float(v), 1) for v in mid], "got": [round(float(v), 1) for v in got], "share": round(share, 3),
                                  "reached": bool(len(as_) >= 0.005 * len(after)), "delta_e": round(float(np.linalg.norm(mid - got)), 1)})
            delta = float(np.average([m["delta_e"] for m in materials], weights=[m["share"] for m in materials]))
            mids = np.array([np.median(d_lab[d_idx == j], axis=0) if (d_idx == j).any() else centres[j] / weight for j in range(k)])
            return {"knots_s": ks, "knots_d": kd, "scale": scale, "materials": materials, "delta_e": delta, "reached": reached, "l_weight": l_weight,
                    "centres": centres, "mids": mids, "weight": weight}

        tries = [fitted(w) for w in (1.0, 0.7, 0.45)]
        best = min(tries, key=lambda t: (t["reached"] < 0.85, t["delta_e"]))
        knots_s, knots_d, chroma_scale = best["knots_s"], best["knots_d"], best["scale"]
        rank_colour = None
        if opt("--tones-by-rank"):
            # Foliage is one material in many tones, and the generator paints it in a narrow band of them: paired
            # material by material, a shrub's texture keeps that band and comes out one flat green beside its
            # design. The lightness curve is fitted by rank instead: the darkest of the texture takes the lightness
            # of the darkest of the design, and so on up, and each rank takes the design's colour at that rank
            # (three quarters of the way). The design is read over its upper part only (TOP of its height): that
            # is where the drawing's light falls, and the game lights and shades the piece itself.
            top_share = float(opt("--tones-by-rank"))
            d_rows = np.empty(d_img.size[0] * d_img.size[1] * 4, dtype=np.float32)
            d_img.pixels.foreach_get(d_rows)
            d_rows = d_rows.reshape(d_img.size[1], d_img.size[0], 4)              # row 0 is the image's bottom
            filled_rows = np.nonzero((d_rows[..., 3] > 0.9).any(axis=1))[0]
            first_row = filled_rows[-1] - int(top_share * (filled_rows[-1] - filled_rows[0]))
            lit = d_rows[first_row: filled_rows[-1] + 1]
            lit = lit[lit[..., 3] > 0.9][:, :3].astype(np.float64)
            lit_lab = to_lab(lit[rng2.choice(len(lit), min(30000, len(lit)), replace=False)])
            if flower_colours:
                # Where flowers are put back as flowers (--flowers), the design's flower pixels are left out of
                # the leaves' tones: counted in, the lightest leaves took a colour between leaf and flower.
                d_hue, d_chroma = np.degrees(np.arctan2(lit_lab[:, 2], lit_lab[:, 1])) % 360, np.hypot(lit_lab[:, 1], lit_lab[:, 2])
                leaf_pixel = np.ones(len(lit_lab), dtype=bool)
                for text in flower_colours:
                    want = to_lab(np.array([[int(text[i:i + 2], 16) / 255 for i in (1, 3, 5)]]))[0]
                    if math.hypot(want[1], want[2]) >= 18:
                        leaf_pixel &= ~((np.abs((d_hue - math.degrees(math.atan2(want[2], want[1])) + 180) % 360 - 180) <= 45) & (d_chroma >= 12))
                    else:
                        leaf_pixel &= ~((lit_lab[:, 0] >= want[0] - 12) & (d_chroma <= 16))
                if leaf_pixel.sum() > 0.5 * len(lit_lab):
                    lit_lab = lit_lab[leaf_pixel]
            lit_lab = lit_lab[np.argsort(lit_lab[:, 0])]
            ranks = np.linspace(3, 97, 12)
            if core_vertices is not None and leaf_texels.sum() > 100:
                # A loose shrub's leaves take the design's tones, darkest to lightest, among themselves: with its
                # inside counted too (which is dark, and darkened again below) every leaf came out a light one.
                s_lab0 = to_lab(px[leaf_texels.ravel()][:, :3])
            knots_s = np.concatenate([[0.0], np.percentile(s_lab0[:, 0], ranks) + np.arange(len(ranks)) * 1e-6, [100.0]])
            knots_d = np.concatenate([[0.0], np.maximum.accumulate(np.percentile(lit_lab[:, 0], ranks)), [100.0]])
            at_rank = [lit_lab[int(len(lit_lab) * max(r - 4, 0) / 100): max(int(len(lit_lab) * min(r + 4, 100) / 100), 1)] for r in ranks]
            rank_colour = (np.maximum.accumulate(np.percentile(lit_lab[:, 0], ranks)) + np.arange(len(ranks)) * 1e-6,
                           np.array([q[:, 1].mean() for q in at_rank]), np.array([q[:, 2].mean() for q in at_rank]))
            report["tones_by_rank"] = {"design_read_from_its_top": top_share,
                                       "lightness": [[round(float(u), 1), round(float(v), 1)] for u, v in zip(knots_s, knots_d)]}
        lab_all = to_lab(px[:, :3])
        lab_all[:, 0] = np.interp(lab_all[:, 0], knots_s, knots_d)
        lab_all[:, 1:] *= chroma_scale
        if rank_colour is not None:
            lab_all[:, 1] += (np.interp(lab_all[:, 0], rank_colour[0], rank_colour[1]) - lab_all[:, 1]) * 0.75
            lab_all[:, 2] += (np.interp(lab_all[:, 0], rank_colour[0], rank_colour[2]) - lab_all[:, 2]) * 0.75
        # Speckle: lifting a dark texture stretches its few levels apart. A 3 by 3 median takes the grain out, and
        # each texel is drawn part of the way to its material's own colour in the design (its hue more than its
        # lightness, so the painted shading stays).
        img = lab_all.reshape(tex, tex, 3)
        stack = np.stack([np.roll(np.roll(img, dy, axis=0), dx, axis=1) for dy in (-1, 0, 1) for dx in (-1, 0, 1)], axis=0)
        lab_all = np.median(stack, axis=0).reshape(-1, 3)
        lab_all[:, 0] = np.clip(lab_all[:, 0] * float(opt("--lift", "1.0")), 0, 100)
        flatten = float(opt("--flatten", "0.5"))
        if flatten > 0:
            nearest = np.empty(len(lab_all), dtype=np.int64)
            for a0 in range(0, len(lab_all), 200000):
                chunk = lab_all[a0:a0 + 200000] * best["weight"]
                nearest[a0:a0 + 200000] = np.argmin(((chunk[:, None, :] - best["centres"][None]) ** 2).sum(axis=2), axis=1)
            target = best["mids"][nearest]
            lab_all[:, 0] += (target[:, 0] - lab_all[:, 0]) * flatten * 0.4
            lab_all[:, 1:] += (target[:, 1:] - lab_all[:, 1:]) * float(opt("--flatten-hue", str(flatten)))
        before = px[chosen][:, :3].mean(axis=0)
        if of_texels is None:
            px[:, :3] = np.clip(from_lab(lab_all), 0, 1)
        else:
            matched[of_texels, :3] = np.clip(from_lab(lab_all), 0, 1)[of_texels]
            px, chosen = matched, covered & of_texels          # measured below on what this group came to
        # How the texture stands against the design (after the median, the lift and the flattening): each of the
        # design's materials against the texels nearest it, as `fitted` measures a try. It is measured here, as
        # matched, and once more when the texture is finished, if anything below changes its colours on purpose.
        picked = rng2.choice(int(chosen.sum()), min(30000, int(chosen.sum())), replace=False)
        d_near = np.argmin((((d_lab * best["weight"])[:, None, :] - best["centres"][None]) ** 2).sum(axis=2), axis=1)

        def against_design(texels, chosen=chosen, picked=picked, d_lab=d_lab, d_near=d_near, best=best, k=k):
            done = to_lab(texels[chosen][:, :3][picked])
            t_near = np.argmin((((done * best["weight"])[:, None, :] - best["centres"][None]) ** 2).sum(axis=2), axis=1)
            finished, reached = [], 0.0
            for j in range(k):
                ds, ts = d_lab[d_near == j], done[t_near == j]
                share = len(ds) / len(d_lab)
                if share < 0.01:
                    continue
                mid = np.median(ds, axis=0)
                if len(ts) >= 0.005 * len(done):
                    got, reached = np.median(ts, axis=0), reached + share
                else:
                    got = done[np.argmin(np.linalg.norm(done - mid, axis=1))]
                finished.append({"design": [round(float(v), 1) for v in mid], "got": [round(float(v), 1) for v in got], "share": round(share, 3),
                                 "reached": bool(len(ts) >= 0.005 * len(done)), "delta_e": round(float(np.linalg.norm(mid - got)), 1)})
            return finished, round(float(np.average([m["delta_e"] for m in finished], weights=[m["share"] for m in finished])), 1), round(reached, 3)

        report[tag + "materials"], report[tag + "colour_delta_e"], report[tag + "materials_reached"] = against_design(px)
        measures.append((tag, against_design))
        report[tag + "colour_delta_e_of_the_fit"] = round(best["delta_e"], 1)
        report[tag + "colour_tries"] = [{"l_weight": t["l_weight"], "delta_e": round(t["delta_e"], 1), "reached": round(t["reached"], 3)} for t in tries]
        report[tag + "lightness_curve"] = [[round(float(a), 1), round(float(b), 1)] for a, b in zip(knots_s, knots_d)]
        report[tag + "colourfulness_scale"] = round(chroma_scale, 3)
        report[tag + "colour_before"] = [round(float(v), 3) for v in before]
        report[tag + "colour_after"] = [round(float(v), 3) for v in px[chosen][:, :3].mean(axis=0)]
        report[tag + "colour_design"] = [round(float(v), 3) for v in d.mean(axis=0)]
    if groups[0][0] is not None:
        px = matched
    measured_px = px[:, :3].copy()

def hex_lab(text):
    return to_lab(np.array([[int(text[i:i + 2], 16) / 255 for i in (1, 3, 5)]]))[0]


if plan_notch is not None:
    # Setting the seat back between the arms draws the seat's sides out along the arms' inner faces: those faces
    # carry the seat's colour. They take the colour the arms' inner faces have above the seat (or, where an
    # arm has none, the arms' tops), and a third of their own variation.
    pn = plan_notch
    lo_d, hi_d = sorted((pn["seat_at"], pn["arms_at"]))
    walls, arm_in, arm_top = [], [], []
    for poly in lo_obj.data.polygons:
        off = poly.center[pn["a_axis"]] - pn["mid"]
        side = 1.0 if off > 0 else -1.0
        inner = pn["reach"][1 if off > 0 else 0]
        inward = -poly.normal[pn["a_axis"]] * side
        if abs(abs(off) - inner) < 0.014 and lo_d + 0.004 < poly.center[pn["d_axis"]] < hi_d + 0.004 and inward > 0.5 and poly.center.z > 0.05:
            walls.append(poly.index)
        elif abs(off) > inner + 0.008 and poly.center.z > pn["seat_h"] + 0.02:
            if inward > 0.5:
                arm_in.append(poly.index)
            elif poly.normal.z > 0.7:
                arm_top.append(poly.index)
    source = arm_in if len(arm_in) >= 4 else arm_top
    if walls and source:
        wall_px = uv_mask(walls) & covered
        src_px = uv_mask(source) & covered & ~wall_px
        if wall_px.sum() > 10 and src_px.sum() > 10:
            want = np.median(to_lab(px[src_px][:, :3]), axis=0)
            lab_w = to_lab(px[wall_px][:, :3])
            lab_w = want + (lab_w - lab_w.mean(axis=0)) * 0.33
            lab_w[:, 0] = np.clip(lab_w[:, 0], 0, 100)
            px[wall_px, :3] = np.clip(from_lab(lab_w), 0, 1)
            report["plan"]["notch"]["walls_recoloured"] = {"faces": len(walls), "from": "the arms' inner faces" if source is arm_in else "the arms' tops",
                                                           "share_of_texels": round(float(wall_px.sum() / max(covered.sum(), 1)), 4)}
def painted_at_faces(obj):
    """The colour the generator painted each face of the piece, read from the baked texture (before matching)
    at the middle of the face's place in it."""
    uv_data = obj.data.uv_layers.active.data
    base = px0.reshape(tex, tex, 3)
    out = np.zeros((len(obj.data.polygons), 3))
    for poly in obj.data.polygons:
        uv = np.mean([uv_data[i].uv for i in poly.loop_indices], axis=0)
        out[poly.index] = base[min(max(int(uv[1] * tex), 0), tex - 1), min(max(int(uv[0] * tex), 0), tex - 1)]
    return out


def glass_faces():
    """Which faces of the piece are glass (--glass): painted by the generator in the range of colour given, and,
    with `front` after the range, looking to the front or the back (a screen's panes: a lit sign of the same
    colour that faces along the piece is not glass)."""
    g_range = opt("--glass").split(",")[1:]
    h0, h1, s0, s1, v0, v1 = (float(v) for v in g_range[:6])
    hue, sat, val = hsv_of(painted_at_faces(lo_obj))
    glassy = (hue >= h0) & (hue <= h1) & (sat >= s0) & (sat <= s1) & (val >= v0) & (val <= v1)
    if len(g_range) > 6 and g_range[6] == "front":
        glassy &= np.array([abs(poly.normal.y) > 0.7 for poly in lo_obj.data.polygons])
    return glassy


if opt("--glow-pale") and opt("--glass"):
    # With the pale rule a pale pane would count as a lantern's glass, keep the generator's own colour and be
    # lit. Glass is neither: its texels are matched to the design like the rest and do not glow.
    warm0 = warm0 & ~uv_mask([int(i) for i in np.nonzero(glass_faces())[0]])
if opt("--bed-colour") and "is_bed" in lo_obj.data.attributes:
    # A generator can paint the bed's stone the colour of the bark, and the match then takes it for bark. The
    # box's walls are known, so they are given the design's own bed colour: the walls' mean takes it, their
    # variation stays, and what on the box's top is the walls' colour (the rim) goes with them.
    flags = [item.value for item in lo_obj.data.attributes["is_bed"].data]
    walls = [poly.index for poly in lo_obj.data.polygons if flags[poly.index] == 1 and abs(poly.normal.z) < 0.5]
    tops = [poly.index for poly in lo_obj.data.polygons if flags[poly.index] == 1 and poly.normal.z >= 0.5]
    if opt("--bed-colour") == "auto":
        # The design image's lowest sixteenth is the bed's two near walls (the view looks down on the piece
        # from its front corner). Their colour: the median of what is there that is neither plant nor ink line.
        bed_img = bpy.data.images.load(design)
        d_all = np.empty(bed_img.size[0] * bed_img.size[1] * 4, dtype=np.float32)
        bed_img.pixels.foreach_get(d_all)
        d_all = d_all.reshape(bed_img.size[1], bed_img.size[0], 4)                # row 0 is the image's bottom
        rows = np.nonzero((d_all[..., 3] > 0.9).any(axis=1))[0]
        low = d_all[rows[0]: rows[0] + max(4, int(0.0625 * (rows[-1] - rows[0] + 1)))]
        low = low[low[..., 3] > 0.9][:, :3].astype(np.float64)
        low_lab = to_lab(low)
        keep = (low_lab[:, 1] > -6) & (low_lab[:, 0] > 25) & (np.hypot(low_lab[:, 1], low_lab[:, 2]) < 30)
        want = np.median(low_lab[keep], axis=0) if keep.sum() > 50 else None
    else:
        want = hex_lab(opt("--bed-colour"))
    if walls and want is not None:
        wall_px = uv_mask(walls) & covered
        if opt("--bed"):
            # All of the walls' texels go, those the bake did not reach too (at the box's corners the generated
            # kerb is bevelled away from it, and those texels were filled from their neighbours before the
            # move), and the texels just outside the walls' own: the texture is read a little past a face's
            # edge. Without both, a kerb moved from cream to sandstone showed a cream line along every corner.
            wall_px = uv_mask(walls)
            grown = wall_px.reshape(tex, tex).copy()
            for _ in range(14):                                            # the bakes' own margin is twelve texels
                grown = grown | np.roll(grown, 1, 0) | np.roll(grown, -1, 0) | np.roll(grown, 1, 1) | np.roll(grown, -1, 1)
            wall_px = wall_px | (grown.ravel() & ~uv_mask([poly.index for poly in lo_obj.data.polygons if flags[poly.index] != 1 or abs(poly.normal.z) >= 0.5]))
        lab_w = to_lab(px[wall_px][:, :3])
        was = np.median(lab_w, axis=0)
        lab_w += want - was
        lab_w[:, 0] = np.clip(lab_w[:, 0], 0, 100)
        if opt("--kerb-tones"):
            # A kerb of one stone keeps its joints and the difference between one block and the next, but not
            # the light the generator painted along the kerb's edges: on a plain box it shows as a pale frame
            # round every wall. Nothing on a wall is more than UP lighter than the stone, or DOWN darker.
            tone_up, tone_down = (float(v) for v in opt("--kerb-tones").split(","))
            lab_w[:, 0] = np.clip(lab_w[:, 0], want[0] - tone_down, want[0] + tone_up)
        px[wall_px, :3] = np.clip(from_lab(lab_w), 0, 1)
        top_px = uv_mask(tops) & covered & ~wall_px
        lab_t = to_lab(px[top_px][:, :3])
        rim = np.linalg.norm(lab_t - was, axis=1) < 12
        lab_t[rim] += want - was
        lab_t[:, 0] = np.clip(lab_t[:, 0], 0, 100)
        idx = np.nonzero(top_px)[0]
        px[idx[rim], :3] = np.clip(from_lab(lab_t[rim]), 0, 1)
        rgb = np.clip(from_lab(want[None, :]), 0, 1)[0]
        report["bed_colour"] = {"asked": opt("--bed-colour"), "was": [round(float(v), 1) for v in was], "now": [round(float(v), 1) for v in want],
                                "hex": "#%02X%02X%02X" % tuple(int(round(float(v) * 255)) for v in rgb), "rim_share_of_top": round(float(rim.mean()), 3) if len(rim) else 0.0}
if opt("--planter-tones") and opt("--planter") and "is_bed" in lo_obj.data.attributes:
    # A plain planter box's stone (its walls and the rim on top) keeps this share of its own variation about
    # its middle colour. The match can part one stone into two of the design's colours (a voxel planter's
    # lighter blocks went to the white of its flowers), and the walls come out in patches.
    keep_tones = float(opt("--planter-tones"))
    flags = [item.value for item in lo_obj.data.attributes["is_bed"].data]
    stone = [poly.index for poly in lo_obj.data.polygons if flags[poly.index] == 1 and (abs(poly.normal.z) < 0.5 or (poly.normal.z >= 0.5 and abs(poly.center.z - rim_h) < 0.005))]
    stone_px = uv_mask(stone) & covered
    if stone_px.any():
        lab_s = to_lab(px[stone_px][:, :3])
        middle = np.median(lab_s, axis=0)
        px[stone_px, :3] = np.clip(from_lab(middle + (lab_s - middle) * keep_tones), 0, 1)
        report["planter"]["stone_tones_kept"] = {"share": keep_tones, "middle": [round(float(v), 1) for v in middle], "spread_was": round(float(np.percentile(lab_s[:, 0], 95) - np.percentile(lab_s[:, 0], 5)), 1)}
if opt("--leaf-colour"):
    # What the generator painted as leaf (green to olive) is moved, as a whole, to this colour: its mean takes
    # the colour's hue and lightness, and its own variation stays. For a tree whose design image shows the
    # leaves lit by its lamps: the game lights them itself, so they need their unlit colour.
    leafy0 = covered & ~warm0 & (px0[:, 1] > px0[:, 2] * 1.25) & (px0[:, 1] >= px0[:, 0] * 0.9)
    if leafy0.sum() > 100:
        # One colour, or two (the sheet's swatches for leaves in light and leaves in shade): then the leaves'
        # mean is put between them, a third of the way from the shaded one to the lit one (--leaf-blend). The
        # match alone leaves the crown at the average of the drawing's light and shadow, and the game then
        # shades it again; the lit swatch alone is the colour of the highlights, and turned a crown yellow.
        asked = [hex_lab(h) for h in opt("--leaf-colour").split(",")]
        blend = float(opt("--leaf-blend", "0.33"))
        want = asked[0] if len(asked) == 1 else blend * asked[0] + (1 - blend) * asked[1]
        lab_leaf = to_lab(px[leafy0][:, :3])
        mean = lab_leaf.mean(axis=0)
        lab_leaf[:, 0] *= want[0] / max(float(mean[0]), 1e-3)
        lab_leaf[:, 1:] += want[1:] - mean[1:]
        px[leafy0, :3] = np.clip(from_lab(lab_leaf), 0, 1)
        report["leaf_colour"] = {"asked": opt("--leaf-colour"), "share_of_texels": round(float(leafy0.sum() / max(covered.sum(), 1)), 3)}
def ramped(mask, hexes, start, blossoms=None, grow=0):
    """The texels `mask`, coloured from the swatches `hexes` (darkest to lightest) by how light the generator
    painted them; returns what share of them stayed as painted (pale, with little colour: blossoms), or with
    `blossoms` (the sheet's blossom swatches) the share that took one of those."""
    stops = sorted((hex_lab(h) for h in hexes), key=lambda q: q[0])
    src = to_lab(px0[mask])
    lo_l, hi_l = np.percentile(src[:, 0], [8, 92])
    t = start + (1 - start) * np.clip((src[:, 0] - lo_l) / max(hi_l - lo_l, 1e-6), 0, 1)
    at = np.linspace(0, 1, len(stops))
    new_lab = np.stack([np.interp(t, at, [q[ch] for q in stops]) for ch in range(3)], axis=1)
    pale = (np.hypot(src[:, 1], src[:, 2]) < 14) & (src[:, 0] > 72)
    new_lab[pale] = src[pale]
    if blossoms:
        petal = np.array([hex_lab(h) for h in blossoms])
        chroma = np.hypot(src[:, 1], src[:, 2])
        flower = ((src[:, 1] > 8) & (src[:, 0] > np.median(src[:, 0]))) | ((src[:, 0] > 65) & (chroma < 20))
        which = np.argmin(((src[:, None, 1:] - petal[None, :, 1:]) ** 2).sum(axis=2), axis=1)
        # Seen in the texture's own layout, so that a flower can be drawn wider: each ring takes the swatch of
        # the flower it grows from, and stays on leaf texels.
        swatch = np.full(mask.shape, -1, dtype=int)
        swatch[mask] = np.where(flower, which, -1)
        swatch, leaf_here = swatch.reshape(tex, tex), mask.reshape(tex, tex)          # the texels are held in one row
        for _ring in range(int(grow)):
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                beside = np.roll(swatch, (dy, dx), axis=(0, 1))
                take = leaf_here & (swatch < 0) & (beside >= 0)
                swatch[take] = beside[take]
        chosen = swatch.ravel()[mask]
        new_lab[chosen >= 0] = petal[chosen[chosen >= 0]]
        # A flower keeps some of its own light and shade (a patch of one flat colour reads as a sticker): each
        # painted flower texel stands as far above or below its swatch's lightness as six tenths of what it
        # stands from the flowers' middle lightness, by 12 at most; the ring a flower is grown by is 4 darker.
        if flower.any():
            middle = float(np.median(src[flower, 0]))
            new_lab[flower, 0] += np.clip(0.6 * (src[flower, 0] - middle), -12, 12)
            new_lab[(chosen >= 0) & ~flower, 0] -= 4
        px[mask, :3] = np.clip(from_lab(new_lab), 0, 1)
        return float((chosen >= 0).mean())
    px[mask, :3] = np.clip(from_lab(new_lab), 0, 1)
    return float(pale.mean())


if (opt("--leaf-ramp") or opt("--wood-ramp")) and "is_leaf" in lo_obj.data.attributes:
    marks = [item.value for item in lo_obj.data.attributes["is_leaf"].data]
    beds = [item.value for item in lo_obj.data.attributes["is_bed"].data] if "is_bed" in lo_obj.data.attributes else [0] * len(marks)
    leaf_px = None
    if opt("--leaf-ramp"):
        leaf_px = uv_mask([poly.index for poly in lo_obj.data.polygons if marks[poly.index] == 1]) & covered
        if leaf_px.sum() > 50:
            kept = ramped(leaf_px, opt("--leaf-ramp").split(","), float(opt("--leaf-ramp-from", "0.25")),
                          opt("--leaf-blossoms").split(",") if opt("--leaf-blossoms") else None, int(opt("--leaf-blossoms-grow", "0")))
            if opt("--leaf-blossoms"):
                report["leaf_blossoms"] = {"swatches": opt("--leaf-blossoms"), "grown_texels": int(opt("--leaf-blossoms-grow", "0")), "share_of_leaf_texels": round(kept, 4)}
            report["leaf_ramp"] = {"swatches": opt("--leaf-ramp"), "share_of_texels": round(float(leaf_px.sum() / max(covered.sum(), 1)), 3), "kept_as_blossom": round(kept, 3)}
    if opt("--wood-ramp"):
        wood_px = uv_mask([poly.index for poly in lo_obj.data.polygons if marks[poly.index] != 1 and beds[poly.index] != 1]) & covered
        if leaf_px is not None:
            wood_px &= ~leaf_px                       # where the two overlap in the texture the leaf has it
        if wood_px.sum() > 50:
            ramped(wood_px, opt("--wood-ramp").split(","), float(opt("--wood-ramp-from", "0.2")))
            report["wood_ramp"] = {"swatches": opt("--wood-ramp"), "share_of_texels": round(float(wood_px.sum() / max(covered.sum(), 1)), 3)}
if opt("--wood-colour") and "is_leaf" in lo_obj.data.attributes:
    # A planted tree's trunk is a small share of its design image, and the match can leave it the colour of the
    # leaves round it. The faces that are wood are known, so their texels are moved, as a whole, to this colour
    # (the sheet's bark swatch): their mean takes it and their own variation stays.
    marks = [item.value for item in lo_obj.data.attributes["is_leaf"].data]
    beds = [item.value for item in lo_obj.data.attributes["is_bed"].data] if "is_bed" in lo_obj.data.attributes else [0] * len(marks)
    wood_px = uv_mask([poly.index for poly in lo_obj.data.polygons if marks[poly.index] != 1 and beds[poly.index] != 1]) & covered
    if wood_px.sum() > 50:
        # Taken from the generator's own colours, not from the matched ones: the match draws each texel towards
        # the nearest of the design's main colours, which for a small tree are all leaf, and bark's lighter
        # streaks came out as pale patches. The streaks keep four fifths of their contrast.
        want = hex_lab(opt("--wood-colour"))
        lab_wood = to_lab(px0[wood_px])
        mean = lab_wood.mean(axis=0)
        lab_wood[:, 0] = want[0] + (lab_wood[:, 0] - mean[0]) * 0.8
        lab_wood[:, 1:] += want[1:] - mean[1:]
        lab_wood[:, 0] = np.clip(lab_wood[:, 0], 0, 100)
        px[wood_px, :3] = np.clip(from_lab(lab_wood), 0, 1)
        report["wood_colour"] = {"asked": opt("--wood-colour"), "share_of_texels": round(float(wood_px.sum() / max(covered.sum(), 1)), 3)}
if opt("--paint"):
    # What the generator painted in one range of colour is moved, as a whole, to a colour of the design: its
    # mean takes that colour, its own variation stays. For a stuff the generator paints so dull that the match
    # cannot tell it from another (the timber staves of a fountain's column came out the grey of its stone).
    p_h0, p_h1, p_sat, p_hex = opt("--paint").split(",")
    hue_g, sat_g, _ = hsv_of(px0)
    painted = (hue_g > float(p_h0)) & (hue_g < float(p_h1)) & (sat_g > float(p_sat)) & ~warm0
    if (painted & covered).sum() > 100:
        want = hex_lab(p_hex)
        lab_p = to_lab(px[painted][:, :3])
        mean = to_lab(px[painted & covered][:, :3]).mean(axis=0)
        lab_p[:, 0] *= want[0] / max(float(mean[0]), 1e-3)
        lab_p[:, 1:] += want[1:] - mean[1:]
        px[painted, :3] = np.clip(from_lab(lab_p), 0, 1)
    report["painted"] = {"asked": opt("--paint"), "share_of_texels": round(float((painted & covered).sum() / max(covered.sum(), 1)), 3)}
def water_colour():
    """The colour of a fountain's deep water (sRGB): --water-colour, or the middle colour of what the design
    image paints as deep water (not foam, not the falling sheets)."""
    if opt("--water-colour"):
        return np.array([int(opt("--water-colour")[i:i + 2], 16) / 255 for i in (1, 3, 5)])
    found = np.array([0.18, 0.5, 0.8])
    if design:
        d_all = bpy.data.images.load(design)
        dp = np.empty(d_all.size[0] * d_all.size[1] * 4, dtype=np.float32)
        d_all.pixels.foreach_get(dp)
        dp = dp.reshape(-1, 4)
        dp = dp[dp[:, 3] > 0.9][:, :3].astype(np.float64)
        deep = painted_water(dp) & (hsv_of(dp)[1] > 0.4)
        if deep.sum() > 100:
            found = np.clip(from_lab(np.median(to_lab(dp[deep]), axis=0)[None, :]), 0, 1)[0]
    return found


if water_disc is not None and pool_painted and "is_pool" in lo_obj.data.attributes:
    # The water in the basin, painted from the generated water: the generator paints it far darker than the
    # rest of its water, and the match, which fits one curve to all the water, leaves it dark. Its deep colour
    # is moved to the water's colour (the sheet's swatch); the foam on it, being light, stays as it is.
    pool_faces = [i for i, item in enumerate(lo_obj.data.attributes["is_pool"].data) if item.value == 1]
    pool_px = uv_mask(pool_faces) & covered
    if pool_px.sum() > 100:
        lab_w = to_lab(px[pool_px][:, :3])
        middle, want = np.median(lab_w, axis=0), to_lab(water_colour()[None, :])[0]
        share = np.clip((85.0 - lab_w[:, 0]) / max(85.0 - float(middle[0]), 1e-3), 0, 1)[:, None]
        lab_w += (want - middle) * share
        lab_w[:, 0] = np.clip(lab_w[:, 0], 0, 100)
        px[pool_px, :3] = np.clip(from_lab(lab_w), 0, 1)
        report["pool_colour"] = {"was": [round(float(v), 1) for v in middle], "now": [round(float(v), 1) for v in want]}
if opt("--fountain-rim") and "is_ring" in lo_obj.data.attributes:
    # The rim's top in another stuff than the wall (a design that lays timber on a stone basin): the generator
    # painted it nearly as dark as the stone, and the match leaves it so. The top of the ring built by rule is
    # known, so it is given the sheet's own colour: its middle colour takes it, its variation (the joints
    # between the planks) stays.
    ring_flags = [item.value for item in lo_obj.data.attributes["is_ring"].data]
    rim_px = uv_mask([poly.index for poly in lo_obj.data.polygons if ring_flags[poly.index] == 1 and poly.normal.z > 0.5]) & covered
    if rim_px.sum() > 100:
        lab_rim = to_lab(px[rim_px][:, :3])
        was = np.median(lab_rim, axis=0)
        lab_rim += hex_lab(opt("--fountain-rim")) - was
        lab_rim[:, 0] = np.clip(lab_rim[:, 0], 0, 100)
        px[rim_px, :3] = np.clip(from_lab(lab_rim), 0, 1)
        report["rim_colour"] = {"asked": opt("--fountain-rim"), "was": [round(float(v), 1) for v in was]}
if opt("--shelter-screen") and opt("--shelter"):
    # A screen the generator painted nearly as dark as the frame it stands in (grey tiles, where the design's
    # are light): by lightness the two cannot be told apart, but the screen's faces are known. What is
    # colourless on the faces that look to the front or the back in the footprint's back strip, between the
    # end structures and under the canopy, is moved to this colour: its mean takes it, its variation stays.
    sx0, sz0, sx1, sz1 = (float(v) for v in opt("--shelter").split(","))
    s_end = float(opt("--shelter-end", "0.15"))
    screen_faces = [poly.index for poly in lo_obj.data.polygons if abs(poly.normal.y) > 0.7 and poly.center.y < -sz1 + 0.25
                    and sx0 + s_end < poly.center.x < sx1 - s_end and poly.center.z < 2.2]
    screen_px = uv_mask(screen_faces) & covered & (hsv_of(px0)[1] < 0.25)
    if screen_px.sum() > 100:
        lab_screen = to_lab(px[screen_px][:, :3])
        was = lab_screen.mean(axis=0)
        lab_screen += hex_lab(opt("--shelter-screen")) - was
        lab_screen[:, 0] = np.clip(lab_screen[:, 0], 0, 100)
        px[screen_px, :3] = np.clip(from_lab(lab_screen), 0, 1)
        report["screen_colour"] = {"asked": opt("--shelter-screen"), "was": [round(float(v), 1) for v in was], "faces": len(screen_faces)}
if opt("--fountain-wall") == "top" and "is_ring" in lo_obj.data.attributes:
    # A basin built of cubes has no round wall for the ring to take its colours from: the bake finds the
    # water behind a step, or nothing. The ring's walls are painted the middle colour of its top instead.
    ring_flags = [item.value for item in lo_obj.data.attributes["is_ring"].data]
    top_px = uv_mask([poly.index for poly in lo_obj.data.polygons if ring_flags[poly.index] == 1 and poly.normal.z > 0.5]) & covered
    wall_faces = {poly.index for poly in lo_obj.data.polygons if ring_flags[poly.index] == 1 and poly.normal.z <= 0.5}
    wall_px = uv_mask(sorted(wall_faces))
    # and a few texels round the walls' places in the texture, where no other face lies: a wall drawn a little
    # smaller than the picture would show what was baked beside it along its seams
    round_them = wall_px.reshape(tex, tex).copy()
    for _ in range(max(2, tex // 256)):
        round_them |= np.roll(round_them, 1, axis=0) | np.roll(round_them, -1, axis=0) | np.roll(round_them, 1, axis=1) | np.roll(round_them, -1, axis=1)
    wall_px = wall_px | (round_them.ravel() & ~uv_mask([poly.index for poly in lo_obj.data.polygons if poly.index not in wall_faces]))
    if top_px.sum() > 100:
        px[wall_px, :3] = np.median(px[top_px][:, :3], axis=0)
        covered = covered | wall_px
        report["ring_walls_painted_as_top"] = int(wall_px.sum())
if opt("--glass") and opt("--glass-colour"):
    # Glass the generator painted another colour than the design's (a pane painted blue where the sheet draws
    # it pale grey, which the match then takes for the design's blue): its mean takes this colour, its own
    # variation stays.
    # texel by texel: what the generator painted in the glass's range, on the faces that may be glass (a face
    # is glass or not by its middle, and a large one holds a pane and the post beside it)
    g_range = opt("--glass").split(",")[1:]
    g_h0, g_h1, g_s0, g_s1, g_v0, g_v1 = (float(v) for v in g_range[:6])
    g_hue, g_sat, g_val = hsv_of(px0)
    may_be = [poly.index for poly in lo_obj.data.polygons if not (len(g_range) > 6 and g_range[6] == "front") or abs(poly.normal.y) > 0.7]
    glass_px = uv_mask(may_be) & covered & (g_hue >= g_h0) & (g_hue <= g_h1) & (g_sat >= g_s0) & (g_sat <= g_s1) & (g_val >= g_v0) & (g_val <= g_v1)
    if glass_px.sum() > 100:
        lab_glass = to_lab(px[glass_px][:, :3])
        lab_glass += hex_lab(opt("--glass-colour")) - lab_glass.mean(axis=0)
        lab_glass[:, 0] = np.clip(lab_glass[:, 0], 0, 100)
        px[glass_px, :3] = np.clip(from_lab(lab_glass), 0, 1)
if opt("--lantern-colour") and warm0.any():
    # What the generator painted as a lantern takes this colour's hue, and half its lightness.
    want = hex_lab(opt("--lantern-colour"))
    lab_warm = to_lab(px0[warm0])
    lab_warm[:, 0] = 0.5 * lab_warm[:, 0] + 0.5 * want[0]
    lab_warm[:, 1:] = want[1:]
    px0[warm0] = np.clip(from_lab(lab_warm), 0, 1)
if opt("--pale-colour") and opt("--glow-pale") and (pale0 & warm0).any():
    # What counts as lantern glass because it is pale (a sign's lit face, painted white by the generator where
    # the design has cream) takes this colour's hue, and half its lightness.
    want = hex_lab(opt("--pale-colour"))
    lab_pale = to_lab(px0[pale0 & warm0])
    lab_pale[:, 0] = 0.5 * lab_pale[:, 0] + 0.5 * want[0]
    lab_pale[:, 1:] = want[1:]
    px0[pale0 & warm0] = np.clip(from_lab(lab_pale), 0, 1)
if "--glow-warm" in argv and "--glow-matched" not in argv:
    px[warm0, :3] = px0[warm0]
if opt("--lamp-faces"):
    # A lamp's face: the generator paints it dark with a few bright specks, the design draws it lit. The faces
    # that look down between two heights (what hangs under a shelter's canopy) are painted as lit lamps, and
    # glow with whatever else glows.
    asked = opt("--lamp-faces").split(",")
    if asked[0] == "auto":
        z_from, z_to = lamp_heights if lamp_heights else (0.0, 0.0)
        tint = asked[1] if len(asked) > 1 else "#FFE9B8"
    else:
        z_from, z_to = float(asked[0]), float(asked[1])
        tint = asked[2] if len(asked) > 2 else "#FFE9B8"
    lamp_faces = [poly.index for poly in lo_obj.data.polygons if z_from <= poly.center.z <= z_to and poly.normal.z < -0.7]
    if lamp_faces:
        lamp_px = uv_mask(lamp_faces)
        px[lamp_px, :3] = np.array([int(tint[i:i + 2], 16) / 255 for i in (1, 3, 5)])
        warm0 = warm0 | lamp_px
        covered = covered | lamp_px
    report["lamp_faces"] = {"faces": len(lamp_faces), "from_m": round(float(z_from), 3), "to_m": round(float(z_to), 3), "colour": tint}
if measures and not np.array_equal(measured_px, px[:, :3]):
    # Colours were changed on purpose after the match (a bed's walls, leaves moved to a given green or ramp, bark,
    # an arm's bared inner face, painted lamp faces, lanterns and lamps given back the generator's colours). The
    # report's figures are the finished texture's; the figures as matched are kept beside them, with the share of
    # the texture's texels that changed.
    moved = np.abs(measured_px - px[:, :3]).max(axis=1) > 1 / 255
    for tag, measure in measures:
        as_matched = {"colour_delta_e": report[tag + "colour_delta_e"], "materials_reached": report[tag + "materials_reached"], "materials": report[tag + "materials"]}
        report[tag + "materials"], report[tag + "colour_delta_e"], report[tag + "materials_reached"] = measure(px)
        as_matched["share_of_texels_changed_since"] = round(float((moved & covered).sum() / max(covered.sum(), 1)), 3)
        report[tag + "colour_as_matched"] = as_matched
if core_vertices is not None:
    # A loose shrub's parts in its texture. Its inside is the shade between its leaves (a third of its own
    # variation kept; the tones are set level by level below). Its flowers take the sheet's
    # own flower colour: matched with the leaves they would be drawn to the colour the design has at their
    # lightness, which is leaf. A flower's centre keeps the colour the generator painted.
    me = lo_obj.data
    kind = np.array([item.value for item in me.attributes["part"].data])
    depth = np.array([item.value for item in me.attributes["drawn_in"].data])
    tint = np.array([item.value for item in me.attributes["flower_colour"].data])
    dark = float(opt("--core-dark", "0.8"))
    lab_px = to_lab(px[:, :3])
    inside_px = uv_mask([int(i) for i in np.nonzero(kind == 0)[0]])
    leaf_lab = lab_px[leaf_texels.ravel()]
    own_mean = lab_px[inside_px].mean(axis=0) if inside_px.any() else np.zeros(3)
    if len(leaf_lab) > 100 and inside_px.any():
        cuts = np.percentile(leaf_lab[:, 0], [20, 30, 55])
        shade = leaf_lab[leaf_lab[:, 0] <= cuts[0]].mean(axis=0)
        middling = leaf_lab[(leaf_lab[:, 0] >= cuts[1]) & (leaf_lab[:, 0] <= cuts[2])].mean(axis=0)
        report["leaves"]["inside_colour"] = ["#%02X%02X%02X" % tuple(int(round(float(v) * 255)) for v in np.clip(from_lab(c_[None, :]), 0, 1)[0]) for c_ in (middling, shade)]
    for level in np.unique(np.round(depth[kind == 0], 1)):
        where_ = uv_mask([int(i) for i in np.nonzero((kind == 0) & (np.round(depth, 1) == level))[0]])
        if len(leaf_lab) > 100:
            # at its ring the inside is a layer of leaves in a middling tone (it stands as far out as they do,
            # and a dark rim there reads as a ledge); from there it passes to the shade of the darkest fifth
            tone = middling + (shade - middling) * min(1.0, 1.5 * float(level))
            lab_px[where_] = tone + 0.33 * (lab_px[where_] - own_mean)
        lab_px[where_, 0] *= 1 - (1 - dark) * level
    for k, text in enumerate(flower_colours):
        where_ = uv_mask([int(i) for i in np.nonzero((kind == 2) & (tint == k))[0]])
        if where_.any():
            want = hex_lab(text)
            lab_px[where_, 0] = np.clip(want[0] + 0.4 * (lab_px[where_, 0] - np.median(lab_px[where_, 0])), want[0] - 10, want[0] + 10)
            lab_px[where_, 1:] = want[1:]
    if opt("--leaf-swatches"):
        # A style that paints in flat colours (low-poly): every leaf takes one of the sheet's own leaf swatches,
        # the nearest to what the match gave it, and keeps a little of its own lightness (so that a blade's two
        # halves still differ). The match alone leaves each leaf a tone of its own, and a shrub of them reads
        # as mottled.
        given = [hex_lab(text) for text in opt("--leaf-swatches").split(",")]
        grown = leaf_texels.copy()
        for _ in range(3):
            grown = grown | np.roll(grown, 1, 0) | np.roll(grown, -1, 0) | np.roll(grown, 1, 1) | np.roll(grown, -1, 1)
        where_ = grown.ravel() & ~inside_px
        own_ = lab_px[where_]
        pick = np.argmin(((own_[:, None, :] - np.array(given)[None]) ** 2).sum(axis=2), axis=1)
        snapped = np.array(given)[pick]
        snapped[:, 0] += 0.5 * np.clip(own_[:, 0] - snapped[:, 0], -5, 5)
        lab_px[where_] = snapped
        report["leaves"]["leaf_swatches"] = {text: round(float((pick == k).mean()), 3) for k, text in enumerate(opt("--leaf-swatches").split(","))}
    lab_px[:, 0] = np.clip(lab_px[:, 0], 0, 100)
    px[:, :3] = np.clip(from_lab(lab_px), 0, 1)
    where_ = uv_mask([int(i) for i in np.nonzero(kind == 3)[0]])
    px[where_, :3] = px0[where_]
    report["leaves"]["inside_darkened_to"] = dark
if "--facet-colour" in argv:
    # One colour a face, as a low-poly kit paints its pieces: every face takes the mean of what the texture
    # holds for it (and a ring of texels round it, so nothing else shows along its edges).
    uv_f = np.empty(len(lo_obj.data.loops) * 2, dtype=np.float32)
    lo_obj.data.uv_layers.active.data.foreach_get("uv", uv_f)
    uv_f = uv_f.reshape(-1, 2).astype(np.float64) * tex
    img_f = px.reshape(tex, tex, 4)
    flat_colours = img_f[..., :3].copy()
    for poly in lo_obj.data.polygons:
        loops = list(poly.loop_indices)
        xs, ys = uv_f[loops, 0], uv_f[loops, 1]
        x0, x1 = max(int(np.floor(xs.min())) - 2, 0), min(int(np.ceil(xs.max())) + 2, tex - 1)
        y0, y1 = max(int(np.floor(ys.min())) - 2, 0), min(int(np.ceil(ys.max())) + 2, tex - 1)
        det = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if len(loops) != 3 or x1 < x0 or y1 < y0 or abs(det) < 1e-12:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / det
        b = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / det
        inside = (a >= 0) & (b >= 0) & (1 - a - b >= 0)
        if not inside.any():
            inside = (a >= -0.5) & (b >= -0.5) & (1 - a - b >= -0.5)
        reach_px = 1.5 / max(math.sqrt(abs(det)), 1e-6)                      # about a texel and a half beyond the edges
        around = (a >= -reach_px) & (b >= -reach_px) & (1 - a - b >= -reach_px)
        part = flat_colours[y0: y1 + 1, x0: x1 + 1]
        part[around & ~inside] = img_f[y0: y1 + 1, x0: x1 + 1, :3][inside].mean(axis=0)
        part[inside] = img_f[y0: y1 + 1, x0: x1 + 1, :3][inside].mean(axis=0)
    img_f[..., :3] = flat_colours
    report["facet_colour"] = True
px[:, 3] = 1.0
albedo.pixels.foreach_set(px.astype(np.float32).ravel())
albedo.filepath_raw = str(out.with_suffix(".albedo.png"))
albedo.file_format = "PNG"
albedo.save()
albedo.pack()

if "--no-normal" not in argv:
    normal, normal_node = bake("NORMAL", "normal", "Non-Color")
    nm = nodes.new("ShaderNodeNormalMap")
    links.new(normal_node.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    normal.filepath_raw = str(out.with_suffix(".normal.png"))
    normal.file_format = "PNG"
    normal.save()
    normal.pack()

if skin_from is not None and "--no-normal" in argv:
    custom = lo_obj.data.attributes.get("custom_normal")
    if custom is not None:
        lo_obj.data.attributes.remove(custom)
    for poly in lo_obj.data.polygons:
        poly.use_smooth = "--flat" not in argv

# ---- A shrub's outline, finished on the piece itself ----
if want_reach is not None and round_by > 0:
    # Where the piece's own surface crosses the ring's height it is turned out to the circle: in each direction
    # the whole piece is scaled across by what that crossing lacks, and what then passes the circle elsewhere
    # comes back to it (it stands there as an upright side, as a clipped shrub's does). Done after the bakes:
    # they need the piece where the generated model is.
    held = want_reach
    me = lo_obj.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    e = np.empty(len(me.edges) * 2, dtype=np.int32)
    me.edges.foreach_get("vertices", e)
    ring_verts = len(co) if core_vertices is None else core_vertices          # a loose shrub's ring is its inside's; its leaves follow
    e = e.reshape(-1, 2)
    e = e[(e < ring_verts).all(axis=1)].ravel()

    def ring_of():
        """Where the surface crosses the ring's height: the outermost crossing in each 3 degrees, by direction."""
        a, b = co[e[0::2]], co[e[1::2]]
        rise = b[:, 2] - a[:, 2]
        with np.errstate(divide="ignore", invalid="ignore"):
            f = (ring_z - a[:, 2]) / rise
        ok = (rise != 0) & (f > 0) & (f < 1)
        p = np.concatenate([a[ok] + (b[ok] - a[ok]) * f[ok][:, None], co[:ring_verts][np.abs(co[:ring_verts, 2] - ring_z) < 1e-6]])
        ang, rad = np.degrees(np.arctan2(p[:, 1], p[:, 0])) % 360, np.hypot(p[:, 0], p[:, 1])
        best = {}
        for k in np.argsort(rad):
            best[int(ang[k] // 3)] = k
        keep = sorted(best.values(), key=lambda k: ang[k])
        return ang[keep], rad[keep]

    first = None
    for _ in range(3 if round_by >= 1 else 1):
        ang, rad = ring_of()
        first = first if first is not None else float(rad.min() / held)
        gain = 1 + round_by * (np.minimum(held / rad, round_most) - 1)
        co[:ring_verts, :2] *= np.interp(np.degrees(np.arctan2(co[:ring_verts, 1], co[:ring_verts, 0])) % 360, ang, gain, period=360)[:, None]
        rr = np.hypot(co[:, 0], co[:, 1])
        past = rr > held                                                   # at every height: an edge from under the band crosses into it
        co[past, :2] *= (held / rr[past])[:, None]
    ang, rad = ring_of()
    rr = np.hypot(co[:, 0], co[:, 1])
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    report["shrub"]["round"].update({"ring_at_m": round(float(ring_z), 3), "ring_least_before": round(first, 3), "ring_least": round(float(rad.min() / held), 3),
                                       "vertices_on_the_circle": int((rr > held * 0.999).sum())})

# ---- A crown open on top is filled with a smaller copy of its own upper leaf masses ----
if opt("--crown-fill") and "is_leaf" in lo_obj.data.attributes:
    # The generator sees the tree from one side and builds its crown as a ring of leaf masses: from above the
    # trunk and the bed show through the middle. The upper leaf masses are copied, drawn in towards the crown's
    # axis (SHARE of their size, about the crown's top) and turned (TURN degrees) so that the copies do not line
    # up with what they were copied from. They keep their texture, so they are the same leaves.
    values = [float(v) for v in opt("--crown-fill").split(",")]
    bmf = bmesh.new()
    bmf.from_mesh(lo_obj.data)
    leaf_layer = bmf.faces.layers.int.get("is_leaf")
    leaf_faces = [f for f in bmf.faces if f[leaf_layer] == 1]
    lz = [v.co.z for f in leaf_faces for v in f.verts]
    lx = [v.co.x for f in leaf_faces for v in f.verts]
    ly = [v.co.y for f in leaf_faces for v in f.verts]
    z_lo, z_hi = min(lz), max(lz)
    cx, cy = (min(lx) + max(lx)) / 2, (min(ly) + max(ly)) / 2
    upper = [f for f in leaf_faces if f.calc_center_median().z > z_lo + 0.45 * (z_hi - z_lo)]
    copies = 0
    for share, turn in zip(values[0::2], values[1::2]):          # a second pair fills what the first copy's own middle leaves open
        made = bmesh.ops.duplicate(bmf, geom=upper)
        ca, sa = math.cos(math.radians(turn)), math.sin(math.radians(turn))
        for v in (g for g in made["geom"] if isinstance(g, bmesh.types.BMVert)):
            x, y = v.co.x - cx, v.co.y - cy
            v.co.x = cx + (x * ca - y * sa) * share
            v.co.y = cy + (x * sa + y * ca) * share
            v.co.z = z_hi - (z_hi - v.co.z) * (0.5 + 0.5 * share)
        copies += sum(1 for g in made["geom"] if isinstance(g, bmesh.types.BMFace))
    bmf.to_mesh(lo_obj.data)
    bmf.free()
    report["crown_fill"] = {"shares_and_turns": values, "triangles": copies}
    report["tris"] += copies

# ---- Where the small lights go (decided here: their light is painted into the glow texture) ----
fairy_spots = []
if opt("--fairy"):
    fairy = opt("--fairy").split(",")
    fairy_count, fairy_above = int(fairy[0]), float(fairy[1])
    fairy_size = float(fairy[2]) if len(fairy) > 2 else 0.18
    rng3 = np.random.default_rng(11)
    f_faces = [f for f in lo_obj.data.polygons if f.center.z > fairy_above]
    f_areas = np.array([f.area for f in f_faces])
    for fi in rng3.choice(len(f_faces), size=fairy_count, p=f_areas / f_areas.sum()):
        f = f_faces[fi]
        corners = [np.array(lo_obj.data.vertices[i].co) for i in list(f.vertices)[:3]]
        w = rng3.dirichlet([1.0, 1.0, 1.0])
        fairy_spots.append(sum(wi * c for wi, c in zip(w, corners)) + np.array(f.normal) * 0.05)

# ---- What glows: bright, saturated texels emit their own colour ----
if glow:
    lum = px[:, :3] @ LUM
    mx, mn = px[:, :3].max(axis=1), px[:, :3].min(axis=1)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    lit = covered & (mx > 0.86) & ((sat > 0.25) | (lum > 0.9))
    if "--glow-warm" in argv:
        lit = warm0.copy()
    if opt("--glow-from"):
        # Only the lantern glows: a design can paint a highlight on the post as bright as the glass.
        lit = lit & uv_mask([poly.index for poly in lo_obj.data.polygons if poly.center.z >= float(opt("--glow-from"))])
    report["glow_share"] = round(float(lit.sum() / max(covered.sum(), 1)), 4)
    em = np.zeros_like(px)
    tint = opt("--glow-colour")
    if tint:
        tint_rgb = np.array([int(tint[i:i + 2], 16) / 255 for i in (1, 3, 5)])
        em[:, :3] = np.where(lit[:, None], tint_rgb[None, :], 0.0)
    else:
        em[:, :3] = np.where(lit[:, None], px[:, :3], 0.0)
    if fairy_spots and opt("--fairy-halo"):
        # The light the small lights throw on the leaves round them, which the game cannot afford as lamps
        # (one lamp a tree): painted into the glow texture, face by face, by how near the face is to them.
        from mathutils import kdtree
        sigma, strength = (float(v) for v in opt("--fairy-halo").split(","))
        kd = kdtree.KDTree(len(fairy_spots))
        for i, q in enumerate(fairy_spots):
            kd.insert(tuple(float(v) for v in q), i)
        kd.balance()
        halo_img = np.zeros((tex, tex))
        uv_data = lo_obj.data.uv_layers.active.data

        def fill_tri(tri, value):
            xs, ys = tri[:, 0], tri[:, 1]
            x0, x1 = max(int(np.floor(xs.min())), 0), min(int(np.ceil(xs.max())), tex - 1)
            y0, y1 = max(int(np.floor(ys.min())), 0), min(int(np.ceil(ys.max())), tex - 1)
            det = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if x1 < x0 or y1 < y0 or abs(det) < 1e-12:
                return
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            a = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / det
            b = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / det
            inside = (a >= -0.05) & (b >= -0.05) & (1 - a - b >= -0.05)
            part = halo_img[y0:y1 + 1, x0:x1 + 1]
            part[inside] = np.maximum(part[inside], value)

        for poly in lo_obj.data.polygons:
            near = kd.find_range(tuple(poly.center), 3 * sigma)
            if not near:
                continue
            value = min(1.0, sum(math.exp(-(d * d) / (2 * sigma * sigma)) for _, _, d in near))
            loops = list(poly.loop_indices)
            for k in range(1, len(loops) - 1):
                fill_tri(np.array([[uv_data[i].uv[0] * tex, uv_data[i].uv[1] * tex] for i in (loops[0], loops[k], loops[k + 1])]), value)
        halo = halo_img.reshape(-1)
        warm = np.array([1.0, 0.77, 0.44])
        em[:, :3] = np.clip(em[:, :3] + (halo ** 2)[:, None] * strength * warm[None, :], 0, 1)
        report["fairy_halo"] = {"sigma_m": sigma, "strength": strength, "share_lit": round(float((halo > 0.05).mean()), 3)}
    em[:, 3] = 1.0
    # Where it glows on the piece: the faces whose middle falls on a glowing texel.
    uv_layer = lo_obj.data.uv_layers.active.data
    lit_img = lit.reshape(tex, tex)
    spots, weights = [], []
    for poly in lo_obj.data.polygons:
        uv = np.mean([uv_layer[i].uv for i in poly.loop_indices], axis=0)
        x, y = min(int(uv[0] * tex), tex - 1), min(int(uv[1] * tex), tex - 1)
        if lit_img[y, x]:
            spots.append(np.array(poly.center))
            weights.append(poly.area)
    glow_at = np.average(spots, axis=0, weights=weights) if spots else None
    report["glow_faces"] = len(spots)
    if opt("--light-at"):
        glow_at = np.array([float(v) for v in opt("--light-at").split(",")])
    emission = bpy.data.images.new("emission", tex, tex, alpha=True)
    emission.pixels.foreach_set(em.astype(np.float32).ravel())
    emission.filepath_raw = str(out.with_suffix(".emission.png"))
    emission.file_format = "PNG"
    emission.save()
    emission.pack()
    e_node = nodes.new("ShaderNodeTexImage")
    e_node.image = emission
    links.new(e_node.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = float(opt("--glow-strength", "2.0"))
    mat.name = glow
else:
    glow_at = None

# ---- The glowing faces as a part of their own, where the kit's spec names one (a tree's `lanterns`) ----
part_name = opt("--glow-part")
glow_part = None
if part_name and glow:
    lit_faces = [poly.index for poly in lo_obj.data.polygons
                 if lit_img[min(int(np.mean([uv_layer[i].uv[1] for i in poly.loop_indices]) * tex), tex - 1),
                            min(int(np.mean([uv_layer[i].uv[0] for i in poly.loop_indices]) * tex), tex - 1)]]
    if opt("--glow-part-from"):
        lit_faces = [i for i in lit_faces if lo_obj.data.polygons[i].center.z >= float(opt("--glow-part-from"))]
    # A lantern is a group of glowing faces that touch. A face or two glowing on its own (a warm texel on the
    # bed, a speck high in the crown) is not one, and stays in the body.
    lit_set, strays = set(lit_faces), 0
    edge_faces = {}
    for poly in lo_obj.data.polygons:
        if poly.index in lit_set:
            for ek in poly.edge_keys:
                edge_faces.setdefault(ek, []).append(poly.index)
    touching = {i: set() for i in lit_set}
    for members in edge_faces.values():
        for i in members:
            touching[i].update(m for m in members if m != i)
    seen_faces, kept_faces = set(), []
    for start in lit_faces:
        if start in seen_faces:
            continue
        group, stack = [], [start]
        seen_faces.add(start)
        while stack:
            f_i = stack.pop()
            group.append(f_i)
            for nb in touching[f_i]:
                if nb not in seen_faces:
                    seen_faces.add(nb)
                    stack.append(nb)
        if len(group) >= int(opt("--glow-part-least", "1")):
            kept_faces += group
        else:
            strays += len(group)
    lit_faces = sorted(kept_faces)
    if len(lit_faces) < 12:
        report["glow_part"] = {"name": part_name, "faces": len(lit_faces), "made": False, "stray_faces_left_in_the_body": strays}        # a stray texel or two is not a lantern
    else:
        only(lo_obj)
        before = set(bpy.data.objects)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_mode(type="FACE")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        for i in lit_faces:
            lo_obj.data.polygons[i].select = True
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        made = [o for o in bpy.data.objects if o not in before]
        if made:
            glow_part = made[0]
            glow_part.name = part_name
            glow_part.data.name = part_name
        report["glow_part"] = {"name": part_name, "faces": len(lit_faces), "stray_faces_left_in_the_body": strays}

# ---- A plain planter box is closed underneath ----
if opt("--planter") and report.get("planter", {}).get("box") == "plain":
    # The ground the game draws under a piece is a few centimetres above or below its foot, and a box open
    # underneath shows its inside through the gap. The bottom takes one texel of a wall's foot for its colour,
    # so it costs no room in the texture (it is added after the bakes for that reason).
    bmb = bmesh.new()
    bmb.from_mesh(lo_obj.data)
    uv_l = bmb.loops.layers.uv.active
    bed_l = bmb.faces.layers.int.get("is_bed")
    wall = next(f for f in bmb.faces if f[bed_l] == 1 and abs(f.normal.z) < 0.1 and min(v.co.z for v in f.verts) < 1e-6)
    mid = sum((l[uv_l].uv for l in wall.loops), Vector((0.0, 0.0))) / len(wall.loops)
    low = next(l for l in wall.loops if l.vert.co.z < 1e-6)[uv_l].uv
    at = low + (mid - low) * 0.25
    hw, hd = box_w / 2, box_d / 2
    if planter_foot:
        under = bmb.faces.new([bmb.verts.new((x, y, 0.0)) for x, y in planter_foot[::-1]])      # a tiered box's lowest outline, looking down
        report["tris"] += len(planter_foot) - 4
    else:
        under = bmb.faces.new([bmb.verts.new(q) for q in ((-hw, -hd, 0.0), (-hw, hd, 0.0), (hw, hd, 0.0), (hw, -hd, 0.0))])      # looks down
    under[bed_l] = 1
    for l in under.loops:
        l[uv_l].uv = at
    bmb.to_mesh(lo_obj.data)
    bmb.free()
    report["tris"] += 2

def plain_copy(of, called, roughness):
    """A copy of the piece's material under another name, with the same colour texture and nothing that glows
    or bumps: for faces the game treats by their material's name (glass), or that are another stuff (water)."""
    copy = of.copy()
    copy.name = called
    tree = copy.node_tree
    shader = tree.nodes["Principled BSDF"]
    for socket in ("Emission Color", "Normal"):
        for link in list(shader.inputs[socket].links):
            tree.links.remove(link)
    shader.inputs["Emission Strength"].default_value = 0.0
    shader.inputs["Roughness"].default_value = roughness
    return copy


# ---- Glass as a material of its own (the game lights a material named glass... at night) ----
if opt("--glass"):
    g_name = opt("--glass").split(",")[0]
    glassy = glass_faces()
    if glassy.any():
        lo_obj.data.materials.append(plain_copy(mat, g_name, float(opt("--glass-rough", "0.1"))))
        for poly in lo_obj.data.polygons:
            if glassy[poly.index]:
                poly.material_index = len(lo_obj.data.materials) - 1
    report["glass"] = {"material": g_name, "faces": int(glassy.sum()), "share_of_area": round(float(sum(p.area for p in lo_obj.data.polygons if glassy[p.index]) / max(sum(p.area for p in lo_obj.data.polygons), 1e-9)), 3)}

# ---- A fountain's water as a part of its own: the flat disc, and what the generator painted as water ----
water_part = None
if water_disc is not None:
    rough_w = float(opt("--water-rough", "0.05"))
    sides_of_disc = int(opt("--fountain-sides", "48"))
    flat_rgb = water_colour()
    ringed = np.zeros(len(lo_obj.data.polygons), dtype=bool)
    if "is_ring" in lo_obj.data.attributes:
        ringed = np.array([item.value == 1 for item in lo_obj.data.attributes["is_ring"].data])
    pooled = np.zeros(len(lo_obj.data.polygons), dtype=bool)
    if pool_painted and "is_pool" in lo_obj.data.attributes:
        pooled = np.array([item.value == 1 for item in lo_obj.data.attributes["is_pool"].data])
    wet = (painted_water(painted_at_faces(lo_obj)) & ~ringed) | pooled
    report["water"] = {"pool": "painted from the generated water" if pool_painted else "flat", "roughness": rough_w,
                       "drawn_tris": int(sum(len(p.vertices) - 2 for p in lo_obj.data.polygons if wet[p.index])), "disc_tris": sides_of_disc - 2}
    if not pool_painted:
        flat = bpy.data.materials.new("water")
        flat.use_nodes = True
        fb = flat.node_tree.nodes["Principled BSDF"]
        lin = np.where(flat_rgb <= 0.04045, flat_rgb / 12.92, ((flat_rgb + 0.055) / 1.055) ** 2.4)
        fb.inputs["Base Color"].default_value = (float(lin[0]), float(lin[1]), float(lin[2]), 1.0)
        fb.inputs["Roughness"].default_value = rough_w
        fb.inputs["Metallic"].default_value = 0.0
        water_disc.data.materials.append(flat)
        report["water"]["flat_colour"] = "#%02X%02X%02X" % tuple(int(round(float(v) * 255)) for v in flat_rgb)
        report["tris"] += sides_of_disc - 2
        water_part = water_disc
    if wet.any():
        only(lo_obj)
        before = set(bpy.data.objects)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_mode(type="FACE")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        for poly in lo_obj.data.polygons:
            poly.select = bool(wet[poly.index])
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        drawn = [o for o in bpy.data.objects if o not in before][0]
        drawn.data.materials.clear()
        drawn.data.materials.append(plain_copy(mat, "water_drawn", rough_w))
        if not pool_painted:
            bpy.ops.object.select_all(action="DESELECT")
            water_disc.select_set(True)
            drawn.select_set(True)
            bpy.context.view_layer.objects.active = drawn
            bpy.ops.object.join()
            drawn = bpy.context.view_layer.objects.active
        water_part = drawn
    water_part.name = "water"
    water_part.data.name = "water"

# ---- Names, the parts the game lights, export ----
bpy.data.objects.remove(hi, do_unlink=True)
root = bpy.data.objects.new(name, None)
bpy.context.scene.collection.objects.link(root)
lo_obj.parent = root
if glow_part is not None:
    glow_part.parent = root
if water_part is not None:
    water_part.parent = root
carried = []
if "--kit-lights" in argv and kit_path:
    for o in load(kit_path):
        if o.type == "MESH" and o.name.split(".")[0] in ("light", "lights"):
            world = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = world
            only(o)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            o.name = opt("--kit-lights-as", o.name.split(".")[0])
            o.parent = root
            carried.append(o.name)
            # The kit hangs its strip just under its own seat boards. This seat's boards are not the kit's: the
            # strip is moved to hang 4 mm under whatever of the new piece lies above it (found by rays cast up
            # from the ground along the strip's middle), or it would lie on the seat or inside it.
            body_tree = BVHTree.FromObject(lo_obj, bpy.context.evaluated_depsgraph_get())
            sp = np.array([v.co[:] for v in o.data.vertices])
            unders = []
            for fx in np.linspace(0.15, 0.85, 15):
                x = sp[:, 0].min() + fx * (sp[:, 0].max() - sp[:, 0].min())
                y = sp[:, 1].min() + fx * (sp[:, 1].max() - sp[:, 1].min()) if (sp[:, 1].max() - sp[:, 1].min()) > (sp[:, 0].max() - sp[:, 0].min()) else float(sp[:, 1].mean())
                if (sp[:, 1].max() - sp[:, 1].min()) > (sp[:, 0].max() - sp[:, 0].min()):
                    x = float(sp[:, 0].mean())
                hit = body_tree.ray_cast(Vector((float(x), float(y), 0.02)), Vector((0, 0, 1)))
                if hit[0] is not None and hit[0].z > 0.2:
                    unders.append(hit[0].z)
            if unders:
                under = float(np.median(unders))
                shift = (under - 0.004) - float(sp[:, 2].max())
                for v in o.data.vertices:
                    v.co.z += shift
                report.setdefault("carried_light_moved_m", {})[o.name] = round(shift, 3)
        elif o.name != root.name:
            bpy.data.objects.remove(o, do_unlink=True)
report["carried_light_parts"] = carried
for extra in (opt("--empty", "") or "").split(","):
    if extra:
        e = bpy.data.objects.new(extra, None)
        bpy.context.scene.collection.objects.link(e)
        e.parent = root
if opt("--core") and opt("--tree"):
    share = float(opt("--core"))
    co = np.array([v.co[:] for v in lo_obj.data.vertices])
    z0, z1 = crown_starts_m, float(co[:, 2].max())
    height = z1 - z0
    crown_pts = co[co[:, 2] > z0 + 0.25 * height]
    centre = (crown_pts[:, :2].min(axis=0) + crown_pts[:, :2].max(axis=0)) / 2
    pick = crown_pts[np.random.default_rng(13).choice(len(crown_pts), min(3000, len(crown_pts)), replace=False)]
    bmc = bmesh.new()
    for q in pick:
        bmc.verts.new(q)
    hull = bmesh.ops.convex_hull(bmc, input=list(bmc.verts))
    junk = list({g for g in hull["geom_interior"] + hull["geom_unused"] if isinstance(g, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bmc, geom=junk, context="VERTS")
    lo_z, hi_z = (float(v) for v in opt("--core-span", "0.42,0.90").split(","))
    for v in bmc.verts:
        v.co.x = centre[0] + (v.co.x - centre[0]) * share
        v.co.y = centre[1] + (v.co.y - centre[1]) * share
        t = (v.co.z - (z0 + 0.25 * height)) / (0.75 * height)
        v.co.z = z0 + (lo_z + t * (hi_z - lo_z)) * height
    core_mesh = bpy.data.meshes.new("core")
    bmc.to_mesh(core_mesh)
    bmc.free()
    core = bpy.data.objects.new(opt("--core-name", "canopy"), core_mesh)
    bpy.context.scene.collection.objects.link(core)
    only(core)
    n_core = tri_count(core)
    if n_core > 220:
        dm = core.modifiers.new("cut", "DECIMATE")
        dm.ratio = 220 / n_core
        dm.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=dm.name)
    for poly in core.data.polygons:
        poly.use_smooth = "--core-smooth" in argv
    # The leaves' shade: among the leaf-coloured texels (green or olive, not bark), the darker third.
    leafy = covered & (px[:, 1] > px[:, 2] * 1.25) & (px[:, 1] >= px[:, 0] * 0.9)
    if leafy.sum() > 100:
        leaf_px = px[leafy][:, :3]
        lum_leaf = leaf_px @ LUM
        shade = leaf_px[lum_leaf <= np.percentile(lum_leaf, 33)].mean(axis=0) * float(opt("--core-dark", "0.8"))
    else:
        shade = px[covered][:, :3].mean(axis=0) * 0.5
    cm = bpy.data.materials.new("crown_shade")
    cm.use_nodes = True
    cb = cm.node_tree.nodes["Principled BSDF"]
    lin = np.where(shade <= 0.04045, shade / 12.92, ((shade + 0.055) / 1.055) ** 2.4)
    cb.inputs["Base Color"].default_value = (float(lin[0]), float(lin[1]), float(lin[2]), 1.0)
    cb.inputs["Roughness"].default_value = 1.0
    cb.inputs["Metallic"].default_value = 0.0
    core.data.materials.append(cm)
    core.parent = root
    report["core"] = {"tris": tri_count(core), "colour": "#%02X%02X%02X" % tuple(int(round(float(v) * 255)) for v in np.clip(shade, 0, 1)),
                      "from_m": round(z0 + lo_z * height, 2), "to_m": round(z0 + hi_z * height, 2)}
    if opt("--core-plan"):
        # The design sheet draws the tree from straight above as well. A generated crown is open or patchy on
        # top (the generator saw it from one side), and the inner mass shows there as a plain lid. It is given
        # the sheet's own view from above instead: that drawing, laid over the mass from above, so that the
        # crown's whole width in the drawing lies on the crown's whole width in the piece.
        plan_path, bx0, by0, bx1, by1 = opt("--core-plan").rsplit(",", 4)
        sheet_img = bpy.data.images.load(plan_path)
        sw, sh = sheet_img.size
        sp = np.empty(sw * sh * 4, dtype=np.float32)
        sheet_img.pixels.foreach_get(sp)
        sp = sp.reshape(sh, sw, 4)[::-1]                                  # top row first, as the box is given
        crop = sp[int(by0):int(by1), int(bx0):int(bx1), :3].astype(np.float64)
        n_plan = 512
        yi = np.clip((np.arange(n_plan) + 0.5) / n_plan * crop.shape[0], 0, crop.shape[0] - 1).astype(int)
        xi = np.clip((np.arange(n_plan) + 0.5) / n_plan * crop.shape[1], 0, crop.shape[1] - 1).astype(int)
        plan = crop[yi][:, xi]
        # What in the drawing is not leaf (the grey backdrop in its corners, the bed's rim) takes the leaves' shade.
        plan_lab = to_lab(plan.reshape(-1, 3))
        grey = np.hypot(plan_lab[:, 1], plan_lab[:, 2]) < 9
        flat_plan = plan.reshape(-1, 3)
        flat_plan[grey] = np.clip(shade, 0, 1)
        plan_px = np.concatenate([flat_plan.reshape(n_plan, n_plan, 3)[::-1], np.ones((n_plan, n_plan, 1))], axis=2)      # bottom row first again
        plan_img = bpy.data.images.new("crown_top", n_plan, n_plan, alpha=False)
        plan_img.pixels.foreach_set(plan_px.astype(np.float32).ravel())
        plan_img.filepath_raw = str(out.with_suffix(".crown-top.png"))
        plan_img.file_format = "PNG"
        plan_img.save()
        plan_img.pack()
        half = (crown_pts[:, :2].max(axis=0) - crown_pts[:, :2].min(axis=0)) / 2
        uv_core = core.data.uv_layers.new(name="UVMap")
        for poly in core.data.polygons:
            for li in poly.loop_indices:
                v = core.data.vertices[core.data.loops[li].vertex_index].co
                uv_core.data[li].uv = (0.5 + (v.x - centre[0]) / (2 * half[0]), 0.5 + (v.y - centre[1]) / (2 * half[1]))
        cm.name = "crown_top"
        tn = cm.node_tree.nodes.new("ShaderNodeTexImage")
        tn.image = plan_img
        cm.node_tree.links.new(tn.outputs["Color"], cb.inputs["Base Color"])
        report["core"]["plan"] = {"box": [int(bx0), int(by0), int(bx1), int(by1)], "not_leaf_share": round(float(grey.mean()), 3)}
    report["tris"] += report["core"]["tris"]
if fairy_spots:
    count, size = len(fairy_spots), fairy_size
    at = np.array([float(v) for v in opt("--light-at", "0,0,0").split(",")])
    rng4 = np.random.default_rng(12)
    bmf = bmesh.new()
    tet = np.array([[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]]) * (size / (2 * math.sqrt(2)))
    for spot in fairy_spots:
        q = rng4.normal(size=4)
        q /= np.linalg.norm(q)
        qw, qx, qy, qz = q
        turn = np.array([[1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw)],
                         [2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw)],
                         [2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)]])
        vs = [bmf.verts.new(tuple(spot + turn @ t - at)) for t in tet]
        for i, j, k in ((0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 3, 2)):
            bmf.faces.new((vs[i], vs[j], vs[k]))
    bmesh.ops.recalc_face_normals(bmf, faces=list(bmf.faces))
    fairy_mesh = bpy.data.meshes.new("lights")
    bmf.to_mesh(fairy_mesh)
    bmf.free()
    fairy_obj = bpy.data.objects.new("lights", fairy_mesh)
    bpy.context.scene.collection.objects.link(fairy_obj)
    fairy_obj.location = tuple(float(v) for v in at)
    fm = bpy.data.materials.new("fairy_glow")
    fm.use_nodes = True
    fb = fm.node_tree.nodes["Principled BSDF"]
    fb.inputs["Base Color"].default_value = (1.0, 0.552, 0.162, 1.0)
    fb.inputs["Emission Color"].default_value = (1.0, 0.552, 0.162, 1.0)
    fb.inputs["Emission Strength"].default_value = 1.0
    fairy_mesh.materials.append(fm)
    fairy_obj.parent = root
    report["fairy_lights"] = count
    report["tris"] += count * 4
if opt("--under-glow") and not carried:
    # A night style's seat stands on a line of light (its design draws one round the base). A thin slab under
    # the piece, a little inside its outline, shows as that line. Named `lights` (the default) it only glows;
    # named `light` the game also hangs a small lamp at its middle, which puts a pool of light on the paving.
    z_lo, z_hi, inset = (float(v) for v in opt("--under-glow").split(","))
    co = np.array([v.co[:] for v in lo_obj.data.vertices])
    x0, y0, x1, y1 = co[:, 0].min(), co[:, 1].min(), co[:, 0].max(), co[:, 1].max()
    if opt("--tree"):
        x0, y0, x1, y1 = -bed_w / 2, -bed_d / 2, bed_w / 2, bed_d / 2          # a tree's line of light runs round its bed
    if opt("--bed"):
        x0, y0, x1, y1 = (float(v) for v in (*kit_box[0][:2], *kit_box[1][:2]))  # a bed's round its kerb, not round the plants that hang over it
    dx, dy = (x1 - x0) * inset, (y1 - y0) * inset
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x0 + x1) / 2, (y0 + y1) / 2, (z_lo + z_hi) / 2))
    slab = bpy.context.view_layer.objects.active
    slab.scale = (x1 - x0 - 2 * dx, y1 - y0 - 2 * dy, z_hi - z_lo)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    slab.name = opt("--under-glow-as", "lights")
    sm = bpy.data.materials.new(opt("--under-glow-material", "lamp_glow"))
    sm.use_nodes = True
    sb = sm.node_tree.nodes["Principled BSDF"]
    sb.inputs["Base Color"].default_value = (1.0, 0.552, 0.162, 1.0)
    sb.inputs["Emission Color"].default_value = (1.0, 0.552, 0.162, 1.0)
    sb.inputs["Emission Strength"].default_value = 1.0
    slab.data.materials.append(sm)
    slab.parent = root
    carried.append(slab.name)
    report["under_glow"] = [round(float(v), 3) for v in (x1 - x0 - 2 * dx, y1 - y0 - 2 * dy, z_lo, z_hi)]
    report["tris"] += 12
if opt("--band-glow"):
    # A strip of light round a rim: the generator paints a design's lit strip as plain rim, or not at all.
    asked = [float(v) for v in opt("--band-glow").split(",")]
    z_lo, z_hi, proud = asked[0], asked[1], (asked[2] if len(asked) > 2 else 0.003)
    co = np.array([v.co[:] for v in lo_obj.data.vertices])
    there = co[(co[:, 2] >= z_lo - 0.01) & (co[:, 2] <= z_hi + 0.01)][:, :2]
    if len(there) >= 3:
        pts2 = sorted({(round(float(x), 5), round(float(y), 5)) for x, y in there})

        def half(points):                                  # one chain of the convex outline
            chain = []
            for q in points:
                while len(chain) >= 2 and ((chain[-1][0] - chain[-2][0]) * (q[1] - chain[-2][1]) - (chain[-1][1] - chain[-2][1]) * (q[0] - chain[-2][0])) <= 0:
                    chain.pop()
                chain.append(q)
            return chain[:-1]
        outline = np.array(half(pts2) + half(pts2[::-1]))          # counter-clockwise
        middle = outline.mean(axis=0)
        away = outline - middle
        outline = middle + away * (1 + proud / np.maximum(np.linalg.norm(away, axis=1), 1e-9))[:, None]
        bmg = bmesh.new()
        low = [bmg.verts.new((float(x), float(y), z_lo)) for x, y in outline]
        high = [bmg.verts.new((float(x), float(y), z_hi)) for x, y in outline]
        for i in range(len(outline)):
            j = (i + 1) % len(outline)
            bmg.faces.new((low[i], low[j], high[j], high[i]))          # looks outwards
        band_mesh = bpy.data.meshes.new(opt("--band-glow-as", "lights"))
        bmg.to_mesh(band_mesh)
        bmg.free()
        band = bpy.data.objects.new(opt("--band-glow-as", "lights"), band_mesh)
        bpy.context.scene.collection.objects.link(band)
        gm = bpy.data.materials.new(opt("--band-glow-material", "lamp_glow"))
        gm.use_nodes = True
        gb = gm.node_tree.nodes["Principled BSDF"]
        gb.inputs["Base Color"].default_value = (1.0, 0.552, 0.162, 1.0)
        gb.inputs["Emission Color"].default_value = (1.0, 0.552, 0.162, 1.0)
        gb.inputs["Emission Strength"].default_value = 1.0
        band_mesh.materials.append(gm)
        band.parent = root
        carried.append(band.name)
        report["band_glow"] = {"from_m": z_lo, "to_m": z_hi, "proud_m": proud, "sides": int(len(outline)), "part": band.name, "material": gm.name}
        report["tris"] += 2 * len(outline)
if "--glow-light" in argv and glow_at is not None and "light" not in carried:
    bpy.ops.mesh.primitive_cube_add(size=0.012, location=tuple(float(v) for v in glow_at))
    lamp = bpy.context.view_layer.objects.active
    lamp.name = "light"
    lm = bpy.data.materials.new("lamp_glow")
    lm.use_nodes = True
    lm.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1.0, 0.552, 0.162, 1.0)
    lm.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.0
    lamp.data.materials.append(lm)
    lamp.parent = root
    report["light_at"] = [round(float(v), 3) for v in glow_at]
if opt("--leaf-round") and "is_leaf" in lo_obj.data.attributes:
    # A crown shaded by its facets is a scatter of light and dark patches, and a style with a hard step
    # between light and shadow (the anime pack's) turns it into noise. The leaf masses' normals are turned
    # part of the way towards the direction out from the middle of the crown, so that the crown takes the
    # light as one rounded form: lit on top and towards the sun, shaded underneath. Done last, since the
    # bakes cast their rays along the surface's own normals.
    blend = float(opt("--leaf-round"))
    lift = float(opt("--leaf-lift", "0"))
    me = lo_obj.data
    leafy = [item.value == 1 for item in me.attributes["is_leaf"].data]
    co = np.array([v.co[:] for v in me.vertices])
    leaf_verts = sorted({vi for poly in me.polygons if leafy[poly.index] for vi in poly.vertices})
    lv = co[leaf_verts]
    middle = np.array([(lv[:, 0].min() + lv[:, 0].max()) / 2, (lv[:, 1].min() + lv[:, 1].max()) / 2, lv[:, 2].min() + 0.35 * (lv[:, 2].max() - lv[:, 2].min())])
    normals = np.array([cn.vector[:] for cn in me.corner_normals])
    for poly in me.polygons:
        if not leafy[poly.index]:
            continue
        for li in poly.loop_indices:
            away = co[me.loops[li].vertex_index] - middle
            away /= max(float(np.linalg.norm(away)), 1e-9)
            away[2] += lift
            away /= max(float(np.linalg.norm(away)), 1e-9)
            n = (1 - blend) * normals[li] + blend * away
            normals[li] = n / max(float(np.linalg.norm(n)), 1e-9)
    me.normals_split_custom_set([tuple(float(v) for v in n) for n in normals])
    report["leaf_normals_rounded"] = blend
    report["leaf_normals_lifted"] = lift
if opt("--planted"):
    # What the game measures of a planted piece is its trunk: the farthest point from the origin, between 0.15
    # and 2.2 m up, of everything not on a leaf-named material (the vertices in that band and the points where
    # edges cross its two heights). It scales every copy's width by 0.25 m over that reach. So below 2.6 m the
    # trunk stands upright over the origin (set so before the cut), its foot is made to reach exactly
    # `reach_m`, and wood that stands further out than that (a low fork, a root) is drawn in. Done after the
    # bakes: they read the generated model, and the trunk has to lie on it while they do.
    reach_m = float(opt("--reach", "0.25"))
    me = lo_obj.data
    leafy = np.array([item.value == 1 for item in me.attributes["is_leaf"].data]) if "is_leaf" in me.attributes else np.zeros(len(me.polygons), bool)
    is_wood = np.zeros(len(me.vertices), bool)
    for poly in me.polygons:
        if not leafy[poly.index]:
            is_wood[list(poly.vertices)] = True
    wood_edges = sorted({tuple(sorted((a_i, b_i))) for poly in me.polygons if not leafy[poly.index]
                         for a_i, b_i in zip(list(poly.vertices), list(poly.vertices)[1:] + list(poly.vertices)[:1])})
    co = np.array([v.co[:] for v in me.vertices])

    def trunk_reach(z_from=0.15, z_to=2.2):
        """The game's measure (KitTown.band_reach) of the faces not marked as leaf: the farthest from the axis of
        their vertices between the two heights and of the points where their edges cross either height."""
        far = 0.0
        for a_i, b_i in wood_edges:
            a, b = co[a_i], co[b_i]
            for q in (a, b):
                if z_from <= q[2] <= z_to:
                    far = max(far, float(np.hypot(q[0], q[1])))
            for level in (z_from, z_to):
                if (a[2] - level) * (b[2] - level) < 0:
                    f = (level - a[2]) / (b[2] - a[2])
                    far = max(far, float(np.hypot(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)))
        return far

    # Above the foot: the stem is made slimmer evenly, about its axis, until none of it is further out than
    # just inside the reach between 0.3 m and the top of the band; the slimming runs out over the 0.8 m above
    # the band, so the limbs keep their spread. (A stem clamped to a cylinder instead came out as a post.)
    r = np.hypot(co[:, 0], co[:, 1])
    inside = reach_m * 0.985
    in_band = is_wood & (co[:, 2] > 0.3) & (co[:, 2] <= 2.2)
    widest = float(r[in_band].max()) if in_band.any() else inside
    slim = min(1.0, inside / max(widest, 1e-6))
    ks = np.where(co[:, 2] <= 2.2, slim, np.where(co[:, 2] <= 3.0, slim + (1 - slim) * (co[:, 2] - 2.2) / 0.8, 1.0))
    ks = np.where(is_wood, ks, 1.0)
    co[:, 0] *= ks
    co[:, 1] *= ks
    drawn_in = 0
    # An edge that crosses the top of the band on its way out to a limb is measured where it crosses: its
    # upper end is drawn towards the axis until the crossing is inside the reach.
    for _ in range(12):
        again = 0
        for a_i, b_i in wood_edges:
            lo_i, hi_i = (a_i, b_i) if co[a_i][2] < co[b_i][2] else (b_i, a_i)
            if co[lo_i][2] < 2.2 < co[hi_i][2]:
                f = (2.2 - co[lo_i][2]) / (co[hi_i][2] - co[lo_i][2])
                if np.hypot(*(co[lo_i][:2] + (co[hi_i][:2] - co[lo_i][:2]) * f)) > inside:
                    co[hi_i][:2] *= 0.85
                    again += 1
        drawn_in += again
        if not again:
            break
    # The foot: up to 0.3 m the trunk's own outline is scaled, and from there to 0.7 m the scale runs out to
    # none, until the game's measure of the foot (which starts at 0.15 m: the widest ring of a flared foot can
    # lie under that) is the reach wanted.
    k_foot = 1.0
    for _ in range(10):
        found = trunk_reach(0.15, 0.7)
        if abs(found - reach_m) < 0.0005 or found < 1e-6:
            break
        again = reach_m / found
        kk = np.where(co[:, 2] <= 0.3, again, np.where(co[:, 2] <= 0.7, again + (1 - again) * (co[:, 2] - 0.3) / 0.4, 1.0))
        kk = np.where(is_wood, kk, 1.0)
        co[:, 0] *= kk
        co[:, 1] *= kk
        k_foot *= again
    me.vertices.foreach_set("co", co.ravel())
    me.update()
    report["planted"].update({"foot_scaled": round(float(k_foot), 3), "stem_slimmed": round(float(slim), 3), "wood_drawn_in": drawn_in,
                              "trunk_reach_m": round(trunk_reach(), 4), "reach_wanted_m": reach_m})
    report["planted"]["width_scale_in_game"] = round(0.25 / max(report["planted"]["trunk_reach_m"], 1e-6), 3)

if opt("--planted"):
    # One mesh, two materials on the same textures: the game tells a planted piece's trunk from its leaves by
    # the material's name alone, and draws only the file's first mesh.
    mat.name = opt("--wood-material", "trunk")
    leaf_mat = mat.copy()
    leaf_mat.name = opt("--leaf-material", "leaf")
    lo_obj.data.materials.append(leaf_mat)
    if "is_leaf" in lo_obj.data.attributes:
        marks = [item.value == 1 for item in lo_obj.data.attributes["is_leaf"].data]
        for poly in lo_obj.data.polygons:
            poly.material_index = 1 if marks[poly.index] else 0
    if opt("--planted-leaf-from"):
        import bmesh
        floor_m = float(opt("--planted-leaf-from"))
        bm = bmesh.new()
        bm.from_mesh(lo_obj.data)
        low = [f for f in bm.faces if f.material_index == 1 and max(v.co.z for v in f.verts) < floor_m]
        bmesh.ops.delete(bm, geom=low, context="FACES")
        bm.to_mesh(lo_obj.data)
        bm.free()
        lo_obj.data.update()
        report["planted"]["leaf_faces_taken_out_below"] = {"m": floor_m, "faces": len(low)}
    report["planted"]["materials"] = [m.name for m in lo_obj.data.materials]
    report["planted"]["leaf_triangles"] = int(sum(len(p.vertices) - 2 for p in lo_obj.data.polygons if p.material_index == 1))
post_mesh = None
if "--panel" in argv:
    # The panel's own post, read off the cut-down piece: the foot that stands on the ground at -x, and the
    # shaft above it (where a level between the rails cuts the piece, left of the foot's inner edge).
    co = np.array([v.co[:] for v in lo_obj.data.vertices])
    end0, end1 = float(co[:, 0].min()), float(co[:, 0].max())
    span_x = end1 - end0
    hang = float(co[np.abs(co[:, 0] - (end0 + end1) / 2) < 0.3 * span_x][:, 2].min())
    foot = co[(co[:, 2] < 0.5 * hang) & (co[:, 0] < (end0 + end1) / 2)]
    landmarks = None
    if hang <= 0.02:
        # The panel stands on the ground all along (a low wall under its rails): its post is where the piece is
        # filled, unbroken, from the ground to seven tenths of its height or more. Read off the cut-down
        # piece's triangles, in slices of a 400th of its length over the -x third.
        lo_obj.data.calc_loop_triangles()
        reach, steps = end0 + 0.3 * span_x, 120
        spans = [[] for _ in range(steps)]
        for lt in lo_obj.data.loop_triangles:
            tri = co[list(lt.vertices)]
            if tri[:, 0].min() > reach:
                continue
            first = max(int((tri[:, 0].min() - end0) / (reach - end0) * steps), 0)
            last = min(int((tri[:, 0].max() - end0) / (reach - end0) * steps), steps - 1)
            for i in range(first, last + 1):
                a_x, b_x = end0 + (reach - end0) * i / steps, end0 + (reach - end0) * (i + 1) / steps
                zs = [q[2] for q in tri if a_x <= q[0] <= b_x]
                for k in range(3):
                    p_, q_ = tri[k], tri[(k + 1) % 3]
                    for plane in (a_x, b_x):
                        if (p_[0] - plane) * (q_[0] - plane) < 0:
                            zs.append(p_[2] + (q_[2] - p_[2]) * (plane - p_[0]) / (q_[0] - p_[0]))
                if zs:
                    spans[i].append((min(zs), max(zs)))
        height = float(co[:, 2].max())
        posted = []
        for i, found in enumerate(spans):
            top = 0.0
            if found and min(lo_z for lo_z, _ in found) < 0.05:
                top = 0.05
                for lo_z, hi_z in sorted(found):
                    if lo_z > top + 0.005:
                        break
                    top = max(top, hi_z)
            posted.append(top >= 0.7 * height)
        if any(posted):
            first = posted.index(True)
            last = first
            while last + 1 < steps and posted[last + 1]:
                last += 1
            landmarks = {"foot_inner": None, "level": None, "last_baluster": None,
                         "shaft": [end0 + (reach - end0) * first / steps, end0 + (reach - end0) * (last + 1) / steps]}
    elif len(foot) >= 3:
        foot_inner = float(foot[:, 0].max())
        # The level: the middle of the widest gap between the rails, read off the piece's +x end, where only
        # the rails' ends are.
        ends_z = np.unique(np.round(co[co[:, 0] > end1 - 0.004][:, 2], 3))
        if len(ends_z) >= 2:
            gaps = np.diff(ends_z)
            level = float(ends_z[np.argmax(gaps)] + gaps.max() / 2)
        else:
            level = float(co[:, 2].max()) / 2
        ed = np.array([e.vertices[:] for e in lo_obj.data.edges])
        a, b = co[ed[:, 0]], co[ed[:, 1]]
        den = b[:, 2] - a[:, 2]
        with np.errstate(divide="ignore", invalid="ignore"):
            f = (level - a[:, 2]) / den
        crossing = (den != 0) & (f > 0) & (f < 1)
        cut_x = (a[crossing] + (b[crossing] - a[crossing]) * f[crossing][:, None])[:, 0]
        shaft = cut_x[cut_x <= foot_inner + 1e-4]
        beyond = cut_x[cut_x > foot_inner + 1e-4]
        if len(shaft) >= 2:
            landmarks = {"foot_inner": foot_inner, "level": level, "shaft": [float(shaft.min()), float(shaft.max())],
                         "last_baluster": float(beyond.max()) if len(beyond) else None}
    report["panel"]["post_m"] = None if landmarks is None else {k: (v if v is None else [round(q, 4) for q in v] if isinstance(v, list) else round(v, 4)) for k, v in landmarks.items()}
    if opt("--panel-post") and landmarks is not None:
        # The post alone: the outer half of the panel's post (no rail reaches it) and its mirror image, so the
        # post the game stands at a fence's ends, unturned, is the same on both sides along the run and
        # carries no rail. It keeps the panel's texture, so it is the same iron.
        middle = (end0 + landmarks["foot_inner"]) / 2 if landmarks["foot_inner"] is not None else sum(landmarks["shaft"]) / 2
        bmq = bmesh.new()
        bmq.from_mesh(lo_obj.data)
        bmesh.ops.bisect_plane(bmq, geom=list(bmq.verts) + list(bmq.edges) + list(bmq.faces), dist=1e-7,
                               plane_co=(middle, 0.0, 0.0), plane_no=(1.0, 0.0, 0.0), clear_outer=True, clear_inner=False)
        twin = bmesh.ops.duplicate(bmq, geom=list(bmq.verts) + list(bmq.edges) + list(bmq.faces))["geom"]
        for v in (g for g in twin if isinstance(g, bmesh.types.BMVert)):
            v.co.x = 2 * middle - v.co.x
        bmesh.ops.reverse_faces(bmq, faces=[g for g in twin if isinstance(g, bmesh.types.BMFace)])
        bmesh.ops.remove_doubles(bmq, verts=[v for v in bmq.verts if abs(v.co.x - middle) < 1e-5], dist=1e-5)
        for v in bmq.verts:
            v.co.x -= middle
        post_mesh = bpy.data.meshes.new("post")
        bmq.to_mesh(post_mesh)
        bmq.free()
        post_mesh.materials.append(mat)
        pc = np.array([v.co[:] for v in post_mesh.vertices])
        report["panel"]["post"] = {"tris": int(sum(len(p.vertices) - 2 for p in post_mesh.polygons)),
                                   "box_min": [round(float(v), 4) for v in pc.min(axis=0)], "box_max": [round(float(v), 4) for v in pc.max(axis=0)],
                                   "shaft_off_the_foot_middle_m": round((landmarks["shaft"][0] + landmarks["shaft"][1]) / 2 - middle, 4)}
    if landmarks is not None and "--panel-no-stubs" not in argv:
        # The rails through the post: the next panel's rails end on this panel's -x end, and this panel's own
        # rails begin at the far side of its post's shaft. Where the post's foot or cap is wider than the
        # shaft, the shaft's outer face stands in from that end, and a gap would show between rail and post
        # at every joint. A short length of the rails' own +x end, turned end for end, is set there: from
        # the piece's -x end to a little way into the shaft. (The kits' rails run through their posts.)
        overhang = landmarks["shaft"][0] - end0
        reach_in = min(0.3 * (landmarks["shaft"][1] - landmarks["shaft"][0]), 0.03)
        stub = overhang + reach_in
        if landmarks["last_baluster"] is not None:
            stub = min(stub, 0.9 * (end1 - landmarks["last_baluster"]))
        if overhang > 0.004 and stub > overhang:
            # Each rail's end is found on the +x end (the faces that lie in that plane, joined), and its outline
            # there is taken plain: the box round it where it is a bar (it fills nine tenths of that box), else
            # its outline cut to eight corners. The stub is that outline drawn out from the -x end, closed on
            # the outside, in the colour of the rail's end.
            bms = bmesh.new()
            bms.from_mesh(lo_obj.data)
            uv_s = bms.loops.layers.uv.active
            ends_in_order = [f for f in bms.faces if all(v.co.x > end1 - 1e-4 for v in f.verts)]
            on_end = set(ends_in_order)
            groups, taken = [], set()
            for f in ends_in_order:
                if f in taken:
                    continue
                stack, group = [f], []
                taken.add(f)
                while stack:
                    g = stack.pop()
                    group.append(g)
                    for v in g.verts:
                        for h in v.link_faces:
                            if h in on_end and h not in taken:
                                taken.add(h)
                                stack.append(h)
                groups.append(group)
            added, outlines = 0, []
            for group in groups:
                yz = np.array(sorted({(round(v.co.y, 6), round(v.co.z, 6)) for f in group for v in f.verts}))
                if len(yz) < 3:
                    continue
                lower, upper = [], []                                    # the outline round the end: a convex hull
                def turn_of(a, b, c):
                    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
                for q in yz:
                    while len(lower) >= 2 and turn_of(lower[-2], lower[-1], q) <= 0:
                        lower.pop()
                    lower.append(q)
                for q in yz[::-1]:
                    while len(upper) >= 2 and turn_of(upper[-2], upper[-1], q) <= 0:
                        upper.pop()
                    upper.append(q)
                hull = np.array(lower[:-1] + upper[:-1])
                def area_of(poly):
                    return 0.5 * abs(float(np.sum(poly[:, 0] * np.roll(poly[:, 1], -1) - np.roll(poly[:, 0], -1) * poly[:, 1])))
                y0, z0b, y1, z1b = hull[:, 0].min(), hull[:, 1].min(), hull[:, 0].max(), hull[:, 1].max()
                if area_of(hull) < 1.5e-4 or min(y1 - y0, z1b - z0b) < 0.008:
                    continue                                             # a sliver on the end plane, not a rail's end
                if area_of(hull) >= 0.9 * (y1 - y0) * (z1b - z0b):
                    outline = np.array([[y0, z0b], [y1, z0b], [y1, z1b], [y0, z1b]])
                else:
                    outline = hull
                    while len(outline) > 8:                              # the corner that holds least goes
                        loss = [area_of(np.array([outline[i - 1], outline[i], outline[(i + 1) % len(outline)]])) for i in range(len(outline))]
                        outline = np.delete(outline, int(np.argmin(loss)), axis=0)
                largest = max(group, key=lambda f: f.calc_area())
                at = np.mean([loop[uv_s].uv[:] for loop in largest.loops], axis=0)
                middle_yz = outline.mean(axis=0)
                half = np.maximum((outline.max(axis=0) - outline.min(axis=0)) / 2, 1e-6)
                def uv_of(q, inner):
                    # all of the stub reads the rail end's colour, from a patch of the texture less than a texel
                    # across there (not from one point: a face without area in the texture has no tangent)
                    return (at[0] + 0.4 / tex * (q[0] - middle_yz[0]) / half[0] + (0.2 / tex if inner else 0.0),
                            at[1] + 0.4 / tex * (q[1] - middle_yz[1]) / half[1] + (0.2 / tex if inner else 0.0))
                # 2 mm inside the piece's end: where the post's foot or cap reaches that end, the stub's end
                # would lie in the same plane as its face and flicker through it
                outer = [bms.verts.new((end0 + 0.002, float(q[0]), float(q[1]))) for q in outline]
                inner = [bms.verts.new((end0 + stub, float(q[0]), float(q[1]))) for q in outline]
                made = []
                k = len(outline)
                for i in range(k):
                    j = (i + 1) % k
                    face = bms.faces.new((outer[j], outer[i], inner[i], inner[j]))      # counter-clockwise seen from outside
                    for loop, (q, far) in zip(face.loops, ((outline[j], False), (outline[i], False), (outline[i], True), (outline[j], True))):
                        loop[uv_s].uv = uv_of(q, far)
                    made.append(face)
                cap = bms.faces.new(outer)                                              # the end, looking out along -x
                for loop, q in zip(cap.loops, outline):
                    loop[uv_s].uv = uv_of(q, False)
                caps_made = [cap]
                if len(outline) > 4:
                    # in triangles: the exporter gives a mesh no tangents at all once one face has five corners
                    caps_made = bmesh.ops.triangulate(bms, faces=[cap])["faces"]
                made += caps_made
                for face in made:
                    face.smooth = False
                    face.normal_update()
                    c = face.calc_center_median()
                    outward = Vector((-1.0, 0.0, 0.0)) if face in caps_made else Vector((0.0, c.y - middle_yz[0], c.z - middle_yz[1]))
                    if face.normal.dot(outward) < 0:
                        face.normal_flip()
                added += sum(len(face.verts) - 2 for face in made)
                outlines.append(len(outline))
            bms.to_mesh(lo_obj.data)
            bms.free()
            lo_obj.data.update()
            report["panel"]["stubs"] = {"length_m": round(stub, 4), "shaft_stands_in_m": round(overhang, 4), "rails": len(outlines), "corners": outlines, "triangles": added}
            report["tris"] += added
        else:
            report["panel"]["stubs"] = None
if "--weighted-normals" in argv and "--flat" not in argv:
    for o in [lo_obj] + ([glow_part] if glow_part is not None else []):
        weighted_normals(o)           # again, now that the piece has its last faces
if opt("--square-normals"):
    # A piece built of flat panes and square members (a shelter) comes out of the reduction with its panes a
    # millimetre or two off flat, and shaded smooth every pane shows its triangles. The faces that look within
    # this many degrees of an axis are given that axis as their normal: the panes shade flat, the members' faces
    # crisp, and a style that inks where normals turn inks the real edges. Done last, like --leaf-round.
    limit = math.cos(math.radians(float(opt("--square-normals"))))
    me = lo_obj.data
    normals = np.array([cn.vector[:] for cn in me.corner_normals])
    squared = 0
    for poly in me.polygons:
        n = np.array(poly.normal)
        axis = int(np.argmax(np.abs(n)))
        if abs(n[axis]) >= limit:
            to = np.zeros(3)
            to[axis] = 1.0 if n[axis] > 0 else -1.0
            for li in poly.loop_indices:
                normals[li] = to
            squared += 1
    me.normals_split_custom_set([tuple(float(v) for v in n) for n in normals])
    report["faces_with_square_normals"] = round(squared / max(len(me.polygons), 1), 3)
if "--no-normal" not in argv:
    # A face of five corners or more costs its mesh every tangent in the written file, and the kits' validator
    # then warns that the engine will make a tangent space of its own (a planter's soil and bottom, drawn as one
    # many-sided face each, did that). Such faces are cut into triangles first; what the steps above set at their
    # corners is kept.
    import bmesh
    many_sided = 0
    for o in [ob for ob in bpy.data.objects if ob.type == "MESH"]:
        if not any(len(poly.vertices) > 4 for poly in o.data.polygons):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        many = [f for f in bm.faces if len(f.verts) > 4]
        bmesh.ops.triangulate(bm, faces=many)
        bm.to_mesh(o.data)
        bm.free()
        o.data.update()
        many_sided += len(many)
    if many_sided:
        report["many_sided_faces_cut_into_triangles"] = many_sided
if want_reach is not None:
    report["shrub"]["reach_of_the_piece_m"] = round(band_reach([o for o in bpy.data.objects if o.type == "MESH"]), 4)
if opt("--bed"):
    in_band = band_from_above([o for o in bpy.data.objects if o.type == "MESH"])
    report["bed"]["band_box"] = [round(float(v), 3) for v in (*in_band.min(axis=0), *in_band.max(axis=0))]
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
# Tangents go in the file: the kit pieces' import settings do not make them, and a normal map needs them.
image_format = opt("--image-format", "AUTO")
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True, export_apply=True, export_image_format=image_format,
                          export_image_quality=int(opt("--image-quality", "90")), export_tangents="--no-normal" not in argv)
if "--mend-tangents" in argv and "--no-normal" not in argv:
    report["tangents_mended"] = mend_tangents(out)
report["image_format"] = image_format
report["bytes"] = out.stat().st_size
report["name"] = name
if opt("--far") and opt("--planted"):
    # The far twin: the same piece, cut down hard, its textures a quarter the size.
    far_tris = int(opt("--far"))
    only(lo_obj)
    for _ in range(3):
        now = tri_count(lo_obj)
        if now <= far_tris:
            break
        mod = lo_obj.modifiers.new("far", "DECIMATE")
        mod.ratio = 0.97 * far_tris / now
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for m in lo_obj.data.materials:
        for node in m.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None and node.image.size[0] > max(64, tex // 4):
                node.image.scale(max(64, tex // 4), max(64, tex // 4))
    root.name = name + "_far"
    far_out = out.with_name(out.stem + "_far.glb")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(far_out), export_format="GLB", export_yup=True, export_apply=True, export_image_format=image_format,
                              export_image_quality=int(opt("--image-quality", "90")), export_tangents=False)
    report["far"] = {"file": far_out.name, "tris": tri_count(lo_obj), "bytes": far_out.stat().st_size}
if post_mesh is not None:
    post_path = Path(opt("--panel-post"))
    part = lo_obj.name
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for old_mesh in list(bpy.data.meshes):
        if old_mesh is not post_mesh and old_mesh.users == 0:
            bpy.data.meshes.remove(old_mesh)                      # the panel's mesh: its name is wanted for the post's
    post_root = bpy.data.objects.new(post_path.stem, None)
    post_body = bpy.data.objects.new(part, post_mesh)
    post_mesh.name = part
    for o in (post_root, post_body):
        bpy.context.scene.collection.objects.link(o)
    post_body.parent = post_root
    # The game stands this post on a fence's end points, unturned: it is centred across as well (the panel is
    # centred on all it draws where people walk, and what it draws deepest need not be its post: a planter is
    # deeper than the post beside it), and it stands on the ground.
    post_points = band_points(post_body)
    post_shift = Vector((0.0, -float(post_points[:, 1].min() + post_points[:, 1].max()) / 2, -min(v.co.z for v in post_mesh.vertices)))
    post_mesh.transform(Matrix.Translation(post_shift))
    post_mesh.update()
    report["panel"]["post"]["moved_across_and_down_m"] = [round(post_shift.y, 4), round(post_shift.z, 4)]
    if opt("--panel-post-tris") and tri_count(post_body) > int(opt("--panel-post-tris")):
        only(post_body)
        dm = post_body.modifiers.new("cut", "DECIMATE")
        dm.ratio = int(opt("--panel-post-tris")) / tri_count(post_body)
        dm.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=dm.name)
        report["panel"]["post"]["tris_before_its_own_cut"] = report["panel"]["post"]["tris"]
        report["panel"]["post"]["tris"] = tri_count(post_body)
    if "--flat" not in argv:
        # The mirrored half's normals were the panel's, written for the other side, and a cut of its own does
        # not keep which edges are sharp: both are made again on the post as it now is.
        only(post_body)
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
        post_mesh.set_sharp_from_angle(angle=math.radians(40))
    if "--weighted-normals" in argv and "--flat" not in argv:
        weighted_normals(post_body)
    post_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(post_path), export_format="GLB", export_yup=True, export_apply=True, export_image_format=image_format,
                              export_image_quality=int(opt("--image-quality", "90")), export_tangents="--no-normal" not in argv)
    if "--mend-tangents" in argv and "--no-normal" not in argv:
        report["panel"]["post"]["tangents_mended"] = mend_tangents(post_path)
    report["panel"]["post"]["bytes"] = post_path.stat().st_size
    report["panel"]["post"]["file"] = post_path.name
print("FIT " + json.dumps(report))
if opt("--report"):
    Path(opt("--report")).write_text(json.dumps(report, indent=1) + "\n")
