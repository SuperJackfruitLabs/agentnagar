## The collision audit: where what a style draws and the core's walkable
## grid disagree (spec §1, success 1). It boots the client on the district
## fixture in one style, reads every solid the style draws in the walking
## band (tools/collision_audit/solids_3d.gd, solids_2d.gd), each named by
## the placement, seat, building or scenery it was drawn for, records a day
## (walk.gd), and counts:
## - `through`: walkable cells whose centre lies in a drawn solid;
## - `within_10cm`: walkable cells whose centre a solid comes within 10 cm
##   of (the body clearance), through cells included;
## - `walker_pass`: walkers' cell visits over the day that are through
##   cells, steps onto and off one's own seat left out;
## - `player_pass`: the same for the player walked along every street and
##   into every building;
## - `tram_overlap`: walkers ending a tick inside a drawn tram but outside
##   the core's tram footprint;
## - `reverse_blocked`: cells inside a room that the grid blocks although
##   nothing solid is drawn within 10 cm of them, within 3 m of walkable
##   floor. Such ground outside every room is reported
##   (`reverse_outside_rooms`) but not gated (spec §10).
## A seat's own furniture is exempt from `through` and `within_10cm` at
## the cells whose centres lie within its protected square (a spec
## amendment): 25 cm either way of its point, in its own frame, where the
## sitter sits and turns and the seat's chair or seat stands whole. Any
## other furniture or solid counts there, and the seat's own counts
## everywhere else, so everything it draws outside the square fits its
## footprint. A perch (a placement whose kind has sit anchors: steps, a
## low wall, a fountain's rim) has the same square round each sit anchor:
## the anchors lie just outside its footprint, and a sitter's hips rest
## over one on the seat the perch reaches out to them.
## `reverse_blocked` reads every solid. Soft ground (a meadow) is walked
## through: what it draws inside its lot is no solid (solids_3d.gd).
## Geometry no tag names is counted as `untagged`. Occupants,
## trams (tram_overlap checks them) and anything below the band are not
## solids.
##
## Each count comes with its offenders, {kind, placement_id (a placement or
## seat) or building and mesh (a shell) or mesh (anything else), cell,
## depth_cm}: depth_cm is how far the solid reaches into the 10 cm
## clearance round the cell's centre (10 or more is through it).
##   var result = await CollisionAudit.run("voxel")
##   result["through"]["count"], result["through"]["offenders"]
extends RefCounted
class_name CollisionAudit

const Solids3D = preload("res://tools/collision_audit/solids_3d.gd")
const Solids2D = preload("res://tools/collision_audit/solids_2d.gd")
const Walk = preload("res://tools/collision_audit/walk.gd")

const STYLES := ["anime_cel", "solarpunk", "neon_noir", "lowpoly_tropical", "voxel", "pixel_art"]
const GATES := ["through", "within_10cm", "walker_pass", "player_pass", "tram_overlap", "reverse_blocked"]
## The walking band, metres above the ground stood on (spec §1).
const BAND := Vector2(0.25, 1.9)
## The body clearance, metres (spec §3).
const CLEARANCE := 0.10
## The reverse problem looks this far (cells, 3 m) from walkable floor.
const REACH_CELLS := 12
## The spike's day: 600 ticks at crowd 60, on seed 7. It is recorded once
## a run (see _days), so the test keeps it whole.
const DAY_TICKS := 600
const CROWD := 60
## Half the side of a seat's protected square, metres.
const SEAT_SQUARE := 0.25
## Own-seat steps: within this many ticks and cells of where one sat.
const SEAT_TICKS := 3
const SEAT_CELLS := 4
## The length a pack draws a tram whose line gives none (pack_3d.gd's
## make_vehicle), metres: the tram kind carries no length of its own.
const DEFAULT_TRAM_LENGTH_M := 20.5

## Recorded days by length. The core alone decides a day (every style's
## day has one checksum), so one recording serves every style in a run.
## Keyed by the day's length, the crowd and the layout, which decide it.
static var _days := {}

var main
var pack
var nav: NavQuery
var style := ""
## The layout's transit lines.
var lines: Array = []
## Placement or seat ID -> {kind, pos (metres), facing, size (metres, a
## sized kind's)}.
var placed := {}
var solids: Array = []
## Per cell: the nearest solid's distance (metres; 0 or less inside) and
## which solid, every solid read: what `reverse_blocked` reads.
var nearest := PackedFloat32Array()
var nearest_solid := PackedInt32Array()
## The same, leaving out a seat's own furniture within its protected
## square: what `through` and `within_10cm` read.
var nearest_gated := PackedFloat32Array()
var nearest_gated_solid := PackedInt32Array()
## Per cell: 1 when inside a room's rectangle.
var in_room := PackedByteArray()
## Per cell: 1 when within REACH_CELLS of walkable floor.
var near := PackedByteArray()
var _near_sum := PackedInt32Array()
## Per cell: 1 for a cell of the reverse problem (blocked, nothing drawn
## within the clearance, reached from the floor), once counted.
var _reached := PackedByteArray()
## Seat cell -> the seat's ID.
var seat_at := {}


## Audits `style`. Options: `ticks` (the day's length; 0 records none),
## `measure` (also measure every placement's silhouette in its kind's
## frame, as `kinds`), `overlay` (a PNG path for a picture of the grid).
## Returns {style, <gate>: {count, offenders}, info}.
static func run(style_: String, opts := {}) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var audit := CollisionAudit.new()
	audit.style = style_
	audit.main = load("res://main.gd").new()
	tree.root.add_child(audit.main)
	audit.main.boot_for_tool(PackedStringArray(["--crowd=%d" % CROWD, "--style=" + style_]))
	audit.main.driver.pause()
	for i in 10:
		await tree.process_frame
	audit.pack = audit.main.host.pack
	var result := {}
	if audit.pack == null or audit.main.host.pack_dir.get_file() != style_:
		push_error("collision audit: style %s did not activate (%s)" % [style_, audit.main.host.last_error])
		result = {"style": style_, "error": "the style did not activate"}
	else:
		result = await audit._audit(int(opts.get("ticks", DAY_TICKS)), bool(opts.get("measure", false)), tree)
		if opts.has("overlay"):
			audit._overlay(str(opts["overlay"]))
	audit.main.free()
	await tree.process_frame
	return result


func _audit(ticks: int, measure: bool, tree: SceneTree) -> Dictionary:
	nav = main.nav
	lines = main.manifest.get("lines", [])
	_places()
	_rooms()
	_near_floor()
	var wanted := func(r: Rect2) -> bool: return measure or _wanted(r)
	var reader = Solids3D.new() if pack is Pack3D else Solids2D.new()
	reader.kinds = {}
	for id in placed:
		reader.kinds[id] = placed[id]["kind"]
	reader.soft = soft_ground()
	if pack is Pack3D:
		reader.band = BAND
		reader.nav = nav
	solids = reader.collect(pack, wanted)
	_nearest()
	var result := {"style": style}
	result["through"] = _through()
	result["within_10cm"] = _within()
	var tram: Dictionary = reader.tram_half_width(pack) if pack is Pack3D else {"half_width": Solids2D.TRAM_HALF_WIDTH, "centre": 0.0}
	var info := {"walkable_cells": 0, "solids": solids.size(), "day_ticks": ticks, "tram_drawn_half_width_m": tram.get("half_width", 0.0),
		"unmeasured_sprites": reader.unmeasured if reader is Solids2D else {},
		"unplaced_multimeshes": reader.unplaced if pack is Pack3D else {}}
	for k in nav._room.size():
		if nav._room[k] >= 0:
			info["walkable_cells"] += 1
	var reverse := _reverse()
	result["reverse_blocked"] = reverse["gated"]
	info["reverse_outside_rooms"] = reverse["outside"]
	if ticks > 0:
		var day_key := "%d|%d|%d" % [ticks, CROWD, JSON.stringify(main.manifest).hash()]
		if not _days.has(day_key):
			_days[day_key] = await Walk.day(main, ticks, tree)
		var day: Dictionary = _days[day_key]
		var own := _own_seat_steps(day)
		result["walker_pass"] = _walker_pass(day, own)
		result["player_pass"] = _player_pass(day)
		result["tram_overlap"] = _tram_overlap(day, own, tram)
		info["own_seat_steps"] = own.size()
		info["player_waypoints"] = day["player"]["waypoints"].size()
	else:
		for gate in ["walker_pass", "player_pass", "tram_overlap"]:
			result[gate] = _gate([])
	result["info"] = info
	if measure:
		result["kinds"] = _measure()
	return result


# ---- The places ----

func _places() -> void:
	for p in CityGeometry.placements(main.manifest):
		add_placement(p["id"], p["kind"], p["pos"], p["facing"], p["size"])
	for d in main.manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				for s in r.get("seats", []):
					if s.get("pos") == null:
						continue
					var id := str(s["id"])
					var pos := CityGeometry.pt_m(s["pos"])
					add_seat(id, str(s.get("kind", "")), pos, float(s.get("facing", 0.0)))


## Records placement `id` of `kind` (a catalogue kind's ID) at `pos`
## (metres) facing `facing` (degrees clockwise from north), `size` its
## size when sized. A placement of a kind with sit anchors (the perches:
## steps, a low wall, a fountain's rim) keeps each sit anchor's place
## (metres) and facing (`sits`), where its protected squares are.
func add_placement(id: String, kind: String, pos: Vector2, facing: float, size := Vector2.ZERO) -> void:
	placed[id] = {"kind": kind, "pos": pos, "facing": facing, "size": size}
	var turn := Transform2D(deg_to_rad(facing), pos)
	var sits := []
	for a in StylePack.kinds().get(kind, {}).get("anchors", []):
		if a.get("type") == "sit":
			sits.append({"pos": turn * (Vector2(a["at"]["x"], a["at"]["z"]) / 100.0), "facing": facing + float(a.get("facing", 0))})
	if not sits.is_empty():
		placed[id]["sits"] = sits


## The district's soft ground: each placement of a kind with no footprint
## and soft shapes (a meadow) -> its lot, metres.
func soft_ground() -> Dictionary:
	var out := {}
	var kinds := StylePack.kinds()
	for p in CityGeometry.placements(main.manifest):
		var kind: Dictionary = kinds.get(p["kind"], {})
		if kind.get("footprint", []).is_empty() and not kind.get("soft", []).is_empty() and p["size"] != Vector2.ZERO:
			out[p["id"]] = CityGeometry.lot(p)
	return out


## Records seat `id` of `kind` at `pos` (metres) facing `facing` (degrees
## clockwise from north): its seat cell.
func add_seat(id: String, kind: String, pos: Vector2, facing: float) -> void:
	placed[id] = {"kind": kind, "pos": pos, "facing": facing, "size": Vector2.ZERO, "seat": true}
	seat_at[nav.cell_of(pos * 100.0)] = id


## Whether world point `p` (metres) lies within seat `seat`'s protected
## square (a `placed` entry), turned as its footprint turns. A hair is
## allowed on the edges, where a cell centre 25 cm off lies exactly.
static func in_seat_square(seat: Dictionary, p: Vector2) -> bool:
	var t := deg_to_rad(float(seat["facing"]))
	var d: Vector2 = p - seat["pos"]
	var local := Vector2(d.x * cos(t) + d.y * sin(t), -d.x * sin(t) + d.y * cos(t))
	return maxf(absf(local.x), absf(local.y)) <= SEAT_SQUARE + 1e-4


## Whether world point `p` (metres) lies within a protected square of
## `place` (a `placed` entry): a seat's own, or one round any sit anchor of
## a placement whose kind has them.
static func in_own_square(place: Dictionary, p: Vector2) -> bool:
	if place.get("seat", false):
		return in_seat_square(place, p)
	for sit in place.get("sits", []):
		if in_seat_square(sit, p):
			return true
	return false


func _index(c: Vector2i) -> int:
	return c.y * nav.cols + c.x


func _centre_m(c: Vector2i) -> Vector2:
	return nav.centre(c) / 100.0


## Cells whose centres a room's rectangle holds (minimum edges in, maximum
## out, as the core's rule 1).
func _rooms() -> void:
	in_room.resize(nav.cols * nav.rows)
	for d in main.manifest.get("city", {}).get("districts", []):
		for f in d.get("facilities", []):
			for r in f.get("rooms", []):
				if r.get("rect") == null:
					continue
				var rc: Dictionary = r["rect"]
				var i0 := ceili((float(rc["x"]) - nav.origin.x - NavQuery.CELL / 2) / NavQuery.CELL)
				var j0 := ceili((float(rc["z"]) - nav.origin.y - NavQuery.CELL / 2) / NavQuery.CELL)
				var i1 := ceili((float(rc["x"]) + float(rc["w"]) - nav.origin.x - NavQuery.CELL / 2) / NavQuery.CELL)
				var j1 := ceili((float(rc["z"]) + float(rc["d"]) - nav.origin.y - NavQuery.CELL / 2) / NavQuery.CELL)
				for j in range(maxi(0, j0), mini(nav.rows, j1)):
					for i in range(maxi(0, i0), mini(nav.cols, i1)):
						in_room[j * nav.cols + i] = 1


## Cells within REACH_CELLS steps of walkable floor, and a summed table of
## them, so a solid far from every such cell is never read.
func _near_floor() -> void:
	var n := nav.cols * nav.rows
	near.resize(n)
	var frontier := PackedInt32Array()
	for k in n:
		if nav._room[k] >= 0:
			near[k] = 1
			frontier.append(k)
	for step in REACH_CELLS:
		var next := PackedInt32Array()
		for k in frontier:
			var i := k % nav.cols
			var j := k / nav.cols
			for nb in [k - 1 if i > 0 else -1, k + 1 if i < nav.cols - 1 else -1, k - nav.cols if j > 0 else -1, k + nav.cols if j < nav.rows - 1 else -1]:
				if nb >= 0 and near[nb] == 0:
					near[nb] = 1
					next.append(nb)
		frontier = next
	var w := nav.cols + 1
	_near_sum.resize(w * (nav.rows + 1))
	for j in nav.rows:
		var row := 0
		for i in nav.cols:
			row += near[j * nav.cols + i]
			_near_sum[(j + 1) * w + i + 1] = _near_sum[j * w + i + 1] + row


## The cells whose centres lie within the clearance of world rectangle `r`
## (metres): [i0, j0, i1, j1], inclusive, clipped to the grid.
func _cells_of(r: Rect2) -> Array:
	var g := r.grow(CLEARANCE + 0.01)
	var a := nav.cell_of(g.position * 100.0)
	var b := nav.cell_of(g.end * 100.0)
	return [maxi(0, a.x), maxi(0, a.y), mini(nav.cols - 1, b.x), mini(nav.rows - 1, b.y)]


func _wanted(r: Rect2) -> bool:
	var c := _cells_of(r)
	if c[2] < c[0] or c[3] < c[1]:
		return false
	var w := nav.cols + 1
	return _near_sum[(c[3] + 1) * w + c[2] + 1] - _near_sum[c[1] * w + c[2] + 1] - _near_sum[(c[3] + 1) * w + c[0]] + _near_sum[c[1] * w + c[0]] > 0


# ---- Solids against cells ----

## For every cell near the floor, the nearest solid within the clearance:
## every solid (`nearest`), and all but a seat's own, or that of a
## placement whose kind has sit anchors, within its protected squares
## (`nearest_gated`).
func _nearest() -> void:
	var n := nav.cols * nav.rows
	nearest.resize(n)
	nearest.fill(INF)
	nearest_solid.resize(n)
	nearest_solid.fill(-1)
	nearest_gated.resize(n)
	nearest_gated.fill(INF)
	nearest_gated_solid.resize(n)
	nearest_gated_solid.fill(-1)
	for s in solids.size():
		var solid = solids[s]
		var own: Dictionary = placed.get(str(solid.owner.get("placement_id", "")), {})
		var c := _cells_of(solid.bounds)
		for j in range(c[1], c[3] + 1):
			for i in range(c[0], c[2] + 1):
				var k := j * nav.cols + i
				if near[k] == 0:
					continue
				var centre := _centre_m(Vector2i(i, j))
				var d: float = solid.probe(centre, CLEARANCE)
				if d < nearest[k]:
					nearest[k] = d
					nearest_solid[k] = s
				if d < nearest_gated[k] and not in_own_square(own, centre):
					nearest_gated[k] = d
					nearest_gated_solid[k] = s


## Cell `k`'s nearest solid, as the gates read it, as an offender.
func _offender(k: int, extra := {}) -> Dictionary:
	var solid = solids[nearest_gated_solid[k]]
	var o: Dictionary = solid.owner.duplicate()
	o["cell"] = [k % nav.cols, k / nav.cols]
	o["depth_cm"] = ceili((CLEARANCE - nearest_gated[k]) * 100.0 - 0.01)
	o.merge(extra)
	return o


## A gate's result: its count (cells, or visits where offenders carry
## them), its offenders, and the count by the offenders' kind.
static func _gate(offenders: Array) -> Dictionary:
	var count := 0
	var by_kind := {}
	for o in offenders:
		var n := int(o.get("visits", 1))
		count += n
		by_kind[o["kind"]] = int(by_kind.get(o["kind"], 0)) + n
	return {"count": count, "offenders": offenders, "by_kind": by_kind}


func _through() -> Dictionary:
	var out := []
	for k in nearest_gated.size():
		if nav._room[k] >= 0 and nearest_gated[k] <= 0.0:
			out.append(_offender(k))
	return _gate(out)


func _within() -> Dictionary:
	var out := []
	for k in nearest_gated.size():
		if nav._room[k] >= 0 and nearest_gated[k] < CLEARANCE - 1e-4:
			out.append(_offender(k))
	return _gate(out)


## Blocked cells with nothing solid within the clearance, reached from
## walkable floor within REACH_CELLS steps through such cells: those in a
## room gated, the rest reported. Each gated one names what blocks it (the
## placement, lot or building shell), counted by kind and by placement.
func _reverse() -> Dictionary:
	var n := nav.cols * nav.rows
	var reached := PackedByteArray()
	reached.resize(n)
	var frontier := PackedInt32Array()
	for k in n:
		if nav._room[k] >= 0:
			frontier.append(k)
	for step in REACH_CELLS:
		var next := PackedInt32Array()
		for k in frontier:
			var i := k % nav.cols
			var j := k / nav.cols
			for nb in [k - 1 if i > 0 else -1, k + 1 if i < nav.cols - 1 else -1, k - nav.cols if j > 0 else -1, k + nav.cols if j < nav.rows - 1 else -1]:
				if nb >= 0 and reached[nb] == 0 and nav._room[nb] < 0 and nearest[nb] >= CLEARANCE:
					reached[nb] = 1
					next.append(nb)
		frontier = next
	_reached = reached
	var gated := []
	var outside := 0
	var blockers := _blockers(reached)
	for k in n:
		if reached[k] == 0:
			continue
		if in_room[k] == 0:
			outside += 1
			continue
		var o: Dictionary = blockers.get(k, {"kind": "grid"}).duplicate()
		o["cell"] = [k % nav.cols, k / nav.cols]
		o["depth_cm"] = 0
		gated.append(o)
	# And by what blocks them (a block's lot, a shelter, a shell), so a
	# pack task can see which lot to fill or trim.
	var result := _gate(gated)
	var by_placement := {}
	for o in gated:
		var whose := str(o.get("placement_id", o.get("building", o["kind"])))
		by_placement[whose] = int(by_placement.get(whose, 0)) + 1
	result["by_placement"] = by_placement
	return {"gated": result, "outside": outside}


## What blocks each of `cells` (a mask): the placement or seat whose
## footprint, grown by the clearance, holds its centre, or the building
## whose shell does. Read with floats: it names, it does not decide.
func _blockers(cells: PackedByteArray) -> Dictionary:
	var out := {}
	var kinds := StylePack.kinds()
	var ids := placed.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = placed[id]
		var kind: Dictionary = kinds.get(p["kind"], {})
		var shapes: Array = []
		if p["size"] != Vector2.ZERO:
			shapes = [{"x": -p["size"].x * 50.0, "z": -p["size"].y * 50.0, "w": p["size"].x * 100.0, "d": p["size"].y * 100.0}]
		else:
			shapes = kind.get("footprint", [])
		if shapes.is_empty():
			continue
		var reach := 0.0
		for sh in shapes:
			var far: float = Vector2(absf(sh["x"]) + sh.get("w", 0.0), absf(sh["z"]) + sh.get("d", 0.0)).length() + sh.get("r", 0.0)
			reach = maxf(reach, far / 100.0)
		var c := _cells_of(Rect2(p["pos"], Vector2.ZERO).grow(reach))
		for j in range(c[1], c[3] + 1):
			for i in range(c[0], c[2] + 1):
				var k := j * nav.cols + i
				if cells[k] == 0 or out.has(k):
					continue
				if _covers(shapes, p, _centre_m(Vector2i(i, j)) * 100.0):
					out[k] = {"kind": p["kind"], "placement_id": id}
	for b in CityGeometry.buildings(main.manifest, StylePack.kinds()):
		var wall := float(kinds.get(b["kind"], {}).get("wall", 25)) / 100.0
		for r in b["rooms"]:
			if r.get("rect") == null:
				continue
			var shell := CityGeometry.rect_m(r["rect"]).grow(wall + CLEARANCE)
			var c := _cells_of(shell)
			for j in range(c[1], c[3] + 1):
				for i in range(c[0], c[2] + 1):
					var k := j * nav.cols + i
					if cells[k] == 1 and not out.has(k) and shell.has_point(_centre_m(Vector2i(i, j))):
						out[k] = {"kind": "building", "building": str(b["id"])}
	return out


## Whether `shapes` (a kind's footprint, centimetres in its frame) placed
## as `p` and grown by the clearance hold `q` (centimetres).
static func _covers(shapes: Array, p: Dictionary, q: Vector2) -> bool:
	var t := deg_to_rad(float(p["facing"]))
	var d: Vector2 = q - p["pos"] * 100.0
	var local := Vector2(d.x * cos(t) + d.y * sin(t), -d.x * sin(t) + d.y * cos(t))
	var m := CLEARANCE * 100.0
	for sh in shapes:
		if sh.has("r"):
			if local.distance_to(Vector2(sh["x"], sh["z"])) < float(sh["r"]) + m:
				return true
		elif Rect2(sh["x"], sh["z"], sh["w"], sh["d"]).grow(m).has_point(local):
			return true
	return false


# ---- The day ----

## Indices (into the day's visits) of steps onto and off one's own seat:
## within SEAT_TICKS ticks and SEAT_CELLS cells of where one sat.
func _own_seat_steps(day: Dictionary) -> Dictionary:
	var sat := {}
	var s: PackedInt32Array = day["seated"]
	for r in s.size() / 4:
		sat["%d@%d" % [s[r * 4 + 1], s[r * 4]]] = Vector2i(s[r * 4 + 2], s[r * 4 + 3])
	var own := {}
	var v: PackedInt32Array = day["visits"]
	for r in v.size() / 5:
		for dt in range(-SEAT_TICKS, SEAT_TICKS + 1):
			var at = sat.get("%d@%d" % [v[r * 5 + 1], v[r * 5] + dt])
			if at != null and absi(at.x - v[r * 5 + 2]) <= SEAT_CELLS and absi(at.y - v[r * 5 + 3]) <= SEAT_CELLS:
				own[r] = true
				break
	return own


func _in_grid(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < nav.cols and j < nav.rows


## Visits, grouped by cell, as offenders carrying their visit count.
func _visits_at(cells: Dictionary) -> Dictionary:
	var out := []
	var keys := cells.keys()
	keys.sort()
	for k in keys:
		out.append(_offender(k, {"visits": cells[k]}))
	return _gate(out)


func _walker_pass(day: Dictionary, own: Dictionary) -> Dictionary:
	var cells := {}
	var v: PackedInt32Array = day["visits"]
	for r in v.size() / 5:
		var i := v[r * 5 + 2]
		var j := v[r * 5 + 3]
		if own.has(r) or not _in_grid(i, j):
			continue
		var k := j * nav.cols + i
		if nearest_gated[k] <= 0.0 and nav._room[k] >= 0:
			cells[k] = cells.get(k, 0) + 1
	return _visits_at(cells)


func _player_pass(day: Dictionary) -> Dictionary:
	var cells := {}
	var v: PackedInt32Array = day["player"]["visits"]
	for r in v.size() / 4:
		var i := v[r * 4 + 1]
		var j := v[r * 4 + 2]
		if not _in_grid(i, j):
			continue
		var k := j * nav.cols + i
		if nearest_gated[k] <= 0.0 and nav._room[k] >= 0:
			cells[k] = cells.get(k, 0) + 1
	return _visits_at(cells)


## Walkers ending a tick inside a drawn tram body (its line's vehicle
## length back from its front, the drawn half width either side) but
## outside the core's (the tram kind's width).
func _tram_overlap(day: Dictionary, own: Dictionary, tram: Dictionary) -> Dictionary:
	var drawn := float(tram.get("half_width", 0.0)) + absf(float(tram.get("centre", 0.0)))
	var core := float(StylePack.kinds().get("tram", {}).get("width", 250)) / 200.0
	var lengths := {}
	for line in lines:
		lengths[str(line["id"])] = float(line.get("vehicle", {}).get("length", DEFAULT_TRAM_LENGTH_M * 100.0)) / 100.0
	var bodies := {}
	var vs: PackedFloat64Array = day["vehicles"]
	var vehicle_lines: Array = day["vehicle_lines"]
	for r in vs.size() / 5:
		var h := deg_to_rad(vs[r * 5 + 4])
		var line_id: String = vehicle_lines[int(vs[r * 5 + 1])]
		if not lengths.has(line_id):
			# Counted still, at the default length, so the gate is not
			# silently switched off.
			push_error("collision audit: a tram runs on %s, which the layout does not hold" % line_id)
			lengths[line_id] = DEFAULT_TRAM_LENGTH_M
		var length: float = lengths[line_id]
		bodies.get_or_add(int(vs[r * 5]), []).append([Vector2(vs[r * 5 + 2], vs[r * 5 + 3]) / 100.0, Vector2(sin(h), -cos(h)), length])
	var cells := {}
	var depth := {}
	var v: PackedInt32Array = day["visits"]
	for r in v.size() / 5:
		if v[r * 5 + 4] != 1 or own.has(r) or not bodies.has(v[r * 5]):
			continue
		var c := Vector2i(v[r * 5 + 2], v[r * 5 + 3])
		var p := _centre_m(c)
		for b in bodies[v[r * 5]]:
			var rel: Vector2 = p - b[0]
			var along: float = -rel.dot(b[1])
			var across: float = absf(rel.cross(b[1]))
			if along >= 0.0 and along <= b[2] and across <= drawn and across > core:
				var k := _index(c)
				cells[k] = cells.get(k, 0) + 1
				depth[k] = ceili((drawn - across) * 100.0)
	var out := []
	var keys := cells.keys()
	keys.sort()
	for k in keys:
		out.append({"kind": "tram", "mesh": "vehicle", "cell": [k % nav.cols, k / nav.cols], "depth_cm": depth[k], "visits": cells[k]})
	return _gate(out)


# ---- Measuring kinds ----

## Every placement's (and seat's) band silhouette in its kind's frame
## (centimetres, facing 0 = north): per kind, the box round it, the
## farthest reach from the placement's point, and the outline's parts.
func _measure() -> Dictionary:
	var out := {}
	for solid in solids:
		var id := str(solid.owner.get("placement_id", ""))
		if id == "" or not placed.has(id):
			continue
		var p: Dictionary = placed[id]
		var t := deg_to_rad(float(p["facing"]))
		var unturn := func(w: Vector2) -> Vector2:
			var d: Vector2 = (w - p["pos"]) * 100.0
			return Vector2(d.x * cos(t) + d.y * sin(t), -d.x * sin(t) + d.y * cos(t))
		var entry: Dictionary = out.get_or_add(p["kind"], {"count": 0, "ids": {}, "box": [INF, INF, -INF, -INF], "reach": 0.0, "parts": {}})
		entry["ids"][id] = true
		var box: Array = entry["box"]
		for w in solid.world_points():
			var q: Vector2 = unturn.call(w)
			box[0] = minf(box[0], q.x)
			box[1] = minf(box[1], q.y)
			box[2] = maxf(box[2], q.x)
			box[3] = maxf(box[3], q.y)
			entry["reach"] = maxf(entry["reach"], q.length())
		for c in solid.contours:
			var part := [INF, INF, -INF, -INF]
			for w in solid.to_world * c:
				var q: Vector2 = unturn.call(w)
				part = [minf(part[0], q.x), minf(part[1], q.y), maxf(part[2], q.x), maxf(part[3], q.y)]
			var key := "%d,%d,%d,%d" % [floori(part[0] / 5.0) * 5, floori(part[1] / 5.0) * 5, ceili(part[2] / 5.0) * 5, ceili(part[3] / 5.0) * 5]
			entry["parts"][key] = true
	for kind in out:
		var e: Dictionary = out[kind]
		e["count"] = e["ids"].size()
		e.erase("ids")
		var parts: Array = e["parts"].keys()
		parts.sort()
		e["parts"] = parts
	return out


# ---- Reporting ----

## A picture of the grid, 4 px a cell (see tools/collision_audit.gd).
func _overlay(path: String) -> void:
	var img := Image.create(nav.cols, nav.rows, false, Image.FORMAT_RGB8)
	for k in nearest.size():
		var c := Vector2i(k % nav.cols, k / nav.cols)
		var colour := Color(0.93, 0.93, 0.93)
		if nav._room[k] >= 0:
			colour = Color(0.62, 0.85, 0.62)
			if seat_at.has(c):
				colour = Color(1.0, 0.9, 0.2)
			elif nearest_gated[k] <= 0.0:
				colour = Color(0.85, 0.1, 0.1)
			elif nearest_gated[k] < CLEARANCE - 1e-4:
				colour = Color(1.0, 0.6, 0.1)
		elif not _reached.is_empty() and _reached[k] == 1:
			colour = Color(0.15, 0.35, 0.95) if in_room[k] == 1 else Color(0.6, 0.75, 1.0)
		elif nearest[k] <= 0.0:
			colour = Color(0.35, 0.35, 0.38)
		elif in_room[k] == 1:
			colour = Color(0.72, 0.72, 0.72)
		img.set_pixelv(c, colour)
	img.resize(nav.cols * 4, nav.rows * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(path)


## Measurements from several styles' `kinds` (style -> CollisionAudit
## results' `kinds`), per kind: each style's box (a rect, centimetres in
## the kind's frame, rounded out to 5 cm), reach (a disc about the point,
## rounded up to 5 cm) and parts, and the widest across the styles in the
## shape of the kind's catalogue footprint (discs for a disc-footed kind,
## else a rect).
static func kind_sizes(by_style: Dictionary) -> Dictionary:
	var kinds := StylePack.kinds()
	var out := {}
	for style_ in by_style:
		for kind in by_style[style_]:
			var m: Dictionary = by_style[style_][kind]
			var box: Array = m["box"]
			var x0 := floori(box[0] / 5.0 + 1e-6) * 5
			var z0 := floori(box[1] / 5.0 + 1e-6) * 5
			var rect := {"x": x0, "z": z0, "w": ceili(box[2] / 5.0 - 1e-6) * 5 - x0, "d": ceili(box[3] / 5.0 - 1e-6) * 5 - z0}
			var entry: Dictionary = out.get_or_add(kind, {"catalogue": kinds.get(kind, {}).get("footprint", []), "styles": {}})
			entry["styles"][style_] = {"placements": m["count"], "rect": rect, "r": ceili(m["reach"] / 5.0 - 1e-6) * 5, "parts": m["parts"]}
	for kind in out:
		var e: Dictionary = out[kind]
		var discs: bool = not e["catalogue"].is_empty() and e["catalogue"].all(func(sh): return sh.has("r"))
		var r := 0
		var b := [INF, INF, -INF, -INF]
		for style_ in e["styles"]:
			var s: Dictionary = e["styles"][style_]
			r = maxi(r, s["r"])
			b = [minf(b[0], s["rect"]["x"]), minf(b[1], s["rect"]["z"]), maxf(b[2], s["rect"]["x"] + s["rect"]["w"]), maxf(b[3], s["rect"]["z"] + s["rect"]["d"])]
		e["widest"] = [{"x": 0, "z": 0, "r": r}] if discs else [{"x": int(b[0]), "z": int(b[1]), "w": int(b[2] - b[0]), "d": int(b[3] - b[1])}]
	return out



## Why `results` (style -> CollisionAudit.run's result) may not be written
## as kind sizes or a budget, or "": a MultiMesh whose pieces could not be
## placed was left out of them.
static func unwritable(results: Dictionary) -> String:
	var why := []
	for style_ in results:
		var unplaced: Dictionary = results[style_].get("info", {}).get("unplaced_multimeshes", {})
		if not unplaced.is_empty():
			why.append("%s left out %s" % [style_, unplaced])
	return "; ".join(why)
