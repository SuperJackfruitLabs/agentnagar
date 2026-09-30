## One drawn solid, as the collision audit sees it: what a style draws for
## one thing, cut to the walking band and seen from above, and whose it is.
##
## The shape is kept in the frame it was measured in (a kit piece's own,
## shared by every copy of it, or the world's) with the transform to the
## world, so a thousand palms share one measurement:
## - `pieces` are the exact band slices: each triangle's part between the
##   band's heights, flattened (a convex polygon, or a segment where the
##   face is vertical), and for a sprite its model's footprint shapes;
## - `contours` are the outlines of what the pieces enclose (a wall's two
##   faces and its ends enclose the wall), traced on a raster `pixel` wide,
##   so they reach up to a pixel past the pieces.
## Distances come from the pieces, which are exact; the contours only say
## what lies inside.
extends RefCounted

## Whose solid this is: {kind, placement_id} for a placement or seat,
## {kind: "building", building, mesh} for a building's shell, {kind:
## "scenery:<kind>", mesh} for scenery, {kind: "untagged", mesh}.
var owner := {}
var contours: Array[PackedVector2Array] = []
var pieces: Array[PackedVector2Array] = []
## Discs among the pieces: (x, z, radius).
var discs := PackedVector3Array()
var to_world := Transform2D.IDENTITY
var to_local := Transform2D.IDENTITY
## World metres per unit of the local frame.
var scale := 1.0
## The raster's pixel, in local units.
var pixel := 0.01
## The world rectangle the shape lies in.
var bounds := Rect2()


## Distance, in metres, from world point `p` to the solid: zero or less
## when `p` is on or inside it (minus how far the outside is), more than
## zero outside it, and INF when farther than `reach`.
func probe(p: Vector2, reach: float) -> float:
	var q := to_local * p
	var inside := false
	var to_contour := INF
	for c in contours:
		if Geometry2D.is_point_in_polygon(q, c):
			inside = true
		to_contour = minf(to_contour, _edge_distance(q, c))
	for disc in discs:
		var off := q.distance_to(Vector2(disc.x, disc.y)) - disc.z
		if off < 0.0:
			inside = true
		to_contour = minf(to_contour, absf(off))
	# Well inside the traced outline, or well clear of it: the outline is
	# within a pixel and a half of the pieces, so it decides alone.
	var loose := pixel * 2.0
	if inside and to_contour > loose:
		return -to_contour * scale
	if not inside and to_contour > reach / scale + loose:
		return INF
	var gap := _gap(q)
	if gap <= TOUCH / scale:
		return -to_contour * scale if inside else 0.0
	# Inside the outline but near a piece: the strip the tracing adds
	# outside the pieces is under a pixel and a half wide, so a point
	# farther in than that from the outline is between pieces (enclosed).
	if inside and to_contour > pixel * 1.5:
		return -to_contour * scale
	return gap * scale


## Pieces this close (metres) count as touched: the point is on the solid.
const TOUCH := 0.01


func _gap(q: Vector2) -> float:
	var best := INF
	for piece in pieces:
		var d := 0.0
		match piece.size():
			1:
				d = q.distance_to(piece[0])
			2:
				d = q.distance_to(Geometry2D.get_closest_point_to_segment(q, piece[0], piece[1]))
			_:
				if Geometry2D.is_point_in_polygon(q, piece):
					return 0.0
				d = _edge_distance(q, piece)
		best = minf(best, d)
	for disc in discs:
		best = minf(best, maxf(0.0, q.distance_to(Vector2(disc.x, disc.y)) - disc.z))
		if best == 0.0:
			return 0.0
	return best


static func _edge_distance(q: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	var n := poly.size()
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		best = minf(best, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return best


## Places the solid in the world with `xform` (local to world, a turn,
## uniform scale and move on the ground plane), and bounds it.
func place(xform: Transform2D) -> void:
	to_world = xform
	to_local = xform.affine_inverse()
	scale = xform.x.length()
	var box := Rect2()
	var first := true
	for c in contours:
		for p in xform * c:
			box = Rect2(p, Vector2.ZERO) if first else box.expand(p)
			first = false
	for disc in discs:
		var c := xform * Vector2(disc.x, disc.y)
		var r := disc.z * scale
		var d := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		box = d if first else box.merge(d)
		first = false
	bounds = box


## The world points of the exact pieces (and each disc's extreme points on
## eight bearings), for measuring a kind's silhouette.
func world_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for piece in pieces:
		out.append_array(to_world * piece)
	for disc in discs:
		for k in 8:
			var a := TAU * k / 8.0
			# Out to the circumscribed octagon, so the disc's whole circle
			# lies inside what is measured.
			out.append(to_world * (Vector2(disc.x, disc.y) + Vector2(cos(a), sin(a)) * disc.z / cos(PI / 8.0)))
	return out
